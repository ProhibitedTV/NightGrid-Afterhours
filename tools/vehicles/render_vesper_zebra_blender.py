#!/usr/bin/env python3
"""Studio zebra-reflection QA on authentic original Vesper body surfaces.

Run Blender --background on the editable .blend. A camera-dependent reflection
vector samples black/white environment bands. Distorted stripes reveal surface
and shading discontinuities; this is an inspection tool, not G2/Class-A proof.
"""
from __future__ import annotations

import argparse
from hashlib import sha256
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
import author_vesper_v2_blender as author


def zebra_material():
    mat=bpy.data.materials.new("QA__ZebraReflectedStripes__NOT_SHIPPED")
    mat.use_nodes=True
    nodes=mat.node_tree.nodes
    nodes.clear()
    coord=nodes.new("ShaderNodeTexCoord")
    projected=nodes.new("ShaderNodeVectorMath")
    projected.operation="DOT_PRODUCT"
    projected.inputs[1].default_value=(.34,.76,.55)
    frequency=nodes.new("ShaderNodeMath")
    frequency.operation="MULTIPLY"
    frequency.inputs[1].default_value=42.0
    sine=nodes.new("ShaderNodeMath")
    sine.operation="SINE"
    cutoff=nodes.new("ShaderNodeMath")
    cutoff.operation="GREATER_THAN"
    cutoff.inputs[1].default_value=0.0
    color=nodes.new("ShaderNodeMixRGB")
    color.blend_type="MIX"
    color.inputs[1].default_value=(.017,.023,.029,1.)
    color.inputs[2].default_value=(.94,.94,.94,1.)
    emission=nodes.new("ShaderNodeEmission")
    emission.inputs["Strength"].default_value=1.0
    output=nodes.new("ShaderNodeOutputMaterial")
    links=mat.node_tree.links
    links.new(coord.outputs["Reflection"],projected.inputs[0])
    links.new(projected.outputs["Value"],frequency.inputs[0])
    links.new(frequency.outputs[0],sine.inputs[0])
    links.new(sine.outputs[0],cutoff.inputs[0])
    links.new(cutoff.outputs[0],color.inputs[0])
    links.new(color.outputs["Color"],emission.inputs["Color"])
    links.new(emission.outputs[0],output.inputs["Surface"])
    return mat


def render(source:Path,destination:Path)->dict:
    bpy.ops.wm.open_mainfile(filepath=str(source))
    high=bpy.data.collections["MASTER__DETAIL__NONSHIPPING"]
    for name in ("GAME__LOD0","GAME__LOD1"):
        bpy.data.collections[name].hide_render=True
    high.hide_render=False
    stripes=zebra_material()
    replaced=0
    for obj in high.objects:
        if obj.type!="MESH":
            continue
        for idx,mat in enumerate(obj.data.materials):
            if mat and mat.name.startswith("VesperPetrolBlue"):
                obj.data.materials[idx]=stripes
                replaced+=1
    if replaced<10:
        raise RuntimeError("Expected original painted body assemblies not found")
    author.MATERIALS={m.name:m for m in bpy.data.materials}
    preview=author.collection("QA__ZEBRA__NOT_SHIPPED")
    camera=author.cameras_and_preview(preview)
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    scene.cycles.device="CPU"
    scene.cycles.samples=12
    scene.render.resolution_x=1120
    scene.render.resolution_y=700
    scene.render.resolution_percentage=100
    scene.render.film_transparent=False
    scene.render.image_settings.file_format="PNG"
    # Auxiliary light makes non-paint seals, wheels and cabin recognizable.
    for index,position in enumerate(((1.,-3.,7.),(-4.,5.,5.))):
        data=bpy.data.lights.new("QA studio "+str(index),"AREA")
        data.energy=1150
        data.shape="DISK"
        data.size=5.0
        ob=bpy.data.objects.new(data.name,data)
        preview.objects.link(ob)
        ob.location=position
        direction=Vector((0.,0.,.6))-ob.location
        ob.rotation_euler=direction.to_track_quat("-Z","Y").to_euler()
    destination.mkdir(parents=True,exist_ok=True)
    views={
        "zebra_front_three_quarter":((5.7,3.3,-6.2),(0,.69,0)),
        "zebra_rear_three_quarter":((-5.7,3.1,6.2),(0,.69,0)),
    }
    result={}
    for name,(eye,target) in views.items():
        camera.location=(eye[0],-eye[2],eye[1])
        t=Vector((target[0],-target[2],target[1]))
        camera.rotation_euler=(t-camera.location).to_track_quat("-Z","Y").to_euler()
        path=destination/(name+".png")
        scene.render.filepath=str(path)
        bpy.ops.render.render(write_still=True)
        if not path.is_file() or path.stat().st_size<1024:
            raise RuntimeError("Missing zebra reflection diagnostic "+name)
        result[path.name]={"sha256":sha256(path.read_bytes()).hexdigest(),
                           "bytes":path.stat().st_size,
                           "capture":"Cycles reflection-vector zebra diagnostic; NOT Godot"}
    manifest_path=destination/"source.json"
    manifest=json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["files"].update(result)
    manifest["zebra_quality_note"]="Normal-reflection QA of original Blender meshes, not surface continuity certification"
    manifest_path.write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n",
                             encoding="utf-8")
    return result


if __name__=="__main__":
    args=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input",type=Path,required=True)
    parser.add_argument("--output-dir",type=Path,required=True)
    opt=parser.parse_args(args)
    print(json.dumps(render(opt.input.resolve(),opt.output_dir.resolve()),indent=2))
