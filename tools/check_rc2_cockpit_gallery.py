#!/usr/bin/env python3
"""Authenticate cockpit evidence against an exact RC2 runtime revision."""
import hashlib
import json
import re
import struct
import subprocess
import sys

def git(*args):
    return subprocess.check_output(["git", *args])

candidate, gallery = sys.argv[1:]
for sha in (candidate, gallery):
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise SystemExit("Full commit SHA required")
    git("cat-file", "-e", sha + "^{commit}")
folder = "docs/screenshots/cinder-cockpit/"
record = json.loads(git("show", gallery + ":" + folder + "manifest.json"))
source = record["source_revision"]
if not re.fullmatch(r"[0-9a-f]{40}", source):
    raise SystemExit("Invalid screenshot source revision")
git("cat-file", "-e", source + "^{commit}")
if git("diff", "--name-only", source, candidate, "--",
       "project.godot", "scripts", "scenes", "assets", "export_presets.cfg",
       "tools/generate_mbpd_radio.py", ":(exclude)scripts/build_info.gd").strip():
    raise SystemExit("Cockpit capture is stale: runtime differs")
assert record["renderer"] == "forward_plus"
assert record["engine"].startswith("4.7.2")
assert record["resolution"] == [960, 540]
assert [s["file"] for s in record["shots"]] == [
    "01-cockpit-day.png", "02-cockpit-night.png", "03-cockpit-rain.png"]
seen = set()
for shot in record["shots"]:
    raw = git("show", gallery + ":" + folder + shot["file"])
    assert raw.startswith(b"\x89PNG\r\n\x1a\n") and len(raw) > 16000
    assert struct.unpack(">II", raw[16:24]) == (960,540)
    digest = hashlib.sha256(raw).hexdigest()
    assert digest == shot["sha256"] and digest not in seen
    seen.add(digest)
print("RC2_COCKPIT_PROVENANCE PASS")
