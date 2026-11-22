#!/usr/bin/env python3
"""Publish only existing, hash-verified engine screenshots to the README."""
import hashlib
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
    manifest = json.loads((GALLERY / "camera-manifest.json").read_text())
    assert manifest["renderer"] == "gl_compatibility"
    assert manifest["source_revision"]
    shots = {shot["file"]: shot for shot in manifest["shots"]}
    assert set(shots) == {name for name, _ in VIEWS}
    for name, _ in VIEWS:
        data = (GALLERY / name).read_bytes()
        assert data.startswith(bytes.fromhex("89504e470d0a1a0a"))
        assert len(data) == shots[name]["bytes"] > 16000
        assert hashlib.sha256(data).hexdigest() == shots[name]["sha256"]
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
