#!/usr/bin/env python3
"""Read-only verification of genuine title capture outputs, not visual approval."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import sys

EXPECTED = {
    "01-title-night.png": (22.1, 0.0),
    "02-title-dawn.png": (6.5, 0.0),
    "03-title-day.png": (12.5, 0.0),
    "04-title-neon-dip.png": (22.1, 9.825),
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify(folder, revision, native=False):
    folder = folder.resolve(strict=True)
    record = json.loads((folder / "capture.json").read_text(encoding="utf-8"))
    require(re.fullmatch(r"[a-f0-9]{40}", revision) is not None, "Expected full Git SHA")
    require(record["source_revision"] == revision, "Capture revision mismatch")
    require(record["renderer"] == "forward_plus" and record["driver"].lower() == "vulkan",
            "Not a Forward+ Vulkan capture")
    require(record["volumetric_fog"] is True, "Volumetric fog disabled")
    require("4.7.2" in record["engine"], "Unexpected engine version")
    require(isinstance(record["adapter"], str) and bool(record["adapter"].strip()), "No adapter identity")
    if native:
        require(not record["capture_only_low_radiance"], "Native review must use full sky radiance")
        require("3060" in record["adapter"].lower() and "nvidia" in record["adapter"].lower(),
                "Expected NVIDIA RTX 3060 native capture")
    shots = record["shots"]
    require([s["file"] for s in shots] == list(EXPECTED), "Missing, unexpected or reordered shots")
    require({p.name for p in folder.glob("*.png")} == set(EXPECTED), "Unexpected PNG inventory")
    seen = set()
    dimensions = set()
    for shot in shots:
        name = shot["file"]
        hour, phase = EXPECTED[name]
        require(abs(float(shot["hour"]) - hour) < 1e-6 and
                abs(float(shot["fault_phase"]) - phase) < 1e-6, "Wrong shot state: " + name)
        path = (folder / name).resolve(strict=True)
        require(path.parent == folder, "Image resolves outside gallery")
        raw = path.read_bytes()
        require(len(raw) > 16000 and raw[:8] == bytes.fromhex("89504e470d0a1a0a") and
                raw[12:16] == b"IHDR" and raw[-12:] == bytes.fromhex("0000000049454e44ae426082"),
                "Invalid or suspect PNG: " + name)
        size = struct.unpack(">II", raw[16:24])
        require(size == (shot["width"], shot["height"]), "Dimension mismatch: " + name)
        require(size[0] >= 1280 and size[1] >= 720, "Resolution too low: " + name)
        if native:
            require(size == (1920, 1080), "Native review requires 1920x1080")
        dimensions.add(size)
        digest = hashlib.sha256(raw).hexdigest()
        require(digest == shot["sha256"] and len(raw) == shot["bytes"] and digest not in seen,
                "Duplicate or changed PNG: " + name)
        seen.add(digest)
    require(len(dimensions) == 1, "Mixed screenshot sizes")
    return {"revision": revision, "adapter": record["adapter"], "renderer": record["renderer"],
            "resolution": list(next(iter(dimensions))), "images": len(shots),
            "status": "integrity verified; human visual review still required"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--native-3060", action="store_true")
    args = parser.parse_args()
    try:
        print(json.dumps(verify(args.folder, args.revision, args.native_3060), indent=2))
    except (OSError, ValueError, TypeError, KeyError, AttributeError, struct.error) as exc:
        print("TITLE GALLERY FAILED:", exc, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
