// TEST ONLY local reports. No Auth, hosted service or curriculum evidence.
import 'dart:io';

import 'package:nihongo_daily/features/quiz/data/native_vocabulary_quiz_journal.dart';
import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_attempt.dart';

const quizOwner = 'a1000000-0000-4000-8000-000000000001';
const quizOther = 'a1000000-0000-4000-8000-000000000002';
const quizTarget = 'a2000000-0000-4000-8000-000000000001';
const quizWrong = 'a2000000-0000-4000-8000-000000000002';
const quizChoices = [
  quizTarget,
  quizWrong,
  'a2000000-0000-4000-8000-000000000003',
  'a2000000-0000-4000-8000-000000000004',
];

VocabularyQuizAttempt quizReport(int number, {bool correct = false}) {
  final tail = number.toString().padLeft(12, '0');
  return VocabularyQuizAttempt.fromJson({
    'format_version': 1,
    'event_id': 'a3000000-0000-4000-8000-$tail',
    'level': 'N5',
    'completed_at': '2026-10-20T00:01:00.000Z',
    'answers': [
      {
        'item_id': quizTarget,
        'content_version': 1,
        'selected_id': correct ? quizTarget : quizWrong,
        'choices': quizChoices,
      },
    ],
  });
}

File quizData(Directory directory) =>
    File('${directory.path}${Platform.pathSeparator}quiz-attempts.ndjson');

/// Child deliberately exits after flush without graceful close to test restart.
/// A separate child also checks the OS lease, beyond the isolate-local guard.
Future<void> main(List<String> args) async {
  if (args.length != 2) exit(2);
  final directory = Directory(args[1]);
  if (args[0] == 'stage') {
    final journal = await NativeVocabularyQuizJournal.open(directory);
    await journal.append(quizOwner, quizReport(1));
    exit(0);
  }
  if (args[0] == 'locked') {
    try {
      final journal = await NativeVocabularyQuizJournal.open(directory);
      await journal.close();
      exit(3);
    } on VocabularyQuizStorageFailure {
      exit(0);
    }
  }
  exit(2);
}
