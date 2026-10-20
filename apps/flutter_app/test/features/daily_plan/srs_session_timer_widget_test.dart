// TEST ONLY memory Auth/RPC/storage/clock; native persistence is exercised by
// recorder fixtures/process tool and actual-SDK tests, not widget fake-clock I/O.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/auth/application/account_provider.dart';
import 'package:nihongo_daily/features/daily_plan/application/daily_plan_provider.dart';
import 'package:nihongo_daily/features/daily_plan/application/srs_session_recorder.dart';
import 'package:nihongo_daily/features/daily_plan/application/srs_session_recorder_provider.dart';
import 'package:nihongo_daily/features/daily_plan/data/daily_plan_repository.dart';
import 'package:nihongo_daily/features/srs/application/srs_study_provider.dart';
import 'package:nihongo_daily/features/settings/application/preview_preferences.dart';
import '../srs/account_fixtures.dart' as account;
import '../srs/account_widget_test.dart' show Harness;
import '../srs/study_fixtures.dart' show fixtureItem;
import 'study_recovery_widget_test.dart'
    show RecoveryMemoryStore, RecoverySource;
import 'study_session_recovery_fixtures.dart';
import 'srs_session_recorder_fixtures.dart';

final class TimerHarness {
  final h = Harness();
  final memory = RecoveryMemoryStore();
  final server = StudyServer();
  final clock = RecorderFixtureClock();
  late final store = StudyFaultStore(memory);
  late final source = RecoverySource(h, store, server);
  late ProviderContainer container;
}

Future<TimerHarness> mountTimer(
  WidgetTester tester, {
  bool configured = true,
}) async {
  final f = TimerHarness(); // Created inside the testWidgets zone.
  f.h.queue.items = [fixtureItem(level: PreviewLevel.n4)];
  f.container = ProviderContainer(
    overrides: [
      if (configured) accountRuntimeProvider.overrideWithValue(f.h.runtime),
      if (configured) durableStudySourceProvider.overrideWithValue(f.source),
      studyRecorderClockProvider.overrideWithValue(f.clock),
    ],
  );
  f.container.read(previewLevelProvider.notifier).state = PreviewLevel.n4;
  addTearDown(() async {
    final wait = f.server.writeWait;
    if (wait != null && !wait.isCompleted) wait.complete();
    await tester.pumpWidget(const SizedBox());
    f.container.dispose();
    await f.h.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: f.container,
      child: const NihongoDailyApp(),
    ),
  );
  if (configured) f.h.access.change(account.owner);
  await tester.pumpAndSettle();
  f.container.read(routerProvider).go('/srs');
  await tester.pumpAndSettle();
  if (configured) expect(f.container.read(canStartSrsRecorderProvider), isTrue);
  return f;
}

Future<void> startTimer(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('srs-timer-date')), '2026-10-20');
  await tester.ensureVisible(find.byKey(const Key('srs-timer-start')));
  await tester.tap(find.byKey(const Key('srs-timer-start')));
  await tester.pumpAndSettle();
}

Future<void> finishTimer(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('srs-timer-finish')));
  await tester.tap(find.byKey(const Key('srs-timer-finish')));
  await tester.pump();
}

