import tempfile
import unittest
from pathlib import Path
import wave
from array import array

import qc
import studio


class QCTests(unittest.TestCase):
    def test_english_normalization(self):
        self.assertEqual(qc.tokens("It’s a CUSTOMER.", "English"), ["it's","a","customer"])
        self.assertEqual(qc.distance(["a","b"],["a","c","b"]),1)
        self.assertEqual(qc.distance(["a","b"],[]),2)

    def test_mandarin_not_compared_to_translation(self):
        expected=qc.tokens("上校，收到资料了吗？","Chinese")
        self.assertEqual(expected,list("上校收到资料了吗"))
        self.assertEqual(qc.distance(expected,qc.tokens("上校，收到材料了吗？","Chinese")),1)

    def test_silence_and_transcript_flags(self):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/"take.wav"
            pcm=array("h",[0]*studio.RATE+[1000,-1000]*(studio.RATE//2)+[0]*studio.RATE*2)
            import sys
            if sys.byteorder!="little":
                pcm.byteswap()
            with wave.open(str(path),"wb") as out:
                out.setparams((1,2,studio.RATE,0,"NONE","not compressed"))
                out.writeframes(pcm.tobytes())
            metrics=qc.assess(path,{"text":"Hello there.","language":"English"},"Hello")
            self.assertEqual(metrics["error_rate"],.5)
            self.assertIn("transcript_difference",metrics["flags"])
            self.assertIn("long_leading_silence",metrics["flags"])
            self.assertIn("long_trailing_silence",metrics["flags"])
            self.assertIn("mostly_quiet",metrics["flags"])

    def test_scoped_equivalence_and_real_errors(self):
        line={"id":"synaxis.conference_end.08","language":"English","text":"It was an off-site."}
        expected=qc.comparison_tokens(line["text"],line,qc.SCHEMA)
        self.assertEqual(expected,qc.comparison_tokens("It was an offsite.",line,qc.SCHEMA))
        self.assertNotEqual(expected,qc.comparison_tokens("It was a site.",line,qc.SCHEMA))
        self.assertNotEqual(qc.comparison_tokens(line["text"],line,1),qc.comparison_tokens("It was an offsite.",line,1))
        other=dict(line,id="other")
        self.assertNotEqual(qc.comparison_tokens(other["text"],other,2),qc.comparison_tokens("It was an offsite.",other,2))
        line={"id":"street.rae.soundcheck.ending","language":"English","text":"Nyx sent you?"}
        self.assertNotEqual(qc.comparison_tokens(line["text"],line,2),qc.comparison_tokens("Nick sent you?",line,2))
        line={"id":"street.nyx.soundcheck.brief","language":"English","text":"Take this demo to Rae."}
        self.assertEqual(qc.comparison_tokens(line["text"],line,2),qc.comparison_tokens("Take this demo to Ray.",line,2))

    def test_model_fingerprint_changes(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            with self.assertRaises(ValueError):
                qc.model_digest(root)
            for name in ("model.bin","config.json","tokenizer.json"):
                (root/name).write_bytes(name.encode())
            old=qc.model_digest(root)
            (root/"model.bin").write_bytes(b"changed")
            self.assertNotEqual(old,qc.model_digest(root))


if __name__=="__main__":
    unittest.main()
