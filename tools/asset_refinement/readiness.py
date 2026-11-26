"""Fail before expensive factory stages on incompatible catalogs or missing candidates."""
import argparse
import importlib.util
import os
from pathlib import Path
import sys


def inspect_catalog(generation, batch, raw):
    from materials import PROFILES
    module_path=generation/"tools/visual_studio/batch.py"
    if not module_path.is_file():
        raise ValueError("Generation checkout missing batch coordinator")
    spec=importlib.util.spec_from_file_location("factory_visual_batch",module_path)
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    if not hasattr(module,"catalog") or module.OUT.resolve()!=raw.resolve():
        raise ValueError("Use integrated generation checkout with current catalog and NAS support")
    catalog=module.catalog()
    if catalog["batch"]!=batch:
        raise ValueError("Factory batch and catalog identity differ")
    jobs=module.jobs()
    unknown=[j["id"] for j in jobs if j["kind"]=="material" and
             (not j["id"].startswith("material.") or j["id"].removeprefix("material.") not in PROFILES)]
    if unknown:
        raise ValueError("Missing explicit material profiles: "+", ".join(sorted(set(unknown))))
    return module,jobs


def check_coverage(rows, mode):
    complete=[r for r in rows if r["status"]=="candidate-only"]
    pending=len(rows)-len(complete)
    if not complete:
        raise ValueError("No verified complete candidates; generate or repair first")
    if mode=="full" and pending:
        raise ValueError("Full batch has incomplete candidates: "+str(pending))
    return len(complete),pending


def main():
    p=argparse.ArgumentParser()
    for name in ("generation","raw"):
        p.add_argument("--"+name,type=Path,required=True)
    p.add_argument("--batch",required=True)
    p.add_argument("--coverage",choices=["full","existing","smoke"])
    a=p.parse_args()
    if a.coverage:
        # CPU-only path: catalog/profile validation ran earlier in the mesh environment.
        spec=importlib.util.spec_from_file_location("factory_visual_batch",a.generation/"tools/visual_studio/batch.py")
        module=importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        complete,pending=check_coverage(module.inventory(),a.coverage)
        print("Verified complete candidates:",complete,"pending:",pending)
    else:
        module,jobs=inspect_catalog(a.generation,a.batch,a.raw)
        print("Catalog preflight:",len(jobs),"jobs; all material profiles recognized")


if __name__=="__main__":
    main()
