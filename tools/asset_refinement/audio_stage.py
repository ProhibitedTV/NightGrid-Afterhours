"""Sequential, candidate-only audio driver for an existing local environment.

Never invokes setup, auto-playtest, approval, cast locking or publication.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
from refine import sha, write


def run(checkout, python, output, cli, seed, sfx_device):
    checkout, python, output = checkout.resolve(), python.absolute(), output.resolve()
    if output == checkout or checkout in output.parents or output in checkout.parents:
        raise ValueError("Audio output must be outside checkout")
    if not python.is_file():
        raise ValueError("Existing voice environment required")
    if cli and not cli.is_file():
        raise ValueError("Existing Stable Audio executable required")
    output.mkdir(parents=True,exist_ok=True)
    lock=output/".audio.lock"
    lock.mkdir()
    env=dict(os.environ,ANUBIS_AUDIO_OUT=str(output),HF_HUB_OFFLINE="1",TRANSFORMERS_OFFLINE="1")
    env.pop("PYTHONPATH",None)
    stages=[]
    def stage(name,argv):
        start=time.monotonic()
        log=output/(name+".log")
        with log.open("a",encoding="utf-8") as handle:
            handle.write("\n--- new attempt ---\n")
            handle.flush()
            result=subprocess.run([str(x) for x in argv],cwd=checkout,env=env,
                                  stdin=subprocess.DEVNULL,stdout=handle,stderr=subprocess.STDOUT)
        stages.append({"stage":name,"status":"completed" if result.returncode==0 else "failed",
                       "exit_code":result.returncode,"seconds":round(time.monotonic()-start,2),
                       "log":log.name,"log_sha256":sha(log)})
        print("Audio",name,stages[-1]["status"],flush=True)
        return result.returncode
    try:
        # An external checkout must implement these exact overrides; fail before generating.
        verify_code="""import sys,os; from pathlib import Path
sys.path.insert(0,'tools/voice')
import studio,production
sys.path.insert(0,'tools/audio')
import generate_sfx
root=Path(os.environ['ANUBIS_AUDIO_OUT'])
assert studio.WORK.resolve()==root/'voice-candidates'
assert production.TAKES.resolve()==root/'voice-production'
assert generate_sfx.CANDIDATES.resolve()==root/'sfx-candidates'
assert production.PUBLISHED.resolve()==Path.cwd()/'assets/audio/voiced'
"""
        if stage("preflight",[python,"-c",verify_code]):
            return 1
        if shutil.disk_usage(output).free<10*1024**3:
            raise RuntimeError("Audio NAS reserve below 10 GiB")
        if cli:
            stage("sfx",[python,"tools/voice/anubis.py","sfx-bake","--sfx-cli",cli,
                         "--sfx-device",sfx_device])
        else:
            stages.append({"stage":"sfx","status":"skipped-no-local-cli"})
        stage("speech",[python,"tools/voice/anubis.py","bake","--all","--non-interactive",
                        "--seed",str(seed)])
        stage("speech-inventory",[python,"tools/voice/anubis.py","status"])
        return int(any(s["status"]=="failed" for s in stages))
    finally:
        try:
            report={"schema":1,"scope":"candidate-only; completed process does not imply full cue coverage",
                    "checkout":str(checkout),"seed":seed,"stages":stages}
            with tempfile.NamedTemporaryFile(dir=output,delete=False) as handle:
                tmp=Path(handle.name)
            try:
                write(tmp,report)
                tmp.replace(output/"audio-run.json")
            finally:
                tmp.unlink(missing_ok=True)
        finally:
            lock.rmdir()


if __name__=="__main__":
    p=argparse.ArgumentParser()
    for flag in ("checkout","python","output"):
        p.add_argument("--"+flag,type=Path,required=True)
    p.add_argument("--sfx-cli",type=Path)
    p.add_argument("--seed",type=int,default=308)
    p.add_argument("--sfx-device",choices=["cpu","cuda"],default="cpu")
    a=p.parse_args()
    sys.exit(run(a.checkout,a.python,a.output,a.sfx_cli,a.seed,a.sfx_device))
