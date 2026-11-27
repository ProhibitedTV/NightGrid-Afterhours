import hashlib
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import check_title_gallery as gallery


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


class TitleGalleryTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.sha = "a" * 40
        self.record = dict(source_revision=self.sha, renderer="forward_plus",
                           driver="vulkan", volumetric_fog=True, engine="4.7.2",
                           adapter="NVIDIA GeForce RTX 3060", capture_only_low_radiance=False,
                           shots=[])
        for index, (name, (hour, phase)) in enumerate(gallery.EXPECTED.items()):
            # Synthetic verifier fixture only; never used as published game art.
            import random
            rng = random.Random(index)
            pixels = b"".join(b"\x00" + rng.randbytes(1920) for _ in range(1080))
            raw = (bytes.fromhex("89504e470d0a1a0a") +
                   chunk(b"IHDR", struct.pack(">IIBBBBB", 1920, 1080, 8, 0, 0, 0, 0)) +
                   chunk(b"IDAT", zlib.compress(pixels)) + chunk(b"IEND", b""))
            (self.root / name).write_bytes(raw)
            self.record["shots"].append(dict(file=name, hour=hour, fault_phase=phase,
                                             width=1920, height=1080, bytes=len(raw),
                                             sha256=hashlib.sha256(raw).hexdigest()))
        self.save()

    def save(self):
        (self.root / "capture.json").write_text(json.dumps(self.record), encoding="utf-8")

    def test_native_and_wrong_revision(self):
        self.assertEqual(gallery.verify(self.root, self.sha, True)["images"], 4)
        with self.assertRaisesRegex(ValueError, "revision mismatch"):
            gallery.verify(self.root, "b" * 40)

    def test_reduced_radiance_and_state_mismatch(self):
        self.record["capture_only_low_radiance"] = True
        self.save()
        with self.assertRaisesRegex(ValueError, "full sky radiance"):
            gallery.verify(self.root, self.sha, True)
        self.record["shots"][0]["hour"] = 12
        self.save()
        with self.assertRaisesRegex(ValueError, "Wrong shot state"):
            gallery.verify(self.root, self.sha)

    def test_changed_image(self):
        path = self.root / self.record["shots"][0]["file"]
        raw = bytearray(path.read_bytes())
        raw[100] ^= 1
        path.write_bytes(raw)
        with self.assertRaisesRegex(ValueError, "changed PNG"):
            gallery.verify(self.root, self.sha)


if __name__ == "__main__":
    unittest.main()
