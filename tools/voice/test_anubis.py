import unittest
import anubis
import chapter


class AnubisTests(unittest.TestCase):
    def setUp(self):
        self.specs=chapter.validate_catalog(chapter.CATALOG)

    def test_full_catalog(self):
        selected=anubis.select(self.specs,True,[],[])
        self.assertEqual(len(selected),121)
        self.assertEqual(len(anubis.reference_ids(self.specs,selected)),15)

    def test_single_line_keeps_canonical_cast_reference(self):
        selected=anubis.select(self.specs,False,["synaxis.call_mandarin.02"],[])
        self.assertEqual(selected,["synaxis.call_mandarin.02"])
        self.assertEqual(anubis.reference_ids(self.specs,selected),{"lin":"synaxis.conference.02"})

    def test_character_and_line_union(self):
        selected=anubis.select(self.specs,False,["synaxis.conference.01"],["lin"])
        self.assertIn("synaxis.conference.01",selected)
        self.assertIn("synaxis.call_mandarin.01",selected)
        self.assertEqual(len(selected),len(set(selected)))
        self.assertTrue(all(self.specs[i]["line"]["character"] in ("jetson","lin") for i in selected))

    def test_sfx_catalog_and_groups(self):
        self.assertEqual(len(anubis.sfx_ids([],None)),37)
        self.assertEqual(len(anubis.sfx_ids([],"steps")),16)
        self.assertEqual(anubis.sfx_ids(["lift_chime"],"office"),["lift_chime"])
        with self.assertRaises(ValueError):
            anubis.sfx_ids(["lift_chime"],"steps")
        with self.assertRaises(ValueError):
            anubis.sfx_ids(["unknown"],None)

    def test_invalid_selection(self):
        for args in ((True,["synaxis.conference.01"],[]),(False,[],[]),
                     (False,["../bad"],[]),(False,[],["missing"])):
            with self.assertRaises(ValueError):
                anubis.select(self.specs,*args)


if __name__=="__main__":
    unittest.main()
