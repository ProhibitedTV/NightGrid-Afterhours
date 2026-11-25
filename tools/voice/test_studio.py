import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
import wave

import studio


class StudioTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.spec = studio.read_manifest()["synaxis.jetson.blinds"]
        self.settings = {"model": studio.MODEL, "revision": "a"*40,
                         "reference": "original synthetic voice design"}
        self.folder = self.root / studio.key({"spec": self.spec, "settings": self.settings})
        self.folder.mkdir()
        self.wav = self.folder / "take.wav"
        self.make_wave(self.wav)
        self.record = {"spec": self.spec, "settings": self.settings,
                       "sha256": studio.digest(self.wav), "stats": studio.inspect_pcm(self.wav)}
        studio.write_json(self.folder / "take.json", self.record)

    def tearDown(self):
        self.tmp.cleanup()

    @staticmethod
    def make_wave(path, amplitude=1000, rate=48000):
        with wave.open(str(path), "wb") as f:
            f.setparams((1, 2, rate, 0, "NONE", "not compressed"))
            f.writeframes(struct.pack("<hh", amplitude, -amplitude) * (rate // 2))

    def approve(self):
        studio.write_json(self.folder / "review.json", {
            "take_sha256": self.record["sha256"],
            "record_sha256": studio.digest(self.folder / "take.json"),
            "reviewer": "fixture", "notes": "test fixture only",
            "license_and_reference_checked": True})

    def test_manifest(self):
        specs = studio.read_manifest()
        self.assertEqual(len(specs), 6)
        self.assertEqual(specs["synaxis.lin.call"]["line"]["language"], "Chinese")

    def test_duplicate_and_unsafe_ids(self):
        data = json.loads(studio.MANIFEST.read_text(encoding="utf-8"))
        path = self.root / "manifest.json"
        data["lines"].append(data["lines"][0].copy())
        studio.write_json(path, data)
        with self.assertRaises(ValueError):
            studio.read_manifest(path)
        data["lines"][-1]["id"] = "../escape"
        studio.write_json(path, data)
        with self.assertRaises(ValueError):
            studio.read_manifest(path)

    def test_verified_approved_take(self):
        self.assertEqual(studio.verify(self.folder, self.spec), self.record)
        self.approve()
        self.assertEqual(studio.verify(self.folder, self.spec, True), self.record)

    def test_tampered_audio(self):
        self.make_wave(self.wav, amplitude=999)
        with self.assertRaises(ValueError):
            studio.verify(self.folder, self.spec)

    def test_stale_script(self):
        changed = json.loads(json.dumps(self.spec))
        changed["line"]["text"] += " Changed."
        with self.assertRaises(ValueError):
            studio.verify(self.folder, changed)

    def test_stale_review(self):
        self.approve()
        self.record["extra"] = "changed metadata"
        studio.write_json(self.folder / "take.json", self.record)
        with self.assertRaises(ValueError):
            studio.verify(self.folder, self.spec, True)

    def test_unreviewed(self):
        with self.assertRaises(FileNotFoundError):
            studio.verify(self.folder, self.spec, True)

    def test_silent_or_wrong_rate(self):
        self.make_wave(self.wav, amplitude=0)
        with self.assertRaises(ValueError):
            studio.inspect_pcm(self.wav)
        self.make_wave(self.wav, rate=24000)
        with self.assertRaises(ValueError):
            studio.inspect_pcm(self.wav)

    def test_master(self):
        import shutil
        if not shutil.which("ffmpeg"):
            self.skipTest("ffmpeg not installed")
        raw = self.root / "raw.wav"
        self.make_wave(raw, amplitude=20000, rate=24000)
        stats = studio.master(raw, self.wav, "ffmpeg")
        self.assertEqual(stats["frames"], 48000)
        self.assertLessEqual(stats["peak"], 23200)
        self.assertGreater(stats["rms"], 20)


if __name__ == "__main__":
    unittest.main()
