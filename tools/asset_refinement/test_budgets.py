import unittest
from budgets import mip_bytes, estimate


class BudgetTests(unittest.TestCase):
    def test_mips(self):
        self.assertEqual(mip_bytes(4,4),84)
        self.assertEqual(mip_bytes(1,8),60)
        with self.assertRaises(ValueError):
            mip_bytes(0,8)

    def test_standalone_ao_excluded(self):
        outputs={}
        for i,size in enumerate((1024,512,256)):
            outputs[f"lod{i}.glb"]={"triangles":100}
            for kind in ("basecolor","normal","ao"):
                outputs[f"lod{i}-{kind}.png"]={"size":[size,size]}
        info=estimate({"outputs":outputs})
        self.assertEqual(info["all_lods_texture_bytes"],2*sum(mip_bytes(s,s) for s in (1024,512,256)))
        self.assertFalse(info["warnings"])
