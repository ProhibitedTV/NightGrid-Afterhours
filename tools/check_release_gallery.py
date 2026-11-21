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
    # A separately merged, additive scheduling API (#116) is dormant:
    # there are no runtime references to its script or class. Exempt only
    # these exact reviewed blob IDs, never a general class of script changes.
    paths = changed.splitlines()
    inactive = "scripts/sidewalk_certification.gd"
    if inactive in paths:
        old_blob = subprocess.check_output(
            ["git", "rev-parse", capture + ":" + inactive], cwd=ROOT, text=True,
        ).strip()
        new_blob = subprocess.check_output(
            ["git", "rev-parse", "HEAD:" + inactive], cwd=ROOT, text=True,
        ).strip()
        references = subprocess.run(
            ["git", "grep", "-in", "-E", "sidewalk_certification|SidewalkCertification",
             "HEAD", "--", "project.godot", "scripts", "scenes", "assets",
             "tools/capture_screenshots.gd", ":(exclude)" + inactive],
            cwd=ROOT, capture_output=True, text=True,
        )
        if (old_blob == "9f19f5b2067fd6b68c77c29df04e63d5f8372707" and
                new_blob == "58e28b61583a1590a9e510e371de8ab773980bdb" and references.returncode == 1):
            paths.remove(inactive)
            print("Verified inactive additive sidewalk API (#116); no runtime references")
    # #117 added an opt-in pool, but did not install it in the world.
    # Permit only the exact reviewed new blob with no prior file and no
    # caller outside the file itself. Any integration needs a fresh capture.
    inactive_pool = "scripts/pedestrian_pool.gd"
    if inactive_pool in paths:
        existed = subprocess.run(
            ["git", "cat-file", "-e", capture + ":" + inactive_pool],
            cwd=ROOT, capture_output=True,
        )
        pool_blob = subprocess.check_output(
            ["git", "rev-parse", "HEAD:" + inactive_pool], cwd=ROOT, text=True,
        ).strip()
        references = subprocess.run(
            ["git", "grep", "-in", "-E", "pedestrian_pool|PedestrianPool",
             "HEAD", "--", "project.godot", "scripts", "scenes", "assets",
             "tools/capture_screenshots.gd", ":(exclude)" + inactive_pool],
            cwd=ROOT, capture_output=True, text=True,
        )
        if (existed.returncode != 0 and
                pool_blob == "159e360f6d4f09a18d5bd5a9a63b073932bd7133" and references.returncode == 1):
            paths.remove(inactive_pool)
            print("Verified standalone unreferenced pedestrian pool (#117)")
    # #119/#121 were reviewed as dormant pedestrian foundations. City
    # pruning remains identical while its reservations dictionary is empty.
    # The exact trio of changed blobs is allowed only together, and only
    # while no shipped caller activates the reservation or population API.
    passive = {
        "scripts/city_details.gd": ("9a137d92d5b9342b40334e6fbd66f23793251905", "ee887a4061e55d92d758b28a48866e24dc114fe2"),
        "scripts/sidewalk_population.gd": ("16111a840ce7155393fde4d32f48095911e76727", "7f5fbfc1f6a8245eba70ff91faac102e082d9871"),
        "scripts/civilian_routines.gd": (None, "055efcaf16109b7c88e78e8dd67bd975045876af"),
    }
    if set(passive).issubset(paths):
        def blob_at(revision, path):
            result = subprocess.run(
                ["git", "rev-parse", "--verify", revision + ":" + path],
                cwd=ROOT, capture_output=True, text=True,
            )
            return result.stdout.strip() if result.returncode == 0 else None
        exact = all(blob_at(capture, path) == pair[0] and
                    blob_at("HEAD", path) == pair[1]
                    for path, pair in passive.items())
        references = subprocess.run(
            ["git", "grep", "-in", "-E",
             "reserve_pedestrian_parcel|release_pedestrian_parcel|sidewalk_population|civilian_routines|SidewalkPopulation|CivilianRoutines",
             "HEAD", "--", "project.godot", "scripts", "scenes", "assets",
             "tools/capture_screenshots.gd",
             *[":(exclude)" + path for path in passive],
             ":(exclude)scripts/pedestrian_pool.gd"],
            cwd=ROOT, capture_output=True, text=True,
        )
        if exact and references.returncode == 1:
            paths = [path for path in paths if path not in passive]
            print("Verified exact dormant pedestrian foundations (#119/#121)")
    if paths:
        raise ValueError("Gallery is stale for release runtime paths:\n" + "\n".join(paths))
    print("RELEASE_GALLERY PASS: exact nine images, unchanged runtime trees")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: check_release_gallery.py FULL_CAPTURE_SHA")
    try:
        verify(sys.argv[1])
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(f"RELEASE_GALLERY FAIL: {error}")
