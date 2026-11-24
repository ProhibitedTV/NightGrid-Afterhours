#!/usr/bin/env python3
"""Verify cockpit screenshot provenance against a candidate commit."""
import hashlib
import json
import re
import struct
import subprocess
import sys
import zlib

FOLDER = "docs/screenshots/cinder-cockpit/"
NAMES = ["01-cockpit-day.png", "02-cockpit-night.png", "03-cockpit-rain.png"]
RUNTIME = ("project.godot", "scripts", "scenes", "assets", "shaders",
           "export_presets.cfg", "tools/generate_mbpd_radio.py",
           ":(exclude)scripts/build_info.gd")

def git(*args):
    return subprocess.check_output(["git", *args])

def require(condition, message):
    if not condition:
        raise ValueError(message)

def commit(sha):
    require(isinstance(sha, str) and re.fullmatch(r"[0-9a-f]{40}", sha), "Full commit SHA required")
    git("cat-file", "-e", sha + "^{commit}")

def check_png(raw):
    require(raw.startswith(b"\x89PNG\r\n\x1a\n") and len(raw) > 16000, "Missing or small PNG")
    pos, kinds = 8, []
    while pos < len(raw):
        require(pos + 12 <= len(raw), "Truncated PNG chunk")
        count = struct.unpack_from(">I", raw, pos)[0]
        end = pos + count + 12
        require(end <= len(raw), "Truncated PNG payload")
        kind = raw[pos+4:pos+8]
        data = raw[pos+8:end-4]
        require(zlib.crc32(kind + data) == struct.unpack_from(">I", raw, end-4)[0], "PNG CRC mismatch")
        kinds.append(kind)
        if kind == b"IHDR":
            require(pos == 8 and count == 13 and struct.unpack_from(">II", data) == (960,540),
                    "Invalid PNG resolution/header")
        pos = end
        if kind == b"IEND":
            require(count == 0 and pos == len(raw), "Trailing PNG data")
            break
    require(kinds[0] == b"IHDR" and kinds.count(b"IHDR") == 1 and b"IDAT" in kinds
            and kinds[-1] == b"IEND", "Incomplete PNG")

def verify(candidate, gallery):
    for sha in (candidate, gallery):
        commit(sha)
    record = json.loads(git("show", gallery + ":" + FOLDER + "manifest.json"))
    source = record["source_revision"]
    commit(source)
    git("merge-base", "--is-ancestor", source, gallery)
    require(not git("diff", "--name-only", source, candidate, "--", *RUNTIME).strip(),
            "Cockpit capture is stale: runtime differs")
    git("cat-file", "-e", source + ":tools/capture_cinder_cockpit.gd")
    require(not git("diff", "--name-only", source, gallery, "--", *RUNTIME,
                    "tools/capture_cinder_cockpit.gd").strip(),
            "Gallery commit modified runtime or capture code")
    require(record["renderer"] == "forward_plus" and record["engine"].startswith("4.7.2"),
            "Wrong renderer/engine")
    require(record["resolution"] == [960, 540], "Wrong capture resolution")
    shots = record["shots"]
    require([s["file"] for s in shots] == NAMES, "Missing, reordered or extra captures")
    seen = set()
    for shot, weather in zip(shots, ("clear", "clear", "rain")):
        require(shot["weather"] == weather and shot["fov"] == 78.0 and shot["dashboard"]["active"],
                "Incorrect cockpit fixture metadata")
        raw = git("show", gallery + ":" + FOLDER + shot["file"])
        check_png(raw)
        digest = hashlib.sha256(raw).hexdigest()
        require(digest == shot["sha256"] and digest not in seen, "Tampered or duplicate screenshot")
        seen.add(digest)
    print("RC2_COCKPIT_PROVENANCE PASS")

if __name__ == "__main__":
    try:
        verify(*sys.argv[1:])
    except (TypeError, ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        sys.exit("RC2_COCKPIT_PROVENANCE FAIL: " + str(error))
