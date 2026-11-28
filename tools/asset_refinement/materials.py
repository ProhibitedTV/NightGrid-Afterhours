"""Offline, deterministic material candidates from visual-001 reference images.

The derived maps are artistic estimates, never measured physical properties.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import sys

import numpy as np
from PIL import Image, __version__ as PIL_VERSION
from refine import KEY, sha, load, write, png_size

# roughness, metallic, luminance-to-height sign, normal detail strength.
# Mixed/coated/patinated surfaces deliberately use dielectric defaults until
# an artist supplies a metal mask; no false inference of material segmentation.
PROFILES = {
    "aged-red-brick-with-mortar": (.82, 0, 1, 2.0),
    "wet-dark-asphalt-aggregate": (.28, 0, 1, 1.2),
    "dry-asphalt-aggregate": (.85, 0, 1, 1.8),
    "brushed-stainless-steel": (.38, 1, 1, .45),
    "weathered-painted-galvanized-metal": (.65, 0, 1, .7),
    "chipped-industrial-blue-enamel": (.55, 0, 1, .7),
    "black-rubber-tire-tread": (.83, 0, 1, 2.0),
    "worn-dark-leather": (.63, 0, 1, .9),
    "office-carpet-tile-charcoal": (.92, 0, 1, 1.1),
    "polished-gray-terrazzo": (.3, 0, 1, .25),
    "weathered-gray-concrete": (.86, 0, 1, 1.4),
    "salt-stained-coastal-concrete": (.88, 0, 1, 1.4),
    "warm-oak-veneer": (.57, 0, 1, .55),
    "dark-stained-walnut": (.56, 0, 1, .55),
    "woven-black-technical-fabric": (.86, 0, 1, 1.2),
    "washed-blue-denim": (.89, 0, 1, 1.2),
    "cream-ceramic-wall-tile": (.3, 0, 1, .5),
    "black-anti-slip-rubber-mat": (.81, 0, 1, 1.5),
    "scratched-plastic": (.59, 0, 1, .5),
    "aged-copper-patina": (.72, 0, 1, .55),
    "corrugated-industrial-steel": (.53, 1, 1, 1.0),
    "peeling-painted-plaster": (.88, 0, 1, 1.1),
    "damp-cobblestone": (.44, 0, 1, 1.9),
    "weathered-wood-decking": (.82, 0, 1, 1.1),
    "rubberized-coastal-roof-membrane": (0.86, 0, 1, 0.75),
    "exposed-aggregate-sidewalk": (0.92, 0, 1, 1.6),
    "powder-coated-charcoal-aluminum": (0.62, 0, 1, 0.35),
    "brushed-copper-sheet": (0.4, 1, 1, 0.3),
    "salt-weathered-dock-timber": (0.9, 0, 1, 1.5),
    "acoustic-felt-panel": (0.96, 0, 1, 0.65),
    "commercial-vinyl-floor": (0.55, 0, 1, 0.3),
    "worn-ceramic-subway-tile": (0.4, 0, 1, 0.9),
}
MAPS = ("basecolor.png", "normal.png", "roughness.png", "metallic.png",
        "height.png", "ao-estimate.png", "orm.png")


def material_source(folder):
    if not KEY.fullmatch(folder.name) or ".." in folder.name or folder.is_symlink():
        raise ValueError("Unsafe candidate")
    image, meta = folder / "concept.png", folder / "image.json"
    if not image.is_file() or not meta.is_file():
        return None
    if image.is_symlink() or meta.is_symlink():
        raise ValueError("Symlink source")
    info = load(meta)
    job = info["job"]
    if job["kind"] != "material":
        return None
    if job["key"] != folder.name or info["sha256"] != sha(image):
        raise ValueError("Source hash or job mismatch")
    kind = job["id"].removeprefix("material.")
    if job["id"] != "material." + kind or kind not in PROFILES:
        raise ValueError("Unprofiled material: " + kind)
    return {"image": sha(image), "metadata": sha(meta), "kind": kind}


def tile(a):
    # Crossfade the original edges against the middle of the image. The
    # shifted image's discontinuity lands in the untouched central region.
    for axis in (0, 1):
        n = a.shape[axis]
        width = max(2, n // 8)
        distance = np.minimum(np.arange(n), np.arange(n)[::-1])
        t = np.clip(distance / (width - 1), 0, 1)
        w = (1 - t*t*(3-2*t)).reshape((-1,1,1) if axis == 0 else (1,-1,1))
        shifted = np.roll(a, n // 2, axis=axis)
        a = a * (1-w) + shifted * w
    return a


def derive(rgb, profile):
    rough, metal, sign, strength = profile
    color = tile(rgb.astype(np.float32) / 255.)
    linear = np.where(color <= .04045, color/12.92, ((color+.055)/1.055)**2.4)
    lum = linear @ np.array([.2126,.7152,.0722], dtype=np.float32)
    low = sum(np.roll(np.roll(lum, y, 0), x, 1)
              for y in (-4,0,4) for x in (-4,0,4))/9
    h = np.clip(.5 + sign*(lum-low)*1.5, 0, 1)
    dx = (np.roll(h,-1,1)-np.roll(h,1,1))*.5
    dy = (np.roll(h,-1,0)-np.roll(h,1,0))*.5
    # Image rows point down; OpenGL tangent Y points up.
    norm = np.stack([-dx*strength, dy*strength, np.ones_like(h)], -1)
    norm /= np.linalg.norm(norm, axis=-1, keepdims=True)
    roughness = np.clip(rough + .12*(h-.5), .04, 1)
    metallic = np.full_like(h, metal)
    # Neutral AO is safe for rendering. Separate cavity estimate is review-only.
    cavity = np.clip(1 - np.maximum(0, low-lum)*.65, .7, 1)
    orm = np.stack([np.ones_like(h), roughness, metallic], -1)
    maps = (color, norm*.5+.5, roughness, metallic, h, cavity, orm)
    return dict(zip(MAPS, (np.rint(np.clip(a,0,1)*255).astype(np.uint8) for a in maps)))


def verified_material(folder, signature, settings):
    try:
        info = load(folder / "material.json")
        return (info["status"] == "unapproved" and info["signature"] == signature
                and info["settings"] == settings and set(info["outputs"]) == set(MAPS)
                and all(sha(folder/name) == info["outputs"][name]["sha256"]
                        and png_size(folder/name) == (settings["size"],)*2 for name in MAPS))
    except (ValueError, OSError, KeyError, TypeError):
        return False


def run(raw, out, size, limit=0):
    if not (raw/"candidates").is_dir() or raw == out or raw in out.parents or out in raw.parents:
        raise ValueError("Output must be separate from raw library")
    out.mkdir(parents=True, exist_ok=True)
    lock = out/".material.lock"
    lock.mkdir()
    attempted = cached = failed = 0
    rows = []
    try:
        for folder in sorted((raw/"candidates").iterdir()):
            if not folder.is_dir() or not folder.name.startswith("material."):
                continue
            if limit and attempted >= limit:
                break
            try:
                src = material_source(folder)
                if src is None:
                    rows.append({"candidate":folder.name,"status":"incomplete"})
                    continue
                settings = {"source":src,"size":size,"profile":list(PROFILES[src["kind"]]),
                            "script":sha(Path(__file__)), "numpy":np.__version__,
                            "pillow":PIL_VERSION}
                sig = hashlib.sha256(json.dumps(settings,sort_keys=True).encode()).hexdigest()
                parent = out/folder.name
                final = parent/sig
                if verified_material(final,sig,settings):
                    cached += 1
                else:
                    if final.exists():
                        raise ValueError("Existing output invalid; quarantine manually")
                    attempted += 1
                    if shutil.disk_usage(out).free < 5*1024**3:
                        raise RuntimeError("NAS reserve below 5 GiB")
                    parent.mkdir(exist_ok=True)
                    stage = Path(tempfile.mkdtemp(prefix=".stage-",dir=parent))
                    try:
                        with Image.open(folder/"concept.png") as im:
                            rgb = np.array(im.convert("RGB").resize((size,size),Image.Resampling.LANCZOS))
                        maps = derive(rgb,PROFILES[src["kind"]])
                        outputs = {}
                        for name, pixels in maps.items():
                            Image.fromarray(pixels).save(stage/name)
                            outputs[name] = {"sha256":sha(stage/name),"size":[size,size],
                                             "color_space":"sRGB" if name=="basecolor.png" else "linear"}
                        if material_source(folder) != src:
                            raise ValueError("Source changed during bake")
                        write(stage/"material.json", {"candidate":folder.name,"signature":sig,
                              "status":"unapproved","settings":settings,"outputs":outputs,
                              "normal_convention":"OpenGL +Y",
                              "orm_channels":["neutral AO","estimated roughness","profile metallic"],
                              "limitations":["source color may include lighting","height and normal are luminance-derived",
                                             "AO estimate not geometry-based","tile seams and physical scale need review",
                                             "mixed metal masks and true PBR properties need authoring"]})
                        if not verified_material(stage,sig,settings):
                            raise ValueError("Invalid material bake")
                        stage.rename(final)
                    finally:
                        if stage.exists():
                            shutil.rmtree(stage)
                rows.append({"candidate":folder.name,"status":"review-required","signature":sig,
                             "manifest_sha256":sha(final/"material.json")})
            except Exception as exc:
                failed += 1
                print("Material failed:",folder.name,exc,file=sys.stderr)
                rows.append({"candidate":folder.name,"status":"failed","error":str(exc)})
        index = out/("review-%d.json" % size)
        tmp = index.with_suffix(".tmp")
        write(tmp,{"status":"unapproved","size":size,"partial":bool(limit),"rows":rows})
        tmp.replace(index)
    finally:
        lock.rmdir()
    print("Materials: attempted=%d cached=%d failed=%d"%(attempted,cached,failed))
    return int(bool(failed))


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--raw",required=True,type=Path)
    p.add_argument("--output",required=True,type=Path)
    p.add_argument("--size",type=int,choices=[128,512,1024,2048],default=1024)
    p.add_argument("--limit",type=int,default=0)
    args = p.parse_args()
    if args.limit < 0:
        p.error("Negative limit")
    sys.exit(run(args.raw.resolve(),args.output.resolve(),args.size,args.limit))
