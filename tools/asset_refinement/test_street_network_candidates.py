import unittest
from street_network_candidates import build, validate, svg

class NetworkTests(unittest.TestCase):
    def test_authored_graph(self):
        p=build()
        metrics=validate(p)
        self.assertEqual(metrics["intersections"],81)
        self.assertEqual(metrics["diagonal_segments"],7)
        self.assertGreater(metrics["three_way_nodes"],0)
        self.assertLess(metrics["segments"],144)
        self.assertIn("<svg",svg(p))
        self.assertEqual(p,build())

    def test_crossing_rejected(self):
        p=build()
        p["edges"].append({"a":"0,0","b":"8,8","class":"arterial"})
        with self.assertRaises(ValueError):validate(p)
