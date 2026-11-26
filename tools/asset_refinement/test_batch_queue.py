import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from batch_queue import plan,run


class QueueTests(unittest.TestCase):
    def test_resume_and_changed_plan(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            cat=root/"catalog.json"
            cat.write_text(json.dumps({"batch":"visual-002"}))
            manifest=root/"queue.json"
            data={"schema":1,"id":"fixture","batches":[{"batch":"visual-001"},
                  {"batch":"visual-002","catalog":"catalog.json"}]}
            manifest.write_text(json.dumps(data))
            calls=[]
            def fake(args,env):
                calls.append(env["ANUBIS_BATCH"])
                return SimpleNamespace(returncode=1 if len(calls)==2 else 0)
            self.assertEqual(run(manifest,root/"runs",root/"launcher",fake),1)
            self.assertEqual(run(manifest,root/"runs",root/"launcher",fake),0)
            self.assertEqual(calls,["visual-001","visual-002","visual-002"])
            cat.write_text(json.dumps({"batch":"visual-002","changed":True}))
            with self.assertRaises(ValueError):
                run(manifest,root/"runs",root/"launcher",fake)

    def test_reject_duplicate(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/"queue.json"
            p.write_text(json.dumps({"schema":1,"id":"fixture","batches":[{"batch":"visual-001"}]*2}))
            with self.assertRaises(ValueError):
                plan(p)
