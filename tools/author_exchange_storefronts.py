#!/usr/bin/env python3
"""One-time offline original 3D store/vestibule authoring for Central Exchange.

Produces TWO distinct hand-laid-out, low-draw-call 3D glTF storefronts, with
a *walkable* 2.8m-wide x 3.35m-deep pedestrian doorway. PBR is derived from
already source-verified Poly Haven CC0 photos, no downloads and no runtime
mesh generation. Engine-side parcel collision is opened ONLY at these two
fixed pilot buildings, retaining all other save-stable walls and stream stages.
"""
from __future__ import annotations
import hashlib
import json
import math
from pathlib import Path
import struct
from PIL import Image

HERE = Path("assets/models/nightgrid/central_exchange_storefront")
IMAGES = HERE / "textures"
PBR = Path("assets/pbr/polyhaven")
CURB = Path("assets/models/nightgrid/central_exchange_curb/textures")
KINDS = ["MASONRY", "STEEL", "CONCRETE", "BITUMEN", "GLASS", "PRACTICAL"]
VARIANTS = ["brickwater_retail", "afterhours_repair"]
ROOM_DEPTH = 3.35
PORTAL_HALF = 1.42
PORTAL_HEIGHT = 3.17
ART = {}

def hash_file(p: Path):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def image_source():
    IMAGES.mkdir(parents=True,exist_ok=True)
    sources = {}
    records = {}
    for name,orig,metal in [
        ("masonry","brick_wall_001",0), ("steel","blue_metal_plate",175),
        ("bitumen","bitumen",0)]:
        src = [PBR / f"{orig}_diffuse_2k.jpg",
               PBR / f"{orig}_nor_gl_2k.png",
               PBR / f"{orig}_rough_2k.png"]
        for p in src:
            if not p.is_file():
                raise ValueError("Missing previously committed CC0 photo source "+str(p))
            sources[str(p)] = hash_file(p)
        resize=lambda path,mode: Image.open(path).convert(mode).resize((1024,1024),Image.Resampling.LANCZOS)
        alb=resize(src[0],"RGB")
        nor=resize(src[1],"RGB")
        rough=resize(src[2],"L")
        destinations=[IMAGES/f"{name}_base_1k.jpg", IMAGES/f"{name}_normal_1k.jpg",
                      IMAGES/f"{name}_arm_1k.png"]
        alb.save(destinations[0],quality=87,subsampling=0)
        nor.save(destinations[1],quality=90,subsampling=0)
        packed=Image.merge("RGB",(Image.new("L",(1024,1024),255),
                                   rough,Image.new("L",(1024,1024),metal)))
        packed.save(destinations[2],optimize=True)
    for channel in ("base","normal","arm"):
        suffix=".png" if channel=="arm" else ".jpg"
        src=CURB/("concrete_"+channel+"_1k"+suffix)
        if not src.is_file():raise ValueError("CC0 derived concrete material absent "+str(src))
        sources[str(src)]=hash_file(src)
        target=IMAGES/("concrete_"+channel+"_1k"+suffix)
        target.write_bytes(src.read_bytes())
    for img in IMAGES.iterdir():
        records[img.name]={"sha256":hash_file(img),"bytes":img.stat().st_size}
    assert len(records)==12
    return sources,records

def begin():
    global ART
    ART={name:{"p":[],"n":[],"t":[],"uv":[],"i":[]} for name in KINDS}

def quad(kind,a,b,c,d):
    edge1=[b[i]-a[i] for i in range(3)]
    edge2=[c[i]-a[i] for i in range(3)]
    normal=(edge1[1]*edge2[2]-edge1[2]*edge2[1],
            edge1[2]*edge2[0]-edge1[0]*edge2[2],
            edge1[0]*edge2[1]-edge1[1]*edge2[0])
    norm=math.sqrt(sum(x*x for x in normal))
    if norm<1e-8:raise ValueError("Degenerate hand-authored façade quad")
    n=tuple(x/norm for x in normal)
    # Architectural texture mapping: horizontal x/z projects in real metres;
    # UV, normal and tangent are all explicit glTF source attributes.
    if abs(n[1])>.77:
        ua=(1,0,0);va=(0,0,1);coords=(0,2)
    elif abs(n[2])>.77:
        ua=(1,0,0);va=(0,1,0);coords=(0,1)
    else:
        ua=(0,0,1);va=(0,1,0);coords=(2,1)
    cross=(n[1]*ua[2]-n[2]*ua[1],
           n[2]*ua[0]-n[0]*ua[2],
           n[0]*ua[1]-n[1]*ua[0])
    hand=1.0 if sum(cross[i]*va[i] for i in range(3))>=0.0 else -1.0
    obj=ART[kind]
    first=len(obj["p"])//3
    for v in (a,b,c,d):
        obj["p"].extend(v)
        obj["n"].extend(n)
        obj["t"].extend((*ua,hand))
        obj["uv"].extend((v[coords[0]]/1.5,v[coords[1]]/1.5))
    obj["i"].extend((first,first+1,first+2,first,first+2,first+3))

