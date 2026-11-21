#!/usr/bin/env python3
"""Author a single production 36m street-trim module in two mirrored glTF variants.

Only run once on a restricted art branch. Real Poly Haven CC0 photographed
weathered concrete is fetched from its OFFICIAL 1K glTF source with MD5 checks;
existing repo CC0 steel/bitumen scans supply original PBR material families.
The original metal drainage slots, rolled curb cross-section and concrete
expansion joints are modeled as true UV/tangent-bearing triangles; the
production game imports the pinned offline static glTFs and never runs this.
"""
from __future__ import annotations
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import struct
import urllib.parse
import urllib.request
from PIL import Image

ASSET = "concrete_floor_01"
OUT = Path("assets/models/nightgrid/central_exchange_curb")
TEX = OUT / "textures"
SOURCE = Path("assets/pbr/polyhaven")
HOSTS = {"api.polyhaven.com", "dl.polyhaven.org"}
COLORS = ("CONCRETE", "STEEL", "BITUMEN")
DATA = {}

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def fetch(url, limit=18000000):
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.hostname not in HOSTS:
        raise ValueError("Not an official HTTPS Poly Haven source: " + url)
    request = urllib.request.Request(url, headers={"User-Agent": "NightGrid-CC0-curb-author/1.0"})
    with urllib.request.urlopen(request, timeout=90) as response:
        target = urllib.parse.urlparse(response.geturl())
        if target.scheme != "https" or target.hostname not in HOSTS:
            raise ValueError("Redirect outside official Poly Haven hosts")
        data = response.read(limit+1)
    if not data or len(data) > limit:
        raise ValueError("Invalid official source byte size")
    return data

def source_image_set():
    TEX.mkdir(parents=True,exist_ok=True)
    api = "https://api.polyhaven.com/files/" + ASSET
    listing = json.loads(fetch(api,8000000))
    item = listing.get("gltf",{}).get("1k",{}).get("gltf")
    if not item or not item.get("url"):
        raise ValueError("No official 1k glTF for weathered concrete photo")
    src = fetch(item["url"])
    if item.get("md5") and hashlib.md5(src).hexdigest()!=item["md5"].lower():
        raise ValueError("Upstream glTF MD5 mismatch")
    gltf = json.loads(src)
    if gltf.get("asset",{}).get("version")!="2.0":
        raise ValueError("Upstream photographic material not glTF 2.0")
    deps = item.get("include",{})
    if isinstance(deps,list):
        entries={str(x.get("name") or urllib.parse.urlparse(x["url"]).path.rsplit("/",1)[-1]):x for x in deps}
    elif isinstance(deps,dict):
        entries=deps
    else:
        raise ValueError("Unexpected Poly Haven source dependency list")
    material=gltf["materials"][0]
    rough=material["pbrMetallicRoughness"]
    specs={"base":rough["baseColorTexture"]["index"],
           "arm":rough["metallicRoughnessTexture"]["index"],
           "normal":material["normalTexture"]["index"]}
    source_provenance={"asset":ASSET,"api":api,"original_gltf":item["url"],"license":"CC0 1.0","texture_sources":{}}
    for channel,index in specs.items():
        uri=gltf["images"][gltf["textures"][index]["source"]]["uri"]
        rel=PurePosixPath(uri)
        if rel.is_absolute() or ".." in rel.parts or not rel.parts:
            raise ValueError("Unsafe texture URI from official glTF")
        info=entries.get(uri) or entries.get(rel.name)
        if not isinstance(info,dict) or not info.get("url"):
            raise ValueError("Official concrete scan missing dependent texture: "+uri)
        data=fetch(info["url"])
        if info.get("md5") and hashlib.md5(data).hexdigest()!=info["md5"].lower():
            raise ValueError("Official photo MD5 mismatch "+uri)
        if info.get("size") is not None and len(data)!=int(info["size"]):
            raise ValueError("Official photo byte count mismatch "+uri)
        suffix=Path(uri).suffix.lower()
        if suffix not in (".jpg",".jpeg",".png"):
            raise ValueError("Unsupported photographed texture file "+uri)
        if channel == "arm":
            # Upstream maps this grayscale ROUGH texture as a source PBR
            # input. glTF requires channel G=roughness and B=metalness:
            # copying grayscale unchanged wrongly makes concrete metallic.
            from io import BytesIO
            for outdated in TEX.glob("concrete_arm_1k.*"):
                outdated.unlink()
            dest=TEX/"concrete_arm_1k.png"
            rough_photo=Image.open(BytesIO(data)).convert("L")
            if rough_photo.size != (1024,1024):
                raise ValueError("Expected official 1K concrete roughness photo")
            packed=Image.merge("RGB", (Image.new("L",rough_photo.size,255),
                                      rough_photo, Image.new("L",rough_photo.size,0)))
            packed.save(dest,optimize=True)
        else:
            dest=TEX/("concrete_"+channel+"_1k"+suffix)
            dest.write_bytes(data)
        source_provenance["texture_sources"][dest.name]={"url":info["url"],
            "source_sha256":hashlib.sha256(data).hexdigest(),
            "derived_sha256":digest(dest),
            "source_md5":str(info.get("md5","")).lower(),
            "source_bytes":len(data),"derived_bytes":dest.stat().st_size}
    return source_provenance

