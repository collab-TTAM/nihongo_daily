// TEST ONLY Auth/RPC/clock-free date fixture. No hosted calendar evidence.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/auth/application/account_provider.dart';
import 'package:nihongo_daily/features/daily_plan/application/daily_plan_provider.dart';
import 'package:nihongo_daily/features/daily_plan/data/daily_plan_repository.dart';
import 'package:nihongo_daily/features/daily_plan/data/durable_study_session_repository.dart';
import 'package:nihongo_daily/features/daily_plan/application/srs_session_recorder.dart';
import 'package:nihongo_daily/features/daily_plan/application/srs_session_recorder_provider.dart';
import 'package:nihongo_daily/features/settings/application/preview_preferences.dart';
import '../srs/account_fixtures.dart' as account;
import '../srs/account_widget_test.dart' show Harness;
import '../srs/study_fixtures.dart' show fixtureItem;
import 'study_recovery_widget_test.dart' show RecoveryMemoryStore;
import 'study_session_recovery_fixtures.dart' show studyPlan;

final class DayGateway implements DailyPlanStudyDayGateway {
  DayGateway(this.current, this.source);
  final bool Function() current;
  final DaySource source;
  @override
  bool get isCurrent => current();
  @override
  Future<Object?> getDailyPlan(Map<String, Object> params) async {
    source.plans++;
    return studyPlan(45);
  }

  @override
  Future<Object?> getStudyDay(Map<String, Object> params) {
    source.days++;
    source.envelope = params;
    return source.response();
  }
}

final class DaySource
    implements DailyPlanRepositorySource, DurableStudySessionSource {
  DaySource(this.h);
  final Harness h;
  final store = RecoveryMemoryStore();
  int days = 0;
  int plans = 0;
  Map<String, Object>? envelope;
  Future<Object?> Function() response = () async => {
    'date': '2026-10-20',
    'timezone': 'Asia/Tokyo',
  };
  @override
  DailyPlanRepository? createDailyPlanRepository() {
    final ready = h.runtime.readyRuntime;
    return ready == null
        ? null
        : DailyPlanRepository(
            DayGateway(() => identical(h.runtime.readyRuntime, ready), this),
          );
  }

  @override
  DurableStudySessionRepository? createDurableStudySessionRepository() {
    final ready = h.runtime.readyRuntime;
    final delegate = createDailyPlanRepository();
    return ready == null || delegate == null
        ? null
        : DurableStudySessionRepository(
            auth: ready.auth,
            delegate: delegate,
            store: store,
          );
  }
}

Future<ProviderContainer> mountDay(
  WidgetTester tester,
  Harness h,
  DaySource source, {
  String route = '/plan',
  bool configured = true,
}) async {
  h.queue.items = [fixtureItem(level: PreviewLevel.n4)];
  final c = ProviderContainer(
    overrides: [
      if (configured) accountRuntimeProvider.overrideWithValue(h.runtime),
      if (configured) dailyPlanSourceProvider.overrideWithValue(source),
      if (configured) durableStudySourceProvider.overrideWithValue(source),
    ],
  );
  c.read(previewLevelProvider.notifier).state = PreviewLevel.n4;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await h.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(container: c, child: const NihongoDailyApp()),
  );
  if (configured) h.access.change(account.owner);
  await tester.pumpAndSettle();
  c.read(routerProvider).go(route);
  await tester.pumpAndSettle();
  return c;
}

Finder todayButton(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byType(OutlinedButton),
);
Future<void> chooseToday(
  WidgetTester tester, {
  String key = 'plan-today',
}) async {
  final button = todayButton(key);
  await tester.ensureVisible(button);
  await tester.pump();
  expect(button.hitTestable(), findsOneWidget);
  await tester.tap(button);
  await tester.pump();
}

