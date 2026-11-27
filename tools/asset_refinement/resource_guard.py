"""Supervise one WSL factory stage, with bounded sampling and process-group stop.

This is a software guard, not hardware thermal protection. No daemon.
"""
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
from telemetry import snapshot

GIB=1024**3


def violation(data, min_ssd, min_nas, max_temp, require_gpu=False):
    for disk,minimum in (("windows_ssd",min_ssd),("nas",min_nas)):
        item=data.get("disks",{}).get(disk,{})
        if item.get("status")!="available":
            return disk+" missing/unavailable"
        if item.get("free_bytes",-1)<minimum*GIB:
            return disk+" free-space reserve breached"
    rows=data.get("gpu") or []
    if require_gpu and (len(rows)!=1 or any(not isinstance(g.get("temperature_c"),(int,float)) or not 0<g["temperature_c"]<100 for g in rows)):
        return "Required single-GPU temperature telemetry unavailable or invalid"
    for gpu in rows:
        temp=gpu.get("temperature_c")
        if isinstance(temp,(int,float)) and temp>=max_temp:
            return "GPU temperature threshold reached"
    return None


def stop(proc, grace):
    # Signal the dedicated group, not unrelated GPU jobs or the host.
    try:
        os.killpg(proc.pid,signal.SIGTERM)
    except ProcessLookupError:
        pass
    deadline=time.monotonic()+grace
    while time.monotonic()<deadline:
        proc.poll()
        try:
            os.killpg(proc.pid,0)
        except ProcessLookupError:
            break
        time.sleep(.2)
    else:
        try:
            os.killpg(proc.pid,signal.SIGKILL)
        except ProcessLookupError:
            pass
    return proc.wait()


def supervise(command, log, interval=15, min_ssd=25, min_nas=10,
              max_temp=85, grace=20, require_gpu=False):
    if not command:
        raise ValueError("Missing stage command")
    if not 5<=interval<=300 or not 1<=grace<=120 or not 60<=max_temp<=95 or min_ssd<10 or min_nas<5:
        raise ValueError("Invalid resource guard settings")
    pending=[None]
    def interrupted(signum,frame):
        pending[0]=signum
    old={s:signal.signal(s,interrupted) for s in (signal.SIGINT,signal.SIGTERM)}
    proc=None
    try:
        # NAS log is intentionally not reopened after mount loss. This local
        # file is small and bounded by one stage's duration.
        with log.open("x",encoding="utf-8") as handle:
            next_sample=0
            warned_temperature=False
            while True:
                if pending[0] is not None:
                    if proc is not None:
                        stop(proc,grace)
                    return 128+pending[0]
                if proc is not None and proc.poll() is not None:
                    return proc.returncode if proc.returncode>=0 else 128-proc.returncode
                t=time.monotonic()
                if t>=next_sample:
                    data=snapshot()
                    gpu_rows=data.get("gpu") or []
                    if not warned_temperature and (not gpu_rows or any(
                            g.get("temperature_c") is None for g in gpu_rows)):
                        print("Resource guard: GPU temperature telemetry incomplete; "
                              "thermal threshold cannot protect GPUs without readings",
                              file=sys.stderr,flush=True)
                        warned_temperature=True
                    bad=violation(data,min_ssd,min_nas,max_temp,require_gpu=require_gpu)
                    record={"unix_time":time.time(),"hardware":data,"stop_reason":bad}
                    handle.write(json.dumps(record)+"\n")
                    handle.flush()
                    if bad:
                        print("Resource guard:",bad,file=sys.stderr,flush=True)
                        if proc is not None:
                            stop(proc,grace)
                        return 75
                    next_sample=t+interval
                if proc is None:
                    if pending[0] is not None:
                        return 128+pending[0]
                    proc=subprocess.Popen(command,start_new_session=True)
                time.sleep(.25)
    finally:
        if proc is not None and proc.poll() is None:
            stop(proc,grace)
        for s,handler in old.items():
            signal.signal(s,handler)


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--log",type=Path,required=True)
    p.add_argument("--interval",type=int,default=15)
    p.add_argument("--min-ssd",type=int,default=25)
    p.add_argument("--min-nas",type=int,default=10)
    p.add_argument("--max-temp",type=int,default=85)
    p.add_argument("--require-gpu",action="store_true",help="Fail closed on missing single-GPU temperature telemetry")
    p.add_argument("command",nargs=argparse.REMAINDER)
    a=p.parse_args()
    command=a.command[1:] if a.command[:1]==["--"] else a.command
    return supervise(command,a.log,a.interval,a.min_ssd,a.min_nas,a.max_temp,require_gpu=a.require_gpu)


if __name__=="__main__":
    sys.exit(main())
