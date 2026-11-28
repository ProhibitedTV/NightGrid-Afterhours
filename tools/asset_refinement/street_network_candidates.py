"""Original Morrow Bay street-network redevelopment study, not runtime geometry."""
import argparse
import json
import math
from pathlib import Path
import tempfile
from refine import sha
from production_evidence import checked
from factory_ledger import atomic

ROOT=Path(__file__).resolve().parents[2]
# Concept only. Logical intersection IDs do NOT replace 58 m streaming cells.
# Coordinates in metres, X east and Z south. Older shore blocks are narrow;
# larger industrial and corporate parcels absorb selected local streets.
XS=(-232,-181,-126,-70,-5,55,118,180,232)
ZS=(-232,-186,-126,-68,-8,55,113,175,232)
REMOVED={
    ("1,1","2,1"),("1,2","1,3"),("2,5","2,6"),
    ("1,6","2,6"),("3,6","4,6"),("4,6","5,6"),
    ("5,2","6,2"),("6,2","6,3"),("6,4","7,4"),
    ("7,5","7,6"),("6,7","7,7"),("3,7","3,8"),
}
# One inherited diagonal trade route across mismatched subdivisions.
DIAGONAL=((0,7),(1,6),(2,5),(3,4),(4,3),(5,2),(6,1),(7,0))
# Coastal edge keeps a continuous quay route; east side road follows the ridge.
# Node displacement is explicit, never randomized.
ADJUST={
 (0,1):(9,-3),(0,2):(12,2),(0,3):(6,5),(0,4):(0,3),
 (0,5):(5,-6),(1,0):(0,7),(2,0):(0,10),(3,0):(0,4),
 (5,5):(4,-6),(6,5):(9,4),(7,5):(11,-5),
 (6,6):(-5,10),(7,6):(5,12),(8,6):(-8,7),
 (6,7):(2,-9),(7,7):(-9,5),(8,7):(-12,-5),
}
WIDTHS={"local":10.0,"collector":14.0,"arterial":18.0,"quay":14.0}
ERA={"local":"later subdivision","collector":"streetcar expansion",
     "arterial":"inherited trade corridor","quay":"harbor reclamation"}


def build():
    nodes={}
    for j,z in enumerate(ZS):
        for i,x in enumerate(XS):
            dx,dz=ADJUST.get((i,j),(0,0))
            nodes[f"{i},{j}"]=[x+dx,z+dz]
    edges=[]
    def add(a,b,kind):
        a,b=sorted((a,b))
        edges.append({"id":a+"|"+b,"a":a,"b":b,"class":kind,
                      "paved_width_m":WIDTHS[kind],"era":ERA[kind]})
    for j in range(9):
        for i in range(9):
            a=f"{i},{j}"
            for ii,jj in ((i+1,j),(i,j+1)):
                if ii>8 or jj>8:continue
                b=f"{ii},{jj}"
                if tuple(sorted((a,b))) in REMOVED:continue
                kind="quay" if (i==ii==0 or j==jj==0) else (
                     "collector" if (i==ii and i in (3,5)) or (j==jj and j in (3,5)) else "local")
                add(a,b,kind)
    for (i,j),(ii,jj) in zip(DIAGONAL,DIAGONAL[1:]):
        add(f"{i},{j}",f"{ii},{jj}","arterial")
    return {"schema":1,"status":"candidate-only","coordinate_space":"concept world metres, X east Z south",
            "nodes":nodes,"edges":edges,
            "history":[
             {"era":"old port","intent":"short blocks on north/west shore; market and dock access"},
             {"era":"trade corridor","intent":"diagonal from southwest to northeast connecting inland commerce to harbor"},
             {"era":"industrial expansion","intent":"combine selected blocks for workshops and freight yards"},
             {"era":"streetcar expansion","intent":"continuous collectors across neighborhoods"},
             {"era":"corporate redevelopment","intent":"larger podium parcels and plazas; retain old arterial"},
             {"era":"hillside housing","intent":"deflected east-side residential routes; real slope survey pending"}],
            "pending":["survey every actual mission, business, property, rail and spawn anchor",
                       "design lane curves, turning radii, signals, crossings and intersections",
                       "terrain grades and shoreline survey",
                       "street graph migration for traffic, police, routing, minimap, audio and road geometry",
                       "versioned saves and native performance acceptance"]}


def cross(a,b,c):
    return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])


def on_segment(a,b,c):
    return cross(a,b,c)==0 and min(a[0],b[0])<=c[0]<=max(a[0],b[0]) and min(a[1],b[1])<=c[1]<=max(a[1],b[1])


def intersect(a,b,c,d):
    p,q,r,s=cross(a,b,c),cross(a,b,d),cross(c,d,a),cross(c,d,b)
    return (p*q<0 and r*s<0) or any((on_segment(a,b,c),on_segment(a,b,d),on_segment(c,d,a),on_segment(c,d,b)))


