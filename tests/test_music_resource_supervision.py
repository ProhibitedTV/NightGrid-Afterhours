import sys
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools/audio"))
import music_gpu_guard
from resource_guard import GIB, supervise, violation


def snapshot(temp=65, used=800, total=12288):
    return {"disks": {"windows_ssd": {"status": "available", "free_bytes": 30*GIB},
                      "nas": {"status": "available", "free_bytes": 20*GIB}},
            "gpu": [{"temperature_c": temp, "temperature_source": "windows-host",
                     "memory_used_mib": used, "memory_total_mib": total}]}


class MusicGuardTest(unittest.TestCase):
    def test_host_temperature_and_memory(self):
        with patch.object(music_gpu_guard, "snapshot", return_value=snapshot()):
            self.assertEqual(music_gpu_guard.gpu_guard(), (800.0, 12288.0))

    def test_reject_unmonitored_or_hot_gpu(self):
        for temp in (None, 0, float("nan"), 85, 105):
            with patch.object(music_gpu_guard, "snapshot", return_value=snapshot(temp)):
                with self.assertRaises(RuntimeError):
                    music_gpu_guard.gpu_guard()
                self.assertIsNotNone(violation(snapshot(temp), 25, 10, 85, require_gpu=True))

    def test_reject_invalid_vram(self):
        with patch.object(music_gpu_guard, "snapshot", return_value=snapshot(65, None)):
            with self.assertRaisesRegex(RuntimeError, "memory telemetry"):
                music_gpu_guard.gpu_guard()

    def test_strict_preflight_does_not_launch_child(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            marker = root / "marker"
            command = [sys.executable, "-c", "from pathlib import Path; Path(" + repr(str(marker)) + ").touch()"]
            with patch("resource_guard.snapshot", return_value=snapshot(None)):
                self.assertEqual(supervise(command, root / "guard.jsonl",
                                           interval=5, require_gpu=True), 75)
            self.assertFalse(marker.exists())

    def test_other_factory_lanes_keep_existing_policy(self):
        self.assertIsNone(violation(snapshot(None), 25, 10, 85))
        self.assertIsNone(violation(snapshot(), 25, 10, 85, require_gpu=True))


if __name__ == "__main__":
    unittest.main()
