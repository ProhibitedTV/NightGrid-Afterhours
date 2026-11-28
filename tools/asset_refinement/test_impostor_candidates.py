import tempfile
from pathlib import Path
import unittest
from PIL import Image
from impostor_candidates import pack


class ImpostorTests(unittest.TestCase):
    def fixture(self, root):
        for i in range(16):
            img = Image.new("RGBA", (32,32))
            img.paste((50+i,90,40,255),(8,8,24,24))
            img.save(root / f"albedo-{i:02d}.png")

    def test_atlas_mapping(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.fixture(root)
            tiles = pack(root,"albedo",root/"atlas.png",32)
            self.assertEqual(len(tiles),16)
            self.assertEqual(tiles[15]["tile_xy"],[96,96])
            self.assertEqual(tiles[0]["coverage"],.25)
            with Image.open(root/"atlas.png") as atlas:
                self.assertEqual(atlas.size,(128,128))
                self.assertEqual(atlas.getpixel((110,110)),(65,90,40,255))
                self.assertEqual(atlas.getpixel((96,96))[3],0)

    def test_reject_clipped(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.fixture(root)
            Image.new("RGBA",(32,32),(1,1,1,255)).save(root/"albedo-00.png")
            with self.assertRaises(ValueError):
                pack(root,"albedo",root/"atlas.png",32)


if __name__ == "__main__":
    unittest.main()