def validate(plan):
    nodes,edges=plan["nodes"],plan["edges"]
    if len({tuple(p) for p in nodes.values()})!=len(nodes):raise ValueError("Duplicate nodes")
    graph={n:set() for n in nodes}
    seen=set()
    for e in edges:
        a,b=e["a"],e["b"]
        pair=tuple(sorted((a,b)))
        if a==b or pair in seen or math.dist(nodes[a],nodes[b])<25:
            raise ValueError("Invalid street")
        seen.add(pair);graph[a].add(b);graph[b].add(a)
    for i,e in enumerate(edges):
        for f in edges[:i]:
            shared={e["a"],e["b"]}&{f["a"],f["b"]}
            if shared:
                # Incident segments may meet only at the common endpoint.
                n=next(iter(shared))
                a=next(k for k in (e["a"],e["b"]) if k!=n)
                b=next(k for k in (f["a"],f["b"]) if k!=n)
                if on_segment(nodes[n],nodes[a],nodes[b]) or on_segment(nodes[n],nodes[b],nodes[a]):
                    raise ValueError("Overlapping incident streets")
            elif intersect(nodes[e["a"]],nodes[e["b"]],nodes[f["a"]],nodes[f["b"]]):
                raise ValueError("Unregistered intersection")
    reached={next(iter(nodes))}
    while True:
        nxt=reached|set.union(*(graph[n] for n in reached))
        if nxt==reached:break
        reached=nxt
    if reached!=set(nodes):raise ValueError("Disconnected road network")
    return {"intersections":len(nodes),"segments":len(edges),
            "three_way_nodes":sum(len(v)==3 for v in graph.values()),
            "diagonal_segments":sum(e["class"]=="arterial" for e in edges),
            "road_length_m":round(sum(math.dist(nodes[e["a"]],nodes[e["b"]]) for e in edges),1)}


def svg(plan):
    nodes=plan["nodes"]
    def xy(p):return (p[0]+252,p[1]+252)
    colors={"local":"#9da9ae","collector":"#d1d3c8","arterial":"#e3b061","quay":"#79b7c5"}
    parts=['<svg xmlns="http://www.w3.org/2000/svg" width="760" height="580" viewBox="0 0 760 580">',
           '<rect width="760" height="580" fill="#17222b"/>',
           '<rect x="20" y="20" width="464" height="464" fill="#2d3b3d" stroke="#586b73"/>',
           '<text x="20" y="510" fill="#e2e6e9" font-family="sans-serif" font-size="14">Morrow Bay — conceptual street redevelopment, 1 px/m</text>',
           '<text x="20" y="532" fill="#a9b6bd" font-family="sans-serif" font-size="12">Not surveyed, not live collision or lane geometry. North is up.</text>']
    for e in sorted(plan["edges"],key=lambda e:WIDTHS[e["class"]]):
        x,y=xy(nodes[e["a"]]);xx,yy=xy(nodes[e["b"]])
        parts.append(f'<line x1="{x}" y1="{y}" x2="{xx}" y2="{yy}" stroke="{colors[e["class"]]}" stroke-width="{e["paved_width_m"]*.6}" stroke-linecap="round"/>')
    for i,(k,c) in enumerate(colors.items()):
        y=65+i*28
        parts.append(f'<line x1="510" y1="{y}" x2="545" y2="{y}" stroke="{c}" stroke-width="5"/><text x="556" y="{y+4}" font-family="sans-serif" font-size="13" fill="#eee">{k}</text>')
    parts.append('</svg>')
    return "\n".join(parts)


def produce(out):
    out=out.resolve()
    if out==ROOT or ROOT in out.parents or out in ROOT.parents:raise ValueError("Use private candidate directory")
    out.mkdir(parents=True,exist_ok=True)
    final=out/"street-network"
    settings={"generator_sha256":sha(Path(__file__))}
    if final.exists():
        doc=json.loads((final/"candidate.json").read_text())
        if doc["settings"]!=settings or set(doc["outputs"])!={"network.json","network.svg"}:
            raise ValueError("Existing network candidate differs")
        for n,rec in doc["outputs"].items():checked(final,n,rec["sha256"])
        return
    plan=build()
    plan["metrics"]=validate(plan)
    stage=Path(tempfile.mkdtemp(prefix=".street-network.partial-",dir=out))
    (stage/"network.json").write_text(json.dumps(plan,indent=2)+"\n")
    (stage/"network.svg").write_text(svg(plan))
    atomic(stage/"candidate.json",{"schema":1,"status":"candidate-only","settings":settings,
          "outputs":{n:{"sha256":sha(stage/n),"bytes":(stage/n).stat().st_size} for n in ("network.json","network.svg")},
          "metrics":plan["metrics"],"scope":"conceptual centerline graph only"})
    stage.rename(final)
    print("Street network study:",plan["metrics"],flush=True)


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out",type=Path,required=True)
    produce(p.parse_args().out)
