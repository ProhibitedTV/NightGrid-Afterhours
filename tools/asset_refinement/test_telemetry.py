import unittest
from unittest.mock import patch
from types import SimpleNamespace
import subprocess
from telemetry import snapshot, query_gpu, native_gpu_rows


class TelemetryTests(unittest.TestCase):
    def test_missing(self):
        with patch("telemetry.os.path.ismount", return_value=False), patch("telemetry.shutil.which", return_value=None):
            data = snapshot()
        self.assertIsNone(data["gpu"])
        self.assertEqual(data["disks"]["nas"]["status"], "not-mounted")

    def test_gpu_unavailable_fields(self):
        with patch("telemetry.os.path.ismount", return_value=False), patch("telemetry.shutil.which", return_value="/fake/nvidia-smi"), patch("telemetry.subprocess.run", return_value=SimpleNamespace(stdout="GPU-one, RTX 3060, 50, [N/A], 1024, 12288\n")):
            data = snapshot()
        self.assertEqual(data["gpu"][0]["memory_total_mib"], 12288)
        self.assertIsNone(data["gpu"][0]["utilization_pct"])
        self.assertEqual(data["gpu"][0]["temperature_source"], "native")

    def test_host_matches_uuid_not_order(self):
        native = "GPU-one, RTX 3060, [N/A], 10, 1024, 12288\nGPU-two, RTX 3060, 51, 0, 2000, 12288\nGPU-three, RTX 3060, [N/A], 0, 2000, 12288\n"
        host = "GPU-two, RTX 3060, 90, 0, 2000, 12288\nGPU-one, RTX 3060, 50.66, 0, 2000, 12288\nGPU-four, RTX 3060, 88, 0, 2000, 12288\n"
        with patch("telemetry.os.path.ismount", return_value=False), patch("telemetry.shutil.which", return_value="/fake/nvidia-smi"), patch("telemetry.windows_nvidia_smi", return_value="/fake/nvidia-smi.exe"), patch("telemetry.subprocess.run", side_effect=[SimpleNamespace(stdout=native), SimpleNamespace(stdout=host)]) as run:
            data = snapshot()
        self.assertEqual(run.call_count, 2)
        self.assertEqual(data["gpu"][0]["temperature_c"], 50.66)
        self.assertEqual(data["gpu"][0]["temperature_source"], "windows-host")
        self.assertEqual(data["gpu"][1]["temperature_c"], 51)
        self.assertIsNone(data["gpu"][2]["temperature_c"])

    def test_secure_path_missing_native_binary(self):
        row = {"uuid": "GPU-one", "temperature_c": 49}
        with patch("telemetry.shutil.which", return_value=None), patch("telemetry.Path.is_file", return_value=True), patch("telemetry.query_gpu", side_effect=lambda binary: [row] if binary == "/usr/lib/wsl/lib/nvidia-smi" else []) as query:
            self.assertEqual(native_gpu_rows(), [row])
            self.assertEqual(query.call_args.args, ("/usr/lib/wsl/lib/nvidia-smi",))

    def test_empty_native_inventory_uses_host(self):
        host = "GPU-one, RTX 3060, 50, 14, 1548, 12288\n"
        with patch("telemetry.os.path.ismount", return_value=False), patch("telemetry.native_gpu_rows", return_value=[]), patch("telemetry.windows_nvidia_smi", return_value="/fake/nvidia-smi.exe"), patch("telemetry.subprocess.run", return_value=SimpleNamespace(stdout=host)):
            data = snapshot()
        self.assertEqual(data["gpu"][0]["temperature_source"], "windows-host")
        self.assertEqual(data["gpu"][0]["memory_used_mib"], 1548)
        self.assertEqual(data["gpu"][0]["temperature_c"], 50)

    def test_nonfinite_temperature_unavailable(self):
        with patch("telemetry.subprocess.run", return_value=SimpleNamespace(stdout="GPU-one, RTX 3060, nan, 0, 1024, 12288\nGPU-two, RTX 3060, inf, 0, 1024, 12288\n")):
            self.assertTrue(all(row["temperature_c"] is None for row in query_gpu("/fake/nvidia-smi")))

    def test_timeout_is_unavailable(self):
        with patch("telemetry.subprocess.run", side_effect=subprocess.TimeoutExpired("nvidia-smi", 5)):
            self.assertEqual(query_gpu("/fake/nvidia-smi"), [])
