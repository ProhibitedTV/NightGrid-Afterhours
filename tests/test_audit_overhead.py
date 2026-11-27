"""Synthetic regression for the read-only overhead inventory."""
import sys
import tempfile
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from audit_overhead import inventory

class InventoryTest(unittest.TestCase):
    def test_candidates(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("assets", "scripts"):
                (root / name).mkdir()
            for name in ("a.bin", "b.bin"):
                (root / "assets" / name).write_bytes(b"same")
            body = 'func helper():\n\tvar a = 1\n\tvar b = 2\n\tvar c = 3\n\tvar d = 4\n\treturn a+b+c+d\n'
            (root / "scripts/a.gd").write_text(body + 'func _process(delta):\n\tvar x = load("res://assets/a.bin")\n\tadd_child(x)\n', encoding="utf-8")
            (root / "scripts/b.gd").write_text(body, encoding="utf-8")
            report = inventory(root)
            self.assertEqual(len(report["identical_asset_candidates"]), 1)
            self.assertEqual(len(report["identical_function_body_candidates"]), 1)
            self.assertEqual(report["frame_callback_cost_candidates"][0]["category"], "resource load")
            self.assertIn("node_attach", report["lifecycle_review_candidates"][0]["markers"])
            refs = {x["path"]: x["literal_referrers"] for x in report["asset_reference_candidates"]}
            self.assertEqual(refs["assets/a.bin"], ["scripts/a.gd"])
            self.assertEqual(refs["assets/b.bin"], [])
            self.assertEqual((root / "assets/b.bin").read_bytes(), b"same")

if __name__ == "__main__":
    unittest.main()
