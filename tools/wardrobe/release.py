"""Explicit, offline review handoff. Never activates items in the game."""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from author import BASE, ROOT, SPEC, candidate_rows, glb, profile, require, validate

POSES={"idle","walk","run","sit","drive_car","aim"}
CHECKS={"body_coverage","joint_clipping","hair_clearance","footwear","vehicle_clearance","camera_clearance","license"}
CANDIDATES=ROOT/"assets/models/nightgrid/wardrobe_candidates"
STAGING=ROOT/"dist/wardrobe-approved"
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def file_in(folder, name):
    require(isinstance(name,str) and re.fullmatch(r"[a-zA-Z0-9_.-]+",name) and name not in (".",".."),"Unsafe evidence filename")
    p=folder/name
    require(p.is_file() and not p.is_symlink(),"Missing or linked evidence: "+name)
    return p

def load_json(path):
    return json.loads(path.read_text(encoding="utf-8"))

def review_record(review, evidence, ident, asset_hash, base_hash, profile_hash):
    require(review.get("schema")==1 and review.get("id")==ident,"Wrong review candidate")
    for key,value in {"sha256":asset_hash,"base_sha256":base_hash,"profile_sha256":profile_hash}.items():
        require(review.get(key)==value,"Stale review: "+key)
    require(isinstance(review.get("reviewer"),str) and bool(review["reviewer"].strip()),"Reviewer required")
    require(isinstance(review.get("license_notes"),str) and bool(review["license_notes"].strip()),"License provenance required")
    require(review.get("decision")=="approved","Explicit manual approval required")
    checks=review.get("checks",{})
    require(isinstance(checks,dict) and set(checks)==CHECKS and all(v is True for v in checks.values()),"All review checks must pass")
    captures=review.get("captures",[])
    require(isinstance(captures,list) and len(captures)==len(POSES),"One native candidate capture per required pose")
    require({c.get("pose") for c in captures}==POSES,"Required pose capture missing")
    names=[c.get("file") for c in captures]
    require(len(set(names))==len(names),"Duplicate capture")
    files=[]
    for c in captures:
        p=file_in(evidence,c["file"])
        prefix=ident+"_"+c["pose"]+"_candidate_"+asset_hash[:12]+"_"
        require(p.name.startswith(prefix) and re.fullmatch(r"\d+\.png",p.name[len(prefix):]),"Capture not bound to selected candidate and pose")
        require(p.suffix.lower()==".png" and p.read_bytes()[:8]==b"\x89PNG\r\n\x1a\n","Expected PNG capture")
        require(sha(p)==c.get("sha256"),"Capture hash mismatch")
        require(p.stat().st_size<=20000000,"Capture size budget exceeded")
        files.append(p)
    return files

def draft_record(ident, report, evidence):
    """Collect candidate-hash-bound screenshots, never approve them."""
    captures=[]
    for pose in sorted(POSES):
        pattern=re.compile(re.escape(ident)+"_"+pose+"_candidate_"+re.escape(report["sha256"][:12])+r"_(\d+)\.png")
        matches=[]
        for p in evidence.glob("*.png"):
            m=pattern.fullmatch(p.name)
            if m and p.is_file() and not p.is_symlink():
                matches.append((int(m.group(1)),p))
        if matches:
            p=max(matches,key=lambda row:row[0])[1]
            captures.append({"pose":pose,"file":p.name,"sha256":sha(p)})
    return {"schema":1,"id":ident,"sha256":report["sha256"],"base_sha256":report["base_sha256"],
            "profile_sha256":report["profile_sha256"],"reviewer":"","decision":"pending",
            "license_notes":"","checks":{k:False for k in sorted(CHECKS)},"captures":captures}

