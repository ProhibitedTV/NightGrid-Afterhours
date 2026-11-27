"""Palette selection must not mutate existing production jobs."""
import subprocess
import sys
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/audio"))
import nightgrid_music_batch as batch


class PaletteTests(unittest.TestCase):
    def test_complete_original_palette(self):
        new = batch.cue_palette("neon-grunge-v1")
        self.assertEqual(len(new), 24)
        self.assertEqual([row[:-1] for row in new],
                         [row[:-1] for row in batch.CUES])
        self.assertTrue(all(a[-1] != b[-1] for a, b in zip(new, batch.CUES)))
        self.assertIs(batch.cue_palette("legacy"), batch.CUES)

    def plan(self, *args):
        return subprocess.run([sys.executable, str(ROOT / "tools/audio/nightgrid_music_batch.py"),
                               "--plan", *args], capture_output=True, text=True)

    def test_namespace_and_default(self):
        self.assertEqual(self.plan().stdout, self.plan("--palette", "legacy").stdout)
        self.assertEqual(self.plan("--palette", "neon-grunge-v1").returncode, 2)
        self.assertEqual(self.plan("--batch", "music-neon-grunge-001").returncode, 2)
        result = self.plan("--palette", "neon-grunge-v1", "--batch", "music-neon-grunge-001")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("24 cues, 48 takes", result.stdout)
        self.assertIn("fuzzy power-chord", result.stdout)


if __name__ == "__main__":
    unittest.main()
