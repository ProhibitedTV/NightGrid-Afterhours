"""Dependency-free regression for FFmpeg-style extensible WAV intake."""
import hashlib
from pathlib import Path
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools/audio"))
from music_pcm import pcm_info
from music_candidate_intake import validate

def chunk(name, payload):
    return name + struct.pack("<I", len(payload)) + payload + (b"\0" if len(payload) % 2 else b"")

def wav(tag=0xfffe, bits=24, guid=bytes.fromhex("0100000000001000800000aa00389b71")):
    align = 2 * bits // 8
    fmt = struct.pack("<HHIIHH", tag, 2, 48000, 48000 * align, align, bits)
    if tag == 0xfffe:
        fmt += struct.pack("<HHI", 22, bits, 3) + guid
    body = b"WAVE" + chunk(b"fmt ", fmt) + chunk(b"JUNK", b"x") + chunk(b"data", bytes(48000 * align))
    return b"RIFF" + struct.pack("<I", len(body)) + body

class MusicPCMTest(unittest.TestCase):
    def test_pcm_intake_and_rejections(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "take.wav"
            for payload, bits in ((wav(1, 16), 16), (wav(), 24)):
                path.write_bytes(payload)
                self.assertEqual(pcm_info(path), dict(seconds=1.0, sample_rate=48000, channels=2, bit_depth=bits))
                row = dict(id="test.take-01", file=path.name, sha256=hashlib.sha256(payload).hexdigest(),
                           model="ace-step", checkpoint="fixture", scene="fixture", direction="fixture",
                           rights_notes="pending", reviewed=False)
                self.assertEqual(validate(dict(schema=1, candidates=[row]), root)["verified_candidates"][0]["bits"], bits)
            for payload in (wav()[:-1], wav(3, 32), wav(guid=bytes.fromhex("0300000000001000800000aa00389b71"))):
                path.write_bytes(payload)
                with self.assertRaises(ValueError):
                    pcm_info(path)

if __name__ == "__main__":
    unittest.main()
