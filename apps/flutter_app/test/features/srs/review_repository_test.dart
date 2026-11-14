import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/domain/srs_models.dart';

const accountA = 'a1000000-0000-4000-8000-000000000001';
const accountB = 'a1000000-0000-4000-8000-000000000002';

Map<String, Object?> successJson() => {
  'srs_state': 'REVIEW',
  'next_review_at': '2026-10-14T19:00:00.123456Z',
  'interval_days': 1,
  'difficulty': 0.5,
  'review_count': 2,
};

SrsReview review() => SrsReview(
  clientEventId: 'b2000000-0000-4000-8000-000000000001',
  itemType: LearningItemType.vocabulary,
  itemId: 'b3000000-0000-4000-8000-000000000001',
  rating: ReviewRating.good,
  isCorrect: true,
  responseMs: 123,
  occurredAt: DateTime.parse('2026-10-14T02:00:00.123456+07:00'),
);

// TEST ONLY mutable Auth and RPC ports. Not JWT/PostgREST or hosted evidence.
final class FixtureAuth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(userId: accountA);
}

final class FixtureRpc implements ReviewRpcTransport {
  Future<Object?> Function()? run;
  int calls = 0;
  final requests = <Map<String, Object>>[];
  final sessions = <ReviewSession>[];
  @override
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String function,
    required Map<String, Object> params,
  }) {
    expect(function, 'submit_review');
    expect(params.keys, ['p_request']);
    calls++;
    requests.add(params);
    sessions.add(capturedSession);
    return run?.call() ?? Future.value(successJson());
  }
}

void expectCode(
  ReviewOutcome outcome,
  ReviewErrorCode code, {
  bool retry = false,
}) {
  expect(outcome, isA<ReviewFailure>());
  final failure = outcome as ReviewFailure;
  expect(failure.code, code);
  expect(failure.retryable, retry);
  expect(failure.messageVi, isNot(contains('PRIVATE SECRET')));
}

