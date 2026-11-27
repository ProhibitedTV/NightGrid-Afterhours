import json
import math
import struct
import unittest
from collections import Counter
from gen2_grate import WIDTH,LENGTH,DEPTH,CENTERS,INNER_Z,geometry,encode,texture_data,SOURCE,dot,sub,cross


def vertices(s):
    return list(zip(s.p[::3],s.p[1::3],s.p[2::3]))


class Gen2GrateTests(unittest.TestCase):
    def test_extents_frames_and_lods(self):
        totals=[]
        for lod in range(3):
            surfaces=geometry(lod)
            points=[p for s in surfaces for p in vertices(s)]
            self.assertEqual([round(min(p[i] for p in points),6) for i in range(3)],
                             [-WIDTH/2,-DEPTH,-LENGTH/2])
            self.assertEqual([round(max(p[i] for p in points),6) for i in range(3)],
                             [WIDTH/2,0,LENGTH/2])
            for s in surfaces:
                verts=vertices(s)
                edges=Counter()
                for j in range(0,len(s.i),3):
                    a,b,c=(verts[i] for i in s.i[j:j+3])
                    normal=cross(sub(b,a),sub(c,a))
                    self.assertGreater(dot(normal,normal),1e-16)
                    for u,v in ((a,b),(b,c),(c,a)):
                        edges[tuple(sorted((u,v)))]+=1
                self.assertTrue(all(n==2 for n in edges.values()))
                for i in range(len(verts)):
                    n=s.n[i*3:i*3+3]
                    t=s.t[i*4:i*4+3]
                    self.assertAlmostEqual(dot(n,t),0,places=6)
                    self.assertAlmostEqual(dot(n,n),1,places=6)
                    self.assertAlmostEqual(dot(t,t),1,places=6)
            totals.append(sum(len(s.i)//3 for s in surfaces))
        self.assertTrue(totals[0]>totals[1]>totals[2]>0)
        self.assertLess(totals[0],2000)

    def test_real_slots(self):
        # At X=0 a vertical line through each slot must miss every triangle.
        zpoints=[(a+b)/2 for a,b in zip((-INNER_Z,*CENTERS),(*CENTERS,INNER_Z))]
        for lod in range(3):
            for z in zpoints:
                for s in geometry(lod):
                    verts=vertices(s)
                    for j in range(0,len(s.i),3):
                        a,b,c=[verts[i] for i in s.i[j:j+3]]
                        def orient(p,q,r):
                            return (q[0]-p[0])*(r[2]-p[2])-(q[2]-p[2])*(r[0]-p[0])
                        if abs(orient(a,b,c))<1e-12:
                            continue
                        values=[orient(p,q,(0,0,z)) for p,q in ((a,b),(b,c),(c,a))]
                        self.assertFalse(min(values)>=-1e-12 or max(values)<=1e-12)

    def test_deterministic_embedded_glb(self):
        maps=texture_data(SOURCE)
        data=encode(0,maps)
        self.assertEqual(data,encode(0,maps))
        magic,v,n,j,tag=struct.unpack_from("<4sIIII",data)
        self.assertEqual((magic,v,n,tag),(b"glTF",2,len(data),0x4E4F534A))
        doc=json.loads(data[20:20+j])
        self.assertEqual(len(doc["images"]),3)
        self.assertTrue(all("bufferView" in i and "uri" not in i for i in doc["images"]))
        self.assertTrue(all("normalTexture" in m for m in doc["materials"]))
        self.assertTrue(all("TANGENT" in p["attributes"] for p in doc["meshes"][0]["primitives"]))
