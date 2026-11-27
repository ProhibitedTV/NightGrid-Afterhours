import json
import tempfile
import unittest
from pathlib import Path
from verify_creator_delivery import CAST, REQUIRED, REQUIRED_CHECKS, sha256, verify

REV = "a" * 40

class DeliveryTests(unittest.TestCase):
    def fixture(self, path):
        for name in REQUIRED:
            (path / name).write_bytes(b"synthetic payload")
        (path / "BUILD-INFO.txt").write_text("Source commit: " + REV + "\nChannel: development\n")
        (path / "CREATOR-MANIFEST.json").write_text(json.dumps({
            "revision": REV, "godot": "4.7.2.stable", "channel": "development",
            "candidate_hashes": CAST, "checks": sorted(REQUIRED_CHECKS),
        }))
        self.checksums(path)

    def checksums(self, path):
        (path / "SHA256SUMS.txt").write_text("".join(
            f"{sha256(path / name)}  {name}\n" for name in sorted(REQUIRED)))

    def test_delivery_and_corruption(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d)
            self.fixture(path)
            self.assertEqual(verify(path, REV)["native_acceptance"], "not verified")
            (path / "NightGrid-Afterhours.pck").write_bytes(b"corrupted")
            with self.assertRaises(ValueError):
                verify(path, REV)

    def test_mismatched_identity_even_with_matching_checksums(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d)
            self.fixture(path)
            with self.assertRaises(ValueError):
                verify(path, "b" * 40)
            manifest = path / "CREATOR-MANIFEST.json"
            data = json.loads(manifest.read_text())
            data["candidate_hashes"] = {}
            manifest.write_text(json.dumps(data))
            self.checksums(path)
            with self.assertRaises(ValueError):
                verify(path, REV)

    def test_duplicate_and_missing_manifest_entries(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d)
            self.fixture(path)
            sums = path / "SHA256SUMS.txt"
            lines = sums.read_text().splitlines()
            for content in [lines + [lines[0]], lines[1:], lines + ["a" * 64 + "  ../other"]]:
                sums.write_text("\n".join(content) + "\n")
                with self.assertRaises(ValueError):
                    verify(path, REV)

if __name__ == "__main__":
    unittest.main()
