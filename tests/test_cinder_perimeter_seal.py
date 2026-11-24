#!/usr/bin/env python3
"""Verify the *exported* Cinder R9 bonded-headlight rubber sealing system.

The gasket must follow all four edges of the lens on both sides, remain
a separate opaque rubber mesh and leave the original lens unmodified.
"""
from __future__ import annotations

from hashlib import sha256
from math import dist
from pathlib import Path
import json
import struct
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
DIR=ROOT/"assets/models/nightgrid/road_cars"
sys.path.insert(0,str(ROOT/"tools/art"))
from author_cinder_r9 import R9, DECK_COLS, HEAD_Z, on_deck, sampled_stations


def vec3(doc,raw,accessor_id):
    a=doc["accessors"][accessor_id]
    assert a["componentType"]==5126 and a["type"]=="VEC3"
    b=doc["bufferViews"][a["bufferView"]]
    start=b.get("byteOffset",0)+a.get("byteOffset",0)
    stride=b.get("byteStride",12)
    assert start+(a["count"]-1)*stride+12<=len(raw)
    return [struct.unpack_from("<3f",raw,start+i*stride)
            for i in range(a["count"])]


class CinderMoldedLampSeals(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.doc=json.loads((DIR/"cinder_r9.gltf").read_text())
        cls.binary=(DIR/"cinder_r9.bin").read_bytes()
        cls.source=json.loads((DIR/"source.json").read_text())
        front=next(m for m in cls.doc["meshes"] if m["name"]=="FrontClip")
        cls.names={m["name"]:i for i,m in enumerate(cls.doc["materials"])}
        cls.gasket=next(p for p in front["primitives"]
                        if p["material"]==cls.names["HeadlampPerimeterSeal"])
        cls.points=vec3(cls.doc,cls.binary,cls.gasket["attributes"]["POSITION"])
        cls.alloy=[v for p in front["primitives"]
                   if p["material"]==cls.names["MachinedAlloy"]
                   for v in vec3(cls.doc,cls.binary,p["attributes"]["POSITION"])]
        cls.cols={}
        cls.stations=[z for z in sampled_stations(R9) if HEAD_Z[0]<=z<=HEAD_Z[1]]
        for side in (-1,1):
            cls.cols[side]=[u for u in DECK_COLS if .48<=side*u<=.96]

    def test_closed_four_edge_seal_on_both_lamp_bays(self):
        self.assertGreater(len(self.points),750)
        for side in (-1,1):
            cols=self.cols[side]
            self.assertGreater(len(cols),3)
            for u in (cols[0],cols[-1]):
                for z in self.stations:
                    expected=on_deck(R9,u,z,-.0115)
                    nearest=min(dist(v,expected) for v in self.points)
                    self.assertLess(nearest,.0025,
                        f"Broken longitudinal gasket side={side}, u={u}, z={z}")
            for z in (self.stations[0],self.stations[-1]):
                for u in cols:
                    expected=on_deck(R9,u,z,-.0115)
                    nearest=min(dist(v,expected) for v in self.points)
                    self.assertLess(nearest,.0025,
                        f"Broken end gasket side={side}, u={u}, z={z}")

    def test_real_thickness_rubber_material_not_transparent_or_metal(self):
        gasket=self.doc["materials"][self.names["HeadlampPerimeterSeal"]]
        pbr=gasket["pbrMetallicRoughness"]
        self.assertEqual(gasket.get("alphaMode","OPAQUE"),"OPAQUE")
        self.assertLess(pbr["metallicFactor"],.02)
        self.assertGreater(pbr["roughnessFactor"],.8)
        # A narrow physical gasket is not just a shader outline or flat card.
        self.assertGreater(len(self.points),750)
        self.assertGreater(max(x for x,y,z in self.points)-min(x for x,y,z in self.points),1.0)

    def test_gasket_stays_below_inner_polycarbonate(self):
        # Each modeled tube is centered 11.5 mm beneath the deck with a
        # 1.9mm circular radius; the existing 3.6mm lens's lower face is
        # 7.6mm beneath the deck perimeter. Expected air gap >= 2.0mm.
        for side in (-1,1):
            cols=self.cols[side]
            for u in (cols[0],cols[-1]):
                for z in self.stations:
                    center=on_deck(R9,u,z,-.0115)
                    seal_y=max(v[1] for v in self.points
                               if abs(v[0]-center[0])<.0026
                               and abs(v[2]-center[2])<.0026)
                    lens_inner_y=on_deck(R9,u,z,-.0076)[1]
                    self.assertGreater(lens_inner_y-seal_y,.0004,
                        "Rubber projects into the bonded optic lens")

    def test_both_recessed_retention_points_have_metal_hardware(self):
        self.assertGreater(len(self.alloy),50)
        for side in (-1,1):
            cols=self.cols[side]
            for z in (HEAD_Z[0]+.094,HEAD_Z[1]-.094):
                for u,direction in ((cols[0],1),(cols[-1],-1)):
                    expected=on_deck(R9,u+direction*.018,z,-.018)
                    self.assertLess(min(dist(v,expected) for v in self.alloy),.0075,
                        "Missing physical inset retainer fastener")

    def test_generated_source_manifest_matches_checked_in_glb(self):
        for name in ("cinder_r9.gltf","cinder_r9.bin"):
            digest=sha256((DIR/name).read_bytes()).hexdigest()
            self.assertEqual(digest,self.source["sha256"][name])


if __name__=="__main__":
    unittest.main()
