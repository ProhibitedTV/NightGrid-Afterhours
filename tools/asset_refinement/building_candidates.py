"""Offline lot-profile building candidates; no world mutation, no GPU required."""
import argparse
import json
import hashlib
import math
import os
from pathlib import Path
import re
import struct
import tempfile
import time

from gen2_grate import Surface

ROOT = Path(__file__).resolve().parents[2]
WORLD = ROOT / "scripts/world_plan.gd"
SOURCE = ROOT / "assets/models/nightgrid/central_exchange_storefront"
FAMILIES = ("B1", "B2", "B3", "B4")
MATERIALS = ("masonry", "concrete", "steel", "glazing")

def digest(data):
    return hashlib.sha256(data).hexdigest()

def profiles():
    # Read the actual source dimensions; fail if its constant format changes.
    match = re.search(r"const LOT_PROFILES = (\{.*?\n\})", WORLD.read_text(encoding="utf-8"), re.S)
    if not match:
        raise ValueError("LOT_PROFILES source format changed")
    result = json.loads(re.sub(r",(\s*[}\]])", r"\1", match.group(1)))
    for key in FAMILIES:
        for field in ("width", "height", "depth"):
            n = result[key][field]
            if not isinstance(n, (int,float)) or not math.isfinite(n) or n <= 0:
                raise ValueError("Invalid canonical profile dimension")
    return result

def box(surface, x0, x1, y0, y1, z0, z1):
    if not (x0 < x1 and y0 < y1 and z0 < z1):
        raise ValueError("Degenerate architectural component")
    a,b,c,d = (x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0)
    e,f,g,h = (x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)
    for pts,n in (((a,b,c,d),(0,0,-1)),((e,h,g,f),(0,0,1)),
                  ((a,d,h,e),(-1,0,0)),((b,f,g,c),(1,0,0)),
                  ((a,e,f,b),(0,-1,0)),((d,c,g,h),(0,1,0))):
        surface.face(pts,n)

def geometry(profile, lod):
    w,h,d = (profile[k] for k in ("width","height","depth"))
    x = w/2
    # Building local frontage z=0, rear z=depth, grade y=0.
    # Preserve canonical outer dimensions; roof hardware stays below height.
    s = {name:Surface() for name in MATERIALS}
    def add(mat, *bounds):
        box(s[mat], *bounds)
    wall = "steel" if profile["material"] == "METAL" else "masonry"
    thick = .28
    roof = h-.62
    ground = 3.6
    floors = max(2, round((roof-ground)/3.1))
    pitch = (roof-ground)/floors
    add("concrete",-x,x,-.18,0,0,d)
    add(wall,-x,-x+thick,0,roof,thick,d-thick)
    add(wall,x-thick,x,0,roof,thick,d-thick)
    # Actual ground-floor front and rear apertures, no geometry across doors.
    portal = 1.42
    for z0,z1 in ((0,thick),(d-thick,d)):
        add(wall,-x,-portal,0,.66,z0,z1)
        add(wall,portal,x,0,.66,z0,z1)
        add(wall,-x,x,3.17,ground,z0,z1)
        for lo,hi in ((-x,-x+.62),(-portal-.24,-portal),(portal,portal+.24),(x-.62,x)):
            add(wall,lo,hi,.66,3.17,z0,z1)
        # Opaque dark glass is provisional; pane is recessed in the real opening.
        pane0 = z0+.14 if z0==0 else z0+.08
        for lo,hi in ((-x+.62,-portal-.24),(portal+.24,x-.62)):
            add("glazing",lo,hi,.66,3.17,pane0,pane0+.035)
            if lod==0:
                for k in range(1,4):
                    xx=lo+(hi-lo)*k/4
                    add("steel",xx-.035,xx+.035,.66,3.17,pane0-.04,pane0+.075)
    bays = max(3,round(w/3.1))
    for floor in range(floors):
        y=ground+floor*pitch
        add("concrete",-x+thick,x-thick,y-.18,y,thick,d-thick)
        for z0,z1 in ((0,thick),(d-thick,d)):
            add(wall,-x,x,y,y+.62,z0,z1)
            add(wall,-x,x,y+pitch-.40,y+pitch,z0,z1)
            pane0=z0+.14 if z0==0 else z0+.08
            for j in range(bays):
                lo=-x+j*w/bays
                hi=lo+w/bays
                margin=.30
                add(wall,lo,lo+margin,y+.62,y+pitch-.40,z0,z1)
                add(wall,hi-margin,hi,y+.62,y+pitch-.40,z0,z1)
                add("glazing",lo+margin,hi-margin,y+.62,y+pitch-.40,pane0,pane0+.035)
                if lod==0:
                    mid=(lo+hi)/2
                    add("steel",mid-.035,mid+.035,y+.62,y+pitch-.40,pane0-.035,pane0+.07)
        if lod==0:
            for z0,z1 in ((0,.09),(d-.09,d)):
                add("concrete",-x,x,y+.10,y+.23,z0,z1)
    add("concrete",-x,x,roof-.20,roof,0,d)
    for lo,hi in ((-x,-x+.24),(x-.24,x)):
        add(wall,lo,hi,roof,h-.08,0,d)
        add("steel",lo,hi,h-.08,h,0,d)
    for lo,hi in ((0,.24),(d-.24,d)):
        add(wall,-x+.24,x-.24,roof,h-.08,lo,hi)
        add("steel",-x+.24,x-.24,h-.08,h,lo,hi)
    if lod==0:
        for xx in (-x*.42,x*.42):
            add("steel",xx-.58,xx+.58,roof,roof+.47,d*.58,d*.58+1.5)
            for j in range(5):
                zz=d*.58+.13+j*.25
                add("concrete",xx-.48,xx+.48,roof+.47,roof+.51,zz,zz+.08)
    return s

