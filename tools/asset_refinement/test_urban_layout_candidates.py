import copy
import unittest
from urban_layout_candidates import PARCELS, INTERIORS, validate, svg

class LayoutTests(unittest.TestCase):
    def test_plans(self):
        for interior,plans in ((False,PARCELS),(True,INTERIORS)):
            for name,plan in plans.items():
                validate(plan,interior)
                self.assertIn("<svg",svg(name,plan,interior))
    def test_invalid_opening(self):
        p=copy.deepcopy(INTERIORS["office_floor"])
        p["doors"][0][2]=0
        with self.assertRaises(ValueError):validate(p,True)
    def test_overlap(self):
        p=copy.deepcopy(PARCELS["brickwater_service_court"])
        p["structures"]["bad"]=[-17,-13,-5,0]
        with self.assertRaises(ValueError):validate(p,False)
