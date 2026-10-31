import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/daily_plan/data/daily_plan_repository.dart';
import 'package:nihongo_daily/features/daily_plan/domain/daily_plan.dart';

Map<String, Object?> planJson() => {
  'plan_date': '2026-10-19',
  'target_minutes': 120,
  'completed_minutes': 145,
  'blocks': <Map<String, Object?>>[
    for (var i = 0; i < DailyPlanArea.values.length; i++)
      {
        'type': DailyPlanArea.values[i].wireName,
        'planned_minutes': [20, 15, 20, 15, 15, 25, 10][i],
        'status': [
          'IN_PROGRESS',
          'DONE',
          'BLOCKED',
          'READY',
          'BLOCKED',
          'BLOCKED',
          'BLOCKED',
        ][i],
        'item_count': i < 4 ? 3 : 0,
      },
  ],
};

List<Map<String, Object?>> blocksOf(Map<String, Object?> plan) =>
    (plan['blocks']! as List<Object?>).cast<Map<String, Object?>>();

TypeMatcher<DailyPlanFailure> failure(
  DailyPlanErrorCode code, {
  bool retryable = false,
}) => isA<DailyPlanFailure>()
    .having((value) => value.code, 'code', code)
    .having((value) => value.retryable, 'retryable', retryable);

final class Gateway implements DailyPlanSessionGateway {
  bool current = true;
  int calls = 0;
  Map<String, Object>? parameters;
  Future<Object?> Function() response = () async => planJson();

  @override
  bool get isCurrent => current;

  @override
  Future<Object?> getDailyPlan(Map<String, Object> parameters) {
    calls++;
    this.parameters = parameters;
    return response();
  }
}

