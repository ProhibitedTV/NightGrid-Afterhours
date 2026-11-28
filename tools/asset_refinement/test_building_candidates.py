import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
import building_candidates as building

class BuildingCandidates(unittest.TestCase):
    def test_profiles_and_geometry(self):
        spec=building.profiles()
        self.assertEqual(spec["B1"]["width"],16.8)
        for key in building.FAMILIES:
            p=spec[key]
            near=building.geometry(p,0); far=building.geometry(p,1)
            self.assertGreater(sum(len(s.i) for s in near.values()),sum(len(s.i) for s in far.values()))
            points=[tuple(s.p[i:i+3]) for s in near.values() for i in range(0,len(s.p),3)]
            self.assertAlmostEqual(max(v[0] for v in points)-min(v[0] for v in points),p["width"])
            self.assertAlmostEqual(max(v[1] for v in points),p["height"])
            self.assertAlmostEqual(max(v[2] for v in points),p["depth"])
            self.assertAlmostEqual(min(v[2] for v in points),0)
    def test_distant_and_occlusion(self):
        for key in building.FAMILIES:
            profile=building.profiles()[key]
            near=building.geometry(profile,1)
            far=building.distant_geometry(profile)
            self.assertLess(sum(len(s.i) for s in far.values()),sum(len(s.i) for s in near.values()))
            occ=building.occlusion_candidate(profile)
            self.assertEqual(occ["triangles"],4)
            for x,y,z in occ["vertices"]:
                self.assertAlmostEqual(abs(x),profile["width"]/2-.14)
                self.assertTrue(3.6<y<profile["height"]-.62)
                self.assertTrue(.28<z<profile["depth"]-.28)
            self.assertTrue(all(0<=i<len(occ["vertices"]) for i in occ["indices"]))
    def test_lightmap_chart_separation(self):
        for profile in (building.profiles()[k] for k in building.FAMILIES):
            for lod in (0,1):
                mesh=building.geometry(profile,lod)
                uv,info=building.lightmap_uvs(mesh)
                rects=[]
                for values in uv.values():
                    for i in range(0,len(values),8):
                        x0,y0,x1,_,_,y1,_,_=values[i:i+8]
                        self.assertTrue(0<x0<x1<1 and 0<y0<y1<1)
                        rects.append((x0,y0,x1,y1))
                self.assertEqual(len(rects),info["charts"])
                for i,(a,b,c,d) in enumerate(rects):
                    for e,f,g,h in rects[:i]:
                        self.assertFalse(a<g and e<c and b<h and f<d)
                self.assertGreater(info["reference_texels_per_m"],0)
    def test_embedded_pbr_and_resume(self):
        with tempfile.TemporaryDirectory() as temp:
            out=Path(temp)/"candidates"
            building.produce(out,["B1"])
            model=out/"B1/lod0.glb"
            raw=model.read_bytes()
            magic,ver,length,n,kind=struct.unpack_from("<4sIIII",raw)
            self.assertEqual((magic,ver,length,kind),(b"glTF",2,len(raw),0x4E4F534A))
            doc=json.loads(raw[20:20+n])
            self.assertEqual(len(doc["images"]),9)
            for primitive in doc["meshes"][0]["primitives"]:
                attrs=primitive["attributes"]
                self.assertEqual(doc["accessors"][attrs["POSITION"]]["count"],doc["accessors"][attrs["TEXCOORD_1"]]["count"])
            self.assertTrue(all("bufferView" in image for image in doc["images"]))
            manifest=json.loads((out/"B1/candidate.json").read_text())
            self.assertEqual(set(manifest["outputs"]),{"lod0.glb","lod1.glb","lod2.glb","occluder.json"})
            far=(out/"B1/lod2.glb").read_bytes()
            far_json=json.loads(far[20:20+struct.unpack_from("<I",far,12)[0]])
            self.assertEqual(far_json["images"],[])
            self.assertLess(len(far),256*1024)
            building.produce(out,["B1"])
            model.write_bytes(raw+b"corrupt")
            with self.assertRaisesRegex(ValueError,"changed"):
                building.produce(out,["B1"])

if __name__=="__main__":
    unittest.main()
