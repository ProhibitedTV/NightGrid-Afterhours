import json
import struct
import tempfile
from pathlib import Path
import unittest
from district_building_candidates import PARCELS, geometry, count, produce

class DistrictBuildingTests(unittest.TestCase):
    def test_geometry(self):
        for parcel,plan in PARCELS.items():
            for name,(x,z,X,Z) in plan["structures"].items():
                meshes=[geometry(name,[x,z,X,Z],lod)[0] for lod in range(3)]
                self.assertGreater(count(meshes[0]),count(meshes[1]))
                self.assertGreater(count(meshes[1]),count(meshes[2]))
                for mesh in meshes:
                    for s in mesh.values():
                        for i in range(0,len(s.p),3):
                            a,_,b=s.p[i:i+3]
                            self.assertTrue(x-1e-6<=a<=X+1e-6 and z-1e-6<=b<=Z+1e-6)
    def test_production(self):
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp)/"districts"
            produce(out)
            for parcel,plan in PARCELS.items():
                folder=out/parcel
                doc=json.loads((folder/"candidate.json").read_text())
                self.assertEqual(len(doc["outputs"]),3*len(plan["structures"])+2)
                raw=(folder/"parcel-lod2.glb").read_bytes()
                n=struct.unpack_from("<I",raw,12)[0]
                self.assertFalse(json.loads(raw[20:20+n])["images"])
            produce(out)
