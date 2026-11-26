import tempfile
import unittest
from pathlib import Path
from batch import jobs, verified, digest, write_json, inventory, pack, guard_storage, choose_pending, lock_catalog
from unittest.mock import patch
import json
import zipfile

class BatchTest(unittest.TestCase):
    def test_nas_mount_required(self):
        with patch("batch.os.path.ismount",return_value=False):
            with self.assertRaisesRegex(RuntimeError,"not mounted"):
                guard_storage(Path("/mnt/z/NightGrid-Afterhours/Visual/visual-001"))

    def test_targeted_retry(self):
        rows=[dict(j,status="pending") for j in jobs()]
        rows[0]["status"]="candidate-only"
        selected=choose_pending(rows,groups=[rows[1]["group"]],limit=2)
        self.assertEqual(len(selected),2)
        self.assertNotIn(rows[0],selected)
        with self.assertRaises(ValueError):
            choose_pending(rows,keys=["unknown.v1"])

    def test_custom_catalog_lock(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            cat=root/"new.json"
            out=root/"visual-002"
            out.mkdir()
            data={"schema":1,"batch":"visual-002","variants":3,
                  "assets":[{"id":"synaxis.example","kind":"prop","group":"synaxis","subject":"desk lamp"}]}
            cat.write_text(json.dumps(data))
            with patch("batch.CATALOG",cat),patch("batch.OUT",out),patch.dict("os.environ",{"ANUBIS_VISUAL_OUT":str(out)}):
                self.assertEqual(len(jobs()),3)
                self.assertEqual(len(jobs(True)),1)
                lock_catalog()
                lock_catalog()
                data["assets"][0]["subject"]="different lamp"
                cat.write_text(json.dumps(data))
                with self.assertRaisesRegex(ValueError,"Catalog changed"):
                    lock_catalog()

    def test_manifest(self):
        rows=jobs()
        self.assertEqual(len(rows),236)
        self.assertEqual(sum(r["kind"]=="prop" for r in rows),188)
        self.assertEqual(len(rows),len({r["key"] for r in rows}))
        self.assertEqual(jobs(),rows)
        self.assertEqual({r["kind"] for r in jobs(True)},{"prop","material"})
    def test_resume_verifies_hash_and_job(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/"concept.png"
            m=Path(d)/"image.json"
            job=jobs(True)[0]
            p.write_bytes(b"candidate")
            write_json(m,{"job":job,"sha256":digest(p)})
            self.assertTrue(verified(p,m,job))
            p.write_bytes(b"tampered")
            self.assertFalse(verified(p,m,job))

    def test_pack_only_complete_candidates(self):
        with tempfile.TemporaryDirectory() as d, patch("batch.OUT",Path(d)):
            job=jobs(True)[0]
            folder=Path(d)/"candidates"/job["key"]
            folder.mkdir(parents=True)
            for filename,meta in [("concept.png","image.json"),("mesh.glb","mesh.json")]:
                p=folder/filename
                p.write_bytes(b"candidate fixture")
                write_json(folder/meta,{"job":job,"sha256":digest(p),"input_sha256":digest(folder/"concept.png")})
            self.assertEqual(sum(r["status"]=="candidate-only" for r in inventory()),1)
            pack()
            idx=json.loads((Path(d)/"handoff/index.json").read_text())
            self.assertEqual(len(idx["packs"]),1)
            z=Path(d)/"handoff"/idx["packs"][0]["file"]
            self.assertEqual(digest(z),idx["packs"][0]["sha256"])
            with zipfile.ZipFile(z) as archive:
                self.assertEqual(len(archive.namelist()),4)
            (folder/"concept.png").write_bytes(b"changed")
            pack()
            self.assertFalse(z.exists())

if __name__=="__main__":
    unittest.main()
