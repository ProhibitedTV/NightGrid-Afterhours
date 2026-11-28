import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from neural_worker_gate import verify, REGISTRY

class NeuralGateTests(unittest.TestCase):
    def test_registry_disabled(self):
        workers=json.loads(REGISTRY.read_text())["workers"]
        self.assertTrue(all(w["state"]=="research" for w in workers))
        self.assertEqual(len({w["id"] for w in workers}),len(workers))

    def test_gate(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            def record(name):
                p=root/name;p.write_text("fixture "+name)
                return {"path":name,"sha256":hashlib.sha256(p.read_bytes()).hexdigest()}
            worker={"id":"fixture","baseline":"existing"}
            ident={"code_revision":"a"*40,"weights_revision":"b"*40,
                "weights":[record("weights.bin")],"environment_lock":record("env.txt"),
                "dependency_inventory":record("dependencies.json")}
            digest=hashlib.sha256(json.dumps(ident,sort_keys=True,separators=(",",":")).encode()).hexdigest()
            rights=dict(decision="cleared-for-commercial-production",identity_sha256=digest,
                reviewer="fixture",review_date="2026-11-28",scope="fixture",obligations="fixture",
                auxiliary_model_review="fixture",source_and_voice_rights="fixture",license_files=[record("license.txt")])
            cases=[dict(id=str(i),technical_pass=True,human_review_pass=True,
                    **{k:record(k+str(i)) for k in ("input","baseline_output","candidate_output","report")})
                   for i in range(3)]
            bench=dict(identity_sha256=digest,baseline="existing",device="RTX 3060 12GB",
                verdict="useful",offline=True,reviewer="fixture",benefit="fixture",
                peak_vram_mib=8000,peak_ram_mib=10000,elapsed_seconds=20,cases=cases)
            doc=dict(schema=1,worker="fixture",identity=ident,rights=rights,benchmark=bench)
            def save(): (root/"qualification.json").write_text(json.dumps(doc))
            save()
            self.assertFalse(verify(worker,root)["production_enabled"])
            rights["decision"]="pending";save()
            with self.assertRaises(ValueError):verify(worker,root)
            rights["decision"]="cleared-for-commercial-production";bench["peak_vram_mib"]=12000;save()
            with self.assertRaises(ValueError):verify(worker,root)
            bench["peak_vram_mib"]=8000;save()
            (root/"weights.bin").write_text("changed")
            with self.assertRaises(ValueError):verify(worker,root)
