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


def glb_info(path, visual=True, textured=False, projected=False):
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
            required = {"TEXCOORD_0", "NORMAL"} | (set() if textured else {"COLOR_0"})
            if visual and not required <= attrs.keys():
                raise ValueError("Missing UV, normal or preserved vertex color")
            if textured:
                material = data["materials"][prim["material"]]["pbrMetallicRoughness"]
                image = data["images"][data["textures"][material["baseColorTexture"]["index"]]["source"]]
                if "bufferView" not in image or "COLOR_0" in attrs:
                    raise ValueError("Expected embedded base color without vertex tint")
                if projected:
                    normal = data["materials"][prim["material"]]["normalTexture"]
                    normal_image = data["images"][data["textures"][normal["index"]]["source"]]
                    if "bufferView" not in normal_image or "TANGENT" not in attrs:
                        raise ValueError("Expected embedded tangent normal and mesh tangents")
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
        baked = info.get("settings", {}).get("bake_size", 0) > 0
        expected = {"lod0.glb", "lod1.glb", "lod2.glb", "collision.glb"}
        if baked:
            expected |= {"lod%d-basecolor.png" % i for i in range(3)}
        projected = info.get("settings", {}).get("project_normals", False)
        if projected:
            expected |= {"lod%d-normal.png" % i for i in range(3)}
        if info.get("settings", {}).get("bake_ao", False):
            expected |= {"lod%d-ao.png" % i for i in range(3)}
        return (info["signature"] == signature and info["status"] == "unapproved"
                and set(info["outputs"]) == expected
                and all(sha(folder / name) == item["sha256"]
                        and (png_size(folder / name) == tuple(item["size"]) if name.endswith(".png")
                             else glb_info(folder / name, name != "collision.glb",
                                           baked and name != "collision.glb",
                                           projected and name != "collision.glb") == item["triangles"])
                        for name, item in info["outputs"].items()))
    except (OSError, ValueError, KeyError, TypeError, struct.error):
        return False


def select(obj):
    import bpy
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def export(obj, path, visual, textured=False, projected=False):
    import bpy
    select(obj)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB",
                              use_selection=True, export_materials="EXPORT" if visual else "NONE",
                              export_normals=True, export_texcoords=visual, export_tangents=projected)
    return glb_info(path, visual, textured, projected)


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


def png_size(path):
    with path.open("rb") as f:
        header = f.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError("Invalid PNG")
    return struct.unpack(">II", header[16:24])


