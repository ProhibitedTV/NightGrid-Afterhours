"""Generate a private, static production dashboard on NAS. No server or browser API."""
import argparse
from datetime import datetime, timezone
from html import escape
import json
from pathlib import Path
import re
from factory_ledger import atomic, STAGES, RUN_ID
from refine import sha
import tempfile

BATCH=re.compile(r"visual-[a-z0-9][a-z0-9-]{0,40}")


def load_safe(path):
    try:
        if path.is_symlink() or not path.is_file() or path.stat().st_size>64*1024**2:
            return None
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError,ValueError):
        return None


def collect(root):
    batches=[]
    for folder in sorted(root.iterdir()):
        if not folder.is_dir() or folder.is_symlink() or not BATCH.fullmatch(folder.name):
            continue
        batch=folder.name
        suffix=batch.removeprefix("visual-")
        inventory=load_safe(folder/"inventory.json")
        counts=None
        if isinstance(inventory,list):
            counts={"images":sum(r.get("image_ready") is True for r in inventory),
                    "image_total":len(inventory),
                    "meshes":sum(r.get("mesh_ready") is True and r.get("kind")=="prop" for r in inventory),
                    "mesh_total":sum(r.get("kind")=="prop" for r in inventory)}
        refined=root/("refined-"+suffix)
        review=load_safe(refined/"review-1024.json")
        triage=load_safe(refined/"triage-1024.json")
        material=load_safe(root/"Materials"/("material-"+suffix)/"review-1024.json")
        godot=load_safe(refined/"godot-1024.json")
        runs=root/"FactoryRuns"
        if batch!="visual-001":
            runs=runs/batch
        latest=load_safe(runs/"latest.json")
        ledger=None
        if isinstance(latest,dict) and isinstance(latest.get("id"),str) and RUN_ID.fullmatch(latest["id"]):
            candidate=runs/latest["id"]
            if not candidate.is_symlink():
                ledger=load_safe(candidate/"run.json")
        batches.append({"batch":batch,"counts":counts,"review":review.get("ready_for_review") if isinstance(review,dict) else None,
                        "materials":sum(r.get("status")=="review-required" for r in material.get("rows",[])) if isinstance(material,dict) else None,
                        "imports":godot.get("passed") if isinstance(godot,dict) else None,
                        "import_failures":godot.get("failed") if isinstance(godot,dict) else None,
                        "ledger":ledger,"triage":triage})
    queues=[]
    qroot=root/"FactoryQueues"
    if qroot.is_dir() and not qroot.is_symlink():
        for file in sorted(qroot.glob("*.json")):
            data=load_safe(file)
            if isinstance(data,dict) and isinstance(data.get("entries"),dict):
                queues.append({"id":data.get("id"),"entries":data["entries"]})
    return batches,queues


def e(value):
    return escape("Not reported" if value is None else str(value),quote=True)


def metric(label,value):
    return "<div class='metric'><small>"+e(label)+"</small><strong>"+e(value)+"</strong></div>"


