import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import budgets
import review_and_budgets as combined
from review_queue import build_report


class SharedReviewScanTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.review = self.root / "review-128.json"
        self.budget = self.root / "budgets-128.json"
        outputs = {}
        for i in range(3):
            outputs[f"lod{i}.glb"] = {"triangles": 100 // (i+1)}
            outputs[f"lod{i}-basecolor.png"] = {"size": [128, 128]}
        self.rows = [{"candidate": "prop", "status": "review-required",
                      "versions": [{"signature": "a"*64, "manifest_sha256": "b"*64,
                                    "outputs": outputs}]}]

    def run_combined(self):
        return combined.run(self.root, self.root, 128, self.review, self.budget)

    def test_same_scan_and_report_values(self):
        with patch.object(combined, "scan", return_value=self.rows) as scan:
            self.assertEqual(self.run_combined(), 0)
            scan.assert_called_once_with(self.root.resolve(), self.root.resolve(), 128)
        with patch.object(budgets, "scan", return_value=self.rows):
            expected_budget = budgets.report(self.root, self.root, 128)
        self.assertEqual(json.loads(self.review.read_text()), build_report(self.rows, 128))
        self.assertEqual(json.loads(self.budget.read_text()), expected_budget)
        self.assertEqual(len(expected_budget["rows"]), 1)
        self.assertGreater(expected_budget["rows"][0]["all_lods_texture_bytes"], 0)

    def test_invalid_source_does_not_publish_budget(self):
        self.budget.write_text("previous budget")
        with patch.object(combined, "scan", return_value=[{"candidate": "bad", "status": "invalid-source"}]):
            self.assertEqual(self.run_combined(), 1)
        self.assertEqual(self.budget.read_text(), "previous budget")
        self.assertEqual(json.loads(self.review.read_text())["rows"][0]["status"], "invalid-source")

    def test_reject_same_output_before_scan(self):
        with patch.object(combined, "scan") as scan:
            with self.assertRaises(ValueError):
                combined.run(self.root, self.root, 128, self.review, self.review)
            scan.assert_not_called()
