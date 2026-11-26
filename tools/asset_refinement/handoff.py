"""Create an isolated Git-layout bundle of explicitly reviewed candidates.

No git commands, no modification of source or game checkout. Approval records
are operator attestations, not an automated visual or legal judgment.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import tempfile
from refine import KEY, load, sha, source, verified, write
from materials import material_source, verified_material

HEX = re.compile(r"[a-f0-9]{64}")
GATES = {"visual", "scale_orientation", "materials", "rights", "godot_import",
         "native_performance", "collision"}
MATERIAL_GATES = {"visual", "physical_scale", "tile_seams", "maps", "rights",
                  "native_shading", "native_performance"}
MAX_FILE = 20*1024**2
MAX_BUNDLE = 100*1024**2


def require(condition, message):
    if not condition:
        raise ValueError(message)


def safe_dir(root, *parts):
    result = root.joinpath(*parts)
    require(result.is_dir() and result.resolve() == result and root in result.parents,
            "Missing or symlinked source directory")
    return result


def evidence(row, gates):
    require(isinstance(row.get("reviewer"),str) and bool(row["reviewer"].strip()),"Reviewer required")
    require(isinstance(row.get("rights_notes"),str) and bool(row["rights_notes"].strip()),"Rights notes required")
    checks = row["review"]
    require(set(checks) == gates, "All review gates must be explicitly present")
    for key, detail in checks.items():
        require(isinstance(detail,dict) and detail.get("passed") is True
                and isinstance(detail.get("evidence"),str) and detail["evidence"].strip(),
                "Missing approval/evidence for "+key)


def import_evidence(refined, row, info):
    # Require a real import report for the exact manifest, not a text-only attestation.
    report = refined / ("godot-%d.json" % info["settings"]["bake_size"])
    require(report.is_file() and not report.is_symlink(), "Godot import report required")
    require(sha(report) == row.get("godot_report_sha256"), "Godot report hash mismatch")
    data = load(report)
    require(data["schema"] == 1 and data["engine"]["version"].startswith("4.7.2.")
            and data["scope"] == "headless structural import only", "Wrong Godot import report")
    matches = [r for r in data["rows"] if r["candidate"] == row["candidate"]
               and r["signature"] == row["signature"]]
    require(len(matches) == 1, "Missing or ambiguous import evidence")
    entry = matches[0]
    require(entry["status"] == "import-passed" and entry["manifest_sha256"] == row["manifest_sha256"],
            "Import evidence does not match approved manifest")
    required = {"lod0.glb","lod1.glb","lod2.glb","collision.glb"}
    require(set(entry["files"]) == required and all(
        entry["files"][n]["sha256"] == info["outputs"][n]["sha256"]
        and all(entry["files"][n][field] > 0 for field in ("meshes","surfaces","vertices"))
        for n in required), "Missing or stale GLB import result")
    return {"engine":data["engine"],"report_sha256":sha(report),"result":entry,
            "scope":data["scope"]}


def gather(raw, refined, materials, approval):
    require(approval.get("schema") == 1, "Unknown approval schema")
    entries = approval["assets"]
    require(isinstance(entries,list) and bool(entries), "No approved assets")
    result = []
    seen = set()
    for row in entries:
        key, sig, kind = row["candidate"],row["signature"],row["kind"]
        require(isinstance(key,str) and KEY.fullmatch(key) and ".." not in key, "Unsafe ID")
        require(isinstance(sig,str) and HEX.fullmatch(sig), "Invalid signature")
        require(key not in seen,"Duplicate approved candidate")
        seen.add(key)
        candidate = safe_dir(raw,"candidates",key)
        import_record = None
        if kind == "prop":
            evidence(row,GATES)
            folder = safe_dir(refined,key,sig)
            manifest = folder/"refinement.json"
            info = load(manifest)
            require(info["candidate"] == key and info["settings"]["source"] == source(candidate)
                    and verified(folder,sig),"Refinement/source verification failed")
            require(info["scale_status"] == "specified-height-only"
                    and info["settings"]["height_m"] is not None,"Measured height required")
            require(info["settings"]["bake_size"] >= 512,"Smoke or unbaked output cannot ship")
            # Collision remains explicit opt-in after its review gate.
            names = ["lod0.glb","lod1.glb","lod2.glb"]
            if row.get("include_collision") is True:
                names.append("collision.glb")
            import_record = import_evidence(refined,row,info)
            meta = ["image.json","mesh.json"]
        elif kind == "material":
            evidence(row,MATERIAL_GATES)
            folder = safe_dir(materials,key,sig)
            manifest = folder/"material.json"
            info = load(manifest)
            require(info["candidate"] == key and info["settings"]["source"] == material_source(candidate)
                    and verified_material(folder,sig,info["settings"]),"Material/source verification failed")
            require(info["settings"]["size"] >= 512,"Smoke material cannot ship")
            names = ["basecolor.png","normal.png","orm.png"]
            meta = ["image.json"]
        else:
            raise ValueError("Unknown asset kind")
        require(sha(manifest) == row["manifest_sha256"],"Review refers to different manifest")
        # Do not ship raw meshes, duplicate baked PNGs, reference concepts or
        # estimated displacement/cavity maps. Only reviewed runtime files.
        copied = [(folder/name,name,info["outputs"][name]["sha256"]) for name in names]
        copied += [(manifest,manifest.name,row["manifest_sha256"])]
        expected = info["settings"]["source"]
        for name in meta:
            digest = expected[name] if kind == "prop" else expected["metadata"]
            copied.append((candidate/name,"source-"+name,digest))
        result.append((row,copied,import_record))
    return result


def stage(raw, refined, materials, out, approval_path):
    approval = load(approval_path)
    rows = gather(raw,refined,materials,approval)
    bundle_id = hashlib.sha256(json.dumps(approval,sort_keys=True).encode()).hexdigest()
    out.mkdir(parents=True,exist_ok=True)
    final = out/bundle_id
    require(not final.exists(),"Bundle already exists; inspect it before exporting again")
    total = sum(p.stat().st_size for _,files,_ in rows for p,_,_ in files)
    require(total <= MAX_BUNDLE,"Bundle exceeds 100 MiB; select fewer assets")
    require(shutil.disk_usage(out).free >= total + 5*1024**3,"Insufficient NAS reserve")
    tmp = Path(tempfile.mkdtemp(prefix=".stage-",dir=out))
    try:
        entries = []
        for row, files, import_record in rows:
            # Isolated repo-relative layout, not an existing game path.
            rel = Path("assets")/"art"/"approved"/"anubis"/row["candidate"]
            dest = tmp/"repo-tree"/rel
            dest.mkdir(parents=True)
            for p,name,digest in files:
                require(not p.is_symlink() and p.stat().st_size <= MAX_FILE,"Symlink or file over 20 MiB")
                target = dest/name
                shutil.copyfile(p,target)
                require(sha(target)==digest and sha(p)==digest,"Copy/source hash mismatch")
                entries.append({"path":(rel/name).as_posix(),"sha256":digest,"bytes":target.stat().st_size})
            if import_record is not None:
                path = dest/"godot-import.json"
                write(path,import_record)
                entries.append({"path":(rel/path.name).as_posix(),"sha256":sha(path),"bytes":path.stat().st_size})
            write(dest/"approval.json",row)
            entries.append({"path":(rel/"approval.json").as_posix(),
                            "sha256":sha(dest/"approval.json"),"bytes":(dest/"approval.json").stat().st_size})
        require(sum(e["bytes"] for e in entries) <= MAX_BUNDLE,"Bundle exceeds size budget")
        write(tmp/"bundle.json",{"schema":1,"id":bundle_id,
              "status":"operator-reviewed-staged-not-committed","files":entries})
        # Rename is atomic on the destination volume. Refuse to overwrite.
        require(not final.exists(),"Concurrent bundle export")
        tmp.rename(final)
    finally:
        if tmp.exists():
            shutil.rmtree(tmp)
    print("Reviewed bundle:",final)
    return final


if __name__ == "__main__":
    p=argparse.ArgumentParser()
    for flag in ("raw","refined","materials","output","approval"):
        p.add_argument("--"+flag,required=True,type=Path)
    args=p.parse_args()
    roots=[getattr(args,n).resolve() for n in ("raw","refined","materials","output")]
    require(all(a!=b and a not in b.parents and b not in a.parents
                for i,a in enumerate(roots) for b in roots[i+1:]),"Roots must be disjoint")
    stage(*roots,args.approval.resolve())
