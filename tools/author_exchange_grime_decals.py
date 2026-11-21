#!/usr/bin/env python3
"""Create TWO bounded 512px photo-derived road decals for Central Exchange.

Based on the already committed Poly Haven CC0 bitumen photographic PBR scans.
Generate once on the named art branch; normal game builds consume pinned PNGs.
Alpha masks are original, deterministic industrial oil/grit shapes; this is
NOT a new runtime road shader, no global wet mirror or procedural box layer.
"""
from __future__ import annotations
import hashlib
import json
import math
from pathlib import Path
from PIL import Image

INPUT = Path("assets/pbr/polyhaven")
OUTPUT = Path("assets/pbr/nightgrid/central_exchange")
SOURCE = "bitumen"
SIZE = 512


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def clamp(x: float) -> float:
    return max(0.0, min(1.0, x))


def make(kind: str, photo: Image.Image, normal: Image.Image, rough: Image.Image):
    albedo_data = []
    orm_data = []
    for y in range(SIZE):
        ny = (y + 0.5 - SIZE * 0.5) / (SIZE * 0.5)
        for x in range(SIZE):
            nx = (x + 0.5 - SIZE * 0.5) / (SIZE * 0.5)
            turbulence = (math.sin(nx * 16.7 + ny * 5.9) +
                          math.cos(nx * 9.7 - ny * 19.3)) * 0.027
            radius = math.sqrt((nx * 0.98) ** 2 + (ny * 1.18) ** 2) + turbulence
            taper = clamp((1.02 - radius) / 0.24)
            tint = 0.62 if kind == "OIL" else 0.79
            noise = ((x * 53 + y * 73 + x * y * 17) % 149) / 148.0
            puncture = 0.45 + 0.55 * noise if kind == "GRIT" else 0.78 + 0.22 * noise
            alpha = int(255 * taper * taper * puncture * (0.90 if kind == "OIL" else 0.70))
            rgb = photo.getpixel((x, y))
            albedo_data.append((int(rgb[0] * tint), int(rgb[1] * tint),
                                int(rgb[2] * tint), alpha))
            photographic_roughness = rough.getpixel((x, y))
            # PBR ORM: R=AO, G=roughness, B=metalness. Oil is smooth but
            # never an everywhere-wet, chrome-like slab; grit is rough.
            rm = int(clamp((0.26 if kind == "OIL" else 0.72) +
                           photographic_roughness / 255.0 * 0.21) * 255)
            orm_data.append((255, rm, 0, 255))
    albedo = Image.new("RGBA", (SIZE, SIZE))
    albedo.putdata(albedo_data)
    orm = Image.new("RGBA", (SIZE, SIZE))
    orm.putdata(orm_data)
    outputs = {
        f"{kind.lower()}_albedo_512.png": albedo,
        f"{kind.lower()}_orm_512.png": orm,
        f"{kind.lower()}_normal_512.png": normal
    }
    for name, image in outputs.items():
        image.save(OUTPUT / name, optimize=True)


def main():
    sources = [
        INPUT / f"{SOURCE}_diffuse_2k.jpg",
        INPUT / f"{SOURCE}_nor_gl_2k.png",
        INPUT / f"{SOURCE}_rough_2k.png"
    ]
    for source in sources:
        if not source.is_file():
            raise ValueError(f"Missing official previously pinned CC0 source: {source}")
    photo = Image.open(sources[0]).convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    normal = Image.open(sources[1]).convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    rough = Image.open(sources[2]).convert("L").resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for kind in ("OIL", "GRIT"):
        make(kind, photo, normal, rough)
    files = {path.name: {"bytes": path.stat().st_size, "sha256": digest(path)}
             for path in sorted(OUTPUT.glob("*.png"))}
    if len(files) != 6 or sum(f["bytes"] for f in files.values()) >= 8_000_000:
        raise ValueError("Bad atlas outputs or texture-memory budget")
    origin = {
        "artist": "NightGrid original, alpha masks derived from photographed bitumen",
        "licensed_input": "Poly Haven Bitumen CC0 1.0",
        "license_url": "https://polyhaven.com/license",
        "source_page": "https://polyhaven.com/a/bitumen",
        "input_sha256": {p.name: digest(p) for p in sources},
        "generator_sha256": digest(Path("tools/author_exchange_grime_decals.py")),
        "resolution": SIZE,
        "files": files,
        "runtime_download_required": False,
        "notes": "Four projected road-side decals, no gameplay physics or global wetness"
    }
    (OUTPUT / "SOURCE.json").write_text(json.dumps(origin, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("PHOTO_ROAD_DECALS PASS: six 512px committed normal/ORM/albedo PNGs,",
          sum(f["bytes"] for f in files.values()), "bytes; CC0 photo sources audited")


if __name__ == "__main__":
    main()
