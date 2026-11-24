"""Original compact glTF writer shared with Cinder R9's source geometry.

Standalone extraction of the polygon deduplicator and glTF 2.0 binary writer.
No Kestrel artwork, sockets, assets or source generation is imported here.
Kept byte-compatible with Cinder's already checked-in mesh files.
"""
import json
import struct
from math import sqrt

def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def cross(a, b):
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])


def unit(v):
    length = sqrt(sum(x*x for x in v))
    if length < 1e-10:
        raise ValueError("zero area surface")
    return tuple(x / length for x in v)


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