def html(batches,queues):
    parts=["<!doctype html><html lang='en'><head><meta charset='utf-8'>",
           "<meta name='viewport' content='width=device-width, initial-scale=1'>",
           "<meta http-equiv='Content-Security-Policy' content=\"default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'\">",
           "<title>Anubis Asset Factory</title><style>",
           "body{font:16px system-ui;background:#15191f;color:#e5e9ef;margin:0;padding:24px;max-width:1200px;margin:auto}h1{font-size:28px}h2{font-size:20px}small,p{color:#aab5c4}section{background:#202731;border:1px solid #394351;border-radius:12px;padding:18px;margin:16px 0}.metrics{display:flex;flex-wrap:wrap;gap:16px}.metric{min-width:125px;display:grid;gap:6px}.metric strong{font-size:24px}table{border-collapse:collapse;width:100%;margin-top:16px}td,th{padding:8px;border-bottom:1px solid #394351;text-align:left}td:last-child{overflow-wrap:anywhere}.completed{color:#86d8a5}.failed,.interrupted{color:#ff9d9d}.running{color:#f6ce85}</style></head><body>",
           "<h1>Anubis Asset Factory</h1><p>Read-only snapshot • "+e(datetime.now(timezone.utc).isoformat(timespec="seconds"))+
           "</p><p>Saved reports, not live process or asset approval evidence. Counts can lag active generation. Missing reports are not zero.</p>"]
    for batch in batches:
        parts.append("<section><h2>"+e(batch["batch"])+"</h2><div class='metrics'>")
        counts=batch["counts"]
        for label,n,d in [("Concepts","images","image_total"),("Raw meshes","meshes","mesh_total")]:
            parts.append(metric(label, f"{counts[n]} / {counts[d]}" if counts else None))
        for label,key in [("Props ready for review","review"),("Material candidates","materials"),("Passed import versions","imports"),("Failed import versions","import_failures")]:
            parts.append(metric(label,batch[key]))
        parts.append("</div>")
        triage=batch.get("triage")
        if isinstance(triage,dict):
            parts.append("<p>Raw generation timing (successful job metadata only):</p><div class='metrics'>")
            for stage,t in triage.get("timing",{}).items():
                center=t.get("median_job_seconds")
                parts.append(metric(stage+" median seconds",round(center,1) if isinstance(center,(int,float)) else None))
                parts.append(metric(stage+" pending jobs",t.get("pending_jobs")))
            parts.append("</div>")
        ledger=batch["ledger"]
        if isinstance(ledger,dict):
            parts.append("<p>Last run: "+e(ledger.get("id"))+" • "+e(ledger.get("mode"))+" • "+e(ledger.get("status"))+"</p>")
            parts.append("<table><thead><tr><th>Stage</th><th>Status</th><th>Finished</th></tr></thead><tbody>")
            for name in STAGES:
                item=ledger.get("stages",{}).get(name,{})
                status=item.get("status","not reported")
                css=status if status in ("completed","failed","interrupted","running") else ""
                parts.append("<tr><td>"+e(name)+"</td><td class='"+css+"'>"+e(status)+"</td><td>"+e(item.get("finished"))+"</td></tr>")
            parts.append("</tbody></table>")
            hardware=ledger.get("hardware_finish") or ledger.get("hardware_start") or {}
            disks=hardware.get("disks",{})
            parts.append("<p>Last run boundary: ")
            for label in ("windows_ssd","nas"):
                free=disks.get(label,{}).get("free_bytes")
                parts.append(e(label)+": "+e(f"{free/1024**3:.1f} GiB free" if isinstance(free,int) else None)+"; ")
            parts.append("</p>")
        parts.append("</section>")
    if not batches:
        parts.append("<p>No batch directories found.</p>")
    parts.append("<section><h2>Production queues</h2>")
    for queue in queues:
        parts.append("<h3>"+e(queue["id"])+"</h3><table><tbody>")
        for name,entry in queue["entries"].items():
            parts.append("<tr><td>"+e(name)+"</td><td>"+e(entry.get("status"))+"</td><td>Attempts: "+e(entry.get("attempts"))+"</td></tr>")
        parts.append("</tbody></table>")
    if not queues:
        parts.append("<p>No queue reports.</p>")
    parts.append("</section></body></html>")
    return "".join(parts)


def generate(root):
    if not root.is_dir() or root.is_symlink():
        raise ValueError("Visual library missing")
    batches,queues=collect(root)
    out=root/"FactoryDashboard.html"
    with tempfile.NamedTemporaryFile(mode="w",encoding="utf-8",dir=root,delete=False) as f:
        tmp=Path(f.name)
        f.write(html(batches,queues))
    try:
        tmp.replace(out)
    finally:
        tmp.unlink(missing_ok=True)
    print("Dashboard:",out)


if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--root",type=Path,required=True)
    a=p.parse_args()
    generate(a.root.resolve())
