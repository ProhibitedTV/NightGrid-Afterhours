import tempfile
import unittest
from pathlib import Path
from batch import jobs, verified, digest, write_json

class BatchTest(unittest.TestCase):
    def test_manifest(self):
        rows=jobs()
        self.assertGreater(len(rows),200)
        self.assertEqual(len(rows),len({r["key"] for r in rows}))
        self.assertEqual(jobs(),rows)
        self.assertEqual({r["kind"] for r in jobs(True)},{"prop","material"})
    def test_resume_verifies_hash_and_job(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/"concept.png"
            m=Path(d)/"image.json"
            job=jobs(True)[0]
            p.write_bytes(b"candidate")
            write_json(m,{"job":job,"sha256":digest(p)})
            self.assertTrue(verified(p,m,job))
            p.write_bytes(b"tampered")
            self.assertFalse(verified(p,m,job))

if __name__=="__main__":
    unittest.main()