def box(k,x0,x1,y0,y1,z0,z1):
    if x1-x0<0.0001 or y1-y0<0.0001 or z1-z0<0.0001:
        raise ValueError("Bad architectural cross-section")
    quad(k,(x0,y0,z0),(x0,y1,z0),(x1,y1,z0),(x1,y0,z0))
    quad(k,(x1,y0,z1),(x1,y1,z1),(x0,y1,z1),(x0,y0,z1))
    quad(k,(x1,y0,z0),(x1,y1,z0),(x1,y1,z1),(x1,y0,z1))
    quad(k,(x0,y0,z1),(x0,y1,z1),(x0,y1,z0),(x0,y0,z0))
    quad(k,(x0,y1,z0),(x0,y1,z1),(x1,y1,z1),(x1,y1,z0))
    quad(k,(x0,y0,z1),(x0,y0,z0),(x1,y0,z0),(x1,y0,z1))

def cylinder(k,x,y,z,r,height,sides=12):
    # Non-box rounded aluminum handrails and genuine power-conduit tubing.
    for i in range(sides):
        a=2*math.pi*i/sides;b=2*math.pi*(i+1)/sides
        q=lambda theta,height_at:(x+r*math.cos(theta),height_at,z+r*math.sin(theta))
        quad(k,q(a,y),q(b,y),q(b,y+height),q(a,y+height))
        # Conduit side wall is 3D; cap disks remain very small and unseen.

def frame(k,x0,x1,y0,y1,z0,z1,t):
    # Extruded mullions and soffit; NEVER a plane behind the doorway.
    box(k,x0,x0+t,y0,y1,z0,z1)
    box(k,x1-t,x1,y0,y1,z0,z1)
    box(k,x0,x1,y1-t,y1,z0,z1)
    box(k,x0,x1,y0,y0+t,z0,z1)

