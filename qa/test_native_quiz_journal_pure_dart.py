"""Keep the native quiz journal loadable by a standalone Dart VM child."""
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class NativeQuizJournalPureDartTests(unittest.TestCase):
    def test_native_journal_has_no_flutter_dependency(self):
        source = (
            ROOT
            / "apps/flutter_app/lib/features/quiz/data/native_vocabulary_quiz_journal.dart"
        ).read_text(encoding="utf-8")
        self.assertNotIn("package:flutter/", source)
        self.assertNotIn("dart:ui", source)
        self.assertIn(
            "TEST ONLY: inject write/flush behavior for fault-injection tests",
            source,
        )

    def test_child_fixture_uses_the_native_journal(self):
        fixture = (
            ROOT
            / "apps/flutter_app/test/features/quiz/quiz_journal_fixtures.dart"
        ).read_text(encoding="utf-8")
        test = (
            ROOT
            / "apps/flutter_app/test/features/quiz/native_vocabulary_quiz_journal_test.dart"
        ).read_text(encoding="utf-8")
        self.assertIn(
            "package:nihongo_daily/features/quiz/data/native_vocabulary_quiz_journal.dart",
            fixture,
        )
        self.assertIn("NativeVocabularyQuizJournal.open(directory)", fixture)
        self.assertIn("Process.start(", test)
        self.assertIn(
            "separate processes retain flushed data and enforce active lease",
            test,
        )


if __name__ == "__main__":
    unittest.main()
