#!/usr/bin/env python3
"""Cinder R9 source-authored static brake-caliper geometry regression gate.

The rotating wheel mesh and stationary brake hardware must be independent
nodes; Godot's live smoke test verifies their parent/rotation semantics.
"""
from __future__ import annotations

from hashlib import sha256
import json
from math import hypot
from pathlib import Path
import struct
import unittest

DIR = Path(__file__).resolve().parents[1] / "assets/models/nightgrid/road_cars"


def positions(doc: dict, buffer: bytes, accessor_id: int):
    accessor = doc["accessors"][accessor_id]
    assert accessor["componentType"] == 5126 and accessor["type"] == "VEC3"
    view = doc["bufferViews"][accessor["bufferView"]]
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    stride = view.get("byteStride", 12)
    assert stride >= 12
    assert offset + (accessor["count"]-1)*stride + 12 <= len(buffer)
    return [struct.unpack_from("<3f", buffer, offset + index*stride)
            for index in range(accessor["count"])]

def indices(doc: dict, buffer: bytes, accessor_id: int):
    accessor = doc["accessors"][accessor_id]
    assert accessor["componentType"] == 5125 and accessor["type"] == "SCALAR"
    view = doc["bufferViews"][accessor["bufferView"]]
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    stride = view.get("byteStride", 4)
    assert stride >= 4
    assert offset + (accessor["count"]-1)*stride + 4 <= len(buffer)
    return [struct.unpack_from("<I", buffer, offset + i*stride)[0]
            for i in range(accessor["count"])]


class CinderStationaryBrakeHardware(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.doc = json.loads((DIR / "wheel.gltf").read_text(encoding="utf-8"))
        cls.raw = (DIR / "wheel.bin").read_bytes()
        cls.manifest = json.loads((DIR / "source.json").read_text(encoding="utf-8"))
        cls.meshes = {m["name"]: m for m in cls.doc["meshes"]}
        cls.mat = {index:m["name"] for index,m in enumerate(cls.doc["materials"])}

    def _vertices(self, mesh):
        return [v for part in mesh["primitives"]
                for v in positions(self.doc, self.raw, part["attributes"]["POSITION"])]

    def test_separate_nodes_for_spinning_rim_and_both_fixed_calipers(self):
        names = {node["name"] for node in self.doc["nodes"]}
        self.assertEqual(names, {"Wheel", "BrakeCaliperL", "BrakeCaliperR"})
        self.assertEqual(set(self.meshes), names)

    def test_caliper_color_and_full_assembly(self):
        for side in ("L", "R"):
            mesh = self.meshes["BrakeCaliper"+side]
            materials = {self.mat[p["material"]] for p in mesh["primitives"]}
            self.assertIn("BrakeCaliper", materials)
            self.assertIn("MachinedAlloy", materials)
            self.assertIn("Graphite", materials)
            triangles = sum(
                self.doc["accessors"][p["indices"]]["count"]//3
                for p in mesh["primitives"]
            )
            self.assertGreaterEqual(triangles, 150)

    def test_caliper_envelope_fits_inside_rim(self):
        for side in ("L", "R"):
            points = self._vertices(self.meshes["BrakeCaliper"+side])
            self.assertGreater(len(points), 100)
            for x,y,z in points:
                self.assertLess(hypot(y,z), .238,
                                "Stationary brake caliper clips wheel rim")
                self.assertGreater(hypot(y,z), .15)
                self.assertLess(abs(x), .13,
                                "Caliper clips the front face of wheel spokes")

    def test_rotor_slot_is_genuinely_empty_below_disc_outer_radius(self):
        # The rotating titanium disc is between 15 and 41 mm on the wheel's
        # corresponding side. The previous 'caliper' was a solid wedge
        # occupying the exact same physical space as the brake disc.
        for side, sign in (("L",-1),("R",1)):
            mesh=self.meshes["BrakeCaliper"+side]
            jaws=[]
            bridge=[]
            for primitive in mesh["primitives"]:
                material=self.mat[primitive["material"]]
                if material not in ("BrakeCaliper","Graphite"):
                    continue
                for x,y,z in positions(self.doc,self.raw,
                                      primitive["attributes"]["POSITION"]):
                    signed_x=sign*x
                    radius=hypot(y,z)
                    if .170<=radius<=.204:
                        self.assertFalse(.0145<=signed_x<=.0415,
                            "Rotor and stationary casting occupy the same volume")
                        jaws.append((signed_x,radius))
                    elif radius>=.215:
                        bridge.append((signed_x,radius))
            self.assertGreater(len(jaws),100)
            self.assertTrue(any(x<.01 for x,_ in jaws),
                            "Missing inner caliper half")
            self.assertTrue(any(x>.06 for x,_ in jaws),
                            "Missing outer caliper half")
            # The bridge is made of triangles connecting the two axial
            # casting halves; individual vertices lie on the two end faces.
            # Its triangle centroids must cross the open channel only at
            # radii beyond the spinning 205 mm brake disc.
            connected=False
            for primitive in mesh["primitives"]:
                if self.mat[primitive["material"]] != "BrakeCaliper":
                    continue
                vertex=positions(self.doc,self.raw,
                                 primitive["attributes"]["POSITION"])
                index=indices(self.doc,self.raw,primitive["indices"])
                for j in range(0,len(index),3):
                    coords=[vertex[k] for k in index[j:j+3]]
                    axial=sum(sign*p[0] for p in coords)/3
                    radius=hypot(sum(p[1] for p in coords)/3,
                                 sum(p[2] for p in coords)/3)
                    if .02<axial<.045 and radius>=.213:
                        connected=True
            self.assertTrue(connected, "Missing radial bridge across the caliper jaws")

    def test_friction_pads_face_both_rotor_sides(self):
        for side,sign in (("L",-1),("R",1)):
            dark=next(p for p in self.meshes["BrakeCaliper"+side]["primitives"]
                      if self.mat[p["material"]]=="Graphite")
            vertices=positions(self.doc,self.raw,dark["attributes"]["POSITION"])
            # The pads are defined by their inner/outer outline vertices
            # at 171 and 200 mm; vertex samples are *not* on the centerline.
            axial=[sign*x for x,y,z in vertices if .170<hypot(y,z)<.201]
            self.assertTrue(any(.0065<=x<=.0125 for x in axial),
                            "No pad behind rotor's inner face")
            self.assertTrue(any(.0465<=x<=.0615 for x in axial),
                            "No pad ahead of rotor's outer face")


    def test_mirrored_calipers_not_unintentional_repeated_wheels(self):
        left = self._vertices(self.meshes["BrakeCaliperL"])
        right = self._vertices(self.meshes["BrakeCaliperR"])
        self.assertEqual(len(left), len(right))
        self.assertEqual(
            sorted((round(-x,5),round(y,5),round(z,5)) for x,y,z in left),
            sorted((round(x,5),round(y,5),round(z,5)) for x,y,z in right))

    def test_regenerated_provenance_and_counts(self):
        for filename in ("wheel.gltf","wheel.bin"):
            actual = sha256((DIR/filename).read_bytes()).hexdigest()
            self.assertEqual(actual, self.manifest["sha256"][filename])
        for name in ("BrakeCaliperL","BrakeCaliperR","Wheel"):
            triangles = sum(
                self.doc["accessors"][p["indices"]]["count"]//3
                for p in self.meshes[name]["primitives"]
            )
            self.assertEqual(self.manifest["triangles"][name], triangles)


if __name__ == "__main__":
    unittest.main()