def write_draft(ident, candidate_root, evidence, destination):
    spec=load_json(SPEC)
    require(ident in candidate_rows(spec),"Unknown candidate")
    folder=candidate_root/ident
    report=load_json(file_in(folder,"candidate.json"))
    require(report.get("id")==ident and report.get("sha256")==sha(file_in(folder,"Morrow_Courier.glb")),"Candidate report does not match model")
    require(report.get("base_sha256")==sha(BASE) and report.get("profile_sha256")==sha(file_in(folder,"appearance.json")),"Candidate report is stale")
    require(evidence.is_dir(),"Missing capture directory")
    record=draft_record(ident,report,evidence)
    with destination.open("x",encoding="utf-8") as out:
        json.dump(record,out,indent=2)
        out.write("\n")
    print("WARDROBE REVIEW DRAFT",ident,len(record["captures"]),"of",len(POSES),"captures; manual review required")

def stage(ident, candidate_root, review_path, evidence, staging):
    spec=load_json(SPEC)
    rows=candidate_rows(spec)
    require(ident in rows,"Unknown candidate")
    source=candidate_root/ident
    model=file_in(source,"Morrow_Courier.glb")
    params=file_in(source,"appearance.json")
    report=load_json(file_in(source,"candidate.json"))
    require(load_json(params)==profile(spec,rows[ident]),"Wrong appearance profile")
    base=glb(BASE)
    fresh=validate(model,base,rows[ident],spec["limits"])
    hashes={"sha256":fresh["sha256"],"base_sha256":sha(BASE),"profile_sha256":sha(params)}
    require(report.get("id")==ident and report.get("source")==spec["source"] and report.get("source_revision")==spec["source_revision"],"Wrong candidate provenance")
    require(all(report.get(k)==v for k,v in hashes.items()),"Stale candidate report")
    review=load_json(review_path)
    files=review_record(review,evidence,ident,hashes["sha256"],hashes["base_sha256"],hashes["profile_sha256"])
    staging.mkdir(parents=True,exist_ok=True)
    dest=staging/ident
    require(not dest.exists(),"Staging destination already exists; review before replacing")
    with tempfile.TemporaryDirectory(dir=staging,prefix=".review-") as temporary:
        temp=Path(temporary)/ident
        temp.mkdir()
        for p in [model,params]:
            shutil.copyfile(p,temp/p.name)
        (temp/"evidence").mkdir()
        for p in files:
            shutil.copyfile(p,temp/"evidence"/p.name)
        (temp/"review.json").write_text(json.dumps(review,indent=2)+"\n")
        fresh.update(hashes,id=ident,source=spec["source"],source_revision=spec["source_revision"],reviewed=True,gameplay_enabled=False)
        (temp/"manifest.json").write_text(json.dumps(fresh,indent=2)+"\n")
        require(sha(temp/model.name)==hashes["sha256"] and sha(temp/params.name)==hashes["profile_sha256"],"Staging copy changed")
        review_record(review,temp/"evidence",ident,hashes["sha256"],hashes["base_sha256"],hashes["profile_sha256"])
        temp.rename(dest)
    print("WARDROBE STAGED",ident,"reviewed handoff only; no gameplay activation")

def check_checkout():
    tracked=subprocess.check_output(["git","ls-files","-z","--","assets/models/nightgrid/wardrobe_candidates","dist/wardrobe-approved"],cwd=ROOT).split(b"\0")
    require(not any(tracked),"Review-only wardrobe assets must not be tracked")
    print("WARDROBE CHECKOUT PASS: no candidate or staging assets tracked")

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action",choices=["check-checkout","draft","stage"])
    parser.add_argument("--id")
    parser.add_argument("--candidate-root",type=Path,default=CANDIDATES)
    parser.add_argument("--review",type=Path)
    parser.add_argument("--evidence",type=Path)
    args=parser.parse_args()
    if args.action=="check-checkout":
        check_checkout()
        return
    require(args.id and args.review and args.evidence,"Requires ID, review JSON path and evidence directory")
    if args.action=="draft":
        write_draft(args.id,args.candidate_root,args.evidence,args.review)
        return
    stage(args.id,args.candidate_root,args.review,args.evidence,STAGING)

if __name__=="__main__":
    main()
