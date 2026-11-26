import unittest
from handoff import evidence, GATES, require


class ApprovalTests(unittest.TestCase):
    def test_fail_closed(self):
        row={"reviewer":"fixture","rights_notes":"fixture only",
             "review":{k:{"passed":True,"evidence":"fixture"} for k in GATES}}
        evidence(row,GATES)
        row["review"]["rights"]["passed"]=False
        with self.assertRaises(ValueError):
            evidence(row,GATES)
        row["review"]["rights"]["passed"]=True
        del row["review"]["collision"]
        with self.assertRaises(ValueError):
            evidence(row,GATES)

    def test_evidence_required(self):
        row={"reviewer":"fixture","rights_notes":"fixture only",
             "review":{k:{"passed":True,"evidence":""} for k in GATES}}
        with self.assertRaises(ValueError):
            evidence(row,GATES)


class ImportEvidenceTests(unittest.TestCase):
    def test_report_bound_to_every_glb(self):
        import json
        from pathlib import Path
        import tempfile
        from handoff import import_evidence
        from refine import sha
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            files = {n: {"sha256": "a"*64, "meshes":1, "surfaces":1, "vertices":3}
                     for n in ("lod0.glb","lod1.glb","lod2.glb","collision.glb")}
            entry = {"candidate":"fixture.chair.v1","signature":"b"*64,
                     "manifest_sha256":"c"*64,"status":"import-passed","files":files}
            report = root/"godot-1024.json"
            doc = {"schema":1,"engine":{"version":"4.7.2.stable"},
                   "scope":"headless structural import only","rows":[entry]}
            report.write_text(json.dumps(doc))
            row = dict(entry,godot_report_sha256=sha(report))
            info = {"settings":{"bake_size":1024},"outputs":files}
            self.assertEqual(import_evidence(root,row,info)["result"]["status"],"import-passed")
            doc["rows"][0]["status"]="import-failed"
            report.write_text(json.dumps(doc))
            with self.assertRaises(ValueError):
                import_evidence(root,row,info)
            row["godot_report_sha256"]=sha(report)
            with self.assertRaises(ValueError):
                import_evidence(root,row,info)
