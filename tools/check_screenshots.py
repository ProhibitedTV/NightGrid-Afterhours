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
    "10-central-exchange-daylight.png",
    "11-brickwater-streetfront.png",
    "12-afterhours-streetfront.png",
    "13-north-quay-exchange.png",
    "14-pier-nine-depot.png",
    "15-southworks-hall.png",
    "16-lantern-cup-exterior.png",
    "17-prism-club-exterior.png",
    "18-static-room-exterior.png",
    "19-dock-nine-social.png",
    "20-blue-hour-exterior.png",
    "21-helix-espresso.png",
    "22-neon-bao-streetfood.png",
    "23-crane-and-gear.png",
    "24-mbpd-dispatch-exterior.png",
    "25-eastside-fire.png",
    "26-courier-street-view.png",
    "27-vesper-player-view.png",
    "28-lantern-cup-interior.png",
    "29-prism-club-interior.png",
    "30-static-room-interior.png",
    "31-mbpd-dispatch-interior.png",
    "32-horizon-health-interior.png",
    "33-crane-and-gear-interior.png",
)
PNG_HEADER = b"\x89PNG\r\n\x1a\n"
readme = (ROOT / "README.md").read_text(encoding="utf-8")
gallery = (IMAGES / "GALLERY.md").read_text(encoding="utf-8")
issues: list[str] = []
if "docs/screenshots/GALLERY.md" not in readme:
    issues.append("README does not link to the full gallery")
if {path.name for path in IMAGES.glob("*.png")} != set(NAMES):
    issues.append("Gallery PNG file set differs from expected captures")
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
    if f"]({name})" not in gallery:
        issues.append(f"Full gallery does not display the real capture: {name}")
    print(f"{name}: {width}×{height}, {len(payload):,} bytes")
if issues:
    print("Screenshot preflight failed:\n" + "\n".join(f" - {i}" for i in issues))
    sys.exit(1)
print(f"SCREENSHOT PREFLIGHT PASS: {len(NAMES)} genuine PNG assets linked in the player gallery")
