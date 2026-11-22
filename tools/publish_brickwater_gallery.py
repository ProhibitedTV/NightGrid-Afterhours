#!/usr/bin/env python3
"""Publish only existing, hash-verified engine screenshots to the README."""
import argparse
import hashlib
import struct
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GALLERY = ROOT / "docs/art/brickwater-review"
START = "<!-- brickwater-gallery:start -->"
END = "<!-- brickwater-gallery:end -->"
VIEWS = (
    ("01-alley-night-north.png", "Brickwater at 22:06 — northbound"),
    ("02-alley-daylight-matched.png", "Matched daylight view"),
    ("03-alley-night-south.png", "Night — reverse direction"),
    ("04-wet-ground-and-drain.png", "Wet ground and drain"),
    ("05-graffiti-and-service-front.png", "Graffiti and service frontage"),
    ("06-overhead-infrastructure.png", "Overhead infrastructure"),
    ("07-driving-height-approach.png", "Driving-height approach"),
)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify without modifying README")
    args = parser.parse_args()
    manifest = json.loads((GALLERY / "camera-manifest.json").read_text())
    assert manifest["renderer"] == "gl_compatibility"
    assert len(manifest["source_revision"]) == 40
    assert manifest["block"] == [-2, 1]
    assert manifest["origin"] == [-87, 0, 87]
    assert len(manifest["shots"]) == 7
    shots = {shot["file"]: shot for shot in manifest["shots"]}
    assert set(shots) == {name for name, _ in VIEWS}
    for name, _ in VIEWS:
        data = (GALLERY / name).read_bytes()
        assert data.startswith(bytes.fromhex("89504e470d0a1a0a"))
        assert len(data) == shots[name]["bytes"] > 16000
        assert struct.unpack(">II", data[16:24]) == (1280, 720)
        assert shots[name]["resolution"] == [1280, 720]
        assert hashlib.sha256(data).hexdigest() == shots[name]["sha256"]
    night, day = (shots[view[0]] for view in VIEWS[:2])
    assert night["camera"] == day["camera"] and night["look"] == day["look"]
    assert night["fov"] == day["fov"] == 70
    assert abs(night["hour"] - 22.1) < 0.001 and day["hour"] == 12
    assert night["sha256"] != day["sha256"]
    def picture(view):
        name, label = view
        return f"![{label}](docs/art/brickwater-review/{name})"
    lines = [START, "### Brickwater — revamped service alley", "",
        picture(VIEWS[0]), "", "*Northbound at 22:06.*", ""]
    for i in (1, 3, 5):
        left, right = VIEWS[i:i+2]
        lines += [f"| {left[1]} | {right[1]} |", "|:--:|:--:|",
            f"| {picture(left)} | {picture(right)} |", ""]
    lines += ["Actual development-branch Godot 4.7.2 framebuffer captures, rendered at 1280×720 using software OpenGL Compatibility. These are not concept art, the released beta, or native Forward+/Vulkan validation. [Camera positions, source revision and checksums](docs/art/brickwater-review/camera-manifest.json).", "", END]
    block = "\n".join(lines)
    file = ROOT / "README.md"
    readme = file.read_text()
    if args.check:
        assert block in readme, "README differs from verified gallery"
        print("README_BRICKWATER_GALLERY PASS: seven hash-verified image links")
        return
    if START in readme:
        assert readme.count(START) == readme.count(END) == 1
        start = readme.index(START)
        end = readme.index(END, start) + len(END)
        readme = readme[:start] + block + readme[end:]
    else:
        anchor = "\n## Play the beta\n"
        assert readme.count(anchor) == 1
        readme = readme.replace(anchor, "\n" + block + "\n" + anchor)
    file.write_text(readme, encoding="utf-8")
    print("README_BRICKWATER_GALLERY PASS: seven hash-verified image links")

if __name__ == "__main__":
    main()
