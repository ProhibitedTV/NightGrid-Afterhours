"""Synthetic evidence fixtures; do not represent real garment reviews."""
import copy
import tempfile
import unittest
from pathlib import Path
from release import CHECKS, POSES, review_record, draft_record, sha

class ReviewGate(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder=Path(self.temp.name)
        self.review={"schema":1,"id":"test_id","sha256":"a","base_sha256":"b","profile_sha256":"c",
                     "reviewer":"synthetic","decision":"approved","license_notes":"test fixture only",
                     "checks":{k:True for k in CHECKS},"captures":[]}
        for pose in sorted(POSES):
            p=self.folder/("test_id_"+pose+"_candidate_a_1.png")
            p.write_bytes(b"\x89PNG\r\n\x1a\n"+pose.encode())
            self.review["captures"].append({"pose":pose,"file":p.name,"sha256":sha(p)})
    def verify(self, review=None):
        return review_record(review or self.review,self.folder,"test_id","a","b","c")
    def test_explicit_review(self):
        self.assertEqual(len(self.verify()),6)
    def test_reject_stale_asset(self):
        self.review["sha256"]="changed"
        with self.assertRaisesRegex(ValueError,"Stale review"):
            self.verify()
    def test_missing_check_and_rejection(self):
        for field in ("checks","decision","license_notes","reviewer"):
            review=copy.deepcopy(self.review)
            review.pop(field)
            with self.assertRaises(ValueError):
                self.verify(review)
    def test_missing_pose(self):
        self.review["captures"].pop()
        with self.assertRaises(ValueError):
            self.verify()
    def test_tampered_capture(self):
        (self.folder/"test_id_idle_candidate_a_1.png").write_bytes(b"\x89PNG\r\n\x1a\nchanged")
        with self.assertRaisesRegex(ValueError,"Capture hash"):
            self.verify()
    def test_path_traversal(self):
        self.review["captures"][0]["file"]="../escape.png"
        with self.assertRaisesRegex(ValueError,"Unsafe evidence"):
            self.verify()
    def test_draft_never_approves(self):
        (self.folder/"test_id_idle_base_a_99.png").write_bytes(b"wrong view")
        (self.folder/"test_id_idle_candidate_old_99.png").write_bytes(b"old asset")
        draft=draft_record("test_id",self.review,self.folder)
        self.assertEqual(len(draft["captures"]),6)
        self.assertEqual(draft["decision"],"pending")
        self.assertFalse(any(draft["checks"].values()))
        with self.assertRaises(ValueError):
            self.verify(draft)
    def test_duplicate_capture(self):
        self.review["captures"][1]["file"]=self.review["captures"][0]["file"]
        with self.assertRaisesRegex(ValueError,"Duplicate capture"):
            self.verify()

if __name__=="__main__":
    unittest.main()
