import unittest
from unittest.mock import patch
from types import SimpleNamespace
from telemetry import snapshot


class TelemetryTests(unittest.TestCase):
    def test_missing(self):
        with patch("telemetry.os.path.ismount",return_value=False),patch("telemetry.shutil.which",return_value=None):
            data=snapshot()
        self.assertIsNone(data["gpu"])
        self.assertEqual(data["disks"]["nas"]["status"],"not-mounted")

    def test_gpu_unavailable_fields(self):
        with patch("telemetry.os.path.ismount",return_value=False),patch("telemetry.shutil.which",return_value="/fake/nvidia-smi"),patch("telemetry.subprocess.run",return_value=SimpleNamespace(stdout="RTX 3060, 50, [N/A], 1024, 12288\n")):
            data=snapshot()
        self.assertEqual(data["gpu"][0]["memory_total_mib"],12288)
        self.assertIsNone(data["gpu"][0]["utilization_pct"])
