"""Blender offline orthographic foliage impostor views (not runtime-ready)."""
import argparse
import math
from pathlib import Path
import sys


def render(source, out, size, samples):
    import bpy
    from mathutils import Vector
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    scene = bpy.context.scene
    meshes = [o for o in scene.objects if o.type == "MESH"]
    points = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    if not points or not all(math.isfinite(v) for p in points for v in p):
        raise ValueError("Missing or nonfinite source bounds")
    low = Vector([min(p[i] for p in points) for i in range(3)])
    high = Vector([max(p[i] for p in points) for i in range(3)])
    center = (low + high) * .5
    radius = max((p-center).length for p in points)
    if radius <= 0:
        raise ValueError("Degenerate source")
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 2
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1
    scene.view_settings.look = "None"
    scene.world = bpy.data.worlds.new("Black")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0
    camera_data = bpy.data.cameras.new("Impostor orthographic")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = radius * 2.3
    camera_data.clip_start = max(radius*.001, .0001)
    camera_data.clip_end = radius*20
    camera = bpy.data.objects.new("Impostor orthographic", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera

    # Original botanical GLBs use vertex colors; no baked directional light
    # in the base-color capture. A separate encoded camera-space normal pass
    # permits a future shader to relight the surface rather than painting sun.
    for mesh in meshes:
        if not mesh.data.color_attributes:
            raise ValueError("Source lacks expected vertex colors")
        attr = mesh.data.color_attributes.active_color
        if attr is None:
            attr = mesh.data.color_attributes[0]
        mat = bpy.data.materials.new("Offline albedo capture")
        mat.use_nodes = True
        n, l = mat.node_tree.nodes, mat.node_tree.links
        n.clear()
        output = n.new("ShaderNodeOutputMaterial")
        emission = n.new("ShaderNodeEmission")
        colors = n.new("ShaderNodeVertexColor")
        colors.layer_name = attr.name
        l.new(colors.outputs["Color"], emission.inputs["Color"])
        l.new(emission.outputs[0], output.inputs["Surface"])
        mesh.data.materials.clear()
        mesh.data.materials.append(mat)

    normal = bpy.data.materials.new("Camera-space normal capture")
    normal.use_nodes = True
    n, l = normal.node_tree.nodes, normal.node_tree.links
    n.clear()
    output = n.new("ShaderNodeOutputMaterial")
    emission = n.new("ShaderNodeEmission")
    geometry = n.new("ShaderNodeNewGeometry")
    transform = n.new("ShaderNodeVectorTransform")
    transform.vector_type = "NORMAL"
    transform.convert_from = "WORLD"
    transform.convert_to = "CAMERA"
    l.new(geometry.outputs["Normal"], transform.inputs["Vector"])
    scale = n.new("ShaderNodeVectorMath")
    scale.operation = "SCALE"
    scale.inputs["Scale"].default_value = .5
    l.new(transform.outputs["Vector"], scale.inputs[0])
    bias = n.new("ShaderNodeVectorMath")
    bias.operation = "ADD"
    bias.inputs[1].default_value = (.5,.5,.5)
    l.new(scale.outputs[0], bias.inputs[0])
    l.new(bias.outputs[0], emission.inputs["Color"])
    l.new(emission.outputs[0], output.inputs["Surface"])

    out.mkdir(parents=True, exist_ok=True)
    for channel in ("albedo", "normal"):
        if channel == "normal":
            # Standard applies sRGB transfer; Raw stores numeric normal data.
            scene.view_settings.view_transform = "Raw"
            for mesh in meshes:
                mesh.data.materials.clear()
                mesh.data.materials.append(normal)
        for row, elevation in enumerate((0, 25)):
            for col in range(8):
                angle = math.radians(col*45)
                pitch = math.radians(elevation)
                direction = Vector((math.cos(angle)*math.cos(pitch),
                                    math.sin(angle)*math.cos(pitch), math.sin(pitch)))
                camera.location = center + direction*radius*4
                camera.rotation_euler = (center-camera.location).to_track_quat("-Z","Y").to_euler()
                target = out / f"{channel}-{row*8+col:02d}.png"
                scene.render.filepath = str(target)
                if "FINISHED" not in bpy.ops.render.render(write_still=True):
                    raise RuntimeError("Capture failed " + target.name)
    import json
    (out / "camera.json").write_text(json.dumps({
        "blender": bpy.app.version_string, "orthographic_width_m": radius*2.3,
        "center_blender_z_up": list(center), "bounds_blender_z_up": [list(low),list(high)],
        "elevations_deg": [0,25], "azimuth_deg": list(range(0,360,45)),
        "normal_encoding": "camera xyz mapped to RGB by n*.5+.5, Raw view, not tangent space",
        "albedo_encoding": "unlit vertex color, Standard sRGB view",
    }, indent=2)+"\n")


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--source", type=Path, required=True)
    p.add_argument("--out", type=Path, required=True)
    p.add_argument("--size", type=int, choices=(256,512), default=512)
    p.add_argument("--samples", type=int, choices=(8,16,32,64), default=32)
    a = p.parse_args(sys.argv[sys.argv.index("--")+1:])
    render(a.source, a.out, a.size, a.samples)
