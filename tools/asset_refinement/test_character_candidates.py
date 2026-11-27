import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
from character_candidates import ACTORS, inspect_glb, plan, profile, run


class CharacterCandidateTests(unittest.TestCase):
    def test_distinct_profiles_and_pinned_export(self):
        profiles = [json.loads(profile(actor))["params"] for actor in ACTORS]
        self.assertEqual(len({p["seed"] for p in profiles}), len(ACTORS))
        self.assertEqual({p["name"] for p in profiles}, set(ACTORS.values()))
        self.assertIn("ara3d@0.13.0", plan("dev_rao", Path("/candidate")))
        with tempfile.TemporaryDirectory() as root:
            out = Path(root)/"new"
            with patch("character_candidates.subprocess.run") as proc:
                run(out, list(ACTORS))
                proc.assert_not_called()
            self.assertFalse(out.exists())

    def test_unsigned_ara_modifier_rejects_negative_value(self):
        with tempfile.TemporaryDirectory() as root:
            folder = Path(root)
            data = json.loads(profile("rina_vale"))
            data["params"]["modifiers"]["head/head-rectangular"] = -0.07
            (folder / "rina_vale.json").write_text(json.dumps(data), encoding="utf-8")
            with patch("character_candidates.PROFILES", folder):
                with self.assertRaisesRegex(ValueError, "head/head-rectangular"):
                    profile("rina_vale")

    def test_structural_gate(self):
        # Synthetic JSON fixture, not a renderable model or proof of actual weights.
        attrs = {k: i for i, k in enumerate(
            ["POSITION", "NORMAL", "TEXCOORD_0", "JOINTS_0", "WEIGHTS_0"])}
        doc = {"skins":[{"joints":list(range(1,56))}],
               "nodes":[{"skin":0,"mesh":0}]+[{} for _ in range(55)],
               "meshes":[{"primitives":[{"attributes":attrs}]}],
               "accessors":[{"count":3} for _ in attrs],
               "materials":[{"pbrMetallicRoughness":{"baseColorTexture":{}},
                             "normalTexture":{}}],
               "animations":[{"name":n,"channels":[{}]} for n in ("Idle","Walk")]}
        with tempfile.TemporaryDirectory() as root:
            path = Path(root)/"candidate.glb"
            def write():
                raw = json.dumps(doc).encode()
                raw += b" " * (-len(raw)%4)
                path.write_bytes(struct.pack("<4sIIII",b"glTF",2,len(raw)+20,len(raw),0x4E4F534A)+raw)
            write()
            self.assertEqual(inspect_glb(path)["weighted_primitives"],1)
            original = list(doc["animations"])
            doc["animations"].extend({"name": name, "channels": [{}]}
                                     for name in ("Talk with gestures", "Sit idle (chair)"))
            write()
            self.assertEqual(inspect_glb(path, ("idle", "walk", "talk_gestures",
                                                "sit_idle"))["weighted_primitives"], 1)
            doc["animations"] = original
            doc["animations"].pop()
            write()
            with self.assertRaisesRegex(ValueError,"Missing weighted"):
                inspect_glb(path)
            doc["images"] = [{"uri":"remote.png"}]
            write()
            with self.assertRaisesRegex(ValueError,"URI"):
                inspect_glb(path)
