import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/srs/application/srs_study_controller.dart';
import 'package:nihongo_daily/features/srs/application/srs_study_provider.dart';
import 'package:nihongo_daily/features/srs/data/review_connection_registry.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/domain/srs_models.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

const a = '11111111-1111-4111-8111-111111111111';
const b = '22222222-2222-4222-8222-222222222222';
const envelope = <String, Object>{
  'p_request': <String, Object>{'jlpt_level': 'N5', 'limit': 100},
};
final unauthorized = isA<ReviewTransportFailure>().having(
  (failure) => failure.code,
  'code',
  ReviewErrorCode.unauthorized,
);

void main() {
  late DateTime now;
  late ReviewConnectionRegistry registry;
  Future<Object?> fixture(String _, Map<String, Object> __) async => null;
  void begin(String user, {CapturedReviewRpc? rpc}) => registry.begin(
    userId: user,
    expiresAt: now.add(const Duration(hours: 1)),
    rpc: rpc ?? fixture,
  );
  Future<Object?> invoke(ReviewSession session) => registry.invoke(
    capturedSession: session,
    function: 'get_review_queue',
    params: envelope,
  );
  setUp(() {
    now = DateTime.utc(2026, 10, 14);
    registry = ReviewConnectionRegistry(now: () => now);
  });
  tearDown(() => registry.dispose());

  test(
    'same-event retry survives refresh but never same-user re-login',
    () async {
      final requests = <Map<String, Object>>[];
      begin(
        a,
        rpc: (_, params) async {
          requests.add(params['p_request'] as Map<String, Object>);
          throw TimeoutException('TEST ONLY unknown server outcome');
        },
      );
      final repository = RpcReviewRepository(
        auth: registry,
        transport: registry,
      );
      final prepared = repository.prepare(
        SrsReview(
          clientEventId: b,
          itemType: LearningItemType.vocabulary,
          itemId: a,
          rating: ReviewRating.good,
          isCorrect: true,
          responseMs: 321,
          occurredAt: now,
        ),
      )!;
      expect(await repository.submit(prepared), isA<ReviewFailure>());
      registry.refresh(
        userId: a,
        expiresAt: now.add(const Duration(hours: 2)),
        rpc: (_, params) async {
          requests.add(params['p_request'] as Map<String, Object>);
          return {
            'srs_state': 'LEARNING',
            'next_review_at': '2026-10-14T00:10:00Z',
            'interval_days': 10 / 1440,
            'difficulty': 0.5,
            'review_count': 1,
          };
        },
      );
      expect(await repository.submit(prepared), isA<ReviewSuccess>());
      expect(requests[1], requests[0]);
      begin(a);
      expect(
        await repository.submit(prepared),
        isA<ReviewFailure>().having(
          (value) => value.code,
          'revoked',
          ReviewErrorCode.unauthorized,
        ),
      );
      expect(requests.length, 2);
    },
  );

  test('assembled notifier clears data synchronously on logout', () async {
    begin(
      a,
      rpc: (_, __) async => {
        'jlpt_level': 'N5',
        'server_time': '2026-10-14T00:00:00Z',
        'items': [
          {
            'item_type': 'VOCABULARY',
            'item_id': a,
            'prompt_ja': '猫',
            'reading_ja': 'ねこ',
            'answer_vi': 'con mèo',
            'next_review_at': '2026-10-13T00:00:00Z',
          },
        ],
      },
    );
    final container = ProviderContainer(
      overrides: [
        srsStudyRuntimeProvider.overrideWithValue(
          createSessionBoundStudyRuntime(registry),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(srsStudyProvider.notifier);
    await notifier.load(PreviewLevel.n5);
    expect(container.read(srsStudyProvider).item?.prompt, '猫');
    notifier.reveal();
    registry.end();
    final state = container.read(srsStudyProvider);
    expect(state.phase, SrsStudyPhase.signedOut);
    expect(state.item, isNull);
    expect(state.answerVisible, isFalse);
    expect(state.hasPendingEvent, isFalse);
  });

  test('no Auth binding means no available session or dispatch', () async {
    expect(registry.currentSession, isNull);
    await expectLater(invoke(ReviewSession(userId: a)), throwsA(unauthorized));
  });
  test('login and logout notifications synchronously expose new state', () {
    final states = <String?>[];
    final subscription = registry.sessionChanges.listen(
      (_) => states.add(registry.currentSession?.userId),
    );
    addTearDown(subscription.cancel);
    begin(a);
    expect(states, [a]);
    registry.end();
    registry.end();
    expect(states, [a, null]);
  });
  test(
    'A B A and same-user re-login never revive old prepared identity',
    () async {
      begin(a);
      final old = registry.currentSession!;
      begin(b);
      begin(a);
      expect(identical(old, registry.currentSession), isFalse);
      await expectLater(invoke(old), throwsA(unauthorized));
      final current = registry.currentSession;
      begin(a);
      expect(identical(current, registry.currentSession), isFalse);
    },
  );
  test(
    'same-user refresh retains identity but replaces captured dispatch',
    () async {
      begin(a, rpc: (_, __) async => 'old');
      final session = registry.currentSession!;
      var changes = 0;
      final subscription = registry.sessionChanges.listen((_) => changes++);
      addTearDown(subscription.cancel);
      registry.refresh(
        userId: a.toUpperCase(),
        expiresAt: now.add(const Duration(hours: 2)),
        rpc: (_, __) async => 'fresh',
      );
      expect(identical(session, registry.currentSession), isTrue);
      expect(changes, 0);
      expect(await invoke(session), 'fresh');
    },
  );
  test(
    'in-flight refresh cannot redirect already captured connection',
    () async {
      final reply = Completer<Object?>();
      var oldCalls = 0;
      var newCalls = 0;
      begin(
        a,
        rpc: (_, __) {
          oldCalls++;
          return reply.future;
        },
      );
      final session = registry.currentSession!;
      final pending = invoke(session);
      registry.refresh(
        userId: a,
        expiresAt: now.add(const Duration(hours: 2)),
        rpc: (_, __) async {
          newCalls++;
          return 'new';
        },
      );
      reply.complete('old captured response');
      expect(await pending, 'old captured response');
      expect(oldCalls, 1);
      expect(newCalls, 0);
      expect(await invoke(session), 'new');
    },
  );
  test('different-user refresh revokes instead of switching implicitly', () {
    begin(a);
    expect(
      () => registry.refresh(
        userId: b,
        expiresAt: now.add(const Duration(hours: 1)),
        rpc: fixture,
      ),
      throwsA(unauthorized),
    );
    expect(registry.currentSession, isNull);
  });
  test('invalid login or refresh clears old visible identity', () {
    for (final value in ['invalid', a]) {
      begin(a);
      expect(
        () => registry.begin(userId: value, expiresAt: now, rpc: fixture),
        throwsA(unauthorized),
      );
      expect(registry.currentSession, isNull);
      begin(a);
      expect(
        () => registry.refresh(userId: value, expiresAt: now, rpc: fixture),
        throwsA(unauthorized),
      );
      expect(registry.currentSession, isNull);
    }
  });
  test(
    'expired identity fails closed even before timer fires; refresh cannot revive',
    () async {
      begin(a);
      final session = registry.currentSession!;
      now = now.add(const Duration(hours: 1));
      await expectLater(invoke(session), throwsA(unauthorized));
      expect(
        () => registry.refresh(
          userId: a,
          expiresAt: now.add(const Duration(hours: 1)),
          rpc: fixture,
        ),
        throwsA(unauthorized),
      );
      begin(a);
      expect(identical(session, registry.currentSession), isFalse);
    },
  );
  testWidgets('expiry timer clears visible session without another request', (
    tester,
  ) async {
    registry.begin(
      userId: a,
      expiresAt: now.add(const Duration(seconds: 2)),
      rpc: fixture,
    );
    var changes = 0;
    final subscription = registry.sessionChanges.listen((_) => changes++);
    addTearDown(subscription.cancel);
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(changes, 1);
    expect(registry.currentSession, isNull);
    registry.dispose();
  });
  testWidgets('cancelled old expiry cannot revoke refreshed credentials', (
    tester,
  ) async {
    registry.begin(
      userId: a,
      expiresAt: now.add(const Duration(seconds: 1)),
      rpc: fixture,
    );
    final session = registry.currentSession;
    registry.refresh(
      userId: a,
      expiresAt: now.add(const Duration(hours: 1)),
      rpc: fixture,
    );
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(identical(session, registry.currentSession), isTrue);
    registry.dispose();
  });
  test(
    'old success and failure are suppressed after logout or A B A',
    () async {
      for (final failure in [false, true]) {
        final reply = Completer<Object?>();
        begin(a, rpc: (_, __) => reply.future);
        final pending = invoke(registry.currentSession!);
        begin(b);
        begin(a);
        if (failure) {
          reply.completeError(Exception('TEST ONLY sensitive detail'));
        } else {
          reply.complete('old');
        }
        await expectLater(pending, throwsA(unauthorized));
      }
    },
  );
  test(
    'only frozen flat ownerless SRS envelopes dispatch; snapshot is immutable',
    () async {
      var calls = 0;
      final reply = Completer<Object?>();
      Map<String, Object>? observed;
      begin(
        a,
        rpc: (_, request) {
          calls++;
          observed = request;
          return reply.future;
        },
      );
      final session = registry.currentSession!;
      final inner = <String, Object>{'jlpt_level': 'N5', 'limit': 100};
      final request = <String, Object>{'p_request': inner};
      final pending = registry.invoke(
        capturedSession: session,
        function: 'get_review_queue',
        params: request,
      );
      inner['limit'] = 1;
      expect((observed!['p_request'] as Map)['limit'], 100);
      expect(
        () => (observed!['p_request'] as Map)['limit'] = 2,
        throwsUnsupportedError,
      );
      for (final bad in <Map<String, Object>>[
        {},
        {...envelope, 'user_id': b},
        {
          'p_request': {...inner, 'user_id': b},
        },
        {
          'p_request': {'jlpt_level': 'N5', 'limit': double.nan},
        },
        {
          'p_request': {
            'jlpt_level': ['N5'],
            'limit': 100,
          },
        },
        {
          'p_request': {'jlpt_level': '日' * 12000, 'limit': 100},
        },
      ]) {
        await expectLater(
          registry.invoke(
            capturedSession: session,
            function: 'get_review_queue',
            params: bad,
          ),
          throwsA(isA<ReviewTransportFailure>()),
        );
      }
      await expectLater(
        registry.invoke(
          capturedSession: session,
          function: 'raw_table',
          params: envelope,
        ),
        throwsA(isA<ReviewTransportFailure>()),
      );
      expect(calls, 1);
      reply.complete(null);
      await pending;
    },
  );
  test(
    'unknown connection failures are redacted; timeout never auto-retries',
    () async {
      var calls = 0;
      begin(
        a,
        rpc: (_, __) async {
          calls++;
          throw Exception('TEST ONLY secret');
        },
      );
      await expectLater(
        invoke(registry.currentSession!),
        throwsA(
          isA<ReviewTransportFailure>().having(
            (e) => e.code,
            'safe code',
            ReviewErrorCode.internalError,
          ),
        ),
      );
      begin(
        a,
        rpc: (_, __) async {
          calls++;
          throw TimeoutException('TEST ONLY detail');
        },
      );
      await expectLater(
        invoke(registry.currentSession!),
        throwsA(
          isA<ReviewTransportFailure>()
              .having(
                (e) => e.code,
                'timeout code',
                ReviewErrorCode.networkUnavailable,
              )
              .having((e) => e.retryable, 'retryable', true),
        ),
      );
      expect(calls, 2);
    },
  );
  test(
    'disposal revokes before stream closes and suppresses in-flight result',
    () async {
      final reply = Completer<Object?>();
      begin(a, rpc: (_, __) => reply.future);
      final pending = invoke(registry.currentSession!);
      var cleared = false;
      final subscription = registry.sessionChanges.listen(
        (_) => cleared = registry.currentSession == null,
      );
      addTearDown(subscription.cancel);
      registry.dispose();
      registry.dispose();
      expect(cleared, isTrue);
      expect(() => begin(a), throwsA(unauthorized));
      reply.complete('old');
      await expectLater(pending, throwsA(unauthorized));
    },
  );
  test(
    'assembled runtime uses same registry for queue reviews and lifecycle',
    () async {
      begin(
        a,
        rpc: (function, _) async {
          expect(function, 'get_review_queue');
          return {
            'jlpt_level': 'N5',
            'server_time': '2026-10-14T00:00:00Z',
            'items': <Object>[],
          };
        },
      );
      final runtime = createSessionBoundStudyRuntime(registry);
      expect(identical(runtime.auth, registry), isTrue);
      expect(
        await runtime.queue.load(registry.currentSession!, PreviewLevel.n5),
        isEmpty,
      );
      expect(
        identical(runtime.sessionChanges, registry.sessionChanges),
        isTrue,
      );
    },
  );
}
