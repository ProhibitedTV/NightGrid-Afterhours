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
                self.assertGreater(abs(x), .02)

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
