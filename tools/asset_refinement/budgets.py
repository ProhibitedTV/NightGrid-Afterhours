"""Conservative decoded texture estimates; not measured Godot VRAM."""
import argparse
import json
from pathlib import Path
import tempfile
from refine import load, sha, write
from review_queue import scan


def mip_bytes(width,height,bpp=4):
    if not all(isinstance(n,int) and 0<n<=8192 for n in (width,height)):
        raise ValueError("Invalid texture dimensions")
    size=0
    while True:
        size+=width*height*bpp
        if width==1 and height==1:
            return size
        width=max(1,width//2)
        height=max(1,height//2)


def estimate(item):
    outputs=item["outputs"]
    lods=[]
    for i in range(3):
        names=[f"lod{i}-basecolor.png",f"lod{i}-normal.png"]
        textures=[{"name":n,"bytes_rgba8_mips":mip_bytes(*outputs[n]["size"])}
                  for n in names if n in outputs]
        lods.append({"lod":i,"triangles":outputs[f"lod{i}.glb"]["triangles"],
                     "textures":textures,"bytes_rgba8_mips":sum(t["bytes_rgba8_mips"] for t in textures)})
    total=sum(l["bytes_rgba8_mips"] for l in lods)
    return {"lods":lods,"all_lods_texture_bytes":total,
            "warnings":["over-provisional-prop-budget"] if total>16*1024**2 else []}


def report_from_rows(review_rows):
    rows=[]
    for row in review_rows:
        for item in row.get("versions",[]):
            record=estimate(item)
            rows.append(dict(record,candidate=row["candidate"],signature=item["signature"],
                             manifest_sha256=item["manifest_sha256"]))
    # Do not sum alternative versions as if all are simultaneously resident.
    return {"schema":1,"scope":"RGBA8 full mip chain estimates, not measured VRAM",
            "excludes":["mesh buffers","render targets","texture compression","standalone AO","surface library",
                        "streaming and runtime copies"],"provisional_prop_budget_bytes":16*1024**2,
            "rows":rows}


def report(raw,refined,size):
    return report_from_rows(scan(raw,refined,size))


if __name__=="__main__":
    p=argparse.ArgumentParser()
    for key in ("raw","refined","output"):
        p.add_argument("--"+key,type=Path,required=True)
    p.add_argument("--size",type=int,default=1024)
    a=p.parse_args()
    if a.output.resolve().parent!=a.refined.resolve():
        p.error("Output must be inside refined root")
    data=report(a.raw.resolve(),a.refined.resolve(),a.size)
    with tempfile.NamedTemporaryFile(dir=a.refined,delete=False) as f:
        tmp=Path(f.name)
    try:
        write(tmp,data)
        tmp.replace(a.output)
    finally:
        tmp.unlink(missing_ok=True)
    print("Texture budget records:",len(data["rows"]))
