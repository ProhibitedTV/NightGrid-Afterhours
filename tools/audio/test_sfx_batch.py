import json
from pathlib import Path
import tempfile
import unittest
import wave
from array import array

import sfx_batch as batch
import generate_sfx as sfx


class BatchSfxTests(unittest.TestCase):
    def test_stage_is_provisional_idempotent_and_refuses_replacement(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            wav=root/"fixture.wav"
            meta=root/"fixture.json"
            spec={"id":"fixture","duration":1,"loop":False}
            with wave.open(str(wav),"wb") as f:
                f.setparams((1,2,48000,0,"NONE","not compressed"))
                f.writeframes(array("h",[1000,-1000]*24000).tobytes())
            pin={"repo":"fixture","revision":"a"*40,"upstream":"b"*40,"steps":8,"cfg_scale":1.0}
            batch.write_json(meta,{"spec":spec,"sha256":sfx.digest(wav),"provenance":pin,
                                    "metrics":batch.metrics(wav,spec),"machine_qc_passed":True,
                                    "reviewed":False})
            dest=root/"published"
            batch.stage_candidate(wav,meta,spec,pin,dest)
            batch.stage_candidate(wav,meta,spec,pin,dest)
            record=json.loads((dest/meta.name).read_text())
            self.assertFalse(record["reviewed"])
            self.assertTrue(record["playtest_accepted"])
            self.assertEqual(sfx.digest(dest/wav.name),sfx.digest(wav))
            (dest/wav.name).write_bytes(b"other asset")
            with self.assertRaises(FileExistsError):
                batch.stage_candidate(wav,meta,spec,pin,dest)

if __name__=="__main__":
    unittest.main()
