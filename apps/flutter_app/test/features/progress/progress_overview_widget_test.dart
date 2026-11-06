import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/app/navigation.dart';
import 'package:nihongo_daily/features/auth/application/account_provider.dart';
import 'package:nihongo_daily/features/daily_plan/application/daily_plan_provider.dart';
import 'package:nihongo_daily/features/daily_plan/data/daily_plan_repository.dart';
import 'package:nihongo_daily/features/daily_plan/domain/daily_plan.dart';

import '../srs/account_fixtures.dart' as account;
import '../srs/account_widget_test.dart' show Harness;
import '../daily_plan/study_session_recovery_fixtures.dart' show studyPlan;

// TEST ONLY Auth/RPC ports. No hosted learner or multi-device proof.
final class _ProgressSource implements DailyPlanRepositorySource {
  _ProgressSource(this.harness);

  final Harness harness;
  int planReads = 0;
  int dayReads = 0;
  Map<String, Object>? lastPlanParameters;
  Map<String, Object>? lastDayParameters;
  Future<Object?> Function(Map<String, Object>) planResponse =
      (_) async => studyPlan(45);
  Future<Object?> Function() dayResponse = () async => {
    'date': '2026-10-20',
    'timezone': 'Asia/Tokyo',
  };

  @override
  DailyPlanRepository? createDailyPlanRepository() {
    final ready = harness.runtime.readyRuntime;
    if (ready == null) return null;
    return DailyPlanRepository(
      _ProgressGateway(
        this,
        () => identical(harness.runtime.readyRuntime, ready),
      ),
    );
  }
}

final class _ProgressGateway implements DailyPlanStudyDayGateway {
  _ProgressGateway(this.source, this.current);

  final _ProgressSource source;
  final bool Function() current;

  @override
  bool get isCurrent => current();

  @override
  Future<Object?> getDailyPlan(Map<String, Object> parameters) {
    source.planReads++;
    source.lastPlanParameters = parameters;
    return source.planResponse(parameters);
  }

  @override
  Future<Object?> getStudyDay(Map<String, Object> parameters) {
    source.dayReads++;
    source.lastDayParameters = parameters;
    return source.dayResponse();
  }
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  Harness harness,
  _ProgressSource source, {
  bool configured = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      if (configured)
        accountRuntimeProvider.overrideWithValue(harness.runtime),
      if (configured) dailyPlanSourceProvider.overrideWithValue(source),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await harness.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const NihongoDailyApp(),
    ),
  );
  if (configured) harness.access.change(account.owner);
  await tester.pumpAndSettle();
  container.read(routerProvider).go('/overview');
  await tester.pumpAndSettle();
  return container;
}

Finder _todayButton() => find.descendant(
  of: find.byKey(const Key('progress-today')),
  matching: find.byType(OutlinedButton),
);

void main() {
  testWidgets('preview overview never fabricates a server plan', (
    tester,
  ) async {
    final harness = Harness();
    final source = _ProgressSource(harness);
    await _mount(tester, harness, source, configured: false);

    expect(find.text('Tiến độ học tập'), findsOneWidget);
    expect(find.text('Mở tài khoản'), findsOneWidget);
    expect(find.byKey(const Key('progress-date')), findsNothing);
    expect(source.planReads, 0);
    expect(source.dayReads, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'profile-local today and plan progress require explicit loads',
    (tester) async {
      final harness = Harness();
      final source = _ProgressSource(harness);
      await _mount(tester, harness, source);

      expect(source.planReads, 0);
      expect(source.dayReads, 0);
      await tester.ensureVisible(_todayButton());
      await tester.tap(_todayButton());
      await tester.pumpAndSettle();

      expect(source.dayReads, 1);
      expect(source.lastDayParameters, {'p_request': <String, Object>{}});
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('progress-date')))
            .controller!
            .text,
        '2026-10-20',
      );

      await tester.ensureVisible(find.byKey(const Key('progress-load')));
      await tester.tap(find.byKey(const Key('progress-load')));
      await tester.pumpAndSettle();

      expect(source.planReads, 1);
      expect(source.lastPlanParameters, {
        'p_request': {'date': '2026-10-20'},
      });
      expect(find.text('45/120 phút'), findsOneWidget);
      expect(find.byKey(const Key('progress-study-minutes')), findsOneWidget);
      expect(find.textContaining('SRS'), findsOneWidget);
      expect(destinationIndex('/overview'), 4);
      expect(destinationIndex('/progress'), 4);
    },
  );

  testWidgets('safe plan error can be retried explicitly', (tester) async {
    final harness = Harness();
    final source = _ProgressSource(harness)
      ..planResponse = (_) async {
        throw const DailyPlanFailure(DailyPlanErrorCode.networkUnavailable);
      };
    await _mount(tester, harness, source);
    await tester.enterText(
      find.byKey(const Key('progress-date')),
      '2026-10-20',
    );
    await tester.tap(find.byKey(const Key('progress-load')));
    await tester.pumpAndSettle();

    expect(find.text('Không có kết nối mạng.'), findsOneWidget);
    expect(find.byKey(const Key('progress-study-minutes')), findsNothing);
    expect(source.planReads, 1);

    source.planResponse = (_) async => studyPlan(45);
    await tester.tap(find.byKey(const Key('progress-load')));
    await tester.pumpAndSettle();

    expect(source.planReads, 2);
    expect(find.text('45/120 phút'), findsOneWidget);
  });

  testWidgets(
    'late plan response cannot publish after account replacement',
    (tester) async {
      final harness = Harness();
      final pending = Completer<Object?>();
      final source = _ProgressSource(harness)
        ..planResponse = (_) => pending.future;
      await _mount(tester, harness, source);

      await tester.enterText(
        find.byKey(const Key('progress-date')),
        '2026-10-20',
      );
      await tester.tap(find.byKey(const Key('progress-load')));
      await tester.pump();
      expect(find.text('Đang tải tiến độ…'), findsOneWidget);

      harness.access.change(account.other);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('progress-study-minutes')), findsNothing);

      pending.complete(studyPlan(45));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('progress-study-minutes')), findsNothing);
      expect(source.planReads, 1);
    },
  );

  testWidgets('overview links keep vocabulary and grammar reports separate', (
    tester,
  ) async {
    final harness = Harness();
    final source = _ProgressSource(harness);
    final container = await _mount(tester, harness, source);

    await tester.ensureVisible(find.byKey(const Key('progress-vocabulary')));
    await tester.tap(find.byKey(const Key('progress-vocabulary')));
    await tester.pumpAndSettle();
    expect(
      container.read(routerProvider).routeInformationProvider.value.uri.path,
      '/progress',
    );

    container.read(routerProvider).go('/overview');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('progress-grammar')));
    await tester.tap(find.byKey(const Key('progress-grammar')));
    await tester.pumpAndSettle();
    expect(
      container.read(routerProvider).routeInformationProvider.value.uri.path,
      '/quiz/grammar/progress',
    );
  });

}
