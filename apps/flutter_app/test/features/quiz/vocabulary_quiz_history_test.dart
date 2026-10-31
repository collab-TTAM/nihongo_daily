import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/curriculum/data/bundled_curriculum_repository.dart';
import 'package:nihongo_daily/features/curriculum/domain/curriculum.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_attempt.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_progress.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

const owner = 'a1000000-0000-4000-8000-000000000001';
const other = 'a1000000-0000-4000-8000-000000000002';
String eventId(int n) {
  final tail = n.toString().padLeft(12, '0');
  return 'a3000000-0000-4000-8000-$tail';
}

Map<String, Object?> copyJson(VocabularyQuizAttempt event) {
  return jsonDecode(jsonEncode(event.toJson())) as Map<String, Object?>;
}

List<Object?> rows(Map<String, Object?> json) {
  return json['answers']! as List<Object?>;
}

Map<String, Object?> row(Map<String, Object?> json, [int index = 0]) {
  return rows(json)[index]! as Map<String, Object?>;
}

VocabularyQuizAttempt variant(
  VocabularyQuizAttempt event,
  void Function(Map<String, Object?>) change,
) {
  final json = copyJson(event);
  change(json);
  return VocabularyQuizAttempt.fromJson(json);
}

QuizRound finish(List<QuizQuestion> questions, {bool correct = false}) {
  final round = QuizRound(questions);
  for (final q in questions) {
    final choice = correct
        ? q.target
        : q.choices.firstWhere((choice) => choice.id != q.target.id);
    expect(round.answer(q.id, choice.id), isTrue);
    expect(round.advance(q.id), isTrue);
  }
  return round;
}

VocabularyQuizAttempt report(
  List<QuizQuestion> questions, {
  int id = 1,
  int minute = 1,
  bool correct = false,
}) {
  return VocabularyQuizAttempt.capture(
    eventId: eventId(id),
    completedAt: DateTime.utc(2026, 10, 20, 0, minute),
    round: finish(questions, correct: correct),
  );
}

