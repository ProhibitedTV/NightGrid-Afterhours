"""Read-only qualification gate for optional neural workers. Never executes a model."""
import argparse
import hashlib
import json
from pathlib import Path
import math
import re

REGISTRY=Path(__file__).with_name("neural_workers.json")
HEX=re.compile(r"[0-9a-f]{64}")
REV=re.compile(r"[0-9a-f]{40,64}")
# Conservative proposed pilot limits for Anubis; not measured worker requirements.
GPU_LIMIT_MIB=10240

def sha(path):
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""):h.update(chunk)
    return h.hexdigest()

def artifact(root,record):
    rel=Path(record["path"])
    if rel.is_absolute() or ".." in rel.parts or not rel.parts:
        raise ValueError("Unsafe evidence path")
    if not HEX.fullmatch(record["sha256"]):
        raise ValueError("Invalid artifact digest")
    p=root/rel
    if root not in p.resolve().parents or not p.is_file() or any(
            (root.joinpath(*rel.parts[:i])).is_symlink() for i in range(1,len(rel.parts)+1)):
        raise ValueError("Missing or unsafe artifact")
    if sha(p)!=record["sha256"]:raise ValueError("Artifact hash mismatch: "+str(rel))
    return p

def require_text(data,key):
    value=data[key]
    if not isinstance(value,str) or not value.strip():raise ValueError("Missing "+key)
    return value

def verify(worker,root):
    """Validate an operator-supplied evidence bundle, not its legal merits."""
    root=root.resolve()
    path=root/"qualification.json"
    if path.is_symlink():raise ValueError("Unsafe qualification record")
    d=json.loads(path.read_text())
    if d["schema"]!=1 or d["worker"]!=worker["id"]:
        raise ValueError("Wrong worker evidence")
    identity=d["identity"]
    for key in ("code_revision","weights_revision"):
        if not REV.fullmatch(identity[key]):raise ValueError("Unpinned revision")
    weights=identity["weights"]
    if not weights:raise ValueError("No exact weight files")
    if len({w["path"] for w in weights})!=len(weights):raise ValueError("Duplicate weights")
    for w in weights:artifact(root,w)
    for key in ("environment_lock","dependency_inventory"):
        artifact(root,identity[key])
    rights=d["rights"]
    if rights["decision"]!="cleared-for-commercial-production":
        raise ValueError("Commercial rights not cleared")
    for key in ("reviewer","review_date","scope","obligations","auxiliary_model_review","source_and_voice_rights"):
        require_text(rights,key)
    if rights["identity_sha256"]!=hashlib.sha256(json.dumps(identity,sort_keys=True,separators=(",",":")).encode()).hexdigest():
        raise ValueError("Rights review is for different identity")
    if not rights["license_files"]:raise ValueError("Missing license evidence")
    for record in rights["license_files"]:artifact(root,record)
    bench=d["benchmark"]
    if bench["identity_sha256"]!=rights["identity_sha256"] or bench["baseline"]!=worker["baseline"]:
        raise ValueError("Benchmark identity or baseline mismatch")
    if bench["device"]!="RTX 3060 12GB" or bench["verdict"]!="useful" or bench["offline"] is not True:
        raise ValueError("Local usefulness/offline verification missing")
    require_text(bench,"reviewer");require_text(bench,"benefit")
    for key in ("peak_vram_mib","peak_ram_mib","elapsed_seconds"):
        v=bench[key]
        if isinstance(v,bool) or not isinstance(v,(int,float)) or not math.isfinite(v) or v<0:
            raise ValueError("Invalid benchmark measurement")
    if not 0<=bench["peak_vram_mib"]<=GPU_LIMIT_MIB or bench["peak_ram_mib"]<=0 or bench["elapsed_seconds"]<=0:
        raise ValueError("Pilot budget or measurement failed")
    cases=bench["cases"]
    if len(cases)<3 or len({c["id"] for c in cases})!=len(cases):
        raise ValueError("Need three distinct comparison cases")
    for case in cases:
        require_text(case,"id")
        if case["technical_pass"] is not True or case["human_review_pass"] is not True:
            raise ValueError("Candidate comparison failed")
        for key in ("input","baseline_output","candidate_output","report"):
            artifact(root,case[key])
    # This gate does not approve a model automatically or authorize a command.
    return {"worker":worker["id"],"state":"eligible-for-adapter-review",
            "identity_sha256":rights["identity_sha256"],
            "qualification_sha256":sha(path),"case_count":len(cases),
            "peak_vram_mib":bench["peak_vram_mib"],"production_enabled":False}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--worker")
    p.add_argument("--evidence",type=Path)
    a=p.parse_args()
    workers=json.loads(REGISTRY.read_text())["workers"]
    if not a.worker and not a.evidence:
        print(json.dumps(workers,indent=2));return
    if not a.worker or not a.evidence:p.error("Both --worker and --evidence required")
    worker=next((w for w in workers if w["id"]==a.worker),None)
    if worker is None:p.error("Unknown worker")
    try:print(json.dumps(verify(worker,a.evidence),indent=2))
    except (OSError,ValueError,TypeError,KeyError) as exc:p.exit(2,"Qualification blocked: "+str(exc)+"\n")

if __name__=="__main__":main()
