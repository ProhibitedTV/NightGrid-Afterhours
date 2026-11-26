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
