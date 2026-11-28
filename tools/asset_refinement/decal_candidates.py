"""Original procedural street-weathering decal candidates, no source downloads."""
import argparse
import json
import math
from pathlib import Path
import tempfile
import numpy as np
from PIL import Image
from refine import sha
from production_evidence import checked
from factory_ledger import atomic

ROOT=Path(__file__).resolve().parents[2]
# id: sRGB tint, nominal roughness, width/height in metres, receiver
PROFILES={
 "asphalt_crack":((48,45,42),.91,(1.8,1.8),"road"),
 "tire_scuffs":((34,32,30),.85,(1.6,3.2),"road"),
 "oil_stain":((40,37,33),.25,(1.2,1.2),"road"),
 "puddle_edge":((48,54,57),.18,(2.0,1.2),"road"),
 "coastal_salt":((173,175,160),.88,(1.2,.8),"masonry"),
 "rust_runoff":((115,58,31),.81,(.7,1.5),"wall"),
 "concrete_spall":((117,111,102),.94,(.8,.8),"concrete"),
 "boot_scuffs":((54,50,46),.87,(.6,.8),"interior"),
}
OUTPUTS=("albedo.png","orm.png","preview.jpg")


def maps(name,size):
    if name not in PROFILES or size<32:
        raise ValueError("Unknown decal or undersized tile")
    tint,rough,_,_=PROFILES[name]
    rng=np.random.default_rng(4201337+list(PROFILES).index(name))
    q=(np.arange(size)+.5)*2/size-1
    x,y=np.meshgrid(q,q)
    # Fade all sides; keep an 8% empty sampling border.
    edge=np.clip((.92-np.maximum(abs(x),abs(y)))/.18,0,1)
    noise=rng.random((size,size))
    field=np.sin(x*19+y*9)+.5*np.sin(x*37-y*23)+.35*np.sin(x*73+y*61)
    if name=="asphalt_crack":
        path=.18*np.sin(y*8)+.07*np.sin(y*23)+.025*np.sin(y*53)
        branch=.30+.42*y+.07*np.sin(y*17)
        main=np.exp(-((x-path)/.021)**2)
        spur=np.exp(-((x-branch)/.014)**2)*np.clip((y+.2)*4,0,1)
        a=np.maximum(main,spur)*(.55+.45*noise)
    elif name=="tire_scuffs":
        a=(np.exp(-((x-.31)/.11)**2)+np.exp(-((x+.31)/.11)**2))*.48
        a*=np.clip(.55+.35*field,0,1)*(.4+.6*noise)
    elif name in ("oil_stain","puddle_edge"):
        radius=np.sqrt((x*.85)**2+(y*1.3)**2)
        irregular=radius+.065*field
        a=np.clip((.70-irregular)*8,0,1)*(.7 if name=="oil_stain" else .55)
        a*=.65+.35*noise
    elif name=="coastal_salt":
        a=np.exp(-((y+.25+.12*field)/.35)**2)*np.clip(noise+.25*field-.3,0,1)*.76
    elif name=="rust_runoff":
        a=np.exp(-((x+.025*np.sin(y*14))/.15)**2)*np.clip((y+.75)*1.4,0,1)
        a*=np.clip(.45+.4*field+.3*noise,0,1)*.8
    elif name=="concrete_spall":
        a=np.clip((.62-np.sqrt(x*x+y*y)+.07*field)*6,0,1)*(.35+.5*noise)
    else:
        a=np.exp(-((x+.19)/.27)**2-((y-.14)/.56)**2)*np.clip(.6+.4*field,0,1)*.65
    a=np.clip(a*edge,0,1)
    # Colors carry material tint only, not directional shading. RGB remains
    # populated outside alpha to minimize dark filtering fringes.
    rgb=np.clip(np.array(tint)[None,None,:]*(.85+.3*noise[...,None]),0,255)
    alpha=np.rint(a*255).astype(np.uint8)
    albedo=np.dstack((rgb.astype(np.uint8),alpha))
    # Neutral AO, authored roughness, dielectric. Alpha is shared explicitly.
    orm=np.stack((np.full_like(alpha,255),
                  np.uint8(np.clip(rough+.08*(noise-.5),0,1)*255),
                  np.zeros_like(alpha),alpha),axis=-1)
    return albedo,orm


def produce(out,size):
    out=out.resolve()
    if out==ROOT or ROOT in out.parents or out in ROOT.parents:
        raise ValueError("Use private candidate directory")
    out.mkdir(parents=True,exist_ok=True)
    settings={"tile_size":size,"generator_sha256":sha(Path(__file__)),"profiles":list(PROFILES)}
    final=out/"street-weathering"
    if final.exists():
        doc=json.loads((final/"candidate.json").read_text())
        if doc["settings"]!=settings or set(doc["outputs"])!=set(OUTPUTS):
            raise ValueError("Existing decal candidate differs")
        for name,rec in doc["outputs"].items():
            checked(final,name,rec["sha256"])
        print("SKIP verified street-weathering",flush=True)
        return
    stage=Path(tempfile.mkdtemp(prefix=".street-weathering.partial-",dir=out))
    atlases=[Image.new("RGBA",(size*4,size*2)) for _ in range(2)]
    records=[]
    for i,(name,(_,rough,extent,receiver)) in enumerate(PROFILES.items()):
        albedo,orm=maps(name,size)
        xy=(i%4*size,i//4*size)
        for atlas,arr in zip(atlases,(albedo,orm)):
            atlas.paste(Image.fromarray(arr),xy)
        coverage=float((albedo[:,:,3]>0).mean())
        if not .005<coverage<.8:
            raise ValueError("Unexpected decal coverage: "+name)
        records.append({"id":name,"tile_xy":list(xy),"size_px":[size,size],
                        "nominal_extent_m":list(extent),"receiver":receiver,
                        "roughness":rough,"coverage":coverage})
    atlases[0].save(stage/"albedo.png")
    atlases[1].save(stage/"orm.png")
    preview=Image.new("RGB",atlases[0].size,(100,105,110))
    preview.paste(atlases[0],mask=atlases[0].getchannel("A"))
    preview.thumbnail((1024,512))
    preview.save(stage/"preview.jpg",quality=90)
    atomic(stage/"candidate.json",{"schema":1,"status":"candidate-only","settings":settings,
        "tiles":records,"outputs":{n:{"sha256":sha(stage/n),"bytes":(stage/n).stat().st_size} for n in OUTPUTS},
        "license":"Original procedural NightGrid art","scope":"unlit decal texture candidates; no runtime placement",
        "color_space":{"albedo":"sRGB RGB, linear alpha","orm":"linear RGBA (AO, roughness, metal, coverage)"},
        "pending":["native decal atlas crop/import and mip bleed","receiver masks and physical scale",
                   "weather interaction and wet reflection A/B","overdraw and GPU budget","visual approval"]})
    stage.rename(final)
    print("Decal atlas candidate",len(records),"tiles",flush=True)


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out",type=Path,required=True)
    p.add_argument("--size",type=int,choices=(256,512),default=512)
    a=p.parse_args()
    produce(a.out,a.size)
