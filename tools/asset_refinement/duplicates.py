"""Flag possible duplicate concepts for human review; never discard candidates."""
import argparse
from itertools import combinations
from pathlib import Path
import tempfile
import json
from PIL import Image, ImageOps
from refine import KEY, sha, load, write


def fingerprint(path):
    with Image.open(path) as im:
        im = ImageOps.exif_transpose(im).convert("L").resize((9,8),Image.Resampling.LANCZOS)
        px=list(im.getdata())
    return sum(int(px[y*9+x]>px[y*9+x+1]) << (y*8+x) for y in range(8) for x in range(8))


def report(raw, threshold=6):
    entries=[]
    invalid=[]
    for folder in sorted((raw/"candidates").iterdir()):
        if not folder.is_dir() or folder.is_symlink() or not KEY.fullmatch(folder.name) or ".." in folder.name:
            continue
        path,meta=folder/"concept.png",folder/"image.json"
        if not path.is_file() or not meta.is_file():
            continue
        try:
            if path.is_symlink() or meta.is_symlink():
                raise ValueError("Symlink input")
            info=load(meta)
            digest=sha(path)
            if info["job"]["key"]!=folder.name or info["sha256"]!=digest:
                raise ValueError("Source mismatch")
            value=fingerprint(path)
            if sha(path)!=digest:
                raise ValueError("Source changed")
            entries.append({"key":folder.name,"kind":info["job"]["kind"],"sha256":digest,"dhash":value})
        except (ValueError,OSError,KeyError,TypeError) as exc:
            invalid.append({"key":folder.name,"error":str(exc)})
    pairs=[]
    for a,b in combinations(entries,2):
        if a["kind"]!=b["kind"]:
            continue
        distance=(a["dhash"]^b["dhash"]).bit_count()
        if distance<=threshold or a["sha256"]==b["sha256"]:
            pairs.append({"a":a["key"],"b":b["key"],"a_sha256":a["sha256"],"b_sha256":b["sha256"],
                          "distance":distance,"exact":a["sha256"]==b["sha256"]})
    return {"schema":1,"scope":"review hints only; perceptual false positives possible",
            "threshold":threshold,"scanned":len(entries),"invalid":invalid,
            "pairs":sorted(pairs,key=lambda p:(not p["exact"],p["distance"],p["a"],p["b"]))}


if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--raw",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True)
    p.add_argument("--threshold",type=int,default=6)
    a=p.parse_args()
    raw,out=a.raw.resolve(),a.output.resolve()
    if raw==out or raw in out.parents or not 0<=a.threshold<=12:
        p.error("Output must be outside raw library; threshold 0–12")
    out.parent.mkdir(parents=True,exist_ok=True)
    data=report(raw,a.threshold)
    with tempfile.NamedTemporaryFile(dir=out.parent,delete=False) as handle:
        temp=Path(handle.name)
    try:
        write(temp,data)
        temp.replace(out)
    finally:
        temp.unlink(missing_ok=True)
    print("Concepts scanned=%d possible duplicate pairs=%d"%(data["scanned"],len(data["pairs"])))
    raise SystemExit(int(bool(data["invalid"])))
