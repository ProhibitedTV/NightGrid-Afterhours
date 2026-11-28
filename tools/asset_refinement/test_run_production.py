import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import run_production as production
from render_inventory import block_mips


class ProductionTests(unittest.TestCase):
    def test_plan(self):
        plan = production.build_plan("render-001", "/native/godot.exe", "full")
        self.assertEqual(tuple(plan), production.STAGES)
        self.assertIn("--profile", plan["music"][0])
        self.assertEqual(plan["visual"][1]["ANUBIS_BAKE_AO"], "1")
        self.assertEqual(plan["visual"][1]["ANUBIS_PROJECT_NORMALS"], "1")
        self.assertIn("synaxis-ground", plan["synaxis-ground"][0])
        self.assertIn("reception", plan["reception"][0])
        self.assertIn("1024",plan["environments"][0])
        self.assertIn("environment_candidates.py",plan["environments"][0][1])
        self.assertIn("postmusic-render-001", plan["characters"][0])

    def test_music_hashes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            rows = []
            for i in range(48):
                name = f"{i}.wav"
                raw = str(i).encode()
                (root / name).write_bytes(raw)
                rows.append({"file": name, "sha256": hashlib.sha256(raw).hexdigest()})
            (root / "manifest.json").write_text(json.dumps({"candidates": rows}))
            self.assertTrue(production.music_complete(root))
            (root / "1.wav").write_bytes(b"corrupt")
            self.assertFalse(production.music_complete(root))

    def test_mips(self):
        self.assertEqual(block_mips(4,4,8),24)
        self.assertEqual(block_mips(1,1,16),16)
        self.assertEqual(block_mips(5,3,8),32)


if __name__ == "__main__":
    unittest.main()
