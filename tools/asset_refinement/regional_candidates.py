"""Emit a schematic regional atlas and architecture demand list, not runtime map data."""
import argparse
import json
from pathlib import Path
import tempfile
from xml.sax.saxutils import escape
from refine import sha
from production_evidence import checked
from factory_ledger import atomic

ROOT=Path(__file__).resolve().parents[2]
SOURCE=Path(__file__).with_name("regional_concept.json")

def validate(data):
    if data.get("state_name")!="Cascadia":raise ValueError("Canonical state name must be Cascadia")
    places=data["places"]
    ids={p["id"] for p in places}
    if len(ids)!=len(places) or len({tuple(p["position"]) for p in places})!=len(places):
        raise ValueError("Duplicate regional place")
    if {p["id"] for p in places if p["production"]=="primary"}!={"morrow-bay"}:
        raise ValueError("Only Morrow Bay is primary")
    graph={n:set() for n in ids}
    seen=set()
    for link in data["links"]:
        a,b=link["a"],link["b"]
        pair=tuple(sorted((a,b)))
        if a==b or a not in ids or b not in ids or pair in seen:
            raise ValueError("Invalid regional link")
        if not link["modes"] or set(link["modes"])-{"road","rail","ferry"}:
            raise ValueError("Invalid mode")
        seen.add(pair);graph[a].add(b);graph[b].add(a)
    reached={"morrow-bay"}
    while True:
        more=reached|set.union(*(graph[n] for n in reached))
        if more==reached:break
        reached=more
    if reached!=ids:raise ValueError("Unreachable regional settlement")
    return {"places":len(ids),"major_cities":sum(p["kind"]=="major_city" for p in places),
            "connections":len(seen)}

def svg(data):
    places={p["id"]:p for p in data["places"]}
    def point(p):return 100+p["position"][0]*65,250+p["position"][1]*65
    parts=['<svg xmlns="http://www.w3.org/2000/svg" width="720" height="760" viewBox="0 0 720 760">',
           '<rect width="720" height="760" fill="#253b3a"/>',
           '<path d="M180 90 Q240 160 230 255 T270 410 Q280 550 240 570 Q185 520 180 400 Q150 310 180 90Z" fill="#416c83"/>',
           '<text x="25" y="30" font-family="sans-serif" font-size="20" fill="#fff">Cascadia — regional concept</text>']
    for link in data["links"]:
        x,y=point(places[link["a"]]);X,Y=point(places[link["b"]])
        color="#e8c078" if "bridge" in link["type"] or link["type"]=="bay-crossing" else "#98a8a4"
        parts.append(f'<line x1="{x}" y1="{y}" x2="{X}" y2="{Y}" stroke="{color}" stroke-width="3"/>')
    for p in places.values():
        x,y=point(p);r=9 if p["kind"]=="major_city" else 5
        parts.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#e5b36d" stroke="#18252b" stroke-width="2"/>')
        parts.append(f'<text x="{x+12}" y="{y-8}" font-family="sans-serif" font-size="13" fill="#fff">{escape(p["name"])}</text>')
    parts.append('<text x="25" y="730" font-family="sans-serif" font-size="12" fill="#ddd">Schematic only · scale and shorelines provisional · not a playable map</text></svg>')
    return "\n".join(parts)

def produce(out):
    out=out.resolve()
    if out==ROOT or ROOT in out.parents or out in ROOT.parents:raise ValueError("Use private candidate directory")
    out.mkdir(parents=True,exist_ok=True)
    final=out/"regional-atlas"
    settings={"source":sha(SOURCE),"generator":sha(Path(__file__))}
    names={"region.json","region.svg","architecture-demand.json"}
    if final.exists():
        doc=json.loads((final/"candidate.json").read_text())
        if doc["settings"]!=settings or set(doc["outputs"])!=names:raise ValueError("Regional plan changed")
        for n,rec in doc["outputs"].items():checked(final,n,rec["sha256"])
        return
    data=json.loads(SOURCE.read_text());metrics=validate(data)
    stage=Path(tempfile.mkdtemp(prefix=".regional-atlas.partial-",dir=out))
    atomic(stage/"region.json",data)
    (stage/"region.svg").write_text(svg(data))
    atomic(stage/"architecture-demand.json",{"status":"planning-only","places":[
        {"id":p["id"],"priority":p["production"],"families":p["architecture"]} for p in data["places"]]})
    atomic(stage/"candidate.json",{"schema":1,"status":"candidate-only","settings":settings,"metrics":metrics,
        "outputs":{n:{"sha256":sha(stage/n),"bytes":(stage/n).stat().st_size} for n in sorted(names)}})
    stage.rename(final)
    print("Regional atlas:",metrics)

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out",type=Path,required=True)
    produce(p.parse_args().out)
