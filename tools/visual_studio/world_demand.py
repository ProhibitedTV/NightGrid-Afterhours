"""Validate a world-demand sidecar and map it to existing candidate variants.

No asset generation, approval, scene edits or claim of missing runtime assets.
"""
import argparse
import json
from pathlib import Path
from collections import defaultdict

ROOT=Path(__file__).resolve().parents[2]


def build(root, data):
    if data["schema"]!=1 or data["status"]!="planned-demand-not-placement":
        raise ValueError("Wrong demand schema")
    base=root/"tools/visual_studio"
    catalogs=[base/"catalog.json",*sorted((base/"catalogs").glob("visual-*.json"))]
    assets={}
    for p in catalogs:
        doc=json.loads(p.read_text())
        for a in doc["assets"]:
            if a["id"] in assets:
                raise ValueError("Duplicate catalog ID: "+a["id"])
            assets[a["id"]]=(doc["batch"],doc["variants"],a["kind"])
    reuse={r["id"]:r for r in json.loads((root/"tools/urban_asset_catalog.json").read_text())["reuse"]}
    seen=set()
    output=[]
    by_batch=defaultdict(dict)
    for row in data["demands"]:
        key=row["key"]
        if key in seen or type(row["priority"]) is not int or not 1<=row["priority"]<=3:
            raise ValueError("Duplicate demand or invalid priority: "+key)
        seen.add(key)
        source=root/row["source"]
        if not source.is_file() or root not in source.resolve().parents:
            raise ValueError("Demand source not in repository")
        if not row["assets"] or not row["constraints"] or not row["why"].strip():
            raise ValueError("Incomplete demand: "+key)
        candidates=[]
        for ident in row["assets"]:
            if ident not in assets:
                raise ValueError("Unknown candidate: "+ident)
            batch,variants,kind=assets[ident]
            for i in range(1,variants+1):
                candidate=f"{ident}.v{i}"
                candidates.append({"batch":batch,"key":candidate,"kind":kind})
                priorities=by_batch[batch]
                priorities[candidate]=min(priorities.get(candidate,3),row["priority"])
        reuse_rows=[]
        for ident in row["reuse"]:
            if ident not in reuse:
                raise ValueError("Unknown reuse reference: "+ident)
            item=reuse[ident]
            p=root/item["path"]
            if root not in p.resolve().parents:
                raise ValueError("Invalid reuse path")
            reuse_rows.append({"id":ident,"path":item["path"],"present":p.exists(),
                               "note":item["use"]})
        output.append(dict(row,candidates=candidates,reuse_checks=reuse_rows))
    return {"schema":1,"scope":"planned demand; compare existing assets and native gameplay before replacement",
            "demands":sorted(output,key=lambda r:(r["priority"],r["key"])),
            "batch_priorities":{b:[{"key":k,"priority":v} for k,v in sorted(rows.items(),key=lambda p:(p[1],p[0]))]
                                for b,rows in sorted(by_batch.items())}}


if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--manifest",type=Path,default=ROOT/"tools/visual_studio/world_demand.json")
    a=p.parse_args()
    print(json.dumps(build(ROOT,json.loads(a.manifest.read_text())),indent=2))
