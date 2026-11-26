#!/usr/bin/env python3
"""Validate the authored fascia contract before the Godot import review."""

from collections import Counter
from hashlib import sha256
import json
import struct

from author_kestrel_fascia import OUT, PORTS, fascia, cross, sub


def read_accessor(model, payload, index):
    record = model["accessors"][index]
    view = model["bufferViews"][record["bufferView"]]
    size = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[record["type"]]
    code = {5125: "I", 5126: "f"}[record["componentType"]]
    assert view["byteLength"] == size * record["count"] * 4
    end = view["byteOffset"] + view["byteLength"]
    assert end <= len(payload)
    return list(struct.iter_unpack("<" + code * size, payload[view["byteOffset"]:end]))


def hit_xy(triangle, point):
    a, b, c = triangle
    normal = cross(sub(b, a), sub(c, a))
    if abs(normal[2]) < 1e-9:
        return False
    x, y = point
    sides = [(j[0] - i[0]) * (y - i[1]) - (j[1] - i[1]) * (x - i[0])
             for i,j in ((a,b),(b,c),(c,a))]
    return all(value >= 0 for value in sides) or all(value <= 0 for value in sides)


def verify_lod(record, sockets, budget):
    model = json.loads((OUT / record["file"]).read_text(encoding="utf-8"))
    payload = (OUT / model["buffers"][0]["uri"]).read_bytes()
    assert len(payload) == model["buffers"][0]["byteLength"]
    assert {n["name"]: n["translation"] for n in model["nodes"] if "translation" in n} == sockets
    assert "KHR_materials_clearcoat" in model["extensionsUsed"]
    assert "normalTexture" in model["materials"][0]
    all_triangles = {}
    for mesh in model["meshes"]:
        faces = []
        for part in mesh["primitives"]:
            attributes = part["attributes"]
            points = read_accessor(model, payload, attributes["POSITION"])
            normals = read_accessor(model, payload, attributes["NORMAL"])
            uvs = read_accessor(model, payload, attributes["TEXCOORD_0"])
            indices = [i[0] for i in read_accessor(model, payload, part["indices"])]
            assert len(points) == len(normals) == len(uvs)
            assert all(abs(sum(x*x for x in n) - 1.0) < 1e-4 for n in normals)
            assert all(abs(x) <= 1.175 and -.43 <= y <= .40 and -2.351 <= z <= -2.09 for x,y,z in points)
            assert len(indices) % 3 == 0 and min(indices) >= 0 and max(indices) < len(points)
            for offset in range(0, len(indices), 3):
                x,y,z = indices[offset:offset+3]
                a, b, c = map(points.__getitem__, (x,y,z))
                face = cross(sub(b,a),sub(c,a))
                assert sum(component**2 for component in face) > 1e-15, (record["file"], mesh["name"], a,b,c)
                for n in (normals[x],normals[y],normals[z]):
                    assert sum(v*u for v,u in zip(n,face)) > 0, (record["file"], mesh["name"], a)
                faces.append((a,b,c))
        assert len(faces) == record["triangles"][mesh["name"]]
        all_triangles[mesh["name"]] = faces
    assert sum(map(len,all_triangles.values())) < budget
    shell = all_triangles["BumperCover"]
    assert any(hit_xy(face, (0,.16)) for face in shell), "Solid brow must remain"
    assert {p for face in shell for p in face if abs(p[1]-.377) < .0001}, "Bonnet flange must reach its mating edge"
    directed = Counter(edge for a,b,c in shell for edge in ((a,b),(b,c),(c,a)))
    assert all(n == 1 and directed.get((b,a)) == 1 for (a,b),n in directed.items()), "Unsealed cover edge"
    for x0,x1,y0,y1 in PORTS:
        x,y,_ = fascia((x0+x1)*.5,(y0+y1)*.5)
        assert not any(hit_xy(face,(x,y)) for face in shell), "Intake was capped by the cover"
    return sum(map(len,all_triangles.values()))


def main():
    manifest = json.loads((OUT / "source.json").read_text(encoding="utf-8"))
    assert manifest["status"] == "creator_review"
    # Original creator-supplied images are JPEGs, not PNGs. Preserve their bytes.
    for relative in (manifest["concept"], "docs/art/references/kestrel_s6/jade_wash_gameplay_baseline.jpg"):
        payload = (OUT.parents[3] / relative).read_bytes()
        assert payload.startswith(b"\xff\xd8\xff"), f"Invalid JPEG signature: {relative}"
        assert payload.endswith(b"\xff\xd9"), f"Missing JPEG end marker: {relative}"
    assert sha256((OUT.parents[3] / manifest["concept"]).read_bytes()).hexdigest() == manifest["concept_sha256"]
    for name, digest in manifest["files"].items():
        assert sha256((OUT / name).read_bytes()).hexdigest() == digest
    counts = [verify_lod(lod,manifest["semantic_sockets"],budget)
              for lod,budget in zip(manifest["lods"], (3200,1350), strict=True)]
    assert counts[1] < counts[0] * .50
    print(f"KESTREL_FASCIA_CHECK PASS: {counts[0]} near / {counts[1]} reduced triangles, three open intake ports")


if __name__ == "__main__":
    main()
