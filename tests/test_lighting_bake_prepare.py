import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from tools.lighting.automation.prepare_pilot import PROFILES, prepare


class LightingBakeStageTests(unittest.TestCase):
    def test_profiles_stage_real_sources_without_a_previous_atlas(self):
        with tempfile.TemporaryDirectory() as scratch:
            for profile, (scene, node, receivers, probes) in PROFILES.items():
                with self.subTest(profile=profile):
                    output = Path(scratch) / profile
                    prepare(output, profile)
                    metadata = json.loads((output / "inputs.json").read_text("utf-8"))
                    self.assertEqual(metadata["scene"], scene)
                    self.assertEqual(metadata["gi_node"], node)
                    self.assertEqual(metadata["receivers"], receivers)
                    self.assertEqual(metadata["probes"], probes)
                    source = (output / scene).read_bytes()
                    self.assertNotIn(b"LightmapGIData", source)
                    self.assertNotIn(b"light_data =", source)
                    self.assertEqual(hashlib.sha256(source).hexdigest(), metadata["unbaked_scene_sha256"])
                    self.assertFalse(list(output.rglob("*.lmbake")))
                    self.assertFalse(list(output.rglob("*.exr")))
                    for relative, digest in metadata["dependencies"].items():
                        self.assertEqual(hashlib.sha256((output / relative).read_bytes()).hexdigest(), digest)
                    with self.assertRaises(ValueError):
                        prepare(output, profile)