def unwrap(obj):
    import bpy
    select(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    try:
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(island_margin=0.02)
    finally:
        bpy.ops.object.mode_set(mode="OBJECT")


def bake_basecolor(obj, path, size):
    """Bake reconstructed vertex color, not measured or de-lit albedo."""
    import bpy
    import numpy as np
    select(obj)
    unwrap(obj)
    color = obj.data.color_attributes.active_color or obj.data.color_attributes[0]
    mat = bpy.data.materials.new("Baked base color candidate")
    mat.use_nodes = True
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.material_index = 0
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    emission = nodes.new("ShaderNodeEmission")
    vertex = nodes.new("ShaderNodeVertexColor")
    vertex.layer_name = color.name
    links.new(vertex.outputs["Color"], emission.inputs["Color"])
    links.new(emission.outputs[0], output.inputs["Surface"])
    image = bpy.data.images.new(path.stem, width=size, height=size, alpha=True)
    image.colorspace_settings.name = "sRGB"
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    nodes.active = tex
    for node in nodes:
        node.select = False
    tex.select = True
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 1
    # Emission baking needs no denoiser; distro Blender may omit OIDN.
    scene.cycles.use_denoising = False
    for layer in scene.view_layers:
        if hasattr(layer.cycles, "use_denoising"):
            layer.cycles.use_denoising = False
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 2
    result = bpy.ops.object.bake(type="EMIT", margin=max(4, size // 128), use_clear=True)
    if "FINISHED" not in result:
        raise RuntimeError("Cycles emission bake did not finish")
    pixels = np.empty(size * size * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    pixels = pixels.reshape((-1, 4))
    valid = pixels[:, 3] > 0.5
    if not np.isfinite(pixels).all() or not valid.any():
        raise ValueError("Empty or nonfinite bake")
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    if png_size(path) != (size, size):
        raise ValueError("Unexpected bake dimensions")
    image.pack()
    nodes.remove(emission)
    nodes.remove(vertex)
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(bsdf.outputs[0], output.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = 0.7
    bsdf.inputs["Metallic"].default_value = 0.0
    # Prevent double multiplication by glTF COLOR_0.
    for attr in list(obj.data.color_attributes):
        obj.data.color_attributes.remove(attr)
    return {"size": [size, size], "sha256": sha(path), "coverage_with_margin": float(valid.mean())}


def bake_projected_normal(high, low, path, size, extent, base_coverage):
    """Selected-to-active tangent-space projection from dense cleaned source."""
    import bpy
    import numpy as np
    mat = low.data.materials[0]
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    image = bpy.data.images.new(path.stem, width=size, height=size, alpha=True)
    image.colorspace_settings.name = "Non-Color"
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    for node in nodes:
        node.select = False
    tex.select = True
    nodes.active = tex
    select(low)
    high.select_set(True)
    extrusion = extent * .02
    max_ray = extent * .08
    result = bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT",
                                 normal_r="POS_X", normal_g="POS_Y", normal_b="POS_Z",
                                 use_selected_to_active=True, cage_extrusion=extrusion,
                                 max_ray_distance=max_ray, margin=max(4,size//128),
                                 use_clear=True)
    if "FINISHED" not in result:
        raise RuntimeError("Normal projection did not finish")
    pixels = np.empty(size*size*4,dtype=np.float32)
    image.pixels.foreach_get(pixels)
    pixels = pixels.reshape((-1,4))
    valid = pixels[:,3] > .5
    coverage = float(valid.mean())
    if not np.isfinite(pixels).all() or coverage < max(.005,base_coverage*.75):
        raise ValueError("Projected normal coverage too low")
    vectors = pixels[valid,:3]*2-1
    lengths = np.linalg.norm(vectors,axis=1)
    unit_fraction = float(((lengths>.8)&(lengths<1.2)).mean())
    if unit_fraction < .95:
        raise ValueError("Invalid tangent-space normal vectors")
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    if png_size(path)!=(size,size):
        raise ValueError("Unexpected normal dimensions")
    image.pack()
    normal = nodes.new("ShaderNodeNormalMap")
    normal.space = "TANGENT"
    links.new(tex.outputs["Color"],normal.inputs["Color"])
    links.new(normal.outputs["Normal"],nodes.get("Principled BSDF").inputs["Normal"])
    return {"size":[size,size],"sha256":sha(path),"coverage_with_margin":coverage,
            "unit_vector_fraction":unit_fraction,"cage_extrusion":extrusion,
            "max_ray_distance":max_ray,"color_space":"linear","convention":"OpenGL +Y",
            "review":"projection misses and thin/intersecting surfaces require visual inspection"}


def bake_geometry_ao(obj, path, size, extent, base_coverage):
    """Self-occlusion of this LOD, not shadows from other studio objects."""
    import bpy
    import numpy as np
    select(obj)
    mat = obj.data.materials[0]
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    output = next(n for n in nodes if n.type == "OUTPUT_MATERIAL")
    bsdf = nodes.get("Principled BSDF")
    ao = nodes.new("ShaderNodeAmbientOcclusion")
    ao.only_local = True
    ao.samples = 16
    distance = extent * .08
    ao.inputs["Distance"].default_value = distance
    emission = nodes.new("ShaderNodeEmission")
    links.new(ao.outputs["AO"], emission.inputs["Color"])
    links.new(emission.outputs[0], output.inputs["Surface"])
    image = bpy.data.images.new(path.stem, width=size, height=size, alpha=True)
    image.colorspace_settings.name = "Non-Color"
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    for node in nodes:
        node.select = False
    tex.select = True
    nodes.active = tex
    scene = bpy.context.scene
    samples = scene.cycles.samples
    scene.cycles.samples = 16
    try:
        result = bpy.ops.object.bake(type="EMIT", margin=max(4,size//128),
                                     use_clear=True, use_selected_to_active=False)
        if "FINISHED" not in result:
            raise RuntimeError("AO bake did not finish")
        pixels = np.empty(size*size*4,dtype=np.float32)
        image.pixels.foreach_get(pixels)
        pixels = pixels.reshape((-1,4))
        valid = pixels[:,3]>.5
        coverage = float(valid.mean())
        if not np.isfinite(pixels).all() or coverage < max(.005,base_coverage*.75):
            raise ValueError("Empty or invalid AO bake")
        colors = pixels[valid,:3]
        if float(np.abs(colors-colors[:,:1]).max())>.015:
            raise ValueError("AO bake must be grayscale")
        if float(colors.min())<-.001 or float(colors.max())>1.001:
            raise ValueError("AO values out of range")
        image.filepath_raw = str(path)
        image.file_format = "PNG"
        image.save()
        if png_size(path)!=(size,size):
            raise ValueError("Unexpected AO dimensions")
        return {"size":[size,size],"sha256":sha(path),"coverage_with_margin":coverage,
                "mean_ao":float(colors.mean()),"ray_distance":distance,"color_space":"linear",
                "scope":"LOD self-occlusion; standalone review map, not embedded"}
    finally:
        scene.cycles.samples = samples
        nodes.remove(ao)
        nodes.remove(emission)
        nodes.remove(tex)
        links.new(bsdf.outputs[0],output.inputs["Surface"])
        bpy.data.images.remove(image)


def build(src, dest, height, bake_size=0, project_normals=False, bake_ao=False):
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
    high = duplicate(obj, "DENSE_SOURCE") if project_normals else None
    if high is not None:
        for face in high.data.polygons:
            face.use_smooth = True
    reduce(obj, BUDGETS[0])
    unwrap(obj)
    outputs = {}
    for i, target in enumerate(BUDGETS):
        lod = duplicate(obj, "LOD" + str(i))
        reduce(lod, target)
        name = "lod%d.glb" % i
        if bake_size:
            texture = "lod%d-basecolor.png" % i
            outputs[texture] = bake_basecolor(lod, dest / texture, max(64, bake_size // (2**i)))
        if project_normals:
            normal_name = "lod%d-normal.png" % i
            outputs[normal_name] = bake_projected_normal(high,lod,dest/normal_name,
                max(64,bake_size//(2**i)),max(bounds)*factor,
                outputs[texture]["coverage_with_margin"])
        if bake_ao:
            ao_name = "lod%d-ao.png" % i
            outputs[ao_name] = bake_geometry_ao(lod,dest/ao_name,
                max(64,bake_size//(2**i)),max(bounds)*factor,
                outputs[texture]["coverage_with_margin"])
        n = export(lod, dest / name, True, bool(bake_size), project_normals)
        if n > target:
            raise ValueError("Exported triangle budget exceeded")
        outputs[name] = {"triangles": n, "sha256": sha(dest / name)}
        bpy.data.objects.remove(lod, do_unlink=True)
    if high is not None:
        bpy.data.objects.remove(high,do_unlink=True)
    # Convex hull of the refined mesh, deliberately not a gameplay collider.
    # A hull can fill gaps such as chair legs or door openings.
    hull = duplicate(obj, "COLLISION_REVIEW_ONLY")
    reduce(hull, 256)
    bm = bmesh.new()
    try:
        # Build from a point cloud, not the existing surface faces.
        for vertex in hull.data.vertices:
            bm.verts.new(vertex.co)
        bmesh.ops.convex_hull(bm, input=list(bm.verts), use_existing_faces=False)
        verts = [v for v in bm.verts if not v.link_faces]
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
            "materials": ("baked reconstructed base color" if bake_size else "vertex color") + "; provisional scalar roughness/metalness; no measured PBR maps",
            "normal_projection": "dense source tangent normals; review pending" if project_normals else "disabled",
            "ambient_occlusion": "geometry-derived standalone map; not embedded" if bake_ao else "disabled",
            "collision": "convex candidate; not approved for gameplay",
            "outputs": outputs}


def main(args):
    import bpy
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True, type=Path, help="visual-001 directory")
    p.add_argument("--output", required=True, type=Path, help="separate refinement directory")
    p.add_argument("--limit", type=int, default=0, help="maximum newly attempted meshes; 0 = all")
    p.add_argument("--dimensions", type=Path, help="JSON map candidate ID -> measured height in metres")
    p.add_argument("--bake-size", type=int, choices=[0, 128, 512, 1024, 2048], default=0, help="LOD0 base color bake size; 0 disables")
    p.add_argument("--project-normals",action="store_true",help="Experimental dense-to-LOD tangent normals")
    p.add_argument("--bake-ao",action="store_true",help="Experimental geometry self-occlusion maps")
    opt = p.parse_args(args)
    if (opt.project_normals or opt.bake_ao) and not opt.bake_size:
        p.error("Normal projection and AO require a texture bake size")
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
                            "blender": bpy.app.version_string, "height_m": height, "budgets": BUDGETS,
                            "bake_size": opt.bake_size, "project_normals": opt.project_normals,
                            "bake_ao": opt.bake_ao}
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
                    info = build(folder / "mesh.glb", stage, height, opt.bake_size, opt.project_normals, opt.bake_ao)
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