def existing_material(kind, origin):
    # These 2K files already have their original Poly Haven source audit in
    # assets/pbr/polyhaven/SOURCE.json; do not download or replace them.
    originals=[SOURCE/(origin+"_diffuse_2k.jpg"),SOURCE/(origin+"_nor_gl_2k.png"),
               SOURCE/(origin+"_rough_2k.png")]
    if any(not p.is_file() for p in originals):
        raise ValueError("Missing existing CC0 photo scan "+origin)
    photo=Image.open(originals[0]).convert("RGB").resize((1024,1024),Image.Resampling.LANCZOS)
    normal=Image.open(originals[1]).convert("RGB").resize((1024,1024),Image.Resampling.LANCZOS)
    rough=Image.open(originals[2]).convert("L").resize((1024,1024),Image.Resampling.LANCZOS)
    base=TEX/(kind.lower()+"_base_1k.jpg")
    nor=TEX/(kind.lower()+"_normal_1k.jpg")
    arm=TEX/(kind.lower()+"_arm_1k.png")
    photo.save(base,quality=88,subsampling=0)
    normal.save(nor,quality=88,subsampling=0)
    # glTF metallic roughness: blue=metallic and green=roughness; red=AO.
    mat=Image.merge("RGB",(Image.new("L",(1024,1024),255),rough,
                           Image.new("L",(1024,1024),175 if kind=="STEEL" else 0)))
    mat.save(arm,optimize=True)
    return {p.name:{"sha256":digest(p),"bytes":p.stat().st_size} for p in [base,nor,arm]}

def begin():
    global DATA
    DATA={color:{"p":[],"n":[],"t":[],"uv":[],"i":[]} for color in COLORS}

def quad(kind,a,b,c,d,sign=1):
    # Faces originally authored in outward CCW. Mirrored cross-sections need
    # reverse winding to keep front/back culling and tangent handedness valid.
    seq=[a,b,c,d] if sign>0 else [a,d,c,b]
    x,y,z=seq[:3]
    u=[y[k]-x[k] for k in range(3)]
    v=[z[k]-x[k] for k in range(3)]
    n=(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])
    size=math.sqrt(sum(a*a for a in n))
    if size<1e-7:raise ValueError("Degenerate authored mesh face")
    n=tuple(a/size for a in n)
    # UV dominant tangent axes. For vertical curb faces, U follows the length
    # Z of the road, V follows the cross-sectional coordinate.
    if abs(n[1])>.75:
        ax=(2,0)
    elif abs(n[2])>.75:
        ax=(0,1)
    else:
        ax=(2,1)
    u_axis=[(0,0,1),(1,0,0),(0,1,0)][0] if ax[0]==2 else ((1,0,0) if ax[0]==0 else (0,1,0))
    v_axis=(1,0,0) if ax[1]==0 else ((0,1,0) if ax[1]==1 else (0,0,1))
    cross=(n[1]*u_axis[2]-n[2]*u_axis[1],n[2]*u_axis[0]-n[0]*u_axis[2],n[0]*u_axis[1]-n[1]*u_axis[0])
    handed=1.0 if sum(cross[i]*v_axis[i] for i in range(3))>=0 else -1.0
    obj=DATA[kind]
    first=len(obj["p"])//3
    for point in seq:
        obj["p"].extend(point)
        obj["n"].extend(n)
        obj["t"].extend((*u_axis,handed))
        obj["uv"].extend((point[ax[0]]/2.0,point[ax[1]]/2.0))
    obj["i"].extend((first,first+1,first+2,first,first+2,first+3))

def block(kind,x0,x1,y0,y1,z0,z1,sign):
    # Six full planar sides for real steel grates and sidewalk slabs, no BoxMesh.
    pt=lambda x,y,z:(x*sign,y,z)
    quad(kind,pt(x0,y0,z0),pt(x0,y1,z0),pt(x1,y1,z0),pt(x1,y0,z0),sign)
    quad(kind,pt(x1,y0,z1),pt(x1,y1,z1),pt(x0,y1,z1),pt(x0,y0,z1),sign)
    quad(kind,pt(x1,y0,z0),pt(x1,y1,z0),pt(x1,y1,z1),pt(x1,y0,z1),sign)
    quad(kind,pt(x0,y0,z1),pt(x0,y1,z1),pt(x0,y1,z0),pt(x0,y0,z0),sign)
    quad(kind,pt(x0,y1,z0),pt(x0,y1,z1),pt(x1,y1,z1),pt(x1,y1,z0),sign)
    quad(kind,pt(x0,y0,z1),pt(x0,y0,z0),pt(x1,y0,z0),pt(x1,y0,z1),sign)

