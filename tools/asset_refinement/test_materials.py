import json
from pathlib import Path
import tempfile
import unittest
import numpy as np
from PIL import Image
from materials import derive, run, MAPS, PROFILES, verified_material
from refine import sha, load


class MaterialTests(unittest.TestCase):
    def test_maps(self):
        rgb = np.random.default_rng(7).integers(0,256,(128,128,3),dtype=np.uint8)
        maps = derive(rgb, PROFILES["brushed-stainless-steel"])
        self.assertEqual(set(maps),set(MAPS))
        self.assertTrue((maps["metallic.png"] == 255).all())
        self.assertTrue((maps["orm.png"][:,:,0] == 255).all())
        self.assertTrue(np.array_equal(maps["orm.png"][:,:,1],maps["roughness.png"]))
        normals = maps["normal.png"].astype(float)/127.5-1
        self.assertLess(float(np.abs(np.linalg.norm(normals,axis=-1)-1).max()),.015)

    def test_resume_tamper(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            raw, out = root/"raw", root/"out"
            key = "material.aged-red-brick-with-mortar.v1"
            folder = raw/"candidates"/key
            folder.mkdir(parents=True)
            Image.new("RGB",(128,128),(140,90,65)).save(folder/"concept.png")
            (folder/"image.json").write_text(json.dumps({"job":{"key":key,"id":key[:-3],"kind":"material"},
                "sha256":sha(folder/"concept.png")}))
            self.assertEqual(run(raw,out,128),0)
            final = next((out/key).iterdir())
            meta = load(final/"material.json")
            self.assertTrue(verified_material(final,final.name,meta["settings"]))
            self.assertEqual(run(raw,out,128),0)
            (final/"normal.png").write_bytes(b"bad")
            self.assertEqual(run(raw,out,128),1)
            self.assertEqual((final/"normal.png").read_bytes(),b"bad")


if __name__ == "__main__":
    unittest.main()
