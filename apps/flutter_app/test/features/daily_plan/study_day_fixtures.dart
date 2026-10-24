// TEST ONLY captured lifecycle/RPC; no hosted JWT or timezone conversion proof.
import 'dart:async';
import 'dart:convert';
import 'package:nihongo_daily/features/daily_plan/data/captured_daily_plan_gateway.dart';
import 'package:nihongo_daily/features/daily_plan/data/daily_plan_repository.dart';
import 'package:nihongo_daily/features/daily_plan/domain/study_day.dart';
import 'package:nihongo_daily/features/srs/data/review_connection_registry.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'study_session_recovery_fixtures.dart' show checkStudy;

const studyDayScenarios = [
  'codec',
  'envelope',
  'errors',
  'ownership',
  'capability',
  'timeout',
];
const dayOwner = 'f5100000-0000-4000-8000-000000000001';
Future<void> dayFailure(Future<Object?> future, DailyPlanErrorCode code) async {
  Object? error;
  try {
    await future;
  } on Object catch (failure) {
    error = failure;
  }
  checkStudy(
    error is DailyPlanFailure &&
        error.code == code &&
        !error.toString().contains('PRIVATE'),
    'Missing safe study-day failure',
  );
}

final class NoDayGateway implements DailyPlanSessionGateway {
  @override
  bool get isCurrent => true;
  @override
  Future<Object?> getDailyPlan(Map<String, Object> parameters) async => null;
}

Future<void> verifyStudyDay(String scenario) async {
  final now = DateTime.utc(2026, 10, 19, 1);
  final registry = ReviewConnectionRegistry(now: () => now);
  var ready = true;
  var calls = 0;
  Object? response = <String, Object>{
    'date': '2026-10-20',
    'timezone': 'Asia/Tokyo',
  };
  ReviewTransportFailure? failure;
  Completer<Object?>? waiting;
  Map<String, Object>? envelope;
  String? function;
  void begin() => registry.begin(
    userId: dayOwner,
    expiresAt: now.add(const Duration(hours: 1)),
    rpc: (name, params) async {
      calls++;
      function = name;
      envelope = params;
      if (failure != null) throw failure;
      return waiting?.future ?? response;
    },
  );
  begin();
  CapturedDailyPlanGateway gateway({
    Duration timeout = const Duration(seconds: 15),
  }) => CapturedDailyPlanGateway(
    auth: registry,
    transport: registry,
    isReady: () => ready,
    timeout: timeout,
  );
  final lease = gateway();
  final repository = DailyPlanRepository(lease);
  try {
    if (scenario == 'codec') {
      for (final zone in [
        'UTC',
        'Asia/Ho_Chi_Minh',
        'America/New_York',
        'Etc/GMT+7',
      ]) {
        checkStudy(
          StudyDay.fromJson({
                'date': '2028-02-29',
                'timezone': zone,
              }).date.value ==
              '2028-02-29',
          'Valid day rejected',
        );
      }
      for (final raw in <Object?>[
        null,
        <Object?>[],
        <String, Object?>{},
        {'date': '2026-02-30', 'timezone': 'UTC'},
        {'date': '0000-01-01', 'timezone': 'UTC'},
        {'date': '2026-10-20', 'timezone': 'UTC\n'},
        {'date': '2026-10-20', 'timezone': 'UTC', 'extra': 1},
      ]) {
        var rejected = false;
        try {
          StudyDay.fromJson(raw);
        } on FormatException {
          rejected = true;
        }
        checkStudy(rejected, 'Malformed day accepted');
      }
    } else if (scenario == 'envelope') {
      checkStudy(repository.supportsStudyDay, 'Captured capability missing');
      final day = await repository.loadStudyDay('Asia/Tokyo');
      checkStudy(
        day.date.value == '2026-10-20' &&
            function == 'get_study_day' &&
            jsonEncode(envelope) == '{"p_request":{}}' &&
            calls == 1,
        'Device date/owner/clock dispatched or server date lost',
      );
      for (final field in ['date', 'user_id', 'timezone', 'now']) {
        await dayFailure(
          lease.getStudyDay({
            'p_request': {field: 'PRIVATE'},
          }),
          DailyPlanErrorCode.validationFailure,
        );
      }
      checkStudy(calls == 1, 'Forbidden day input dispatched');
    } else if (scenario == 'errors') {
      response = {'date': '2026-10-20', 'timezone': 'UTC'};
      await dayFailure(
        repository.loadStudyDay('Asia/Tokyo'),
        DailyPlanErrorCode.syncConflict,
      );
      response = {'date': '2026-02-30', 'timezone': 'Asia/Tokyo'};
      await dayFailure(
        repository.loadStudyDay('Asia/Tokyo'),
        DailyPlanErrorCode.internalError,
      );
      response = {
        'code': 'NOT_FOUND',
        'message_vi': 'PRIVATE SQL',
        'retryable': true,
      };
      await dayFailure(
        repository.loadStudyDay('Asia/Tokyo'),
        DailyPlanErrorCode.notFound,
      );
      failure = const ReviewTransportFailure(
        ReviewErrorCode.networkUnavailable,
        retryable: true,
      );
      await dayFailure(
        repository.loadStudyDay('Asia/Tokyo'),
        DailyPlanErrorCode.networkUnavailable,
      );
      checkStudy(calls == 4, 'Unexpected automatic read retry');
    } else if (scenario == 'ownership') {
      for (final lateError in [false, true]) {
        ready = true;
        begin();
        waiting = Completer<Object?>();
        final old = DailyPlanRepository(gateway());
        final pending = dayFailure(
          old.loadStudyDay('Asia/Tokyo'),
          DailyPlanErrorCode.unauthorized,
        );
        ready = false;
        if (lateError) {
          waiting.completeError(StateError('PRIVATE'));
        } else {
          waiting.complete(response);
        }
        await pending;
        ready = true;
        begin();
        await dayFailure(
          old.loadStudyDay('Asia/Tokyo'),
          DailyPlanErrorCode.unauthorized,
        );
      }
      checkStudy(calls == 2, 'Old same-owner day lease revived');
    } else if (scenario == 'capability') {
      final missing = DailyPlanRepository(NoDayGateway());
      checkStudy(
        !missing.supportsStudyDay,
        'Legacy gateway gained synthetic capability',
      );
      await dayFailure(
        missing.loadStudyDay('UTC'),
        DailyPlanErrorCode.providerUnavailable,
      );
      await dayFailure(
        repository.loadStudyDay('UTC\n'),
        DailyPlanErrorCode.validationFailure,
      );
      checkStudy(calls == 0, 'Invalid zone/capability dispatched');
    } else if (scenario == 'timeout') {
      waiting = Completer<Object?>();
      final timed = DailyPlanRepository(
        gateway(timeout: const Duration(milliseconds: 5)),
      );
      await dayFailure(
        timed.loadStudyDay('Asia/Tokyo'),
        DailyPlanErrorCode.networkUnavailable,
      );
      waiting.complete(response);
      await Future<void>.delayed(Duration.zero);
      checkStudy(calls == 1, 'Day read automatically retried');
    } else {
      throw StateError('Unknown day scenario');
    }
  } finally {
    registry.dispose();
  }
}
