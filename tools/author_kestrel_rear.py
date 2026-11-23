#!/usr/bin/env python3
"""Author the S6 rear quarters, hatch, cargo enclosure and optical assemblies."""

from hashlib import sha256
from itertools import pairwise
import json
from math import ceil, cos, hypot, pi, sin, sqrt
from pathlib import Path

from author_kestrel_fascia import PAINT, Surface, cross, sub, unit, subdivide, write_model

OUT = Path(__file__).resolve().parents[1] / "assets/models/nightgrid/kestrel_s6_rear"
GLASS = {"name": "Tinted Rear Laminate", "alphaMode": "BLEND", "doubleSided": True,
         "pbrMetallicRoughness": {"baseColorFactor": [.023, .042, .052, .49], "roughnessFactor": .12,
                                  "metallicFactor": 0.0}}
MATERIALS = [
    PAINT,
    {"name": "Graphite Inner Structure", "pbrMetallicRoughness": {
        "baseColorFactor": [.022,.029,.035,1], "roughnessFactor": .57, "metallicFactor": .03}},
    {"name": "Smoked Lens Edge", "pbrMetallicRoughness": {
        "baseColorFactor": [.037,.013,.019,1], "roughnessFactor": .26, "metallicFactor": .13}},
    {"name": "Tail Light Guide", "pbrMetallicRoughness": {
        "baseColorFactor": [.27,.012,.027,1], "roughnessFactor": .21, "metallicFactor": .0},
        "emissiveFactor": [.31,.009,.027]},
    {"name": "Reverse Light Guide", "pbrMetallicRoughness": {
        "baseColorFactor": [.15,.17,.18,1], "roughnessFactor": .24, "metallicFactor": .0}},
    GLASS,
    {"name": "Charcoal Rear Upholstery", "pbrMetallicRoughness": {
        "baseColorFactor": [.048,.042,.044,1], "roughnessFactor": .82, "metallicFactor": 0}},
]
# Body-local metres. First station duplicates the existing monocoque exactly.
# Upper shoulder, lower flank and deck heights are independent design curves.
STATIONS = [
    (.77, 1.00, .480, .250, .000),
    (.99, 1.01, .489, .245, .009),
    (1.27, 1.035, .516, .270, .020),
    (1.58, 1.048, .539, .291, .034),
    (1.83, 1.040, .543, .266, .038),
    (2.03, 1.011, .528, .230, .033),
    (2.17, .979, .505, .192, .019),
    (2.28, .942, .468, .149, .008),
    (2.342, .892, .413, .112, .005),
]
SOCKETS = {
    "QuarterJoin_L": (-1.15,.25,.77), "QuarterJoin_R": (1.15,.25,.77),
    "RearAxle_L": (-1.10,-.43,1.49), "RearAxle_R": (1.10,-.43,1.49),
    "HatchLatch": (0,.352,2.29), "TowCover": (.57,-.145,2.321),
}


def mix(a, b, t):
    return a+(b-a)*t


def profile(z):
    for left, right in pairwise(STATIONS):
        if z <= right[0]:
            t = (z-left[0])/(right[0]-left[0])
            # Linear station interpolants share averaged mesh normals.
            return tuple(mix(a,b,t) for a,b in zip(left[1:],right[1:]))
    return STATIONS[-1][1:]


def tail_depth(x, y):
    return 2.326 - .063*x*x - .019*(y-.17)**2


