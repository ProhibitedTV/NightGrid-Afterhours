"""Small atomic factory run ledger. No asset approval, credentials or job scheduling."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import tempfile
import uuid

from refine import sha
from telemetry import snapshot

STAGES=("generation","refinement","materials","review","budgets","godot",
        "previews","contact-sheets","duplicates","triage","audio")
RUN_ID=re.compile(r"[0-9]{8}T[0-9]{6}Z-[a-f0-9]{12}")


def now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def atomic(path,data):
    with tempfile.NamedTemporaryFile(mode="w",encoding="utf-8",dir=path.parent,delete=False) as f:
        tmp=Path(f.name)
        json.dump(data,f,indent=2,sort_keys=True)
        f.write("\n")
        f.flush()
    try:
        tmp.replace(path)
    finally:
        tmp.unlink(missing_ok=True)


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def start(root,mode):
    root.mkdir(parents=True,exist_ok=True)
    ident=datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")+"-"+uuid.uuid4().hex[:12]
    run=root/ident
    run.mkdir()
    atomic(run/"run.json",{"schema":1,"id":ident,"mode":mode,"started":now(),
                           "status":"running","scope":"production processes, not asset approval",
                           "hardware_start":snapshot(),
                           "stages":{s:{"status":"pending"} for s in STAGES}})
    atomic(root/"latest.json",{"id":ident})
    return run


def change(run,action,stage=None,code=None,reason=None):
    if not RUN_ID.fullmatch(run.name) or run.is_symlink():
        raise ValueError("Invalid run path")
    path=run/"run.json"
    data=read(path)
    if data["id"]!=run.name or data["status"]!="running":
        raise ValueError("Run is not active")
    stages=data["stages"]
    if action=="finish":
        for item in stages.values():
            if item["status"]=="running":
                item.update(status="interrupted",finished=now())
        bad=any(s["status"] in ("pending","running","failed","interrupted") for s in stages.values())
        data.update(status="failed" if code or bad else "completed",
                    finished=now(),exit_code=code,hardware_finish=snapshot())
    else:
        item=stages[stage]
        if action=="begin" and item["status"]=="pending":
            item.update(status="running",started=now(),hardware_start=snapshot())
        elif action=="skip" and item["status"]=="pending":
            item.update(status="skipped",reason=reason,finished=now())
        elif action=="end" and item["status"]=="running":
            log=run/(stage+".log")
            item.update(status="failed" if code else "completed",finished=now(),exit_code=code,hardware_finish=snapshot())
            if log.is_file():
                item.update(log=log.name,log_sha256=sha(log))
        else:
            raise ValueError("Invalid stage transition: "+stage)
    atomic(path,data)


def status(root):
    latest=root/"latest.json"
    if not latest.is_file():
        print("No factory run ledger exists yet.")
        return
    ident=read(latest)["id"]
    if not RUN_ID.fullmatch(ident):
        raise ValueError("Invalid latest run ID")
    run=root/ident
    if run.is_symlink():
        raise ValueError("Symlink run not allowed")
    data=read(run/"run.json")
    print("Factory",data["id"],data["mode"],data["status"])
    print("Started:",data["started"])
    for name in STAGES:
        item=data["stages"].get(name,{"status":"not recorded"})
        print("%-16s %s %s"%(name,item["status"],item.get("reason","")))
    if data["status"]=="running":
        print("Ledger may be stale after power loss; inspect process locks. No jobs are started by status.")
    print("Run directory:",run)


def main():
    p=argparse.ArgumentParser()
    sub=p.add_subparsers(dest="action",required=True)
    for name in ("start","status"):
        q=sub.add_parser(name)
        q.add_argument("--root",required=True,type=Path)
        if name=="start":
            q.add_argument("--mode",choices=["full","existing","smoke"],required=True)
    for name in ("begin","end","skip","finish"):
        q=sub.add_parser(name)
        q.add_argument("--run",required=True,type=Path)
        if name!="finish":
            q.add_argument("--stage",choices=STAGES,required=True)
        if name in ("end","finish"):
            q.add_argument("--code",required=True,type=int)
        if name=="skip":
            q.add_argument("--reason",required=True)
    a=p.parse_args()
    if a.action=="start":
        print(start(a.root,a.mode))
    elif a.action=="status":
        status(a.root)
    else:
        change(a.run,a.action,getattr(a,"stage",None),getattr(a,"code",None),getattr(a,"reason",None))


if __name__=="__main__":
    main()
