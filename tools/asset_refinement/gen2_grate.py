"""Gen 2 dimensioned hard-surface pilot. Offline, review-only, no inference."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import tempfile
import shutil

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT/"assets/models/nightgrid/central_exchange_storefront"
# Proposed envelope, metres. Y=0 is flush grade, X width, Z length.
WIDTH, LENGTH, DEPTH = .48, .72, .065
RIM = .045
BAR = .018
COUNT = 13
INNER_X, INNER_Z = WIDTH/2-RIM, LENGTH/2-RIM
PITCH = 2*INNER_Z/(COUNT+1)
CENTERS = tuple(-INNER_Z+PITCH*(i+1) for i in range(COUNT))
MAPS = ("steel_base_1k.jpg", "steel_normal_1k.jpg", "steel_arm_1k.png")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def sub(a,b):
    return tuple(x-y for x,y in zip(a,b))


def dot(a,b):
    return sum(x*y for x,y in zip(a,b))


def cross(a,b):
    return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])


def unit(a):
    mag=math.sqrt(dot(a,a))
    if mag < 1e-10:
        raise ValueError("Degenerate face")
    return tuple(v/mag for v in a)


class Surface:
    def __init__(self):
        self.p,self.n,self.t,self.uv,self.i = [],[],[],[],[]

    def face(self, points, outward):
        # Planar convex polygon; per-face orthonormal tangent basis and metre UVs.
        points=list(points)
        n=unit(cross(sub(points[1],points[0]),sub(points[2],points[0])))
        if dot(n,outward)<0:
            points.reverse()
            n=tuple(-x for x in n)
        t=unit(sub(points[1],points[0]))
        b=cross(n,t)
        first=len(self.p)//3
        for p in points:
            self.p.extend(p)
            self.n.extend(n)
            self.t.extend((*t,1.0))
            self.uv.extend((dot(p,t)/.4,dot(p,b)/.4))
        for j in range(1,len(points)-1):
            self.i.extend((first,first+j,first+j+1))

    def loop(self, a,b,center,inner=False):
        for i in range(len(a)):
            j=(i+1)%len(a)
            # Radial direction supplies the winding hint, including chamfers.
            mid=tuple((a[i][k]+a[j][k]+b[i][k]+b[j][k])/4 for k in range(3))
            hint=(mid[0]-center[0],0,mid[2]-center[1])
            self.face((a[i],a[j],b[j],b[i]),tuple(-x for x in hint) if inner else hint)


def rect(x,z,y,cx=0,cz=0):
    return [(cx-x,y,cz-z),(cx-x,y,cz+z),(cx+x,y,cz+z),(cx+x,y,cz-z)]


def annulus(s, outer, inner, up):
    for i in range(4):
        j=(i+1)%4
        s.face((outer[i],outer[j],inner[j],inner[i]),(0,up,0))


def frame(s, bevel):
    # Continuous hollow rectangular ring; both the top and underside remain open.
    x,z=WIDTH/2,LENGTH/2
    levels=[(-DEPTH,x,z,INNER_X,INNER_Z)]
    if bevel:
        levels.extend([(-bevel,x,z,INNER_X,INNER_Z),
                       (0,x-bevel,z-bevel,INNER_X+bevel,INNER_Z+bevel)])
    else:
        levels.append((0,x,z,INNER_X,INNER_Z))
    outer=[rect(a,b,y) for y,a,b,_,_ in levels]
    inner=[rect(a,b,y) for y,_,_,a,b in levels]
    for i in range(len(levels)-1):
        s.loop(outer[i],outer[i+1],(0,0))
        s.loop(inner[i],inner[i+1],(0,0),inner=True)
    annulus(s,outer[0],inner[0],-1)
    annulus(s,outer[-1],inner[-1],1)


def rib(s, cx,cz,x,z,top,bottom,bevel):
    # Closed tapered-top casting, with actual thickness below grade.
    rings=[rect(x,z,bottom,cx,cz)]
    if bevel:
        rings.append(rect(x,z,top-bevel,cx,cz))
        rings.append(rect(x-bevel,z-bevel,top,cx,cz))
    else:
        rings.append(rect(x,z,top,cx,cz))
    for a,b in zip(rings,rings[1:]):
        s.loop(a,b,(cx,cz))
    s.face(rings[0],(0,-1,0))
    s.face(rings[-1],(0,1,0))


def fastener(s,x,z,sides):
    rings=[[(x+r*math.cos(math.tau*i/sides),y,z+r*math.sin(math.tau*i/sides))
             for i in range(sides)] for y,r in ((-.005,.011),(0,.009))]
    s.loop(*rings,(x,z))
    s.face(rings[0],(0,-1,0))
    s.face(rings[-1],(0,1,0))


def geometry(lod):
    if lod not in (0,1,2):
        raise ValueError("LOD must be 0, 1 or 2")
    cast,hardware=Surface(),Surface()
    frame(cast,.003 if lod<2 else 0)
    for z in CENTERS:
        rib(cast,0,z,INNER_X+.001,BAR/2,-.001,-.045,.002 if lod<2 else 0)
    # Two recessed supports carry the ribs. They do not cover the slots.
    for x in (-.10,.10):
        rib(cast,x,0,.008,INNER_Z+.001,-.040,-.060,0)
    if lod<2:
        for x in (-WIDTH/2+RIM/2,WIDTH/2-RIM/2):
            for z in (-LENGTH/2+RIM/2,LENGTH/2-RIM/2):
                fastener(hardware,x,z,12 if lod==0 else 6)
    return [s for s in (cast,hardware) if s.i]


def texture_data(source):
    notice=json.loads((source/"SOURCE.json").read_text(encoding="utf-8"))
    maps=[]
    for name in MAPS:
        relative="textures/"+name
        data=(source/relative).read_bytes()
        expected=notice["files"][relative]
        if sha(data)!=expected["sha256"] or len(data)!=expected["bytes"]:
            raise ValueError("Texture source hash mismatch: "+name)
        maps.append((name,data))
    return maps


def encode(lod,maps):
    surfaces=geometry(lod)
    binary=bytearray()
    views,accessors,primitives,images=[],[],[],[]

    def view(data,target=None):
        binary.extend(b"\0"*(-len(binary)%4))
        item={"buffer":0,"byteOffset":len(binary),"byteLength":len(data)}
        if target:
            item["target"]=target
        views.append(item)
        binary.extend(data)
        return len(views)-1

    def accessor(values,dim,kind):
        is_index=kind=="I"
        i=view(struct.pack("<"+str(len(values))+kind,*values),34963 if is_index else 34962)
        a={"bufferView":i,"componentType":5125 if is_index else 5126,
           "count":len(values)//dim,"type":{1:"SCALAR",2:"VEC2",3:"VEC3",4:"VEC4"}[dim]}
        if dim==3:
            a.update(min=[min(values[j::3]) for j in range(3)],max=[max(values[j::3]) for j in range(3)])
        accessors.append(a)
        return len(accessors)-1

    for i,s in enumerate(surfaces):
        attrs={name:accessor(data,dim,"f") for name,data,dim in
               (("POSITION",s.p,3),("NORMAL",s.n,3),("TANGENT",s.t,4),("TEXCOORD_0",s.uv,2))}
        primitives.append({"attributes":attrs,"indices":accessor(s.i,1,"I"),"material":i})
    for name,data in maps:
        images.append({"name":name,"bufferView":view(data),
                       "mimeType":"image/png" if name.endswith(".png") else "image/jpeg"})
    materials=[]
    for name,color,rough in (("Cast drainage iron",.42,.92),("Recessed fasteners",.65,.75))[:len(surfaces)]:
        materials.append({"name":name,"pbrMetallicRoughness":{
            "baseColorFactor":[color,color,color,1],"metallicFactor":1,"roughnessFactor":rough,
            "baseColorTexture":{"index":0},"metallicRoughnessTexture":{"index":2}},
            "normalTexture":{"index":1,"scale":.55},"occlusionTexture":{"index":2}})
    binary.extend(b"\0"*(-len(binary)%4))
    doc={"asset":{"version":"2.0","generator":"NightGrid Gen2 dimensioned grate"},
         "scene":0,"scenes":[{"nodes":[0]}],"nodes":[{"mesh":0,"name":"Brickwater cast drain"}],
         "meshes":[{"primitives":primitives}],"materials":materials,"images":images,
         "textures":[{"source":i} for i in range(len(images))],
         "buffers":[{"byteLength":len(binary)}],"bufferViews":views,"accessors":accessors}
    raw=json.dumps(doc,separators=(",",":"),sort_keys=True).encode()
    raw+=b" "*(-len(raw)%4)
    return (struct.pack("<4sII",b"glTF",2,12+8+len(raw)+8+len(binary))
            +struct.pack("<I4s",len(raw),b"JSON")+raw
            +struct.pack("<I4s",len(binary),b"BIN\0")+binary)


def produce(output):
    output=output.resolve()
    if output==ROOT or ROOT in output.parents or output in ROOT.parents:
        raise ValueError("Use a separate candidate library, not the game checkout")
    if output.exists():
        raise FileExistsError(output)
    maps=texture_data(SOURCE)
    output.parent.mkdir(parents=True,exist_ok=True)
    stage=Path(tempfile.mkdtemp(prefix=".gen2-grate-",dir=output.parent))
    try:
        files={}
        for lod in range(3):
            payload=encode(lod,maps)
            name=f"lod{lod}.glb"
            (stage/name).write_bytes(payload)
            files[name]={"sha256":sha(payload),"bytes":len(payload),
                         "triangles":sum(len(s.i)//3 for s in geometry(lod))}
        manifest={"schema":1,"status":"candidate-only","asset":"brickwater.cast-drain.gen2",
                  "dimensions_m":[WIDTH,DEPTH,LENGTH],"grade_y":0,
                  "dimensions_status":"proposed; measure existing world placement",
                  "orientation":"glTF Y-up, X width, Z length","slots":COUNT+1,
                  "geometry":"original dimensioned casting; intersecting support components, not boolean-unioned",
                  "collision":"retain existing floor and steam; no mesh collision or placement generated",
                  "source_code_sha256":sha(Path(__file__).read_bytes()),
                  "material_source":"central_exchange_storefront/SOURCE.json; Poly Haven CC0 photo maps",
                  "material_review":"reuse steel photos; cast-iron appearance and UV scale require review",
                  "textures":{name:sha(data) for name,data in maps},"outputs":files,
                  "pending":["placement","native import","native visual","performance","human review"]}
        (stage/"candidate.json").write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n",encoding="utf-8")
        if output.exists():
            raise FileExistsError(output)
        stage.rename(output)
    finally:
        if stage.exists():
            shutil.rmtree(stage)
    print("Candidate only:",output)


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out",type=Path,required=True)
    produce(p.parse_args().out)