PROFILE=[(-0.32,0.025),(-0.32,0.105),(-0.29,0.218),(-0.235,0.267),
         (0.19,0.267),(0.31,0.218),(0.31,0.075),(0.27,0.025)]

def profile_segment(z0,z1,sign):
    p=lambda v,z:(v[0]*sign,v[1],z)
    # PROFILE is clockwise in XY, which yields outward curvature with the
    # a(z0)->a(z1)->b(z1)->b(z0) winding.
    for i in range(len(PROFILE)):
        a,b=PROFILE[i],PROFILE[(i+1)%len(PROFILE)]
        quad("CONCRETE",p(a,z0),p(a,z1),p(b,z1),p(b,z0),sign)
    # Sealed endcaps; triangulated in 6 each.
    for j in range(1,len(PROFILE)-1):
        a,b,c=PROFILE[0],PROFILE[j],PROFILE[j+1]
        # Duplicate vertex to make a triangle using a very small drawless
        # quad would be degenerate; use explicit triangle emission instead.
        triangle("CONCRETE",p(a,z0),p(b,z0),p(c,z0),sign)
        triangle("CONCRETE",p(a,z1),p(c,z1),p(b,z1),sign)

def triangle(kind,a,b,c,sign):
    seq=[a,b,c] if sign>0 else [a,c,b]
    u=[seq[1][k]-seq[0][k] for k in range(3)]
    v=[seq[2][k]-seq[0][k] for k in range(3)]
    n=(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])
    length=math.sqrt(sum(t*t for t in n))
    if length<1e-8:raise ValueError("Degenerate curb cap triangle")
    n=tuple(x/length for x in n)
    kind_data=DATA[kind]
    first=len(kind_data["p"])//3
    hand=1.0 if n[2]>0 else -1.0
    for p in seq:
        kind_data["p"].extend(p)
        kind_data["n"].extend(n)
        kind_data["t"].extend((1.0,0.0,0.0,hand))
        kind_data["uv"].extend((p[0]/2.0,p[1]/2.0))
    kind_data["i"].extend((first,first+1,first+2))

def author(sign):
    begin()
    for i in range(12):
        low=-18.0+i*3.0+0.012
        high=-18.0+(i+1)*3.0-0.012
        profile_segment(low,high,sign)
        # Real expansion-jointed sidewalk slab: 0.86m of scanned concrete,
        # next to and outside the curb; existing crosswalk ramps stay clear.
        block("CONCRETE",0.39,1.22,0.09,0.166,low,high,sign)
        # Roadside drain trough doesn't intrude into 14m traffic lanes.
        block("BITUMEN",-0.62,-0.36,0.008,0.037,low,high,sign)
    for z in (-13.5,-7.5,-1.5,4.5,10.5,16.5):
        # Six true slotted steel drains across 36 m: actual shadows/holes
        # between 9 separate bars, not a dark sticker on the roadway.
        block("STEEL",-0.735,-0.356,0.040,0.065,z-0.60,z-0.535,sign)
        block("STEEL",-0.735,-0.356,0.040,0.065,z+0.535,z+0.60,sign)
        for edge in (-0.735,-0.374):
            block("STEEL",edge,edge+0.018,0.040,0.068,z-0.58,z+0.58,sign)
        for i in range(9):
            oz=z-0.48+i*0.12
            block("STEEL",-0.716,-0.388,0.042,0.063,oz,oz+0.026,sign)
    return DATA

