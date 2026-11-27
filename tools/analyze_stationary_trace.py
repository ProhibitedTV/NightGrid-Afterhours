#!/usr/bin/env python3
"""Separate stationary-position and traversal frame intervals from an F8 trace.

Position is quantized to centimeters. This does not measure camera motion,
CPU/GPU time or identify a hitch's cause. Classify displacement over 0.5s,
not individual frames; exclude the initial window and vehicle mode changes.
"""
import argparse
import csv
import json
import math
from collections import deque
from pathlib import Path
from analyze_vehicle_trace import MAX_ROWS, number, stats

WINDOW_SECONDS = .5
STILL_METERS = .10

def read_rows(path):
    with Path(path).open(newline="", encoding="utf-8-sig") as stream:
        reader = csv.DictReader(stream)
        required = {"elapsed_s", "frame_ms", "stream_build_ms", "world_x", "world_z", "in_car"}
        if not required <= set(reader.fieldnames or []):
            raise ValueError("missing F8 position/time columns")
        rows = []
        for row in reader:
            if len(rows) >= MAX_ROWS:
                raise ValueError("capture exceeds recorder limit")
            elapsed, frame, build = (number(row[key]) for key in
                                     ("elapsed_s", "frame_ms", "stream_build_ms"))
            x, z = float(row["world_x"]), float(row["world_z"])
            if (not math.isfinite(x) or not math.isfinite(z) or frame <= 0
                    or row["in_car"] not in ("0", "1")
                    or (rows and elapsed <= rows[-1][0])):
                raise ValueError("invalid position, frame, clock or vehicle flag")
            rows.append((elapsed, frame, build, x, z, row["in_car"]))
    if not rows:
        raise ValueError("empty capture")
    return rows

def summarize_position(rows):
    groups = {f"{mode}/{motion}/{stream}": [] for mode in ("foot", "car")
              for motion in ("stationary", "moving") for stream in ("idle", "active")}
    history = deque()
    excluded = 0
    distance = 0.0
    previous = None
    for row in rows:
        now, frame, build, x, z, mode = row
        if previous is not None and previous[5] != mode:
            history.clear()
            distance = 0.0
        segment = 0.0 if not history else math.hypot(x - history[-1][3], z - history[-1][4])
        # A mode change does not contribute any cross-mode displacement.
        history.append(row)
        distance += segment
        while len(history) > 1 and history[1][0] <= now - WINDOW_SECONDS:
            first = history.popleft()
            distance -= math.hypot(history[0][3] - first[3], history[0][4] - first[4])
        previous = row
        if now - history[0][0] < WINDOW_SECONDS:
            excluded += 1
            continue
        motion = "stationary" if distance <= STILL_METERS else "moving"
        key = "/".join(("car" if mode == "1" else "foot", motion, "active" if build > 0 else "idle"))
        groups[key].append(frame)
    return {"frames": len(rows), "excluded_warmup_or_mode_change": excluded,
            "groups": {key: stats(values) for key, values in groups.items()}}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    args = parser.parse_args()
    try:
        report = summarize_position(read_rows(args.capture))
        report["capture"] = str(args.capture)
        report["note"] = ("Stationary horizontal position over >=0.5s and <=0.10m accumulated movement; "
                          "camera motion and GPU timing are not measured. Streaming active means positive "
                          "recorded build duration on that sampled interval; not exclusive causation.")
        print(json.dumps(report, indent=2, allow_nan=False))
    except (OSError, ValueError, KeyError, TypeError, OverflowError) as exc:
        parser.exit(2, f"Invalid capture: {exc}\n")

if __name__ == "__main__":
    main()