def section(z):
    width, deck, waist, crown = profile(z)
    # Rear wheel swept circle plus a 34 mm liner clearance. Only the two
    # outside edges rise with the arc. The inner floor joins under the axle.
    radius = .444
    wheel = -.43 + sqrt(max(0.0,radius**2-(z-1.49)**2))
    arch = max(-.33,wheel)
    crease = max(-.08,arch+.054)
    # The first contour is exactly collinear with every stock seam edge.
    shoulder = mix(0.0, .12, min(1.0,(z-.77)/.35))
    half = [(0,deck+crown),(.47*width,deck+crown*.78),(.98*width,deck),
            ((1.045+shoulder*.05)*width,mix(deck,waist,(1.045-.98)/.17)),
            (min(1.168,1.15*width),waist),(min(1.175,1.17*width),crease),(1.02*width,arch),
            (.81*width,arch),(.76*width,-.33),(0,-.33)]
    loop = half + [(-x,y) for x,y in half[-2:0:-1]]
    fade = max(0.0, (z-1.94)/.402)**1.18
    # At the tail the same transverse curve carries the lamp and lower trim.
    return [(x,y,z+(tail_depth(x,y)-2.342)*fade) for x,y in loop]


def loft(surface, rings, surface_uvs):
    count = len(rings[0])
    sections = len(rings)
    normals = []
    for row in range(sections):
        # Use a centred tangent so the continuous painted shoulder carries
        # neon without individual slices creating highlight bands.
        ring = rings[row]
        left, right = rings[max(row-1,0)], rings[min(row+1, sections-1)]
        normals.append([unit(cross(sub(right[i],left[i]),sub(ring[(i+1)%count],ring[i-1])))
                        for i in range(count)])
    for row in range(sections-1):
        for i in range(count):
            j = (i+1)%count
            surface.face([rings[row][i],rings[row+1][i],rings[row+1][j],rings[row][j]],
                         [surface_uvs(row,i),surface_uvs(row+1,i),surface_uvs(row+1,i+1),surface_uvs(row,i+1)],
                         [normals[row][i],normals[row+1][i],normals[row+1][j],normals[row][j]])
    for row in (0,sections-1):
        ring = rings[row]
        center = (0.0, (max(p[1] for p in ring)+min(p[1] for p in ring))*.5,
                  ring[0][2] if row == 0 else tail_depth(0.0,.055))
        for i in range(count):
            a,b = ring[i],ring[(i+1)%count]
            points = (center,a,b) if row == 0 else (center,b,a)
            normals = None if row == 0 else [unit((.126*x,.038*(y-.17),1.0)) for x,y,_ in points]
            surface.face(points,[(.5+x*.447,.5+y) for x,y,_ in points],normals)


def quarters(far):
    stages = sorted({*(row[0] for row in STATIONS),
                     *(round(1.49 + offset,6) for offset in [-.43,-.39,-.32,-.22,-.10,0,.10,.22,.32,.39,.43])})
    zs = subdivide(stages,.13 if far else .032)
    skin = Surface(0)
    rings = [section(z) for z in zs]
    loft(skin,rings,lambda row,col: (col/len(rings[0]),(zs[row]-.77)/1.572))
    return skin


def on_tail(points, offset):
    return [(x,y,tail_depth(x,y)+offset) for x,y in points]


def flat_cross(a,b,c):
    return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])


def skin_pattern(surface, polygon, offset):
    # Ear clipping preserves the narrow concave light-guide tips. Evaluate
    # every subtriangle on the curved tail so the cover cannot cut through it.
    remaining = list(polygon)
    while len(remaining) > 2:
        for i,b in enumerate(remaining):
            a,c = remaining[i-1],remaining[(i+1)%len(remaining)]
            if flat_cross(a,b,c) <= 1e-8:
                continue
            if any(p not in (a,b,c) and min(flat_cross(a,b,p),flat_cross(b,c,p),flat_cross(c,a,p)) >= 0
                   for p in remaining):
                continue
            steps = ceil(max(hypot(*sub(a,b)),hypot(*sub(b,c)),hypot(*sub(c,a))) / .28)
            def p(u,v):
                return tuple(x+((y-x)*u+(z-x)*v)/steps for x,y,z in zip(a,b,c))
            for u in range(steps):
                for v in range(steps-u):
                    surface.panel(on_tail([p(u,v),p(u+1,v),p(u,v+1)],offset))
                    if u+v < steps-1:
                        surface.panel(on_tail([p(u+1,v),p(u+1,v+1),p(u,v+1)],offset))
            remaining.pop(i)
            break
        else:
            raise ValueError("Tail trim contour must have positive winding and simple boundaries")


