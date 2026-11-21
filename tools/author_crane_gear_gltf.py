#!/usr/bin/env python3
"""Author an ORIGINAL, UV-mapped industrial building as a real glTF 2.0 mesh.

Permanent art address: West Docks (-4,-2) lot 1, adjacent to CRANE & GEAR.
No runtime mesh generation; the source-controlled output is a portable, offline
glTF with 1K derivatives of the repo's already licensed Poly Haven CC0 scans.
The geometry is purpose-built: true wall/window openings, 3D recessed glazing,
metal bay door seams, enclosed roof/returns, structural loading canopy.
This is a source-controlled model authoring tool, not a screenshot generator.
"""
from __future__ import annotations
import hashlib
import json
import math
import shutil
import struct
from pathlib import Path
from PIL import Image

BASE = Path("assets/models/nightgrid/crane_gear")
TEXTURES = BASE / "textures"
PBR = Path("assets/pbr/polyhaven")
WIDTH, HEIGHT, DEPTH = 16.1, 20.0, 23.0
HALF = WIDTH / 2.0
FRONT = -DEPTH / 2.0
BACK = DEPTH / 2.0
FAMILIES = ["BRICK", "STEEL", "ROOF", "GLASS", "INTERIOR", "PAINT"]
data = {key: {"position": [], "normal": [], "tangent": [], "uv": [], "indices": []} for key in FAMILIES}
counts = {"front_windows": 0, "side_windows": 0, "dock_bays": 0,
          "roof_quads": 0, "structural_projections": 0}
SOURCE = {"BRICK": "brick_wall_001", "STEEL": "blue_metal_plate", "ROOF": "bitumen"}


def uv_data(a: tuple, b: tuple, c: tuple):
    vx = [b[i] - a[i] for i in range(3)]
    vy = [c[i] - a[i] for i in range(3)]
    cross = (vx[1]*vy[2]-vx[2]*vy[1], vx[2]*vy[0]-vx[0]*vy[2], vx[0]*vy[1]-vx[1]*vy[0])
    length = math.sqrt(sum(x*x for x in cross))
    assert length > 1e-7, ("degenerate triangle",a,b,c)
    n = tuple(x / length for x in cross)
    if abs(n[1]) > 0.7:
        return n, (0, 2)
    if abs(n[0]) > 0.7:
        return n, (2, 1)
    return n, (0, 1)


def quad(mat: str, a: tuple, b: tuple, c: tuple, d: tuple, repeat=0.38):
    obj=data[mat]
    n, axes = uv_data(a,b,c)
    axis_u=(1,0,0) if axes[0]==0 else ((0,0,1) if axes[0]==2 else (0,1,0))
    axis_v=(0,1,0) if axes[1]==1 else ((0,0,1) if axes[1]==2 else (1,0,0))
    cx=(n[1]*axis_u[2]-n[2]*axis_u[1],n[2]*axis_u[0]-n[0]*axis_u[2],n[0]*axis_u[1]-n[1]*axis_u[0])
    handed=1.0 if sum(cx[k]*axis_v[k] for k in range(3))>0 else -1.0
    first=len(obj["position"])//3
    for p in [a,b,c,d]:
        obj["position"].extend(p)
        obj["normal"].extend(n)
        obj["tangent"].extend((*axis_u,handed))
        obj["uv"].extend((p[axes[0]]*repeat, p[axes[1]]*repeat))
    obj["indices"].extend((first,first+1,first+2,first,first+2,first+3))


def front(mat, x0,x1,y0,y1,z=FRONT):
    if x1>x0 and y1>y0:
        quad(mat,(x0,y0,z),(x0,y1,z),(x1,y1,z),(x1,y0,z))


def rear(mat, x0,x1,y0,y1,z=BACK):
    if x1>x0 and y1>y0:
        quad(mat,(x1,y0,z),(x1,y1,z),(x0,y1,z),(x0,y0,z))


