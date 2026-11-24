"""Numeric contract for the Brickwater wetness response, not GPU image QA."""
import unittest

def smooth(a,b,x):
    u=max(0.,min(1.,(x-a)/(b-a)))
    return u*u*(3.-2.*u)

def response(mask,film):
    drainage=smooth(.20,.82,mask)
    wet=mask*(.68+.32*film)+film*(.15+.19*drainage)
    return smooth(.10,.68,wet),smooth(.56,.91,wet)

class WeatherPavement(unittest.TestCase):
    def test_more_rain_never_reduces_dampness_or_pooling(self):
        for mask in (0.,.1,.25,.5,.75,1.):
            values=[response(mask,x/64) for x in range(65)]
            for prior,after in zip(values,values[1:]):
                self.assertGreaterEqual(after[0]+1e-9,prior[0])
                self.assertGreaterEqual(after[1]+1e-9,prior[1])
    def test_dry_island_not_mirror(self):
        self.assertEqual(response(.15,1.)[1],0.)
    def test_existing_depression_holds_residual_water(self):
        self.assertGreater(response(1.,0.)[1],0.)
        self.assertGreater(response(.85,.74)[1],response(.85,0.)[1])
    def test_rain_keeps_local_contrast(self):
        self.assertGreater(response(.85,.74)[1],response(.25,.74)[1])

if __name__=="__main__":
    unittest.main()
