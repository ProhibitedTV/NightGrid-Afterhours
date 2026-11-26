import unittest
from readiness import check_coverage


class ReadinessTests(unittest.TestCase):
    def test_full_requires_complete(self):
        rows=[{"status":"candidate-only"},{"status":"pending"}]
        self.assertEqual(check_coverage(rows,"existing"),(1,1))
        with self.assertRaises(ValueError):
            check_coverage(rows,"full")
        self.assertEqual(check_coverage(rows[:1],"full"),(1,0))

    def test_empty_rejected(self):
        for mode in ("smoke","full","existing"):
            with self.assertRaises(ValueError):
                check_coverage([{"status":"pending"}],mode)
