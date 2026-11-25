"""Offline, review-only fitted garment matrix. No game-time generation."""
import argparse
import hashlib
import itertools
import json
import re
import struct
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = Path(__file__).with_name("collection.json")
BASE = ROOT / "assets/models/nightgrid/courier/morrow_courier.glb"

def require(ok, message):
    if not ok:
        raise ValueError(message)

def glb(path):
    raw = path.read_bytes()
    require(len(raw) >= 28, "Truncated GLB")
    magic, version, size, n, kind = struct.unpack_from("<4sIIII", raw)
    require((magic, version, size, kind)==(b"glTF", 2, len(raw), 0x4E4F534A), "Invalid GLB header")
    require(20+n+8 <= len(raw), "Truncated JSON")
    doc=json.loads(raw[20:20+n])
    length, kind=struct.unpack_from("<II",raw,20+n)
    require(kind==0x004E4942 and 28+n+length==len(raw),"Invalid embedded BIN")
    require(len(doc.get("buffers",[]))==1 and "uri" not in doc["buffers"][0],"External buffer")
    require(all("uri" not in i and "bufferView" in i for i in doc.get("images",[])),"External image")
    return doc,raw,raw[28+n:]

def accessor_bytes(doc, binary, idx):
    a=doc["accessors"][idx]
    require("sparse" not in a and "bufferView" in a,"Unsupported sparse accessor")
    v=doc["bufferViews"][a["bufferView"]]
    widths={"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4,"MAT4":16}
    sizes={5120:1,5121:1,5122:2,5123:2,5125:4,5126:4}
    item=widths[a["type"]]*sizes[a["componentType"]]
    stride=v.get("byteStride",item)
    start=v.get("byteOffset",0)+a.get("byteOffset",0)
    count=a["count"]
    end=start+(count-1)*stride+item
    require(count>0 and stride>=item and start>=v.get("byteOffset",0) and end<=v.get("byteOffset",0)+v["byteLength"] and end<=len(binary),"Accessor out of range")
    return b"".join(binary[start+i*stride:start+i*stride+item] for i in range(count))

def rig(doc,binary):
    require(len(doc.get("skins",[]))==1,"Exactly one skin required")
    skin=doc["skins"][0]
    nodes=doc["nodes"]
    parents={c:i for i,node in enumerate(nodes) for c in node.get("children",[])}
    joints=skin["joints"]
    require(len(joints)>=60 and len(set(joints))==len(joints),"Incomplete rig")
    rows=[]
    for j in joints:
        node=nodes[j]
        parent=parents.get(j)
        rows.append((node["name"],nodes[parent]["name"] if parent is not None else None,
                     node.get("translation",[0,0,0]),node.get("rotation",[0,0,0,1]),
                     node.get("scale",[1,1,1]),node.get("matrix")))
    binds=accessor_bytes(doc,binary,skin["inverseBindMatrices"])
    return rows,binds

def variants(spec):
    axes=[spec["axes"][k] for k in ("top","bottom","shoe")]
    for combo in itertools.product(*axes):
        yield "_".join(x["id"] for x in combo),combo

def profile(spec,combo):
    result=json.loads((ROOT/spec["base"]).read_text())
    params=result["params"]
    params.update(spec["common"])
    params["garmentStyles"]={}
    for entry in combo:
        params.update(entry["settings"])
        params["garmentStyles"].update(entry["styles"])
    return result

def validate(path,reference,combo,limits):
    doc,raw,binary=glb(path)
    ref,_,refbin=reference
    require(len(raw)<=limits["max_bytes"],"Candidate byte budget exceeded")
    require(rig(doc,binary)==rig(ref,refbin),"Joint hierarchy, transforms or inverse binds differ")
    nodes=[n for n in doc["nodes"] if "mesh" in n and "skin" in n]
    require(len(nodes)==1,"Expected single weighted avatar mesh")
    parts=doc["meshes"][nodes[0]["mesh"]]["primitives"]
    materials=[]
    vertices=0
    for part in parts:
        attrs=part["attributes"]
        require(all(k in attrs for k in ("POSITION","NORMAL","TEXCOORD_0","JOINTS_0","WEIGHTS_0")),"Missing weighted surface attributes")
        count=doc["accessors"][attrs["POSITION"]]["count"]
        require(all(doc["accessors"][attrs[k]]["count"]==count for k in ("NORMAL","TEXCOORD_0","JOINTS_0","WEIGHTS_0")),"Attribute count mismatch")
        for k in ("POSITION","NORMAL","TEXCOORD_0","JOINTS_0","WEIGHTS_0"):
            accessor_bytes(doc,binary,attrs[k])
        vertices+=count
        materials.append(doc["materials"][part["material"]].get("name","").lower())
    require(0<vertices<=limits["max_vertices"],"Vertex budget exceeded")
    require(any("skin" in n for n in materials),"Missing body skin")
    require(not any("backpack" in n or "scarf" in n for n in materials),"Unexpected default equipment")
    for entry in combo:
        for pattern in entry["materials"]:
            require(any(re.search(pattern,n) for n in materials),f"Missing expected garment {pattern}: {materials}")
    return {"sha256":hashlib.sha256(raw).hexdigest(),"bytes":len(raw),"vertices":vertices,
            "joints":len(rig(doc,binary)[0]),"materials":materials,"reviewed":False}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action",choices=["list","prepare","build","verify"])
    parser.add_argument("--out",type=Path,default=ROOT/"dist/wardrobe-candidates")
    parser.add_argument("--id",action="append",default=[])
    args=parser.parse_args()
    spec=json.loads(SPEC.read_text())
    rows=dict(variants(spec))
    require(len(rows)<=spec["limits"]["max_variants"],"Matrix budget exceeded")
    require(set(args.id)<=set(rows),"Unknown candidate")
    selected=args.id or list(rows)
    if args.action=="list":
        print("\n".join(selected));return
    reference=glb(BASE) if args.action in ("build","verify") else None
    args.out.mkdir(parents=True,exist_ok=True)
    for ident in selected:
        combo=rows[ident]
        folder=args.out/ident
        folder.mkdir(exist_ok=True)
        params=folder/"appearance.json"
        candidate=folder/"Morrow_Courier.glb"
        if args.action in ("prepare","build"):
            params.write_text(json.dumps(profile(spec,combo),indent=2)+"\n")
        if args.action=="build":
            subprocess.run(["npx","--yes",spec["source"],"export","--params",str(params),"--out",str(folder),"--animations","idle"],check=True)
        if args.action in ("build","verify"):
            result=validate(candidate,reference,combo,spec["limits"])
            result.update(id=ident,source=spec["source"],source_revision=spec["source_revision"],
                          base_sha256=hashlib.sha256(reference[1]).hexdigest(),
                          profile_sha256=hashlib.sha256(params.read_bytes()).hexdigest())
            (folder/"candidate.json").write_text(json.dumps(result,indent=2)+"\n")
            print("WARDROBE CANDIDATE PASS",ident,result["vertices"])

if __name__=="__main__":
    main()
