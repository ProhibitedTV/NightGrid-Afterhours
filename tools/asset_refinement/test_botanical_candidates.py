import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import botanical_candidates as b


class BotanicalTests(unittest.TestCase):
    def test_all_species_and_tiers(self):
        for species in b.SPECIES:
            near, a = b.encode(species, 0)
            far, c = b.encode(species, 1)
            self.assertEqual(near, b.encode(species, 0)[0])
            self.assertLess(c["triangles"], a["triangles"])
            self.assertLessEqual(a["triangles"], b.BUDGETS[0])
            self.assertLessEqual(c["triangles"], b.BUDGETS[1])
            self.assertEqual(near[:4], b"glTF")
            self.assertAlmostEqual(a["bounds_m"][0][1], 0, delta=.3)

    def test_resume_and_tamper(self):
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp)/"botanical"
            b.produce(out)
            b.produce(out)
            m=json.loads((out/"SOURCE.json").read_text())
            self.assertEqual(len(m["files"]), 14)
            for name, record in m["files"].items():
                self.assertEqual(hashlib.sha256((out/name).read_bytes()).hexdigest(), record["sha256"])
            (out/"date_palm_lod0.glb").write_bytes(b"broken")
            with self.assertRaises(ValueError):
                b.produce(out)


if __name__=="__main__":
    unittest.main()
