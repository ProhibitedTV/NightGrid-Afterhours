import sys
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/audio"))
import nightgrid_music_batch as batch


class StudioProfiles(unittest.TestCase):
    def test_model_settings(self):
        for name, expected in [("studio", "acestep-5Hz-lm-1.7B"),
                               ("studio-4b-cpu", "acestep-5Hz-lm-4B")]:
            profile = batch.PROFILES[name]
            dit = SimpleNamespace(initialize_service=Mock(return_value=("ok", True)),
                                  offload_to_cpu=True, offload_dit_to_cpu=True)
            lm = SimpleNamespace(initialize=Mock(return_value=("ok", True)),
                                 device=profile["lm_device"], offload_to_cpu=profile["lm_offload"])
            batch.initialize_models(dit, lm, profile, name)
            self.assertEqual(dit.initialize_service.call_args.kwargs["config_path"], "acestep-v15-sft")
            self.assertTrue(dit.initialize_service.call_args.kwargs["offload_dit_to_cpu"])
            self.assertEqual(lm.initialize.call_args.kwargs["lm_model_path"], expected)
            self.assertEqual(lm.initialize.call_args.kwargs["offload_to_cpu"], name == "studio")
            self.assertEqual(profile["steps"], 50)

    def test_fail_on_silent_device_fallback(self):
        dit = SimpleNamespace(initialize_service=Mock(return_value=("ok", True)),
                              offload_to_cpu=True, offload_dit_to_cpu=True)
        lm = SimpleNamespace(initialize=Mock(return_value=("ok", True)),
                             device="cpu", offload_to_cpu=True)
        with self.assertRaisesRegex(RuntimeError, "device differs"):
            batch.initialize_models(dit, lm, batch.PROFILES["studio"], "studio")

    def test_modern_source_path_and_reject_fallback(self):
        self.assertEqual(batch.source_format("legacy"), "wav")
        self.assertEqual(batch.source_format("studio"), "wav32")
        self.assertEqual(batch.source_format("studio-4b-cpu"), "wav32")
        for codec in ("pcm_f32le", "pcm_s16le"):
            data = '{"streams":[{"codec_name":"' + codec + '","sample_rate":"48000","channels":2}]}'
            with patch.object(batch.subprocess, "check_output", return_value=data):
                if codec == "pcm_f32le":
                    self.assertEqual(batch.verify_studio_source(Path("fixture.wav"))["codec_name"], codec)
                else:
                    with self.assertRaisesRegex(RuntimeError, "lower-precision fallback"):
                        batch.verify_studio_source(Path("fixture.wav"))

    def test_signature_rejects_old_api_before_invocation(self):
        def old_initialize(checkpoint_dir, lm_model_path, backend, device):
            raise AssertionError("must not call incompatible API")
        dit = SimpleNamespace(initialize_service=Mock(return_value=("ok", True)))
        lm = SimpleNamespace(initialize=old_initialize)
        with self.assertRaisesRegex(RuntimeError, "LLMHandler.initialize"):
            batch.initialize_models(dit, lm, batch.PROFILES["studio"], "studio")
        dit.initialize_service.assert_not_called()

    def test_initial_checkpoint_sync_only_accepts_authoritative_code(self):
        profile = batch.PROFILES["studio"]
        key = profile["dit"] + "/configuration_acestep_v15.py"
        weight = profile["dit"] + "/model.safetensors"
        before = {"source_commit":"abc", "files_sha256":{key:"old",weight:"weights"}}
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "acestep/models/sft/configuration_acestep_v15.py"
            source.parent.mkdir(parents=True)
            source.write_text("# verified source")
            after = {"source_commit":"abc", "files_sha256":{key:batch.sha(source),weight:"weights"}}
            with patch.object(batch, "HOME", root):
                batch.validate_initial_sync(before, after, profile)
                for changes in ({key:"unexpected",weight:"weights"}, {key:batch.sha(source),weight:"changed"}):
                    with self.assertRaisesRegex(RuntimeError, "Unexpected checkpoint change"):
                        batch.validate_initial_sync(before, {"source_commit":"abc","files_sha256":changes}, profile)
                with self.assertRaisesRegex(RuntimeError, "metadata changed"):
                    batch.validate_initial_sync(before, dict(after, source_commit="different"), profile)

    def test_memory_guard(self):
        with patch.object(batch, "available_ram_gib", return_value=15):
            with self.assertRaises(RuntimeError):
                batch.check_profile_ram("studio")
            batch.check_profile_ram("legacy")
        with patch.object(batch, "available_ram_gib", return_value=20):
            batch.check_profile_ram("studio")
            with self.assertRaises(RuntimeError):
                batch.check_profile_ram("studio-4b-cpu")

    def plan(self, *args):
        return subprocess.run([sys.executable, str(ROOT / "tools/audio/nightgrid_music_batch.py"),
                               "--plan", *args], capture_output=True, text=True)

    def test_namespace(self):
        p = ("--palette", "neon-grunge-v1")
        self.assertEqual(self.plan(*p, "--profile", "studio", "--batch",
                                   "music-neon-grunge-001").returncode, 2)
        self.assertEqual(self.plan(*p, "--batch", "music-neon-grunge-studio-001").returncode, 2)
        self.assertEqual(self.plan(*p, "--profile", "studio", "--batch",
                                   "music-neon-grunge-studio-4b-cpu-001").returncode, 2)
        for name in ("studio", "studio-4b-cpu"):
            run = self.plan(*p, "--profile", name, "--batch", "music-neon-grunge-"+name+"-001")
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertIn(batch.PROFILES[name]["lm"], run.stdout)


if __name__ == "__main__":
    unittest.main()
