"""Best-effort local resource snapshots, no monitoring daemon."""
import math
import os
from pathlib import Path
import shutil
import subprocess

QUERY = "uuid,name,temperature.gpu,utilization.gpu,memory.used,memory.total"


def number(value):
    return int(value) if value.isdigit() else None


def temperature(value):
    try:
        temp = float(value)
    except ValueError:
        return None
    return temp if math.isfinite(temp) else None


def query_gpu(binary):
    if not binary:
        return []
    try:
        proc = subprocess.run([binary, "--query-gpu=" + QUERY,
                               "--format=csv,noheader,nounits"],
                              capture_output=True, text=True, timeout=5, check=True)
        rows = []
        for line in proc.stdout.splitlines():
            fields = [v.strip() for v in line.split(",")]
            if len(fields) != 6:
                continue
            temp = temperature(fields[2])
            rows.append(dict(uuid=fields[0] if fields[0].startswith("GPU-") else None,
                             name=fields[1], temperature_c=temp,
                             utilization_pct=number(fields[3]),
                             memory_used_mib=number(fields[4]),
                             memory_total_mib=number(fields[5]),
                             temperature_source="native" if temp is not None else None))
        return rows
    except (OSError, subprocess.SubprocessError):
        return []


def native_gpu_rows():
    # sudo's secure_path often omits the WSL-provided NVIDIA executable.
    binaries = [shutil.which("nvidia-smi")]
    wsl_binary = Path("/usr/lib/wsl/lib/nvidia-smi")
    if wsl_binary.is_file():
        binaries.append(str(wsl_binary))
    for binary in dict.fromkeys(binaries):
        rows = query_gpu(binary)
        if rows:
            return rows
    return []


def windows_nvidia_smi():
    # WSL's NVML does not expose every metric on every driver. Only try
    # Windows interop under WSL; never download or install a binary.
    try:
        if "microsoft" not in Path("/proc/sys/kernel/osrelease").read_text().lower():
            return None
    except OSError:
        return None
    for path in ("/mnt/c/Windows/System32/nvidia-smi.exe",
                 "/mnt/c/Program Files/NVIDIA Corporation/NVSMI/nvidia-smi.exe"):
        if Path(path).is_file():
            return path
    return shutil.which("nvidia-smi.exe")


def fill_temperatures(rows, host_rows):
    # Do not match by model name or index: multiple identical GPUs may exist.
    by_uuid = {}
    for gpu in host_rows:
        uuid = gpu["uuid"]
        if uuid:
            if uuid in by_uuid:
                by_uuid[uuid] = None
            else:
                by_uuid[uuid] = gpu["temperature_c"]
    for gpu in rows:
        if gpu["temperature_c"] is None and gpu["uuid"]:
            temp = by_uuid.get(gpu["uuid"])
            if temp is not None:
                gpu.update(temperature_c=temp, temperature_source="windows-host")


def snapshot():
    result = {"disks": {}, "gpu": None}
    for name, path in (("windows_ssd", "/mnt/c"), ("nas", "/mnt/z")):
        if not os.path.ismount(path):
            result["disks"][name] = {"status": "not-mounted"}
            continue
        try:
            disk = shutil.disk_usage(path)
            result["disks"][name] = {"status": "available", "total_bytes": disk.total,
                                     "free_bytes": disk.free}
        except OSError:
            result["disks"][name] = {"status": "unavailable"}
    rows = native_gpu_rows()
    if not rows:
        # No native inventory: monitor the entire Windows host inventory rather
        # than guessing a device by model or index. Strict music mode rejects
        # multiple GPUs and incomplete readings; CUDA still checks its device.
        rows = query_gpu(windows_nvidia_smi())
        for gpu in rows:
            if gpu["temperature_c"] is not None:
                gpu["temperature_source"] = "windows-host"
    elif any(gpu["temperature_c"] is None and gpu["uuid"] for gpu in rows):
        fill_temperatures(rows, query_gpu(windows_nvidia_smi()))
    result["gpu"] = rows or None
    return result
