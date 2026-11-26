"""Hash-verified, paginated concept / actual mesh render review sheets."""
import argparse
from pathlib import Path
import shutil
import tempfile
from PIL import Image, ImageDraw, ImageOps
from refine import sha, load, write, KEY
from previews import valid, VIEWS


def thumbnail(file, size):
    with Image.open(file) as source:
        image = ImageOps.contain(source.convert("RGBA"),(size,size))
    bg=Image.new("RGB",(size,size),(43,46,52))
    bg.paste(image,((size-image.width)//2,(size-image.height)//2),image)
    return bg


def run(raw, previews, size):
    index=previews/("review-%d.json"%size)
    digest=sha(index)
    final=previews/("sheets-"+digest)
    if final.exists():
        info=load(final/"index.json")
        if info["source_sha256"]==digest and all(sha(final/n)==h for n,h in info["pages"].items()):
            return final
        raise ValueError("Existing contact sheets corrupt")
    stage=Path(tempfile.mkdtemp(prefix=".sheets-",dir=previews))
    pages={}
    try:
        rows=load(index)["rows"]
        rows=[r for r in rows if r["status"]=="review-only"]
        if not rows:
            raise ValueError("No successful preview rows")
        width,cell,height=1040,250,300
        for offset in range(0,len(rows),8):
            chunk=rows[offset:offset+8]
            sheet=Image.new("RGB",(width,48+height*len(chunk)),(24,27,31))
            draw=ImageDraw.Draw(sheet)
            draw.text((12,12),"ANUBIS | CONCEPT + BLENDER STUDIO RENDERS | NOT IN-GAME",fill="white")
            for i,row in enumerate(chunk):
                key,version=row["candidate"],row["preview"]
                if not KEY.fullmatch(key) or ".." in key or len(version)!=64 or any(c not in "0123456789abcdef" for c in version):
                    raise ValueError("Unsafe review row")
                folder=previews/key/version
                manifest=folder/"preview.json"
                info=load(manifest)
                settings=info["settings"]
                if sha(manifest)!=row["manifest_sha256"] or settings["candidate"]!=key or settings["refinement"]!=row["refinement"] or not valid(folder,settings):
                    raise ValueError("Stale preview")
                source=raw/"candidates"/key/"concept.png"
                image=load(source.with_name("image.json"))
                if image["sha256"]!=sha(source) or image["sha256"]!=settings["concept_sha256"] or image["job"]["key"]!=key:
                    raise ValueError("Concept hash mismatch")
                y=48+i*height
                draw.text((12,y),key+" / "+row["refinement"][:12],fill="white")
                for j,(label,file) in enumerate([("Concept",source)]+[(v,folder/(v+".png")) for v in VIEWS]):
                    x=12+j*258
                    sheet.paste(thumbnail(file,cell),(x,y+24))
                    draw.text((x,y+278),label,fill="white")
            name="page-%03d.jpg"%(offset//8+1)
            sheet.save(stage/name,quality=90)
            pages[name]=sha(stage/name)
        if sha(index)!=digest:
            raise ValueError("Preview index changed")
        write(stage/"index.json",{"source_sha256":digest,"pages":pages,"scope":"review-only"})
        stage.rename(final)
    finally:
        if stage.exists():
            shutil.rmtree(stage)
    print("Contact sheets:",final)
    return final


if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--raw",type=Path,required=True)
    p.add_argument("--previews",type=Path,required=True)
    p.add_argument("--size",type=int,default=1024)
    a=p.parse_args()
    run(a.raw.resolve(),a.previews.resolve(),a.size)