def contour(surface, edge, inset, outset=.004, depth=.022):
    for i,a in enumerate(edge):
        j = (i+1)%len(edge)
        steps = ceil(hypot(*sub(a,edge[j]))/.22)
        for step in range(steps):
            lo,hi = step/steps,(step+1)/steps
            outside = [tuple(mix(x,y,t) for x,y in zip(a,edge[j])) for t in (lo,hi)]
            inside = [tuple(mix(x,y,t) for x,y in zip(inset[i],inset[j])) for t in (hi,lo)]
            surface.panel(on_tail(outside,outset)+on_tail(inside,depth))


def optics(side):
    housing, tail, reverse = Surface(2), Surface(3), Surface(4)
    outer = [(x*side,y) for x,y in [(.16,.206),(.84,.192),(.914,.218),(.969,.313),
                                  (.945,.348),(.835,.305),(.18,.289)]]
    if side < 0:
        outer.reverse()
    inner = [(mix(x,.58*side,.08),mix(y,.258,.17)) for x,y in outer]
    contour(housing,outer,inner,.008,.023)
    # Dark opaque lens enclosure with individual seated light guides.
    skin_pattern(housing,inner,.023)
    for guide in [
        [(.188,.266),(.786,.248),(.871,.268),(.920,.314),(.896,.318),(.830,.282),(.197,.280)],
        [(.203,.233),(.780,.216),(.841,.224),(.866,.248),(.826,.249),(.770,.234),(.203,.246)],
    ]:
        edge = [(x*side,y) for x,y in guide]
        skin_pattern(tail,edge if side > 0 else edge[::-1],.028)
    low = [(side*x,y) for x,y in [(.231,.190),(.386,.187),(.412,.205),(.229,.211)]]
    skin_pattern(reverse,low if side > 0 else low[::-1],.027)
    return housing, tail, reverse


def rear_garnish():
    finish = Surface(1)
    # An undertray relief that meets the stock battery shield height and
    # wraps its chamfered edge back into the new solid bumper.
    outer = [(-.93,-.196),(-.81,-.296),(-.70,-.329),(.70,-.329),(.81,-.296),
             (.93,-.196),(.74,-.168),(-.74,-.168)]
    inner = [(x*.943,mix(y,-.244,.15)) for x,y in outer]
    contour(finish,outer,inner,.003,.024)
    skin_pattern(finish,inner,.024)
    for x in (-.62,-.41,.41,.62):
        finish.panel(on_tail([(x-.014,-.285),(x+.012,-.285),(x+.034,-.195),(x+.004,-.197)],.029))
    # Mounting recess between the optics. The dark surface reads as a
    # plate pocket rather than a bright bar across the whole deck.
    finish.panel(on_tail([(-.157,.022),(.157,.022),(.176,.131),(-.176,.131)],.018))
    return finish


def hatch():
    pillar, seal, pane = Surface(0), Surface(1), Surface(5)
    def row(level, u):
        width = mix(.76,.915,level)
        return (u*width,mix(1.13,.515,level)+.038*(1-u*u)*level,
                mix(.555,1.471,level)+.035*(1-u*u)*level)

    slices = [i/14 for i in range(15)]
    for u0,u1 in pairwise([-1+i/9 for i in range(19)]):
        pane.face([row(l,u) for l,u in [(.035,u0),(.965,u0),(.965,u1),(.035,u1)]],
                  [((u+1)*.5,v) for v,u in [(.035,u0),(.965,u0),(.965,u1),(.035,u1)]])
        for lo,hi in [(0,.038),(.963,1)]:
            seal.face([row(l,u) for l,u in [(lo,u0),(hi,u0),(hi,u1),(lo,u1)]],
                      [((u+1)*.5,v) for v,u in [(lo,u0),(hi,u0),(hi,u1),(lo,u1)]])
    for sign in (-1,1):
        for lo,hi in pairwise(slices):
            # Fill the old gap between the side glass and hatch with a
            # structural rail. Frit strip inside the rail masks the edge.
            strip = []
            for level, k in [(lo,1.13),(hi,1.13),(hi,.955),(lo,.955)]:
                x,y,z = row(level,sign)
                strip.append((x*mix(1.0,k,.66),y+.004,z-.023 if k > 1 else z))
            points = strip[::-1] if sign > 0 else strip
            pillar.panel(points)
            frit = [row(v,u*sign) for v,u in [(lo,.942),(hi,.942),(hi,.994),(lo,.994)]]
            seal.panel(frit if sign > 0 else frit[::-1])
    return pillar, seal, pane


