from contextlib import redirect_stdout
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest

from scripts.export_quiz_source_order import build_projection, main

N5A = "17745f5e-9f28-559a-8e19-6935ae77363b"
N5B = "1ca82497-f4a7-55d5-9085-b0f6bddda015"
N5C = "ea196360-05d4-55e9-8aa4-1c96d9dbf4ea"
N4A = "ee2c390b-6b01-561a-892e-3d8c9e45c670"


def write_json(path: Path, value: object) -> bytes:
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode()
    path.write_bytes(raw)
    return raw


def row(item_id: str, level: str, active: bool = True, version: int = 1):
    return {"id": item_id, "jlpt_level": level, "is_active": active, "content_version": version}


class QuizSourceOrderExportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.manifest = {
            "schema_version": "0.1",
            "levels": ["N5", "N4"],
            "counts": {
                "N5": {"vocabulary": 3, "grammar": 1},
                "N4": {"vocabulary": 1, "grammar": 1},
            },
        }
        self.manifest_raw = write_json(self.root / "data/manifest.json", self.manifest)
        self.vocab_n5 = write_json(self.root / "data/n5/vocabulary.json", [
            row(N5A, "N5"), row(N5B, "N5", active=False), row(N5C, "N5", version=2)
        ])
        self.grammar_n5 = write_json(self.root / "data/n5/grammar.json", [row(N5A, "N5")])
        self.vocab_n4 = write_json(self.root / "data/n4/vocabulary.json", [row(N4A, "N4")])
        self.grammar_n4 = write_json(self.root / "data/n4/grammar.json", [row(N4A, "N4")])

    def tearDown(self):
        self.temp.cleanup()

    def test_original_array_positions_include_inactive_rows_and_reset_per_table_level(self):
        result = build_projection(self.root)
        sources = {(s["table"], s["jlpt_level"]): s for s in result["sources"]}
        self.assertEqual([r["source_ordinal"] for r in sources[("vocabulary", "N5")]["rows"]], [0, 1, 2])
        self.assertFalse(sources[("vocabulary", "N5")]["rows"][1]["is_active"])
        self.assertEqual([r["source_ordinal"] for r in sources[("vocabulary", "N4")]["rows"]], [0])
        self.assertEqual([r["source_ordinal"] for r in sources[("grammar", "N5")]["rows"]], [0])
        self.assertEqual(sources[("vocabulary", "N5")]["active_count"], 2)

    def test_projection_records_exact_source_hashes_and_manifest_hash(self):
        result = build_projection(self.root)
        self.assertEqual(result["manifest_sha256"], hashlib.sha256(self.manifest_raw).hexdigest())
        sources = {(s["table"], s["jlpt_level"]): s for s in result["sources"]}
        self.assertEqual(sources[("vocabulary", "N5")]["source_sha256"], hashlib.sha256(self.vocab_n5).hexdigest())
        self.assertEqual(sources[("grammar", "N5")]["source_sha256"], hashlib.sha256(self.grammar_n5).hexdigest())

    def test_selected_level_is_manifest_ordered_and_does_not_read_other_level(self):
        (self.root / "data/n4/grammar.json").unlink()
        result = build_projection(self.root, ["N5"])
        self.assertEqual([(s["table"], s["jlpt_level"]) for s in result["sources"]],
                         [("vocabulary", "N5"), ("grammar", "N5")])

    def test_cli_emits_valid_json_for_explicit_n5_projection(self):
        output = io.StringIO()
        with redirect_stdout(output):
            self.assertEqual(main(["--root", str(self.root), "--level", "N5"]), 0)
        decoded = json.loads(output.getvalue())
        self.assertEqual(decoded["schema_version"], "nd-quiz-source-order-1")
        self.assertEqual([s["jlpt_level"] for s in decoded["sources"]], ["N5", "N5"])

    def test_rejects_manifest_count_mismatch(self):
        self.manifest["counts"]["N5"]["vocabulary"] = 2
        write_json(self.root / "data/manifest.json", self.manifest)
        with self.assertRaisesRegex(ValueError, "count does not match manifest"):
            build_projection(self.root, ["N5"])

    def test_rejects_duplicate_ids_and_wrong_level(self):
        write_json(self.root / "data/n5/vocabulary.json", [
            row(N5A, "N5"), row(N5A, "N5"), row(N5C, "N5")
        ])
        with self.assertRaisesRegex(ValueError, "identity/metadata"):
            build_projection(self.root, ["N5"])
        write_json(self.root / "data/n5/vocabulary.json", [
            row(N5A, "N4"), row(N5B, "N5", active=False), row(N5C, "N5")
        ])
        with self.assertRaisesRegex(ValueError, "identity/metadata"):
            build_projection(self.root, ["N5"])

    def test_rejects_invalid_active_version_or_existing_source_ordinal(self):
        for changed in (
            {**row(N5A, "N5"), "is_active": 1},
            {**row(N5A, "N5"), "content_version": True},
            {**row(N5A, "N5"), "source_ordinal": 0},
        ):
            with self.subTest(changed=changed):
                write_json(self.root / "data/n5/vocabulary.json", [
                    changed, row(N5B, "N5", active=False), row(N5C, "N5")
                ])
                with self.assertRaisesRegex(ValueError, "identity/metadata"):
                    build_projection(self.root, ["N5"])

    def test_rejects_duplicate_manifest_levels_and_duplicate_json_keys(self):
        self.manifest["levels"] = ["N5", "N5"]
        write_json(self.root / "data/manifest.json", self.manifest)
        with self.assertRaisesRegex(ValueError, "manifest levels"):
            build_projection(self.root)
        (self.root / "data/manifest.json").write_text(
            '{"schema_version":"0.1","schema_version":"0.1","levels":["N5"],'
            '"counts":{"N5":{"vocabulary":3,"grammar":1}}}', encoding="utf-8"
        )
        with self.assertRaisesRegex(ValueError, "duplicate JSON key"):
            build_projection(self.root)

    def test_rejects_missing_export_file_and_unlisted_level(self):
        (self.root / "data/n5/grammar.json").unlink()
        with self.assertRaises(FileNotFoundError):
            build_projection(self.root, ["N5"])
        with self.assertRaisesRegex(ValueError, "absent or duplicated"):
            build_projection(self.root, ["N3"])

    def test_rejects_unhashable_manifest_and_requested_levels(self):
        self.manifest["levels"] = ["N5", {}]
        write_json(self.root / "data/manifest.json", self.manifest)
        with self.assertRaisesRegex(ValueError, "manifest levels"):
            build_projection(self.root)
        write_json(self.root / "data/manifest.json", {
            "schema_version": "0.1", "levels": ["N5", "N4"],
            "counts": {"N5": {"vocabulary": 3, "grammar": 1},
                       "N4": {"vocabulary": 1, "grammar": 1}},
        })
        with self.assertRaisesRegex(ValueError, "absent or duplicated"):
            build_projection(self.root, [{}])


if __name__ == "__main__":
    unittest.main()
