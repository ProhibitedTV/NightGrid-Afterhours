"""GPU-independent batch coordinator. No game paths are written."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = Path(os.environ.get("ANUBIS_VISUAL_OUT", ROOT / "dist" / "anubis-visual" / "visual-001")).resolve()
HOME = Path(os.environ.get("ANUBIS_VISUAL_HOME", Path.home() / ".local/share/nightgrid-visual-v1"))
ID = re.compile(r"[a-z0-9][a-z0-9.-]{0,100}")
BATCH_ID = re.compile(r"visual-[a-z0-9][a-z0-9-]{0,40}")
CATALOG = Path(os.environ.get("ANUBIS_VISUAL_CATALOG", HERE / "catalog.json")).resolve()

def guard_storage(output=None):
    """Refuse fallback to a local /mnt/z directory and protect physical SSD."""
    output = Path(output or OUT).resolve()
    mount = Path("/mnt/z")
    if mount == output or mount in output.parents:
        if not os.path.ismount(mount):
            raise RuntimeError("NAS /mnt/z is not mounted")
    if Path("/mnt/c").is_mount() and shutil.disk_usage("/mnt/c").free < 25*1024**3:
        raise RuntimeError("Windows physical SSD reserve below 25 GiB")
    # Check nearest existing parent without creating a fallback output directory.
    probe = output
    while not probe.exists() and probe != probe.parent:
        probe = probe.parent
    if shutil.disk_usage(probe).free < 5*1024**3:
        raise RuntimeError("Output volume reserve below 5 GiB")


def digest(path):
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()

def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(path)

def catalog():
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    if data["schema"] != 1 or not BATCH_ID.fullmatch(data["batch"]):
        raise ValueError("Invalid catalog schema or batch ID")
    variants = data["variants"]
    if type(variants) is not int or not 1 <= variants <= 16:
        raise ValueError("Catalog variants must be 1..16")
    if not isinstance(data["assets"], list) or not 1 <= len(data["assets"]) <= 10000:
        raise ValueError("Catalog needs 1..10000 assets")
    if len(data["assets"]) * variants > 20000:
        raise ValueError("Maximum 20000 image jobs per batch")
    if CATALOG != (HERE / "catalog.json").resolve():
        if not os.environ.get("ANUBIS_VISUAL_OUT") or OUT.name != data["batch"]:
            raise ValueError("Custom catalogs require an explicit output named after the batch")
        if data["batch"] == "visual-001":
            raise ValueError("Reserve visual-001 for the original catalog")
    return data


def jobs(smoke=False):
    data = catalog()
    result = []
    seen = set()
    for asset in data["assets"]:
        key = asset["id"]
        if not ID.fullmatch(key) or ".." in key or key in seen or asset["kind"] not in {"prop", "material"}:
            raise ValueError("Invalid asset ID or kind: " + key)
        if not isinstance(asset.get("subject"),str) or not 1 <= len(asset["subject"].strip()) <= 1000:
            raise ValueError("Missing or oversized asset subject: "+key)
        if not isinstance(asset.get("group"),str) or not ID.fullmatch(asset["group"]):
            raise ValueError("Invalid asset group: "+key)
        seen.add(key)
        for variant in range(data["variants"]):
            job = dict(asset, variant=variant, seed=int(hashlib.sha256(f"{key}:{variant}".encode()).hexdigest()[:8],16))
            job["key"] = f"{key}.v{variant+1}"
            result.append(job)
    if smoke:
        return [next(j for j in result if j["kind"] == k) for k in ("prop", "material") if any(j["kind"]==k for j in result)]
    return result

def verified(path, meta, job):
    try:
        info = json.loads(meta.read_text())
        return path.is_file() and path.stat().st_size > 0 and info["job"] == job and info["sha256"] == digest(path)
    except (OSError, ValueError, KeyError, TypeError):
        return False

def lock_catalog():
    """Immutable catalog identity; default batch 001 can adopt existing output."""
    snapshot = OUT / "catalog.lock.json"
    data = catalog()
    canonical = json.dumps(data,sort_keys=True,separators=(",",":"))
    expected = {"batch":data["batch"],"sha256":hashlib.sha256(canonical.encode()).hexdigest(),"catalog":data}
    if snapshot.exists():
        if json.loads(snapshot.read_text()) != expected:
            raise ValueError("Catalog changed; choose a new batch and output directory")
    else:
        if CATALOG != (HERE/"catalog.json").resolve() and (OUT/"candidates").exists():
            raise ValueError("Cannot adopt an existing custom candidate directory without a catalog lock")
        write_json(snapshot,expected)


def choose_pending(rows, keys=(), groups=(), limit=0):
    if set(keys)-{r["key"] for r in rows} or set(groups)-{r["group"] for r in rows}:
        raise ValueError("Unknown candidate key or group")
    chosen=[r for r in rows if r["status"]=="pending"
            and (not keys or r["key"] in keys)
            and (not groups or r["group"] in groups)]
    return chosen[:limit] if limit else chosen


def inventory():
    rows = []
    for job in jobs():
        folder = OUT / "candidates" / job["key"]
        image = verified(folder / "concept.png", folder / "image.json", job)
        mesh = image and verified(folder / "mesh.glb", folder / "mesh.json", job)
        if mesh:
            mesh = json.loads((folder / "mesh.json").read_text()).get("input_sha256") == digest(folder / "concept.png")
        rows.append(dict(job, image_ready=image, mesh_ready=mesh, status="candidate-only" if image and (mesh or job["kind"]=="material") else "pending"))
    return rows

def pack():
    rows = inventory()
    batch_id = catalog()["batch"]
    dest = OUT / "handoff"
    dest.mkdir(parents=True, exist_ok=True)
    write_json(OUT / "inventory.json", rows)
    # Stage separate numbered packs; each contains complete candidate folders.
    # An individual huge candidate may exceed the target; never split a GLB.
    staging = dest / ".next"
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir()
    part, size, archive = 0, 0, None
    try:
        for row in rows:
            if row["status"] != "candidate-only":
                continue
            folder = OUT / "candidates" / row["key"]
            names = ["concept.png","image.json"] + (["mesh.glb","mesh.json"] if row["kind"]=="prop" else [])
            total = sum((folder / name).stat().st_size for name in names)
            if archive is None or size + total > 75 * 1024**2:
                if archive:
                    archive.close()
                part += 1
                archive = zipfile.ZipFile(staging / f"{batch_id}-{part:03}.zip","w",zipfile.ZIP_DEFLATED)
                size = 0
            for name in names:
                archive.write(folder / name, f"candidates/{row['key']}/{name}")
            size += total
    finally:
        if archive:
            archive.close()
    for old in dest.glob(f"{batch_id}-*.zip"):
        old.unlink()
    for new in staging.iterdir():
        new.replace(dest / new.name)
    staging.rmdir()
    write_json(dest / "index.json", {"status":"candidate-only","packs":[{"file":p.name,"sha256":digest(p),"bytes":p.stat().st_size} for p in sorted(dest.glob("*.zip"))],"inventory":rows})
    print(f"Handoff: {dest} ({part} packs)")

def main():
    p = argparse.ArgumentParser()
    p.add_argument("mode", choices=["plan","status","pack","smoke","full","retry"])
    p.add_argument("--key",action="append",default=[])
    p.add_argument("--group",action="append",default=[])
    p.add_argument("--limit",type=int,default=0)
    args = p.parse_args()
    if args.limit<0 or (args.mode!="retry" and (args.key or args.group or args.limit)):
        p.error("Retry selectors require retry mode and nonnegative limit")
    selected = jobs(args.mode=="smoke")
    if args.mode == "plan":
        print(f"{len(selected)} image jobs, {sum(j['kind']=='prop' for j in selected)} mesh jobs")
        return 0
    if args.mode == "status":
        if Path("/mnt/z") in OUT.parents and not os.path.ismount("/mnt/z"):
            raise RuntimeError("NAS /mnt/z is not mounted")
        rows = inventory()
        print(f"{sum(r['image_ready'] for r in rows)}/{len(rows)} images; {sum(r['mesh_ready'] for r in rows)}/{sum(r['kind']=='prop' for r in rows)} meshes")
        return 0
    if args.mode == "pack":
        guard_storage()
        OUT.mkdir(parents=True,exist_ok=True)
        lock_catalog()
        pack()
        return 0
    guard_storage()
    OUT.mkdir(parents=True, exist_ok=True)
    lock_catalog()
    if args.mode=="retry":
        pending_keys={r["key"] for r in choose_pending(inventory(),args.key,args.group,args.limit)}
        selected=[j for j in selected if j["key"] in pending_keys]
        if not selected:
            print("No matching incomplete candidates")
            return 0
    plan = OUT / "run-plan.json"
    write_json(plan, selected)
    if shutil.disk_usage(OUT).free < 5 * 1024**3:
        raise RuntimeError("Need at least 5 GiB free on output volume; model cache needs additional space")
    errors = []
    for stage in ("image","mesh"):
        guard_storage()
        py = HOME / stage / "bin/python"
        command = [str(py), str(HERE / "worker.py"), stage, str(plan), str(OUT)]
        rc = subprocess.run(command, cwd=HERE).returncode
        if rc:
            errors.append((stage, rc))
    guard_storage()
    pack()
    rows = {r["key"]:r for r in inventory()}
    pending = [j["key"] for j in selected if rows[j["key"]]["status"]!="candidate-only"]
    write_json(OUT/"retry-queue.json", {"batch":catalog()["batch"],"pending":[r for r in rows.values() if r["status"]=="pending"],"last_selected":[j["key"] for j in selected],"stage_errors":errors})
    print(f"Requested={len(selected)}, pending={len(pending)}, stage errors={errors}")
    return int(bool(pending or errors))

if __name__ == "__main__":
    sys.exit(main())
