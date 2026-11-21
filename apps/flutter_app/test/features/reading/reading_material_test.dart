import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/reading/domain/reading_material.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

// TEST ONLY minimal parser/answer fixtures, not reviewed N5/N4 curriculum.
Map<String, Object?> fixture({
  String id = 'fixture-a',
  String level = 'N5',
}) => {
  'id': id,
  'jlpt_level': level,
  'content_version': 1,
  'title_ja': '読書',
  'title_vi': 'Đọc sách',
  'text_ja': '本を読みます。\n毎日読みます。',
  'reading_ja': 'ほんをよみます。\nまいにちよみます。',
  'translation_vi': 'Tôi đọc sách mỗi ngày.',
  'source_note_vi': 'TEST ONLY, không phải bài học được duyệt.',
  'questions': <Map<String, Object?>>[
    {
      'id': 'question-1',
      'prompt_ja': '何を読みますか。',
      'reading_ja': 'なにをよみますか。',
      'prompt_vi': 'Đọc gì?',
      'choices': <Map<String, Object?>>[
        {'id': 'book', 'text_ja': '本', 'reading_ja': 'ほん', 'text_vi': 'Sách'},
        {
          'id': 'paper',
          'text_ja': '新聞',
          'reading_ja': 'しんぶん',
          'text_vi': 'Báo',
        },
      ],
      'correct_choice_id': 'book',
      'explanation_vi': 'Câu đầu nói đọc sách.',
    },
  ],
};

Map<String, Object?> question(Map<String, Object?> row) =>
    (row['questions']! as List<Map<String, Object?>>).first;

List<Map<String, Object?>> choices(Map<String, Object?> row) =>
    question(row)['choices']! as List<Map<String, Object?>>;

String catalog(List<Map<String, Object?>> rows) =>
    jsonEncode({'schema_version': 1, 'passages': rows});

ReadingPassage passage(Map<String, Object?> row) =>
    decodeReadingMaterial(catalog([row]), PreviewLevel.n5).single;