def make_gltf(sign):
    geo=author(sign)
    data=bytearray()
    views=[]; accessors=[]
    def add(values,fmt,count,comp,target,position=False):
        while len(data)%4:data.append(0)
        start=len(data)
        data.extend(struct.pack("<"+fmt*len(values),*values))
        idx=len(views)
        views.append({"buffer":0,"byteOffset":start,"byteLength":len(data)-start,"target":target})
        spec={"bufferView":idx,"componentType":comp,"count":len(values)//count,
              "type":{1:"SCALAR",2:"VEC2",3:"VEC3",4:"VEC4"}[count]}
        if position:
            spec["min"]=[min(values[i::3]) for i in range(3)]
            spec["max"]=[max(values[i::3]) for i in range(3)]
        accessors.append(spec)
        return len(accessors)-1
    primitives=[]
    vertices=0
    triangles=0
    for index,kind in enumerate(COLORS):
        row=geo[kind]
        assert row["p"] and len(row["p"])%3==0
        vertices+=len(row["p"])//3
        triangles+=len(row["i"])//3
        primitive={"attributes":{
           "POSITION":add(row["p"],"f",3,5126,34962,True),
           "NORMAL":add(row["n"],"f",3,5126,34962),
           "TANGENT":add(row["t"],"f",4,5126,34962),
           "TEXCOORD_0":add(row["uv"],"f",2,5126,34962)},
           "indices":add(row["i"],"I",1,5125,34963),
           "material":index,"mode":4}
        primitives.append(primitive)
    imgs=[];tex=[];mats=[]
    for kind in COLORS:
        def find(channel):
            matches=list(TEX.glob(kind.lower()+"_"+channel+"_1k.*"))
            if len(matches)!=1:raise ValueError("Missing source photo channel "+kind+"/"+channel)
            idx=len(imgs)
            imgs.append({"uri":"textures/"+matches[0].name})
            tex.append({"source":idx,"sampler":0})
            return len(tex)-1
        color=find("base")
        normal=find("normal")
        arm=find("arm")
        tint=[0.86,0.87,0.86,1] if kind=="CONCRETE" else [0.78,0.81,0.82,1]
        mats.append({"name":kind+"_REAL_CC0_PHOTO",
            "pbrMetallicRoughness":{"baseColorTexture":{"index":color},
             "metallicRoughnessTexture":{"index":arm},
             "baseColorFactor":tint,"metallicFactor":1.0,"roughnessFactor":1.0},
             "normalTexture":{"index":normal,"scale":0.68 if kind=="CONCRETE" else 0.52}})
    variant="outer_plus" if sign>0 else "outer_minus"
    filename="central_curb_"+variant
    doc={"asset":{"version":"2.0","generator":"NightGrid original 36m curb trim glTF v1"},
         "scene":0,"scenes":[{"nodes":[0],"name":"SOURCE_AUTHORED_CURB"}],
         "nodes":[{"mesh":0,"name":"RealPhotoPBRStreetCurb_"+variant}],
         "meshes":[{"name":"36m_source_measured_curb_steel_drains_pavers","primitives":primitives}],
         "buffers":[{"uri":filename+".bin","byteLength":len(data)}],
         "bufferViews":views,"accessors":accessors,"materials":mats,
         "textures":tex,"images":imgs,
         "samplers":[{"magFilter":9729,"minFilter":9987,"wrapS":10497,"wrapT":10497}]}
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/(filename+".bin")).write_bytes(data)
    (OUT/(filename+".gltf")).write_text(json.dumps(doc,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    return {"name":filename,"triangles":triangles,"vertices":vertices,
            "surfaces":len(primitives),"curb_stones":12,
            "steel_grate_frames":6,"steel_grate_slots":54,
            "concrete_expansion_joints":11}

def main():
    official=source_image_set()
    own={"STEEL":existing_material("STEEL","blue_metal_plate"),
         "BITUMEN":existing_material("BITUMEN","bitumen")}
    for suffix in ("base","arm","normal"):
        matches=list(TEX.glob("concrete_"+suffix+"_1k.*"))
        if len(matches)!=1:raise ValueError("Photo concrete missing "+suffix)
    shapes=[make_gltf(-1),make_gltf(+1)]
    files={}
    for target in sorted(OUT.glob("*.gltf"))+sorted(OUT.glob("*.bin"))+sorted(TEX.glob("*")):
        files[target.relative_to(OUT).as_posix()]={"sha256":digest(target),"bytes":target.stat().st_size}
    assert len(files)==13
    manifest={"authoring_source":"tools/author_central_curb.py",
      "authoring_sha256":digest(Path("tools/author_central_curb.py")),
      "original_asset": "NightGrid authored beveled 36m street curb/road gutter modules",
      "source_concrete":official,"source_existing_2k":{str(p.relative_to(SOURCE)):digest(p)
       for stem in ("blue_metal_plate","bitumen")
       for p in (SOURCE/(stem+"_diffuse_2k.jpg"),SOURCE/(stem+"_nor_gl_2k.png"),
                 SOURCE/(stem+"_rough_2k.png"))},
      "material_derivatives":own,
      "license":"CC0 1.0 source photo texture layers; original NightGrid 3D geometry",
      "model_variants":shapes,
      "placement":"8 fixed 36m Central Exchange inner curbs, existing corner crossing ramps preserved",
      "runtime_download_required":False,
      "files":files}
    (OUT/"SOURCE.json").write_text(json.dumps(manifest,sort_keys=True,indent=2)+"\n",encoding="utf-8")
    print("AUTHORED_CENTRAL_CURB_PASS:",shapes,"/ source files",len(files),
          "bytes",sum(x["bytes"] for x in files.values()))

if __name__=="__main__":main()
