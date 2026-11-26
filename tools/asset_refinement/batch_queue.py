"""Explicit sequential local batch queue. No daemon, automatic approval or publication."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from factory_ledger import atomic, now

BATCH = re.compile(r"visual-[a-z0-9][a-z0-9-]{0,40}")
QUEUE = re.compile(r"[a-z0-9][a-z0-9-]{0,40}")


def plan(path):
    data=json.loads(path.read_text(encoding="utf-8"))
    if data["schema"]!=1 or not QUEUE.fullmatch(data["id"]):
        raise ValueError("Invalid queue identity")
    rows=data["batches"]
    if not isinstance(rows,list) or not 1<=len(rows)<=100:
        raise ValueError("Queue must contain 1..100 batches")
    seen=set()
    result=[]
    for row in rows:
        batch=row["batch"]
        mode=row.get("mode","full")
        if not BATCH.fullmatch(batch) or batch in seen or mode not in ("full","existing","smoke"):
            raise ValueError("Invalid or duplicate batch")
        seen.add(batch)
        catalog=row.get("catalog")
        if batch!="visual-001" and not catalog:
            raise ValueError("Custom batch requires catalog")
        if batch=="visual-001" and catalog:
            raise ValueError("Original batch uses built-in catalog")
        if catalog:
            cat=(path.parent/catalog).resolve()
            if not cat.is_file():
                raise ValueError("Catalog missing")
            raw=cat.read_bytes()
            if json.loads(raw)["batch"]!=batch:
                raise ValueError("Catalog batch mismatch")
            catalog=str(cat)
            digest=hashlib.sha256(raw).hexdigest()
        else:
            digest=None
        result.append({"batch":batch,"mode":mode,"catalog":catalog,"catalog_sha256":digest})
    return data["id"],result


def run(path,root,launcher,invoke=subprocess.run):
    ident,rows=plan(path)
    root.mkdir(parents=True,exist_ok=True)
    with (root/".queue.lock").open("a") as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        state_path=root/(ident+".json")
        if state_path.exists():
            state=json.loads(state_path.read_text())
            if state["plan"]!=rows:
                raise ValueError("Queue plan changed; choose a new queue ID")
        else:
            state={"schema":1,"id":ident,"plan":rows,"created":now(),
                   "entries":{r["batch"]:{"status":"pending","attempts":0} for r in rows}}
        for row in rows:
            batch=row["batch"]
            entry=state["entries"][batch]
            if entry["status"]=="completed":
                continue
            if row["catalog"] and hashlib.sha256(Path(row["catalog"]).read_bytes()).hexdigest()!=row["catalog_sha256"]:
                raise ValueError("Catalog changed after queue planning")
            # All custom outputs are determined by the factory, not supplied shell commands.
            env=dict(os.environ,ANUBIS_BATCH=batch,ANUBIS_SKIP_AUDIO="1")
            env.pop("ANUBIS_VISUAL_CATALOG",None)
            if row["catalog"]:
                env["ANUBIS_VISUAL_CATALOG"]=row["catalog"]
            entry.update(status="running",started=now(),attempts=entry["attempts"]+1)
            atomic(state_path,state)
            print("Queue batch:",batch,flush=True)
            try:
                rc=invoke(["bash",str(launcher),row["mode"]],env=env).returncode
            except KeyboardInterrupt:
                entry.update(status="interrupted",finished=now(),exit_code=130)
                atomic(state_path,state)
                return 130
            entry.update(status="completed" if rc==0 else "failed",finished=now(),exit_code=rc)
            atomic(state_path,state)
            if rc:
                print("Queue paused at",batch,"; rerun after correcting the failure.")
                return rc
        print("Queue processes completed; assets still require review.")
        return 0


def main():
    p=argparse.ArgumentParser()
    p.add_argument("manifest",type=Path)
    p.add_argument("--root",type=Path,required=True)
    a=p.parse_args()
    return run(a.manifest.resolve(),a.root.resolve(),Path(__file__).with_name("run_factory.sh"))


if __name__=="__main__":
    sys.exit(main())
