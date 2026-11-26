"""Best-effort local resource snapshots, no monitoring daemon."""
import os
from pathlib import Path
import shutil
import subprocess


def snapshot():
    result={"disks":{},"gpu":None}
    for name,path in (("windows_ssd","/mnt/c"),("nas","/mnt/z")):
        if not os.path.ismount(path):
            result["disks"][name]={"status":"not-mounted"}
            continue
        try:
            disk=shutil.disk_usage(path)
            result["disks"][name]={"status":"available","total_bytes":disk.total,"free_bytes":disk.free}
        except OSError:
            result["disks"][name]={"status":"unavailable"}
    binary=shutil.which("nvidia-smi")
    if binary:
        try:
            proc=subprocess.run([binary,"--query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total",
                                 "--format=csv,noheader,nounits"],capture_output=True,text=True,timeout=5,check=True)
            rows=[]
            for line in proc.stdout.splitlines():
                fields=[v.strip() for v in line.split(",")]
                if len(fields)!=5:
                    continue
                def number(value):
                    return int(value) if value.isdigit() else None
                rows.append(dict(name=fields[0],temperature_c=number(fields[1]),
                                 utilization_pct=number(fields[2]),memory_used_mib=number(fields[3]),
                                 memory_total_mib=number(fields[4])))
            result["gpu"]=rows or None
        except (OSError,subprocess.SubprocessError):
            pass
    return result
