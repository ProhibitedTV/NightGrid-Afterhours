import json
from pathlib import Path
import tempfile
import unittest
import zipfile
from review_packet import digest, export


class ReviewPacketTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.refined, self.previews = root/"refined", root/"previews"
        self.refined.mkdir()
        self.previews.mkdir()
        self.out = root/"packet.zip"
        self.key, self.sig, self.pid = "synaxis.test.v1", "a"*64, "b"*64
        glb = "c"*64
        manifest = {"candidate": self.key, "settings": {"bake_size": 1024},
                    "outputs": {"lod0.glb": {"sha256": glb}}}
        self.manifest = self.refined/self.key/self.sig/"refinement.json"
        rh = self.put(self.manifest, manifest)
        ph = self.put(self.previews/self.key/self.pid/"preview.json",
                      {"status":"review-only", "settings":{"candidate":self.key,
                      "refinement":self.sig, "manifest_sha256":rh, "glb_sha256":glb}})
        self.put(self.refined/"review-1024.json",
                 {"schema":1,"status":"unapproved","bake_size":1024,
                  "rows":[{"candidate":self.key,"status":"review-required",
                           "versions":[{"signature":self.sig,"manifest_sha256":rh}]}]})
        index = self.put(self.previews/"review-1024.json",
                         {"schema":1,"scope":"Blender preview only","partial":False,
                          "rows":[{"candidate":self.key,"refinement":self.sig,"preview":self.pid,
                                   "status":"review-only","manifest_sha256":ph}]})
        sheet_dir = self.previews/("sheets-"+index)
        sheet_dir.mkdir()
        self.page = sheet_dir/"page-001.jpg"
        self.page.write_bytes(b"synthetic sheet bytes")
        self.put(sheet_dir/"index.json", {"source_sha256":index,"scope":"review-only",
                 "pages":{"page-001.jpg":digest(self.page.read_bytes())}})

    def put(self, path, obj):
        path.parent.mkdir(parents=True, exist_ok=True)
        data = json.dumps(obj).encode()
        path.write_bytes(data)
        return digest(data)

    def test_export_and_exclusive_destination(self):
        index = export(self.refined,self.previews,1024,self.out)
        self.assertEqual(index["versions"],1)
        with zipfile.ZipFile(self.out) as z:
            self.assertIsNone(z.testzip())
            for name, sha in index["files"].items():
                self.assertEqual(digest(z.read(name)),sha)
            self.assertNotIn("approval.json",z.namelist())
        with self.assertRaises(FileExistsError):
            export(self.refined,self.previews,1024,self.out)

    def test_tampered_page(self):
        self.page.write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError,"hash mismatch"):
            export(self.refined,self.previews,1024,self.out)
        self.assertFalse(self.out.exists())

    def test_stale_refinement(self):
        self.manifest.write_bytes(b"{}")
        with self.assertRaisesRegex(ValueError,"hash mismatch"):
            export(self.refined,self.previews,1024,self.out)
        self.assertFalse(self.out.exists())

    def test_size_limit(self):
        with self.assertRaisesRegex(ValueError,"size limit"):
            export(self.refined,self.previews,1024,self.out,10)
        self.assertFalse(self.out.exists())

    def test_no_write_into_input(self):
        with self.assertRaisesRegex(ValueError,"separate"):
            export(self.refined,self.previews,1024,self.refined/"packet.zip")
