import tempfile
from pathlib import Path
import unittest
import numpy as np
from PIL import Image
from decal_candidates import PROFILES, maps, produce


class DecalTests(unittest.TestCase):
    def test_channels_and_border(self):
        for key in PROFILES:
            a,o=maps(key,128)
            self.assertEqual(a.shape,(128,128,4))
            np.testing.assert_array_equal(a,maps(key,128)[0])
            np.testing.assert_array_equal(a[:,:,3],o[:,:,3])
            self.assertTrue(np.all(o[:,:,0]==255) and np.all(o[:,:,2]==0))
            self.assertTrue(np.all(a[[0,-1],:,3]==0) and np.all(a[:,[0,-1],3]==0))
            self.assertGreater((a[:,:,3]>0).mean(),.005)
            self.assertLess((a[:,:,3]>0).mean(),.8)

    def test_atlas_resume(self):
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp)/"decals"
            produce(out,128)
            atlas=out/"street-weathering"/"albedo.png"
            with Image.open(atlas) as im:
                self.assertEqual(im.size,(512,256))
            before=atlas.stat().st_mtime_ns
            produce(out,128)
            self.assertEqual(atlas.stat().st_mtime_ns,before)
            atlas.write_bytes(b"bad")
            with self.assertRaises(ValueError):
                produce(out,128)


if __name__=="__main__":
    unittest.main()