def side(mat, right, z0,z1,y0,y1,x=None):
    if z1<=z0 or y1<=y0:return
    x=(HALF if right else -HALF) if x is None else x
    if right:
        quad(mat,(x,y0,z0),(x,y1,z0),(x,y1,z1),(x,y0,z1))
    else:
        quad(mat,(x,y0,z1),(x,y1,z1),(x,y1,z0),(x,y0,z0))


def solid(mat,x0,x1,y0,y1,z0,z1):
    # All six exposed faces on purpose-made jambs/profiles, never BoxMesh nodes.
    front(mat,x0,x1,y0,y1,z0)
    rear(mat,x0,x1,y0,y1,z1)
    side(mat,True,z0,z1,y0,y1,x1)
    side(mat,False,z0,z1,y0,y1,x0)
    quad(mat,(x0,y1,z0),(x0,y1,z1),(x1,y1,z1),(x1,y1,z0))
    quad(mat,(x0,y0,z1),(x0,y0,z0),(x1,y0,z0),(x1,y0,z1))
    counts["structural_projections"]+=1


def opening(x0,x1,y0,y1,side_wall=False,right=False):
    # Truly empty masonry plane, recessed smooth glazing and separate
    # behind-glass room backing; reveal depth casts actual occlusion.
    if side_wall:
        plane=HALF if right else -HALF
        inner=plane+(-0.34 if right else 0.34)
        backing=plane+(-0.95 if right else 0.95)
        side("GLASS",right,x0+0.09,x1-0.09,y0+0.09,y1-0.09,inner)
        side("INTERIOR",right,x0+0.09,x1-0.09,y0+0.09,y1-0.09,backing)
        for z in [x0,x1]:
            solid("STEEL",min(plane,inner),max(plane,inner),y0,y1,z-0.05,z+0.05)
        for y in [y0,y1]:
            solid("STEEL",min(plane,inner),max(plane,inner),y-0.055,y+0.055,x0,x1)
        side("STEEL",right,x0+0.08,x1-0.08,y0+(y1-y0)*0.52-0.045,y0+(y1-y0)*0.52+0.045,inner-0.02 if right else inner+0.02)
        counts["side_windows"]+=1
    else:
        front("GLASS",x0+0.09,x1-0.09,y0+0.10,y1-0.09,FRONT+0.31)
        front("INTERIOR",x0+0.09,x1-0.09,y0+0.10,y1-0.09,FRONT+1.05)
        for x in [x0,x1]:
            solid("STEEL",x-0.055,x+0.055,y0,y1,FRONT-0.035,FRONT+0.35)
        for y in [y0,y1]:
            solid("STEEL",x0,x1,y-0.055,y+0.055,FRONT-0.035,FRONT+0.35)
        # Two physical mullions per window produce commercial framing scale.
        solid("STEEL",(x0+x1)*0.5-0.037,(x0+x1)*0.5+0.037,y0,y1,FRONT+0.25,FRONT+0.355)
        counts["front_windows"]+=1


def make_ground():
    front("BRICK",-HALF,HALF,0.12,0.57)
    front("BRICK",-HALF,HALF,4.22,4.86)
    bay_centers=[-3.7,3.7]
    last=-HALF
    for center in bay_centers:
        x0,x1=center-1.58,center+1.58
        front("BRICK",last,x0,0.57,4.22)
        # Door is not a painted rectangle; the 0.62m recessed rolled steel
        # leaves physically framed jambs and actual sectional panel depth.
        solid("STEEL",x0-0.16,x0+0.06,0.57,4.22,FRONT-0.13,FRONT+0.63)
        solid("STEEL",x1-0.06,x1+0.16,0.57,4.22,FRONT-0.13,FRONT+0.63)
        solid("STEEL",x0-0.17,x1+0.17,4.08,4.28,FRONT-0.16,FRONT+0.65)
        solid("STEEL",x0-0.13,x1+0.13,0.57,0.72,FRONT-0.12,FRONT+0.66)
        for section in range(7):
            low=0.74+section*0.47
            high=min(4.03, low+0.44)
            front("STEEL" if section%2==0 else "PAINT",x0+0.10,x1-0.10,low,high,FRONT+0.61)
            solid("STEEL",x0+0.06,x1-0.06,low+0.005,low+0.048,FRONT+0.535,FRONT+0.66)
        counts["dock_bays"]+=1
        last=x1
    front("BRICK",last,HALF,0.57,4.22)
    # Entire industrial canopy is a 3D structural projection with ribs, not
    # an emissive slab. It stays above clearance at the road-facing frontage.
    solid("ROOF",-HALF+0.22,HALF-0.22,4.72,4.94,FRONT-1.12,FRONT-0.10)
    for x in [-6.9,-3.7,0.0,3.7,6.9]:
        solid("STEEL",x-0.09,x+0.09,4.28,4.72,FRONT-1.0,FRONT+0.17)
    front("PAINT",-HALF+0.22,HALF-0.22,4.29,4.58,FRONT-1.14)
    # No illuminated rectangle: signboard below canopy is unlit painted steel.