void main() {
  testWidgets('preview has no active timer or invented save', (tester) async {
    final f = await mountTimer(tester, configured: false);
    expect(find.byKey(const Key('srs-timer-date')), findsNothing);
    expect(find.byKey(const Key('srs-timer-start')), findsNothing);
    expect(find.byKey(const Key('srs-timer-confirmed')), findsNothing);
    expect(f.server.writes, 0);
  });
  testWidgets(
    'explicit profile date validated then timer starts with real SRS card',
    (tester) async {
      final f = await mountTimer(tester);
      expect(find.text('猫'), findsOneWidget);
      expect(find.textContaining('Asia/Tokyo'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('srs-timer-date')),
        '2026-02-29',
      );
      await tester.tap(find.byKey(const Key('srs-timer-start')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('srs-timer-validation')), findsOneWidget);
      expect(f.server.reads, 0);
      await startTimer(tester);
      expect(find.text('00:00'), findsOneWidget);
      expect(f.server.reads, 1);
      expect(f.server.writes, 0);
      expect(
        tester
            .widget<DropdownButton<dynamic>>(find.byKey(const Key('srs-level')))
            .onChanged,
        isNull,
      );
      await finishTimer(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('Chỉ lưu buổi học từ 1 phút'), findsOneWidget);
      expect(f.server.writes, 0);
      expect(f.clock.ids, 0);
    },
  );
  testWidgets(
    'profile-level mismatch prevents starting even with a ready card',
    (tester) async {
      final f = await mountTimer(tester);
      f.h.queue.items = [fixtureItem()];
      await f.container
          .read(srsStudyProvider.notifier)
          .changeLevel(PreviewLevel.n5);
      await tester.pumpAndSettle();
      expect(f.container.read(canStartSrsRecorderProvider), isFalse);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('srs-timer-start')))
            .onPressed,
        isNull,
      );
      expect(f.server.reads, 0);
      expect(f.server.writes, 0);
    },
  );

  testWidgets(
    'finish persists SRS report once then displays fresh confirmed progress',
    (tester) async {
      final f = await mountTimer(tester);
      await startTimer(tester);
      f.clock.advance(const Duration(minutes: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('01:00'), findsOneWidget);
      f.server.writeWait = Completer<void>();
      f.server.entered = Completer<void>();
      await finishTimer(tester);
      expect(f.server.entered!.isCompleted, isTrue);
      expect(find.byKey(const Key('srs-timer-finish')), findsNothing);
      expect(find.byKey(const Key('srs-timer-start')), findsNothing);
      expect(find.byKey(const Key('srs-timer-confirmed')), findsNothing);
      expect(f.server.writes, 1);
      f.server.writeWait!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Buổi học đã được ghi nhận.'), findsOneWidget);
      expect(find.text('Ngày 2026-10-20: 45/120 phút'), findsOneWidget);
      final record = (await f.memory.list(account.owner)).single;
      expect(record.acknowledged, isTrue);
      expect(record.event.area.wireName, 'SRS');
      expect(
        record.event.endedAt.difference(record.event.startedAt),
        const Duration(minutes: 1),
      );
      expect(f.clock.ids, 1);
    },
  );
  testWidgets(
    'pending report blocks new interval before plan read and opens recovery',
    (tester) async {
      final f = await mountTimer(tester);
      await f.memory.stage(account.owner, studyEvent());
      await startTimer(tester);
      expect(find.textContaining('Hãy xử lý buổi học còn chờ'), findsOneWidget);
      expect(find.byKey(const Key('srs-timer-elapsed')), findsNothing);
      expect(f.server.reads, 0);
      await tester.tap(find.text('Mở buổi học chờ đồng bộ'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('study-recovery-check')), findsOneWidget);
      expect(f.server.writes, 0);
    },
  );
  testWidgets(
    'failed stage and uncertain commit retain same report across navigation',
    (tester) async {
      final f = await mountTimer(tester);
      await startTimer(tester);
      f.clock.advance(const Duration(minutes: 1));
      final originalEnd = f.clock.instant;
      f.store.failStage = true;
      await finishTimer(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('srs-timer-retry')), findsOneWidget);
      expect(find.byKey(const Key('srs-timer-confirmed')), findsNothing);
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(f.server.writes, 0);
      f.container.read(routerProvider).go('/auth');
      await tester.pumpAndSettle();
      f.container.read(routerProvider).go('/srs');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('srs-timer-retry')), findsOneWidget);
      f.store.failStage = false;
      f.server.writeFailure = const DailyPlanFailure(
        DailyPlanErrorCode.networkUnavailable,
        retryable: true,
      );
      f.server.commitBeforeFailure = true;
      f.clock.advance(const Duration(minutes: 5));
      await tester.tap(find.byKey(const Key('srs-timer-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('srs-timer-start')), findsNothing);
      expect(
        (await f.memory.list(account.owner)).single.event.endedAt,
        originalEnd,
      );
      await tester.pump(const Duration(seconds: 30));
      expect(f.server.writes, 1);
      f.server.writeFailure = null;
      await tester.tap(find.byKey(const Key('srs-timer-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('srs-timer-confirmed')), findsOneWidget);
      expect(f.server.committed.length, 1);
      expect(f.clock.ids, 1);
    },
  );
  testWidgets(
    'background and route loss cancel unfinished timer without writes',
    (tester) async {
      final f = await mountTimer(tester);
      await startTimer(tester);
      f.clock.advance(const Duration(minutes: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(
        f.container.read(srsSessionRecorderProvider).phase,
        StudyRecorderPhase.canceled,
      );
      expect(f.server.writes, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await startTimer(tester);
      f.container.read(routerProvider).go('/auth');
      await tester.pumpAndSettle();
      expect(
        f.container.read(srsSessionRecorderProvider).phase,
        StudyRecorderPhase.canceled,
      );
      expect(f.clock.ids, 0);
    },
  );
  testWidgets(
    'revocation retains cleared field observer and hides late old save',
    (tester) async {
      final f = await mountTimer(tester);
      await startTimer(tester);
      final field = find.byKey(const Key('srs-timer-date'));
      final fieldState = tester.state(field);
      f.clock.advance(const Duration(minutes: 1));
      f.server.writeWait = Completer<void>();
      f.server.entered = Completer<void>();
      await finishTimer(tester);
      expect(f.server.entered!.isCompleted, isTrue);
      f.h.access.change(null);
      await tester.pumpAndSettle();
      final hidden = find.byKey(
        const Key('srs-timer-date'),
        skipOffstage: false,
      );
      expect(identical(tester.state(hidden), fieldState), isTrue);
      expect(tester.widget<TextField>(hidden).enabled, isFalse);
      expect(tester.widget<TextField>(hidden).controller!.text, isEmpty);
      expect(find.byKey(const Key('srs-timer-date')), findsNothing);
      f.server.writeWait!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('srs-timer-confirmed')), findsNothing);
      expect((await f.memory.list(account.owner)).single.isPending, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'large text narrow panel distinguishes confirmed reload failure',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1100);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final f = await mountTimer(tester);
      await startTimer(tester);
      f.clock.advance(const Duration(minutes: 1));
      f.server.readFailure = const DailyPlanFailure(
        DailyPlanErrorCode.networkUnavailable,
      );
      await finishTimer(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Buổi học đã được ghi nhận. Chưa tải được tiến độ mới.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('srs-timer-progress')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
