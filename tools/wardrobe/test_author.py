"""Small structural fixtures; these are never game assets."""
import struct
import unittest
from author import validate_weights

def fixture(joints=(0,1,2,3), weights=(0.25,0.25,0.25,0.25), integer=False):
    jb=struct.pack("<4B",*joints)
    wb=struct.pack("<4B" if integer else "<4f",*weights)
    doc={
        "accessors":[
            {"bufferView":0,"count":1,"type":"VEC4","componentType":5121},
            {"bufferView":1,"count":1,"type":"VEC4","componentType":5121 if integer else 5126,"normalized":integer}
        ],
        "bufferViews":[{"byteOffset":0,"byteLength":len(jb)},{"byteOffset":len(jb),"byteLength":len(wb)}]
    }
    return doc,jb+wb,{"JOINTS_0":0,"WEIGHTS_0":1}

class WeightValidation(unittest.TestCase):
    def verify(self, **kwargs):
        doc,raw,attrs=fixture(**kwargs)
        validate_weights(doc,raw,attrs,4)

    def test_float_and_normalized_integer(self):
        self.verify()
        self.verify(weights=(64,64,64,63),integer=True)

    def test_invalid_joint(self):
        with self.assertRaisesRegex(ValueError,"Joint index"):
            self.verify(joints=(0,1,2,4))

    def test_invalid_weight(self):
        for weights in [(float("nan"),0,0,1),(-0.1,0.1,0.5,0.5),(0,0,0,1.1)]:
            with self.subTest(weights=weights), self.assertRaisesRegex(ValueError,"Invalid weight"):
                self.verify(weights=weights)

    def test_bad_sum(self):
        with self.assertRaisesRegex(ValueError,"Unnormalized"):
            self.verify(weights=(0.1,0.1,0.1,0.1))

    def test_mismatched_counts(self):
        doc,raw,attrs=fixture()
        doc["accessors"][1]["count"]=2
        with self.assertRaises(ValueError):
            validate_weights(doc,raw,attrs,4)

    def test_integer_encoding(self):
        doc,raw,attrs=fixture(weights=(64,64,64,63),integer=True)
        doc["accessors"][1]["normalized"]=False
        with self.assertRaisesRegex(ValueError,"Integer weights"):
            validate_weights(doc,raw,attrs,4)

if __name__=="__main__":
    unittest.main()
