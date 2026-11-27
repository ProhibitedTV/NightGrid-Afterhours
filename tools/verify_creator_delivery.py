#!/usr/bin/env python3
"""Verify a private creator build directory without launching or modifying it."""
import argparse
import json
import re
import sys
from pathlib import Path
from build_creator_playtest import CREDITS, sha256

REQUIRED = {"NightGrid-Afterhours.exe", "NightGrid-Afterhours.pck",
            "BUILD-INFO.txt", "CREATOR-MANIFEST.json", *CREDITS.values()}
CAST = {
    "dev.glb.bin": "da44fc3cef88d7f55f2837b22b355140536ac19f0530a0779d1257a30d93bdd6",
    "rina.glb.bin": "74321e1f1184090c50915ef8901d7c2b067f8643d21bb85055166558b4b1b08e",
    "dana.glb.bin": "642073bc5d603e0dff9b99c5f6e0d2a5f8565bb995bea7636f1568cdafd70d84",
    "jetson.glb.bin": "4f7878f077863584eb6ff9229cb8175d427db8298b45987184a1bcc85fdf8d36",
}
REQUIRED_CHECKS = {"voice-contract", "voice-library", "sfx-library", "import",
                   "strict-cast", "windows-export", "packaged-cast"}

def verify(directory, expected_revision):
    directory = Path(directory)
    if not re.fullmatch(r"[0-9a-f]{40}", expected_revision):
        raise ValueError("Supply the expected full 40-character source commit")
    hashes = {}
    for line in (directory / "SHA256SUMS.txt").read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  ([A-Za-z0-9._-]+)", line)
        if not match:
            raise ValueError("Malformed checksum line")
        digest, name = match.groups()
        if name not in REQUIRED or name in hashes:
            raise ValueError("Unexpected or duplicate checksum entry: " + name)
        hashes[name] = digest
    if set(hashes) != REQUIRED:
        raise ValueError("Missing checksums: " + ", ".join(sorted(REQUIRED - hashes.keys())))
    for name, digest in hashes.items():
        path = directory / name
        if path.is_symlink() or not path.is_file() or path.stat().st_size == 0 or sha256(path) != digest:
            raise ValueError("Missing, empty, linked or modified payload: " + name)
    manifest = json.loads((directory / "CREATOR-MANIFEST.json").read_text(encoding="utf-8"))
    if (manifest.get("revision") != expected_revision or manifest.get("channel") != "development"
            or not str(manifest.get("godot", "")).startswith("4.7.2.")
            or manifest.get("candidate_hashes") != CAST):
        raise ValueError("Creator manifest identity or candidate hash mismatch")
    if not REQUIRED_CHECKS <= set(manifest.get("checks", [])):
        raise ValueError("Creator manifest lacks required build checks")
    info = (directory / "BUILD-INFO.txt").read_text(encoding="utf-8").splitlines()
    if "Source commit: " + expected_revision not in info or "Channel: development" not in info:
        raise ValueError("BUILD-INFO identity mismatch")
    return {"revision": expected_revision, "verified_files": sorted(hashes),
            "reported_checks": manifest["checks"], "native_acceptance": "not verified",
            "note": "Checksums detect transfer corruption, not malicious replacement of the manifest. "
                    "Candidate hashes and checks are recorded claims; run packaged verifier and native QA independently."}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--revision", required=True, help="Expected full commit from integration checkout")
    args = parser.parse_args()
    try:
        print(json.dumps(verify(args.directory, args.revision), indent=2))
    except (OSError, ValueError, TypeError, AttributeError) as exc:
        sys.exit("CREATOR_DELIVERY FAIL: " + str(exc))
    print("CREATOR_DELIVERY PASS: delivery integrity and recorded identity")

if __name__ == "__main__":
    main()
