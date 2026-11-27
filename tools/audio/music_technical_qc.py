#!/usr/bin/env python3
"""Read-only technical review of verified original music masters (no approval)."""
import argparse
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import sys

from music_candidate_intake import validate, sha256

SILENCE_SECONDS = 0.5
SILENCE_DB = -50


def number(value):
    value = float(value)
    return round(value, 3) if math.isfinite(value) else None


def measure(path, binary):
    # Silence must be measured before loudnorm changes the signal. The output
    # is discarded; input_* fields describe the original, not normalized audio.
    command = [binary, "-nostdin", "-hide_banner", "-loglevel", "info",
               "-i", str(path), "-map", "0:a:0",
               "-af", "silencedetect=noise=-50dB:d=0.5,loudnorm=print_format=json",
               "-f", "null", "-"]
    proc = subprocess.run(command, capture_output=True, text=True,
                          timeout=300, check=True)
    candidates = re.findall(r"\{[^{}]*\"input_i\"[^{}]*\}", proc.stderr, re.S)
    if len(candidates) != 1:
        raise ValueError("Expected exactly one FFmpeg loudness measurement")
    data = json.loads(candidates[0])
    silence = [float(x) for x in re.findall(
        r"silence_duration:\s*([0-9]+(?:\.[0-9]+)?)", proc.stderr)]
    return {
        "integrated_lufs": number(data["input_i"]),
        "true_peak_dbtp": number(data["input_tp"]),
        "loudness_range_lu": number(data["input_lra"]),
        "silence_total_seconds": round(sum(silence), 3),
        "silence_longest_seconds": round(max(silence, default=0), 3),
    }


def review(manifest, source, binary):
    verified = validate(manifest, source)["verified_candidates"]
    entries = {row["id"]: row for row in manifest["candidates"]}
    rows = []
    for item in verified:
        entry = entries[item["id"]]
        path = (source / entry["file"]).resolve(strict=True)
        if not path.is_relative_to(source.resolve()) or sha256(path) != item["sha256"]:
            raise ValueError("Source changed before measurement: " + item["id"])
        metrics = measure(path, binary)
        if sha256(path) != item["sha256"]:
            raise ValueError("Source changed during measurement: " + item["id"])
        flags = []
        if metrics["integrated_lufs"] is None:
            flags.append("loudness-unmeasurable")
        peak = metrics["true_peak_dbtp"]
        if peak is None:
            flags.append("peak-unmeasurable")
        elif peak >= 0:
            flags.append("true-peak-at-or-above-full-scale")
        elif peak > -1:
            flags.append("true-peak-headroom-under-1db")
        if metrics["silence_longest_seconds"] >= 2:
            flags.append("extended-silence-listen")
        target = entry.get("requested_duration")
        if isinstance(target, (int, float)) and not isinstance(target, bool) and math.isfinite(target) and target > 0:
            if abs(item["duration_seconds"] - target) > max(4, target * 0.12):
                flags.append("duration-outside-requested-tolerance")
        rows.append(dict(item, measurements=metrics, flags=flags,
                         status="technical-review-only; listening and rights pending"))
    # Exact duplicate files are a useful signal, not perceptual similarity.
    counts = {}
    for row in rows:
        counts[row["sha256"]] = counts.get(row["sha256"], 0) + 1
    for row in rows:
        if counts[row["sha256"]] > 1:
            row["flags"].append("byte-identical-candidate")
    return {"schema": 1, "mode": "read-only; no approval or publish",
            "silence_threshold_db": SILENCE_DB,
            "silence_minimum_seconds": SILENCE_SECONDS,
            "candidate_count": len(rows),
            "flagged_count": sum(bool(row["flags"]) for row in rows),
            "not_measured": ["sample clipping count", "channel balance",
                             "loop seam", "perceptual similarity", "tempo", "key"],
            "candidates": rows}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        binary = shutil.which("ffmpeg")
        if not binary:
            raise ValueError("Existing FFmpeg installation required")
        version = subprocess.check_output([binary, "-version"], text=True,
                                          timeout=10).splitlines()[0]
        result = review(json.loads(args.manifest.read_text(encoding="utf-8")),
                        args.source, binary)
        result["measurement_engine"] = version
        print(json.dumps(result, indent=2, sort_keys=True, allow_nan=False))
    except (OSError, ValueError, KeyError, TypeError, IndexError,
            subprocess.SubprocessError) as exc:
        print("MUSIC QC FAILED:", exc, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