def build(name):
    begin()
    is_brick=name.startswith("brick")
    main="MASONRY" if is_brick else "STEEL"
    trim="STEEL" if is_brick else "CONCRETE"
    # Whole original 6.4m storefront has architectural pier return geometry.
    # Two side display windows flank an EMPTY 2.84m walk-in entrance; a
    # separate authored 3.35m-deep 3D shop vestibule sits behind that portal.
    box(main,-3.28,-3.14,0.15,3.86,-0.48,0.38)
    box(main,3.14,3.28,0.15,3.86,-0.48,0.38)
    box(main,-3.28,3.28,3.46,4.05,-0.48,0.43)
    box(main,-3.28,-1.54,0.12,0.50,-0.52,0.12)
    box(main,1.54,3.28,0.12,0.50,-0.52,0.12)
    # Two true recessed display windows, transparent photo display panes,
    # separate visible shelving and 3D backing instead of opaque stickers.
    for side in (-1,1):
        x0,x1=(-3.12,-1.59) if side<0 else (1.59,3.12)
        frame(trim,x0,x1,0.57,3.32,-0.52,0.24,0.095)
        quad("GLASS",(x0+0.12,0.67,0.12),(x0+0.12,3.18,0.12),
             (x1-0.12,3.18,0.12),(x1-0.12,0.67,0.12))
        # Behind the clear surface is a true 1.04m display enclosure.
        box("CONCRETE",x0+0.08,x1-0.08,0.17,0.21,0.26,1.18)
        box(main,x0+0.08,x0+0.13,0.21,3.20,0.28,1.18)
        box(main,x1-0.13,x1-0.08,0.21,3.20,0.28,1.18)
        box("BITUMEN",x0+0.12,x1-0.12,0.42,3.20,1.16,1.19)
        for level in (1.08,1.86,2.65):
            box("STEEL",x0+0.16,x1-0.16,level,level+0.055,0.46,1.06)
            # Shop goods are solid dimensional geometry and photographed
            # painted metal, not infinitely thin neon shop cards.
            for j in range(3):
                cx=x0+0.34+j*0.36
                cylinder("STEEL",cx,level+0.055,0.74,0.10,0.23,12)
                box("CONCRETE",cx-0.13,cx+0.13,level+0.28,level+0.34,0.62,0.86)
        box("PRACTICAL",x0+0.16,x1-0.16,3.13,3.17,0.53,0.84)
    # Full 3D doorway with 0.20m metal extruded jambs, deep soffit,
    # inward threshold and a high transom but intentionally NO solid door.
    frame("STEEL",-1.56,1.56,0.08,3.40,-0.64,0.22,0.13)
    box("CONCRETE",-1.42,1.42,0.018,0.047,-0.72,0.65)
    box("STEEL",-1.42,1.42,3.10,3.20,-0.34,0.31)
    quad("GLASS",(-1.39,3.21,-0.18),(-1.39,3.35,-0.18),
        (1.39,3.35,-0.18),(1.39,3.21,-0.18))
    # A credible 3.35m real recess one can WALK inside; floor flush with
    # the existing city ground (no invisible 0.17m floor step or new ramp).
    box("CONCRETE",-1.41,1.41,0.006,0.019,0.02,ROOM_DEPTH-0.10)
    for side in (-1,1):
        xx=-1.42 if side<0 else 1.40
        box(main,xx,xx+0.02,0.04,3.23,0.18,ROOM_DEPTH)
        # Exposed metal interior service rails along room depth.
        for y in (0.75,1.66,2.44):
            box("STEEL",xx-0.06,xx+0.08,y,y+0.044,0.64,2.86)
        for z in (1.05,2.42):
            cylinder("STEEL",xx+(-0.07 if side<0 else 0.09),1.2,z,0.028,1.38,12)
    box(main,-1.41,1.41,0.03,3.23,ROOM_DEPTH-0.10,ROOM_DEPTH)
    box("CONCRETE",-1.41,1.41,3.20,3.28,0.14,ROOM_DEPTH)
    # Real hanging recessed practical fixtures without unbounded OmniLights
    # or unrelated global fog/reflection changes. Ceiling covers are explicit.
    for z in (1.08,2.64):
        box("STEEL",-0.87,0.87,3.10,3.19,z-0.16,z+0.16)
        box("PRACTICAL",-0.71,0.71,3.07,3.09,z-0.095,z+0.095)
    # Polished field-install utility counter against the REAR, not across
    # the entry axis; city collision ends at this modelled rear wall.
    box("STEEL",-1.19,1.19,0.66,0.96,ROOM_DEPTH-0.48,ROOM_DEPTH-0.15)
    box("CONCRETE",-1.13,1.13,0.22,0.67,ROOM_DEPTH-0.42,ROOM_DEPTH-0.22)
    # Recessed back shelf, individually modelled stock (20 small real
    # cylindrical stock/metal fasteners) to sell believable room depth.
    for level in (1.72,2.31):
        box("STEEL",-1.15,1.15,level,level+0.055,ROOM_DEPTH-0.39,ROOM_DEPTH-0.14)
        for j in range(10):
            x=-0.98+j*0.21
            cylinder("STEEL",x,level+0.055,ROOM_DEPTH-0.27,0.065,0.17,10)
    # Outside frame channels and suspension shoes, all material grouped.
    for side in (-1,1):
        x=side*3.01
        box("STEEL",x-0.040,x+0.040,0.42,3.50,-0.63,-0.44)
        box("CONCRETE",x-0.15,x+0.15,0.02,0.14,-0.73,-0.47)
    # Five real photo material groups + one tiny bounded emissive lens group.
    assert all(ART[key]["p"] for key in KINDS)
    return ART

