import json
from pathlib import Path
import struct
import tempfile
import unittest
from refine import glb_info, sha, source, verified


def glb(path, attributes=None, n=3):
    obj = {"meshes": [{"primitives": [{"attributes": attributes or {"POSITION": 0, "NORMAL": 0,
            "TEXCOORD_0": 0, "COLOR_0": 0}, "indices": 0}]}], "accessors": [{"count": n}]}
    data = json.dumps(obj).encode()
    data += b" " * (-len(data) % 4)
    path.write_bytes(struct.pack("<4sII", b"glTF", 2, 20+len(data))
                     + struct.pack("<I4s", len(data), b"JSON") + data)


class Contract(unittest.TestCase):
    def test_source_and_tamper(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "test.chair.v1"
            p.mkdir()
            job = {"key": p.name, "kind": "prop"}
            self.assertIsNone(source(p))
            (p/"concept.png").write_bytes(b"test")
            glb(p/"mesh.glb")
            image = {"job": job, "sha256": sha(p/"concept.png")}
            mesh = {"job": job, "sha256": sha(p/"mesh.glb"), "input_sha256": image["sha256"]}
            (p/"image.json").write_text(json.dumps(image))
            (p/"mesh.json").write_text(json.dumps(mesh))
            self.assertEqual(len(source(p)), 4)
            (p/"concept.png").write_bytes(b"changed")
            with self.assertRaises(ValueError):
                source(p)

    def test_glb_gate(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)/"mesh.glb"
            glb(p)
            self.assertEqual(glb_info(p), 1)
            glb(p, {"POSITION": 0})
            with self.assertRaises(ValueError):
                glb_info(p)
            self.assertEqual(glb_info(p, False), 1)
            glb(p, n=4)
            with self.assertRaises(ValueError):
                glb_info(p)

    def test_resume_integrity(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)
            outputs = {}
            for name in ("lod0.glb", "lod1.glb", "lod2.glb", "collision.glb"):
                glb(p/name)
                outputs[name] = {"sha256": sha(p/name), "triangles": 1}
            (p/"refinement.json").write_text(json.dumps({"signature":"abc","status":"unapproved","outputs":outputs}))
            self.assertTrue(verified(p, "abc"))
            self.assertFalse(verified(p, "different"))
            (p/"lod0.glb").write_bytes(b"corrupt")
            self.assertFalse(verified(p, "abc"))


if __name__ == "__main__":
    unittest.main()
