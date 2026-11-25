#!/usr/bin/env python3
"""Bake the original Kestrel S6 bumper assembly and review variants to glTF."""

from collections import defaultdict
from hashlib import sha256
from itertools import pairwise
import json
from math import sin, pi, exp, sqrt, ceil
from pathlib import Path
from random import Random
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/models/nightgrid/kestrel_s6_front"

# Body-local metres, Y up and -Z forward. Fit the main-branch front axle
# bracket, bonnet seam and lamp seats while retaining each original rig pivot.
U = [-1, -.95, -.89, -.64, -.54, -.45, 0, .45, .54, .64, .89, .95, 1]
V = [0, .055, .12, .18, .24, .59, .65, .72, .81, .945, 1]
PORTS = [(-.54, .54, .18, .59), (-.89, -.64, .24, .65), (.64, .89, .24, .65)]
SOCKETS = {
    "Mount_L": (-.93, .158, -2.177), "Mount_R": (.93, .158, -2.177),
    "Tray_L": (-.65, -.369, -2.182), "Tray_R": (.65, -.369, -2.182),
    "CoolingCore": (0, -.062, -2.12),
    "TowEye": (.59, -.12, -2.24), "PlateCarrier": (0, .081, -2.346),
}

PAINT = {"name": "Deep Crimson Basecoat", "pbrMetallicRoughness": {
    "baseColorFactor": [.28, .012, .026, 1], "metallicFactor": .58, "roughnessFactor": .205},
    "normalTexture": {"index": 0, "scale": .10},
    "extensions": {"KHR_materials_clearcoat": {"clearcoatFactor": 1.0, "clearcoatRoughnessFactor": .115}}}
MATERIALS = [
    PAINT,
    {"name": "Molded Graphite Duct", "pbrMetallicRoughness": {
        "baseColorFactor": [.021, .027, .033, 1], "metallicFactor": .06, "roughnessFactor": .5}},
    {"name": "Satin Black Grille", "pbrMetallicRoughness": {
        "baseColorFactor": [.040, .049, .061, 1], "metallicFactor": .43, "roughnessFactor": .33}},
    {"name": "Cooling Core Aluminum", "pbrMetallicRoughness": {
        "baseColorFactor": [.075, .086, .096, 1], "metallicFactor": .77, "roughnessFactor": .42}},
]


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def cross(a, b):
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])


def unit(v):
    length = sqrt(sum(x*x for x in v))
    if length < 1e-10:
        raise ValueError("zero area surface")
    return tuple(x / length for x in v)


def fascia(u, v):
    a = abs(u)
    # Crown in section, rearward turn into the fenders and a lifted lower
    # corner. Local shoulders carry reflections back to the stamped bonnet.
    width = .944 + .090*sin(pi*v*.97)
    x = width*u
    y = -.417 + .724*v + a**2*(.066 - .028*v)
    shoulder = .019*exp(-((a-.66)/.14)**2)*sin(pi*v)**2
    z = -2.347 + .165*a**3 + .034*(2*v-1)**2 - shoulder*(1-a**3)
    # Wrap the upper flange onto the real forward bonnet edge. The join tapers
    # inward and stays tight to the hood shutline across the entire width.
    blend = max(0.0, min(1.0, (v - .72) / .28))
    blend = blend*blend*(3 - 2*blend)
    return (x+(.784*u-x)*blend, y+(.377-y)*blend,
            max(-2.35,z+(-2.31-z)*blend))


def front_normal(u, v):
    du = sub(fascia(u+.001, v), fascia(u-.001, v))
    dv = sub(fascia(u, v+.001), fascia(u, v-.001))
    return unit(cross(dv, du))


class Surface:
    def __init__(self, material):
        self.material = material
        self.vertices = []
        self.indices = []
        self.lookup = {}

    def face(self, points, uvs, normals=None):
        if normals is None:
            n = unit(cross(sub(points[1], points[0]), sub(points[2], points[0])))
            normals = [n] * len(points)
        ids = []
        for pos, normal, uv in zip(points, normals, uvs):
            vertex = tuple(round(v, 7) for v in (*pos, *normal, *uv))
            if vertex not in self.lookup:
                self.lookup[vertex] = len(self.vertices)
                self.vertices.append(vertex)
            ids.append(self.lookup[vertex])
        for i in range(1, len(ids)-1):
            self.indices.extend((ids[0], ids[i], ids[i+1]))

    def panel(self, points):
        self.face(points, [(p[0], p[1]) for p in points])


def subdivide(marks, spacing):
    result = []
    for start, end in pairwise(marks):
        segments = ceil((end-start) / spacing)
        result.extend(round(start + (end-start)*i/segments, 8) for i in range(segments))
    return result + marks[-1:]


def in_port(u, v):
    return any(x0 < u < x1 and y0 < v < y1 for x0, x1, y0, y1 in PORTS)


