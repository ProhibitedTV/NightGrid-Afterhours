import tempfile
from pathlib import Path
import unittest
import numpy as np
from environment_candidates import radiance, rgbe, write_hdr, produce, PRESETS


class EnvironmentTests(unittest.TestCase):
    def test_radiance(self):
        for preset in PRESETS:
            rgb=radiance(preset,128)
            self.assertEqual(rgb.shape,(64,128,3))
            self.assertTrue(np.isfinite(rgb).all())
            self.assertGreaterEqual(rgb.min(),0)
            np.testing.assert_array_equal(rgb,radiance(preset,128))
            # Neighboring samples across the wrap should be continuous.
            seam=radiance(preset,512)
            self.assertLess(np.max(np.abs(seam[:,0]-seam[:,-1])),.3)
        self.assertGreater(radiance("clear_day",128).max(),1)
        self.assertLess(radiance("moonlit_night",128).max(),1)

    def test_rgbe_round_trip(self):
        src=np.array([[[0,0,0],[.2,.8,2.5],[.015,.031,.12],[12,4,.5]]],dtype=np.float32)
        encoded=rgbe(src)
        decoded=encoded[:,:,:3]*np.exp2(encoded[:,:,3:].astype(float)-136)
        np.testing.assert_allclose(decoded,src,atol=.063,rtol=.01)

    def test_resume_integrity(self):
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp)/"environments"
            produce(out,64)
            self.assertEqual({p.name for p in out.iterdir()},set(PRESETS))
            first=out/"clear_day"/"environment.hdr"
            before=first.stat().st_mtime_ns
            produce(out,64)
            self.assertEqual(first.stat().st_mtime_ns,before)
            first.write_bytes(b"bad")
            with self.assertRaises(ValueError):
                produce(out,64)

    def test_hdr_scanline(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/"env.hdr"
            rgb=radiance("clear_day",256)
            write_hdr(path,rgb)
            with path.open("rb") as f:
                self.assertEqual(f.readline(),b"#?RADIANCE\n")
                self.assertEqual(f.readline(),b"FORMAT=32-bit_rle_rgbe\n")
                self.assertEqual(f.readline(),b"\n")
                self.assertEqual(f.readline(),b"-Y 128 +X 256\n")
                expected=rgbe(rgb)
                for row in expected:
                    self.assertEqual(f.read(4),bytes((2,2,1,0)))
                    for channel in range(4):
                        data=bytearray()
                        while len(data)<256:
                            count=f.read(1)[0]
                            self.assertTrue(1<=count<=128)
                            data.extend(f.read(count))
                        self.assertEqual(bytes(data),row[:,channel].tobytes())
                self.assertEqual(f.read(),b"")


if __name__=="__main__":
    unittest.main()
