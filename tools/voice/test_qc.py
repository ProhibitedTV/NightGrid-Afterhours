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
