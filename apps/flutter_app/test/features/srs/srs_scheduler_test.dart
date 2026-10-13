import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/srs/domain/srs_models.dart';
import 'package:nihongo_daily/features/srs/domain/srs_scheduler.dart';

const itemId = '20000000-0000-4000-8000-000000000001';
const otherItemId = '20000000-0000-4000-8000-000000000002';
const eventId = '80000000-0000-4000-8000-000000000001';
final instant = DateTime.utc(2026, 10, 13, 12);
const scheduler = SrsScheduler();

SrsCard newCard({double difficulty = .5}) => SrsCard(
  itemType: LearningItemType.vocabulary,
  itemId: itemId,
  difficulty: difficulty,
);
SrsReview review(
  ReviewRating rating,
  DateTime time, {
  String id = itemId,
  LearningItemType type = LearningItemType.vocabulary,
}) => SrsReview(
  clientEventId: eventId,
  itemType: type,
  itemId: id,
  rating: rating,
  isCorrect: rating.isCorrect,
  responseMs: 1000,
  occurredAt: time,
);
SrsCard cardFromFixture(Map<String, dynamic> value) => SrsCard(
  itemType: LearningItemType.vocabulary,
  itemId: itemId,
  state: SrsState.values.singleWhere((s) => s.wireName == value['srs_state']),
  intervalDays: (value['interval_days'] as num).toDouble(),
  difficulty: (value['difficulty'] as num).toDouble(),
  reviewCount: value['review_count'] as int,
  correctCount: value['correct_count'] as int,
  incorrectCount: value['incorrect_count'] as int,
  lastReviewAt: value['last_review_at'] == null
      ? null
      : DateTime.parse(value['last_review_at'] as String),
  nextReviewAt: value['next_review_at'] == null
      ? null
      : DateTime.parse(value['next_review_at'] as String),
);

void expectFields(Map<String, Object?> actual, Map<String, dynamic> expected) {
  expect(actual.keys.toSet(), expected.keys.toSet());
  for (final key in expected.keys) {
    final value = expected[key];
    if (value is double) {
      expect(actual[key], closeTo(value, 1e-12), reason: key);
    } else {
      expect(actual[key], value, reason: key);
    }
  }
}