void main() {
  final originals = <PreviewLevel, List<CurriculumEntry>>{};
  final decks = <PreviewLevel, List<QuizQuestion>>{};
  setUpAll(() async {
    for (final level in PreviewLevel.values) {
      final path = '../../data/${level.name}/vocabulary.json';
      originals[level] = decodeCurriculum(
        await File(path).readAsString(),
        CurriculumKind.vocabulary,
        level,
      );
      decks[level] = buildVocabularyQuiz(originals[level]!, level);
    }
  });

  VocabularyQuizProgress derive(
    List<OwnedVocabularyQuizAttempt> history, {
    PreviewLevel level = PreviewLevel.n5,
    List<CurriculumEntry>? source,
  }) {
    return deriveVocabularyQuizProgress(
      ownerId: owner,
      level: level,
      source: source ?? originals[level]!,
      history: history,
    );
  }

  OwnedVocabularyQuizAttempt own(VocabularyQuizAttempt event) {
    return OwnedVocabularyQuizAttempt(owner, event);
  }

  for (final level in PreviewLevel.values) {
    test('${level.name} completed canonical immutable snapshot', () {
      final questions = decks[level]!.take(10).toList();
      final round = QuizRound(questions);
      for (var i = 0; i < questions.length; i++) {
        final q = questions[i];
        final choice = i.isEven
            ? q.target
            : q.choices.firstWhere((choice) => choice.id != q.target.id);
        expect(round.answer(q.id, choice.id), isTrue);
        expect(round.answer(q.id, q.target.id), isFalse);
        expect(round.advance(q.id), isTrue);
      }
      final event = VocabularyQuizAttempt.capture(
        eventId: eventId(1),
        completedAt: DateTime.utc(2026, 10, 20),
        round: round,
      );
      expect(event.score, 5);
      expect(event.level, level);
      expect(event.answers, hasLength(10));
      for (var i = 0; i < questions.length; i++) {
        final answer = event.answers[i];
        expect(answer.itemId, questions[i].target.id);
        expect(answer.contentVersion, questions[i].target.contentVersion);
        expect(answer.choices, questions[i].choices.map((choice) => choice.id));
        expect(answer.selectedId, round.acceptedAnswers[questions[i].id]);
      }
      final decoded = VocabularyQuizAttempt.fromJson(copyJson(event));
      expect(sameVocabularyQuizAttempt(event, decoded), isTrue);
      expect(() => event.answers.clear(), throwsUnsupportedError);
      expect(() => event.answers.first.choices.clear(), throwsUnsupportedError);
      final mutable = event.toJson();
      rows(mutable).clear();
      expect(event.answers, hasLength(10));
      final choices = event.answers.first.toJson()['choices']! as List<String>;
      choices.clear();
      expect(event.answers.first.choices, hasLength(4));
      expect(event.score, round.score);
    });
  }

  test('capture rejects unfinished empty mixed and invalid identity', () {
    final q = decks[PreviewLevel.n5]!.first;
    VocabularyQuizAttempt capture(QuizRound round) {
      return VocabularyQuizAttempt.capture(
        eventId: eventId(1),
        completedAt: DateTime.utc(2026),
        round: round,
      );
    }

    final round = QuizRound([q]);
    expect(() => capture(round), throwsFormatException);
    round.answer(q.id, q.target.id);
    expect(() => capture(round), throwsFormatException);
    expect(() => capture(QuizRound([])), throwsFormatException);
    final mixed = finish([q, decks[PreviewLevel.n4]!.first]);
    expect(() => capture(mixed), throwsFormatException);
    expect(
      () => VocabularyQuizAttempt.capture(
        eventId: 'PRIVATE INVALID ID',
        completedAt: DateTime.utc(2026),
        round: finish([q]),
      ),
      throwsFormatException,
    );
    expect(
      () => VocabularyQuizAttempt.capture(
        eventId: eventId(1),
        completedAt: DateTime(2026),
        round: finish([q]),
      ),
      throwsFormatException,
    );
  });

  test('accepted answer maps are immutable snapshots', () {
    final questions = decks[PreviewLevel.n5]!.take(2).toList();
    final round = QuizRound(questions);
    round.answer(questions.first.id, questions.first.target.id);
    final before = round.acceptedAnswers;
    expect(() => before.clear(), throwsUnsupportedError);
    round.advance(questions.first.id);
    round.answer(questions.last.id, questions.last.target.id);
    expect(before, hasLength(1));
    expect(round.acceptedAnswers, hasLength(2));
  });

  test('decode copies caller collections and rejects schema drift', () {
    final event = report(decks[PreviewLevel.n5]!.take(2).toList());
    final json = copyJson(event);
    final decoded = VocabularyQuizAttempt.fromJson(json);
    final choices = row(json)['choices']! as List<Object?>;
    choices.clear();
    rows(json).clear();
    expect(decoded.answers, hasLength(2));
    expect(decoded.answers.first.choices, hasLength(4));
    final good = copyJson(event);
    for (final invalid in <Object?>[
      null,
      [],
      {...good, 'owner_id': owner},
      {...good, 'score': 999},
      {...good, 'format_version': 2},
      {...good, 'format_version': 1.0},
      {...good, 'level': 'N1'},
      {...good, 'event_id': owner.toUpperCase()},
      {...good, 'completed_at': '2026-02-30T00:00:00.000Z'},
      {...good, 'completed_at': '2026-01-01T00:00:00.000+00:00'},
      {...good, 'completed_at': '1999-01-01T00:00:00.000Z'},
      {...good, 'completed_at': '2101-01-01T00:00:00.000Z'},
      {...good, 'completed_at': 'x' * 33},
      {...good, 'answers': <Object?>[]},
      {...good, 'answers': List.filled(11, rows(good).first)},
      {
        ...good,
        'answers': [rows(good).first, rows(good).first],
      },
      Map<String, Object?>.of(good)..remove('event_id'),
    ]) {
      expect(
        () => VocabularyQuizAttempt.fromJson(invalid),
        throwsFormatException,
      );
    }
  });

  test('answer decoder rejects forged selection choices and versions', () {
    final event = report([decks[PreviewLevel.n5]!.first]);
    final answer = event.answers.single.toJson();
    for (final invalid in <Object?>[
      null,
      {...answer, 'is_correct': true},
      {...answer, 'item_id': 'not-an-id'},
      {...answer, 'selected_id': other},
      {...answer, 'content_version': 0},
      {...answer, 'content_version': 1.0},
      {...answer, 'content_version': 2147483648},
      {...answer, 'choices': <Object?>[]},
      {...answer, 'choices': List.filled(4, answer['item_id'])},
      {
        ...answer,
        'choices': [owner, other, eventId(1), eventId(2)],
      },
      {...answer, 'choices': 'PRIVATE'},
    ]) {
      expect(
        () => VocabularyQuizAnswer.fromJson(invalid),
        throwsFormatException,
      );
    }
  });

  test('empty history has no invented practice or review items', () {
    final result = derive([]);
    expect(result.attemptCount, 0);
    expect(result.answerCount, 0);
    expect(result.correctCount, 0);
    expect(result.practicedCurrentItemCount, 0);
    expect(result.items, isEmpty);
    expect(result.needsReview, isEmpty);
    expect(() => result.items.clear(), throwsUnsupportedError);
    expect(() => result.needsReview.clear(), throwsUnsupportedError);
  });

  test('identical event replay does not double any counters', () {
    final event = report(decks[PreviewLevel.n5]!.take(3).toList());
    final replay = VocabularyQuizAttempt.fromJson(copyJson(event));
    final result = derive([own(event), own(replay), own(event)]);
    expect(result.attemptCount, 1);
    expect(result.answerCount, 3);
    expect(result.correctCount, 0);
    expect(result.practicedCurrentItemCount, 3);
    expect(result.items.every((item) => item.answerCount == 1), isTrue);
    expect(result.items.every((item) => item.incorrectCount == 1), isTrue);
  });

  test('changed event payload conflicts before level filter or counters', () {
    final event = report([decks[PreviewLevel.n5]!.first]);
    final original = copyJson(event);
    final changedChoice = variant(event, (json) {
      row(json)['selected_id'] = row(json)['item_id'];
    });
    final changedTime = variant(event, (json) {
      json['completed_at'] = '2026-10-20T00:02:00.000Z';
    });
    final changedOrder = variant(event, (json) {
      final choices = row(json)['choices']! as List<Object?>;
      row(json)['choices'] = choices.reversed.toList();
    });
    final otherLevel = report([decks[PreviewLevel.n4]!.first]);
    for (final conflict in [
      changedChoice,
      changedTime,
      changedOrder,
      otherLevel,
    ]) {
      expect(
        () => derive([own(event), own(conflict)]),
        throwsA(isA<VocabularyQuizHistoryConflict>()),
      );
    }
    expect(copyJson(event), original);
    expect(derive([own(event)]).attemptCount, 1);
  });

  test('foreign owner is rejected before dedup and level filtering', () {
    final event = report([decks[PreviewLevel.n5]!.first]);
    final foreign = OwnedVocabularyQuizAttempt(other, event);
    expect(() => derive([own(event), foreign]), throwsFormatException);
    expect(() => derive([foreign, own(event)]), throwsFormatException);
    final n4 = report([decks[PreviewLevel.n4]!.first], id: 2);
    expect(
      () => derive([own(event), OwnedVocabularyQuizAttempt(other, n4)]),
      throwsFormatException,
    );
    expect(
      () => OwnedVocabularyQuizAttempt('PRIVATE OWNER', event),
      throwsFormatException,
    );
    expect(
      () => deriveVocabularyQuizProgress(
        ownerId: 'PRIVATE OWNER',
        level: PreviewLevel.n5,
        source: originals[PreviewLevel.n5]!,
        history: [],
      ),
      throwsFormatException,
    );
  });

  test('wrong correct wrong preserves counts', () {
    final questions = [decks[PreviewLevel.n5]!.first];
    final first = report(questions);
    final second = report(questions, id: 2, minute: 2);
    final corrected = report(questions, id: 3, minute: 3, correct: true);
    final wrongAgain = report(questions, id: 4, minute: 4);
    final repeated = derive([own(second), own(first)]);
    expect(repeated.needsReview.single.incorrectCount, 2);
    final resolved = derive([own(corrected), own(first), own(second)]);
    expect(resolved.correctCount, 1);
    expect(resolved.items.single.answerCount, 3);
    expect(resolved.items.single.incorrectCount, 2);
    expect(resolved.needsReview, isEmpty);
    final again = derive([
      own(wrongAgain),
      own(second),
      own(corrected),
      own(first),
    ]);
    expect(again.answerCount, 4);
    expect(again.correctCount, 1);
    expect(again.needsReview.single.incorrectCount, 3);
    expect(again.needsReview.single.entry, same(questions.single.target));
  });

  test('review ranking uses errors then time then canonical identity', () {
    final questions = decks[PreviewLevel.n5]!.take(3).toList();
    final first = report(questions, minute: 1);
    final repeat = report([questions[2]], id: 2, minute: 2);
    final result = derive([own(repeat), own(first)]);
    expect(result.needsReview.first.entry, same(questions[2].target));
    final tied = questions.take(2).map((q) => q.target.id).toList()..sort();
    expect(result.needsReview.skip(1).map((item) => item.entry.id), tied);
    final later = report([questions.first], id: 3, minute: 3);
    final laterResult = derive([own(first), own(repeat), own(later)]);
    expect(laterResult.needsReview.first.entry, same(questions.first.target));
    expect(laterResult.needsReview[1].entry, same(questions[2].target));
    expect(() => laterResult.needsReview.clear(), throwsUnsupportedError);
  });

  test('equal times are stable under reverse input order', () {
    final questions = [decks[PreviewLevel.n5]!.first];
    final wrong = report(questions);
    final correct = report(questions, id: 2, correct: true);
    for (final records in [
      [own(wrong), own(correct)],
      [own(correct), own(wrong)],
    ]) {
      final result = derive(records);
      expect(result.attemptCount, 2);
      expect(result.correctCount, 1);
      expect(result.items.single.lastAnswerCorrect, isTrue);
      expect(result.needsReview, isEmpty);
    }
  });

  test('old unknown and changed-choice snapshots keep only history totals', () {
    final event = report([decks[PreviewLevel.n5]!.first]);
    final old = variant(event, (json) {
      row(json)['content_version'] = event.answers.single.contentVersion + 1;
    });
    final unknown = variant(event, (json) {
      final answer = row(json);
      final choices = answer['choices']! as List<Object?>;
      choices[choices.indexOf(answer['item_id'])] = other;
      answer['item_id'] = other;
    });
    final changedChoices = variant(event, (json) {
      final choices = row(json)['choices']! as List<Object?>;
      row(json)['choices'] = choices.reversed.toList();
    });
    for (final historical in [old, unknown, changedChoices]) {
      final result = derive([own(historical)]);
      expect(result.attemptCount, 1);
      expect(result.answerCount, 1);
      expect(result.practicedCurrentItemCount, 0);
      expect(result.needsReview, isEmpty);
    }
    final retired = derive([own(event)], source: []);
    expect(retired.answerCount, 1);
    expect(retired.items, isEmpty);
  });

  test('selected levels have independent practice and historical totals', () {
    final n5 = report(decks[PreviewLevel.n5]!.take(2).toList(), correct: true);
    final n4 = report(decks[PreviewLevel.n4]!.take(3).toList(), id: 2);
    final history = [own(n4), own(n5)];
    final first = derive(history);
    expect(first.attemptCount, 1);
    expect(first.answerCount, 2);
    expect(first.correctCount, 2);
    expect(first.needsReview, isEmpty);
    final second = derive(history, level: PreviewLevel.n4);
    expect(second.attemptCount, 1);
    expect(second.answerCount, 3);
    expect(second.correctCount, 0);
    expect(second.practicedCurrentItemCount, 3);
    expect(
      second.needsReview.every((p) => p.entry.level == PreviewLevel.n4),
      isTrue,
    );
  });

  test('history and source bounds reject before projection', () {
    final event = own(report([decks[PreviewLevel.n5]!.first]));
    expect(() => derive(List.filled(10001, event)), throwsFormatException);
    expect(
      () => derive([event], source: originals[PreviewLevel.n4]),
      throwsFormatException,
    );
    expect(
      () => derive([
        event,
      ], source: List.filled(5001, originals[PreviewLevel.n5]!.first)),
      throwsFormatException,
    );
  });
}
