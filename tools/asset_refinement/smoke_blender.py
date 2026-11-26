"""Run under Blender in CI; a synthetic fixture, not a quality benchmark."""
import json
import os
from pathlib import Path
import sys
import tempfile

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from refine import main, sha, load, verified

with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    src, out = root / "raw", root / "refined"
    folder = src / "candidates" / "fixture.sphere.v1"
    folder.mkdir(parents=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32)
    obj = bpy.context.object
    color = obj.data.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    for i, v in enumerate(obj.data.vertices):
        color.data[i].color = ((v.co.x+1)/2, (v.co.y+1)/2, (v.co.z+1)/2, 1)
    mat = bpy.data.materials.new("Fixture")
    mat.use_nodes = True
    node = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    node.layer_name = color.name
    mat.node_tree.links.new(node.outputs["Color"], mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"])
    obj.data.materials.append(mat)
    bpy.ops.export_scene.gltf(filepath=str(folder/"mesh.glb"), export_format="GLB", use_selection=True)
    (folder/"concept.png").write_bytes(b"fixture-only")
    job = {"key": folder.name, "kind": "prop"}
    image = {"job": job, "sha256": sha(folder/"concept.png")}
    mesh = {"job": job, "sha256": sha(folder/"mesh.glb"), "input_sha256": image["sha256"]}
    (folder/"image.json").write_text(json.dumps(image))
    (folder/"mesh.json").write_text(json.dumps(mesh))
    args = ["--input", str(src), "--output", str(out)]
    assert main(args) == 0
    paths = list((out/folder.name).iterdir())
    assert len(paths) == 1
    manifest = load(paths[0]/"refinement.json")
    assert verified(paths[0], manifest["signature"])
    assert main(args) == 0
    assert len(list((out/folder.name).iterdir())) == 1
    assert manifest["scale_status"] == "unresolved"
    args += ["--bake-size", "128"]
    assert main(args) == 0
    results = [load(p/"refinement.json") for p in (out/folder.name).iterdir()]
    baked = next(m for m in results if m["settings"]["bake_size"] == 128)
    assert len(baked["outputs"]) == 7
    assert baked["outputs"]["lod0-basecolor.png"]["size"] == [128, 128]
    assert verified(out/folder.name/baked["signature"], baked["signature"])
    assert main(args) == 0
    if os.environ.get("ANUBIS_TEST_GODOT"):
        from godot_gate import run
        report = root / "godot-report.json"
        assert run(src, out, 128, Path(os.environ["ANUBIS_TEST_GODOT"]), report) == 0
        result = load(report)
        assert result["passed"] == 1 and result["failed"] == 0
        assert len(result["rows"][0]["files"]) == 4
    print("Blender fixture refinement, texture bake and resume passed")
