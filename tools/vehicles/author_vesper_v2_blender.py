#!/usr/bin/env python3
"""Vesper V2: original 2-seat convertible full-car asset study for NightGrid.

Use:
  blender --background --python-exit-code 1 --python tools/vehicles/author_vesper_v2_blender.py -- --output-dir out/vesper-v2

Creates editable high/low detail Blender collections; separately exported
LOD0/LOD1 GLBs; offline Workbench reference shots and SHA manifest. This is
NOT an integrated/drivable vehicle or completed Class-A automotive sculpt.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bezier_surface import tessellate
from vehicle_body_surface import (
    width_shoulder, arch_lower_boundary, body_surface_point, STATIONS,
    side_panel as sculpt_side, top_panel as sculpt_top,
    fascia as sculpt_fascia, wheel_liner as sculpt_liner,
    tire_cross_section as sculpt_tire, continuity_metrics,
)

import bpy
from mathutils import Vector, Matrix

# +Y is up, -Z is the front of the car; physical units are metres.
LENGTH = 4.38
WIDTH = 1.92
WHEELBASE = 2.71
AXLES = (-1.38, 1.33)
WHEEL_Y = 0.365
WHEEL_X = 0.805
RADIUS = 0.365

SOCKETS = {
    "WheelFL": (-WHEEL_X, WHEEL_Y, AXLES[0]),
    "WheelFR": ( WHEEL_X, WHEEL_Y, AXLES[0]),
    "WheelRL": (-WHEEL_X, WHEEL_Y, AXLES[1]),
    "WheelRR": ( WHEEL_X, WHEEL_Y, AXLES[1]),
    "SeatDriver": (-0.400, 0.62, 0.17),
    "SeatPassenger": (0.400, 0.62, 0.17),
    "CameraDriver": (-0.400, 1.12, 0.13),
    "DoorHingeL": (-0.78, 0.80, -0.53),
    "DoorHingeR": (0.78, 0.80, -0.53),
    "RoofStow": (0.0, 0.96, 0.85),
    "RoofPivotL": (-0.66, 0.95, 0.69),
    "RoofPivotR": (0.66, 0.95, 0.69),
    "HeadlampL": (-0.63, 0.83, -1.91),
    "HeadlampR": (0.63, 0.83, -1.91),
    "TaillampL": (-0.65, 0.80, 2.12),
    "TaillampR": (0.65, 0.80, 2.12),
    "AudioMotor": (0.0, 0.44, 1.27),
}
PALETTE = {
    "VesperPetrolBlue": ((0.020, 0.134, 0.160), 0.66, 0.24),
    "VesperCopper": ((0.48, 0.235, 0.085), 0.72, 0.31),
    "DarkComposite": ((0.021, 0.027, 0.032), 0.10, 0.64),
    "SoftTopStowed": ((0.044, 0.047, 0.057), 0.0, 0.93),
    "CabinLeather": ((0.095, 0.107, 0.124), 0.0, 0.79),
    "SatinAlloy": ((0.45, 0.51, 0.54), 0.89, 0.30),
    "TireRubber": ((0.016, 0.018, 0.021), 0.0, 0.94),
    "BrakeRotor": ((0.35, 0.38, 0.41), 0.86, 0.50),
    "BrakeCaliper": ((0.56, 0.20, 0.050), 0.48, 0.41),
    "Glazing": ((0.12, 0.24, 0.27), 0.0, 0.11),
    "LightWhite": ((0.67, 0.85, 0.94), 0.0, 0.17),
    "LightRed": ((0.51, 0.035, 0.045), 0.0, 0.16),
}
MATERIALS = {}
ACTIVE_COLLECTION = None


def collection(name):
    result=bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(result)
    return result


def material(name, rgb, metal=0.0, rough=0.5, alpha=1.0):
    m=bpy.data.materials.new(name)
    m.diffuse_color=(*rgb, alpha)
    m.use_nodes=True
    bsdf=next(n for n in m.node_tree.nodes if n.type=="BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value=(*rgb,alpha)
    bsdf.inputs["Metallic"].default_value=metal
    bsdf.inputs["Roughness"].default_value=rough
    bsdf.inputs["Alpha"].default_value=alpha
    if metal>0.1 and "Coat Weight" in bsdf.inputs and name=="VesperPetrolBlue":
        bsdf.inputs["Coat Weight"].default_value=0.48
        bsdf.inputs["Coat Roughness"].default_value=0.14
    if alpha < 1:
        if hasattr(m,"surface_render_method"):
            m.surface_render_method="DITHERED"
        elif hasattr(m,"blend_method"):
            m.blend_method="BLEND"
    if name in ("LightWhite","LightRed"):
        key="Emission Color" if "Emission Color" in bsdf.inputs else "Emission"
        if key in bsdf.inputs:
            bsdf.inputs[key].default_value=(*rgb,1)
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value=0.5
    return m


def attach(obj, name, mat, col=None):
    col=col or ACTIVE_COLLECTION
    obj.name=name
    for orig in list(obj.users_collection):
        orig.objects.unlink(obj)
    col.objects.link(obj)
    if mat is not None:
        obj.data.materials.append(MATERIALS[mat])
    return obj


def mesh(name, verts, faces, mat, col=None, smooth=True):
    data=bpy.data.meshes.new(name)
    data.from_pydata([tuple(v) for v in verts],[],[tuple(f) for f in faces])
    data.update()
    obj=bpy.data.objects.new(name,data)
    (col or ACTIVE_COLLECTION).objects.link(obj)
    obj.data.materials.append(MATERIALS[mat])
    for poly in data.polygons:
        poly.use_smooth=smooth
    # Reproducible provisional UV coordinates; not a production bake atlas.
    layer=data.uv_layers.new(name="UVMap")
    for p in data.polygons:
        for loop_idx in p.loop_indices:
            v=data.vertices[data.loops[loop_idx].vertex_index].co
            layer.data[loop_idx].uv=((v.x+1.25)/2.5,(v.z+2.4)/4.8)
    return obj


def box(name, loc, dims, mat, bevel=0.0, high=False):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj=attach(bpy.context.object,name,mat)
    obj.scale=dims
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        modifier=obj.modifiers.new("Engineered edge radii","BEVEL")
        # A bevel larger than thin-panel thickness creates subpixel sliver
        # triangles and malformed glTF. Bound radii by the narrowest dimension.
        modifier.width=min(bevel, min(dims)*0.16)
        modifier.segments=4 if high else 2
        if hasattr(modifier,"affect"):
            modifier.affect="EDGES"
        smooth=obj.modifiers.new("Weighted corner normals","WEIGHTED_NORMAL")
        smooth.keep_sharp=True
    return obj


def beam(name,a,b,radius,mat,high=False):
    a,b=Vector(a),Vector(b)
    direction=b-a
    if direction.length<=0.0001: raise ValueError("beam endpoints must differ")
    bpy.ops.mesh.primitive_cylinder_add(vertices=16 if high else 10,
                                       radius=radius,depth=direction.length,
                                       location=(a+b)*0.5)
    obj=attach(bpy.context.object,name,mat)
    obj.rotation_euler=direction.to_track_quat('Z','Y').to_euler()
    return obj


def ring(name, center, major, minor, mat, high=False, rotation=(0,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=42 if high else 20,
                                    minor_segments=12 if high else 7,
                                    location=center,rotation=rotation,
                                    major_radius=major,minor_radius=minor)
    return attach(bpy.context.object,name,mat)


def socket(name,location):
    ob=bpy.data.objects.new(name,None)
    ob.empty_display_type='ARROWS'
    ob.empty_display_size=.06
    ob.location=location
    ACTIVE_COLLECTION.objects.link(ob)
    return ob


def smooth_profile(z):
    """All exterior assemblies share the same original design stations."""
    return width_shoulder(z)


def wheel_arch_y(z):
    return arch_lower_boundary(z)


def panel(name,sign,z0,z1,steps,mat):
    """Sculpted multi-station flank with real cutout and rounded shoulders."""
    source=sculpt_side(z0,z1,sign,max(steps,16),12 if steps>30 else 7)
    return mesh(name,source.positions,source.faces,mat)


def bezier_deck(name,z0,z1,front,back,center_bulge,detail,mat):
    """Unified C1 Hermite sheet: camber, stamped creases and rear tonneau humps.

    Former independent half-patches were flat and did not fit side shoulder
    curves. Keep the legacy function signature for the authoring script.
    """
    source=sculpt_top(z0,z1,30 if detail>=20 else 16,
                      60 if detail>=20 else 28)
    return mesh(name,source.positions,source.faces,mat)


def _oval_lamp_band(name,x,z,scale_outer,scale_inner,outer_lift,inner_lift,
                    material_name,high=False):
    count=32 if high else 20
    vertices=[];faces=[]
    for radius,lift in ((scale_outer,outer_lift),(scale_inner,inner_lift)):
        for i in range(count):
            t=2*math.pi*i/count
            xx=x+.20*radius*math.cos(t)
            zz=z+.12*radius*math.sin(t)
            wx,_=width_shoulder(zz)
            yy=body_surface_point(zz,xx/wx)[1]+lift
            vertices.append((xx,yy,zz))
    for i in range(count):
        next_i=(i+1)%count
        faces.append((i,next_i,count+next_i,count+i))
    return mesh(name,vertices,faces,material_name)


def _oval_lamp_plate(name,x,z,radius,lift,material_name,high=False):
    count=32 if high else 20
    vertices=[]
    for i in range(count):
        t=2*math.pi*i/count
        xx=x+.20*radius*math.cos(t)
        zz=z+.12*radius*math.sin(t)
        wx,_=width_shoulder(zz)
        yy=body_surface_point(zz,xx/wx)[1]+lift
        vertices.append((xx,yy,zz))
    wx,_=width_shoulder(z)
    vertices.append((x,body_surface_point(z,x/wx)[1]+lift+.007,z))
    faces=[(i,(i+1)%count,count) for i in range(count)]
    return mesh(name,vertices,faces,material_name)


def lamp(name,x,z,y,mat,high=False,rear=False):
    """Manufacturable lamp pockets with fitted bezel, lens, LED light guides."""
    if rear:
        # Rear units are housed inside the convex tail fascia rather than
        # suspended off the old squared-off crash-cover slab.
        box(name+"_TailPocket",(x,.762,2.246),(.407,.095,.034),
            "DarkComposite",.018,high)
        box(name+"_RedLens",(x,.772,2.267),(.345,.045,.018),mat,.009,high)
        box(name+"_LightGuide",(x,.783,2.280),(.274,.010,.008),
            mat,.004,high)
        return
    _oval_lamp_band(name+"_RubberSeal",x,z,1.0,.86,.007,.010,
                    "DarkComposite",high)
    _oval_lamp_band(name+"_Reflector",x,z,.87,.63,.011,.013,
                    "SatinAlloy",high)
    _oval_lamp_plate(name+"_PolycarbonateLens",x,z,.81,.020,
                     "Glazing",high)
    # Three small real projector internals behind the front glazing.
    count=3 if high else 2
    for index in range(count):
        u=index-(count-1)/2
        xx=x+u*.069
        zz=z+.006
        wx,_=width_shoulder(zz)
        level=body_surface_point(zz,xx/wx)[1]
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=16 if high else 10,ring_count=8 if high else 6,
            location=(xx,level+.018,zz))
        obj=attach(bpy.context.object,name+"_Projector"+str(index),
                   "LightWhite")
        obj.scale=(.026,.006,.022)
    # Fitted edge DRL, not a detached billboard rectangle.
    count=15 if high else 9
    points=[]
    for i in range(count):
        t=math.pi*(.03+.94*i/(count-1))
        xx=x+.172*math.cos(t)
        zz=z-.092*math.sin(t)
        wx,_=width_shoulder(zz)
        yy=body_surface_point(zz,xx/wx)[1]+.025
        points.append((xx,yy,zz))
    for i in range(len(points)-1):
        beam(name+"_DRL"+str(i),points[i],points[i+1],.0045,mat,high)


def tire_and_brake(name,sign,axle,high=False):
    """Closed sidewalls, molded tread shoulder and actual exposed rim depth."""
    x=sign*WHEEL_X
    at=(x,WHEEL_Y,axle)
    tire=sculpt_tire(axle,x,56 if high else 32)
    mesh(name+"_ClosedTire",tire.positions,tire.faces,"TireRubber")
    ring(name+"_RimLip",(x+sign*.094,WHEEL_Y,axle),.232,.012,
         "SatinAlloy",high,(0,math.pi/2,0))
    # Rotor is recessed under the sculpted spoke plane.
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=40 if high else 24,radius=.246,depth=.025,
        location=(x-sign*.035,WHEEL_Y,axle),rotation=(0,math.pi/2,0))
    attach(bpy.context.object,name+"_Rotor","BrakeRotor")
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=40 if high else 24,radius=.092,depth=.135,
        location=at,rotation=(0,math.pi/2,0))
    attach(bpy.context.object,name+"_Hub","SatinAlloy")
    count=10 if high else 7
    for n in range(count):
        t=2*math.pi*n/count
        inner=(x+sign*.095,WHEEL_Y+.073*math.sin(t),axle+.073*math.cos(t))
        outer=(x+sign*.090,WHEEL_Y+.228*math.sin(t),axle+.228*math.cos(t))
        beam(name+"_Spoke"+str(n),inner,outer,.013 if high else .016,
             "SatinAlloy",high)
    box(name+"_Caliper",(x-sign*.041,WHEEL_Y+.12,axle-.19),
        (.105,.10,.090),"BrakeCaliper",.012,high)


def build_geometry(col,high,socket_prefix=''):
    global ACTIVE_COLLECTION
    ACTIVE_COLLECTION=col
    span=60 if high else 25
    for side,name in ((-1,"Left"),(1,"Right")):
        panel("FrontWing"+name,side,-2.13,-.73,span,"VesperPetrolBlue")
        panel("DoorSkin"+name,side,-.725,.69,span,"VesperPetrolBlue")
        panel("RearQuarter"+name,side,.695,2.12,span,"VesperPetrolBlue")
    bezier_deck("ForwardBonnet",-2.13,-.78,.785,.925,.060,24 if high else 10,"VesperPetrolBlue")
    bezier_deck("RearTonneau",.71,2.10,.923,.788,.043,24 if high else 10,"VesperPetrolBlue")
    # Front/rear fascia and sill structural components.
    box("FrontCrashCover",(0,.48,-2.13),(1.52,.35,.12),"VesperPetrolBlue",.09,high)
    box("FrontInlet",(0,.405,-2.203),(1.03,.105,.012),"DarkComposite",.030,high)
    box("RearCrashCover",(0,.45,2.095),(1.65,.39,.12),"VesperPetrolBlue",.075,high)
    box("RearVent",(0,.445,2.164),(1.28,.13,.022),"DarkComposite",.03,high)
    box("Underbody",(0,.33,0),(1.55,.14,3.92),"DarkComposite",.05,high)
    for side,name in ((-1,"L"),(1,"R")):
        box("Sill"+name,(side*.77,.33,0.0),(.12,.10,1.53),"DarkComposite",.025,high)
        box("DoorHandlePocket"+name,(side*.845,.862,-.17),
            (.018,.035,.18),"DarkComposite",.008,high)
        box("DoorHandle"+name,(side*.859,.866,-.17),
            (.025,.016,.126),"VesperCopper",.005,high)
        # Real forward aero blade, but no R9 body asset reuse.
        box("FrontLowerBlade"+name,(side*.67,.340,-2.05),(.31,.031,.32),
            "DarkComposite",.016,high)
        lamp("HeadLamp"+name,side*.622,-1.93,.83,"LightWhite",high)
        lamp("TailLamp"+name,side*.63,2.13,.786,"LightRed",high,rear=True)
    # Cabin: actually open above its side rails, not a painted roof.
    box("CabinTub",(0,.465,-.04),(1.46,.11,1.41),"DarkComposite",.065,high)
    box("CabinBackBulkhead",(0,.72,.67),(1.46,.52,.065),"DarkComposite",.040,high)
    box("Dashboard",(0,.855,-.68),(1.45,.205,.24),"DarkComposite",.055,high)
    box("DigitalCluster",(-.405,.938,-.771),(.30,.085,.008),
        "LightWhite",.012,high)
    box("CenterConsole",(0,.61,.04),(.23,.19,1.12),"DarkComposite",.05,high)
    box("ConsoleCopperSwitch",(0,.73,-.15),(.09,.024,.22),"VesperCopper",.015,high)
    for side,name in ((-1,"L"),(1,"R")):
        x=side*.397
        box("SeatCushion"+name,(x,.570,.13),(.53,.155,.61),"CabinLeather",.075,high)
        back=box("SeatBack"+name,(x,.824,.43),(.54,.52,.18),
                 "CabinLeather",.082,high)
        back.rotation_euler.x=-.11
        box("SeatHeadrest"+name,(x,1.045,.505),(.31,.16,.13),
            "CabinLeather",.050,high)
        beam("RollHoopUp"+name,(x-.165,.94,.74),(x-.132,1.205,.72),
             .027,"SatinAlloy",high)
        beam("RollHoopCrown"+name,(x-.132,1.205,.72),(x+.132,1.205,.72),
             .026,"SatinAlloy",high)
        beam("RollHoopDown"+name,(x+.132,1.205,.72),(x+.165,.94,.74),
             .027,"SatinAlloy",high)
    # Windshield is a real four-corner transparent pane with separately authored frame.
    corners=[(-.719,.954,-.823),(.719,.954,-.823),
             (.630,1.310,-.512),(-.630,1.310,-.512)]
    mesh("WindscreenPane",corners,[(0,1,2),(0,2,3)],"Glazing",smooth=False)
    for i,j in [(0,3),(3,2),(2,1),(1,0)]:
        beam("WindshieldFrame"+str(i),corners[i],corners[j],.022,
             "SatinAlloy",high)
    beam("WindshieldWiper",(-.46,.966,-.846),(.30,.987,-.838),.009,
         "DarkComposite")
    # Steering wheel's toroid remains visible, though not yet driving-animated.
    ring("SteeringWheel",(-.398,.879,-.485),.121,.011,
         "DarkComposite",high)
    beam("SteeringColumn",(-.398,.865,-.487),(-.398,.842,-.600),
         .018,"SatinAlloy",high)
    # Soft top is physically stowed, without pretending an animated roof is implemented.
    box("FoldedSoftTopCassette",(0,.925,.83),(1.23,.14,.31),
        "SoftTopStowed",.055,high)
    for sign,name in ((-1,"L"),(1,"R")):
        for z,label in zip(AXLES,("F","R")):
            tire_and_brake("Wheel"+label+name,sign,z,high)
    for name,location in SOCKETS.items():
        socket(socket_prefix+name,location)


def cameras_and_preview(preview_col):
    global ACTIVE_COLLECTION
    ACTIVE_COLLECTION=preview_col
    ground=box("PreviewGround",(0,0,-.045),(200,200,.075),"DarkComposite",0)
    # Render preview includes high-resolution *source* but not game LODs.
    camera=bpy.data.cameras.new("PreviewCamera")
    cam=bpy.data.objects.new("PreviewCamera",camera)
    preview_col.objects.link(cam)
    bpy.context.scene.camera=cam
    scene=bpy.context.scene
    scene.render.engine="BLENDER_WORKBENCH"
    scene.render.resolution_x=1152
    scene.render.resolution_y=720
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.display.shading.light="STUDIO"
    scene.display.shading.color_type="MATERIAL"
    scene.display.shading.show_cavity=True
    scene.display.shading.cavity_type="BOTH"
    scene.display.shading.curvature_ridge_factor=1.2
    scene.render.film_transparent=False
    scene.camera.data.type="ORTHO"
    scene.camera.data.ortho_scale=6.6
    return cam


def render_views(camera, output_dir):
    shots={
        "front_three_quarter":((5.7,3.3,-6.2),(0,.69,0)),
        "rear_three_quarter":((-5.7,3.1,6.2),(0,.69,0)),
        "profile":((6.0,2.5,.05),(0,.68,0)),
        "open_cockpit":((3.8,6.6,-2.1),(0,.68,0)),
    }
    for name,(eye,target) in shots.items():
        # Preview cameras are specified in game coordinates, transformed to
        # Blender's native Z-up world used by the editable source file.
        camera.location=(eye[0],-eye[2],eye[1])
        target_blender=(target[0],-target[2],target[1])
        direction=Vector(target_blender)-camera.location
        camera.rotation_euler=direction.to_track_quat("-Z","Y").to_euler()
        bpy.context.scene.render.filepath=str(output_dir/(name+".png"))
        bpy.ops.render.render(write_still=True)


def build(output_dir:Path,preview=True):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    global MATERIALS
    MATERIALS={name:material(name,*args) for name,args in PALETTE.items()}
    high=collection("MASTER__DETAIL__NONSHIPPING")
    low0=collection("GAME__LOD0")
    low1=collection("GAME__LOD1")
    build_geometry(high,True,'MASTER_')
    build_geometry(low0,False)
    # LOD1 begins with the same semantic parts and reduces complexity through
    # a decimation modifier for mesh-only components (do not modify socket empties).
    build_geometry(low1,False,'LOD1_')
    # Authoring geometry and sockets use NightGrid (+Y up, -Z forward);
    # Blender uses native +Z up. Rotate +90deg about X BEFORE saving/export.
    # The Blender glTF exporter converts this native basis to glTF +Y up,
    # restoring the original NightGrid model coordinates on import.
    to_blender=Matrix.Rotation(math.pi/2,4,"X")
    for part_collection in (high, low0, low1):
        for obj in part_collection.objects:
            obj.matrix_world=to_blender @ obj.matrix_world
    for ob in low1.objects:
        if ob.type=="MESH" and len(ob.data.polygons)>90:
            mod=ob.modifiers.new("distant mesh reduction","DECIMATE")
            mod.ratio=.55
    output_dir.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output_dir/"vesper_v2_master.blend"),compress=True)
    def export(selected_col,filename):
        bpy.ops.object.select_all(action="DESELECT")
        for obj in selected_col.objects:
            obj.select_set(True)
        meshes=[ob for ob in selected_col.objects if ob.type=="MESH"]
        if meshes:
            bpy.context.view_layer.objects.active=meshes[0]
        bpy.ops.export_scene.gltf(filepath=str(output_dir/filename),
            export_format="GLB",use_selection=True,export_apply=True,
            export_materials="EXPORT")
    export(low0,"vesper_v2_lod0.glb")
    # Blender enforces globally unique object names. Export each independent
    # LOD with the *same exact Godot socket contract*, never suffixed .001.
    for socket_name in SOCKETS:
        low0.objects["" + socket_name].name="LOD0_"+socket_name
        low1.objects["LOD1_"+socket_name].name=socket_name
    export(low1,"vesper_v2_lod1.glb")
    if preview:
        preview_col=collection("OFFLINE_PREVIEW_ONLY")
        camera=cameras_and_preview(preview_col)
        low0.hide_render=True
        low1.hide_render=True
        high.hide_render=False
        render_views(camera,output_dir)
    manifest={
        "id":"nightgrid.vesper_v2.original_roadster",
        "status":"design_study_nonplayable_not_aaa_approved",
        "source":"tools/vehicles/author_vesper_v2_blender.py",
        "blender":bpy.app.version_string,
        "unit":"metre","up":"+Y","forward":"-Z",
        "dimensions":{"length_m":LENGTH,"width_m":WIDTH,
                      "wheelbase_m":WHEELBASE},
        "seat_count":2,"roof":"stowed_prototype_only",
        "sockets":list(SOCKETS),
        "files":{},
        "evidence":"PNG files are offline Blender Workbench previews, NOT gameplay",
        "licence":"all authored meshes original to NightGrid; no outside car assets",
    }
    for file in output_dir.iterdir():
        if file.is_file() and file.name!="source.json":
            manifest["files"][file.name]={
                "sha256":hashlib.sha256(file.read_bytes()).hexdigest(),
                "bytes":file.stat().st_size,
            }
    (output_dir/"source.json").write_text(
        json.dumps(manifest,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    return manifest


def main():
    args=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir",required=True,type=Path)
    parser.add_argument("--skip-preview",action="store_true")
    opts=parser.parse_args(args)
    print(json.dumps(build(opts.output_dir,not opts.skip_preview),indent=2))


if __name__=="__main__":
    main()