def textures():
    notice=json.loads((SOURCE/"SOURCE.json").read_text(encoding="utf-8"))
    maps={}
    for mat in MATERIALS[:-1]:
        for suffix in ("base_1k.jpg","normal_1k.jpg","arm_1k.png"):
            rel=f"textures/{mat}_{suffix}"
            raw=(SOURCE/rel).read_bytes()
            expected=notice["files"][rel]
            if digest(raw)!=expected["sha256"] or len(raw)!=expected["bytes"]:
                raise ValueError("PBR input mismatch: "+rel)
            maps[rel]=raw
    return maps

# Lightmap UV charts are packed across all materials, not per surface.
# Geometry here is authored as independent planar rectangles (four vertices).
# A fixed atlas with 4 px gutters and world-size proportional charts provides
# a deterministic UV2 candidate. Native Godot may choose a different atlas size.
UV2_SIZE = 2048
UV2_GUTTER = 4

def lightmap_uvs(surfaces, size=UV2_SIZE, gutter=UV2_GUTTER):
    charts = []
    for mat, surface in surfaces.items():
        if len(surface.p) % 12 or len(surface.i) != len(surface.p)//12*6:
            raise ValueError("Expected rectangular face topology")
        for i in range(0,len(surface.p),12):
            v = [surface.p[i+j:i+j+3] for j in (0,3,6,9)]
            w = math.dist(v[0],v[1])
            h = math.dist(v[1],v[2])
            if min(w,h)<=0 or not math.isclose(w,math.dist(v[2],v[3]),rel_tol=1e-6) or not math.isclose(h,math.dist(v[3],v[0]),rel_tol=1e-6):
                raise ValueError("Invalid rectangular chart")
            charts.append((mat,i//3,w,h))
    def fit(density):
        rects = [(mat,i,max(1,math.ceil(w*density)),max(1,math.ceil(h*density))) for mat,i,w,h in charts]
        rects.sort(key=lambda a:(-a[3],-a[2],a[0],a[1]))
        x=y=row=0
        placed=[]
        for mat,i,w,h in rects:
            ww,hh=w+2*gutter,h+2*gutter
            if ww>size or hh>size:
                return None
            if x+ww>size:
                x=0;y+=row;row=0
            if y+hh>size:
                return None
            placed.append((mat,i,x+gutter,y+gutter,w,h))
            x+=ww;row=max(row,hh)
        return placed
    if not charts or fit(0) is None:
        raise ValueError("UV2 chart count exceeds atlas capacity")
    lo,hi=0.,float(size)
    for _ in range(24):
        mid=(lo+hi)/2
        if fit(mid) is None: hi=mid
        else: lo=mid
    if lo<=0:
        raise ValueError("No positive lightmap density fits")
    placed=fit(lo)
    uvs={mat:[0.]*(len(s.p)//3*2) for mat,s in surfaces.items()}
    for mat,i,x,y,w,h in placed:
        uvs[mat][i*2:i*2+8]=[q/size for q in (x,y,x+w,y,x+w,y+h,x,y+h)]
    return uvs,{"atlas_reference_px":size,"gutter_px":gutter,"charts":len(charts),
                "reference_texels_per_m":round(lo,3),
                "chart_occupancy":round(sum(w*h for _,_,_,_,w,h in placed)/size**2,4)}

def encode(surfaces,maps):
    uv2, _ = lightmap_uvs(surfaces)
    blob=bytearray()
    views,accessors,images,prims,materials=[],[],[],[],[]
    def view(raw,target=None):
        blob.extend(b"\0"*(-len(blob)%4))
        item={"buffer":0,"byteOffset":len(blob),"byteLength":len(raw)}
        if target: item["target"]=target
        views.append(item); blob.extend(raw)
        return len(views)-1
    def accessor(vals,dim,kind):
        index=kind=="I"
        item={"bufferView":view(struct.pack("<"+str(len(vals))+kind,*vals),34963 if index else 34962),
              "componentType":5125 if index else 5126,"count":len(vals)//dim,
              "type":{1:"SCALAR",2:"VEC2",3:"VEC3",4:"VEC4"}[dim]}
        if dim==3:
            item.update(min=[min(vals[k::3]) for k in range(3)],max=[max(vals[k::3]) for k in range(3)])
        accessors.append(item)
        return len(accessors)-1
    indices={}
    for rel,raw in maps.items():
        indices[rel]=len(images)
        images.append({"name":Path(rel).name,"bufferView":view(raw),
                       "mimeType":"image/png" if rel.endswith(".png") else "image/jpeg"})
    for mat,s in surfaces.items():
        if not s.i: continue
        if mat=="glazing":
            m={"name":"Recessed dark glazing - provisional","pbrMetallicRoughness":{
               "baseColorFactor":[.035,.055,.065,1],"roughnessFactor":.24,"metallicFactor":.3}}
        else:
            def tex(suffix): return {"index":indices[f"textures/{mat}_{suffix}"]}
            m={"name":mat,"pbrMetallicRoughness":{"baseColorTexture":tex("base_1k.jpg"),
               "metallicRoughnessTexture":tex("arm_1k.png"),"metallicFactor":1,"roughnessFactor":1},
               "normalTexture":tex("normal_1k.jpg"),"occlusionTexture":tex("arm_1k.png")}
        attrs={name:accessor(v,dim,"f") for name,v,dim in
               (("POSITION",s.p,3),("NORMAL",s.n,3),("TANGENT",s.t,4),("TEXCOORD_0",s.uv,2),("TEXCOORD_1",uv2[mat],2))}
        prims.append({"attributes":attrs,"indices":accessor(s.i,1,"I"),"material":len(materials)})
        materials.append(m)
    blob.extend(b"\0"*(-len(blob)%4))
    doc={"asset":{"version":"2.0","generator":"NightGrid architecture studio pilot"},
         "scene":0,"scenes":[{"nodes":[0]}],"nodes":[{"mesh":0}],"meshes":[{"primitives":prims}],
         "materials":materials,"images":images,"textures":[{"source":i} for i in range(len(images))],
         "buffers":[{"byteLength":len(blob)}],"bufferViews":views,"accessors":accessors}
    raw=json.dumps(doc,separators=(",",":")).encode(); raw+=b" "*(-len(raw)%4)
    return struct.pack("<4sII",b"glTF",2,28+len(raw)+len(blob))+struct.pack("<I4s",len(raw),b"JSON")+raw+struct.pack("<I4s",len(blob),b"BIN\0")+blob

def produce(out,keys):
    out=out.resolve()
    if out==ROOT or ROOT in out.parents or out in ROOT.parents:
        raise ValueError("Candidate output must be outside source checkout")
    spec=profiles(); maps=textures()
    inputs={"generator":digest(Path(__file__).read_bytes()),"geometry_helper":digest((Path(__file__).with_name("gen2_grate.py")).read_bytes()),
            "world_plan":digest(WORLD.read_bytes()),"textures":{n:digest(v) for n,v in maps.items()}}
    out.mkdir(parents=True,exist_ok=True)
    for key in keys:
        dest=out/key
        if dest.exists():
            if dest.is_symlink(): raise ValueError("Unsafe candidate directory")
            doc=json.loads((dest/"candidate.json").read_text(encoding="utf-8"))
            if doc["inputs"]!=inputs or doc["profile"]!=spec[key] or set(doc["outputs"])!={"lod0.glb","lod1.glb"}:
                raise ValueError("Existing building provenance mismatch: "+key)
            for name,record in doc["outputs"].items():
                path=dest/name
                if path.is_symlink() or digest(path.read_bytes())!=record["sha256"]:
                    raise ValueError("Existing building candidate changed: "+key)
            print("SKIP verified",key,flush=True); continue
        stage=Path(tempfile.mkdtemp(prefix="."+key+".partial-",dir=out))
        files={}
        for lod in (0,1):
            mesh=geometry(spec[key],lod)
            raw=encode(mesh,maps); name=f"lod{lod}.glb"
            (stage/name).write_bytes(raw)
            files[name]={"sha256":digest(raw),"bytes":len(raw),"triangles":sum(len(s.i)//3 for s in mesh.values()),"uv2":lightmap_uvs(mesh)[1]}
        doc={"schema":1,"status":"candidate-only","family":key,"profile":spec[key],"inputs":inputs,
             "outputs":files,"placement":"unassigned archetype, not a surveyed lot; front z=0, grade y=0",
             "notes":"Dimensioned shell and ground apertures; upper floors are not furnished or navigable. Dark opaque pane is provisional.",
             "pending":["lot fit and existing anchors","collision and doors","native UV2 import and actual bake density","native material and lighting review","performance","rights and promotion"]}
        (stage/"candidate.json").write_text(json.dumps(doc,indent=2)+"\n",encoding="utf-8")
        if dest.exists(): raise FileExistsError(dest)
        stage.rename(dest)
        print("Candidate only:",key,files,flush=True)

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out",type=Path,required=True)
    p.add_argument("--family",action="append",choices=FAMILIES)
    p.add_argument("--execute",action="store_true")
    a=p.parse_args()
    keys=a.family or FAMILIES
    if len(set(keys))!=len(keys): p.error("duplicate family")
    if a.execute: produce(a.out,keys)
    else:
        for key in keys: print(key,profiles()[key])