void main() {
  final bundle =
      jsonDecode(File('../../contracts/srs/v1/golden.json').readAsStringSync())
          as Map<String, dynamic>;
  test('golden bundle matches engine version', () {
    expect(bundle['algorithm'], SrsScheduler.version);
  });
  for (final raw in bundle['cases'] as List<dynamic>) {
    final c = raw as Map<String, dynamic>;
    test('policy golden: ${c['name']}', () {
      final input = cardFromFixture(c['before'] as Map<String, dynamic>);
      final original = input.toStateJson();
      final request = c['request'] as Map<String, dynamic>;
      final r = SrsReview(
        clientEventId: request['client_event_id'] as String,
        itemType: LearningItemType.values.singleWhere(
          (t) => t.wireName == request['item_type'],
        ),
        itemId: request['item_id'] as String,
        rating: ReviewRating.fromWire(request['rating'] as int),
        isCorrect: request['is_correct'] as bool,
        responseMs: request['response_ms'] as int,
        occurredAt: DateTime.parse(request['occurred_at'] as String),
      );
      final actual = scheduler.schedule(input, r);
      expectFields(
        actual.toStateJson(),
        c['expected_state'] as Map<String, dynamic>,
      );
      expectFields(
        actual.toReviewResponseJson(),
        c['expected_response'] as Map<String, dynamic>,
      );
      expect(input.toStateJson(), original, reason: 'input is immutable');
      expect(
        scheduler.schedule(input, r).toStateJson(),
        actual.toStateJson(),
        reason: 'no clock/random state',
      );
      expectFields(r.toJson(), {
        ...request,
        'occurred_at': r.occurredAt.toIso8601String(),
      });
    });
  }

  test('ratings match the frozen contract', () {
    final config =
        jsonDecode(
              File('../../contracts/v0.1/contract.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect({
      for (final r in ReviewRating.values) r.name.toUpperCase(): r.wireValue,
    }, config['rating_scale']);
    expect(() => ReviewRating.fromWire(-1), throwsArgumentError);
    expect(() => ReviewRating.fromWire(4), throwsArgumentError);
  });
  test('same instant in different offsets produces identical schedules', () {
    final a = scheduler.schedule(
      newCard(),
      review(ReviewRating.good, DateTime.parse('2026-10-13T19:00:00+07:00')),
    );
    final b = scheduler.schedule(
      newCard(),
      review(ReviewRating.good, DateTime.parse('2026-10-13T07:00:00-05:00')),
    );
    expect(a.toStateJson(), b.toStateJson());
    expect(a.nextReviewAt!.isUtc, isTrue);
  });
  test('sub-day intervals are not rounded to calendar days', () {
    final a = scheduler.schedule(
      newCard(),
      review(ReviewRating.again, instant),
    );
    expect(a.nextReviewAt!.difference(instant), const Duration(minutes: 1));
    expect(a.intervalDays, lessThan(1));
  });
  test('stale new review conflicts without mutating state', () {
    final card = scheduler.schedule(
      newCard(),
      review(ReviewRating.easy, instant),
    );
    final before = card.toStateJson();
    expect(
      () => scheduler.schedule(
        card,
        review(
          ReviewRating.good,
          instant.subtract(const Duration(microseconds: 1)),
        ),
      ),
      throwsA(
        isA<StaleSrsReview>().having((e) => e.code, 'code', 'SYNC_CONFLICT'),
      ),
    );
    expect(card.toStateJson(), before);
  });
  test(
    'same timestamp with a distinct event can be scheduled; receipts are external',
    () {
      final a = scheduler.schedule(
        newCard(),
        review(ReviewRating.good, instant),
      );
      final b = scheduler.schedule(
        a,
        SrsReview(
          clientEventId: '80000000-0000-4000-8000-000000000002',
          itemType: a.itemType,
          itemId: a.itemId,
          rating: ReviewRating.good,
          isCorrect: true,
          responseMs: 1,
          occurredAt: instant,
        ),
      );
      expect(b.reviewCount, 2);
      expect(b.state, SrsState.review);
    },
  );
  test('different content ID or type is rejected', () {
    expect(
      () => scheduler.schedule(
        newCard(),
        review(ReviewRating.good, instant, id: otherItemId),
      ),
      throwsArgumentError,
    );
    expect(
      () => scheduler.schedule(
        newCard(),
        review(ReviewRating.good, instant, type: LearningItemType.kanji),
      ),
      throwsArgumentError,
    );
  });
  test('every item type uses the same canonical scheduling policy', () {
    for (final type in LearningItemType.values) {
      final card = SrsCard(itemType: type, itemId: itemId);
      final result = scheduler.schedule(
        card,
        review(ReviewRating.easy, instant, type: type),
      );
      expect(result.itemType, type);
      expect(result.intervalDays, 4);
    }
  });
  test('MASTERED is reserved and never emitted by v1', () {
    final reserved = SrsCard(
      itemType: LearningItemType.vocabulary,
      itemId: itemId,
      state: SrsState.mastered,
      intervalDays: 1,
      reviewCount: 1,
      correctCount: 1,
      lastReviewAt: instant,
      nextReviewAt: instant.add(const Duration(days: 1)),
    );
    expect(
      () => scheduler.schedule(reserved, review(ReviewRating.good, instant)),
      throwsArgumentError,
    );
  });
  test('long successful learning history obeys bounds and counters', () {
    var card = newCard();
    for (var i = 0; i < 300; i++) {
      final time = card.nextReviewAt ?? instant;
      final rating = ReviewRating.values[i % 4];
      card = scheduler.schedule(card, review(rating, time));
      expect(card.reviewCount, i + 1);
      expect(card.correctCount + card.incorrectCount, card.reviewCount);
      expect(card.difficulty, inInclusiveRange(0, 1));
      expect(
        card.intervalDays,
        inInclusiveRange(1 / 1440, SrsScheduler.maxIntervalDays),
      );
      expect(card.state, isNot(SrsState.mastered));
      expect(card.nextReviewAt!.isAfter(time), isTrue);
      expect(
        card.nextReviewAt!.difference(time).inMicroseconds / 86400000000,
        card.intervalDays,
      );
    }
  });
  test('success interval ordering is monotone at due and overdue times', () {
    for (final d in [0.0, .5, 1.0]) {
      final card = SrsCard(
        itemType: LearningItemType.vocabulary,
        itemId: itemId,
        state: SrsState.review,
        intervalDays: 10,
        difficulty: d,
        reviewCount: 1,
        correctCount: 1,
        lastReviewAt: instant,
        nextReviewAt: instant.add(const Duration(days: 10)),
      );
      for (final late in [0, 1, 100]) {
        final time = instant.add(Duration(days: 10 + late));
        final hard = scheduler.schedule(card, review(ReviewRating.hard, time));
        final good = scheduler.schedule(card, review(ReviewRating.good, time));
        final easy = scheduler.schedule(card, review(ReviewRating.easy, time));
        expect(hard.intervalDays, lessThanOrEqualTo(good.intervalDays));
        expect(good.intervalDays, lessThanOrEqualTo(easy.intervalDays));
      }
    }
  });
  test('repeated early taps cannot compound a long scheduled interval', () {
    var card = scheduler.schedule(
      newCard(),
      review(ReviewRating.easy, instant),
    );
    for (var i = 0; i < 50; i++) {
      card = scheduler.schedule(card, review(ReviewRating.good, instant));
      expect(card.intervalDays, lessThanOrEqualTo(2.5));
    }
  });
  test('malformed typed request boundaries fail', () {
    for (final ms in [-1, 3600001]) {
      expect(
        () => SrsReview(
          clientEventId: eventId,
          itemType: LearningItemType.vocabulary,
          itemId: itemId,
          rating: ReviewRating.good,
          isCorrect: true,
          responseMs: ms,
          occurredAt: instant,
        ),
        throwsArgumentError,
      );
    }
    for (final r in ReviewRating.values) {
      expect(
        () => SrsReview(
          clientEventId: eventId,
          itemType: LearningItemType.vocabulary,
          itemId: itemId,
          rating: r,
          isCorrect: !r.isCorrect,
          responseMs: 1,
          occurredAt: instant,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => SrsReview(
        clientEventId: 'bad',
        itemType: LearningItemType.vocabulary,
        itemId: itemId,
        rating: ReviewRating.good,
        isCorrect: true,
        responseMs: 1,
        occurredAt: instant,
      ),
      throwsArgumentError,
    );
    expect(() => newCard().toReviewResponseJson(), throwsStateError);
  });
  test('request boundary values encode without owner or derived fields', () {
    for (final ms in [0, 3600000]) {
      final r = SrsReview(
        clientEventId: eventId.toUpperCase(),
        itemType: LearningItemType.vocabulary,
        itemId: itemId,
        rating: ReviewRating.good,
        isCorrect: true,
        responseMs: ms,
        occurredAt: instant,
      );
      expect(r.toJson().keys.toSet(), {
        'client_event_id',
        'item_type',
        'item_id',
        'rating',
        'is_correct',
        'response_ms',
        'occurred_at',
      });
      expect(r.clientEventId, eventId);
    }
  });
  test('invalid persisted state and non-finite values are rejected', () {
    for (final d in [-.1, 1.1, double.nan, double.infinity]) {
      expect(() => newCard(difficulty: d), throwsArgumentError);
    }
    expect(
      () => SrsCard(
        itemType: LearningItemType.vocabulary,
        itemId: itemId,
        intervalDays: double.infinity,
      ),
      throwsArgumentError,
    );
    expect(
      () => SrsCard(
        itemType: LearningItemType.vocabulary,
        itemId: itemId,
        reviewCount: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => SrsCard(
        itemType: LearningItemType.vocabulary,
        itemId: itemId,
        state: SrsState.review,
      ),
      throwsArgumentError,
    );
    expect(
      () => SrsCard(itemType: LearningItemType.vocabulary, itemId: '$itemId\n'),
      throwsArgumentError,
    );
  });
  test('database counter overflow fails instead of wrapping', () {
    final card = SrsCard(
      itemType: LearningItemType.vocabulary,
      itemId: itemId,
      state: SrsState.review,
      intervalDays: 1,
      reviewCount: maxSrsCounter,
      correctCount: maxSrsCounter,
      lastReviewAt: instant,
      nextReviewAt: instant.add(const Duration(days: 1)),
    );
    expect(
      () => scheduler.schedule(card, review(ReviewRating.good, instant)),
      throwsRangeError,
    );
  });
  test('unrepresentable RFC3339 output cannot escape validation', () {
    expect(
      () => scheduler.schedule(
        newCard(),
        review(ReviewRating.easy, DateTime.utc(9999, 12, 31)),
      ),
      throwsArgumentError,
    );
  });
}
