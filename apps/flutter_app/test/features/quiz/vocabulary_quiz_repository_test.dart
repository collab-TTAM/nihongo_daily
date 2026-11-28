import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_repository.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the original N5 export and builds a deterministic round', () async {
    final entries = await BundledVocabularyQuizRepository().load('N5');
    expect(entries, hasLength(24));
    expect(entries.every((entry) => entry.jlptLevel == 'N5'), isTrue);

    const builder = VocabularyQuizBuilder();
    final first = builder.build(level: 'N5', entries: entries);
    final second = builder.build(level: 'N5', entries: entries);
    expect(first.status, VocabularyQuizBuildStatus.ready);
    expect(first.questions, isNotEmpty);
    expect(
      first.questions.map((question) => question.questionId).toList(),
      second.questions.map((question) => question.questionId).toList(),
    );
  });

  test('does not substitute N5 when N4 content is unavailable', () async {
    await expectLater(
      BundledVocabularyQuizRepository().load('N4'),
      throwsA(isA<QuizContentUnavailable>()),
    );
  });

  test('rejects duplicate IDs and mismatched source levels', () {
    const row = {
      'id': '17745f5e-9f28-59ac-8e19-6935ae77363b',
      'jlpt_level': 'N5',
      'content_version': 1,
      'is_active': true,
      'expression': '私',
      'reading': 'わたし',
      'meaning_vi': 'tôi',
    };
    final duplicate = jsonEncode([row, row]);
    expect(
      () => decodeVocabularyQuizEntries(duplicate, expectedLevel: 'N5'),
      throwsA(isA<FormatException>()),
    );

    final wrongLevel = jsonEncode([
      {...row, 'jlpt_level': 'N4'},
    ]);
    expect(
      () => decodeVocabularyQuizEntries(wrongLevel, expectedLevel: 'N5'),
      throwsA(isA<FormatException>()),
    );
  });
}
