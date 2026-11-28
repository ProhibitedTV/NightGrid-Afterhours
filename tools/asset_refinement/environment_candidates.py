"""Original procedural linear HDR environment candidates, no external images.
Not measured radiance or a city capture. Direct sun remains a separate light.
"""
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
# zenith, horizon, ground, glow azimuth, glow RGB, cloud cover
PRESETS={
    "clear_day":((.22,.48,1.2),(1.05,1.12,1.2),(.16,.19,.22),90,(2.2,1.8,1.3),.10),
    "dawn_clear":((.10,.19,.42),(.85,.32,.16),(.045,.05,.08),0,(2.8,1.0,.32),.16),
    "dawn_overcast":((.13,.19,.27),(.53,.37,.31),(.06,.065,.08),0,(1.25,.60,.36),.82),
    "afternoon_clouds":((.26,.51,.99),(.93,1.05,1.13),(.18,.20,.22),110,(1.8,1.5,1.2),.48),
    "evening_clear":((.12,.17,.39),(1.05,.40,.19),(.06,.045,.065),180,(3.4,1.1,.30),.18),
    "overcast_day":((.56,.65,.74),(.79,.82,.87),(.13,.15,.17),90,(.48,.46,.40),.88),
    "storm_day":((.13,.17,.24),(.32,.36,.42),(.045,.055,.075),90,(.18,.17,.16),.98),
    "moonlit_night":((.008,.013,.034),(.025,.039,.07),(.004,.007,.013),230,(.20,.25,.40),.12),
    "overcast_night":((.014,.018,.027),(.055,.040,.039),(.008,.010,.015),230,(.02,.025,.035),.85),
    "storm_night":((.005,.009,.016),(.025,.028,.043),(.004,.005,.008),230,(.012,.018,.025),.98),
}


def radiance(preset, width):
    if width<16 or width%2:
        raise ValueError("Even panorama width required")
    height=width//2
    zenith,horizon,ground,azimuth,glow,cover=PRESETS[preset]
    # Pixel centers and a spherical field give a periodic horizontal seam.
    phi=(np.arange(width)+.5)*2*np.pi/width
    theta=(np.arange(height)+.5)*np.pi/height
    y=np.cos(theta)[:,None]
    x=np.sin(theta)[:,None]*np.cos(phi)[None,:]
    z=np.sin(theta)[:,None]*np.sin(phi)[None,:]
    upper=np.maximum(y,0)
    lower=np.maximum(-y,0)
    rgb=np.array(horizon)[None,None,:]*(1-upper[...,None]**.55)+np.array(zenith)[None,None,:]*upper[...,None]**.55
    rgb=rgb*(1-lower[...,None]**.45)+np.array(ground)[None,None,:]*lower[...,None]**.45
    # Broad horizon glow, no sharp sun or moon disc: avoid baking directional
    # illumination that the live game already represents with its sun.
    a=math.radians(azimuth)
    facing=np.maximum(x*math.cos(a)+z*math.sin(a),0)
    lobe=facing**10*np.exp(-((y-.12)/.23)**2)*(y>=0)
    rgb=rgb+np.array(glow)[None,None,:]*lobe[...,None]
    # Smooth multi-scale spherical cloud variation, intentionally stylized.
    field=(np.sin(13*x+5*z+3*y)+.55*np.sin(27*z-11*x+7*y)+
           .27*np.sin(53*x+23*z-9*y)+.13*np.sin(89*z+51*x))
    clouds=np.clip((field+cover*2-1.2)*.8,0,1)*np.clip(upper*4,0,1)
    cloud_tint=np.array(horizon)*(.72 if cover>.8 else 1.22)
    rgb=rgb*(1-clouds[...,None]*.66)+cloud_tint[None,None,:]*clouds[...,None]*.66
    rgb=np.asarray(rgb,dtype=np.float32)
    if rgb.shape!=(height,width,3) or not np.isfinite(rgb).all() or rgb.min()<0:
        raise ValueError("Invalid HDR environment")
    return rgb


def rgbe(rgb):
    brightest=rgb.max(axis=2)
    mantissa,exponent=np.frexp(brightest)
    factor=np.divide(mantissa*256,brightest,out=np.zeros_like(brightest),where=brightest>1e-32)
    out=np.zeros((*brightest.shape,4),dtype=np.uint8)
    out[:,:,:3]=np.clip(rgb*factor[...,None],0,255).astype(np.uint8)
    out[:,:,3]=np.where(brightest>1e-32,np.clip(exponent+128,0,255),0).astype(np.uint8)
    return out


def write_hdr(path,rgb):
    h,w,_=rgb.shape
    if not 8<=w<=32767:
        raise ValueError("RGBE scanline width unsupported")
    encoded=rgbe(rgb)
    # Radiance new-style planar RLE, literal packets <=128 bytes.
    with path.open("xb") as f:
        f.write(f"#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n-Y {h} +X {w}\n".encode("ascii"))
        for row in encoded:
            f.write(bytes((2,2,w>>8,w&255)))
            for channel in range(4):
                values=row[:,channel].tobytes()
                for start in range(0,w,128):
                    chunk=values[start:start+128]
                    f.write(bytes((len(chunk),)))
                    f.write(chunk)


def produce(out,width):
    out=out.resolve()
    if out==ROOT or ROOT in out.parents or out in ROOT.parents:
        raise ValueError("Use private candidate directory")
    out.mkdir(parents=True,exist_ok=True)
    for preset in PRESETS:
        settings={"preset":preset,"width":width,"generator_sha256":sha(Path(__file__))}
        final=out/preset
        if final.exists():
            doc=json.loads((final/"candidate.json").read_text())
            if doc["settings"]!=settings or set(doc["outputs"])!={"environment.hdr","preview.jpg"}:
                raise ValueError("Existing environment mismatch: "+preset)
            for name,rec in doc["outputs"].items():
                checked(final,name,rec["sha256"])
            print("SKIP verified",preset,flush=True)
            continue
        stage=Path(tempfile.mkdtemp(prefix="."+preset+".partial-",dir=out))
        rgb=radiance(preset,width)
        write_hdr(stage/"environment.hdr",rgb)
        # Preview only: exposure-independent fixed Reinhard curve + sRGB.
        display=np.power(rgb/(1+rgb),1/2.2)
        img=Image.fromarray(np.uint8(np.clip(display*255,0,255)),"RGB")
        img.thumbnail((1024,512))
        img.save(stage/"preview.jpg",quality=88)
        stats={"linear_min":float(rgb.min()),"linear_max":float(rgb.max()),
               "linear_mean":float(rgb.mean()),"fraction_over_one":float((rgb>1).mean()),
               "dimensions":[width,width//2]}
        atomic(stage/"candidate.json",{"schema":1,"status":"candidate-only","settings":settings,
               "outputs":{n:{"sha256":sha(stage/n),"bytes":(stage/n).stat().st_size}
                          for n in ("environment.hdr","preview.jpg")},
               "radiance":stats,"license":"Original procedural NightGrid art",
               "scope":"synthetic scene-linear RGBE sky, not measured/calibrated HDR or local scene reflection",
               "pending":["native Godot HDR import and radiance convolution",
                          "orientation and energy calibration","day/night transition and reflection A/B",
                          "texture residency and shader timing","visual approval"]})
        stage.rename(final)
        print("HDR environment candidate",preset,stats,flush=True)


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out",type=Path,required=True)
    p.add_argument("--width",type=int,choices=(512,1024,2048),default=1024)
    a=p.parse_args()
    produce(a.out,a.width)
