import hashlib
import json
import struct
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

    def test_post_import_sidecar_accepts_only_line_ending_rewrite(self):
        path = "assets/example.glb.import"
        original = b"[params]\nmeshes/light_baking=2\n"
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            file = root / path
            file.parent.mkdir()
            for data, dirty, accepted in [
                (original.replace(b"\n", b"\r\n"), " M ", True),
                (original.replace(b"=2", b"=1"), " M ", False),
                (original, "M  ", False),
            ]:
                file.write_bytes(data)
                with patch.object(build, "ROOT", root), \
                     patch.object(build, "git", side_effect=[dirty + path, path]), \
                     patch.object(build.subprocess, "check_output", return_value=original):
                    if accepted:
                        build.require_clean(after_import=True)
                    else:
                        with self.assertRaises(RuntimeError):
                            build.require_clean(after_import=True)

    def test_only_new_sidecars_of_tracked_sources_are_allowed_after_import(self):
        tracked = "scripts/world.gd\nassets/example.svg\nassets/room.glb"
        sidecars = "?? scripts/world.gd.uid\n?? assets/example.svg.import\n?? assets/room.glb.unwrap_cache"
        with patch.object(build, "git", side_effect=[sidecars, tracked]):
            build.require_clean(after_import=True)
        for extra in ("?? scripts/other.gd.uid", "?? assets/unknown.png.import",
                      " M assets/example.svg.import", "?? assets/example.png", "?? assets/other.glb.unwrap_cache"):
            with patch.object(build, "git", side_effect=[sidecars + "\n" + extra, tracked]):
                with self.assertRaises(RuntimeError):
                    build.require_clean(after_import=True)
        with patch.object(build, "git", return_value=sidecars):
            with self.assertRaises(RuntimeError):
                build.require_clean()

    def test_extracted_courier_image_must_match_embedded_bytes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            model = root / build.COURIER_MODEL
            model.parent.mkdir(parents=True)
            image = model.with_name(model.stem + "_0.png")
            manifest = json.dumps({"images": [{"mimeType": "image/png", "bufferView": 0}],
                                   "bufferViews": [{"byteLength": 4}]}).encode()
            model.write_bytes(bytes(12) + struct.pack("<I4s", len(manifest), b"JSON") + manifest
                              + struct.pack("<I4s", 4, b"BIN\0") + b"data")
            image.write_bytes(b"data")
            status = "?? " + image.relative_to(root).as_posix()
            with patch.object(build, "ROOT", root), patch.object(build, "git", side_effect=[status, ""]):
                build.require_clean(after_import=True)
            image.write_bytes(b"else")
            with patch.object(build, "ROOT", root), patch.object(build, "git", side_effect=[status, ""]):
                with self.assertRaises(RuntimeError):
                    build.require_clean(after_import=True)

if __name__ == "__main__":
    unittest.main()
