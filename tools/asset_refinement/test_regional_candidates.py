import json
import copy
import unittest
from regional_candidates import SOURCE, validate, svg

class RegionalTests(unittest.TestCase):
    def test_concept(self):
        data=json.loads(SOURCE.read_text())
        self.assertEqual(validate(data),{"places":7,"major_cities":3,"connections":8})
        self.assertIn("Morrow Bay",svg(data))
    def test_disconnected(self):
        data=json.loads(SOURCE.read_text())
        data["links"]=[x for x in data["links"] if "redwood-heights" not in (x["a"],x["b"])]
        with self.assertRaises(ValueError):validate(data)
