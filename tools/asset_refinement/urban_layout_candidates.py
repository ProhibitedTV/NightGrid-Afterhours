"""Dimensioned authored planning candidates; never changes live city or saves."""
import argparse
import json
from pathlib import Path
import tempfile
from xml.sax.saxutils import escape
from refine import sha
from production_evidence import checked
from factory_ledger import atomic

ROOT=Path(__file__).resolve().parents[2]
# Rectangle coordinates: west, street-side, east, rear in metres.
# Block envelope is local [-20,20] (nominal planning area, not a surveyed lot).
PARCELS={
 "brickwater_service_court":{"bounds":[-20,-20,20,20],"structures":{
    "older_shop":[-18,-14,-4,6],"workshop":[0,-9,18,13],
    "service_annex":[-18,10,-8,18]},
    "open_space":{"street_forecourt":[-4,-19,18,-10],"service_passage":[-4,-9,0,18]}},
 "glassline_recessed_podium":{"bounds":[-20,-20,20,20],"structures":{
    "podium":[-18,-8,17,12]},
    "open_space":{"public_plaza":[-18,-19,17,-8],"service_yard":[-18,12,17,18]}},
 "north_quay_market_yard":{"bounds":[-20,-20,20,20],"structures":{
    "market_hall":[-18,-14,0,12],"dock_office":[7,-3,18,13]},
    "open_space":{"market_court":[0,-14,18,-3],"service_lane":[0,-3,7,18]}},
 "horizon_courtyard":{"bounds":[-20,-20,20,20],"structures":{
    "west_wing":[-18,-13,-8,17],"rear_wing":[-8,7,18,17],
    "east_wing":[8,-8,18,7]},
    "open_space":{"courtyard":[-8,-8,8,7],"entry_walk":[-8,-19,8,-8]}}
}
# Gross room allocations (not finished clear widths). Openings recorded as
# explicit point on shared wall plus width; all plans have real circulation.
INTERIORS={
 "mixed_use_shop":{"bounds":[0,0,16,24],"rooms":{
    "shop":[0,0,12,11],"entry_spine":[12,0,16,24],
    "stock":[0,11,12,17],"staff":[0,17,7,24],"utility":[7,17,12,24]},
    "entry":"entry_spine","doors":[["entry_spine","shop",12,3,1.8],
       ["entry_spine","stock",12,14,1.5],["entry_spine","utility",12,20,1.2],
       ["stock","staff",3,17,1.2]]},
 "coastal_cafe":{"bounds":[0,0,16,22],"rooms":{
    "dining":[0,0,12,10],"public_spine":[12,0,16,22],
    "servery":[0,10,12,14],"kitchen":[0,14,8,22],
    "storage":[8,14,12,18],"restroom":[8,18,12,22]},
    "entry":"public_spine","doors":[["public_spine","dining",12,3,1.8],
       ["public_spine","servery",12,12,1.5],["servery","kitchen",4,14,1.5],
       ["kitchen","storage",8,16,1.2],["public_spine","restroom",12,20,1.2]]},
 "office_floor":{"bounds":[0,0,28,24],"rooms":{
    "workplace_w":[0,0,11,12],"workplace_e":[17,0,28,12],
    "main_spine":[11,0,17,24],"meeting":[0,12,11,18],
    "breakroom":[0,18,11,24],"lift_lobby":[17,12,22,18],
    "stairs":[22,12,28,18],"services":[17,18,22,24],"toilets":[22,18,28,24]},
    "entry":"main_spine","doors":[["main_spine","workplace_w",11,4,1.8],
       ["main_spine","workplace_e",17,4,1.8],["main_spine","meeting",11,15,1.2],
       ["main_spine","breakroom",11,21,1.5],["main_spine","lift_lobby",17,15,2],
       ["lift_lobby","stairs",22,15,1.2],["main_spine","services",17,21,1.2],
       ["services","toilets",22,21,1.2]]}
}


def overlap(a,b):
    return a[0]<b[2] and b[0]<a[2] and a[1]<b[3] and b[1]<a[3]


