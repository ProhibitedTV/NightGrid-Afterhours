import json
from pathlib import Path
import tempfile
import unittest

import chapter
import studio


class ChapterTests(unittest.TestCase):
    def test_catalog_matches_pinned_spoken_source(self):
        specs=chapter.validate_catalog(chapter.CATALOG)
        self.assertEqual(len(specs),27)
        self.assertEqual(len({s["line"]["character"] for s in specs.values()}),6)
        chinese=[s["line"] for s in specs.values() if s["line"]["language"]=="Chinese"]
        self.assertEqual(len(chinese),2)
        self.assertTrue(all(s["caption"] and s["text"]!=s["caption"] for s in chinese))

    def test_live_source_parity_and_drift(self):
        data=json.loads(chapter.CATALOG.read_text(encoding="utf-8"))
        constants=data["source"]["constants"]
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/"opening.gd"
            path.write_text("\n".join(f"const {k} = {json.dumps(v,ensure_ascii=False)}" for k,v in constants.items()),encoding="utf-8")
            self.assertEqual(len(chapter.validate_catalog(chapter.CATALOG,path)),27)
            path.write_text(path.read_text(encoding="utf-8").replace("close the blinds","open the blinds"),encoding="utf-8")
            with self.assertRaises(ValueError):
                chapter.validate_catalog(chapter.CATALOG,path)

    def test_changed_catalog_text_rejected(self):
        data=json.loads(chapter.CATALOG.read_text(encoding="utf-8"))
        data["lines"][0]["text"]="Unrelated speech"
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/"manifest.json"
            studio.write_json(path,data)
            with self.assertRaises(ValueError):
                chapter.validate_catalog(path)

    def test_empty_inventory_is_not_complete(self):
        specs=chapter.validate_catalog(chapter.CATALOG)
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            rows=chapter.status(specs,root/"cast",root/"takes",root/"published")
            self.assertEqual(len(rows),27)
            self.assertTrue(all(x["state"]=="needs_cast" for x in rows))


if __name__=="__main__":
    unittest.main()
