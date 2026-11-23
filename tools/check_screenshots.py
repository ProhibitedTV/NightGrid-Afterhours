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
    "08-city-bus-coachwork.png",
    "09-civilian-sedan-coachwork.png",
)
PNG_HEADER = b"\x89PNG\r\n\x1a\n"
readme = (ROOT / "README.md").read_text(encoding="utf-8")
# Preserve the original nine-capture archive and a short, current landing page.
# Historical screenshots are indexed in their own gallery, not all on README.
gallery = (IMAGES / "README.md").read_text(encoding="utf-8")
featured_manifest = json.loads(
    (IMAGES / "beta8-rc1" / "provenance.json").read_text(encoding="utf-8")
)
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
    if name not in gallery:
        issues.append(f"Original capture not indexed in gallery: {name}")
    print(f"{name}: {width}×{height}, {len(payload):,} bytes")
# Also authenticate the current screenshots shown to project visitors.
featured = featured_manifest.get("images", [])
visible = 0
for entry in featured:
    name = str(entry.get("file", ""))
    rel = f"docs/screenshots/beta8-rc1/{name}"
    if rel not in readme:
        continue
    visible += 1
    path = ROOT / rel
    if not path.is_file():
        issues.append(f"Missing featured gameplay screenshot: {rel}")
        continue
    payload = path.read_bytes()
    if not payload.startswith(PNG_HEADER) or hashlib.sha256(payload).hexdigest() != entry.get("sha256"):
        issues.append(f"Featured image does not match verified Windows capture: {rel}")
if visible == 0 and "docs/screenshots/skyboxes/GALLERY.md" not in readme:
    issues.append("README must link at least one verified playable gameplay gallery")
if issues:
    print("Screenshot preflight failed:\\n" + "\\n".join(f" - {i}" for i in issues))
    sys.exit(1)
print(f"SCREENSHOT PREFLIGHT PASS: {len(NAMES)} archived PNGs and {visible} real featured gameplay captures")