def cover(far):
    paint, trim = Surface(0), Surface(1)
    us = subdivide(U, .20 if far else .069)
    vs = subdivide(V, .19 if far else .065)
    edges = defaultdict(list)
    for u0, u1 in pairwise(us):
        for v0, v1 in pairwise(vs):
            if in_port((u0+u1)*.5, (v0+v1)*.5):
                continue
            ring = [(u0,v0), (u0,v1), (u1,v1), (u1,v0)]
            outer = [fascia(*p) for p in ring]
            inner = [(x, y, z + .004) for x,y,z in outer] # 4 mm molded polymer
            normals = [front_normal(*p) for p in ring]
            uvs = [((u+1)*.5, v) for u,v in ring]
            surface = trim if v1 <= .12 else paint
            surface.face(outer, uvs, normals)
            trim.face(inner[::-1], uvs[::-1], [tuple(-q for q in n) for n in normals[::-1]])
            for i in range(4):
                j = (i+1) % 4
                edges[tuple(sorted((ring[i], ring[j])))].append((outer[i], outer[j], inner[i], inner[j]))
    for matches in edges.values():
        if len(matches) == 1:
            a,b,c,d = matches[0]
            trim.panel([b,a,c,d])
    return [paint, trim]


def ring_for_port(bounds, far):
    x0,x1,y0,y1 = bounds
    us = [u for u in subdivide(U, .20 if far else .069) if x0 <= u <= x1]
    vs = [v for v in subdivide(V, .19 if far else .065) if y0 <= v <= y1]
    return ([(u, y0) for u in us[:-1]] + [(x1, v) for v in vs[:-1]]
            + [(u, y1) for u in us[:0:-1]] + [(x0, v) for v in vs[:0:-1]])


def ducts(far):
    throat = Surface(1)
    for bounds in PORTS:
        ring = ring_for_port(bounds, far)
        x0,x1,y0,y1 = bounds
        mid_x, mid_y = (x0+x1)*.5, (y0+y1)*.5
        front = [fascia(u,v) for u,v in ring]
        back = []
        collar = []
        for u,v in ring:
            x,y,z = fascia(mid_x+(u-mid_x)*.82, mid_y+(v-mid_y)*.78)
            back.append((x, y, -2.119))
            skin = fascia(u,v)
            collar.append(tuple(a+(b-a)*.20 for a,b in zip(skin, (x,y,z+.046))))
        for i,a in enumerate(front):
            j = (i+1) % len(front)
            throat.panel([front[j],a,collar[i],collar[j]])
            throat.panel([collar[j],collar[i],back[i],back[j]])
    return throat


def grille(far):
    insert, core = Surface(2), Surface(3)
    division = 16 if far else 32
    for sides, (x0,x1,y0,y1) in enumerate(PORTS):
        # A recessed flared heat exchanger for the centre opening, finned
        # wheel-duct debris screens at each outer opening.
        i0,i1 = x0+.021, x1-.021
        floor, ceiling = y0+.035, y1-.035
        count = division if sides == 0 else division//3
        for i in range(count):
            start = i0 + (i1-i0)*i/count
            end = start + (i1-i0)*(.19 if sides == 0 else .21)/count
            a,b = fascia(start,floor), fascia(start,ceiling)
            c,d = fascia(end,ceiling), fascia(end,floor)
            if sides == 0:
                z = -2.174
            else:
                z = -2.140
            # Angled fins have separate leading face and side wall.
            front_edge = [(p[0], p[1], z-.012) for p in (a,b,c,d)]
            insert.panel(front_edge)
            leading = [(p[0]-.006, p[1], z+.024) for p in front_edge[:2]]
            insert.panel([leading[0],leading[1],front_edge[1],front_edge[0]])
        if sides == 0:
            # Real open bars in front of a set-back radiator face.
            for v in (.218, .289, .371, .449, .542):
                p = [fascia(u,w) for u,w in ((-.493,v),(-.493,v+.009),(.493,v+.009),(.493,v))]
                insert.panel([(x,y,-2.187) for x,y,_ in p])
            core.panel([(-.46,-.251,-2.105),(-.46,.06,-2.105),(.46,.06,-2.105),(.46,-.251,-2.105)])
            for i in range(9 if far else 24):
                y = -.249 + i*.305/(9 if far else 24)
                core.panel([(-.46,y,-2.105),(-.46,y+.0025,-2.110),(.46,y+.0025,-2.110),(.46,y,-2.105)])
    return insert, core


