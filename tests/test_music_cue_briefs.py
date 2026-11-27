#!/usr/bin/env python3
"""Offline fixture checks for music cue briefs and local model detection."""
import copy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools/audio"))
import music_cue_briefs as briefs

VALID = {
    "schema": 1, "generation_mode": "offline_candidate_only",
    "cues": [{
        "id": "synaxis.arrival.security-pulse",
        "model_preference": "ace-step",
        "scene": "Synaxis vestibule",
        "duration_target_seconds": 45,
        "direction": "Original instrumental score",
        "role": "non-diegetic cinematic underscore",
        "start_event": "arrival_intro",
        "stop_event": "arrival_gate",
        "mix_notes": "Under dialogue"
    }]
}

class MusicBriefsTest(unittest.TestCase):
    def test_valid_catalog(self):
        self.assertEqual(len(briefs.validate_briefs(VALID)), 1)
        catalog = Path(briefs.__file__).with_name("anubis_music_cue_briefs.json")
        import json
        self.assertEqual(len(briefs.validate_briefs(json.loads(catalog.read_text()))), 4)

    def test_rejects_duplicate_and_malformed(self):
        bad = copy.deepcopy(VALID)
        bad["cues"].append(copy.deepcopy(bad["cues"][0]))
        with self.assertRaises(ValueError):
            briefs.validate_briefs(bad)
        for key, value in (("model_preference", "unverified"), ("role", "radio-main"),
                           ("duration_target_seconds", 0), ("id", "../escape"),
                           ("mix_notes", "")):
            bad = copy.deepcopy(VALID)
            bad["cues"][0][key] = value
            with self.assertRaises(ValueError):
                briefs.validate_briefs(bad)

    def test_readiness_never_claims_installed_model(self):
        report = briefs.readiness({})
        self.assertFalse(report["ace-step"]["ready"])
        self.assertFalse(report["audiocraft-musicgen"]["python_present"])
        self.assertFalse(briefs.readiness({"ANUBIS_ACE_STEP_PYTHON": "/missing/python"})["ace-step"]["ready"])

if __name__ == "__main__":
    unittest.main()