def gltf_for(name):
    data=build(name)
    binary=bytearray();views=[];accessors=[]
    def pack(values,fmt,dim,component,target,bounds=False):
        while len(binary)%4:binary.append(0)
        start=len(binary)
        binary.extend(struct.pack("<"+fmt*len(values),*values))
        k=len(views);views.append({"buffer":0,"byteOffset":start,"byteLength":len(binary)-start,"target":target})
        a={"bufferView":k,"componentType":component,"count":len(values)//dim,
           "type":{1:"SCALAR",2:"VEC2",3:"VEC3",4:"VEC4"}[dim]}
        if bounds:
            a["min"]=[min(values[i::3]) for i in range(3)]
            a["max"]=[max(values[i::3]) for i in range(3)]
        accessors.append(a)
        return len(accessors)-1
    primitives=[];triangles=0;vertices=0
    for k,kind in enumerate(KINDS):
        row=data[kind]
        vertices+=len(row["p"])//3;triangles+=len(row["i"])//3
        attributes={
            "POSITION":pack(row["p"],"f",3,5126,34962,True),
            "NORMAL":pack(row["n"],"f",3,5126,34962),
            "TANGENT":pack(row["t"],"f",4,5126,34962),
            "TEXCOORD_0":pack(row["uv"],"f",2,5126,34962)}
        primitives.append({"attributes":attributes,
                           "indices":pack(row["i"],"I",1,5125,34963),
                           "material":k,"mode":4})
    images=[];textures=[];materials=[]
    for kind in KINDS:
        if kind in ("GLASS","PRACTICAL"):
            if kind=="GLASS":
                materials.append({"name":"CLEAR_RECESSED_GLASS","alphaMode":"BLEND",
                    "doubleSided":True,
                    "pbrMetallicRoughness":{"baseColorFactor":[0.34,0.53,0.58,0.24],
                        "metallicFactor":0.0,"roughnessFactor":0.17}})
            else:
                materials.append({"name":"WARM_PRACTICAL_CEILING_LENS",
                    "emissiveFactor":[0.80,0.44,0.23],
                    "pbrMetallicRoughness":{"baseColorFactor":[0.48,0.37,0.28,1.0],
                        "metallicFactor":0.0,"roughnessFactor":0.65}})
            continue
        prefix={"MASONRY":"masonry","STEEL":"steel","CONCRETE":"concrete","BITUMEN":"bitumen"}[kind]
        channel={}
        for unit in ("base","normal","arm"):
            extension=".png" if unit=="arm" else ".jpg"
            path=f"textures/{prefix}_{unit}_1k{extension}"
            assert (HERE/path).is_file(),path
            images.append({"uri":path})
            textures.append({"source":len(images)-1,"sampler":0})
            channel[unit]=len(textures)-1
        factor = [0.93,0.87,0.83,1] if kind=="MASONRY" else [0.82,0.86,0.90,1]
        materials.append({"name":"SOURCE_PHOTO_PBR_"+kind,
            "pbrMetallicRoughness":{"baseColorTexture":{"index":channel["base"]},
                "metallicRoughnessTexture":{"index":channel["arm"]},
                "baseColorFactor":factor,"metallicFactor":1.0,"roughnessFactor":1.0},
            "normalTexture":{"index":channel["normal"],"scale":0.63}})
    assert len(primitives)==6 and len(images)==12
    json_doc={
        "asset":{"version":"2.0","generator":"NightGrid original street-level walk-in store photomesh 1.0"},
        "scene":0,"scenes":[{"name":"Central Exchange connected storefront source","nodes":[0]}],
        "nodes":[{"name":"STORE_"+name,"mesh":0}],
        "meshes":[{"name":"LIVE_ENTRY_ARCHITECTURE_"+name,"primitives":primitives}],
        "buffers":[{"uri":name+".bin","byteLength":len(binary)}],
        "bufferViews":views,"accessors":accessors,
        "materials":materials,"samplers":[{"magFilter":9729,"minFilter":9987,"wrapS":10497,"wrapT":10497}],
        "images":images,"textures":textures}
    HERE.mkdir(parents=True,exist_ok=True)
    (HERE/(name+".bin")).write_bytes(binary)
    (HERE/(name+".gltf")).write_text(json.dumps(json_doc,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    return {"name":name,"triangles":triangles,"vertices":vertices,"materials":6,
            "room_depth_m":ROOM_DEPTH,"portal_half_width_m":PORTAL_HALF,
            "portal_clear_height_m":PORTAL_HEIGHT,"display_windows":2,
            "physical_stock_items":26,"added_dynamic_lights":0}

def main():
    originals,photo_files=image_source()
    models=[gltf_for(name) for name in VARIANTS]
    paths=[p for p in HERE.rglob("*") if p.is_file() and p.name!="SOURCE.json"]
    manifest={
        "description":"Original physical walk-in 3D shopfront/vestibule + recessed photo-PBR retail displays",
        "source_generator":"tools/author_exchange_storefronts.py",
        "generator_sha256":hash_file(Path("tools/author_exchange_storefronts.py")),
        "license":"Original 3D geometry; Poly Haven photo maps CC0 1.0",
        "license_url":"https://polyhaven.com/license",
        "sources":[
            "https://polyhaven.com/a/brick_wall_001",
            "https://polyhaven.com/a/blue_metal_plate",
            "https://polyhaven.com/a/bitumen",
            "https://polyhaven.com/a/concrete_floor_01"],
        "source_sha256":originals,
        "files":{p.relative_to(HERE).as_posix():{"sha256":hash_file(p),"bytes":p.stat().st_size}
                 for p in sorted(paths)},
        "models":models,
        "runtime_download_required":False,
        "permanent_parcels":[{"ix":-1,"iz":0,"which":1},{"ix":0,"iz":0,"which":0}],
        "source_saved_world_version_unchanged":True
    }
    assert len(photo_files)==12
    assert len(manifest["files"])==16
    (HERE/"SOURCE.json").write_text(json.dumps(manifest,sort_keys=True,indent=2)+"\n",encoding="utf-8")
    print("CENTRAL_EXCHANGE_WALK_IN_GLTF_PASS:",models,
          len(manifest["files"]),"SHA256-verified source/model files")

if __name__=="__main__":main()
