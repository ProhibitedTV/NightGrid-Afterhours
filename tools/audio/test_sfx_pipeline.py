"""CPU-only tests of the authoring path; no model or GPU dependency."""
import array
import math
import tempfile
import unittest
import wave
from pathlib import Path
import shutil
import generate_sfx as sfx


class AuthoringTests(unittest.TestCase):
    def test_manifest(self):
        import json
        data = json.loads(sfx.MANIFEST.read_text(encoding="utf-8"))
        assets = data["assets"]
        ids = [x["id"] for x in assets]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(len(ids), 38)
        self.assertTrue(all(x["duration"] > 0 and x["prompt"] for x in assets))
        self.assertTrue(next(x for x in assets if x["id"] == "lift_motor")["loop"])

    def test_partial_library_and_provenance(self):
        import json
        import sfx_batch
        with tempfile.TemporaryDirectory() as tmp:
            dest=Path(tmp)
            manifest={"model":"small-sfx","weights":"weights","license":"license",
                      "assets":[{"id":"a","duration":1,"loop":False},{"id":"b","duration":1,"loop":True}]}
            self.assertEqual(sfx.verify_staged_library(manifest,dest),[])
            wav=dest/"a.wav"
            meta=dest/"a.json"
            with wave.open(str(wav),"wb") as stream:
                stream.setparams((1,2,sfx.RATE,0,"NONE","not compressed"))
                stream.writeframes(array.array("h",[1000,-1000]*24000).tobytes())
            with self.assertRaisesRegex(ValueError,"Incomplete"):
                sfx.verify_staged_library(manifest,dest)
            record={"spec":manifest["assets"][0],"sha256":sfx.digest(wav),
                    "model":"small-sfx","weights":"weights","license":"license",
                    "reviewed":False,"playtest_accepted":True,"rights_checked":True,
                    "machine_qc_passed":True,"metrics":sfx_batch.metrics(wav,manifest["assets"][0]),
                    "provenance":{"repo":"stabilityai/stable-audio-3-small-sfx",
                                  "revision":"a"*40,"upstream":"b"*40}}
            meta.write_text(json.dumps(record))
            self.assertEqual(sfx.verify_staged_library(manifest,dest),[{"id":"a","loop":False,"reviewed":False}])
            record["rights_checked"]=False
            meta.write_text(json.dumps(record))
            with self.assertRaisesRegex(ValueError,"acceptance"):
                sfx.verify_staged_library(manifest,dest)
            record["rights_checked"]=True
            record["sha256"]="0"*64
            meta.write_text(json.dumps(record))
            with self.assertRaisesRegex(ValueError,"provenance"):
                sfx.verify_staged_library(manifest,dest)

    @unittest.skipUnless(shutil.which("ffmpeg"), "FFmpeg required for conversion")
    def test_loop_and_oneshot(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "test.wav"
            samples = array.array("h", (int(2000*math.sin(i*math.tau*110/sfx.RATE)) for i in range(sfx.RATE*2)))
            with wave.open(str(source), "wb") as wav:
                wav.setparams((1,2,sfx.RATE,0,"NONE","not compressed"))
                wav.writeframes(samples.tobytes())
            for loop in (False, True):
                dest = root / f"{loop}.wav"
                sfx.prepare(source, dest, {"duration":2,"loop":loop}, "ffmpeg")
                data = sfx.read_pcm(dest)
                self.assertLess(max(abs(x) for x in data), 24000)
                self.assertEqual(len(data), sfx.RATE*2 - (sfx.RATE//4 if loop else 0))
                if not loop:
                    self.assertEqual(data[0],0)
                    self.assertEqual(data[-1],0)
                else:
                    self.assertLess(abs(data[0]-data[-1]),1000)


if __name__ == "__main__":
    unittest.main()
