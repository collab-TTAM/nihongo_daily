// TEST ONLY process-local lifecycle/RPC fixture; no hosted identity proof.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/daily_plan/data/captured_daily_plan_gateway.dart';
import 'package:nihongo_daily/features/daily_plan/data/daily_plan_repository.dart';
import 'package:nihongo_daily/features/srs/data/review_connection_registry.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

const owner = 'a1000000-0000-4000-8000-000000000001';
const other = 'a1000000-0000-4000-8000-000000000002';
const read = {
  'p_request': <String, Object>{'date': '2026-10-14'},
};
const write = {
  'p_request': <String, Object>{
    'client_event_id': 'e1400000-0000-4000-8000-000000000001',
    'plan_date': '2026-10-14',
    'session_type': 'VOCABULARY',
    'started_at': '2026-10-14T01:00:00.000Z',
    'ended_at': '2026-10-14T01:15:00.000Z',
  },
};
final unauthorized = isA<DailyPlanFailure>().having(
  (e) => e.code,
  'code',
  DailyPlanErrorCode.unauthorized,
);

void main() {
  late ReviewConnectionRegistry registry;
  late DateTime now;
  late bool ready;
  late int calls;
  late Future<Object?> Function(String, Map<String, Object>) rpc;
  void begin(String user) => registry.begin(
    userId: user,
    expiresAt: now.add(const Duration(hours: 1)),
    rpc: (f, p) => rpc(f, p),
  );
  CapturedDailyPlanGateway gateway({
    Duration timeout = const Duration(seconds: 15),
  }) => CapturedDailyPlanGateway(
    auth: registry,
    transport: registry,
    isReady: () => ready,
    timeout: timeout,
  );
  setUp(() {
    now = DateTime.utc(2026, 10, 14, 3);
    ready = true;
    calls = 0;
    registry = ReviewConnectionRegistry(now: () => now);
    rpc = (f, p) async {
      calls++;
      return {'handled': f};
    };
    begin(owner);
  });
  tearDown(() => registry.dispose());

  test('closed registry dispatches exactly the two fixed plan RPCs', () async {
    final lease = gateway();
    expect(await lease.getDailyPlan(read), {'handled': 'get_daily_plan'});
    expect(await lease.submitStudySession(write), {
      'handled': 'submit_study_session',
    });
    expect(calls, 2);
    await expectLater(
      lease.getDailyPlan({
        'p_request': {'date': '2026-10-14', 'user_id': other},
      }),
      throwsA(
        isA<DailyPlanFailure>().having(
          (e) => e.code,
          'code',
          DailyPlanErrorCode.validationFailure,
        ),
      ),
    );
    await expectLater(
      lease.submitStudySession({
        'p_request': {'actual_minutes': 999},
      }),
      throwsA(
        isA<DailyPlanFailure>().having(
          (e) => e.code,
          'code',
          DailyPlanErrorCode.validationFailure,
        ),
      ),
    );
    expect(calls, 2);
  });

  test(
    'readiness loss permanently revokes a lease even if Auth identity remains',
    () async {
      final lease = gateway();
      ready = false;
      expect(lease.isCurrent, isFalse);
      ready = true;
      await expectLater(lease.getDailyPlan(read), throwsA(unauthorized));
      expect(calls, 0);
      expect(await gateway().getDailyPlan(read), {'handled': 'get_daily_plan'});
    },
  );

  test('A-B-A relogin and expiry cannot reactivate captured session', () async {
    final old = gateway();
    begin(other);
    begin(owner);
    await expectLater(old.submitStudySession(write), throwsA(unauthorized));
    final current = gateway();
    now = now.add(const Duration(hours: 2));
    await expectLater(current.getDailyPlan(read), throwsA(unauthorized));
    expect(calls, 0);
  });

  test(
    'late success/error is fenced by immediate readiness and owner checks',
    () async {
      for (final fail in [false, true]) {
        ready = true;
        begin(owner);
        final pending = Completer<Object?>();
        rpc = (_, __) {
          calls++;
          return pending.future;
        };
        final operation = gateway().submitStudySession(write);
        final rejected = expectLater(operation, throwsA(unauthorized));
        ready = false;
        if (fail) {
          pending.completeError(StateError('PRIVATE TOKEN'));
        } else {
          pending.complete({'accepted': true});
        }
        await rejected;
      }
      expect(calls, 2);
    },
  );

  test(
    'bounded timeout remains an uncertain event and never retries',
    () async {
      final pending = Completer<Object?>();
      rpc = (_, __) {
        calls++;
        return pending.future;
      };
      await expectLater(
        gateway(
          timeout: const Duration(milliseconds: 5),
        ).submitStudySession(write),
        throwsA(
          isA<DailyPlanFailure>()
              .having(
                (e) => e.code,
                'code',
                DailyPlanErrorCode.networkUnavailable,
              )
              .having((e) => e.retryable, 'retryable', true),
        ),
      );
      expect(calls, 1);
      pending.complete({'accepted': true});
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
    },
  );

  test(
    'safe transport codes map without raw SDK errors or disposal of borrowed owner',
    () async {
      for (final code in ReviewErrorCode.values) {
        rpc = (_, __) async =>
            throw ReviewTransportFailure(code, retryable: true);
        await expectLater(
          gateway().getDailyPlan(read),
          throwsA(
            isA<DailyPlanFailure>().having(
              (e) => e.code.wireName,
              'code',
              code.wireName,
            ),
          ),
        );
      }
      rpc = (_, __) async => throw StateError('PRIVATE SQL / TOKEN');
      await expectLater(
        gateway().getDailyPlan(read),
        throwsA(
          isA<DailyPlanFailure>()
              .having((e) => e.code, 'code', DailyPlanErrorCode.internalError)
              .having((e) => e.toString(), 'safe', isNot(contains('PRIVATE'))),
        ),
      );
      expect(registry.currentSession, isNotNull);
      expect(() => gateway(timeout: Duration.zero), throwsArgumentError);
    },
  );
}
