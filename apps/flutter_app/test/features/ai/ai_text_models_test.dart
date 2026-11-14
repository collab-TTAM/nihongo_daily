// TEST ONLY payload mutations. Original frozen fixtures are read unchanged.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';

const id = 'abcdefab-1234-0000-ffff-abcdefabcdef';
const nil = '00000000-0000-0000-0000-000000000000';

Map<String, Object?> example() => {
  'sentence_ja': '水を飲みます。',
  'reading_ja': 'みずをのみます。',
  'translation_vi': 'Tôi uống nước.',
};

Map<String, Object?> practice() => {
  'question_ja': '水を＿＿。',
  'answer_ja': '飲みます',
  'explanation_vi': 'Điền động từ.',
};

Map<String, Object?> correction() => {
  'original_text': 'TEST ONLY original',
  'corrected_text': 'TEST ONLY corrected',
  'explanation_vi': 'TEST ONLY explanation',
  'item_refs': [
    {'item_type': 'GRAMMAR', 'item_id': id},
  ],
};

Map<String, Object?> explanation({
  Object? examples = const <Object?>[],
  Object? exercises = const <Object?>[],
}) => {
  'answer_vi': 'TEST ONLY answer',
  'examples': examples,
  'practice': exercises,
};

Map<String, Object?> corrected({
  Object? grammar = const <Object?>[],
  Object? vocabulary = const <Object?>[],
}) => {
  'corrected_sentence': '水を飲みます。',
  'natural_sentence': '水を飲みます。',
  'grammar_errors': grammar,
  'vocabulary_errors': vocabulary,
};

String repeat(String value, int count) => List.filled(count, value).join();

