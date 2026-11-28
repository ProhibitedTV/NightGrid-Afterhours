import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from production_evidence import checked, manifest, visual_evidence


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

    def test_visual_output_integrity(self):
        with tempfile.TemporaryDirectory() as temp:
            nas=Path(temp)
            sig="a"*64
            key="fixture.v1"
            def version(root,filename):
                folder=root/key/sig
                folder.mkdir(parents=True)
                payload=folder/"derivative.bin"
                payload.write_bytes(b"verified bytes")
                meta=folder/filename
                meta.write_text(json.dumps({"candidate":key,"signature":sig,"status":"unapproved",
                    "outputs":{"derivative.bin":{"sha256":hashlib.sha256(payload.read_bytes()).hexdigest()}}}))
                return hashlib.sha256(meta.read_bytes()).hexdigest(),payload
            ref=nas/"Visual/refined-001"
            mat=nas/"Visual/Materials/material-001"
            a,mesh=version(ref,"refinement.json")
            b,texture=version(mat,"material.json")
            (ref/"review-1024.json").write_text(json.dumps({"schema":1,"status":"unapproved","bake_size":1024,
                "rows":[{"candidate":key,"status":"review-required","versions":[{"signature":sig,"manifest_sha256":a}]}]}))
            (mat/"review-1024.json").write_text(json.dumps({"status":"unapproved","size":1024,"partial":False,
                "rows":[{"candidate":key,"status":"review-required","signature":sig,"manifest_sha256":b}]}))
            self.assertEqual(len(visual_evidence(nas,"001")),2)
            texture.write_bytes(b"corrupted")
            with self.assertRaises(ValueError):
                visual_evidence(nas,"001")


if __name__ == "__main__":
    unittest.main()