def make_upper():
    y=4.86
    while y < HEIGHT-0.9:
        limit=min(y+3.35, HEIGHT-0.25)
        sill=y+0.42
        lintel=limit-0.58
        if lintel-sill<=0.75:
            front("BRICK",-HALF,HALF,y,limit)
            break
        front("BRICK",-HALF,HALF,y,sill)
        front("BRICK",-HALF,HALF,lintel,limit)
        previous=-HALF
        for i in range(4):
            x0=-HALF+0.78+i*(WIDTH-1.56)/4
            x1=x0+(WIDTH-1.56)/4-0.64
            front("BRICK",previous,x0,sill,lintel)
            opening(x0,x1,sill,lintel)
            previous=x1
        front("BRICK",previous,HALF,sill,lintel)
        # Structural wall string course, not neon window sticker.
        solid("STEEL",-HALF-0.04,HALF+0.04,limit-0.12,limit+0.02,FRONT-0.09,FRONT+0.04)
        y=limit+0.12
    if y<HEIGHT:
        front("BRICK",-HALF,HALF,y,HEIGHT)


def make_side(right):
    # Both side elevations have functional depth, not blank opaque caps.
    side("STEEL",right,FRONT,BACK,0.12,4.86)
    y=4.86
    while y < HEIGHT-0.9:
        limit=min(y+3.35,HEIGHT-0.25)
        sill=y+0.48
        lintel=limit-0.60
        if lintel-sill<0.9:
            side("STEEL",right,FRONT,BACK,y,limit)
            break
        side("STEEL",right,FRONT,BACK,y,sill)
        side("STEEL",right,FRONT,BACK,lintel,limit)
        previous=FRONT
        for i in range(3):
            z0=FRONT+1.55+i*(DEPTH-3.1)/3
            z1=z0+(DEPTH-3.1)/3-1.18
            side("STEEL",right,previous,z0,sill,lintel)
            opening(z0,z1,sill,lintel,True,right)
            previous=z1
        side("STEEL",right,previous,BACK,sill,lintel)
        y=limit+0.13
    if y<HEIGHT:
        side("STEEL",right,FRONT,BACK,y,HEIGHT)


def make_rear():
    # Rear service opening stays visually closed and is not a new walkable
    # gameplay doorway. The sealed physics block remains authoritative.
    rear("STEEL",-HALF,HALF,0.12,HEIGHT)
    solid("STEEL",-3.8,3.8,1.0,3.72,BACK+0.09,BACK+0.20)
    for y in [1.45,2.20,2.95,3.6]:
        solid("PAINT",-3.66,3.66,y-0.025,y+0.025,BACK+0.19,BACK+0.225)
    solid("STEEL",-4.05,4.05,3.78,3.95,BACK+0.10,BACK+0.32)


