import hashlib
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import build_creator_playtest as build

class CreatorBuildTests(unittest.TestCase):
    def test_stamp_only_exact_development_source(self):
        original = b'const CHANNEL = "development"\r\nconst REVISION = "development"\r\n'
        expected = original.replace(build.MARKER, b'const REVISION = "' + b"a" * 40 + b'"')
        self.assertEqual(build.stamp(original, "a" * 40), expected)
        for invalid, sha in [(original, "short"), (original + build.MARKER, "a" * 40),
                             (original.replace(b'CHANNEL = "development"', b'CHANNEL = "release"'), "a" * 40)]:
            with self.assertRaises(RuntimeError):
                build.stamp(invalid, sha)

    def test_fresh_output_and_hash(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with patch.object(build, "ROOT", root / "checkout"):
                with self.assertRaises(RuntimeError):
                    build.fresh_output(root / "checkout" / "dist")
                out = build.fresh_output(root / "candidate")
                with self.assertRaises(FileExistsError):
                    build.fresh_output(out)
                file = out / "payload"
                file.write_bytes(b"candidate")
                self.assertEqual(build.sha256(file), hashlib.sha256(b"candidate").hexdigest())

    def test_dirty_source_rejected(self):
        with patch.object(build, "git", return_value=" M scripts/world.gd"):
            with self.assertRaises(RuntimeError):
                build.require_clean()

if __name__ == "__main__":
    unittest.main()
