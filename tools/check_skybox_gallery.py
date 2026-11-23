#!/usr/bin/env python3
"""Verify eight genuine in-game sky/weather PNGs, hashes and public gallery."""
from __future__ import annotations

import hashlib
import json
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FOLDER = ROOT / "docs/screenshots/skyboxes"
CAPTURE = json.loads((FOLDER / "capture.json").read_text(encoding="utf-8"))
GALLERY = (FOLDER / "GALLERY.md").read_text(encoding="utf-8")
README = (ROOT / "README.md").read_text(encoding="utf-8")
EXPECTED = [
    ("01-dawn-clear.png", "clear", "dawn_clear"),
    ("02-afternoon-sunny.png", "clear", "clear_day"),
    ("03-afternoon-cloudy.png", "cloudy", "afternoon_clouds"),
    ("04-evening-golden.png", "clear", "evening_clear"),
    ("05-night-clear.png", "clear", "moonlit_night"),
    ("06-overcast.png", "overcast", "overcast_day"),
    ("07-rain.png", "rain", "storm_day"),
    ("08-storm.png", "storm", "storm_day"),
]
assert re.fullmatch(r"[0-9a-f]{40}", CAPTURE["source_revision"])
assert CAPTURE["renderer"] == "gl_compatibility", "Do not mislabel Linux Mesa images as Vulkan"
assert CAPTURE["resolution"] == [1600, 900]
assert CAPTURE["district"] == "Brickwater"
assert [v["file"] for v in CAPTURE["shots"]] == [v[0] for v in EXPECTED]
assert "docs/screenshots/skyboxes/GALLERY.md" in README, "README must link full skybox gallery"
assert len([s for s in EXPECTED if "docs/screenshots/skyboxes/" + s[0] in README]) >= 4, (
    "New sky imagery should replace the old homepage featured screenshots"
)
hashes = set()
for item, (name, weather, preset) in zip(CAPTURE["shots"], EXPECTED):
    assert item["weather"] == weather and item["selected_sky"] == preset, name
    path = FOLDER / name
    raw = path.read_bytes()
    assert raw[:8] == bytes.fromhex("89504e470d0a1a0a") and raw[12:16] == b"IHDR", name
    assert struct.unpack(">II", raw[16:24]) == (1600, 900), name
    assert raw.endswith(bytes.fromhex("49454e44ae426082")) and len(raw) > 16000, name
    digest = hashlib.sha256(raw).hexdigest()
    assert digest == item["sha256"] and len(raw) == item["bytes"], name
    assert digest not in hashes, f"Two weather captures have identical pixels: {name}"
    hashes.add(digest)
    assert f"]({name})" in GALLERY, f"Missing game capture link: {name}"
print("SKYBOX_SHOWCASE PASS: 8 genuine 1600x900 game frames, hashes, presets and README")