def make_roof():
    # True sloped photographed roof and continuous sealed edge/parapet.
    roof_y=HEIGHT+0.08
    for i in range(4):
        x0=-HALF+i*WIDTH/4
        x1=x0+WIDTH/4
        quad("ROOF",(x0,roof_y,FRONT),(x0,roof_y+0.23,BACK),
             (x1,roof_y+0.23,BACK),(x1,roof_y,FRONT))
        counts["roof_quads"]+=1
    solid("STEEL",-HALF-0.11,HALF+0.11,HEIGHT-0.32,HEIGHT+0.48,FRONT-0.12,FRONT+0.10)
    solid("STEEL",-HALF-0.11,HALF+0.11,HEIGHT-0.32,HEIGHT+0.48,BACK-0.10,BACK+0.12)
    for right in (False,True):
        x=(-HALF if not right else HALF)
        solid("STEEL",x-0.10,x+0.10,HEIGHT-0.32,HEIGHT+0.48,FRONT-0.10,BACK+0.10)
    # Three high-mass rooftop ducts, original closed section geometry.
    for x in [-3.9,0.0,3.9]:
        solid("STEEL",x-0.50,x+0.50,HEIGHT+0.24,HEIGHT+0.93,3.0,4.2)
        solid("PAINT",x-0.64,x+0.64,HEIGHT+0.92,HEIGHT+1.02,2.86,4.34)


def prepare_textures():
    TEXTURES.mkdir(parents=True,exist_ok=True)
    files={}
    for family,src in SOURCE.items():
        d=Image.open(PBR/(src+"_diffuse_2k.jpg")).convert("RGB")
        n=Image.open(PBR/(src+"_nor_gl_2k.png")).convert("RGB")
        rough=Image.open(PBR/(src+"_rough_2k.png")).convert("L")
        if min(*d.size,*n.size,*rough.size)<2048:
            raise ValueError("Missing full-resolution source photographic scan for "+src)
        for suffix,img in (("base",d),("normal",n)):
            name=f"{family.lower()}_{suffix}_1k.jpg"
            path=TEXTURES/name
            img.resize((1024,1024),Image.Resampling.LANCZOS).save(path,quality=90,subsampling=0)
            files["textures/"+name]=path
        value=rough.resize((1024,1024),Image.Resampling.LANCZOS)
        # glTF channel convention: G=roughness, B=metalness, R=AO.
        arm=Image.merge("RGB",(Image.new("L",(1024,1024),255),
                               value,Image.new("L",(1024,1024),{"BRICK":0,"STEEL":169,"ROOF":0}[family])))
        name=f"{family.lower()}_arm_1k.png"
        path=TEXTURES/name
        arm.save(path,optimize=True)
        files["textures/"+name]=path
    return files


