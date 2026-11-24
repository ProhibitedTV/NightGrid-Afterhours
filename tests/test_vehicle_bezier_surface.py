import math
import sys
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'/'vehicles'))
from bezier_surface import evaluate,tessellate,seam_report


def panel(x0=0.0,x1=1.0,bulge=0.0):
    return tuple(tuple((x0+(x1-x0)*i/3,
                         bulge*math.sin(math.pi*i/3)*math.sin(math.pi*j/3),
                         j/3) for j in range(4)) for i in range(4))


class TestBezierSurface(unittest.TestCase):
    def test_flat_patch_outward_normal(self):
        p,n=evaluate(panel(),.5,.5)
        self.assertAlmostEqual(p[0],.5,places=6)
        self.assertAlmostEqual(p[2],.5,places=6)
        self.assertAlmostEqual(n[1],1.,places=6)

    def test_curved_patch_normals(self):
        a=tessellate(panel(bulge=.11),12,15)
        self.assertEqual(len(a.positions),13*16)
        self.assertEqual(len(a.triangles),12*15*2)
        self.assertTrue(all(0.999 < math.sqrt(sum(x*x for x in n)) < 1.001 for n in a.normals))
        self.assertGreater(max(p[1] for p in a.positions),.04)

    def test_identical_segment_sampling(self):
        a=tessellate(panel(bulge=.14),8,8)
        b=tessellate(panel(bulge=.14),8,8)
        self.assertEqual(a,b)

    def test_identify_disconnected_seam(self):
        a,b=panel(0,1),panel(1,2)
        aligned=seam_report(a,b)
        self.assertLess(aligned['max_position_gap_m'],1e-12)
        self.assertLess(aligned['max_handle_mismatch_m'],1e-12)
        off=seam_report(a,panel(1.05,2.05))
        self.assertAlmostEqual(off['max_position_gap_m'],.05,places=6)

    def test_degenerate_patch_rejected(self):
        bad=(((0.,0.,0.),)*4,)*4
        with self.assertRaisesRegex(ValueError,'degenerate'):
            evaluate(bad,.5,.5)

    def test_invalid_segment_counts_rejected(self):
        with self.assertRaisesRegex(ValueError,'segment'):
            tessellate(panel(),0,8)


if __name__=='__main__':
    unittest.main()
