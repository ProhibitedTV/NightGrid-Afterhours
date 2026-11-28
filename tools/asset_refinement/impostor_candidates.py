"""Build and resume 16-view botanical impostor atlas candidates on the NAS."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
from PIL import Image
from botanical_candidates import SPECIES
from refine import sha
from production_evidence import checked
from factory_ledger import atomic

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
CHANNELS = ("albedo", "normal")


def pack(views, channel, out, size):
    # Per-view transparent border avoids sampling adjacent views at top mips.
    # Further mip-safe dilation and alpha coverage testing are promotion gates.
    atlas = Image.new("RGBA", (size*4, size*4))
    boxes = []
    for i in range(16):
        with Image.open(views / f"{channel}-{i:02d}.png") as raw:
            img = raw.convert("RGBA")
        if img.size != (size,size):
            raise ValueError("Incorrect view dimensions")
        alpha = img.getchannel("A")
        bounds = alpha.getbbox()
        if bounds is None or bounds[0] < 2 or bounds[1] < 2 or bounds[2] > size-2 or bounds[3] > size-2:
            raise ValueError("Empty or clipped impostor view")
        hist = alpha.histogram()
        coverage = sum(hist[128:]) / (size*size)
        if not .001 < coverage < .85:
            raise ValueError("Unexpected impostor coverage")
        x,y = i%4*size,i//4*size
        atlas.paste(img,(x,y))
        boxes.append({"index": i, "tile_xy": [x,y], "coverage": coverage})
    atlas.save(out)
    return boxes


def produce(bank, out, size, samples):
    bank, out = bank.resolve(), out.resolve()
    if ROOT in out.parents or out == ROOT or out in ROOT.parents or bank in out.parents or out in bank.parents or out == bank:
        raise ValueError("Use separate private candidate directory")
    source_manifest = json.loads((bank / "SOURCE.json").read_text())
    out.mkdir(parents=True, exist_ok=True)
    if shutil.which("blender") is None:
        raise RuntimeError("Existing Blender required")
    version = subprocess.check_output(["blender", "--version"], text=True).splitlines()[0]
    for species in SPECIES:
        name = species+"_lod0.glb"
        source = bank/name
        source_hash = source_manifest["files"][name]["sha256"]
        checked(bank, name, source_hash)
        settings = {"species":species, "source_sha256":source_hash,
                    "renderer_sha256":sha(HERE/"render_impostor_views.py"),
                    "packer_sha256":sha(Path(__file__)), "blender":version,
                    "tile_size":size, "samples":samples, "views":16}
        final = out/species
        if final.exists():
            doc = json.loads((final/"candidate.json").read_text())
            if doc["settings"] != settings or set(doc["outputs"]) != {"albedo.png","normal.png","camera.json"}:
                raise ValueError("Existing candidate settings changed: "+species)
            for n, rec in doc["outputs"].items():
                checked(final,n,rec["sha256"])
            print("SKIP verified impostor", species, flush=True)
            continue
        if shutil.disk_usage(out).free < 10*1024**3:
            raise RuntimeError("NAS reserve breached")
        stage = Path(tempfile.mkdtemp(prefix="."+species+".partial-",dir=out))
        views = stage/"views"
        subprocess.run(["blender","-b","-t","2","--python-exit-code","1","--python",
                        str(HERE/"render_impostor_views.py"),"--","--source",str(source),
                        "--out",str(views),"--size",str(size),"--samples",str(samples)],check=True)
        tiles = {ch: pack(views,ch,stage/(ch+".png"),size) for ch in CHANNELS}
        if any(abs(a["coverage"]-b["coverage"])>.02 for a,b in zip(tiles["albedo"],tiles["normal"])):
            raise ValueError("Albedo/normal coverage mismatch")
        shutil.copy2(views/"camera.json",stage/"camera.json")
        checked(bank,name,source_hash)
        outputs = {n:{"sha256":sha(stage/n),"bytes":(stage/n).stat().st_size}
                   for n in ("albedo.png","normal.png","camera.json")}
        atomic(stage/"candidate.json",{"schema":1,"status":"candidate-only","settings":settings,
               "outputs":outputs,"tiles":tiles,
               "pending":["native shader and orientation","alpha cutoff and mip bleed",
                          "distance transitions","moving sunlight","overdraw and GPU timings","visual approval"]})
        # Individual source views are private and retained for inspection.
        stage.rename(final)
        print("IMPOSTOR candidate",species,flush=True)


if __name__ == "__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--bank",type=Path,required=True)
    p.add_argument("--out",type=Path,required=True)
    p.add_argument("--size",type=int,choices=(256,512),default=512)
    p.add_argument("--samples",type=int,choices=(8,16,32,64),default=32)
    a=p.parse_args()
    produce(a.bank,a.out,a.size,a.samples)
