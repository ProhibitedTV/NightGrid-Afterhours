"""Original district-specific architecture from authored parcel footprints."""
import argparse
import json
from pathlib import Path
import tempfile
import math

import building_candidates as base
from gen2_grate import Surface
from urban_layout_candidates import PARCELS, validate
from production_evidence import checked
from refine import sha
from factory_ledger import atomic

ROOT=Path(__file__).resolve().parents[2]
# height, floors, style, entrance width, wall color (sRGB)
SPECS={
    "older_shop":(10.2,3,"brick_shop",2.0,"885e51"),
    "workshop":(7.4,1,"industrial",4.5,"686d70"),
    "service_annex":(4.2,1,"industrial",1.8,"77716b"),
    "podium":(8.4,2,"corporate",4.0,"7b8895"),
    "market_hall":(8.2,1,"market",4.0,"8d7965"),
    "dock_office":(10.4,3,"brick_shop",1.8,"827b71"),
    "west_wing":(14.4,4,"residential",2.0,"a3a199"),
    "rear_wing":(19.0,5,"residential",2.0,"b1a394"),
    "east_wing":(10.8,3,"residential",2.0,"a09e92"),
}
STYLES={
    "brick_shop":("masonry",.28,3.0,.32,.85),
    "industrial":("steel",.25,5.0,.7,1.5),
    "corporate":("concrete",.28,2.6,.16,.35),
    "market":("masonry",.30,4.5,.45,.65),
    "residential":("masonry",.28,3.4,.65,.9),
}


def bank():
    return {m:Surface() for m in base.MATERIALS}


def add_shell(s,bounds,y0,height,floors,style,door,lod):
    """Open-front shell with structural aperture and separate recessed glazing.
    All volumes stay inside planned footprint. No collision or finished rooms.
    """
    x,z,X,Z=bounds
    wall,t,bay,jamb,sill=STYLES[style]
    top=y0+height
    parapet=.28
    roof=top-parapet
    pitch=(height-parapet)/floors
    def add(mat,a,b,c,d,e,f):
        if b-a>1e-6 and d-c>1e-6 and f-e>1e-6:
            base.box(s[mat],a,b,c,d,e,f)
    add("concrete",x,X,y0-.15,y0,z,Z)
    add("concrete",x,X,roof-.18,roof,z,Z)
    for floor in range(1,floors):
        y=y0+floor*pitch
        add("concrete",x+t,X-t,y-.15,y,z+t,Z-t)
    # Roof parapets do not cover the terrace or entire roof.
    for lo,hi in ((x,x+t),(X-t,X)):
        add(wall,lo,hi,roof,top,z,Z)
    for lo,hi in ((z,z+t),(Z-t,Z)):
        add(wall,x+t,X-t,roof,top,lo,hi)
    # Facade coordinates u along face, v across wall depth.
    faces=(("front",x,X,z,z+t),("rear",x,X,Z-t,Z),
           ("left",z+t,Z-t,x,x+t),("right",z+t,Z-t,X-t,X))
    for face,u,U,v,V in faces:
        def panel(mat,a,b,y,Y,thin=False):
            vv,VV=(v+t*.55,v+t*.73) if thin else (v,V)
            if face in ("front","rear"):add(mat,a,b,y,Y,vv,VV)
            else:add(mat,vv,VV,y,Y,a,b)
        middle=(u+U)/2
        has_door=face=="front" and door>0
        for floor in range(floors):
            y=y0+floor*pitch
            Y=y+pitch
            if floor==0 and has_door:
                left,right=middle-door/2,middle+door/2
                head=y+min(3.0,pitch-.35)
                # Preserve a central real entry/loading aperture.
                panel(wall,u,left,y,Y)
                panel(wall,right,U,y,Y)
                panel(wall,left,right,head,Y)
                if lod==0:
                    for a in (left,right-.09):
                        panel("steel",a,a+.09,y,head)
                continue
            if lod==2 or (style=="industrial" and face in ("left","right")):
                panel(wall,u,U,y,Y)
                continue
            n=max(1,round((U-u)/bay))
            lo=y+min(sill,pitch*.33)
            hi=Y-min(.4,pitch*.18)
            panel(wall,u,U,y,lo)
            panel(wall,u,U,hi,Y)
            for j in range(n):
                a=u+(U-u)*j/n
                b=u+(U-u)*(j+1)/n
                gap=min(jamb,(b-a)*.22)
                panel(wall,a,a+gap,lo,hi)
                panel(wall,b-gap,b,lo,hi)
                panel("glazing",a+gap,b-gap,lo,hi,True)
                if lod==0:
                    m=(a+b)/2
                    if style in ("corporate","market","brick_shop"):
                        panel("steel",m-.045,m+.045,lo,hi,True)
                    if style=="residential":
                        panel("concrete",a+gap,b-gap,lo-.14,lo)
    if lod==0:
        # Architectural age and function expressed by different roof plant.
        if style in ("industrial","market"):
            for f in (.28,.67):
                a=x+(X-x)*f
                add("steel",a,a+.7,roof,top+.45,z+(Z-z)*.35,z+(Z-z)*.65)
        elif style=="brick_shop":
            add(wall,x+(X-x)*.18,x+(X-x)*.23,roof,top+.45,z+(Z-z)*.7,z+(Z-z)*.75)
        elif style=="residential":
            add("concrete",x+(X-x)*.35,x+(X-x)*.65,roof,top+.65,z+(Z-z)*.65,z+(Z-z)*.85)
    return {"x":(x+X)/2,"z":z,"width":door,"head_height":min(3.0,pitch-.35)} if door else None


