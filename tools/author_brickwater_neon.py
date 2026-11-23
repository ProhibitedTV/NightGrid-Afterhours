#!/usr/bin/env python3
"""Offline authored glass tubes, mounting hardware and enamel sign panels."""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

from author_brickwater_repair import box, emit, quad
from PIL import Image, ImageDraw, ImageFilter

OUT = Path("assets/models/nightgrid/brickwater_alley")

# Original single-stroke lettering. Coordinates run from top to bottom.
GLYPHS = {
    "A": (((0, 1), (.5, 0), (1, 1)), ((.22, .58), (.78, .58))),
    "D": (((0, 1), (0, 0), (.64, 0), (1, .24), (1, .76), (.64, 1), (0, 1)),),
    "E": (((1, 0), (0, 0), (0, 1), (1, 1)), ((0, .5), (.76, .5))),
    "F": (((1, 0), (0, 0), (0, 1)), ((0, .48), (.77, .48))),
    "G": (((1, .13), (.79, 0), (.23, 0), (0, .23), (0, .76), (.24, 1), (.81, 1), (1, .78), (1, .53), (.54, .53)),),
    "H": (((0, 0), (0, 1)), ((1, 0), (1, 1)), ((0, .5), (1, .5))),
    "I": (((.08, 0), (.92, 0)), ((.5, 0), (.5, 1)), ((.08, 1), (.92, 1))),
    "J": (((1, 0), (1, .73), (.79, 1), (.23, 1), (0, .76)),),
    "L": (((0, 0), (0, 1), (1, 1)),),
    "N": (((0, 1), (0, 0), (1, 1), (1, 0)),),
    "P": (((0, 1), (0, 0), (.78, 0), (1, .19), (1, .39), (.8, .53), (0, .53)),),
    "R": (((0, 1), (0, 0), (.78, 0), (1, .2), (1, .37), (.78, .52), (0, .52)), ((.56, .52), (1, 1))),
    "S": (((1, .08), (.79, 0), (.21, 0), (0, .18), (0, .36), (.22, .51), (.79, .51), (1, .67), (1, .84), (.78, 1), (.17, 1), (0, .91)),),
    "T": (((0, 0), (1, 0)), ((.5, 0), (.5, 1))),
    "U": (((0, 0), (0, .78), (.22, 1), (.78, 1), (1, .78), (1, 0)),),
    "W": (((0, 0), (.18, 1), (.5, .48), (.82, 1), (1, 0)),),
    "Y": (((0, 0), (.5, .52), (1, 0)), ((.5, .52), (.5, 1))),
    "2": (((0, .15), (.22, 0), (.79, 0), (1, .19), (1, .38), (0, .91), (0, 1), (1, 1)),),
    "4": (((.78, 1), (.78, 0), (0, .65), (1, .65)),),
}

RIM = [(-.49, .27), (-.49, .95), (-.44, 1.00), (.44, 1.00),
       (.49, .95), (.49, .27), (.44, .22), (-.44, .22), (-.49, .27)]


def tube(material, plate_x, points, radius, segments=6):
    """Sweep the glass cross-section along a planar stroke on the panel."""
    closed = points[0] == points[-1]
    run = points[:-1] if closed else points
    rings = []
    for i, (y, z) in enumerate(run):
        previous = run[(i - 1) % len(run)] if closed else run[max(0, i - 1)]
        following = run[(i + 1) % len(run)] if closed else run[min(len(run) - 1, i + 1)]
        dy, dz = following[0] - previous[0], following[1] - previous[1]
        norm = math.hypot(dy, dz)
        rings.append([
            (plate_x + radius * math.cos(math.tau * j / segments),
             y - dz / norm * radius * math.sin(math.tau * j / segments),
             z + dy / norm * radius * math.sin(math.tau * j / segments))
            for j in range(segments)
        ])
    edges = list(zip(rings, rings[1:]))
    if closed:
        edges.append((rings[-1], rings[0]))
    for a, b in edges:
        for j in range(segments):
            k = (j + 1) % segments
            quad(material, a[j], b[j], b[k], a[k])


