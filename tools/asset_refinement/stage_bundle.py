"""Verify an explicitly approved handoff bundle and stage only its new paths.

Default is a read-only preview. No commits, pushes, overwrite, force-add or
changes to an already dirty checkout. Operator approval is not authentication.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
from refine import KEY, sha, load
from handoff import HEX, MAX_FILE, MAX_BUNDLE, evidence, GATES, MATERIAL_GATES, require

PREFIX=("assets","art","approved","anubis")


def git(repo,*args):
    return subprocess.check_output(["git","-C",str(repo),*args],stderr=subprocess.STDOUT)


def validate(bundle):
    require(bundle.is_dir() and not bundle.is_symlink(),"Missing bundle")
    manifest=bundle/"bundle.json"
    require(manifest.is_file() and not manifest.is_symlink(),"Missing manifest")
    info=load(manifest)
    require(info["schema"]==1 and info["status"]=="operator-reviewed-staged-not-committed"
            and HEX.fullmatch(info["id"]) and bundle.name==info["id"],"Wrong bundle identity")
    rows=info["files"]
    require(isinstance(rows,list) and bool(rows),"Empty bundle")
    tree=bundle/"repo-tree"
    require(tree.is_dir() and not tree.is_symlink(),"Missing repo-tree")
    seen=set()
    by_asset={}
    total=0
    for row in rows:
        name=row["path"]
        rel=PurePosixPath(name)
        require(rel.as_posix()==name and len(rel.parts)==6 and rel.parts[:4]==PREFIX
                and KEY.fullmatch(rel.parts[4]) and ".." not in rel.parts[4]
                and rel.name not in (".","..") and "\\" not in name,"Unsafe bundle path")
        require(name not in seen,"Duplicate path")
        seen.add(name)
        src=tree.joinpath(*rel.parts)
        require(src.is_file() and src.resolve()==src and not src.is_symlink(),"Missing/symlinked file")
        size=src.stat().st_size
        require(type(row["bytes"]) is int and size==row["bytes"] and 0<size<=MAX_FILE
                and HEX.fullmatch(row["sha256"]) and sha(src)==row["sha256"],"File size/hash mismatch")
        total+=size
        require(total<=MAX_BUNDLE,"Bundle size limit")
        by_asset.setdefault(rel.parts[4],{})[rel.name]=src
    actual={p.relative_to(tree).as_posix() for p in tree.rglob("*") if p.is_file()}
    require(actual==seen and not any(p.is_symlink() for p in tree.rglob("*")),"Unexpected bundle files")
    approvals=[]
    for key,files in by_asset.items():
        row=load(files["approval.json"])
        require(row["candidate"]==key and HEX.fullmatch(row["signature"]),"Approval identity mismatch")
        if row["kind"]=="prop":
            evidence(row,GATES)
            expected={"lod0.glb","lod1.glb","lod2.glb","refinement.json","source-image.json","source-mesh.json","godot-import.json","approval.json"}
            if row.get("include_collision") is True:
                expected.add("collision.glb")
            meta=load(files["refinement.json"])
            require(meta["scale_status"]=="specified-height-only" and meta["settings"]["height_m"] is not None
                    and meta["settings"]["bake_size"]>=512,"Missing production dimensions/texture")
            report=load(files["godot-import.json"])
            require(report["report_sha256"]==row["godot_report_sha256"]
                    and report["engine"]["version"].startswith("4.7.2.")
                    and report["result"]["status"]=="import-passed"
                    and report["result"]["manifest_sha256"]==row["manifest_sha256"]
                    and report["result"]["candidate"]==key and report["result"]["signature"]==row["signature"],"Wrong import evidence")
            for n in ("lod0.glb","lod1.glb","lod2.glb","collision.glb"):
                record=report["result"]["files"][n]
                require(record["sha256"]==meta["outputs"][n]["sha256"]
                        and all(record[k]>0 for k in ("meshes","surfaces","vertices")),"Invalid import record")
            manifest_name="refinement.json"
            source_names={"source-image.json":"image.json","source-mesh.json":"mesh.json"}
        elif row["kind"]=="material":
            evidence(row,MATERIAL_GATES)
            expected={"basecolor.png","normal.png","orm.png","material.json","source-image.json","approval.json"}
            meta=load(files["material.json"])
            require(meta["settings"]["size"]>=512,"Smoke material")
            manifest_name="material.json"
            source_names={"source-image.json":"metadata"}
        else:
            raise ValueError("Unknown asset kind")
        require(set(files)==expected,"Unexpected runtime/provenance files")
        require(meta["candidate"]==key and meta["signature"]==row["signature"]
                and meta["status"]=="unapproved" and sha(files[manifest_name])==row["manifest_sha256"],"Wrong reviewed manifest")
        for n in files:
            if n in meta["outputs"]:
                require(sha(files[n])==meta["outputs"][n]["sha256"],"Output differs from reviewed manifest")
        for n,source_key in source_names.items():
            require(sha(files[n])==meta["settings"]["source"][source_key],"Source metadata mismatch")
        approvals.append(row)
    # Handoff hash preserves ordered approvals. Recover order from the file list.
    expected_id=hashlib.sha256(json.dumps({"schema":1,"assets":approvals},sort_keys=True).encode()).hexdigest()
    require(expected_id==info["id"],"Approval bundle identity mismatch (schema must contain only schema/assets)")
    return rows


def stage(bundle,repo,apply=False):
    bundle,repo=bundle.resolve(),repo.resolve()
    require(repo!=bundle and repo not in bundle.parents and bundle not in repo.parents,"Bundle must be outside checkout")
    rows=validate(bundle)
    require(Path(git(repo,"rev-parse","--show-toplevel").decode().strip()).resolve()==repo,"Specify Git checkout root")
    branch=git(repo,"symbolic-ref","--short","HEAD").decode().strip()
    require(branch not in ("main","master"),"Use a dedicated review branch")
    require(not git(repo,"status","--porcelain","--untracked-files=all"),"Checkout must be clean")
    names=[r["path"] for r in rows]
    for name in names:
        dest=repo/name
        require(dest.resolve()==dest and not dest.exists(),"Target already exists or symlinked: "+name)
    if git(repo,"ls-files","--",*names):
        raise ValueError("Target already tracked")
    total=sum(r["bytes"] for r in rows)
    print("Branch:",branch,"files:",len(names),"bytes:",total)
    for name in names:
        print("ADD",name)
    if not apply:
        print("Preview only; no changes")
        return
    require(shutil.disk_usage(repo).free>=total+5*1024**3,"Insufficient checkout storage reserve")
    created=[]
    dirs=[]
    try:
        for row in rows:
            dest=repo/row["path"]
            missing=[]
            parent=dest.parent
            while not parent.exists():
                missing.append(parent)
                parent=parent.parent
            for directory in reversed(missing):
                directory.mkdir()
                dirs.append(directory)
            with dest.open("xb") as out:
                created.append(dest)
                with (bundle/"repo-tree"/row["path"]).open("rb") as src:
                    shutil.copyfileobj(src,out)
            require(sha(dest)==row["sha256"],"Copy hash mismatch")
        git(repo,"add","--",*names)
        staged=set(git(repo,"diff","--cached","--name-only","-z").decode().split("\0"))-{""}
        require(staged==set(names),"Unexpected staged paths")
        print(git(repo,"diff","--cached","--stat").decode())
    except BaseException:
        # Only paths created by this invocation; initial index was clean.
        subprocess.run(["git","-C",str(repo),"reset","-q","HEAD","--",*names],check=False)
        for dest in reversed(created):
            dest.unlink(missing_ok=True)
        for directory in reversed(dirs):
            try:
                directory.rmdir()
            except OSError:
                pass
        raise
    print("Staged only. Review git diff --cached; no commit or push performed.")


if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--bundle",type=Path,required=True)
    p.add_argument("--repo",type=Path,required=True)
    p.add_argument("--apply",action="store_true")
    a=p.parse_args()
    stage(a.bundle,a.repo,a.apply)
