"""Offline Blender batch refinement; never publishes to res://.

Run using Blender's bundled Python, not the neural inference environments.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import struct
import sys
import tempfile
import traceback

VERSION = "refine-v1"
KEY = re.compile(r"[a-z0-9][a-z0-9.-]{0,110}")
BUDGETS = (12000, 5000, 1500)


def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def glb_info(path, visual=True):
    with path.open("rb") as f:
        magic, version, length = struct.unpack("<4sII", f.read(12))
        if magic != b"glTF" or version != 2 or length != path.stat().st_size:
            raise ValueError("Invalid GLB header")
        size, tag = struct.unpack("<I4s", f.read(8))
        if tag != b"JSON" or size > min(length - 20, 32 * 1024**2):
            raise ValueError("Invalid GLB JSON chunk")
        data = json.loads(f.read(size))
    count = 0
    for mesh in data.get("meshes", []):
        for prim in mesh["primitives"]:
            attrs = prim["attributes"]
            if prim.get("mode", 4) != 4 or "POSITION" not in attrs:
                raise ValueError("Expected triangles")
            if visual and not {"TEXCOORD_0", "NORMAL", "COLOR_0"} <= attrs.keys():
                raise ValueError("Missing UV, normal or preserved vertex color")
            n = data["accessors"][prim.get("indices", attrs["POSITION"])]["count"]
            if n % 3:
                raise ValueError("Invalid triangle index count")
            count += n // 3
    if not count:
        raise ValueError("Empty mesh")
    return count


def source(folder):
    if not KEY.fullmatch(folder.name) or ".." in folder.name:
        raise ValueError("Unsafe candidate ID")
    if folder.is_symlink():
        raise ValueError("Candidate symlinks not supported")
    names = ("concept.png", "image.json", "mesh.glb", "mesh.json")
    if not all((folder / name).is_file() for name in names):
        return None
    if any((folder / name).is_symlink() for name in names):
        raise ValueError("Candidate symlinks not supported")
    image, mesh = load(folder / "image.json"), load(folder / "mesh.json")
    hashes = {name: sha(folder / name) for name in names}
    if (image["job"] != mesh["job"] or mesh["job"]["key"] != folder.name
            or mesh["job"]["kind"] != "prop"
            or image["sha256"] != hashes["concept.png"]
            or mesh["sha256"] != hashes["mesh.glb"]
            or mesh["input_sha256"] != hashes["concept.png"]):
        raise ValueError("Source provenance mismatch")
    return hashes


def verified(folder, signature):
    try:
        info = load(folder / "refinement.json")
        return (info["signature"] == signature and info["status"] == "unapproved"
                and set(info["outputs"]) == {"lod0.glb", "lod1.glb", "lod2.glb", "collision.glb"}
                and all(sha(folder / name) == item["sha256"]
                        and glb_info(folder / name, name != "collision.glb") == item["triangles"]
                        for name, item in info["outputs"].items()))
    except (OSError, ValueError, KeyError, TypeError, struct.error):
        return False


def select(obj):
    import bpy
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def export(obj, path, visual):
    import bpy
    select(obj)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB",
                              use_selection=True, export_materials="EXPORT" if visual else "NONE",
                              export_normals=True, export_texcoords=visual)
    return glb_info(path, visual)


def triangles(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def duplicate(obj, name):
    import bpy
    copy = obj.copy()
    copy.data = obj.data.copy()
    copy.name = name
    bpy.context.collection.objects.link(copy)
    return copy


def reduce(obj, target):
    import bpy
    count = triangles(obj)
    if count > target:
        select(obj)
        mod = obj.modifiers.new("Triangle budget", "DECIMATE")
        mod.ratio = target / count
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if triangles(obj) == 0 or triangles(obj) > target:
        raise ValueError("Decimation did not satisfy triangle budget")


def build(src, dest, height):
    import bpy
    import bmesh
    from mathutils import Vector
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(src))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if len(meshes) != 1:
        raise ValueError("Expected one static source mesh; multi-part candidates need authored handling")
    obj = meshes[0]
    select(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new()
    try:
        bm.from_mesh(obj.data)
        if not bm.verts or not all(math.isfinite(c) for v in bm.verts for c in v.co):
            raise ValueError("Empty or nonfinite source")
        original = len(bm.faces)
        # Relative weld tolerance avoids assuming source units are metres.
        extent = max(max(v.co[i] for v in bm.verts)-min(v.co[i] for v in bm.verts) for i in range(3))
        if extent <= 0:
            raise ValueError("Zero extent")
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=extent * 1e-6)
        bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=extent * 1e-7)
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context="VERTS")
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        if not bm.faces:
            raise ValueError("Cleanup removed all faces")
        bm.to_mesh(obj.data)
    finally:
        bm.free()
    obj.data.update()
    low = Vector(tuple(min(v.co[i] for v in obj.data.vertices) for i in range(3)))
    high = Vector(tuple(max(v.co[i] for v in obj.data.vertices) for i in range(3)))
    bounds = high - low
    if min(bounds) <= 0:
        raise ValueError("Degenerate bounds")
    factor = height / bounds.z if height is not None else 1.0
    anchor = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
    for v in obj.data.vertices:
        v.co = (v.co - anchor) * factor
    obj.data.update()
    # Refuse to silently replace neural vertex color with a flat material.
    colors = obj.data.color_attributes
    if not len(colors):
        raise ValueError("No source vertex colors")
    color = colors.active_color or colors[0]
    mat = bpy.data.materials.new("Provisional vertex-color dielectric")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    vertex = nodes.new("ShaderNodeVertexColor")
    vertex.layer_name = color.name
    mat.node_tree.links.new(vertex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.7
    bsdf.inputs["Metallic"].default_value = 0.0
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    for p in obj.data.polygons:
        p.material_index = 0
    reduce(obj, BUDGETS[0])
    select(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    try:
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(island_margin=0.02)
    finally:
        bpy.ops.object.mode_set(mode="OBJECT")
    outputs = {}
    for i, target in enumerate(BUDGETS):
        lod = duplicate(obj, "LOD" + str(i))
        reduce(lod, target)
        name = "lod%d.glb" % i
        n = export(lod, dest / name, True)
        if n > target:
            raise ValueError("Exported triangle budget exceeded")
        outputs[name] = {"triangles": n, "sha256": sha(dest / name)}
        bpy.data.objects.remove(lod, do_unlink=True)
    # Convex hull of the refined mesh, deliberately not a gameplay collider.
    # A hull can fill gaps such as chair legs or door openings.
    hull = duplicate(obj, "COLLISION_REVIEW_ONLY")
    reduce(hull, 256)
    bm = bmesh.new()
    try:
        bm.from_mesh(hull.data)
        result = bmesh.ops.convex_hull(bm, input=list(bm.verts), use_existing_faces=False)
        discard = set(result["geom_unused"]) | set(result["geom_interior"])
        verts = [v for v in discard if isinstance(v, bmesh.types.BMVert) and v.is_valid]
        if verts:
            bmesh.ops.delete(bm, geom=verts, context="VERTS")
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        if not bm.faces or not all(e.is_manifold for e in bm.edges):
            raise ValueError("Collision hull is not closed")
        bm.to_mesh(hull.data)
    finally:
        bm.free()
    hull.data.update()
    n = export(hull, dest / "collision.glb", False)
    outputs["collision.glb"] = {"triangles": n, "sha256": sha(dest / "collision.glb")}
    return {"source_faces": original, "source_bounds_blender_xyz": list(bounds),
            "output_bounds_target_xyz": list(bounds * factor),
            "scale_status": "specified-height-only" if height is not None else "unresolved",
            "anchor": "ground-center; Blender Z up, glTF Y up",
            "materials": "vertex color; provisional scalar roughness/metalness; no measured PBR maps",
            "collision": "convex candidate; not approved for gameplay",
            "outputs": outputs}


def main(args):
    import bpy
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True, type=Path, help="visual-001 directory")
    p.add_argument("--output", required=True, type=Path, help="separate refinement directory")
    p.add_argument("--limit", type=int, default=0, help="maximum newly attempted meshes; 0 = all")
    p.add_argument("--dimensions", type=Path, help="JSON map candidate ID -> measured height in metres")
    opt = p.parse_args(args)
    src, out = opt.input.resolve(), opt.output.resolve()
    if not (src / "candidates").is_dir() or out == src or src in out.parents or out in src.parents:
        p.error("Input must exist; output must be a separate sibling or unrelated directory")
    if opt.limit < 0:
        p.error("Limit must be nonnegative")
    dimensions = load(opt.dimensions) if opt.dimensions else {}
    out.mkdir(parents=True, exist_ok=True)
    # Exclusive lock, including on NAS. Stale lock requires operator inspection.
    lock = out / ".refinement.lock"
    try:
        lock.mkdir()
    except FileExistsError:
        p.error("Refinement lock exists; inspect running processes before removing it")
    failures = attempted = cached = skipped = 0
    try:
        for folder in sorted((src / "candidates").iterdir()):
            if opt.limit and attempted >= opt.limit:
                break
            if not folder.is_dir():
                continue
            try:
                hashes = source(folder)
                if hashes is None:
                    skipped += 1
                    continue
                height = dimensions.get(folder.name)
                if height is not None and (isinstance(height, bool) or not isinstance(height, (float, int))
                                           or not math.isfinite(height) or height <= 0):
                    raise ValueError("Invalid measured height")
                settings = {"source": hashes, "pipeline": VERSION, "script": sha(Path(__file__)),
                            "blender": bpy.app.version_string, "height_m": height, "budgets": BUDGETS}
                signature = hashlib.sha256(json.dumps(settings, sort_keys=True).encode()).hexdigest()
                parent = out / folder.name
                final = parent / signature
                if verified(final, signature):
                    cached += 1
                    continue
                if final.exists():
                    raise ValueError("Existing refined result failed verification; quarantine manually")
                attempted += 1
                parent.mkdir(exist_ok=True)
                if shutil.disk_usage(out).free < 5 * 1024**3:
                    raise RuntimeError("Refinement output volume below 5 GiB reserve")
                stage = Path(tempfile.mkdtemp(prefix=".stage-", dir=parent))
                try:
                    print("Refining", folder.name, flush=True)
                    info = build(folder / "mesh.glb", stage, height)
                    if source(folder) != hashes:
                        raise ValueError("Source changed during refinement")
                    write(stage / "refinement.json", dict(info, signature=signature, settings=settings,
                          candidate=folder.name, status="unapproved", godot_import="pending",
                          review=["silhouette", "UV overlap/stretch", "scale/orientation", "PBR maps",
                                  "collision suitability", "rights", "native Godot visuals and performance"]))
                    if not verified(stage, signature):
                        raise ValueError("Staged exports failed verification")
                    stage.rename(final)
                finally:
                    if stage.exists():
                        shutil.rmtree(stage)
            except Exception:
                failures += 1
                print("FAILED:", folder.name, file=sys.stderr)
                traceback.print_exc()
        print("Attempted=%d cached=%d incomplete=%d failures=%d" % (attempted, cached, skipped, failures), flush=True)
    finally:
        lock.rmdir()
    return int(bool(failures))


if __name__ == "__main__":
    # Blender's --python-exit-code handles exceptions, not a normal return.
    argv = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    if main(argv):
        raise RuntimeError("One or more candidates failed refinement")