void main() {
  late Map<String, Object?> fixtures;
  setUpAll(() async {
    fixtures =
        jsonDecode(
              await File('../../contracts/v0.1/fixtures.json').readAsString(),
            )
            as Map<String, Object?>;
  });

  test('both request encoders match untouched frozen v0.1 fixtures', () {
    final tutor = fixtures['tutor_explain_request']! as Map<String, Object?>;
    final sentence =
        fixtures['correct_sentence_request']! as Map<String, Object?>;
    expect(
      TutorExplainRequest(
        level: AiTextLevel.n5,
        questionVi: tutor['question_vi']! as String,
      ).toJson(),
      tutor,
    );
    expect(
      CorrectSentenceRequest(
        level: AiTextLevel.n5,
        sentenceJa: sentence['sentence_ja']! as String,
      ).toJson(),
      sentence,
    );
  });

  test('both response decoders round trip untouched frozen v0.1 fixtures', () {
    final tutor = TutorExplanation.fromJson(fixtures['tutor_explain_response']);
    final sentence = SentenceCorrection.fromJson(
      fixtures['correct_sentence_response'],
    );
    expect(tutor.toJson(), fixtures['tutor_explain_response']);
    expect(tutor.examples.single.readingJa, 'みずをのみます。');
    expect(tutor.practice.single.answerJa, '飲みます');
    expect(sentence.toJson(), fixtures['correct_sentence_response']);
    expect(sentence.grammarErrors, isEmpty);
    expect(sentence.vocabularyErrors, isEmpty);
  });

  test(
    'request levels preserve all five frozen wire values without owner fields',
    () {
      expect(AiTextLevel.values.map((l) => l.wireName), [
        'N5',
        'N4',
        'N3',
        'N2',
        'N1',
      ]);
      for (final level in AiTextLevel.values) {
        final tutor = TutorExplainRequest(
          level: level,
          questionVi: ' câu hỏi ',
        );
        final sentence = CorrectSentenceRequest(
          level: level,
          sentenceJa: ' 文 ',
        );
        expect(tutor.toJson().keys, ['jlpt_level', 'question_vi', 'context']);
        expect(sentence.toJson().keys, ['jlpt_level', 'sentence_ja']);
        expect(tutor.toJson()['jlpt_level'], level.wireName);
        expect(sentence.toJson()['jlpt_level'], level.wireName);
        expect(tutor.questionVi, ' câu hỏi ');
        expect(sentence.sentenceJa, ' 文 ');
      }
    },
  );

  test(
    'context copies freezes and independently bounds both unique UUID lists',
    () {
      final grammar = [id];
      final vocabulary = [nil];
      final request = TutorExplainRequest(
        level: AiTextLevel.n4,
        questionVi: 'TEST ONLY question',
        recentGrammarIds: grammar,
        recentVocabularyIds: vocabulary,
      );
      grammar.clear();
      vocabulary[0] = id;
      expect(request.recentGrammarIds, [id]);
      expect(request.recentVocabularyIds, [nil]);
      expect(() => request.recentGrammarIds.add(nil), throwsUnsupportedError);
      expect(() => request.recentVocabularyIds.clear(), throwsUnsupportedError);
      final json = request.toJson();
      final context = json['context']! as Map<String, Object>;
      (context['recent_grammar_ids']! as List<String>).clear();
      expect(request.recentGrammarIds, [id]);
      expect(
        (request.toJson()['context']!
            as Map<String, Object>)['recent_grammar_ids'],
        [id],
      );
      final hundred = List.generate(
        100,
        (i) => '00000000-0000-0000-0000-${i.toString().padLeft(12, '0')}',
      );
      expect(
        TutorExplainRequest(
          level: AiTextLevel.n5,
          questionVi: 'x',
          recentGrammarIds: hundred,
        ).recentGrammarIds,
        hasLength(100),
      );
      for (final ids in [
        [id, id],
        [...hundred, id],
        ['bad'],
        [' $id'],
        ['$id\n'],
      ]) {
        expect(
          () => TutorExplainRequest(
            level: AiTextLevel.n5,
            questionVi: 'x',
            recentGrammarIds: ids,
          ),
          throwsFormatException,
        );
        expect(
          () => TutorExplainRequest(
            level: AiTextLevel.n5,
            questionVi: 'x',
            recentVocabularyIds: ids,
          ),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'UUID spelling nil and case-sensitive uniqueness follow frozen format',
    () {
      final request = TutorExplainRequest(
        level: AiTextLevel.n5,
        questionVi: 'x',
        recentGrammarIds: [id, id.toUpperCase(), nil],
        recentVocabularyIds: [id],
      );
      expect(request.recentGrammarIds, [id, id.toUpperCase(), nil]);
      for (final type in AiTextItemType.values) {
        final ref = AiTextItemRef.fromJson({
          'item_type': type.wireName,
          'item_id': id.toUpperCase(),
        });
        expect(ref.type, type);
        expect(ref.id, id.toUpperCase());
        expect(ref.toJson(), {
          'item_type': type.wireName,
          'item_id': id.toUpperCase(),
        });
      }
    },
  );

  test('requests count Unicode code points and retain boundary text', () {
    final limit = repeat('😀', 5000);
    expect(
      TutorExplainRequest(level: AiTextLevel.n5, questionVi: limit).questionVi,
      limit,
    );
    expect(
      CorrectSentenceRequest(
        level: AiTextLevel.n4,
        sentenceJa: limit,
      ).sentenceJa,
      limit,
    );
    for (final text in ['', '$limit😀', repeat('x', 10001)]) {
      expect(
        () => TutorExplainRequest(level: AiTextLevel.n5, questionVi: text),
        throwsFormatException,
      );
      expect(
        () => CorrectSentenceRequest(level: AiTextLevel.n5, sentenceJa: text),
        throwsFormatException,
      );
    }
    expect(
      CorrectSentenceRequest(
        level: AiTextLevel.n4,
        sentenceJa: ' か\u3099\n',
      ).sentenceJa,
      ' か\u3099\n',
    );
  });

  test('response scalar lengths use exact frozen Unicode limits', () {
    final answer = repeat('😀', 10000);
    final longTutor = explanation()..['answer_vi'] = answer;
    expect(TutorExplanation.fromJson(longTutor).answerVi, answer);
    expect(
      () => TutorExplanation.fromJson({...longTutor, 'answer_vi': '$answer😀'}),
      throwsFormatException,
    );
    for (final bad in <Object?>[null, 1, true, [], {}, '']) {
      expect(
        () => TutorExplanation.fromJson({...explanation(), 'answer_vi': bad}),
        throwsFormatException,
      );
      for (final field in ['corrected_sentence', 'natural_sentence']) {
        expect(
          () => SentenceCorrection.fromJson({...corrected(), field: bad}),
          throwsFormatException,
        );
      }
    }
    for (final field in ['corrected_sentence', 'natural_sentence']) {
      final text = repeat('😀', 5000);
      final json = corrected()..[field] = text;
      expect(SentenceCorrection.fromJson(json).toJson()[field], text);
      expect(
        () => SentenceCorrection.fromJson({...json, field: '$text😀'}),
        throwsFormatException,
      );
    }
  });

  test(
    'unknown missing mixed error and invalid top-level responses fail closed',
    () {
      for (final raw in <Object?>[
        null,
        [],
        'TEST_ONLY_SECRET',
        1,
        true,
        {
          'code': 'PROVIDER_UNAVAILABLE',
          'message_vi': 'TEST_ONLY_SECRET',
          'retryable': true,
        },
      ]) {
        expect(() => TutorExplanation.fromJson(raw), throwsFormatException);
        expect(() => SentenceCorrection.fromJson(raw), throwsFormatException);
      }
      for (final key in explanation().keys) {
        final json = explanation()..remove(key);
        expect(() => TutorExplanation.fromJson(json), throwsFormatException);
      }
      for (final key in corrected().keys) {
        final json = corrected()..remove(key);
        expect(() => SentenceCorrection.fromJson(json), throwsFormatException);
      }
      expect(
        () => TutorExplanation.fromJson({
          ...explanation(),
          'code': 'INTERNAL_ERROR',
        }),
        throwsFormatException,
      );
      expect(
        () => SentenceCorrection.fromJson({...corrected(), 'owner_id': id}),
        throwsFormatException,
      );
    },
  );

  test('null wrong scalar and unknown nested example fields are rejected', () {
    for (final field in example().keys) {
      for (final value in <Object?>[
        null,
        1,
        false,
        [],
        {},
        '',
        repeat('😀', 2001),
      ]) {
        expect(
          () => TutorExplanation.fromJson(
            explanation(
              examples: [
                {...example(), field: value},
              ],
            ),
          ),
          throwsFormatException,
        );
      }
      expect(
        AiTextExample.fromJson({
          ...example(),
          field: repeat('😀', 2000),
        }).toJson()[field],
        repeat('😀', 2000),
      );
      final missing = example()..remove(field);
      expect(() => AiTextExample.fromJson(missing), throwsFormatException);
    }
    expect(
      () =>
          AiTextExample.fromJson({...example(), 'source': 'TEST_ONLY_SECRET'}),
      throwsFormatException,
    );
  });

  test('practice requires all three bounded fields with no extra keys', () {
    for (final field in practice().keys) {
      final missing = practice()..remove(field);
      expect(() => AiTextPractice.fromJson(missing), throwsFormatException);
      for (final value in <Object?>[
        null,
        1,
        true,
        [],
        '',
        repeat('😀', 2001),
      ]) {
        expect(
          () => TutorExplanation.fromJson(
            explanation(
              exercises: [
                {...practice(), field: value},
              ],
            ),
          ),
          throwsFormatException,
        );
      }
      expect(
        AiTextPractice.fromJson({
          ...practice(),
          field: repeat('😀', 2000),
        }).toJson()[field],
        repeat('😀', 2000),
      );
    }
    expect(
      () => AiTextPractice.fromJson({...practice(), 'role': 'assistant'}),
      throwsFormatException,
    );
  });

  test(
    'response arrays accept zero and one hundred but reject oversized and wrong types',
    () {
      expect(TutorExplanation.fromJson(explanation()).examples, isEmpty);
      expect(TutorExplanation.fromJson(explanation()).practice, isEmpty);
      final tutor = TutorExplanation.fromJson(
        explanation(
          examples: List.generate(100, (_) => example()),
          exercises: List.generate(100, (_) => practice()),
        ),
      );
      expect(tutor.examples, hasLength(100));
      expect(tutor.practice, hasLength(100));
      final sentence = SentenceCorrection.fromJson(
        corrected(
          grammar: List.generate(100, (_) => correction()),
          vocabulary: List.generate(100, (_) => correction()),
        ),
      );
      expect(sentence.grammarErrors, hasLength(100));
      expect(sentence.vocabularyErrors, hasLength(100));
      for (final bad in <Object?>[
        null,
        {},
        'bad',
        1,
        List<Object?>.filled(101, null),
        [null],
      ]) {
        expect(
          () => TutorExplanation.fromJson(explanation(examples: bad)),
          throwsFormatException,
        );
        expect(
          () => TutorExplanation.fromJson(explanation(exercises: bad)),
          throwsFormatException,
        );
        expect(
          () => SentenceCorrection.fromJson(corrected(grammar: bad)),
          throwsFormatException,
        );
        expect(
          () => SentenceCorrection.fromJson(corrected(vocabulary: bad)),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'both correction lists decode full original text and all reference types',
    () {
      final refs = [
        for (final type in AiTextItemType.values)
          {'item_type': type.wireName, 'item_id': id},
      ];
      final error = correction()..['item_refs'] = refs;
      final json = corrected(grammar: [error], vocabulary: [error]);
      final result = SentenceCorrection.fromJson(json);
      expect(result.toJson(), json);
      expect(result.grammarErrors.single.originalText, 'TEST ONLY original');
      expect(
        result.vocabularyErrors.single.correctedText,
        'TEST ONLY corrected',
      );
      expect(
        result.grammarErrors.single.itemRefs.map((r) => r.type),
        AiTextItemType.values,
      );
    },
  );

  test('nested corrections require bounded text and exact keys', () {
    for (final field in ['original_text', 'corrected_text', 'explanation_vi']) {
      final missing = correction()..remove(field);
      expect(() => AiTextCorrection.fromJson(missing), throwsFormatException);
      for (final value in <Object?>[
        null,
        true,
        4,
        [],
        '',
        repeat('😀', 2001),
      ]) {
        expect(
          () => AiTextCorrection.fromJson({...correction(), field: value}),
          throwsFormatException,
        );
      }
      expect(
        AiTextCorrection.fromJson({
          ...correction(),
          field: repeat('😀', 2000),
        }).toJson()[field],
        repeat('😀', 2000),
      );
    }
    final missing = correction()..remove('item_refs');
    expect(() => AiTextCorrection.fromJson(missing), throwsFormatException);
    expect(
      () => AiTextCorrection.fromJson({
        ...correction(),
        'metadata': <String, Object?>{},
      }),
      throwsFormatException,
    );
  });

  test(
    'item references validate exact enum UUID and object shape without inventing matches',
    () {
      for (final ref in <Object?>[
        null,
        [],
        {},
        {'item_type': 'GRAMMAR'},
        {'item_type': 'grammar', 'item_id': id},
        {'item_type': 'AUDIO', 'item_id': id},
        {'item_type': 'GRAMMAR', 'item_id': 'bad'},
        {'item_type': 'GRAMMAR', 'item_id': 1},
        {'item_type': 'GRAMMAR', 'item_id': id, 'user_id': nil},
      ]) {
        expect(() => AiTextItemRef.fromJson(ref), throwsFormatException);
        expect(
          () => SentenceCorrection.fromJson(
            corrected(
              grammar: [
                {
                  ...correction(),
                  'item_refs': [ref],
                },
              ],
            ),
          ),
          throwsFormatException,
        );
      }
      // The frozen correction array has no uniqueItems rule. Preserve order and duplicates.
      final ref = {'item_type': 'KANJI', 'item_id': nil};
      final result = AiTextCorrection.fromJson({
        ...correction(),
        'item_refs': List.filled(100, ref),
      });
      expect(result.itemRefs, hasLength(100));
      expect(result.itemRefs.map((r) => r.id), everyElement(nil));
      expect(
        AiTextCorrection.fromJson({
          ...correction(),
          'item_refs': <Object?>[],
        }).itemRefs,
        isEmpty,
      );
      for (final bad in <Object?>[null, {}, 'bad', List.filled(101, ref)]) {
        expect(
          () => AiTextCorrection.fromJson({...correction(), 'item_refs': bad}),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'explanation deep copies inputs freezes arrays and exports fresh nested objects',
    () {
      final ex = example();
      final exercise = practice();
      final examples = [ex];
      final exercises = [exercise];
      final result = TutorExplanation.fromJson(
        explanation(examples: examples, exercises: exercises),
      );
      ex['reading_ja'] = 'CHANGED';
      exercise['answer_ja'] = 'CHANGED';
      examples.clear();
      exercises.clear();
      expect(result.examples.single.readingJa, 'みずをのみます。');
      expect(result.practice.single.answerJa, '飲みます');
      expect(() => result.examples.clear(), throwsUnsupportedError);
      expect(
        () => result.practice.add(result.practice.single),
        throwsUnsupportedError,
      );
      final json = result.toJson();
      ((json['examples']! as List<Object>).single
              as Map<String, Object>)['sentence_ja'] =
          'CHANGED';
      (json['practice']! as List<Object>).clear();
      expect(result.examples.single.sentenceJa, '水を飲みます。');
      expect(result.practice, hasLength(1));
      expect(
        result.toJson(),
        explanation(examples: [example()], exercises: [practice()]),
      );
    },
  );

  test('correction deep copies nested refs and freezes both error arrays', () {
    final ref = {'item_type': 'GRAMMAR', 'item_id': id};
    final refs = [ref];
    final error = correction()..['item_refs'] = refs;
    final errors = [error];
    final result = SentenceCorrection.fromJson(
      corrected(grammar: errors, vocabulary: errors),
    );
    ref['item_id'] = nil;
    refs.clear();
    error['explanation_vi'] = 'CHANGED';
    errors.clear();
    expect(result.grammarErrors.single.itemRefs.single.id, id);
    expect(
      result.vocabularyErrors.single.explanationVi,
      'TEST ONLY explanation',
    );
    expect(() => result.grammarErrors.clear(), throwsUnsupportedError);
    expect(() => result.vocabularyErrors.clear(), throwsUnsupportedError);
    expect(
      () => result.grammarErrors.single.itemRefs.clear(),
      throwsUnsupportedError,
    );
    final json = result.toJson();
    final exported =
        (json['grammar_errors']! as List<Object>).single as Map<String, Object>;
    ((exported['item_refs']! as List<Object>).single
            as Map<String, Object>)['item_id'] =
        nil;
    (json['vocabulary_errors']! as List<Object>).clear();
    expect(result.grammarErrors.single.itemRefs.single.id, id);
    expect(result.vocabularyErrors, hasLength(1));
  });

  test(
    'malformed output exposes only a constant format error with no payload echo',
    () {
      try {
        TutorExplanation.fromJson(
          explanation(
            examples: [
              {
                ...example(),
                'reading_ja': {'TEST_ONLY_SECRET': 'TEST_ONLY_PATH'},
              },
            ],
          ),
        );
        fail('Malformed response accepted');
      } on FormatException catch (error) {
        expect(error.message, 'Invalid AI text payload');
        expect(error.source, isNull);
        expect(error.toString(), isNot(contains('TEST_ONLY')));
      }
    },
  );
}
