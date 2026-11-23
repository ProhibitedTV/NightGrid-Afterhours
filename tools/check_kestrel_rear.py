#!/usr/bin/env python3
"""Check geometry and provenance for both Kestrel rear variants."""

from collections import Counter
from hashlib import sha256
import json

from author_kestrel_rear import OUT, SOCKETS, tail_depth
from check_kestrel_fascia import read_accessor
from author_kestrel_fascia import cross, sub


def triangles(model, payload, mesh):
    for face in mesh["primitives"]:
        attr = face["attributes"]
        points = read_accessor(model,payload,attr["POSITION"])
        normals = read_accessor(model,payload,attr["NORMAL"])
        uv = read_accessor(model,payload,attr["TEXCOORD_0"])
        indices = read_accessor(model,payload,face["indices"])
        assert len(points) == len(normals) == len(uv)
        assert max(indices)[0] < len(points) and len(indices) % 3 == 0
        assert all(abs(sum(x*x for x in n)-1) < .001 for n in normals)
        for i in range(0,len(indices),3):
            a,b,c = [points[j[0]] for j in indices[i:i+3]]
            area = cross(sub(b,a),sub(c,a))
            assert sum(value**2 for value in area) > 1e-16, mesh["name"]
            yield a,b,c


def closed(faces):
    edges = Counter(edge for a,b,c in faces for edge in ((a,b),(b,c),(c,a)))
    return all(count == 1 and edges.get((b,a)) == 1 for (a,b),count in edges.items())


def main():
    source = json.loads((OUT/"source.json").read_text(encoding="utf-8"))
    for path,expected in source["sha256"].items():
        assert sha256((OUT/path).read_bytes()).hexdigest() == expected
    totals = []
    for asset,budget in zip(source["variants"],[4400,2000],strict=True):
        model = json.loads((OUT/asset["file"]).read_text(encoding="utf-8"))
        payload = (OUT/model["buffers"][0]["uri"]).read_bytes()
        assert len(payload) == model["buffers"][0]["byteLength"]
        assert {d["name"]:d["translation"] for d in model["nodes"] if "translation" in d} == {
            label:list(point) for label,point in SOCKETS.items()}
        parts = {mesh["name"]:list(triangles(model,payload,mesh)) for mesh in model["meshes"]}
        assert {n:len(t) for n,t in parts.items()} == asset["triangles"]
        for name in ("RearHatchSolid","RearCabinBulkhead"):
            assert closed(parts[name]), f"{name} has an open or reversed edge"
        skin = {p for triangle in parts["RearHatchSolid"] for p in triangle}
        assert all(abs(x) <= 1.176 and -.331 <= y <= .60 and .769 <= z <= 2.35 for x,y,z in skin)
        assert any(abs(x) >= 1.02 and abs(y-.014) < .001 and abs(z-1.49) < .001 for x,y,z in skin), (
            "Wheel-opening crown no longer matches rear axle and tire clearance")
        for kind in ("BrakeLens","ReverseLens"):
            for side in "LR":
                vertices = {p for triangle in parts[kind+side] for p in triangle}
                assert all(.02 < z-tail_depth(x,y) < .031 and z < 2.356 for x,y,z in vertices)
        bench = {p for triangle in parts["RearBench"] for p in triangle}
        assert all(y < .88 and z < .94 for _,y,z in bench), "Rear upholstery must stay inside the hatch glass"
        assert (OUT/model["images"][0]["uri"]).is_file()
        count = sum(map(len,parts.values()))
        assert count < budget, (asset["file"],count)
        totals.append(count)
    print(f"KESTREL_REAR_ASSET PASS: closed rear and cargo bulkhead, mounted optics, {totals} triangles")


if __name__ == "__main__":
    main()
