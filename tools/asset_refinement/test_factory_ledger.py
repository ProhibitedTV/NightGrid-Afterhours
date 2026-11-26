import tempfile
import unittest
from pathlib import Path
from factory_ledger import start,change,read,STAGES


class LedgerTests(unittest.TestCase):
    def test_success_and_log(self):
        with tempfile.TemporaryDirectory() as tmp:
            run=start(Path(tmp),"smoke")
            change(run,"begin","refinement")
            (run/"refinement.log").write_text("fixture")
            change(run,"end","refinement",0)
            for name in STAGES:
                if name!="refinement":
                    change(run,"skip",name,reason="fixture")
            change(run,"finish",code=0)
            data=read(run/"run.json")
            self.assertEqual(data["status"],"completed")
            self.assertEqual(len(data["stages"]["refinement"]["log_sha256"]),64)
            with self.assertRaises(ValueError):
                change(run,"begin","audio")

    def test_interruption_keeps_pending(self):
        with tempfile.TemporaryDirectory() as tmp:
            run=start(Path(tmp),"full")
            change(run,"begin","generation")
            change(run,"finish",code=130)
            data=read(run/"run.json")
            self.assertEqual(data["status"],"failed")
            self.assertEqual(data["stages"]["generation"]["status"],"interrupted")
            self.assertEqual(data["stages"]["audio"]["status"],"pending")
