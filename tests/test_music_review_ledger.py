import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
import wave

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools/audio"))
import music_review_ledger as review


class LedgerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.manifest = self.root / "manifest.json"
        self.qc = self.root / "qc.json"
        self.ids = ["morrow.title.theme.take-01", "morrow.title.theme.take-02"]
        masters, rows = [], []
        for index, ident in enumerate(self.ids):
            path = self.root / (ident + ".wav")
            with wave.open(str(path), "wb") as wav:
                wav.setparams((2, 2, 48000, 0, "NONE", "not compressed"))
                wav.writeframes(bytes([index, 0, index, 0]) * 48000)
            checksum = review.sha256(path)
            masters.append(dict(id=ident, file=path.name, sha256=checksum,
                                model="ace-step", checkpoint="fixture-checkpoint",
                                scene="title", direction="original", rights_notes="pending",
                                reviewed=False))
            rows.append(dict(id=ident, sha256=checksum, model="ace-step",
                             duration_seconds=1.0, sample_rate=48000, bits=16,
                             measurements=dict(integrated_lufs=-20, true_peak_dbtp=-3,
                                               full_scale_samples_left=0, full_scale_samples_right=0,
                                               wrap_sample_jump_fraction=0),
                             flags=["listen"]))
        self.manifest.write_text(json.dumps(dict(schema=1, candidates=masters)))
        self.qc.write_text(json.dumps(dict(schema=1, mode="read-only; no approval or publish",
                                           measurement_engine="fixture", candidate_count=2, candidates=rows)))
        self.data = review.inputs(self.manifest, self.qc, self.root)
        self.ledger = review.template(*self.data)

    def verify(self):
        return review.verify_ledger(self.ledger, *self.data, evidence_root=self.root)

    def select(self, index):
        self.ledger["reviews"][index].update(decision="selected", listening_notes="listened",
                                              reviewer="fixture reviewer", qc_flags_reviewed=["listen"])

    def test_pending_is_not_selected(self):
        self.assertEqual(self.verify()["documented_selection_and_rights"], [])

    def test_selection_requires_notes_and_flags(self):
        self.ledger["reviews"][0]["decision"] = "selected"
        with self.assertRaisesRegex(ValueError, "Missing review field"):
            self.verify()
        self.select(0)
        self.ledger["reviews"][0]["qc_flags_reviewed"] = []
        with self.assertRaisesRegex(ValueError, "QC flags"):
            self.verify()
        self.select(0)
        self.assertEqual(self.verify()["selected"], {"morrow.title.theme": self.ids[0]})
        self.assertEqual(self.verify()["documented_selection_and_rights"], [])

    def test_two_selected_rejected(self):
        self.select(0)
        self.select(1)
        with self.assertRaisesRegex(ValueError, "Multiple selected"):
            self.verify()

    def test_rights_evidence_and_model_binding(self):
        self.select(0)
        row = self.ledger["reviews"][0]
        evidence = dict(candidate_sha256=row["sha256"], checkpoint=row["checkpoint"],
                        license_reference="fixture only", output_rights_basis="fixture only",
                        review_date="2026-11-27")
        payload = json.dumps(evidence).encode()
        checksum = hashlib.sha256(payload).hexdigest()
        path = self.root / (checksum + ".json")
        path.write_bytes(payload)
        row.update(rights="cleared", rights_reviewer="fixture reviewer",
                   rights_notes="fixture only", rights_evidence_sha256=checksum)
        self.assertEqual(self.verify()["documented_selection_and_rights"], [self.ids[0]])
        path.write_text("changed")
        with self.assertRaisesRegex(ValueError, "evidence file mismatch"):
            self.verify()
        path.write_bytes(payload)
        self.data[2][self.ids[0]]["model"] = "audiocraft-musicgen"
        with self.assertRaisesRegex(ValueError, "research only"):
            self.verify()

    def test_stale_qc_or_missing_review(self):
        self.ledger["reviews"].pop()
        with self.assertRaisesRegex(ValueError, "complete candidate"):
            self.verify()
        self.ledger = review.template(*self.data)
        self.qc.write_text(self.qc.read_text() + "\n")
        fresh = review.inputs(self.manifest, self.qc, self.root)
        with self.assertRaisesRegex(ValueError, "stale"):
            review.verify_ledger(self.ledger, *fresh)


if __name__ == "__main__":
    unittest.main()
