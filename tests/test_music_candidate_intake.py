#!/usr/bin/env python3
"""Small dependency-free fixtures for offline music intake."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
import wave

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools/audio"))
import music_candidate_intake as intake


class MusicIntakeTest(unittest.TestCase):
    def test_valid_and_rejects_stale_unsafe_or_unreviewed(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            target = root / "original.wav"
            with wave.open(str(target), "wb") as sound:
                sound.setnchannels(2)
                sound.setsampwidth(2)
                sound.setframerate(48000)
                sound.writeframes(b"\x00\x00" * 2 * 48000)
            original = target.read_bytes()
            item = {"id": "synaxis.lobby.original-01", "file": "original.wav",
                    "sha256": hashlib.sha256(original).hexdigest(),
                    "model": "ace-step", "checkpoint": "local-checkpoint-revision",
                    "scene": "Synaxis vestibule", "direction": "oppressive corporate ambient",
                    "rights_notes": "Not reviewed; private candidate only", "reviewed": False}
            report = intake.validate({"schema": 1, "candidates": [item]}, root)
            self.assertEqual(len(report["verified_candidates"]), 1)
            self.assertEqual(target.read_bytes(), original)
            for edit in ({"sha256": "0" * 64}, {"file": "../original.wav"},
                         {"file": "/tmp/original.wav"}, {"model": "unknown"},
                         {"reviewed": True}, {"rights_notes": ""}):
                changed = dict(item, **edit)
                with self.assertRaises(ValueError):
                    intake.validate({"schema": 1, "candidates": [changed]}, root)
            with self.assertRaises(ValueError):
                intake.validate({"schema": 1, "candidates": [item, item]}, root)


if __name__ == "__main__":
    unittest.main()
