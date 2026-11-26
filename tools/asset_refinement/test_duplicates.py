import json
from pathlib import Path
import tempfile
import unittest
from PIL import Image
from duplicates import report
from refine import sha


class DuplicateTests(unittest.TestCase):
    def test_exact_and_tamper(self):
        with tempfile.TemporaryDirectory() as tmp:
            raw=Path(tmp)
            for key,kind in [("chair.v1","prop"),("chair.v2","prop"),("brick.v1","material")]:
                folder=raw/"candidates"/key
                folder.mkdir(parents=True)
                Image.new("RGB",(32,32),(60,70,80)).save(folder/"concept.png")
                (folder/"image.json").write_text(json.dumps({"job":{"key":key,"kind":kind},"sha256":sha(folder/"concept.png")}))
            data=report(raw)
            self.assertEqual(data["scanned"],3)
            self.assertEqual(len(data["pairs"]),1)
            self.assertTrue(data["pairs"][0]["exact"])
            (raw/"candidates"/"chair.v2"/"concept.png").write_bytes(b"changed")
            self.assertEqual(len(report(raw)["invalid"]),1)
            self.assertFalse(report(raw)["pairs"])
