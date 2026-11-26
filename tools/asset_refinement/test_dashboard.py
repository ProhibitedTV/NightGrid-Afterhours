import tempfile
import unittest
from pathlib import Path
import json
from dashboard import collect,html,generate


class DashboardTests(unittest.TestCase):
    def test_missing_and_escaped(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            (root/"visual-001").mkdir()
            q=root/"FactoryQueues"
            q.mkdir()
            (q/"a.json").write_text(json.dumps({"id":"<script>alert(1)</script>","entries":{"visual-001":{"status":"pending","attempts":0}}}))
            batches,queues=collect(root)
            self.assertIsNone(batches[0]["counts"])
            page=html(batches,queues)
            self.assertIn("Not reported",page)
            self.assertIn("&lt;script&gt;",page)
            self.assertNotIn("<script>",page)
            generate(root)
            self.assertTrue((root/"FactoryDashboard.html").is_file())
