#!/usr/bin/env python3
"""Verify new expanded captures without publishing over historical screenshots."""
import hashlib
import json
import struct
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
out = Path(sys.argv[1])
manifest = json.loads((out / "capture-manifest.json").read_text())
baseline = json.loads((root / "docs/screenshots/archive-20261121/capture-manifest.json").read_text())
records = manifest["images"]
assert len(records) == 33 and set(records) == set(baseline["images"])
assert set(records) == {p.name for p in out.glob("*.png")}
assert manifest["source_revision"]
seen = set()
for name, record in records.items():
    data = (out / name).read_bytes()
    assert data.startswith(b"\x89PNG\r\n\x1a\n") and data[12:16] == b"IHDR", name
    w, h = struct.unpack(">II", data[16:24])
    assert w >= 1100 and h >= 600 and len(data) > 16000, name
    digest = hashlib.sha256(data).hexdigest()
    assert digest == record["sha256"] and digest not in seen and len(data) == record["bytes"], name
    seen.add(digest)
print("EXPANDED_CAPTURE PASS: 33 distinct real framebuffer files, visual review still required")
