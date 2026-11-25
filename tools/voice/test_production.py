import json
from pathlib import Path
import shutil
import tempfile
import unittest

import production
import studio
import test_studio


class ProductionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.specs = studio.read_manifest()
        self.spec = self.specs["synaxis.jetson.blinds"]
        settings = {"model": studio.MODEL, "revision": "a"*40,
                    "reference": "original synthetic voice design"}
        self.audition = self.root / studio.key({"spec": self.spec, "settings": settings})
        self.audition.mkdir()
        wav = self.audition / "take.wav"
        test_studio.StudioTests.make_wave(wav)
        rec = {"spec": self.spec, "settings": settings, "sha256": studio.digest(wav),
               "stats": studio.inspect_pcm(wav)}
        studio.write_json(self.audition / "take.json", rec)
        self.review(self.audition)
        self.castdir = self.root / "cast"
        self.cast = production.lock_cast(self.spec, self.audition, self.castdir)
        self.library = self.root / "library"

    def tearDown(self):
        self.tmp.cleanup()

    @staticmethod
    def review(folder):
        rec = production.load(folder / "take.json")
        studio.write_json(folder / "review.json", {
            "take_sha256": rec["sha256"], "record_sha256": studio.digest(folder / "take.json"),
            "reviewer": "fixture", "notes": "test only", "license_and_reference_checked": True})

    def make_take(self, spec=None, cast=None):
        spec = spec or self.spec
        cast = cast or self.cast
        settings = {"model": production.BASE, "revision": "b"*40, "cast_sha256": studio.key(cast)}
        fingerprint = studio.key({"spec": spec, "settings": settings})
        folder = self.root / fingerprint
        folder.mkdir()
        wav = folder / "take.wav"
        test_studio.StudioTests.make_wave(wav)
        studio.write_json(folder / "take.json", {"spec": spec, "settings": settings,
                          "cast": cast, "fingerprint": fingerprint,
                          "sha256": studio.digest(wav), "stats": studio.inspect_pcm(wav)})
        return folder

    def test_cast_read_and_no_overwrite(self):
        self.assertEqual(production.read_cast(self.castdir, "jetson", self.spec["voice"]), self.cast)
        with self.assertRaises(FileExistsError):
            production.lock_cast(self.spec, self.audition, self.castdir)

    def test_ref_tampering(self):
        test_studio.StudioTests.make_wave(self.castdir / "reference.wav", amplitude=999)
        with self.assertRaises(ValueError):
            production.read_cast(self.castdir, "jetson", self.spec["voice"])

    def test_wrong_speaker(self):
        with self.assertRaises(ValueError):
            production.read_cast(self.castdir, "lin", self.spec["voice"])

    def test_unapproved_production_rejected(self):
        folder = self.make_take()
        dest = self.library / self.spec["line"]["id"]
        with self.assertRaises(FileNotFoundError):
            production.publish(folder, dest, self.spec, self.cast)
        self.assertFalse(dest.exists())

    def test_publish_and_verify(self):
        folder = self.make_take()
        self.review(folder)
        dest = self.library / self.spec["line"]["id"]
        production.publish(folder, dest, self.spec, self.cast)
        self.assertEqual(production.verify_library(self.specs, self.library), 1)
        with self.assertRaises(FileExistsError):
            production.publish(folder, dest, self.spec, self.cast)
        test_studio.StudioTests.make_wave(dest / "take.wav", amplitude=1200)
        with self.assertRaises(ValueError):
            production.verify_library(self.specs, self.library)

    def test_mixed_cast_rejected(self):
        first = self.make_take()
        self.review(first)
        production.publish(first, self.library / self.spec["line"]["id"], self.spec, self.cast)
        second_spec = json.loads(json.dumps(self.spec))
        second_spec["line"]["id"] = "synaxis.jetson.second"
        second_cast = json.loads(json.dumps(self.cast))
        second_cast["review"]["notes"] = "different cast record"
        second = self.make_take(second_spec, second_cast)
        self.review(second)
        production.publish(second, self.library / second_spec["line"]["id"], second_spec, second_cast)
        with self.assertRaises(ValueError):
            production.verify_library(dict(self.specs, **{second_spec["line"]["id"]: second_spec}), self.library)

    def test_no_partial_destination(self):
        dest = self.root / "broken"
        def fail(stage):
            (stage / "incomplete").write_text("partial")
            raise RuntimeError("interrupted")
        with self.assertRaises(RuntimeError):
            production.atomic_directory(dest, fail)
        self.assertFalse(dest.exists())


if __name__ == "__main__":
    unittest.main()
