"""Validate separated steering rim/spokes against the original source."""
import json
import sys
import unittest
from pathlib import Path
from math import hypot

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/art"))
from author_cinder_r9 import R9, Mesh, MATERIALS, LEATHER, ALLOY, compartment, steering_pivot

class SteeringWheel(unittest.TestCase):
    def test_source_separation_conserves_geometry(self):
        legacy = [Mesh() for _ in MATERIALS]
        fixed = [Mesh() for _ in MATERIALS]
        wheel = [Mesh() for _ in MATERIALS]
        compartment(R9, legacy)
        compartment(R9, fixed, wheel)
        for before, after, rotating in zip(legacy, fixed, wheel):
            self.assertEqual(len(before.indices), len(after.indices) + len(rotating.indices))
        self.assertGreater(len(wheel[LEATHER].indices), 100)
        self.assertGreater(len(wheel[ALLOY].indices), 100)
        self.assertGreater(len(fixed[ALLOY].indices), 0)
        pivot = steering_pivot(R9)
        for channel in wheel:
            for x,y,z in channel.positions:
                self.assertLess(hypot(x-pivot[0], y-pivot[1]), .20)
                self.assertLess(abs(z-pivot[2]), .06)

    def test_exported_pivot(self):
        directory = ROOT / "assets/models/nightgrid/road_cars"
        doc = json.loads((directory / "cinder_r9.gltf").read_text())
        node = next(n for n in doc["nodes"] if n["name"] == "SteeringWheel")
        for actual, expected in zip(node["translation"], steering_pivot(R9)):
            self.assertAlmostEqual(actual, expected, places=6)
        self.assertEqual(doc["meshes"][node["mesh"]]["name"], "SteeringWheel")
        manifest = json.loads((directory / "source.json").read_text())
        self.assertGreater(manifest["triangles"]["SteeringWheel"], 100)

if __name__ == "__main__":
    unittest.main()
