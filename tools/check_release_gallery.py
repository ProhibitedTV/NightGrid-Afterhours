#!/usr/bin/env python3
"""Fail closed if the published gallery does not match the runtime sources."""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# Exclude only the version constants stamped separately for a release.
RUNTIME_PATHS = (
    "project.godot", "scripts", "scenes", "assets",
    "tools/capture_screenshots.gd", "tools/generate_mbpd_radio.py",
    ":(exclude)scripts/build_info.gd",
)


def verify(capture: str) -> None:
    if not re.fullmatch(r"[0-9a-f]{40}", capture):
        raise ValueError("Invalid full gallery revision SHA")
    record = json.loads((ROOT / "docs/screenshots/capture-manifest.json").read_text())
    if record.get("source_revision") != capture or len(record.get("images", {})) != 9:
        raise ValueError("Beta.7 requires the exact nine-image capture manifest")
    subprocess.run([sys.executable, "tools/check_screenshots.py"], cwd=ROOT, check=True)
    subprocess.run(["git", "cat-file", "-e", capture + "^{commit}"], cwd=ROOT, check=True)
    changed = subprocess.check_output(
        ["git", "diff", "--name-only", capture, "HEAD", "--", *RUNTIME_PATHS],
        cwd=ROOT, text=True,
    )
    if changed.strip():
        raise ValueError("Gallery is stale for release runtime paths:\n" + changed)
    print("RELEASE_GALLERY PASS: exact nine images, unchanged runtime trees")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: check_release_gallery.py FULL_CAPTURE_SHA")
    try:
        verify(sys.argv[1])
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(f"RELEASE_GALLERY FAIL: {error}")
