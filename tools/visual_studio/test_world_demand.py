import json
import unittest
from pathlib import Path
from world_demand import ROOT,build


class WorldDemandTests(unittest.TestCase):
    def test_repo_demand(self):
        data=json.loads((ROOT/"tools/visual_studio/world_demand.json").read_text())
        result=build(ROOT,data)
        self.assertEqual(len(result["demands"]),7)
        self.assertEqual(set(result["batch_priorities"]),{"visual-001","visual-002"})
        for rows in result["batch_priorities"].values():
            self.assertEqual(len({r["key"] for r in rows}),len(rows))
        data["demands"][0]["assets"].append("unknown.asset")
        with self.assertRaisesRegex(ValueError,"Unknown candidate"):
            build(ROOT,data)