void main() {
  test(
    'strict catalog preserves readings translations order and level identity',
    () {
      final rows = [fixture(), fixture(id: 'fixture-b', level: 'N4')];
      final a = decodeReadingMaterial(catalog(rows), PreviewLevel.n5).single;
      final b = decodeReadingMaterial(catalog(rows), PreviewLevel.n4).single;
      expect(a.snapshotKey, 'n5/fixture-a/1');
      expect(b.snapshotKey, 'n4/fixture-b/1');
      expect(a.japanese, rows.first['text_ja']);
      expect(a.reading, rows.first['reading_ja']);
      expect(a.vietnamese, rows.first['translation_vi']);
      expect(a.questions.single.choices.map((c) => c.id), ['book', 'paper']);
      expect(a.questions.single.explanationVi, 'Câu đầu nói đọc sách.');
      expect(decodeReadingMaterial(catalog([]), PreviewLevel.n5), isEmpty);
      expect(
        decodeReadingMaterial(catalog([fixture()]), PreviewLevel.n4),
        isEmpty,
      );
    },
  );

  test('nested models and filtered collections cannot be mutated', () {
    final row = fixture();
    final list = decodeReadingMaterial(catalog([row]), PreviewLevel.n5);
    final a = list.single;
    question(row)['correct_choice_id'] = 'paper';
    choices(row).clear();
    expect(a.questions.single.correctChoiceId, 'book');
    expect(a.questions.single.choices, hasLength(2));
    expect(() => list.clear(), throwsUnsupportedError);
    expect(() => a.questions.clear(), throwsUnsupportedError);
    expect(() => a.questions.single.choices.clear(), throwsUnsupportedError);
  });

  test('maximum catalog question and choice counts remain valid', () {
    final rows = List.generate(50, (i) => fixture(id: 'fixture-$i'));
    expect(
      decodeReadingMaterial(catalog(rows), PreviewLevel.n5),
      hasLength(50),
    );
    final row = fixture();
    choices(row).addAll([
      {'id': 'letter', 'text_ja': '手紙', 'reading_ja': 'てがみ', 'text_vi': 'Thư'},
      {'id': 'map', 'text_ja': '地図', 'reading_ja': 'ちず', 'text_vi': 'Bản đồ'},
    ]);
    row['questions'] = List.generate(
      10,
      (i) => {...question(row), 'id': 'question-$i'},
    );
    final result = passage(row);
    expect(result.questions, hasLength(10));
    expect(result.questions.every((q) => q.choices.length == 4), isTrue);
  });

  test('schema envelope byte size and raw decoder error are bounded', () {
    for (final source in [
      'PRIVATE bad JSON',
      '[]',
      jsonEncode({'schema_version': 1.0, 'passages': <Object?>[]}),
      jsonEncode({'schema_version': 2, 'passages': <Object?>[]}),
      jsonEncode({'schema_version': 1, 'passages': null}),
      jsonEncode({
        'schema_version': 1,
        'passages': <Object?>[],
        'owner': 'PRIVATE',
      }),
      ' ' * 262145,
      'あ' * 90000,
      catalog(List.generate(51, (i) => fixture(id: 'fixture-$i'))),
    ]) {
      expect(
        () => decodeReadingMaterial(source, PreviewLevel.n5),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'safe message',
            'Invalid reading material',
          ),
        ),
      );
    }
  });

  test(
    'duplicate passage and malformed hidden level fail before filtering',
    () {
      expect(
        () => decodeReadingMaterial(
          catalog([fixture(), fixture()]),
          PreviewLevel.n5,
        ),
        throwsFormatException,
      );
      final other = fixture(id: 'fixture-b', level: 'N4');
      other['questions'] = <Object?>[];
      expect(
        () =>
            decodeReadingMaterial(catalog([fixture(), other]), PreviewLevel.n5),
        throwsFormatException,
      );
    },
  );

  test('invalid passage fields identifiers versions and text fail closed', () {
    for (final change in <Map<String, Object?>>[
      {'jlpt_level': 'N3'},
      {'jlpt_level': 'n5'},
      {'id': ''},
      {'id': 'a/b'},
      {'id': 'x' * 65},
      {'content_version': 0},
      {'content_version': 1.0},
      {'content_version': 2147483648},
      {'title_ja': ' '},
      {'text_ja': 'x' * 8193},
      {'reading_ja': null},
      {'translation_vi': '\u0000PRIVATE'},
      {'source_note_vi': ''},
      {'audio_ref': 'https://unreviewed.example/audio'},
    ]) {
      expect(() => passage({...fixture(), ...change}), throwsFormatException);
    }
    final row = fixture()..remove('source_note_vi');
    expect(() => passage(row), throwsFormatException);
  });

  test('question bounds uniqueness unknown fields and answer association', () {
    final mutations = <void Function(Map<String, Object?>)>[
      (r) => r['questions'] = <Object?>[],
      (r) => r['questions'] = List.filled(11, question(r)),
      (r) => r['questions'] = [question(r), question(r)],
      (r) => question(r)['correct_choice_id'] = 'missing',
      (r) => question(r)['prompt_vi'] = null,
      (r) => question(r)['explanation_vi'] = 'x' * 2049,
      (r) => question(r)['owner'] = 'PRIVATE',
      (r) => question(r).remove('reading_ja'),
    ];
    for (final mutate in mutations) {
      final row = fixture();
      mutate(row);
      expect(() => passage(row), throwsFormatException);
    }
  });

  test(
    'choice bounds duplicate IDs labels and invalid fields are rejected',
    () {
      final mutations = <void Function(Map<String, Object?>)>[
        (r) => question(r)['choices'] = <Object?>[],
        (r) => question(r)['choices'] = [choices(r).first],
        (r) => question(r)['choices'] = List.filled(5, choices(r).first),
        (r) => choices(r).last['id'] = 'book',
        (r) => choices(r).last['text_ja'] = ' 本 ',
        (r) => choices(r).last['reading_ja'] = '',
        (r) => choices(r).last['text_vi'] = 'x' * 513,
        (r) => choices(r).last['id'] = 'foreign/id',
        (r) => choices(r).last['score'] = 100,
      ];
      for (final mutate in mutations) {
        final row = fixture();
        mutate(row);
        expect(() => passage(row), throwsFormatException);
      }
    },
  );

  test(
    'first valid answer wins and unknown answers never complete a round',
    () {
      final round = ReadingRound(passage(fixture()));
      final key = round.passage.snapshotKey;
      expect(round.isComplete, isFalse);
      expect(round.answer(key, 'foreign', 'book'), isFalse);
      expect(round.answer(key, 'question-1', 'foreign'), isFalse);
      expect(round.acceptedAnswers, isEmpty);
      expect(round.correctCount, 0);
      expect(round.answer(key, 'question-1', 'paper'), isTrue);
      expect(round.answer(key, 'question-1', 'book'), isFalse);
      expect(round.isComplete, isTrue);
      expect(round.correctCount, 0);
      expect(round.acceptedAnswers, {'question-1': 'paper'});
      expect(() => round.acceptedAnswers.clear(), throwsUnsupportedError);
    },
  );

  test('snapshot version passage and level prevent stale callback answers', () {
    final old = passage(fixture());
    final changed = fixture()..['content_version'] = 2;
    final round = ReadingRound(passage(changed));
    for (final key in [old.snapshotKey, 'n4/fixture-a/2', 'n5/fixture-b/2']) {
      expect(round.answer(key, 'question-1', 'book'), isFalse);
    }
    expect(round.acceptedAnswers, isEmpty);
    expect(
      round.answer(round.passage.snapshotKey, 'question-1', 'book'),
      isTrue,
    );
    expect(round.correctCount, 1);
    final restarted = ReadingRound(round.passage);
    expect(restarted.acceptedAnswers, isEmpty);
    expect(restarted.isComplete, isFalse);
    expect(restarted.correctCount, 0);
  });

  test(
    'completion requires every question and deterministic mixed scoring',
    () {
      final row = fixture();
      row['questions'] = [
        question(row),
        {...question(row), 'id': 'question-2'},
      ];
      final round = ReadingRound(passage(row));
      final key = round.passage.snapshotKey;
      expect(round.answer(key, 'question-2', 'book'), isTrue);
      expect(round.isComplete, isFalse);
      expect(round.correctCount, 1);
      expect(round.answer(key, 'question-1', 'paper'), isTrue);
      expect(round.isComplete, isTrue);
      expect(round.correctCount, 1);
      expect(round.acceptedAnswers, hasLength(2));
    },
  );
}