def write_model(directory, stem, meshes, materials, sockets, generator, image, *, pivots=None):
    payload = bytearray()
    accessors, views = [], []

    def buffer(values, code, size, role):
        lanes = len(values[0])
        flat = [x for row in values for x in row]
        raw = struct.pack("<" + str(len(flat)) + code, *flat)
        view = {"buffer": 0, "byteOffset": len(payload), "byteLength": len(raw), "target": role}
        payload.extend(raw)
        obj = {"bufferView": len(views), "componentType": size, "count": len(values),
               "type": "SCALAR" if lanes == 1 else f"VEC{lanes}"}
        if role == 34962:
            obj |= {"min": list(map(min, zip(*values))), "max": list(map(max, zip(*values)))}
        views.append(view)
        accessors.append(obj)
        return len(accessors)-1

    records, totals = [], {}
    for name, surfaces in meshes.items():
        entries = []
        totals[name] = 0
        for surface in surfaces:
            pos = [row[:3] for row in surface.vertices]
            norm = [row[3:6] for row in surface.vertices]
            uv = [row[6:] for row in surface.vertices]
            attrs = {"POSITION": buffer(pos, "f", 5126, 34962),
                     "NORMAL": buffer(norm, "f", 5126, 34962),
                     "TEXCOORD_0": buffer(uv, "f", 5126, 34962)}
            indices = buffer([(i,) for i in surface.indices], "I", 5125, 34963)
            entries.append({"attributes": attrs, "indices": indices, "material": surface.material})
            totals[name] += len(surface.indices) // 3
        records.append({"name": name, "primitives": entries})
    nodes = [{"name": name, "mesh": idx} for idx,name in enumerate(meshes)]
    for node in nodes:
        if pivots and node["name"] in pivots:
            node["translation"] = pivots[node["name"]]
    nodes.extend({"name": name, "translation": point} for name,point in sockets.items())
    model = {"asset": {"version": "2.0", "generator": generator},
             "extensionsUsed": ["KHR_materials_clearcoat"],
             "nodes": nodes, "scene": 0, "scenes": [{"nodes": list(range(len(nodes)))}],
             "meshes": records, "materials": materials, "buffers": [{"uri": stem+".bin", "byteLength": len(payload)}],
             "bufferViews": views, "accessors": accessors, "textures": [{"source": 0}],
             "images": [{"uri": image}]}
    (directory / (stem+".bin")).write_bytes(payload)
    (directory / (stem+".gltf")).write_text(json.dumps(model,separators=(",",":"))+"\n",encoding="utf-8",newline="\n")
    return totals


def write_asset(stem, far):
    skin, trims = cover(far)
    radiator, condenser = grille(far)
    meshes = {
        "BumperCover": [skin, trims],
        "DuctReturns": [ducts(far)],
        "GrilleAndCore": [radiator, condenser],
    }
    return write_model(OUT, stem, meshes, MATERIALS, SOCKETS, "NightGrid Kestrel front fascia authoring",
                       "crimson_micro_normal.png")


def bake_normal(path):
    size = 128
    rng = Random(23547)
    height = [[rng.uniform(-.18,.18) for _ in range(size)] for _ in range(size)]
    scan = bytearray()
    for y in range(size):
        scan.append(0)
        for x in range(size):
            dx = height[y][(x+1)%size] - height[y][x-1]
            dy = height[(y+1)%size][x] - height[y-1][x]
            scan.extend(round((axis+1)*127.5) for axis in unit((-dx,-dy,1.0)))
    def chunk(kind, contents):
        return (struct.pack(">I",len(contents)) + kind + contents
                + struct.pack(">I",zlib.crc32(kind+contents)))
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR",struct.pack(">IIBBBBB",size,size,8,2,0,0,0))
                     + chunk(b"IDAT",zlib.compress(scan,9)) + chunk(b"IEND",b""))


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    bake_normal(OUT / "crimson_micro_normal.png")
    near, far = [write_asset(f"fascia_lod{i}", i == 1) for i in range(2)]
    names = ["fascia_lod0.gltf","fascia_lod0.bin","fascia_lod1.gltf","fascia_lod1.bin","crimson_micro_normal.png"]
    manifest = {
        "schema_version": 1, "id": "nightgrid.kestrel_s6.front_bumper", "status": "creator_review",
        "units": "metres", "up": "+Y", "forward": "-Z", "pivot": [0,0,0],
        "author": "NightGrid Afterhours", "source": "tools/author_kestrel_fascia.py",
        "license": "Original NightGrid project artwork. No separate public license declared.",
        "concept": "docs/art/concepts/kestrel_s6/jade_wash_approved_direction.png",
        "concept_sha256": "cfb3ca8338a7b34aff3bafe41cefbf7348e295cd3421cdc0c0ae7071e07da119",
        "files": {name: sha256((OUT / name).read_bytes()).hexdigest() for name in names},
        "lods": [{"file": names[0], "triangles": near},{"file": names[2],"triangles": far}],
        "semantic_sockets": SOCKETS,
    }
    (OUT/"source.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8",newline="\n")


if __name__ == "__main__":
    main()
