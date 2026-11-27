import hashlib
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools/release"))
from check_commercial_clearance import verify

class ClearanceTest(unittest.TestCase):
    def test_fail_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "asset.wav").write_bytes(b"original")
            inv = {"schema": 1, "files": ["asset.wav"]}
            item = {"path": "asset.wav", "sha256": hashlib.sha256(b"original").hexdigest(),
                    "status": "commercial-approved", "category": "original",
                    "source": "creator", "license": "owned", "evidence": "fixture",
                    "reviewer": "fixture", "review_date": "2026-11-27"}
            self.assertEqual(verify(root, inv, {"schema": 1, "entries": [item]}), [])
            for changes in ({"status": "pending"}, {"sha256": "bad"}, {"license": ""},
                            {"category": "generated"}):
                self.assertTrue(verify(root, inv, {"schema": 1, "entries": [dict(item, **changes)]}))
            self.assertTrue(verify(root, inv, {"schema": 1, "entries": []}))
            self.assertTrue(verify(root, {"schema": 1, "files": ["../asset.wav"]},
                                   {"schema": 1, "entries": [item]}))
            (root / "asset.wav").write_bytes(b"changed")
            self.assertTrue(verify(root, inv, {"schema": 1, "entries": [item]}))

if __name__ == "__main__":
    unittest.main()