void main() {
  test(
    'decodes exact five-field server response and retains the wire instant',
    () {
      final raw = successJson();
      final decoded = decodeReviewOutcome(raw) as ReviewSuccess;
      expect(decoded.toJson(), raw);
      expect(decoded.state, SrsState.review);
      expect(decoded.nextReviewAt.isUtc, isTrue);
      raw['difficulty'] = 0.9;
      expect(decoded.difficulty, 0.5);
    },
  );

  test(
    'all 26 TEST ONLY frozen responses decode; no local scheduling occurs',
    () {
      final fixture =
          jsonDecode(
                File('../../contracts/srs/v1/golden.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final cases = fixture['cases'] as List<dynamic>;
      expect(cases.length, 26);
      for (final entry in cases.cast<Map<String, dynamic>>()) {
        final raw = entry['expected_response'] as Map<String, dynamic>;
        final result = decodeReviewOutcome(raw);
        expect(result, isA<ReviewSuccess>(), reason: entry['name'] as String);
        expect((result as ReviewSuccess).toJson(), raw);
      }
    },
  );

  test('missing, unknown, mixed, non-object response fields fail closed', () {
    final missing = successJson()..remove('difficulty');
    final extra = successJson()..['private_owner'] = 'PRIVATE SECRET';
    for (final raw in [
      null,
      <Object>[],
      'PRIVATE SECRET',
      missing,
      extra,
      {...successJson(), 'code': 'NOT_FOUND'},
      {...successJson(), 'review_count': null},
    ]) {
      expectCode(decodeReviewOutcome(raw), ReviewErrorCode.internalError);
    }
  });

  test(
    'wrong numeric/state types, nonfinite values and bounds fail closed',
    () {
      final mutations = <String, List<Object>>{
        'srs_state': ['NEW', 'MASTERED', 'review', 2],
        'interval_days': [0, -1, '1', true, double.nan, double.infinity],
        'difficulty': [-0.1, 1.1, '0.5', false, double.nan, double.infinity],
        'review_count': [0, -1, 2.5, '2', true, maxSrsCounter + 1, double.nan],
      };
      for (final entry in mutations.entries) {
        for (final value in entry.value) {
          expectCode(
            decodeReviewOutcome({...successJson(), entry.key: value}),
            ReviewErrorCode.internalError,
          );
        }
      }
    },
  );

  test('integral JSON double counters and supported states decode', () {
    for (final state in ['LEARNING', 'REVIEW', 'RELEARNING']) {
      final decoded =
          decodeReviewOutcome({
                ...successJson(),
                'srs_state': state,
                'review_count': 2.0,
              })
              as ReviewSuccess;
      expect(decoded.reviewCount, 2);
    }
  });

  test(
    'invalid RFC3339 dates/times/offsets are never normalized into success',
    () {
      for (final value in [
        '2026-02-30T00:00:00Z',
        '2026-13-01T00:00:00Z',
        '2026-01-00T00:00:00Z',
        '0000-01-01T00:00:00Z',
        '2026-01-01T24:00:00Z',
        '2026-01-01T00:60:00Z',
        '2026-01-01T00:00:60Z',
        '2026-01-01T00:00:00+24:00',
        '2026-01-01T00:00:00+07:60',
        '2026-01-01T00:00:00',
        '2026-01-01 00:00:00Z',
        '2026-01-01T00:00:00z',
        '2026-01-01T00:00:00Z\n',
        '2026-01-01T00:00:00.Z',
        '0001-01-01T00:00:00+23:59',
        '9999-12-31T23:59:59-23:59',
        '2026-01-01T00:00:00.${List.filled(4096, '1').join()}Z',
      ]) {
        expectCode(
          decodeReviewOutcome({...successJson(), 'next_review_at': value}),
          ReviewErrorCode.internalError,
        );
      }
    },
  );

  test(
    'valid leap day/offset/fraction are preserved with UTC display precision',
    () {
      final wire = '2024-02-29T07:00:00.123456789+07:00';
      final decoded =
          decodeReviewOutcome({...successJson(), 'next_review_at': wire})
              as ReviewSuccess;
      expect(
        decoded.nextReviewAt.toIso8601String(),
        '2024-02-29T00:00:00.123456Z',
      );
      expect(decoded.nextReviewAtWire, wire);
      expect(decoded.toJson()['next_review_at'], wire);
      final boundary =
          decodeReviewOutcome({
                ...successJson(),
                'next_review_at': '2026-01-02T00:00:00+23:59',
              })
              as ReviewSuccess;
      expect(
        boundary.nextReviewAt.toIso8601String(),
        '2026-01-01T00:01:00.000Z',
      );
    },
  );

  test('all frozen safe error codes decode without displaying raw details', () {
    for (final code in ReviewErrorCode.values) {
      final result = decodeReviewOutcome({
        'code': code.wireName,
        'message_vi': 'PRIVATE SECRET',
        'retryable': false,
      });
      expectCode(result, code);
      expect((result as ReviewFailure).toJson().keys.toSet(), {
        'code',
        'message_vi',
        'retryable',
      });
    }
  });

  test('only network/provider/retryable rate errors allow immutable retry', () {
    for (final code in ReviewErrorCode.values) {
      final result = decodeReviewOutcome({
        'code': code.wireName,
        'message_vi': 'Không khả dụng',
        'retryable': true,
      });
      final allowed = [
        ReviewErrorCode.networkUnavailable,
        ReviewErrorCode.providerUnavailable,
        ReviewErrorCode.rateLimited,
      ].contains(code);
      expectCode(
        result,
        allowed ? code : ReviewErrorCode.internalError,
        retry: allowed,
      );
    }
  });

  test('malformed error objects and unknown codes fail closed', () {
    for (final raw in [
      {'code': 'NOPE', 'message_vi': 'PRIVATE SECRET', 'retryable': false},
      {'code': 'NOT_FOUND', 'message_vi': '', 'retryable': false},
      {'code': 'NOT_FOUND', 'message_vi': 'x' * 501, 'retryable': false},
      {'code': 'NOT_FOUND', 'message_vi': 12, 'retryable': false},
      {'code': 'NOT_FOUND', 'message_vi': 'Không thấy', 'retryable': 'false'},
      {
        'code': 'NOT_FOUND',
        'message_vi': 'Không thấy',
        'retryable': false,
        'sql': 'PRIVATE SECRET',
      },
      {'code': 'NOT_FOUND', 'retryable': false},
    ]) {
      expectCode(decodeReviewOutcome(raw), ReviewErrorCode.internalError);
    }
  });

  late FixtureAuth auth;
  late FixtureRpc rpc;
  late RpcReviewRepository repository;
  setUp(() {
    auth = FixtureAuth();
    rpc = FixtureRpc();
    repository = RpcReviewRepository(auth: auth, transport: rpc);
  });

  test(
    'sends only immutable seven-field p_request with captured session',
    () async {
      final pending = repository.prepare(review())!;
      expect(() => pending.request['rating'] = 0, throwsUnsupportedError);
      expect(await repository.submit(pending), isA<ReviewSuccess>());
      expect(rpc.sessions.single, same(pending.session));
      expect(rpc.requests.single['p_request'], review().toJson());
      expect(
        () => rpc.requests.single['user_id'] = accountB,
        throwsUnsupportedError,
      );
      expect(pending.request.keys.toSet(), {
        'client_event_id',
        'item_type',
        'item_id',
        'rating',
        'is_correct',
        'response_ms',
        'occurred_at',
      });
    },
  );

  test(
    'missing auth cannot prepare; logged-out token never dispatches',
    () async {
      final pending = repository.prepare(review())!;
      auth.currentSession = null;
      expect(repository.prepare(review()), isNull);
      expectCode(
        await repository.submit(pending),
        ReviewErrorCode.unauthorized,
      );
      expect(rpc.calls, 0);
    },
  );

  test('account switch and A -> B -> A invalidate prepared events', () async {
    final pending = repository.prepare(review())!;
    auth.currentSession = ReviewSession(userId: accountB);
    expectCode(await repository.submit(pending), ReviewErrorCode.unauthorized);
    auth.currentSession = ReviewSession(userId: accountA);
    expectCode(await repository.submit(pending), ReviewErrorCode.unauthorized);
    expect(rpc.calls, 0);
  });

  test(
    'in-flight old-user success is discarded after account switch',
    () async {
      final completer = Completer<Object?>();
      rpc.run = () => completer.future;
      final result = repository.submit(repository.prepare(review())!);
      auth.currentSession = ReviewSession(userId: accountB);
      completer.complete(successJson());
      expectCode(await result, ReviewErrorCode.unauthorized);
      expect(rpc.calls, 1);
    },
  );

  test('in-flight old-user failure is discarded after logout/login', () async {
    final completer = Completer<Object?>();
    rpc.run = () => completer.future;
    final result = repository.submit(repository.prepare(review())!);
    auth.currentSession = ReviewSession(userId: accountA);
    completer.completeError(
      const ReviewTransportFailure(
        ReviewErrorCode.networkUnavailable,
        retryable: true,
      ),
    );
    expectCode(await result, ReviewErrorCode.unauthorized);
  });

  test(
    'transport failure maps recognized safe code and never leaks raw errors',
    () async {
      final pending = repository.prepare(review())!;
      for (final code in ReviewErrorCode.values) {
        rpc.run = () => Future.error(ReviewTransportFailure(code));
        expectCode(await repository.submit(pending), code);
      }
      rpc.run = () => throw StateError('PRIVATE SECRET headers/token/SQL');
      expectCode(
        await repository.submit(pending),
        ReviewErrorCode.internalError,
      );
    },
  );

  test(
    'timeout stays uncertain; late result is ignored; retry has same request',
    () async {
      repository = RpcReviewRepository(
        auth: auth,
        transport: rpc,
        timeout: const Duration(milliseconds: 1),
      );
      final pending = repository.prepare(review())!;
      final completer = Completer<Object?>();
      rpc.run = () => completer.future;
      expectCode(
        await repository.submit(pending),
        ReviewErrorCode.networkUnavailable,
        retry: true,
      );
      expect(rpc.calls, 1); // No automatic redispatch.
      completer.complete(
        successJson(),
      ); // Timeout does not cancel server writes.
      rpc.run = () => Future.value(successJson()); // TEST ONLY original replay.
      expect(await repository.submit(pending), isA<ReviewSuccess>());
      expect(rpc.requests[0], rpc.requests[1]);
      expect(rpc.calls, 2);
    },
  );

  test(
    'same immutable event decodes unchanged TEST ONLY fixture replay',
    () async {
      final pending = repository.prepare(review())!;
      final original = await repository.submit(pending) as ReviewSuccess;
      // TEST ONLY server receipt fixture, no local counter/scheduler/cache authority.
      final replay = await repository.submit(pending) as ReviewSuccess;
      expect(replay.toJson(), original.toJson());
      expect(replay.reviewCount, 2);
      expect(rpc.requests[0], rpc.requests[1]);
    },
  );

  test(
    'conflict and malformed result never manufacture scheduled success',
    () async {
      final pending = repository.prepare(review())!;
      rpc.run = () => Future.value({
        'code': 'SYNC_CONFLICT',
        'message_vi': 'PRIVATE SECRET',
        'retryable': false,
      });
      expectCode(
        await repository.submit(pending),
        ReviewErrorCode.syncConflict,
      );
      rpc.run = () => Future.value({...successJson(), 'difficulty': 'bad'});
      expectCode(
        await repository.submit(pending),
        ReviewErrorCode.internalError,
      );
    },
  );

  test('invalid account and timeout configuration are rejected', () {
    expect(() => ReviewSession(userId: 'bad'), throwsArgumentError);
    expect(() => ReviewSession(userId: '$accountA\n'), throwsArgumentError);
    for (final timeout in [
      Duration.zero,
      const Duration(seconds: -1),
      const Duration(minutes: 3),
    ]) {
      expect(
        () => RpcReviewRepository(auth: auth, transport: rpc, timeout: timeout),
        throwsArgumentError,
      );
    }
  });

  test(
    'late transport exception after timeout cannot escape or auto-redispatch',
    () async {
      repository = RpcReviewRepository(
        auth: auth,
        transport: rpc,
        timeout: const Duration(milliseconds: 1),
      );
      final completer = Completer<Object?>();
      rpc.run = () => completer.future;
      final pending = repository.prepare(review())!;
      expectCode(
        await repository.submit(pending),
        ReviewErrorCode.networkUnavailable,
        retry: true,
      );
      completer.completeError(
        StateError('PRIVATE SECRET late transport details'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(rpc.calls, 1);
    },
  );
}
