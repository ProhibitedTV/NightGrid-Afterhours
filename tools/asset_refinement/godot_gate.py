"""Isolated Godot import gate for hash-verified GLBs, not art approval."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from refine import sha, load
from review_queue import scan

FILES = ("lod0.glb", "lod1.glb", "lod2.glb", "collision.glb")
VERSION = re.compile(r"^4\.7\.2(?:[.\-+]|$)")
MARK = "ANUBIS_IMPORT_PASS "


def probe(binary, project, script, file):
    proc = subprocess.run([str(binary),"--headless","--path",str(project),
                           "--script",str(script),"--",str(file)],
                          capture_output=True,text=True,errors="replace",timeout=90)
    output = proc.stdout + "\n" + proc.stderr
    matches = [line[len(MARK):] for line in proc.stdout.splitlines() if line.startswith(MARK)]
    if proc.returncode or len(matches) != 1 or re.search(r"(?:SCRIPT ERROR:|ERROR:|Parse Error)",output):
        raise ValueError("Godot import failed: "+output[-3000:])
    data = json.loads(matches[0])
    if data["surfaces"] <= 0 or data["meshes"] <= 0 or data["vertices"] <= 0:
        raise ValueError("Empty Godot mesh")
    return data


def run(raw, refined, size, binary, output):
    binary = binary.resolve(strict=True)
    version = subprocess.check_output([str(binary),"--version"],text=True,timeout=30).strip()
    if not VERSION.match(version):
        raise ValueError("Expected Godot 4.7.2, got "+version)
    script = Path(__file__).with_name("validate.gd")
    engine = {"version":version,"binary_sha256":sha(binary),"script_sha256":sha(script)}
    rows = []
    with tempfile.TemporaryDirectory(prefix="anubis-godot-") as tmp:
        project = Path(tmp)
        (project/"project.godot").write_text('config_version=5\n[application]\nconfig/name="Anubis Import Gate"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        local_script = project/"validate.gd"
        shutil.copyfile(script,local_script)
        for row in scan(raw,refined,size):
            for item in row.get("versions",[]):
                folder = refined/row["candidate"]/item["signature"]
                record = {"candidate":row["candidate"],"signature":item["signature"],
                          "manifest_sha256":item["manifest_sha256"],"files":{}}
                try:
                    for name in FILES:
                        path = folder/name
                        digest = item["outputs"][name]["sha256"]
                        if sha(path) != digest:
                            raise ValueError("Source changed before import")
                        # Local copy avoids network URI quirks; GLBs are self-contained.
                        local = project/name
                        shutil.copyfile(path,local)
                        if sha(local) != digest:
                            raise ValueError("Copy verification failed")
                        info = probe(binary,project,local_script,local)
                        if sha(path) != digest:
                            raise ValueError("Source changed during import")
                        record["files"][name] = dict(info,sha256=digest)
                    if sha(folder/"refinement.json") != item["manifest_sha256"]:
                        raise ValueError("Manifest changed during import")
                    record["status"] = "import-passed"
                except (OSError,ValueError,KeyError,subprocess.SubprocessError) as exc:
                    record.update(status="import-failed",error=str(exc))
                rows.append(record)
    result = {"schema":1,"engine":engine,"scope":"headless structural import only",
              "passed":sum(r["status"]=="import-passed" for r in rows),
              "failed":sum(r["status"]=="import-failed" for r in rows),"rows":rows}
    with tempfile.NamedTemporaryFile(mode="w",encoding="utf-8",dir=output.parent,delete=False) as f:
        temp = Path(f.name)
        json.dump(result,f,indent=2,sort_keys=True)
    try:
        temp.replace(output)
    finally:
        temp.unlink(missing_ok=True)
    print("Godot import passed=%d failed=%d"%(result["passed"],result["failed"]))
    return int(not rows or bool(result["failed"]))


if __name__=="__main__":
    p=argparse.ArgumentParser()
    for flag in ("raw","refined","godot","output"):
        p.add_argument("--"+flag,type=Path,required=True)
    p.add_argument("--size",type=int,required=True)
    a=p.parse_args()
    if a.output.resolve().parent != a.refined.resolve():
        p.error("Output must be inside refinement root")
    raise SystemExit(run(a.raw.resolve(),a.refined.resolve(),a.size,a.godot,a.output.resolve()))
