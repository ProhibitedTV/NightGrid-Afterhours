"""Report-only tracked shipping asset inventory. Estimates are not measured VRAM."""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import struct
import subprocess
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
IMAGE_EXT = {".png", ".jpg", ".jpeg", ".webp", ".tga", ".bmp", ".exr", ".hdr"}


def block_mips(w, h, block_bytes):
    total = 0
    while True:
        total += ((w + 3) // 4) * ((h + 3) // 4) * block_bytes
        if w == h == 1:
            return total
        w, h = max(1, w // 2), max(1, h // 2)


def inspect():
    names = subprocess.check_output(["git", "ls-files", "-z", "--", "assets", "scenes"],
                                    cwd=ROOT).decode().split("\0")
    groups = defaultdict(list)
    rows = []
    for name in filter(None, names):
        path = ROOT / name
        if not path.is_file() or path.is_symlink():
            continue
        suffix = path.suffix.lower()
        if suffix not in IMAGE_EXT | {".glb", ".gltf", ".lmbake", ".wav", ".ogg", ".mp3"}:
            continue
        with path.open("rb") as f:
            h = hashlib.sha256()
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                h.update(chunk)
            digest = h.hexdigest()
        size = path.stat().st_size
        row = {"path": name, "bytes_on_disk": size, "sha256": digest}
        groups[digest].append(name)
        if suffix in IMAGE_EXT:
            try:
                with Image.open(path) as image:
                    w, h = image.size
                row.update(width=w, height=h, bc1_full_mips=block_mips(w,h,8),
                           bc7_full_mips=block_mips(w,h,16),
                           review_large_texture=max(w,h)>2048)
            except (OSError, ValueError):
                row["dimensions"] = "unavailable"
        if suffix == ".glb":
            try:
                with path.open("rb") as f:
                    magic, version, length = struct.unpack("<4sII", f.read(12))
                    n, kind = struct.unpack("<I4s", f.read(8))
                    if magic != b"glTF" or version != 2 or length != size or kind != b"JSON" or n > 16*1024**2:
                        raise ValueError("invalid or oversized GLB header")
                    gltf = json.loads(f.read(n))
                row.update(materials=len(gltf.get("materials", [])),
                           surfaces=sum(len(m["primitives"]) for m in gltf.get("meshes", [])),
                           embedded_images=sum("bufferView" in i for i in gltf.get("images", [])))
            except (OSError, ValueError, KeyError, struct.error):
                row["glb_metadata"] = "unavailable"
        rows.append(row)
    return {"scope": "tracked source asset files; not PCK dependency closure or measured residency",
            "total_bytes": sum(r["bytes_on_disk"] for r in rows), "assets": rows,
            "duplicate_content": [v for v in groups.values() if len(v)>1]}


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()
    out = a.output.resolve()
    if ROOT in out.parents:
        p.error("report must be outside checkout")
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_suffix(".partial")
    tmp.write_text(json.dumps(inspect(), indent=2) + "\n", encoding="utf-8")
    tmp.replace(out)
