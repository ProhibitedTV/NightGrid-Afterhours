import csv
import json
import tempfile
import unittest
from pathlib import Path

from analyze_vehicle_trace import load_capture, summarize, compare, stats

class TraceTests(unittest.TestCase):
    def fixture(self, root, name="test", peak=40):
        path = root / (name + ".csv")
        with path.open("w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["frame_ms", "stream_build_ms", "in_car"])
            writer.writerows([[16, 0, 0], [peak, 3, 1]] + [[16, 0, 1]] * 12)
        event = {"kind":"enter","model":"cinder_r9","result":"ok",
                 "first_frame_index":1, "total_cpu_ms":2,
                 "stages":{"rig":1.5}, "following_frame_ms":[peak]+[16]*11,
                 "following_stream_build_ms":3,"complete_window":True}
        sidecar = path.with_name(path.stem+"-vehicle-transitions.json")
        sidecar.write_text(json.dumps({"schema_version":1,"source_csv":path.name,"transitions":[event]}))
        return path, sidecar

    def test_matching_and_comparison(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            old, _ = self.fixture(root,"cold",80)
            new, _ = self.fixture(root,"warm",40)
            a, b = summarize(*load_capture(old)), summarize(*load_capture(new))
            self.assertEqual(b["groups"]["enter/cinder_r9/ok"]["following_window_peak"]["max_ms"],40)
            self.assertEqual(b["outside_transition_windows"]["count"],2)
            self.assertEqual(compare(a,b)["groups"]["enter/cinder_r9/ok"]["following_window_peak"]["max_ms"],-40)

    def test_missing_and_mismatched_sidecar(self):
        with tempfile.TemporaryDirectory() as d:
            path, sidecar = self.fixture(Path(d))
            data=json.loads(sidecar.read_text())
            data["transitions"][0]["following_frame_ms"][0]=90
            sidecar.write_text(json.dumps(data))
            with self.assertRaises(ValueError):
                load_capture(path)
            sidecar.unlink()
            self.assertFalse(summarize(*load_capture(path))["transition_sidecar"])

    def test_incomplete_and_overlap(self):
        with tempfile.TemporaryDirectory() as d:
            path, sidecar = self.fixture(Path(d))
            data=json.loads(sidecar.read_text())
            e=dict(data["transitions"][0])
            e.update(first_frame_index=13,following_frame_ms=[16],
                     following_stream_build_ms=0,complete_window=False)
            data["transitions"].append(e)
            sidecar.write_text(json.dumps(data))
            result=summarize(*load_capture(path))
            self.assertEqual(result["outside_transition_windows"]["count"],1)
            self.assertEqual(result["groups"]["enter/cinder_r9/ok"]["complete_windows"],1)

    def test_percentiles(self):
        self.assertEqual(stats([10,20,40])["p95_ms"],40)
        self.assertEqual(stats([10,20,40])["hitches"],1)
        self.assertEqual(stats([]),{"count":0})

if __name__ == "__main__":
    unittest.main()
