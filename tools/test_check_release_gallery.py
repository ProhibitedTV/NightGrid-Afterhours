#!/usr/bin/env python3
"""Exercise the release provenance gate with real, isolated git histories.

Fixtures are not gameplay images. The PNG verifier is a stub here so these
tests isolate the release gate; the actual screenshot preflight runs separately.
"""
from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import check_release_gallery as gate


class ReleaseGalleryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git("init", "-q")
        self.git("config", "user.name", "Release gate fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        for path in (
            "project.godot", "scripts/world.gd", "scripts/build_info.gd",
            "scenes/main.tscn", "assets/material.png", "tools/capture_screenshots.gd",
            "tools/generate_mbpd_radio.py", "README.md",
        ):
            self.write(path, "fixture input\n")
        self.write("tools/check_screenshots.py", "print('fixture: PNG validation stub')\n")
        self.commit("rendered source")
        self.capture = self.git("rev-parse", "HEAD").strip()
        self.manifest()
        self.commit("gallery manifest")
        self.root_patch = patch.object(gate, "ROOT", self.root)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.root, text=True,
                                       stderr=subprocess.STDOUT)

    def write(self, path, data):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(data, encoding="utf-8")

    def commit(self, message):
        self.git("add", ".")
        self.git("commit", "-qm", message)

    def manifest(self, count=9, revision=None):
        self.write("docs/screenshots/capture-manifest.json", json.dumps({
            "source_revision": revision or self.capture,
            "images": {f"fixture-{i}.png": {} for i in range(count)},
        }))

    def test_docs_and_version_only_are_allowed(self):
        self.write("README.md", "new README")
        self.write("scripts/build_info.gd", "new version")
        self.commit("documentation and version identity")
        gate.verify(self.capture)

    def test_runtime_change_is_rejected(self):
        for path in ("project.godot", "scripts/world.gd", "scenes/main.tscn",
                     "assets/material.png", "tools/capture_screenshots.gd",
                     "tools/generate_mbpd_radio.py"):
            with self.subTest(path=path):
                self.write(path, "different runtime content")
                self.commit("change " + path)
                with self.assertRaisesRegex(ValueError, "Gallery is stale"):
                    gate.verify(self.capture)
                self.git("reset", "--hard", "HEAD~1")

    def test_new_runtime_asset_is_rejected(self):
        self.write("assets/added.mesh", "new geometry")
        self.commit("new asset")
        with self.assertRaisesRegex(ValueError, "Gallery is stale"):
            gate.verify(self.capture)

    def test_missing_gallery_image_is_rejected(self):
        self.manifest(count=8)
        with self.assertRaisesRegex(ValueError, "nine-image"):
            gate.verify(self.capture)

    def test_incorrect_revision_is_rejected(self):
        self.manifest(revision="0" * 40)
        with self.assertRaisesRegex(ValueError, "nine-image"):
            gate.verify(self.capture)
        with self.assertRaisesRegex(ValueError, "full gallery revision"):
            gate.verify("HEAD")

    def test_failed_png_verification_is_rejected(self):
        self.write("tools/check_screenshots.py", "raise SystemExit(1)\n")
        self.commit("fixture simulates damaged PNG")
        with self.assertRaises(subprocess.CalledProcessError):
            gate.verify(self.capture)


if __name__ == "__main__":
    unittest.main()
