import unittest
from triage import timing, version_flags, positive


class TriageTests(unittest.TestCase):
    def test_small_samples_do_not_forecast(self):
        self.assertIsNone(timing([{"seconds":10}],5)["remaining_serial_job_seconds"])
        data=timing([{"seconds":n,"peak_allocated_bytes":1024} for n in (1,2,3,4,100)],10)
        self.assertEqual(data["remaining_serial_job_seconds"],30)
        self.assertEqual(data["max_observed_torch_allocated_bytes"],1024)
        self.assertFalse(positive(float("nan")))

    def test_technical_flags(self):
        item={"scale_status":"unresolved","outputs":{}}
        for i,n in enumerate((100,50,20)):
            item["outputs"][f"lod{i}.glb"]={"triangles":n}
            item["outputs"][f"lod{i}-basecolor.png"]={"size":[128,128],"coverage_with_margin":.5}
        item["outputs"]["lod2-basecolor.png"]["coverage_with_margin"]=.04
        flags=version_flags(item)
        self.assertIn("measure-physical-height",flags)
        self.assertIn("lod2-low-uv-coverage",flags)
        self.assertNotIn("inspect-lod-order",flags)
        self.assertNotIn("review-missing-projected-normals", flags)
        item["normal_projection_exception"] = "operator-requested omission after failed bake"
        self.assertIn("review-missing-projected-normals", version_flags(item))
