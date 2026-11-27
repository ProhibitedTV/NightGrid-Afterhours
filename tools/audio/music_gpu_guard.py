"""Strict single-GPU music guard using the shared Factory telemetry."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "asset_refinement"))
from telemetry import snapshot


def gpu_guard():
    rows = snapshot().get("gpu") or []
    if len(rows) != 1:
        raise RuntimeError("Expected one monitored Anubis GPU")
    row = rows[0]
    temp = row.get("temperature_c")
    used = row.get("memory_used_mib")
    total = row.get("memory_total_mib")
    if not isinstance(temp, (float, int)) or not 0 < temp < 85:
        raise RuntimeError("GPU temperature missing or outside safe range")
    if not isinstance(used, int) or not isinstance(total, int) or not 0 <= used <= total or total <= 0:
        raise RuntimeError("GPU memory telemetry unavailable or invalid")
    print(f"GPU: {temp:.1f} C ({row.get('temperature_source')}), {used}/{total} MiB", flush=True)
    return float(used), float(total)
