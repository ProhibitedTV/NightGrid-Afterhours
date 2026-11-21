#!/usr/bin/env python3
"""Build *review-only* contact sheets from a verified, full gallery.

Requires Pillow. The original viewport PNGs are never modified.
Output goes outside the tracked gallery, to exports/gallery-review by default.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parent.parent
GALLERY = ROOT / "docs" / "screenshots"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=ROOT / "exports" / "gallery-review")
    args = parser.parse_args()
    out = args.out.resolve()
    if out == GALLERY or GALLERY in out.parents:
        parser.error("Review sheets must stay outside the source gallery")
    manifest = json.loads((GALLERY / "capture-manifest.json").read_text())
    entries = re.findall(r"!\[([^\]]+)\]\((\d{2}-[a-z0-9-]+\.png)\)", (GALLERY / "GALLERY.md").read_text())
    names = [name for _, name in entries]
    if len(names) != len(set(names)) or set(names) != set(manifest["images"]):
        raise SystemExit("Gallery and manifest disagree; wait for a complete fresh render")
    if set(names) != {p.name for p in GALLERY.glob("*.png")}:
        raise SystemExit("PNG file set does not match gallery")
    thumbs = []
    for label, name in entries:
        payload = (GALLERY / name).read_bytes()
        rec = manifest["images"][name]
        if hashlib.sha256(payload).hexdigest() != rec["sha256"] or len(payload) != rec["bytes"]:
            raise SystemExit(f"Manifest mismatch: {name}")
        with Image.open(GALLERY / name) as im:
            im.load()
            if im.format != "PNG" or im.width < 1100 or im.height < 600:
                raise SystemExit(f"Invalid screenshot: {name}")
            thumb = ImageOps.contain(im.convert("RGB"), (400, 225))
        thumbs.append((label, name, thumb))
    out.mkdir(parents=True, exist_ok=True)
    font = ImageFont.load_default()
    for start in range(0, len(thumbs), 12):
        group = thumbs[start:start + 12]
        sheet = Image.new("RGB", (1260, 1080), "#171b24")
        draw = ImageDraw.Draw(sheet)
        draw.text((16, 12), f"NIGHTGRID REVIEW ONLY | {manifest['source_revision'][:12]} | frames {start+1}-{start+len(group)} of {len(thumbs)}", fill="white", font=font)
        for i, (label, name, thumb) in enumerate(group):
            x, y = 12 + (i % 3) * 416, 40 + (i // 3) * 258
            sheet.paste(thumb, (x + (400-thumb.width)//2, y))
            draw.text((x, y+228), name, fill="#a6c8ff", font=font)
            draw.text((x, y+241), label.replace("—", "-"), fill="white", font=font)
        sheet.save(out / f"review-{start//12+1:02d}.png")
    (out / "review-checklist.md").write_text(
        "# Gallery visual review\n\n"
        "Source: " + manifest["source_revision"] + "\n\n"
        "Review full-size originals for framing, clipping, location, visibility and distinct composition.\n\n"
        + "\n".join(f"- [ ] {name}: {label}" for label, name in entries) + "\n",
        encoding="utf-8",
    )
    print(f"Prepared {len(thumbs)} verified frames for visual review in {out}")


if __name__ == "__main__":
    main()
