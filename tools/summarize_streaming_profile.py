#!/usr/bin/env python3
"""Summarize a native Brickwater or road run from the capture harness."""
import argparse
import csv
import json
import math
from pathlib import Path


def frame_stats(samples):
    ordered = sorted(samples)
    count = len(ordered)

    def percentile(fraction):
        return round(ordered[math.ceil(count * fraction) - 1], 3)

    tail = ordered[-math.ceil(count * 0.01):]
    return {
        "frames": count,
        "median_ms": percentile(0.5),
        "p95_ms": percentile(0.95),
        "p99_ms": percentile(0.99),
        "max_ms": round(ordered[-1], 3),
        "over_16_67": sum(value > 16.67 for value in ordered),
        "over_33_3": sum(value > 33.3 for value in ordered),
        "mean_fps": round(1000 * count / sum(ordered), 2),
        "lowest_1pct_fps": round(1000 * len(tail) / sum(tail), 2),
    }


def summarize(directory):
    profile = json.loads((directory / "stream-profile.json").read_text(encoding="utf-8-sig"))
    result = {key: value for key, value in profile.items() if key not in ("frames", "spans", "runs")}
    result["directory"] = directory.name
    result["startup_spans"] = [
        span for span in profile["spans"] if span["category"].startswith("main_scene_")
    ]
    result["runs"] = []
    for route in profile["runs"]:
        name = Path(route["file"]).stem
        with (directory / route["file"]).open(newline="", encoding="utf-8-sig") as stream:
            samples = list(csv.DictReader(stream))
        draws = [frame for frame in profile["frames"] if frame["pass"] == name]
        frame_ids = {frame["frame"] for frame in draws}
        spans = [span for span in profile["spans"] if span["frame"] in frame_ids]
        stages = [span for span in spans if span["category"] == "chunk_stage"]
        result["runs"].append({
            **route,
            "game_frame": frame_stats([float(row["frame_ms"]) for row in samples]),
            "draw_interval": frame_stats([row["frame_ms"] for row in draws]),
            "loaded_chunks": sum(int(row["loaded_blocks"]) for row in samples),
            "peak_stage_ms": round(max((span["duration_us"] for span in stages), default=0) / 1000, 3),
            "material_bakes": [span for span in spans if span["category"] == "material_image_bake"],
            "slowest_spans": sorted(spans, key=lambda span: span["duration_us"], reverse=True)[:5],
            "max_viewport_cpu_ms": round(max(row["render_cpu_ms"] for row in draws), 3),
            "max_viewport_gpu_ms": round(max(row["render_gpu_ms"] for row in draws), 3),
            "draw_pipeline_delta": draws[-1]["draw_pipelines"] - draws[0]["draw_pipelines"],
            "unfocused_draws": sum(row.get("focused") is False for row in draws),
        })
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directories", nargs="+", type=Path)
    args = parser.parse_args()
    print(json.dumps([summarize(directory) for directory in args.directories], indent=2))
