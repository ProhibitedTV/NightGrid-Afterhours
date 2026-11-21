#!/usr/bin/env python3
"""Check checked-in *actual framebuffer PNGs*, not placeholder links/assets."""
from __future__ import annotations

import hashlib
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IMAGES = ROOT / "docs" / "screenshots"
NAMES = (
    "01-morrow-bay-neon-night.png",
    "02-vesper-market-nightlife.png",
    "03-m-line-helix-terminal.png",
    "04-horizon-commons-daylight.png",
    "05-quay-fresh-interior.png",
    "06-title-menu.png",
    "07-city-map-menu.png",
)
PNG_HEADER = b"\x89PNG\r\n\x1a\n"
readme = (ROOT / "README.md").read_text(encoding="utf-8")
issues: list[str] = []
seen_hashes: set[str] = set()
manifest = json.loads((IMAGES / "capture-manifest.json").read_text(encoding="utf-8"))
if set(manifest.get("images", {})) != set(NAMES):
    issues.append("Capture manifest image set differs from expected gallery")
for name in NAMES:
    path = IMAGES / name
    if not path.is_file():
        issues.append(f"Missing actual screenshot: {path}")
        continue
    payload = path.read_bytes()
    if not payload.startswith(PNG_HEADER) or payload[12:16] != b"IHDR":
        issues.append(f"Not a PNG: {name}")
        continue
    width, height = struct.unpack(">II", payload[16:24])
    if width < 1100 or height < 600 or len(payload) < 16000:
        issues.append(f"Screenshot too small/invalid: {name}: {width}×{height}, {len(payload)} B")
    if payload[-12:-8] != b"\x00\x00\x00\x00" or not payload.endswith(b"IEND\xaeB\x60\x82"):
        issues.append(f"Malformed PNG ending: {name}")
    fingerprint = hashlib.sha256(payload).hexdigest()
    record = manifest.get("images", {}).get(name, {})
    if record.get("sha256") != fingerprint or record.get("bytes") != len(payload):
        issues.append(f"Capture manifest mismatch: {name}")
    if fingerprint in seen_hashes:
        issues.append(f"Duplicate image contents: {name}")
    seen_hashes.add(fingerprint)
    if f"docs/screenshots/{name}" not in readme:
        issues.append(f"README does not display the real capture: {name}")
    print(f"{name}: {width}×{height}, {len(payload):,} bytes")
if issues:
    print("Screenshot preflight failed:\n" + "\n".join(f" - {i}" for i in issues))
    sys.exit(1)
print(f"SCREENSHOT PREFLIGHT PASS: {len(NAMES)} genuine PNG assets linked in README")
