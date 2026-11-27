"""Music QC fixtures: no model, GPU, or real soundtrack required."""
import hashlib
import json
from pathlib import Path
import shutil
import struct
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import wave

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools/audio"))
import music_technical_qc as qc


class MusicQCTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.path = self.root / "fixture.wav"
        with wave.open(str(self.path), "wb") as writer:
            writer.setparams((2, 2, 48000, 0, "NONE", "not compressed"))
            writer.writeframes(struct.pack("<hh", 0, 0) * 48000)
        self.row = dict(id="fixture.take-01", file=self.path.name,
                        sha256=hashlib.sha256(self.path.read_bytes()).hexdigest(),
                        model="ace-step", checkpoint="fixture", scene="fixture",
                        direction="fixture", rights_notes="pending", reviewed=False)
        self.manifest = dict(schema=1, candidates=[self.row])

    def test_measure_original_and_nonfinite(self):
        log = 'silence_duration: 2.5\n' + json.dumps(dict(
            input_i="-inf", input_tp="-inf", input_lra="0.0"))
        with patch.object(qc.subprocess, "run", return_value=SimpleNamespace(stderr=log)) as run:
            metrics = qc.measure(self.path, "ffmpeg")
            self.assertIsNone(metrics["integrated_lufs"])
            self.assertEqual(metrics["silence_longest_seconds"], 2.5)
            self.assertIn("silencedetect", " ".join(run.call_args.args[0]))

    def test_flag_duplicate_and_duration_without_approval(self):
        self.row["requested_duration"] = 42
        self.manifest["candidates"].append(dict(self.row, id="fixture.take-02"))
        metrics = dict(integrated_lufs=-14, true_peak_dbtp=0,
                       silence_longest_seconds=3)
        with patch.object(qc, "measure", return_value=metrics):
            result = qc.review(self.manifest, self.root, "ffmpeg")
        self.assertEqual(result["flagged_count"], 2)
        self.assertEqual(set(result["candidates"][0]["flags"]), {
            "true-peak-at-or-above-full-scale", "extended-silence-listen",
            "duration-outside-requested-tolerance", "byte-identical-candidate"})
        self.assertFalse(self.row["reviewed"])
        self.assertIn("pending", result["candidates"][0]["status"])

    def test_mutated_source_fails(self):
        def mutate(*args):
            self.path.write_bytes(b"changed")
            return {}
        with patch.object(qc, "measure", side_effect=mutate):
            with self.assertRaisesRegex(ValueError, "during measurement"):
                qc.review(self.manifest, self.root, "ffmpeg")

    @unittest.skipUnless(shutil.which("ffmpeg"), "FFmpeg not installed")
    def test_real_ffmpeg_silence(self):
        result = qc.review(self.manifest, self.root, shutil.which("ffmpeg"))
        metrics = result["candidates"][0]["measurements"]
        self.assertIsNone(metrics["integrated_lufs"])
        self.assertAlmostEqual(metrics["silence_total_seconds"], 1, places=2)
        self.assertIn("loudness-unmeasurable", result["candidates"][0]["flags"])


if __name__ == "__main__":
    unittest.main()