def cargo():
    bulkhead = Surface(1)
    rings = []
    for z,width,high in [(1.12,.89,.71),(1.30,.91,.691),(1.53,.93,.522)]:
        rings.append([(0,high,z),(.79*width,high,z),(width,high-.105,z),
                      (width,.16,z),(.76*width,-.261,z),(0,-.261,z),
                      (-.76*width,-.261,z),(-width,.16,z),(-width,high-.105,z),(-.79*width,high,z)])
    loft(bulkhead,rings,lambda row,col:(col/10,row*.5))
    return bulkhead


def rear_bench(far):
    seat = Surface(6)
    bands,segments = (4,8) if far else (8,12)
    for side in (-1,1):
        for center,size,lean in [
            ((side*.46,.370,.53),(.387,.076,.291),0.0),
            ((side*.46,.575,.756),(.327,.232,.100),.23),
            ((side*.46,.791,.803),(.167,.084,.073),.10),
        ]:
            rings = []
            for band in range(bands+1):
                lat = pi*band/bands
                scale = max(.001,sin(lat))**.68
                y = -cos(lat)
                ring = []
                for segment in range(segments):
                    angle = segment*2*pi/segments
                    x,z = cos(angle)*scale,sin(angle)*scale
                    point = (center[0]+size[0]*x,center[1]+size[1]*y,
                             center[2]+size[2]*z+lean*size[1]*y)
                    ring.append(point)
                rings.append(ring)
            for low,high in pairwise(rings):
                for i in range(len(low)):
                    j = (i+1)%len(low)
                    shape = [low[i],high[i],high[j],low[j]]
                    seat.face(shape,[(p[0],p[1]+p[2]) for p in shape])
            for index in (0,-1):
                ring = rings[index]
                shape = ring[::-1] if index < 0 else ring
                seat.face(shape,[(p[0],p[2]) for p in shape])
    return seat


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    data = []
    for level in (0,1):
        frame, seal, glass = hatch()
        rear = {"RearHatchSolid":[quarters(level == 1)], "RearCabinBulkhead":[cargo()],
                "HatchFrame":[frame,seal], "RearGlass":[glass], "RearLowerTrim":[rear_garnish()],
                "RearBench":[rear_bench(level == 1)]}
        for side,tag in [(-1,"L"),(1,"R")]:
            housing,tail,reverse = optics(side)
            rear.update({f"LampHousing{tag}":[housing],f"BrakeLens{tag}":[tail],f"ReverseLens{tag}":[reverse]})
        name = f"rear_lod{level}"
        triangles = write_model(OUT,name,rear,MATERIALS,SOCKETS,"NightGrid Kestrel S6 rear body authoring",
                                "../kestrel_s6_front/crimson_micro_normal.png")
        data.append({"file":name+".gltf","triangles":triangles})
    files = {p.name:sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.iterdir())
             if p.suffix in (".bin",".gltf")}
    manifest = {"source":"tools/author_kestrel_rear.py","units":"metres","forward":"-Z",
                "license":"Original NightGrid project artwork. No separate public license declared.",
                "pivots":SOCKETS,"variants":data,"sha256":files,
                "texture":"../kestrel_s6_front/crimson_micro_normal.png"}
    (OUT/"source.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8",newline="\n")


if __name__ == "__main__":
    main()