void main() {
  testWidgets('unconfigured preview offers no server-day action', (
    tester,
  ) async {
    final h = Harness();
    final source = DaySource(h);
    await mountDay(tester, h, source, configured: false);
    expect(find.text('Chọn hôm nay theo hồ sơ'), findsNothing);
    expect(source.days, 0);
  });
  testWidgets(
    'plan today fills server date with empty request and no plan write/read',
    (tester) async {
      final h = Harness();
      final source = DaySource(h);
      await mountDay(tester, h, source);
      await chooseToday(tester);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('plan-date')))
            .controller!
            .text,
        '2026-10-20',
      );
      expect(source.envelope, {'p_request': <String, Object>{}});
      expect(source.days, 1);
      expect(source.plans, 0);
      await tester.ensureVisible(find.byKey(const Key('plan-load')));
      await tester.tap(find.byKey(const Key('plan-load')));
      await tester.pumpAndSettle();
      expect(source.plans, 1);
      expect(find.text('45/120 phút'), findsOneWidget);
    },
  );
  testWidgets('manual edit while day lookup waits is never overwritten', (
    tester,
  ) async {
    final h = Harness();
    final source = DaySource(h);
    final wait = Completer<Object?>();
    source.response = () => wait.future;
    await mountDay(tester, h, source);
    await chooseToday(tester);
    expect(
      tester.widget<OutlinedButton>(todayButton('plan-today')).onPressed,
      isNull,
    );
    await tester.enterText(find.byKey(const Key('plan-date')), '2026-10-21');
    wait.complete({'date': '2026-10-20', 'timezone': 'Asia/Tokyo'});
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('plan-date')))
          .controller!
          .text,
      '2026-10-21',
    );
    expect(source.days, 1);
    expect(source.plans, 0);
  });
  testWidgets('logout clears retained field and fences late old-owner day', (
    tester,
  ) async {
    final h = Harness();
    final source = DaySource(h);
    final wait = Completer<Object?>();
    source.response = () => wait.future;
    await mountDay(tester, h, source);
    final fieldState = tester.state(find.byKey(const Key('plan-date')));
    await chooseToday(tester);
    h.access.change(null);
    await tester.pumpAndSettle();
    wait.complete({'date': '2026-10-20', 'timezone': 'Asia/Tokyo'});
    await tester.pumpAndSettle();
    final hidden = find.byKey(const Key('plan-date'), skipOffstage: false);
    expect(identical(tester.state(hidden), fieldState), isTrue);
    expect(tester.widget<TextField>(hidden).controller!.text, isEmpty);
    expect(tester.widget<TextField>(hidden).enabled, isFalse);
    expect(find.text('Chọn hôm nay theo hồ sơ'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'changed timezone and raw errors stay safe with explicit retry only',
    (tester) async {
      final h = Harness();
      final source = DaySource(h)
        ..response = () async => {'date': '2026-10-20', 'timezone': 'UTC'};
      await mountDay(tester, h, source);
      await chooseToday(tester);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Múi giờ hồ sơ đã thay đổi. Hãy làm mới phiên tại Tài khoản.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('plan-date')))
            .controller!
            .text,
        isEmpty,
      );
      source.response = () async => throw StateError('PRIVATE TOKEN SQL');
      await chooseToday(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('PRIVATE'), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      expect(source.days, 2);
      source.response = () async => {
        'date': '2026-10-20',
        'timezone': 'Asia/Tokyo',
      };
      await chooseToday(tester);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('plan-date')))
            .controller!
            .text,
        '2026-10-20',
      );
      expect(source.days, 3);
    },
  );
  testWidgets('SRS today fills date without starting timer or submitting', (
    tester,
  ) async {
    final h = Harness();
    final source = DaySource(h);
    final c = await mountDay(tester, h, source, route: '/srs');
    await chooseToday(tester, key: 'srs-timer-today');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('srs-timer-date')))
          .controller!
          .text,
      '2026-10-20',
    );
    expect(c.read(srsSessionRecorderProvider).phase, StudyRecorderPhase.idle);
    expect(source.days, 1);
    expect(source.plans, 0);
    expect(source.store.records, isEmpty);
    await tester.ensureVisible(find.byKey(const Key('srs-timer-start')));
    await tester.tap(find.byKey(const Key('srs-timer-start')));
    await tester.pumpAndSettle();
    expect(
      c.read(srsSessionRecorderProvider).phase,
      StudyRecorderPhase.running,
    );
    expect(source.plans, 1);
    expect(source.store.records, isEmpty);
  });
}
