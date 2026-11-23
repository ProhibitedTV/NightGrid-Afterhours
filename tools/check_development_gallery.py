#!/usr/bin/env python3
"""Verify copied native gameplay captures and their Git blob provenance."""
from __future__ import annotations

import hashlib
import json
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FOLDER = ROOT / "docs/screenshots/development"
SOURCE = FOLDER / "provenance.json"
GALLERY = (FOLDER / "GALLERY.md").read_text(encoding="utf-8")
README = (ROOT / "README.md").read_text(encoding="utf-8")
record = json.loads(SOURCE.read_text(encoding="utf-8"))
assert record["schema"] == 1
assert record["renderer"] == "Forward+/Vulkan"
assert record["resolution"] == [1920, 1080]
files = record["images"]
assert len(files) == 13, "Native gallery expects 13 selected images"
listed = set()
for item in files:
    name = item["file"]
    path = FOLDER / name
    assert name not in listed and name.startswith(("brickwater/", "physical/", "courier/"))
    assert ".." not in Path(name).parts
    listed.add(name)
    assert re.fullmatch("[0-9a-f]{40}", item["source_commit"])
    assert re.fullmatch("[0-9a-f]{40}", item["git_blob_sha"])
    assert item["source_path"].endswith(name.split("/")[-1])
    raw = path.read_bytes()
    assert raw.startswith(bytes.fromhex("89504e470d0a1a0a")) and raw[12:16] == b"IHDR", name
    assert struct.unpack(">II", raw[16:24]) == (1920, 1080), name
    assert raw.endswith(bytes.fromhex("49454e44ae426082")), name
    blob = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
    assert blob == item["git_blob_sha"], f"Git blob content mismatch: {name}"
    assert f"]({name})" in GALLERY, f"Missing gallery image: {name}"
gallery_images = set(re.findall(r"!\[[^\]]*\]\(([^)]+\.png)\)", GALLERY))
assert gallery_images == listed, "Gallery image links and provenance must match"
assert "docs/screenshots/development/GALLERY.md" in README
for name in ("brickwater/01-alley-night-north.png", "courier/day-face-after.png", "physical/east-gardens-platform.png"):
    assert "docs/screenshots/development/" + name in README, name
print(f"NATIVE_SHOWCASE PASS: {len(files)} exact unmodified Git PNG blobs; links, dimensions and provenance verified")
