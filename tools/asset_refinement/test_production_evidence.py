import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from production_evidence import checked, manifest


class EvidenceTests(unittest.TestCase):
    def test_manifest_and_corruption(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            data = b"candidate mesh"
            (root / "mesh.glb").write_bytes(data)
            digest = hashlib.sha256(data).hexdigest()
            (root / "SOURCE.json").write_text(json.dumps({"files": {"mesh.glb": {"sha256": digest}}}))
            row = manifest(root, "SOURCE.json", "files")
            self.assertEqual(row["files"][0]["bytes"], len(data))
            self.assertEqual(row["files"][0]["sha256"], digest)
            (root / "mesh.glb").write_bytes(b"corrupted")
            with self.assertRaises(ValueError):
                manifest(root, "SOURCE.json", "files")

    def test_reject_escape(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for name in ("../outside", "/absolute"):
                with self.assertRaises(ValueError):
                    checked(root, name, "0" * 64)
            target = root / "target"
            target.write_bytes(b"x")
            (root / "alias").symlink_to(target)
            with self.assertRaises(ValueError):
                checked(root, "alias", hashlib.sha256(b"x").hexdigest())


if __name__ == "__main__":
    unittest.main()
