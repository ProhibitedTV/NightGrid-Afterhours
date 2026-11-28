import json
from pathlib import Path
import unittest
from materials import PROFILES

ROOT=Path(__file__).resolve().parents[2]
class CoastalCatalog(unittest.TestCase):
    def test_unique_profiled_catalog(self):
        original=json.loads((ROOT/"tools/visual_studio/catalog.json").read_text())
        catalog=json.loads((ROOT/"tools/visual_studio/catalog_coastal_detail.json").read_text())
        ids=[a["id"] for a in catalog["assets"]]
        self.assertEqual(len(ids),len(set(ids)))
        self.assertFalse(set(ids)&{a["id"] for a in original["assets"]})
        self.assertEqual(catalog["batch"],"visual-coastal-detail-001")
        self.assertEqual(catalog["variants"],2)
        self.assertGreaterEqual(len(ids),50)
        for a in catalog["assets"]:
            self.assertTrue(0<len(a["subject"])<=1000)
            if a["kind"]=="material":
                self.assertIn(a["id"].removeprefix("material."),PROFILES)
