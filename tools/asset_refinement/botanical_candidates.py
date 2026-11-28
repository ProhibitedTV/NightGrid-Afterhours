"""Original, deterministic botanical geometry factory. No external inputs or GPU."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SPECIES = ("date_palm", "fan_palm", "coast_oak", "cypress", "shrub", "agave", "grass")
BUDGETS = {0: 14000, 1: 4000}


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def mul(a, k):
    return tuple(x * k for x in a)


def sub(a, b):
    return add(a, mul(b, -1))


def cross(a, b):
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])


def unit(a):
    return mul(a, 1 / max(1e-9, math.sqrt(sum(x*x for x in a))))


def lerp(a, b, t):
    return add(mul(a, 1-t), mul(b, t))


def color(c, shade):
    return tuple(max(0, min(1, x*shade)) for x in c)


class Surface:
    def __init__(self):
        self.p, self.n, self.c = [], [], []

    def tri(self, a, b, c, tint):
        n = cross(sub(b,a),sub(c,a))
        if sum(v*v for v in n) < 1e-16:
            return
        for p in (a,b,c):
            self.p.extend(p)
            self.n.extend(unit(n))
            self.c.extend(tint)

    def quad(self, a,b,c,d,tint):
        self.tri(a,b,c,tint)
        self.tri(a,c,d,tint)


def tube(s, points, radii, sides, tint, rng):
    rings = []
    for j, (p,r) in enumerate(zip(points,radii)):
        axis = unit(sub(points[min(j+1,len(points)-1)], points[max(j-1,0)]))
        u = unit(cross(axis,(0,0,1) if abs(axis[2]) < .9 else (1,0,0)))
        v = cross(axis,u)
        rings.append([add(p,add(mul(u,r*math.cos(i*math.tau/sides)),mul(v,r*math.sin(i*math.tau/sides)))) for i in range(sides)])
    for j in range(len(rings)-1):
        for i in range(sides):
            k=(i+1)%sides
            s.quad(rings[j][i],rings[j][k],rings[j+1][k],rings[j+1][i],color(tint,rng.uniform(.77,1.24)))
    for j in (0,len(rings)-1):
        for i in range(sides):
            k=(i+1)%sides
            s.tri(points[j],rings[j][k if j==0 else i],rings[j][i if j==0 else k],tint)


def leaf(s, start, end, width, tint, rng, bend=.05, segments=3):
    # Individual tapered leaf, curved midrib and folded cross-section.
    axis = sub(end,start)
    side = unit(cross(axis,(0,1,0)))
    if sum(v*v for v in side)<.01:
        side=(1,0,0)
    rows=[]
    for j in range(segments+1):
        t=j/segments
        p=add(lerp(start,end,t),(0,bend*math.sin(math.pi*t),0))
        w=width*math.sin(math.pi*t)**.7
        rows.append((add(p,mul(side,-w)),add(p,(0,w*.24,0)),add(p,mul(side,w))))
    for j in range(segments):
        a,b,c=rows[j]; d,e,f=rows[j+1]
        s.quad(a,d,e,b,color(tint,rng.uniform(.80,1.0)))
        s.quad(b,e,f,c,color(tint,rng.uniform(1.0,1.18)))


def palm(bark, foliage, rng, fan, lod):
    h=5.8 if fan else 6.7
    steps=34 if lod==0 else 12
    points=[(.20*(i/steps)**2,h*i/steps,.12*(i/steps)**2) for i in range(steps+1)]
    radii=[(.24+.08*(1-i/steps)**4)*(1.07 if i%2==0 else .93) for i in range(steps+1)]
    tube(bark,points,radii,12 if lod==0 else 8,(.24,.15,.085),rng)
    root=points[-1]
    count=(19 if lod==0 else 9) if fan else (23 if lod==0 else 12)
    for i in range(count):
        angle=i*2.399963+rng.uniform(-.12,.12)
        direction=(math.cos(angle),0,math.sin(angle))
        transverse=(-direction[2],0,direction[0])
        length=rng.uniform(1.65,2.35)
        lift=rng.uniform(.35,1.1)
        def spine(t):
            return add(root,add(mul(direction,length*t),(0,lift*math.sin(math.pi*t)-.58*t*t,0)))
        if fan:
            tip=spine(.70)
            tube(bark,[root,spine(.35),tip],[.032,.025,.009],5,(.26,.29,.08),rng)
            n=15 if lod==0 else 7
            for j in range(n):
                a=angle+(j/(n-1)-.5)*2.35
                v=(math.cos(a),0,math.sin(a))
                end=add(tip,add(mul(v,rng.uniform(.75,1.15)),(0,-.23+lift*.20,0)))
                leaf(foliage,tip,end,.075 if lod==0 else .13,(.105,.29,.075),rng,.13,3)
        else:
            tube(bark,[spine(j/6) for j in range(7)],[.038*(1-j/7) for j in range(7)],5,(.27,.30,.07),rng)
            n=19 if lod==0 else 8
            for j in range(n):
                t=.12+.84*j/max(1,n-1)
                p=spine(t)
                span=.54*math.sin(math.pi*t)**.65+.07
                for sign in (-1,1):
                    end=add(p,add(mul(transverse,sign*span),add(mul(direction,.28),(0,-.22*span,0))))
                    leaf(foliage,p,end,.035 if lod==0 else .065,(.075,.25,.045),rng,.07,3 if lod==0 else 2)


def branched(bark, foliage, rng, species, lod):
    cypress=species=="cypress"
    shrub=species=="shrub"
    h=.82 if shrub else (5.6 if cypress else 4.2)
    radius=.46 if shrub else (.80 if cypress else 1.85)
    origin=(0,0,0)
    if not shrub:
        tube(bark,[origin,(.04,h*.35,0),(.07,h*.72,.04),(.03,h,.06)],[.19,.14,.08,.018],10 if lod==0 else 6,(.18,.115,.07),rng)
    n=(15 if lod==0 else 8) if shrub else (24 if lod==0 else 12)
    for i in range(n):
        angle=i*2.399963
        t=(i+.5)/n
        y=h*(.15+.85*t) if not shrub else h*rng.uniform(.50,.96)
        spread=radius*(math.sin(math.pi*t)**.65 if cypress else rng.uniform(.64,1))
        d=(math.cos(angle),0,math.sin(angle))
        p=(0,y*.62 if not shrub else 0,0)
        q=add(mul(d,spread*.56),(0,y*.88,0))
        end=add(mul(d,spread),(0,y,0))
        tube(bark,[p,q,end],[.027 if shrub else .07,.020,.006],5,(.19,.13,.08),rng)
        for j in range(8 if lod==0 else 4):
            t2=.30+.70*j/(7 if lod==0 else 3)
            center=lerp(q,end,t2)
            for k in range(7 if lod==0 else 4):
                a=angle+k*2.399963+rng.uniform(-.4,.4)
                v=(math.cos(a),rng.uniform(-.25,.62),math.sin(a))
                length=(.17 if shrub else (.24 if cypress else .38))*rng.uniform(.8,1.4)
                leaf(foliage,center,add(center,mul(v,length)),length*.24,(.065,.22,.05),rng,length*.18,2)


def groundcover(foliage,rng,agave,lod):
    n=(30 if lod==0 else 13) if agave else (68 if lod==0 else 22)
    for i in range(n):
        angle=i*2.399963
        r=rng.uniform(.13,.47)
        h=rng.uniform(.24,.72)
        d=(math.cos(angle),0,math.sin(angle))
        start=mul(d,rng.uniform(.015,.06))
        end=add(mul(d,r),(0,h,0))
        leaf(foliage,start,end,.078 if agave else .019,
             (.12,.34,.24) if agave else (.24,.34,.09),rng,.13,4 if lod==0 else 2)


def geometry(species,lod):
    if species not in SPECIES or lod not in BUDGETS:
        raise ValueError("Unknown species or tier")
    rng=random.Random(4201337+SPECIES.index(species)*17+lod)
    bark,foliage=Surface(),Surface()
    if species in ("date_palm","fan_palm"):
        palm(bark,foliage,rng,species=="fan_palm",lod)
    elif species in ("coast_oak","cypress","shrub"):
        branched(bark,foliage,rng,species,lod)
    else:
        groundcover(foliage,rng,species=="agave",lod)
    return bark,foliage


def encode(species,lod):
    blob=bytearray()
    views,accessors,prims,materials=[],[],[],[]
    all_positions=[]
    for name,s in zip(("wood","foliage"),geometry(species,lod)):
        if not s.p:
            continue
        attrs={}
        for attr,data in (("POSITION",s.p),("NORMAL",s.n),("COLOR_0",s.c)):
            raw=struct.pack("<"+"f"*len(data),*data)
            views.append({"buffer":0,"byteOffset":len(blob),"byteLength":len(raw),"target":34962})
            blob.extend(raw)
            acc={"bufferView":len(views)-1,"componentType":5126,"count":len(data)//3,"type":"VEC3"}
            if attr=="POSITION":
                acc.update(min=[min(data[i::3]) for i in range(3)],max=[max(data[i::3]) for i in range(3)])
                all_positions.extend(data)
            attrs[attr]=len(accessors)
            accessors.append(acc)
        prims.append({"attributes":attrs,"material":len(materials)})
        materials.append({"name":name,"doubleSided":True,"pbrMetallicRoughness":{"baseColorFactor":[1,1,1,1],"metallicFactor":0,"roughnessFactor":.86 if name=="wood" else .68}})
    tris=len(all_positions)//9
    if not 0<tris<=BUDGETS[lod]:
        raise ValueError(f"{species} LOD{lod} triangle budget: {tris}")
    doc={"asset":{"version":"2.0","generator":"NightGrid original botanical studio"},
         "scene":0,"scenes":[{"nodes":[0]}],"nodes":[{"name":species,"mesh":0}],
         "meshes":[{"primitives":prims}],"materials":materials,
         "buffers":[{"byteLength":len(blob)}],"bufferViews":views,"accessors":accessors}
    raw=json.dumps(doc,separators=(",",":")).encode()
    raw+=b" "*(-len(raw)%4)
    glb=struct.pack("<4sII",b"glTF",2,28+len(raw)+len(blob))+struct.pack("<I4s",len(raw),b"JSON")+raw+struct.pack("<I4s",len(blob),b"BIN\0")+blob
    bounds=[[min(all_positions[i::3]) for i in range(3)],[max(all_positions[i::3]) for i in range(3)]]
    return glb, {"triangles":tris,"bounds_m":bounds,"sha256":hashlib.sha256(glb).hexdigest(),"bytes":len(glb)}


def produce(out):
    out=out.resolve()
    if out==ROOT or out in ROOT.parents or (ROOT in out.parents and out != ROOT/"assets/models/nightgrid/botanical"):
        raise ValueError("Choose external candidate folder or exact botanical asset path")
    records={}
    outputs={}
    for species in SPECIES:
        for lod in (0,1):
            raw,record=encode(species,lod)
            name=f"{species}_lod{lod}.glb"
            outputs[name]=raw
            records[name]=record
    manifest={"schema":1,"license":"Original NightGrid project geometry; no third-party inputs",
              "generator_sha256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),"files":records}
    if out.exists():
        if out.is_symlink() or json.loads((out/"SOURCE.json").read_text())!=manifest:
            raise ValueError("Existing botanical batch differs; preserve it and use a fresh folder")
        for name,raw in outputs.items():
            if (out/name).read_bytes()!=raw:
                raise ValueError("Existing output mismatch "+name)
        print("BOTANICAL_BANK PASS: verified",len(outputs),"existing meshes")
        return
    out.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".botanical-",dir=out.parent) as tmp:
        stage=Path(tmp)/"bank"
        stage.mkdir()
        for name,raw in outputs.items():
            (stage/name).write_bytes(raw)
        (stage/"SOURCE.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
        stage.rename(out)
    print("BOTANICAL_BANK PASS:",len(outputs),"original meshes",out)


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out",type=Path,required=True)
    p.add_argument("--execute",action="store_true")
    a=p.parse_args()
    if a.execute:
        produce(a.out)
    else:
        for species in SPECIES:
            for lod in (0,1):
                _,rec=encode(species,lod)
                print(species,lod,rec["triangles"],rec["bounds_m"])
