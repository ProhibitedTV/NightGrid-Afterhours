#!/usr/bin/env python3
"""Regression gate for genuine original Cinder R9 tire tread geometry.

Checks the *generated glTF* and its associated binary rather than trusting a
source-code constant. This test does not prove tire grip, wet handling, or
actual display quality; it protects the modeled tread from accidental loss.
"""
from __future__ import annotations

from collections import defaultdict
from hashlib import sha256
from math import atan2, hypot
from pathlib import Path
import json
import struct
import unittest

ASSETS = Path(__file__).resolve().parents[1] / "assets/models/nightgrid/road_cars"


def floats3(doc, payload, index):
    accessor = doc["accessors"][index]
    if accessor["componentType"] != 5126 or accessor["type"] != "VEC3":
        raise AssertionError("Expected float32 VEC3 vertex stream")
    view = doc["bufferViews"][accessor["bufferView"]]
    if view["buffer"] != 0:
        raise AssertionError("Unexpected glTF buffer index")
    start = int(view.get("byteOffset", 0)) + int(accessor.get("byteOffset", 0))
    stride = int(view.get("byteStride", 12))
    if stride < 12 or start + (accessor["count"]-1)*stride + 12 > len(payload):
        raise AssertionError("Tire vertex stream is outside the binary")
    return [struct.unpack_from("<3f", payload, start + k*stride)
            for k in range(accessor["count"])]


class CinderTireTread(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.doc = json.loads((ASSETS/"wheel.gltf").read_text(encoding="utf-8"))
        cls.binary = (ASSETS/"wheel.bin").read_bytes()
        cls.source = json.loads((ASSETS/"source.json").read_text(encoding="utf-8"))
        wheel = next(mesh for mesh in cls.doc["meshes"] if mesh["name"] == "Wheel")
        tire_material = next(i for i, material in enumerate(cls.doc["materials"])
                             if material["name"] == "Tire")
        tire = next(p for p in wheel["primitives"] if p["material"] == tire_material)
        cls.vertices = floats3(cls.doc, cls.binary, tire["attributes"]["POSITION"])
        cls.rings = defaultdict(list)
        for x, y, z in cls.vertices:
            cls.rings[round(x, 4)].append((hypot(y, z), atan2(z, y)))

    def test_model_has_dense_original_molded_tread(self):
        # Source facets share equivalent positions/normals through the glTF
        # exporter's vertex deduplication, so the generated stream is about
        # 4,100 vertices rather than one vertex per quad corner.
        self.assertGreater(len(self.vertices), 3500)
        self.assertGreaterEqual(len(self.rings), 28)
        angles = {round(theta, 4) for _, theta in self.rings[-.046]}
        self.assertEqual(len(angles), 96, "Tire lost its 96-sector roundness")

    def test_four_axial_rain_channels_have_measurable_depth(self):
        for left, right in ((-.046,-.042),(-.022,-.018),(.009,.013),(.041,.045)):
            for x in (left, right):
                radii = [r for r, angle in self.rings[x]]
                self.assertGreaterEqual(len(radii),96)
                self.assertTrue(all(.3558 < r < .3566 for r in radii),
                                f"Missing 2.8 mm molded channel at x={x}")

    def test_ground_contact_stays_inside_original_rolling_radius(self):
        points = [(x, r) for x, values in self.rings.items()
                  for r, angle in values]
        self.assertLessEqual(max(r for x, r in points), .3592)
        self.assertGreaterEqual(max(r for x, r in points), .3589)
        self.assertTrue(any(x < -.142 for x, r in points))
        self.assertTrue(any(x > .142 for x, r in points))

    def test_staggered_micro_sipes_are_real_geometric_insets(self):
        for x in (-.026, .004, .037):
            radii = [r for r, angle in self.rings[x]]
            self.assertGreaterEqual(len(radii),96)
            self.assertGreater(max(radii)-min(radii), .00050,
                               f"No angled tread sipes at x={x}")
            self.assertGreater(max(radii), .3589)
            self.assertLess(min(radii), .359)

    def test_exported_wheel_and_manifest_stay_in_sync(self):
        for name in ("wheel.gltf","wheel.bin"):
            digest = sha256((ASSETS/name).read_bytes()).hexdigest()
            self.assertEqual(digest, self.source["sha256"][name])


if __name__=="__main__":
    unittest.main()
