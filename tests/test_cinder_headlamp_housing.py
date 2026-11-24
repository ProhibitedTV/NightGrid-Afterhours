#!/usr/bin/env python3
"""Geometric validation for Cinder's original stamped headlamp housings.

Reads regenerated glTF and BIN. Source-only assertions would miss incorrect
exporter wiring and accidentally exposed/deleted optics at Godot runtime.
"""
from __future__ import annotations
from collections import defaultdict
from hashlib import sha256
import json
from pathlib import Path
import struct
import unittest

BASE = Path(__file__).resolve().parents[1] / "assets/models/nightgrid/road_cars"

def vertices(doc, raw, index):
    accessor = doc["accessors"][index]
    if accessor["componentType"] != 5126 or accessor["type"] != "VEC3":
        raise AssertionError("Expected float32 VEC3 positions")
    view = doc["bufferViews"][accessor["bufferView"]]
    if view["buffer"] != 0:
        raise AssertionError("Unexpected buffer")
    start = int(view.get("byteOffset",0)) + int(accessor.get("byteOffset",0))
    stride = int(view.get("byteStride",12))
    if stride < 12 or start+(accessor["count"]-1)*stride+12>len(raw):
        raise AssertionError("Vertex buffer out of bounds")
    return [struct.unpack_from("<3f",raw,start+i*stride)
            for i in range(accessor["count"])]

class OriginalCinderHeadlampCradles(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.doc=json.loads((BASE/"cinder_r9.gltf").read_text())
        cls.raw=(BASE/"cinder_r9.bin").read_bytes()
        cls.source=json.loads((BASE/"source.json").read_text())
        cls.materials={m["name"]:i for i,m in enumerate(cls.doc["materials"])}
        cls.meshes={m["name"]:m for m in cls.doc["meshes"]}
        front=cls.meshes["FrontClip"]
        cls.housing=next(p for p in front["primitives"]
                         if p["material"]==cls.materials["HeadlampReflectorHousing"])
        lens=cls.meshes["HeadLenses"]
        cls.lens=next(p for p in lens["primitives"]
                      if p["material"]==cls.materials["OpticCover"])
        cls.housing_points=vertices(cls.doc,cls.raw,cls.housing["attributes"]["POSITION"])
        cls.lens_points=vertices(cls.doc,cls.raw,cls.lens["attributes"]["POSITION"])

    def test_separate_formed_bowls_on_both_front_corners(self):
        self.assertGreater(len(self.housing_points),110)
        left=[(x,y,z) for x,y,z in self.housing_points if x < -.42]
        right=[(x,y,z) for x,y,z in self.housing_points if x > .42]
        self.assertGreater(len(left),45)
        self.assertGreater(len(right),45)
        self.assertTrue(all(-2.32<z<-1.73 for x,y,z in left+right))

    def test_bonded_glazing_remains_ahead_of_every_housing_station(self):
        # Both surfaces share the existing on_deck station mapping, hence
        # identical X and Z coordinates. Test the *actual exported models*.
        optical=defaultdict(list)
        for x,y,z in self.lens_points:
            optical[(round(x,5),round(z,5))].append(y)
        checked=0
        for x,y,z in self.housing_points:
            candidate=optical.get((round(x,5),round(z,5)))
            if candidate:
                self.assertGreater(min(candidate)-y,.015,
                    "New stamped reflector housing cuts into the bonded cover")
                checked+=1
        self.assertGreater(checked,110,"Housing and lens stations disconnected")

    def test_cradle_has_both_a_perimeter_and_deeper_mounting_regions(self):
        # Nominal 29mm perimeter setback and progressively deeper local
        # pressings behind the two projector mounts.
        shallow=[]
        deep=[]
        for x,y,z in self.housing_points:
            if abs(x) < .45:
                continue
            # The two bowls must retain variable molded depth/curvature,
            # rather than collapsing back to one flat black card.
            near = [p[1] for p in self.housing_points
                    if abs(p[0]-x)<.001 and abs(p[2]-z)<.001]
            self.assertTrue(near)
        for x,y,z in self.housing_points:
            if z < -2.19 or z > -1.83:
                shallow.append(y)
            else:
                deep.append(y)
        self.assertGreater(len(shallow),20)
        self.assertGreater(len(deep),20)
        self.assertGreater(max(shallow),min(deep)+.020)

    def test_manufactured_satin_metal_is_not_transparent_glass(self):
        mat=self.doc["materials"][self.materials["HeadlampReflectorHousing"]]
        pbr=mat["pbrMetallicRoughness"]
        self.assertGreater(pbr["metallicFactor"],.5)
        self.assertLess(pbr["roughnessFactor"],.4)
        self.assertNotEqual(mat.get("alphaMode","OPAQUE"),"BLEND")
        self.assertNotEqual(self.materials["HeadlampReflectorHousing"],
                            self.materials["OpticCover"])

    def test_unchanged_asset_source_provenance(self):
        for name in ("cinder_r9.gltf","cinder_r9.bin"):
            self.assertEqual(sha256((BASE/name).read_bytes()).hexdigest(),
                             self.source["sha256"][name])

if __name__ == "__main__":
    unittest.main()