def validate(plan,interior):
    bounds=plan["bounds"]
    rooms=plan["rooms"] if interior else {**plan["structures"],**plan["open_space"]}
    for name,a in rooms.items():
        if not bounds[0]<=a[0]<a[2]<=bounds[2] or not bounds[1]<=a[1]<a[3]<=bounds[3]:
            raise ValueError("Outside envelope: "+name)
        for other,b in rooms.items():
            if name!=other and overlap(a,b):
                raise ValueError("Overlap: "+name+"/"+other)
    if not interior:
        return
    total=sum((a[2]-a[0])*(a[3]-a[1]) for a in rooms.values())
    if total!=(bounds[2]-bounds[0])*(bounds[3]-bounds[1]):
        raise ValueError("Unallocated interior floor area")
    graph={name:set() for name in rooms}
    for left,right,x,z,width in plan["doors"]:
        a,b=rooms[left],rooms[right]
        vertical=(x==a[0]==b[2] or x==a[2]==b[0]) and max(a[1],b[1])+.2<=z-width/2 and z+width/2<=min(a[3],b[3])-.2
        horizontal=(z==a[1]==b[3] or z==a[3]==b[1]) and max(a[0],b[0])+.2<=x-width/2 and x+width/2<=min(a[2],b[2])-.2
        if width<1.2 or not (vertical or horizontal):
            raise ValueError("Door outside shared wall: "+left+"/"+right)
        graph[left].add(right);graph[right].add(left)
    reached={plan["entry"]}
    while True:
        more=reached|set.union(*(graph[n] for n in reached))
        if more==reached:break
        reached=more
    if reached!=set(rooms) or rooms[plan["entry"]][1]!=bounds[1]:
        raise ValueError("Disconnected floor or entry not at frontage")


def svg(name,plan,interior):
    lo,top,hi,bottom=plan["bounds"]
    w,h=(hi-lo)*16,(bottom-top)*16
    parts=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{w+64}" height="{h+88}" viewBox="0 0 {w+64} {h+88}">',
           '<rect width="100%" height="100%" fill="#18212a"/>',
           f'<text x="32" y="22" fill="#fff" font-family="sans-serif" font-size="15">{escape(name.replace("_"," ").title())} — candidate</text>',
           f'<rect x="32" y="40" width="{w}" height="{h}" fill="#2b3944" stroke="#b6c1ca"/>']
    def point(x,z):return 32+(x-lo)*16,40+(z-top)*16
    groups=[(plan["rooms"],"#536e85")] if interior else [(plan["structures"],"#536e85"),(plan["open_space"],"#426653")]
    for group,color in groups:
        for label,(x,z,x1,z1) in group.items():
            px,py=point(x,z);rw,rh=(x1-x)*16,(z1-z)*16
            parts.append(f'<rect x="{px}" y="{py}" width="{rw}" height="{rh}" fill="{color}" stroke="#d7dce0"/>')
            parts.append(f'<text x="{px+rw/2}" y="{py+rh/2}" fill="#fff" text-anchor="middle" font-family="sans-serif" font-size="10">{escape(label.replace("_"," "))}</text>')
    if interior:
        for left,right,x,z,width in plan["doors"]:
            px,py=point(x,z);a,b=plan["rooms"][left],plan["rooms"][right]
            dx,dz=(0,width*8) if x==a[0]==b[2] or x==a[2]==b[0] else (width*8,0)
            parts.append(f'<line x1="{px-dx}" y1="{py-dz}" x2="{px+dx}" y2="{py+dz}" stroke="#f6cc81" stroke-width="4"/>')
    parts.append(f'<text x="32" y="{h+65}" font-family="sans-serif" fill="#d7dce0" font-size="11">Street / frontage at top · 16 px/m · gross allocations</text></svg>')
    return "\n".join(parts)


def produce(out):
    out=out.resolve()
    if out==ROOT or ROOT in out.parents or out in ROOT.parents:
        raise ValueError("Use private candidate directory")
    out.mkdir(parents=True,exist_ok=True)
    settings={"generator_sha256":sha(Path(__file__))}
    final=out/"urban-layouts"
    if final.exists():
        doc=json.loads((final/"candidate.json").read_text())
        if doc["settings"]!=settings:raise ValueError("Layout source changed")
        for n,rec in doc["outputs"].items():checked(final,n,rec["sha256"])
        return
    stage=Path(tempfile.mkdtemp(prefix=".urban-layouts.partial-",dir=out))
    for interior,plans in ((False,PARCELS),(True,INTERIORS)):
        for name,plan in plans.items():
            validate(plan,interior)
            (stage/(name+".json")).write_text(json.dumps(plan,indent=2)+"\n")
            (stage/(name+".svg")).write_text(svg(name,plan,interior))
    atomic(stage/"candidate.json",{"schema":1,"status":"candidate-only","settings":settings,
          "outputs":{p.name:{"sha256":sha(p),"bytes":p.stat().st_size} for p in stage.iterdir()},
          "scope":"unassigned original planning archetypes, not real code compliance or geometry",
          "pending":["survey exact live lot and mission anchors","door and wall assembly clearances",
                     "vertical circulation and services","collision/navigation/traffic tests",
                     "save migration and native visual review"]})
    stage.rename(final)
    print("Urban layout candidates:",len(PARCELS),len(INTERIORS),flush=True)


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out",type=Path,required=True)
    produce(p.parse_args().out)
