import csv
import tempfile
import unittest
from pathlib import Path
from analyze_stationary_trace import read_rows, summarize_position

class StationaryTests(unittest.TestCase):
    def test_classifies_stationary_streaming_and_walk(self):
        rows = [(i / 10, 16., 0., -3., 4., "0") for i in range(11)]
        rows[8] = (.8, 40., 5., -3., 4., "0")
        rows += [(i / 10, 18., 0., -3. + (i - 10) * .2, 4., "0") for i in range(11, 21)]
        result = summarize_position(rows)
        self.assertEqual(result["groups"]["foot/stationary/active"]["max_ms"], 40.)
        self.assertGreater(result["groups"]["foot/stationary/idle"]["count"], 0)
        self.assertGreater(result["groups"]["foot/moving/idle"]["count"], 0)
        self.assertEqual(sum(v["count"] for v in result["groups"].values()) +
                         result["excluded_warmup_or_mode_change"], len(rows))

    def test_mode_change_restarts_window(self):
        rows = [(i / 4, 16., 0., 0., 0., "0" if i < 4 else "1") for i in range(8)]
        report = summarize_position(rows)
        self.assertEqual(report["excluded_warmup_or_mode_change"], 4)
        self.assertEqual(report["groups"]["foot/stationary/idle"]["count"], 2)
        self.assertEqual(report["groups"]["car/stationary/idle"]["count"], 2)

    def test_invalid_clock_and_signed_positions(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "trace.csv"
            with path.open("w", newline="") as f:
                writer = csv.writer(f)
                writer.writerow(["elapsed_s", "frame_ms", "stream_build_ms", "world_x", "world_z", "in_car"])
                writer.writerow([.1, 16, 0, -100, -20, 0])
            self.assertEqual(read_rows(path)[0][3], -100)
            with path.open("a") as f:
                f.write(".1,16,0,0,0,0\n")
            with self.assertRaises(ValueError):
                read_rows(path)

if __name__ == "__main__":
    unittest.main()
