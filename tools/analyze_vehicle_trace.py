#!/usr/bin/env python3
"""Analyze paired NightGrid F8 CSV/JSON traces without dependencies.

Intervals include VSync and are not GPU timers. Transition windows overlap
when events are close; groups summarize events, not exclusive frame costs.
"""
import argparse
import csv
import json
import math
from collections import defaultdict
from pathlib import Path
from statistics import mean

WINDOW = 12
HITCH = 1000 / 30
MAX_ROWS = 18000
MAX_EVENTS = 256

def number(value):
    if isinstance(value, bool):
        raise ValueError("boolean is not a measurement")
    n = float(value)
    if not math.isfinite(n) or n < 0:
        raise ValueError("invalid nonnegative measurement")
    return n

def percentile(values, p):
    if not values:
        return None
    return sorted(values)[max(0, math.ceil(len(values) * p) - 1)]

def stats(values):
    if not values:
        return {"count": 0}
    tail = sorted(values)[-max(1, math.ceil(len(values) * .01)):]
    return {"count": len(values), "mean_ms": mean(values),
            "p50_ms": percentile(values, .5), "p95_ms": percentile(values, .95),
            "p99_ms": percentile(values, .99), "max_ms": max(values),
            "low_1pct_fps": 1000 / mean(tail) if mean(tail) else None,
            "hitches": sum(n > HITCH for n in values)}

def load_capture(path, sidecar=None):
    path = Path(path)
    with path.open(newline="", encoding="utf-8-sig") as stream:
        reader = csv.DictReader(stream)
        required = {"frame_ms", "stream_build_ms", "in_car"}
        if not required <= set(reader.fieldnames or []):
            raise ValueError("missing F8 CSV columns")
        rows = []
        for row in reader:
            if len(rows) >= MAX_ROWS:
                raise ValueError("capture exceeds recorder limit")
            frame, build = number(row["frame_ms"]), number(row["stream_build_ms"])
            if row["in_car"] not in ("0", "1") or frame <= 0:
                raise ValueError("invalid frame or driving flag")
            rows.append((frame, build, row["in_car"] == "1"))
    if not rows:
        raise ValueError("empty capture")
    sidecar = Path(sidecar) if sidecar else path.with_name(path.stem + "-vehicle-transitions.json")
    if not sidecar.exists():
        return rows, None
    data = json.loads(sidecar.read_text(encoding="utf-8"))
    if data.get("schema_version") != 1 or data.get("source_csv") != path.name:
        raise ValueError("sidecar schema or CSV filename mismatch")
    events = data["transitions"]
    if not isinstance(events, list) or len(events) > MAX_EVENTS:
        raise ValueError("invalid transition list")
    for event in events:
        start = event["first_frame_index"]
        if isinstance(start, bool) or not isinstance(start, (int, float)) or not float(start).is_integer() or not 0 <= start <= len(rows):
            raise ValueError("transition frame index outside capture")
        start = int(start)
        event["first_frame_index"] = start
        if event["kind"] not in ("enter", "exit") or not isinstance(event["model"], str):
            raise ValueError("unknown transition kind/model")
        if event["result"] not in ("ok", "blocked_speed", "blocked_clearance", "unfinished"):
            raise ValueError("unknown transition result")
        actual = rows[start:start+WINDOW]
        expected = event["following_frame_ms"]
        if len(expected) != len(actual) or event["complete_window"] is not (len(actual) == WINDOW):
            raise ValueError("transition window mismatch")
        if any(abs(number(n) - row[0]) > .001 for n, row in zip(expected, actual)):
            raise ValueError("CSV and sidecar interval mismatch")
        # CSV rounds each sample to 0.001 ms; permit accumulated rounding.
        if abs(number(event["following_stream_build_ms"]) - sum(row[1] for row in actual)) > .007:
            raise ValueError("CSV and sidecar streaming measurement mismatch")
        for value in event["stages"].values():
            number(value)
        if event["result"] != "unfinished":
            number(event["total_cpu_ms"])
    return rows, events

def summarize(rows, events):
    result = {"all": stats([r[0] for r in rows]),
              "driving": stats([r[0] for r in rows if r[2]]),
              "on_foot": stats([r[0] for r in rows if not r[2]]),
              "stream_active": stats([r[0] for r in rows if r[1] > 0]),
              "stream_idle": stats([r[0] for r in rows if r[1] == 0]),
              "transition_sidecar": events is not None, "groups": {}}
    if events is None:
        return result
    covered = set()
    groups = defaultdict(list)
    for event in events:
        start = event["first_frame_index"]
        covered.update(range(start, min(start + WINDOW, len(rows))))
        key = "/".join((event["kind"], event["model"] or "legacy", event["result"]))
        groups[key].append(event)
    result["outside_transition_windows"] = stats([r[0] for i, r in enumerate(rows) if i not in covered])
    for key, group in sorted(groups.items()):
        complete = [e for e in group if e["complete_window"]]
        cpu = [number(e["total_cpu_ms"]) for e in group if "total_cpu_ms" in e]
        peaks = [max(r[0] for r in rows[e["first_frame_index"]:e["first_frame_index"]+WINDOW]) for e in complete]
        stages = defaultdict(list)
        for e in group:
            for stage, value in e["stages"].items():
                stages[stage].append(number(value))
        result["groups"][key] = {
            "events": len(group), "complete_windows": len(complete),
            "cpu": stats(cpu), "following_window_peak": stats(peaks),
            "stages": {name: stats(values) for name, values in sorted(stages.items())},
            "worst_events": sorted([{
                "frame_index": e["first_frame_index"],
                "peak_ms": max(r[0] for r in rows[e["first_frame_index"]:e["first_frame_index"]+WINDOW]),
                "stream_ms": sum(r[1] for r in rows[e["first_frame_index"]:e["first_frame_index"]+WINDOW])
            } for e in complete], key=lambda e: e["peak_ms"], reverse=True)[:5]
        }
    return result

def compare(before, after):
    """Signed after-minus-before deltas; no causation or pass/fail inference."""
    out = {}
    for key in ("all", "driving", "on_foot", "outside_transition_windows"):
        if key in before and key in after:
            out[key] = delta(before[key], after[key])
    out["groups"] = {}
    for key in sorted(before["groups"].keys() & after["groups"].keys()):
        a, b = before["groups"][key], after["groups"][key]
        out["groups"][key] = {"cpu": delta(a["cpu"], b["cpu"]),
                              "following_window_peak": delta(a["following_window_peak"], b["following_window_peak"])}
    return out

def delta(a, b):
    return {k: b[k] - a[k] for k in ("p50_ms", "p95_ms", "p99_ms", "max_ms")
            if a.get(k) is not None and b.get(k) is not None}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("--baseline", type=Path)
    args = parser.parse_args()
    try:
        current = summarize(*load_capture(args.capture))
        output = {"capture": str(args.capture), "summary": current,
                  "note": "Compare matching hardware, settings and cold/warm scenarios. Render intervals are not GPU time; overlapping event windows are not exclusive attribution."}
        if args.baseline:
            baseline = summarize(*load_capture(args.baseline))
            output["baseline"] = baseline
            output["after_minus_before_ms"] = compare(baseline, current)
        print(json.dumps(output, indent=2, allow_nan=False))
    except (OSError, ValueError, KeyError, TypeError, AttributeError, OverflowError) as exc:
        parser.exit(2, f"Invalid capture: {exc}\n")

if __name__ == "__main__":
    main()
