#!/usr/bin/env python3
"""Dependency-free structure and resource-reference preflight."""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parent.parent
required = ["project.godot", "scenes/main.tscn", "scripts/world.gd",
            "scripts/player.gd", "scripts/car.gd", "scripts/minimap.gd", "README.md"]
errors = []
for name in required:
    if not (root / name).is_file():
        errors.append(f"Missing file: {name}")
for path in root.rglob("*.gd"):
    data = path.read_text(encoding="utf8")
    for ref in re.findall(r'res://([^"\']+)', data):
        # Generated botanical assets are optional only until local staging.
        # All literal scene/model references elsewhere remain mandatory.
        if (path.relative_to(root).as_posix(), ref) == (
                "scripts/botanical_bank.gd", "assets/models/nightgrid/botanical/"):
            continue
        if not (root / ref).exists():
            errors.append(f"Broken resource in {path.relative_to(root)}: {ref}")
    if re.search(r"^const\s+\w+\s*:=", data, flags=re.M):
        errors.append(f"Possible invalid GDScript const inference in {path}")
scene = root / "scenes/main.tscn"
if scene.exists() and 'res://scripts/world.gd' not in scene.read_text():
    errors.append("Main scene is not linked to world.gd")
if errors:
    print("Preflight failed:")
    for error in errors:
        print(f"  - {error}")
    sys.exit(1)
print("Project preflight passed (use Godot to validate GDScript).")
