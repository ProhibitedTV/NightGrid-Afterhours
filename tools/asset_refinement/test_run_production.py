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
        self.assertEqual(plan["visual_detail"][1]["ANUBIS_BATCH"],"visual-coastal-detail-001")
        self.assertTrue(plan["visual_detail"][1]["ANUBIS_VISUAL_CATALOG"].endswith("catalog_coastal_detail.json"))
        self.assertIn("review_detail",plan)

    def test_status_and_order(self):
        self.assertLess(production.STAGES.index("district_buildings"),production.STAGES.index("visual"))
        self.assertLess(production.STAGES.index("visual_detail"),production.STAGES.index("evidence"))
        with tempfile.TemporaryDirectory() as tmp:
            run=Path(tmp)/"render-001"
            self.assertEqual(production.status(run)["status"],"not-started")
            self.assertFalse(run.exists())
            run.mkdir()
            entries={n:{"status":"pending"} for n in production.STAGES}
            entries["music"]={"status":"completed"}
            entries["layouts"]={"status":"running","log":"layouts-1.log"}
            (run/"production.json").write_text(json.dumps({"signature":{"stages":production.STAGES,"source":"fixture"},"entries":entries}))
            (run/"PAUSE").touch()
            report=production.status(run)
            self.assertEqual(report["completed"],1)
            self.assertEqual(report["current_stage"],"layouts")
            self.assertEqual(report["current_log"],"layouts-1.log")
            self.assertTrue(report["pause_requested"])

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