def geometry(name,bounds,lod):
    height,floors,style,door,color=SPECS[name]
    s=bank()
    entry=add_shell(s,bounds,0,height,floors,style,door,lod)
    if name=="podium":
        x,z,X,Z=bounds
        # Set back a much taller corporate tower from its podium frontage.
        add_shell(s,[x+6,z+3,X-5,Z-3],height,36,10,"corporate",0,lod)
    return s,entry


def count(s):
    return sum(len(v.i)//3 for v in s.values())


def rgb(hexcolor):
    vals=[int(hexcolor[i:i+2],16)/255 for i in (0,2,4)]
    return [c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in vals]


def append(target,source):
    for name,src in source.items():
        dst=target[name]
        offset=len(dst.p)//3
        for attr in ("p","n","t","uv"):
            getattr(dst,attr).extend(getattr(src,attr))
        dst.i.extend(i+offset for i in src.i)


def produce(out):
    out=out.resolve()
    if out==ROOT or ROOT in out.parents or out in ROOT.parents:
        raise ValueError("Use private candidate directory")
    out.mkdir(parents=True,exist_ok=True)
    maps=base.textures()
    settings={"generator":sha(Path(__file__)),"parcel_source":sha(Path(__file__).with_name("urban_layout_candidates.py")),
              "mesh_encoder":sha(Path(base.__file__)),"geometry_helper":sha(Path(__file__).with_name("gen2_grate.py")),
              "textures":{n:base.digest(v) for n,v in maps.items()}}
    for parcel,plan in PARCELS.items():
        validate(plan,False)
        final=out/parcel
        expected={f"{n}-lod{lod}.glb" for n in plan["structures"] for lod in (0,1,2)}|{"parcel-lod2.glb","placement.json"}
        if final.exists():
            doc=json.loads((final/"candidate.json").read_text())
            if doc["settings"]!=settings or set(doc["outputs"])!=expected:
                raise ValueError("Existing district architecture differs")
            for n,rec in doc["outputs"].items():checked(final,n,rec["sha256"])
            print("SKIP verified",parcel,flush=True)
            continue
        stage=Path(tempfile.mkdtemp(prefix="."+parcel+".partial-",dir=out))
        combined=bank();metrics={};entries={}
        for name,bounds in plan["structures"].items():
            tri=[]
            for lod in (0,1,2):
                mesh,entry=geometry(name,bounds,lod)
                count_tri=count(mesh)
                tri.append(count_tri)
                # Near PBR reused from verified existing source maps. Medium
                # and far use untextured color; actual switching is review only.
                raw=base.encode(mesh,maps if lod==0 else {},None if lod==0 else rgb(SPECS[name][4]))
                path=stage/f"{name}-lod{lod}.glb"
                path.write_bytes(raw)
                if lod==2:
                    append(combined,mesh)
                    if len(raw)>256*1024:raise ValueError("Far shell budget")
                entries[name]={"footprint":bounds,"front_entry":entry,"style":SPECS[name][2]}
            if not tri[0]>tri[1]>tri[2]:
                raise ValueError("LOD triangle reduction missing: "+name)
            metrics[name]=tri
        raw=base.encode(combined,{},rgb("798087"))
        if len(raw)>512*1024:raise ValueError("Parcel proxy budget")
        (stage/"parcel-lod2.glb").write_bytes(raw)
        atomic(stage/"placement.json",{"coordinate_space":"parcel-local metres, X east Y up Z south",
            "structures":entries,"open_space":plan["open_space"],"bounds":plan["bounds"],
            "note":"Separate from current live world; entry frame clear width needs validation"})
        atomic(stage/"candidate.json",{"schema":1,"status":"candidate-only","settings":settings,
            "outputs":{p.name:{"sha256":sha(p),"bytes":p.stat().st_size} for p in stage.iterdir()},
            "triangles_lod0_1_2":metrics,"parcel_proxy_triangles":count(combined),
            "scope":"dimensioned architectural shells and parcel proxy; no finished interior or live placement",
            "pending":["visual quality and facade material variation","finished interior and matching apertures",
                       "survey, collision and native UV2/import","LOD transition, shared textures and occlusion",
                       "actual gameplay frame-time acceptance"]})
        stage.rename(final)
        print("District architecture candidates",parcel,metrics,flush=True)


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out",type=Path,required=True)
    produce(p.parse_args().out)