def strokes(side, label, center, overall_width, height):
    letter_width = overall_width / (len(label) + (len(label) - 1) * .31)
    for i, glyph in enumerate(label):
        start = -overall_width * .5 + i * letter_width * 1.31
        for stroke in GLYPHS[glyph]:
            yield [(center + height * (.5 - down), .61 - side * (start + letter_width * across))
                   for across, down in stroke]


def lettering(side, labels):
    lines = [(labels[0], .29, .59, .135), (labels[1], .085, .59, .135), (labels[2], -.119, .62, .113)]
    for label, y, width, height in lines:
        for path in strokes(side, label, y, width, height):
            yield "tube", path, .0062
    for path in strokes(side, "24H", -.344, .28, .093):
        yield "hours", path, .0044


def blade(labels):
    # The steel box, stepped trim and mounting legs share one plane at z=0.
    # The recessed panel is backed on both sides and clears the glass tubes.
    box("steel", -.055, .055, -.59, .59, .15, 1.07)
    for side in (-1, 1):
        x0, x1 = sorted((side * .055, side * .062))
        box("enamel", x0, x1, -.548, .548, .185, 1.035)
        for y in (-.534, .534):
            box("steel", x0, x1, y - .023, y + .023, .158, 1.062)
        tube("tube", side * .071, RIM, .009, 8)
        for material, path, radius in lettering(side, labels):
            tube(material, side * .071, path, radius)
    for y in (-.435, .435):
        box("steel", -.092, .092, y - .084, y + .084, .002, .025)
        box("steel", -.040, .040, y - .033, y + .033, .019, .255)
        for x in (-.070, .070):
            box("bolt", x - .009, x + .009, y - .010, y + .010, .022, .038)
        box("steel", -.065, .065, y - .057, y + .057, .171, .224)

def emitter_mask(labels, path):
    """Rasterize the same sweeps onto the physical emitter's UV domain."""
    w, h = 240, 304
    mask = Image.new("L", (w, h))
    strokes_2d = [("tube", RIM, .009), *lettering(1, labels)]
    draw = ImageDraw.Draw(mask)
    for _, points, radius in strokes_2d:
        uv = [((.5 + (.61 - z) / .88) * w, (.5 - y / 1.10) * h) for y, z in points]
        draw.line(uv, fill=255, width=round(radius * 2 * w / .88), joint="curve")
    mask.filter(ImageFilter.GaussianBlur(.8)).save(path, optimize=True)


def main():
    specs = [
        ("repair_neon_blade", ("NIGHT", "SHIFT", "REPAIRS"), (1., .055, .19), (1., .52, .45)),
        ("laundry_neon_blade", ("JADE", "WASH", "LAUNDRY"), (.025, .62, 1.), (.45, .85, 1.)),
    ]
    models = []
    for name, labels, color, hours in specs:
        palette = {
            "steel": ("steel", (.53, .53, .48), .82, 1.),
            "enamel": ("steel", (.18, .20, .21), .87, 1.),
            "bolt": (None, (.32, .29, .23), .63, .65),
            "tube": (None, tuple(.22 + .52 * c for c in color), .23, 0.),
            "hours": (None, tuple(.22 + .52 * c for c in hours), .23, 0.),
        }
        models.append(emit(name, lambda: blade(labels), output=OUT, palette=palette,
                           emission={"tube": color, "hours": hours}, generator="NightGrid original Brickwater neon blades"))
        emitter_mask(labels, OUT / f"{name}_emitter.png")
    files = [OUT / name for row in models for name in
             (f"{row['name']}.gltf", f"{row['name']}.bin", f"{row['name']}_emitter.png")]
    result = {
        "models": models,
        "source": "tools/author_brickwater_neon.py",
        "license": "Original modeled signage and lettering. Shared steel photographs are Poly Haven CC0.",
        "photo_source": "https://polyhaven.com/a/blue_metal_plate",
        "gltf_hash_format": "UTF-8 with LF line endings",
        "sha256": {
            file.name: hashlib.sha256(
                file.read_text(encoding="utf-8").encode("utf-8") if file.suffix == ".gltf" else file.read_bytes()
            ).hexdigest()
            for file in files
        },
    }
    (OUT / "NEON_SOURCE.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