void main() {
  final date = DailyPlanDate('2026-10-19');

  test('decodes the canonical frozen fixture without inventing fields', () {
    final fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
    final request = fixtures['get_daily_plan_request']! as Map<String, Object?>;
    final plan = DailyPlan.fromJson(fixtures['get_daily_plan_response']);
    expect(plan.date.toRequestJson(), request);
    expect(plan.targetMinutes, 120);
    expect(plan.blocks.map((block) => block.plannedMinutes), [
      20,
      15,
      20,
      15,
      15,
      25,
      10,
    ]);
  });

  test('calendar dates reject rollover, zero years and device timestamps', () {
    for (final value in [
      '0001-01-01',
      '2000-02-29',
      '2024-02-29',
      '9999-12-31',
    ]) {
      expect(DailyPlanDate(value).value, value);
    }
    for (final value in [
      '0000-01-01',
      '1900-02-29',
      '2026-02-29',
      '2026-04-31',
      '2026-00-01',
      '2026-13-01',
      '2026-01-00',
      '2026-01-32',
      '2026-1-01',
      '2026-10-19\n',
      '2026-10-19T00:00:00Z',
    ]) {
      expect(() => DailyPlanDate(value), throwsFormatException, reason: value);
    }
  });

  test(
    'actual JSON decode preserves all statuses, order and over-target time',
    () {
      final plan = DailyPlan.fromJson(jsonDecode(jsonEncode(planJson())));
      expect(plan.date.value, date.value);
      expect(plan.targetMinutes, 120);
      expect(plan.completedMinutes, 145);
      expect(plan.blocks.map((block) => block.area), DailyPlanArea.values);
      expect(
        plan.blocks.map((block) => block.status).toSet(),
        DailyPlanStatus.values.toSet(),
      );
      expect(plan.blocks.last.itemCount, 0);
      expect(plan.blocks.last.plannedMinutes, 10);
    },
  );

  test('decoded plan owns an immutable snapshot', () {
    final input = planJson();
    final plan = DailyPlan.fromJson(input);
    blocksOf(input).first['planned_minutes'] = 999;
    blocksOf(input).clear();
    input['completed_minutes'] = 0;
    expect(plan.blocks.length, 7);
    expect(plan.blocks.first.plannedMinutes, 20);
    expect(plan.completedMinutes, 145);
    expect(() => plan.blocks.clear(), throwsUnsupportedError);
  });

  test('missing/extra owner and success-envelope fields fail closed', () {
    for (final key in planJson().keys) {
      final input = planJson()..remove(key);
      expect(() => DailyPlan.fromJson(input), throwsFormatException);
    }
    for (final key in ['user_id', 'code', 'data']) {
      expect(
        () => DailyPlan.fromJson(planJson()..[key] = 'hidden'),
        throwsFormatException,
      );
    }
    for (final input in [
      null,
      <Object?>[],
      {'data': planJson()},
      'plan',
    ]) {
      expect(() => DailyPlan.fromJson(input), throwsFormatException);
    }
  });

  test('requires seven unique known blocks and exact positive allocation', () {
    final mutations = <void Function(Map<String, Object?>)>[
      (p) => blocksOf(p).removeLast(),
      (p) => blocksOf(p).add(Map.of(blocksOf(p).first)),
      (p) => blocksOf(p)[1]['type'] = 'SRS',
      (p) => blocksOf(p).first['type'] = 'UNKNOWN',
      (p) => blocksOf(p).first['status'] = 'ready',
      (p) => blocksOf(p).first['planned_minutes'] = 0,
      (p) => blocksOf(p).first['planned_minutes'] = 21,
      (p) => blocksOf(p).first['item_count'] = -1,
      (p) => blocksOf(p).first['user_id'] = 'other',
      (p) => blocksOf(p).first.remove('status'),
    ];
    for (final change in mutations) {
      final input = planJson();
      change(input);
      expect(() => DailyPlan.fromJson(input), throwsFormatException);
    }
  });

  test(
    'numeric validation rejects fractions, booleans and unsafe precision',
    () {
      for (final value in [
        -1,
        1.5,
        double.nan,
        double.infinity,
        true,
        '5',
        9007199254740992,
      ]) {
        expect(
          () => DailyPlan.fromJson(planJson()..['completed_minutes'] = value),
          throwsFormatException,
        );
      }
      for (final value in [0, 9007199254740991, 145.0]) {
        expect(
          DailyPlan.fromJson(
            planJson()..['completed_minutes'] = value,
          ).completedMinutes,
          value,
        );
      }
      for (final target in [6, 1441]) {
        expect(
          () => DailyPlan.fromJson(planJson()..['target_minutes'] = target),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'minimum and maximum target plans are accepted without reallocating',
    () {
      for (final target in [7, 1440]) {
        final input = planJson()..['target_minutes'] = target;
        final blocks = blocksOf(input);
        for (var i = 0; i < blocks.length; i++) {
          blocks[i]['planned_minutes'] = i == 0 ? target - 6 : 1;
        }
        final plan = DailyPlan.fromJson(input);
        expect(plan.targetMinutes, target);
        expect(plan.blocks.first.plannedMinutes, target - 6);
      }
    },
  );

  test(
    'dispatch sends only frozen date nested in p_request; reads never cache',
    () async {
      final gateway = Gateway();
      final repository = DailyPlanRepository(gateway);
      expect((await repository.load(date)).completedMinutes, 145);
      expect(gateway.parameters, {
        'p_request': {'date': '2026-10-19'},
      });
      gateway.response = () async => planJson()..['completed_minutes'] = 160;
      expect((await repository.load(date)).completedMinutes, 160);
      expect(gateway.calls, 2);
    },
  );

  test('obsolete session cannot dispatch', () async {
    final gateway = Gateway()..current = false;
    await expectLater(
      DailyPlanRepository(gateway).load(date),
      throwsA(failure(DailyPlanErrorCode.unauthorized)),
    );
    expect(gateway.calls, 0);
  });

  test(
    'account switch rejects late success and leaves new account isolated',
    () async {
      final pending = Completer<Object?>();
      final old = Gateway()..response = () => pending.future;
      final future = DailyPlanRepository(old).load(date);
      final rejected = expectLater(
        future,
        throwsA(failure(DailyPlanErrorCode.unauthorized)),
      );
      old.current = false;
      final next = Gateway()
        ..response = () async => planJson()..['completed_minutes'] = 0;
      final newRepository = DailyPlanRepository(next);
      expect((await newRepository.load(date)).completedMinutes, 0);
      pending.complete(planJson());
      await rejected;
      expect((await newRepository.load(date)).completedMinutes, 0);
    },
  );

  test(
    'logout wins over late transport failures without leaking detail',
    () async {
      for (final rawError in [
        StateError('secret'),
        const DailyPlanFailure(
          DailyPlanErrorCode.networkUnavailable,
          retryable: true,
        ),
      ]) {
        final pending = Completer<Object?>();
        final gateway = Gateway()..response = () => pending.future;
        final result = DailyPlanRepository(gateway).load(date);
        final rejected = expectLater(
          result,
          throwsA(failure(DailyPlanErrorCode.unauthorized)),
        );
        gateway.current = false;
        pending.completeError(rawError);
        await rejected;
      }
    },
  );

  test(
    'known server errors keep safe codes and bounded retry advice',
    () async {
      final gateway = Gateway();
      for (final code in DailyPlanErrorCode.values) {
        gateway.response = () async => {
          'code': code.wireName,
          'message_vi': 'secret SQL token',
          'retryable': true,
        };
        final transient = [
          DailyPlanErrorCode.networkUnavailable,
          DailyPlanErrorCode.providerUnavailable,
          DailyPlanErrorCode.rateLimited,
        ].contains(code);
        await expectLater(
          DailyPlanRepository(gateway).load(date),
          throwsA(
            failure(code, retryable: transient)
                .having(
                  (value) => value.messageVi,
                  'safe text',
                  isNot(contains('secret')),
                )
                .having(
                  (value) => value.toString(),
                  'safe exception',
                  isNot(contains('secret')),
                ),
          ),
        );
      }
      expect(gateway.calls, DailyPlanErrorCode.values.length);
    },
  );

  test(
    'malformed payload, error envelope and wrong date never become success',
    () async {
      final gateway = Gateway();
      for (final input in [
        null,
        {
          'error': {'code': 'NOT_FOUND'},
        },
        {'code': 'UNKNOWN', 'message_vi': 'bad', 'retryable': false},
        {'code': 'NOT_FOUND', 'message_vi': '', 'retryable': false},
        {'code': 'NOT_FOUND', 'message_vi': 'x' * 501, 'retryable': false},
        {'code': 'NOT_FOUND', 'message_vi': 'bad', 'retryable': 'yes'},
        {
          'code': 'NOT_FOUND',
          'message_vi': 'bad',
          'retryable': false,
          'extra': 1,
        },
        planJson()..['plan_date'] = '2026-10-20',
        planJson()..['plan_date'] = '2026-02-30',
      ]) {
        gateway.response = () async => input;
        await expectLater(
          DailyPlanRepository(gateway).load(date),
          throwsA(failure(DailyPlanErrorCode.internalError)),
        );
      }
    },
  );

  test(
    'offline failure is typed, no auto retry, explicit next load can recover',
    () async {
      final gateway = Gateway()
        ..response = () async => throw const DailyPlanFailure(
          DailyPlanErrorCode.networkUnavailable,
          retryable: true,
        );
      final repository = DailyPlanRepository(gateway);
      await expectLater(
        repository.load(date),
        throwsA(
          failure(DailyPlanErrorCode.networkUnavailable, retryable: true),
        ),
      );
      expect(gateway.calls, 1);
      gateway.response = () async => planJson();
      expect((await repository.load(date)).completedMinutes, 145);
      expect(gateway.calls, 2);
    },
  );

  test(
    'unknown transport exception is redacted and not labeled offline',
    () async {
      final gateway = Gateway()
        ..response = () async => throw StateError('token SQL');
      await expectLater(
        DailyPlanRepository(gateway).load(date),
        throwsA(failure(DailyPlanErrorCode.internalError)),
      );
      expect(gateway.calls, 1);
    },
  );
}
