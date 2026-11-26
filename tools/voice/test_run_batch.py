from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import run_batch


class BatchTests(unittest.TestCase):
    def test_chunks_and_remaining(self):
        self.assertEqual(run_batch.chunks(list(range(25)),12),[list(range(12)),list(range(12,24)),[24]])
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            (root/"done").mkdir()
            self.assertEqual(run_batch.remaining({"done":{},"todo":{}},root),["todo"])

    def test_retry_skips_published(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            specs={"a":{},"b":{}}
            calls=[]
            def fake(cmd, **kwargs):
                calls.append(cmd)
                (root/"a").mkdir(exist_ok=True)
            with patch.object(run_batch,"remaining",side_effect=lambda specs: [i for i in specs if not (root/i).is_dir()]), patch.object(run_batch.production,"verify_library"), patch.object(run_batch,"command",side_effect=fake):
                run_batch.voice_pass(specs,[312,314],[],"cuda")
            self.assertIn("a",calls[0])
            self.assertNotIn("a",calls[1])
            self.assertIn("b",calls[1])
            self.assertIn("--auto-playtest",calls[1])
            self.assertIn("--rights-checked",calls[1])


if __name__ == "__main__":
    unittest.main()
