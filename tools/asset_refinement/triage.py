"""Technical review triage and observed raw generation work, never aesthetic approval."""
import argparse
import hashlib
import importlib.util
import math
from pathlib import Path
from statistics import median
from factory_ledger import atomic, now
from refine import load, sha
from review_queue import scan
from budgets import estimate


def positive(value):
    return isinstance(value,(int,float)) and not isinstance(value,bool) and math.isfinite(value) and value>0


def timing(samples,pending):
    seconds=[r["seconds"] for r in samples]
    peaks=[r["peak_allocated_bytes"] for r in samples if positive(r.get("peak_allocated_bytes"))]
    center=median(seconds) if seconds else None
    return {"sample_count":len(seconds),"recorded_job_seconds":round(sum(seconds),2),
            "median_job_seconds":center,"pending_jobs":pending,
            "remaining_serial_job_seconds":round(center*pending,2) if len(seconds)>=5 else None,
            "max_observed_torch_allocated_bytes":max(peaks) if peaks else None}


def version_flags(item):
    flags=[]
    if item.get("normal_projection_exception"):
        flags.append("review-missing-projected-normals")
    if item["scale_status"]!="specified-height-only":
        flags.append("measure-physical-height")
    budget=estimate(item)
    flags.extend(budget["warnings"])
    outputs=item["outputs"]
    lods=[outputs[f"lod{i}.glb"]["triangles"] for i in range(3)]
    if not lods[0]>=lods[1]>=lods[2]>0:
        flags.append("inspect-lod-order")
    for i in range(3):
        base=outputs.get(f"lod{i}-basecolor.png",{})
        coverage=base.get("coverage_with_margin")
        if coverage is None:
            flags.append(f"lod{i}-no-baked-color-coverage")
        elif not positive(coverage) or coverage<.10:
            flags.append(f"lod{i}-low-uv-coverage")
    return flags


def report(raw,refined,size,generation):
    spec=importlib.util.spec_from_file_location("triage_batch",generation/"tools/visual_studio/batch.py")
    batch=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(batch)
    if batch.OUT.resolve()!=raw.resolve():
        raise ValueError("Generation output differs from requested raw directory")
    inventory=batch.inventory()
    reviews={r["candidate"]:r for r in scan(raw,refined,size)}
    samples={"image":[],"mesh":[]}
    pending={"image":0,"mesh":0}
    rows=[]
    for job in inventory:
        key=job["key"]
        folder=raw/"candidates"/key
        flags=[]
        records={}
        stages=["image"]+(["mesh"] if job["kind"]=="prop" else [])
        for stage in stages:
            if not job[stage+"_ready"]:
                pending[stage]+=1
                flags.append("missing-"+stage)
                continue
            meta=folder/(stage+".json")
            try:
                info=load(meta)
                if positive(info.get("seconds")):
                    samples[stage].append(info)
                records[stage]={"metadata_sha256":sha(meta),"seconds":info.get("seconds"),
                                "peak_allocated_bytes":info.get("peak_allocated_bytes")}
                if stage=="mesh":
                    records[stage]["triangles"]=info.get("triangles")
                    records[stage]["watertight"]=info.get("watertight")
                    if info.get("watertight") is False:
                        flags.append("inspect-open-raw-mesh")
            except (OSError,ValueError,KeyError,TypeError):
                flags.append("metadata-unavailable-"+stage)
        versions=[]
        if job["kind"]=="prop":
            review=reviews.get(key,{})
            for item in review.get("versions",[]):
                versions.append({"signature":item["signature"],"manifest_sha256":item["manifest_sha256"],
                                 "flags":version_flags(item)})
            if job["mesh_ready"] and not versions:
                flags.append("refinement-pending")
        # Incomplete raw jobs first; then completed candidates with technical
        # flags. Never rank artistic value or choose between alternate versions.
        priority=0 if any(f.startswith("missing-") for f in flags) else 1 if flags or any(v["flags"] for v in versions) else 2
        rows.append({"candidate":key,"kind":job["kind"],"group":job["group"],
                     "priority":priority,"flags":flags,"versions":versions,"measurements":records})
    rows.sort(key=lambda r:(r["priority"],r["group"],r["candidate"]))
    return {"schema":1,"generated":now(),"batch":batch.catalog()["batch"],"bake_size":size,
            "scope":"technical review hints, not visual scoring or approval",
            "timing_scope":"successful raw job metadata; excludes startup, model loading, failures, packaging, refinement and other stages",
            "timing":{s:timing(samples[s],pending[s]) for s in samples},"rows":rows}


if __name__=="__main__":
    p=argparse.ArgumentParser()
    for key in ("raw","refined","generation","output"):
        p.add_argument("--"+key,type=Path,required=True)
    p.add_argument("--size",type=int,default=1024)
    a=p.parse_args()
    if a.output.resolve().parent!=a.refined.resolve():
        p.error("Triage output must be inside refinement root")
    data=report(a.raw.resolve(),a.refined.resolve(),a.size,a.generation.resolve())
    atomic(a.output,data)
    print("Technical triage records:",len(data["rows"]))
