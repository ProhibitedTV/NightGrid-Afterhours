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

    def test_audio_inventory_contract(self):
        bank = '[{"id":"step_tile","loop":false,"reviewed":false}]'
        count, effects = build.audio_inventory("Verified published lines: 86\n", bank)
        self.assertEqual(count, 86)
        self.assertEqual(effects[0]["id"], "step_tile")
        for bad in ['{}', '[{"id":"x","loop":1,"reviewed":true}]',
                    '[{"id":"x","loop":false,"reviewed":true},{"id":"x","loop":true,"reviewed":true}]']:
            with self.assertRaises(RuntimeError):
                build.audio_inventory("Verified published lines: 86", bad)
        with self.assertRaises(RuntimeError):
            build.audio_inventory("unrecognized voice output", bank)

    def test_only_known_untracked_radio_outputs_allowed(self):
        with patch.object(build, "git", return_value="?? assets/audio/mbpd/report.wav\n?? assets/audio/mbpd/report.wav.import"):
            build.require_clean()
        for status in [" M assets/audio/mbpd/report.wav", "?? assets/audio/mbpd/extra.wav",
                       "?? scripts/world.gd", "?? assets/audio/mbpd/README.md"]:
            with patch.object(build, "git", return_value=status):
                with self.assertRaises(RuntimeError):
                    build.require_clean()

    def test_dirty_source_rejected(self):
        with patch.object(build, "git", return_value=" M scripts/world.gd"):
            with self.assertRaises(RuntimeError):
                build.require_clean()

if __name__ == "__main__":
    unittest.main()
