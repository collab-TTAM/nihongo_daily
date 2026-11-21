import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/daily_plan/data/daily_plan_repository.dart';
import 'package:nihongo_daily/features/daily_plan/domain/completed_study_session.dart';
import 'package:nihongo_daily/features/daily_plan/domain/daily_plan.dart';

CompletedStudySession event({
  String id = 'e1400000-0000-4000-8000-000000000001',
  DateTime? start,
  DateTime? end,
}) => CompletedStudySession(
  clientEventId: id,
  date: DailyPlanDate('2026-10-13'),
  area: DailyPlanArea.vocabulary,
  startedAt: start ?? DateTime.utc(2026, 10, 13),
  endedAt: end ?? DateTime.utc(2026, 10, 13, 0, 15),
);

Map<String, Object?> response() {
  final fixtures =
      jsonDecode(File('../../contracts/v0.1/fixtures.json').readAsStringSync())
          as Map<String, Object?>;
  return (fixtures['get_daily_plan_response']! as Map<String, Object?>)
    ..['completed_minutes'] = 15;
}

final class WritableGateway implements DailyPlanStudySessionGateway {
  bool current = true;
  int reads = 0;
  final sent = <Map<String, Object>>[];
  Future<Object?> Function() result = () async => response();
  @override
  bool get isCurrent => current;
  @override
  Future<Object?> getDailyPlan(Map<String, Object> parameters) async {
    reads++;
    return response();
  }

  @override
  Future<Object?> submitStudySession(Map<String, Object> parameters) {
    sent.add(parameters);
    return result();
  }
}

final class ReadOnlyGateway implements DailyPlanSessionGateway {
  @override
  bool get isCurrent => true;
  @override
  Future<Object?> getDailyPlan(Map<String, Object> parameters) async =>
      response();
}

void main() {
  test('immutable UTC event matches separate versioned contract fixture', () {
    final fixture = jsonDecode(
      File('../../contracts/study/v1/request.fixture.json').readAsStringSync(),
    );
    final report = event(
      start: DateTime.parse('2026-10-13T07:00:00+07:00'),
      end: DateTime.parse('2026-10-13T07:15:00+07:00'),
    );
    expect(report.toJson(), fixture);
    final mutable = report.toJson()..['actual_minutes'] = 999;
    expect(mutable.length, 6);
    expect(report.toJson(), fixture);
    expect(report.toJson().keys.toSet(), {
      'client_event_id',
      'plan_date',
      'session_type',
      'started_at',
      'ended_at',
    });
  });

  test(
    'event rejects malformed identity, invalid duration and unsupported years',
    () {
      for (final id in [
        'bad',
        '{e1400000-0000-4000-8000-000000000001}',
        'e1400000-0000-4000-8000-000000000001\n',
      ]) {
        expect(() => event(id: id), throwsFormatException);
      }
      for (final end in [
        DateTime.utc(2026, 10, 12),
        DateTime.utc(2026, 10, 13),
        DateTime.utc(2026, 10, 13, 0, 0, 59, 999),
        DateTime.utc(2026, 10, 14, 1, 0, 1),
      ]) {
        expect(() => event(end: end), throwsFormatException);
      }
      expect(
        () => event(
          start: DateTime.utc(10000),
          end: DateTime.utc(10000, 1, 1, 0, 1),
        ),
        throwsFormatException,
      );
      expect(
        event(id: 'E1400000-0000-4000-8000-000000000001').clientEventId,
        'e1400000-0000-4000-8000-000000000001',
      );
      expect(
        event(end: DateTime.utc(2026, 10, 14, 1)).toJson()['ended_at'],
        '2026-10-14T01:00:00.000Z',
      );
    },
  );

  test(
    'submit dispatches only exact event and publishes authoritative response',
    () async {
      final gateway = WritableGateway();
      final report = event();
      final plan = await DailyPlanRepository(gateway).submit(report);
      expect(plan.completedMinutes, 15);
      expect(gateway.sent, [
        {'p_request': report.toJson()},
      ]);
      expect(gateway.reads, 0);
    },
  );

  test(
    'offline submit retains immutable event for explicit retry without auto save',
    () async {
      final gateway = WritableGateway()
        ..result = () async => throw const DailyPlanFailure(
          DailyPlanErrorCode.networkUnavailable,
          retryable: true,
        );
      final repository = DailyPlanRepository(gateway);
      final report = event();
      await expectLater(
        repository.submit(report),
        throwsA(
          isA<DailyPlanFailure>().having(
            (e) => e.code,
            'code',
            DailyPlanErrorCode.networkUnavailable,
          ),
        ),
      );
      expect(gateway.sent.length, 1);
      gateway.result = () async => response();
      expect((await repository.submit(report)).completedMinutes, 15);
      expect(gateway.sent.length, 2);
      expect(gateway.sent.first, gateway.sent.last);
    },
  );

  test(
    'revoked session never dispatches and missing writer fails explicitly',
    () async {
      final gateway = WritableGateway()..current = false;
      await expectLater(
        DailyPlanRepository(gateway).submit(event()),
        throwsA(
          isA<DailyPlanFailure>().having(
            (e) => e.code,
            'code',
            DailyPlanErrorCode.unauthorized,
          ),
        ),
      );
      expect(gateway.sent, isEmpty);
      await expectLater(
        DailyPlanRepository(ReadOnlyGateway()).submit(event()),
        throwsA(
          isA<DailyPlanFailure>().having(
            (e) => e.code,
            'code',
            DailyPlanErrorCode.providerUnavailable,
          ),
        ),
      );
    },
  );

  test('account switch discards late submit success and failure', () async {
    for (final fail in [false, true]) {
      final pending = Completer<Object?>();
      final gateway = WritableGateway()..result = () => pending.future;
      final saved = DailyPlanRepository(gateway).submit(event());
      final rejected = expectLater(
        saved,
        throwsA(
          isA<DailyPlanFailure>().having(
            (e) => e.code,
            'code',
            DailyPlanErrorCode.unauthorized,
          ),
        ),
      );
      gateway.current = false;
      if (fail) {
        pending.completeError(StateError('secret'));
      } else {
        pending.complete(response());
      }
      await rejected;
      expect(gateway.sent.length, 1);
    }
  });

  test(
    'malformed save response and mismatched date cannot claim saved progress',
    () async {
      final gateway = WritableGateway();
      for (final payload in <Object?>[
        null,
        {'saved': true},
        response()..['plan_date'] = '2026-10-14',
      ]) {
        gateway.result = () async => payload;
        await expectLater(
          DailyPlanRepository(gateway).submit(event()),
          throwsA(
            isA<DailyPlanFailure>().having(
              (e) => e.code,
              'code',
              DailyPlanErrorCode.internalError,
            ),
          ),
        );
      }
    },
  );

  test(
    'submit conflicts are safe typed failures without leaking server text',
    () async {
      final gateway = WritableGateway()
        ..result = () async => {
          'code': 'SYNC_CONFLICT',
          'message_vi': 'secret SQL token',
          'retryable': true,
        };
      await expectLater(
        DailyPlanRepository(gateway).submit(event()),
        throwsA(
          isA<DailyPlanFailure>()
              .having((e) => e.code, 'code', DailyPlanErrorCode.syncConflict)
              .having((e) => e.retryable, 'retryable', false)
              .having(
                (e) => e.messageVi,
                'safe text',
                isNot(contains('secret')),
              ),
        ),
      );
      expect(gateway.sent.length, 1);
    },
  );
}