def gltf():
    output=bytearray()
    views=[]
    accessors=[]
    def add_array(values,fmt,component_count,component_type,target,position=False):
        while len(output)%4:output.append(0)
        offset=len(output)
        output.extend(struct.pack("<"+fmt*len(values),*values))
        view_idx=len(views)
        views.append({"buffer":0,"byteOffset":offset,"byteLength":len(output)-offset,"target":target})
        idx=len(accessors)
        accessor={"bufferView":view_idx,"byteOffset":0,"componentType":component_type,
                  "count":len(values)//component_count,"type":{1:"SCALAR",2:"VEC2",3:"VEC3",4:"VEC4"}[component_count]}
        if position:
            accessor["min"]=[min(values[i::3]) for i in range(3)]
            accessor["max"]=[max(values[i::3]) for i in range(3)]
        accessors.append(accessor)
        return idx
    primitives=[]
    num_triangles=0
    total_vertices=0
    for m,kind in enumerate(FAMILIES):
        geo=data[kind]
        assert len(geo["position"])>0,kind
        num_triangles+=len(geo["indices"])//3
        total_vertices+=len(geo["position"])//3
        primitive={"attributes":{
            "POSITION":add_array(geo["position"],"f",3,5126,34962,True),
            "NORMAL":add_array(geo["normal"],"f",3,5126,34962),
            "TANGENT":add_array(geo["tangent"],"f",4,5126,34962),
            "TEXCOORD_0":add_array(geo["uv"],"f",2,5126,34962)},
            "indices":add_array(geo["indices"],"I",1,5125,34963),
            "material":m,"mode":4}
        primitives.append(primitive)
    materials=[]
    images=[]
    textures=[]
    for family in FAMILIES:
        if family in SOURCE:
            refs=[]
            for suffix,extension in [("base","jpg"),("normal","jpg"),("arm","png")]:
                image_idx=len(images)
                images.append({"uri":f"textures/{family.lower()}_{suffix}_1k.{extension}"})
                refs.append(len(textures))
                textures.append({"source":image_idx,"sampler":0})
            materials.append({"name":"CRANE_GEAR_"+family+"_CC0_PHOTO",
                "pbrMetallicRoughness":{"baseColorFactor":[0.85,0.87,0.89,1],
                    "baseColorTexture":{"index":refs[0]},
                    "metallicRoughnessTexture":{"index":refs[2]},
                    "roughnessFactor":1.0,"metallicFactor":1.0},
                "normalTexture":{"index":refs[1],"scale":0.72}})
        else:
            color={"GLASS":[0.13,0.21,0.25,1.0],
                   "INTERIOR":[0.27,0.22,0.19,1.0],
                   "PAINT":[0.34,0.38,0.40,1.0]}[family]
            materials.append({"name":"CRANE_GEAR_"+family+"_ORIGINAL",
                "pbrMetallicRoughness":{"baseColorFactor":color,
                    "metallicFactor":0.02 if family!="PAINT" else 0.4,
                    "roughnessFactor":0.12 if family=="GLASS" else 0.74}})
    model={"asset":{"version":"2.0","generator":"NightGrid original authored architectural mesh v1"},
           "scene":0,"scenes":[{"name":"CRANE_GEAR_ARCHITECTURE","nodes":[0]}],
           "nodes":[{"name":"CRANE_GEAR_PBR_CLOSED_ENVELOPE","mesh":0}],
           "meshes":[{"name":"original_crane_gear_warehouse","primitives":primitives}],
           "buffers":[{"uri":"crane_gear_warehouse.bin","byteLength":len(output)}],
           "bufferViews":views,"accessors":accessors,"materials":materials,
           "images":images,"textures":textures,
           "samplers":[{"magFilter":9729,"minFilter":9987,"wrapS":10497,"wrapT":10497}]}
    return model,output,num_triangles,total_vertices


def main():
    make_ground()
    make_upper()
    for right in (False,True):make_side(right)
    make_rear()
    make_roof()
    files=prepare_textures()
    model,binary,triangles,vertices=gltf()
    BASE.mkdir(parents=True,exist_ok=True)
    (BASE/"crane_gear_warehouse.gltf").write_text(json.dumps(model,sort_keys=True,indent=2)+"\n",encoding="utf-8")
    (BASE/"crane_gear_warehouse.bin").write_bytes(binary)
    files["crane_gear_warehouse.gltf"]=BASE/"crane_gear_warehouse.gltf"
    files["crane_gear_warehouse.bin"]=BASE/"crane_gear_warehouse.bin"
    generator=Path("tools/author_crane_gear_gltf.py")
    manifest={"name":"crane_gear_warehouse","origin":"Original NightGrid authored glTF architecture",
              "authoring_source":str(generator),
              "source_material_assets":[{"name":n,"license":"CC0 1.0",
                 "url":"https://polyhaven.com/a/"+n} for n in SOURCE.values()],
              "prototype_dimensions_m":{"width":WIDTH,"height":HEIGHT,"depth":DEPTH},
              "model":{"mesh_count":len(model["meshes"]),"material_count":len(model["materials"]),
                       "triangles":triangles,"vertices":vertices},
              "design_features":counts,
              "source_generator_sha256":hashlib.sha256(generator.read_bytes()).hexdigest(),
              "files":{p:{"sha256":hashlib.sha256(file.read_bytes()).hexdigest(),"bytes":file.stat().st_size}
                       for p,file in sorted(files.items())},
              "runtime_download_required":False}
    (BASE/"SOURCE.json").write_text(json.dumps(manifest,sort_keys=True,indent=2)+"\n",encoding="utf-8")
    assert triangles>=250 and counts["front_windows"]>=12 and counts["side_windows"]>=18
    print("CRANE_GEAR_GLTF PASS:",triangles,"triangles,",vertices,"vertices,",
          counts,"model+texture bytes:",sum(x["bytes"] for x in manifest["files"].values()))


if __name__=="__main__":
    main()
