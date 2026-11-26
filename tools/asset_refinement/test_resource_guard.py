import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import sys
from resource_guard import violation, supervise, GIB


def fixture():
    return {"disks":{"windows_ssd":{"status":"available","free_bytes":30*GIB},
                     "nas":{"status":"available","free_bytes":100*GIB}},
            "gpu":[{"temperature_c":60}]}


class ResourceTests(unittest.TestCase):
    def test_limits(self):
        data=fixture()
        self.assertIsNone(violation(data,25,10,85))
        data["gpu"][0]["temperature_c"]=85
        self.assertIn("temperature",violation(data,25,10,85))
        data["disks"]["nas"]["status"]="not-mounted"
        self.assertIn("nas",violation(data,25,10,85))

    def test_preflight_refuses_launch(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            data=fixture()
            data["disks"]["windows_ssd"]["free_bytes"]=1
            marker=root/"marker"
            with patch("resource_guard.snapshot",return_value=data):
                rc=supervise([sys.executable,"-c","from pathlib import Path; Path("+repr(str(marker))+").touch()"],root/"guard.jsonl",interval=5)
            self.assertEqual(rc,75)
            self.assertFalse(marker.exists())

    def test_successful_child(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch("resource_guard.snapshot",return_value=fixture()):
                self.assertEqual(supervise([sys.executable,"-c","pass"],Path(tmp)/"guard.jsonl",interval=5),0)
