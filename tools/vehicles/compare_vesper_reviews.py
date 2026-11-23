#!/usr/bin/env python3
"""Create auditable, like-for-like Vesper Blender contact sheets from two runs.

Requires Pillow. Input captures MUST be authentic Blender Workbench previews
with their original source.json; this does not create or claim Godot gameplay.
"""
from __future__ import annotations
import argparse
from hashlib import sha256
import json
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError as e:
    raise SystemExit("Pillow is required: python -m pip install Pillow") from e

VIEWS=("front_three_quarter","rear_three_quarter","profile","open_cockpit")


def _safe_manifest(folder:Path, name:str) -> dict:
    f=folder/"source.json"
    if not f.is_file():
        raise ValueError(f"{name}: no source.json to prove provenance")
    data=json.loads(f.read_text(encoding="utf-8"))
    if data.get("id")!="nightgrid.vesper_v2.original_roadster":
        raise ValueError(f"{name}: source is not the matching Vesper model")
    return data


def compare(baseline:Path, candidate:Path, output:Path) -> dict:
    a=_safe_manifest(baseline,"baseline")
    b=_safe_manifest(candidate,"candidate")
    width=1600; border=22; header=60; cell_w=(width-3*border)//2
    cell_h=480
    sheet=Image.new("RGB",(width,header+4*(cell_h+border)+border),
                    color=(15,23,30))
    draw=ImageDraw.Draw(sheet)
    try:
        font=ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",19)
        heading=ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",23)
    except OSError:
        font=heading=ImageFont.load_default()
    draw.text((border,18),"VESPER V2 | MATCHED-CAMERA MODELING REVIEW",
              font=heading,fill=(238,243,246))
    records={}
    for idx,view in enumerate(VIEWS):
        y=header+idx*(cell_h+border)
        for side,(folder,manifest,label) in enumerate(((baseline,a,"BASELINE"),
                                                        (candidate,b,"CANDIDATE"))):
            path=folder/(view+".png")
            if not path.is_file():
                raise ValueError(f"Missing authentic source frame: {path}")
            actual=sha256(path.read_bytes()).hexdigest()
            expected=manifest.get("files",{}).get(path.name,{}).get("sha256")
            if not expected or expected!=actual:
                raise ValueError(f"{path.name}: manifest SHA-256 mismatch")
            with Image.open(path) as im:
                im=im.convert("RGB")
                records[label+"_"+view]={"sha256":actual,"dimensions":list(im.size)}
                im.thumbnail((cell_w-20,cell_h-65),Image.Resampling.LANCZOS)
                x=border+side*(cell_w+border)
                draw.rectangle((x,y,x+cell_w,y+cell_h),fill=(22,29,35))
                px=x+(cell_w-im.width)//2
                py=y+45+(cell_h-55-im.height)//2
                sheet.paste(im,(px,py))
                draw.text((x+15,y+13),label+" — "+view.replace("_"," ").upper(),
                          font=font,fill=(228,235,242))
    output.parent.mkdir(parents=True,exist_ok=True)
    sheet.save(output)
    report={
       "image":str(output),
       "image_sha256":sha256(output.read_bytes()).hexdigest(),
       "evidence_type":"Matched-camera Blender Workbench renders; NOT Godot gameplay",
       "baseline_source":a.get("source"),"candidate_source":b.get("source"),
       "captured_frames":records,
       "warning":"This is a comparison for human artistic review, not an automated AAA quality score",
    }
    (output.with_suffix(".json")).write_text(json.dumps(report,indent=2)+"\n",
                                             encoding="utf-8")
    return report


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline",type=Path,required=True)
    parser.add_argument("--candidate",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    print(json.dumps(compare(args.baseline,args.candidate,args.output),indent=2))
