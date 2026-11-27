import hashlib
import json
import math
import shutil
import struct
import sys
from pathlib import Path
import unittest
import wave

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools/audio"))
import music_mastering_export as master
import music_review_ledger as review
import music_technical_qc as qc
from test_music_review_ledger import LedgerTest


class MasteringTest(LedgerTest):
    def test_gain_preserves_dynamics_and_headroom(self):
        self.assertEqual(master.choose_gain(dict(integrated_lufs=-25, true_peak_dbtp=-10)), 6)
        self.assertEqual(master.choose_gain(dict(integrated_lufs=-30, true_peak_dbtp=-1)), -1)
        self.assertEqual(master.choose_gain(dict(integrated_lufs=-12, true_peak_dbtp=-4)), -6)
        with self.assertRaises(ValueError):
            master.choose_gain(dict(integrated_lufs=None, true_peak_dbtp=-10))

    def test_pending_selection_blocks_before_output(self):
        self.select(0)
        ledger = self.root / "ledger.json"
        ledger.write_text(json.dumps(self.ledger))
        out = self.root / "derivatives-fixture"
        with self.assertRaisesRegex(ValueError, "documented clearance"):
            master.export(self.manifest, self.qc, ledger, self.root, self.root,
                          out, "ffmpeg", "ffprobe")
        self.assertFalse(out.exists())

    @unittest.skipUnless(shutil.which("ffmpeg") and shutil.which("ffprobe"),
                         "FFmpeg and FFprobe required")
    def test_real_ogg_export_and_no_overwrite(self):
        source_manifest = json.loads(self.manifest.read_text())
        for index, row in enumerate(source_manifest["candidates"]):
            path = self.root / row["file"]
            with wave.open(str(path), "wb") as writer:
                writer.setparams((2, 2, 48000, 0, "NONE", "not compressed"))
                samples = bytearray()
                for i in range(48000):
                    value = int(3000 * math.sin(2 * math.pi * (440 + 30 * index) * i / 48000))
                    samples.extend(struct.pack("<hh", value, value))
                writer.writeframes(samples)
            row["sha256"] = review.sha256(path)
        self.manifest.write_text(json.dumps(source_manifest))
        binary, probe = shutil.which("ffmpeg"), shutil.which("ffprobe")
        report = qc.review(source_manifest, self.root, binary)
        report["measurement_engine"] = "real fixture"
        self.qc.write_text(json.dumps(report))
        data = review.inputs(self.manifest, self.qc, self.root)
        ledger = review.template(*data)
        row = ledger["reviews"][0]
        row.update(decision="selected", listening_notes="test tone only", reviewer="fixture",
                   qc_flags_reviewed=data[3][row["id"]]["flags"],
                   rights="cleared", rights_reviewer="fixture", rights_notes="test tone")
        evidence = dict(candidate_sha256=row["sha256"], checkpoint=row["checkpoint"],
                        license_reference="fixture", output_rights_basis="fixture",
                        review_date="2026-11-27")
        raw = json.dumps(evidence).encode()
        checksum = hashlib.sha256(raw).hexdigest()
        (self.root / (checksum + ".json")).write_bytes(raw)
        row["rights_evidence_sha256"] = checksum
        ledger_path = self.root / "ledger.json"
        ledger_path.write_text(json.dumps(ledger))
        out = self.root / "derivatives-fixture"
        result = master.export(self.manifest, self.qc, ledger_path, self.root, self.root,
                               out, binary, probe)
        item = result["derivatives"][0]
        self.assertEqual(item["file"], "morrow.title.theme.ogg")
        self.assertEqual(review.sha256(out / item["file"]), item["sha256"])
        self.assertEqual(item["source_sha256"], row["sha256"])
        self.assertAlmostEqual(item["duration_seconds"], 1, places=2)
        self.assertTrue((out / "derivatives.json").is_file())
        with self.assertRaisesRegex(ValueError, "Output exists"):
            master.export(self.manifest, self.qc, ledger_path, self.root, self.root,
                          out, binary, probe)


if __name__ == "__main__":
    unittest.main()
