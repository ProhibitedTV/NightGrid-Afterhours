#!/usr/bin/env python3
"""Isolated Git fixture tests; generated PNGs are test data, never game evidence."""
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
import zlib

from check_rc2_cockpit_gallery import FOLDER, NAMES, verify

def png(seed):
    # Deterministic test raster, intentionally not compressed for size gate.
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag+data))
    raw = b"".join(b"\0" + bytes([seed,0,0])*960 for _ in range(540))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB",960,540,8,2,0,0,0)) + chunk(b"IDAT",zlib.compress(raw,0)) + chunk(b"IEND",b"")

class Gate(unittest.TestCase):
    def setUp(self):
        self.cwd = Path.cwd()
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        os.chdir(self.temp.name)
        self.addCleanup(os.chdir,self.cwd)
        self.git("init","-q")
        self.git("config","user.name","fixture")
        self.git("config","user.email","fixture@example.invalid")
        self.write("project.godot","fixture")
        self.write("scripts/build_info.gd","version one")
        self.write("shaders/test.gdshader","shader one")
        self.write("tools/capture_cinder_cockpit.gd","fixture capture")
        self.source=self.commit("source")
        self.shots=[]
        for i,name in enumerate(NAMES):
            raw=png(i+1)
            self.write(FOLDER+name,raw)
            self.shots.append({"file":name,"sha256":hashlib.sha256(raw).hexdigest(),
                "weather":"rain" if i==2 else "clear","fov":78.0,"dashboard":{"active":True}})
        self.record={"source_revision":self.source,"engine":"4.7.2.stable","renderer":"forward_plus","resolution":[960,540],"shots":self.shots}
        self.manifest()
        self.gallery=self.commit("gallery")
        self.git("checkout","-q",self.source)
        self.write("scripts/build_info.gd","version two")
        self.candidate=self.commit("candidate")

    def git(self,*args):
        return subprocess.check_output(["git",*args],text=True).strip()

    def write(self,path,data):
        p=Path(path)
        p.parent.mkdir(parents=True,exist_ok=True)
        if isinstance(data,bytes):
            p.write_bytes(data)
        else:
            p.write_text(data)

    def manifest(self):
        self.write(FOLDER+"manifest.json",json.dumps(self.record))

    def commit(self,message):
        self.git("add",".")
        self.git("commit","-qm",message)
        return self.git("rev-parse","HEAD")

    def test_matching_candidate_accepts_version_stamp(self):
        verify(self.candidate,self.gallery)

    def test_changed_shader_rejected(self):
        self.write("shaders/test.gdshader","shader changed")
        with self.assertRaisesRegex(ValueError,"runtime differs"):
            verify(self.commit("shader change"),self.gallery)

    def test_tampered_frame_rejected(self):
        self.git("checkout","-q",self.gallery)
        self.write(FOLDER+NAMES[0],png(5))
        with self.assertRaisesRegex(ValueError,"Tampered"):
            verify(self.candidate,self.commit("tamper"))

    def test_duplicate_frame_rejected(self):
        self.git("checkout","-q",self.gallery)
        self.write(FOLDER+NAMES[1],png(1))
        self.shots[1]["sha256"]=self.shots[0]["sha256"]
        self.manifest()
        with self.assertRaisesRegex(ValueError,"duplicate"):
            verify(self.candidate,self.commit("duplicate"))

    def test_gallery_changed_capture_code_rejected(self):
        self.git("checkout","-q",self.gallery)
        self.write("tools/capture_cinder_cockpit.gd","changed")
        with self.assertRaisesRegex(ValueError,"modified runtime or capture"):
            verify(self.candidate,self.commit("changed capture"))

    def test_bad_crc_rejected(self):
        self.git("checkout","-q",self.gallery)
        raw=bytearray(png(6))
        raw[100]^=1
        self.write(FOLDER+NAMES[0],raw)
        self.shots[0]["sha256"]=hashlib.sha256(raw).hexdigest()
        self.manifest()
        with self.assertRaisesRegex(ValueError,"CRC"):
            verify(self.candidate,self.commit("corrupt png"))

if __name__=="__main__":
    unittest.main()
