import tempfile
from pathlib import Path
import unittest
from check_worker_cache import revision, check

class WorkerCacheTests(unittest.TestCase):
    def test_revision(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            p=root/"owner--model.revision"
            p.write_text("a"*40+"\n")
            self.assertEqual(revision(root,"owner/model"),"a"*40)
            p.write_text("main")
            with self.assertRaises(ValueError):revision(root,"owner/model")
    def test_missing_setup_is_not_installed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            with self.assertRaises(ValueError):check(root)
            self.assertEqual(list(root.iterdir()),[])
