#!/usr/bin/env python3
"""Validate generated Cinder R9 paired headlight covers and their provenance."""
from __future__ import annotations
from collections import defaultdict
from hashlib import sha256
import json
from pathlib import Path
import struct
import unittest

ROOT=Path(__file__).resolve().parents[1]
ASSET=ROOT/"assets/models/nightgrid/road_cars"
THICKNESS=.0036

def vec3(doc, buffer, index):
    accessor=doc["accessors"][index]
    if accessor["componentType"]!=5126 or accessor["type"]!="VEC3":
        raise AssertionError("Expected float VEC3")
    view=doc["bufferViews"][accessor["bufferView"]]
    offset=int(view.get("byteOffset",0))+int(accessor.get("byteOffset",0))
    stride=int(view.get("byteStride",12))
    if stride<12 or offset+(accessor["count"]-1)*stride+12>len(buffer):
        raise AssertionError("Vertex stream out of bounds")
    return [struct.unpack_from("<3f",buffer,offset+i*stride)
            for i in range(accessor["count"])]

class CinderOpticGeometry(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.doc=json.loads((ASSET/"cinder_r9.gltf").read_text(encoding="utf-8"))
        cls.binary=(ASSET/"cinder_r9.bin").read_bytes()
        cls.manifest=json.loads((ASSET/"source.json").read_text(encoding="utf-8"))
        front=next(m for m in cls.doc["meshes"] if m["name"]=="FrontClip")
        cls.idx=next(i for i,m in enumerate(cls.doc["materials"]) if m["name"]=="OpticCover")
        cover=next(p for p in front["primitives"] if p["material"]==cls.idx)
        cls.points=vec3(cls.doc,cls.binary,cover["attributes"]["POSITION"])
        cls.normals=vec3(cls.doc,cls.binary,cover["attributes"]["NORMAL"])

    def test_generated_artifact_hashes(self):
        for name in ("cinder_r9.gltf","cinder_r9.bin"):
            self.assertEqual(sha256((ASSET/name).read_bytes()).hexdigest(),
                             self.manifest["sha256"][name])

    def test_covers_on_both_corners(self):
        self.assertTrue(any(x<-.45 for x,y,z in self.points))
        self.assertTrue(any(x>.45 for x,y,z in self.points))
        self.assertGreater(len(self.points),200)

    def test_outward_inward_and_edge_normals(self):
        self.assertTrue(any(n[1]>.7 for n in self.normals))
        self.assertTrue(any(n[1]<-.7 for n in self.normals))
        self.assertTrue(any(abs(n[1])<.5 for n in self.normals))

    def test_real_pair_thickness(self):
        groups=defaultdict(list)
        for x,y,z in self.points:
            groups[(round(x,5),round(z,5))].append(y)
        paired=[max(ys)-min(ys) for ys in groups.values() if len(ys)>1]
        count=sum(abs(d-THICKNESS)<.0002 for d in paired)
        self.assertGreater(count,100)

    def test_two_skin_opacity(self):
        mat=self.doc["materials"][self.idx]
        self.assertEqual(mat["alphaMode"],"BLEND")
        alpha=mat["pbrMetallicRoughness"]["baseColorFactor"][3]
        self.assertTrue(.1<alpha<.2)

if __name__=="__main__":
    unittest.main()
