import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from handoff import MATERIAL_GATES
from refine import sha,write
from stage_bundle import validate,stage


def fixture(root):
    approval={"candidate":"material.fixture.v1","signature":"a"*64,"kind":"material",
              "reviewer":"fixture","rights_notes":"synthetic test only",
              "review":{k:{"passed":True,"evidence":"fixture"} for k in MATERIAL_GATES}}
    temp=root/"temp"
    rel=Path("assets/art/approved/anubis")/approval["candidate"]
    files=temp/"repo-tree"/rel
    files.mkdir(parents=True)
    for n in ("basecolor.png","normal.png","orm.png","source-image.json"):
        (files/n).write_bytes(b"synthetic test only")
    meta={"candidate":approval["candidate"],"signature":approval["signature"],"status":"unapproved",
          "settings":{"size":512,"source":{"metadata":sha(files/"source-image.json")}},
          "outputs":{n:{"sha256":sha(files/n)} for n in ("basecolor.png","normal.png","orm.png")}}
    write(files/"material.json",meta)
    approval["manifest_sha256"]=sha(files/"material.json")
    write(files/"approval.json",approval)
    ident=hashlib.sha256(json.dumps({"schema":1,"assets":[approval]},sort_keys=True).encode()).hexdigest()
    bundle=root/ident
    temp.rename(bundle)
    rows=[{"path":(rel/p.name).as_posix(),"sha256":sha(p),"bytes":p.stat().st_size}
          for p in sorted((bundle/"repo-tree"/rel).iterdir())]
    write(bundle/"bundle.json",{"schema":1,"id":ident,"status":"operator-reviewed-staged-not-committed","files":rows})
    return bundle,rel


class StageTests(unittest.TestCase):
    def test_preview_apply_and_tamper(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            bundle,rel=fixture(root)
            repo=root/"repo"
            repo.mkdir()
            def git(*a):
                return subprocess.check_output(["git","-C",str(repo),*a])
            git("init","-b","review")
            git("-c","user.name=Fixture","-c","user.email=fixture@example.invalid","commit","--allow-empty","-m","fixture")
            self.assertEqual(len(validate(bundle)),6)
            stage(bundle,repo)
            self.assertFalse((repo/rel).exists())
            stage(bundle,repo,True)
            self.assertEqual(len(git("diff","--cached","--name-only").splitlines()),6)
            self.assertEqual(len(git("log","--oneline").splitlines()),1)
            with self.assertRaises(ValueError):
                stage(bundle,repo,True)
            (bundle/"repo-tree"/rel/"normal.png").write_bytes(b"tamper")
            with self.assertRaises(ValueError):
                validate(bundle)
