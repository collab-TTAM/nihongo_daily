// TEST ONLY owned Auth/RPC/storage/clock and reading material. The fixture grants
// a reading plan explicitly; production SQL remains blocked pending reviewed data.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/auth/application/account_provider.dart';
import 'package:nihongo_daily/features/daily_plan/application/daily_plan_provider.dart';
import 'package:nihongo_daily/features/daily_plan/application/srs_session_recorder_provider.dart';
import 'package:nihongo_daily/features/daily_plan/application/study_session_recorder.dart';
import 'package:nihongo_daily/features/daily_plan/domain/daily_plan.dart';
import 'package:nihongo_daily/features/daily_plan/data/durable_study_session_repository.dart'
    show sameStudyEvent;
import 'package:nihongo_daily/features/reading/application/reading_provider.dart';
import 'package:nihongo_daily/features/reading/data/local_reading_repository.dart';
import 'package:nihongo_daily/features/reading/domain/reading_material.dart';
import 'package:nihongo_daily/features/reading/domain/reading_repository.dart';
import 'package:nihongo_daily/features/settings/application/preview_preferences.dart';

import '../daily_plan/srs_session_timer_widget_test.dart' show TimerHarness;
import '../daily_plan/study_session_recovery_fixtures.dart';
import '../srs/account_fixtures.dart' as account;
import 'reading_widget_test.dart'
    show material, TestReadingRepository, openReading, tapReading;

const area = DailyPlanArea.listeningReading;
Finder timer(String suffix) =>
    find.byKey(Key('listening_reading-timer-$suffix'));

Future<TimerHarness> mountReadingStudy(
  WidgetTester tester, {
  bool configured = true,
  PreviewLevel level = PreviewLevel.n4,
  ReadingRepository? content,
  StateProvider<ReadingRepository?>? source,
  bool settled = true,
  Size size = const Size(1100, 900),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final f = TimerHarness();
  f.container = ProviderContainer(
    overrides: [
      if (configured) accountRuntimeProvider.overrideWithValue(f.h.runtime),
      if (configured) durableStudySourceProvider.overrideWithValue(f.source),
      studyRecorderClockProvider.overrideWithValue(f.clock),
      if (source != null)
        readingRepositoryProvider.overrideWith((ref) => ref.watch(source))
      else
        readingRepositoryProvider.overrideWithValue(
          content ??
              LocalReadingRepository(read: () async => material(level: 'N4')),
        ),
    ],
  );
  f.container.read(previewLevelProvider.notifier).state = level;
  addTearDown(() async {
    if (!(f.server.readWait?.isCompleted ?? true)) {
      f.server.readWait!.complete(studyPlan(0));
    }
    if (!(f.server.writeWait?.isCompleted ?? true)) {
      f.server.writeWait!.complete();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    f.container.dispose();
    await f.h.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: f.container,
      child: const NihongoDailyApp(),
    ),
  );
  if (configured) {
    f.h.access.change(account.owner);
  }
  await tester.pumpAndSettle();
  f.container.read(routerProvider).go('/listening');
  if (settled) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  return f;
}

Future<void> begin(WidgetTester tester, {bool settle = true}) async {
  await tester.enterText(timer('date'), '2026-10-20');
  // Complete date editing before scrolling to the separate start control.
  // Otherwise EditableText's deferred caret reveal can undo ensureVisible
  // during tapReading's pump and move the real hit target offscreen.
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  await tapReading(tester, timer('start'), settle: settle);
}

void main() {
  for (final action in ['reading-restart', 'reading-reload']) {
    testWidgets('retained start cannot follow $action into a new round', (
      tester,
    ) async {
      final f = await mountReadingStudy(tester);
      await openReading(tester);
      final passage = f.container.read(readingSelectedPassageProvider);
      final before = f.container.read(studySessionRecorderProvider);
      final stale = tester.widget<FilledButton>(timer('start')).onPressed!;
      await tapReading(tester, find.byKey(Key(action)));
      if (action == 'reading-reload') {
        await openReading(tester);
      }
      // The same passage and idle recorder cannot stand in for round identity.
      expect(f.container.read(readingSelectedPassageProvider), same(passage));
      expect(f.container.read(studySessionRecorderProvider), same(before));
      await tester.enterText(timer('date'), '2026-10-20');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      stale();
      await tester.pumpAndSettle();
      expect(f.container.read(studySessionRecorderProvider), same(before));
      expect(f.server.reads, 0);
      expect(f.server.writes, 0);
      expect(f.clock.ids, 0);
      expect(f.memory.records, isEmpty);
      await begin(tester);
      expect(timer('elapsed'), findsOneWidget);
      expect(f.server.reads, 1);
    });
  }

  testWidgets('replaced reading source cannot reuse its retained start', (
    tester,
  ) async {
    final passages = decodeReadingMaterial(
      material(level: 'N4'),
      PreviewLevel.n4,
    );
    final first = TestReadingRepository((_) async => passages);
    final second = TestReadingRepository((_) async => passages);
    final source = StateProvider<ReadingRepository?>((ref) => first);
    final f = await mountReadingStudy(tester, source: source);
    await openReading(tester);
    final stale = tester.widget<FilledButton>(timer('start')).onPressed!;
    f.container.read(source.notifier).state = second;
    await tester.pumpAndSettle();
    expect(f.container.read(readingSelectedPassageProvider), isNull);
    await openReading(tester);
    expect(
      f.container.read(readingSelectedPassageProvider),
      same(passages.single),
    );
    await tester.enterText(timer('date'), '2026-10-20');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    stale();
    await tester.pumpAndSettle();
    expect(f.server.reads, 0);
    expect(f.server.writes, 0);
    expect(f.clock.ids, 0);
    expect(f.memory.records, isEmpty);
    await begin(tester);
    expect(timer('elapsed'), findsOneWidget);
    expect(f.server.reads, 1);
  });

  testWidgets('A B A owner replacement invalidates an old reading start', (
    tester,
  ) async {
    final f = await mountReadingStudy(tester);
    await openReading(tester);
    final stale = tester.widget<FilledButton>(timer('start')).onPressed!;
    final oldOwner = f.container.read(studySessionRecorderProvider.notifier);
    for (final user in [account.other, account.owner]) {
      f.h.access.change(user);
      await tester.pumpAndSettle();
      expect(
        f.container.read(studySessionRecorderProvider.notifier),
        isNot(same(oldOwner)),
      );
      expect(tester.widget<TextField>(timer('date')).controller!.text, isEmpty);
    }
    await tester.enterText(timer('date'), '2026-10-20');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    stale();
    await tester.pumpAndSettle();
    expect(f.server.reads, 0);
    expect(f.server.writes, 0);
    expect(f.clock.ids, 0);
    expect(f.memory.records, isEmpty);
    await begin(tester);
    expect(timer('elapsed'), findsOneWidget);
    expect(f.server.reads, 1);
  });

  testWidgets(
    'disposed reading start and finish are harmless after route exit',
    (tester) async {
      final f = await mountReadingStudy(tester);
      await openReading(tester);
      final staleStart = tester.widget<FilledButton>(timer('start')).onPressed!;
      await begin(tester);
      final staleFinish = tester
          .widget<FilledButton>(timer('finish'))
          .onPressed!;
      f.clock.advance(const Duration(seconds: 61));
      f.container.read(routerProvider).go('/study');
      await tester.pumpAndSettle();
      expect(staleStart, returnsNormally);
      expect(staleFinish, returnsNormally);
      await tester.pumpAndSettle();
      expect(
        f.container.read(studySessionRecorderProvider).phase,
        StudyRecorderPhase.canceled,
      );
      expect(f.server.reads, 1);
      expect(f.server.writes, 0);
      expect(f.clock.ids, 0);
      expect(f.memory.records, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('public reading opens without any account timer or dispatch', (
    tester,
  ) async {
    final f = await mountReadingStudy(tester, configured: false);
    await openReading(tester);
    expect(timer('date'), findsNothing);
    expect(timer('start'), findsNothing);
    expect(f.server.reads, 0);
    expect(f.server.writes, 0);
    expect(f.clock.ids, 0);
  });

  testWidgets(
    'selected profile-level reading explicitly records one staged interval',
    (tester) async {
      final f = await mountReadingStudy(tester);
      expect(f.container.read(canStartStudyRecorderProvider(area)), isFalse);
      expect(tester.widget<FilledButton>(timer('start')).onPressed, isNull);
      await openReading(tester);
      expect(f.container.read(canStartStudyRecorderProvider(area)), isTrue);
      expect(f.server.reads, 0);
      final started = f.clock.instant;
      await begin(tester);
      expect(timer('elapsed'), findsOneWidget);
      f.clock.advance(const Duration(seconds: 61));
      await tester.pump(const Duration(seconds: 1));
      await tapReading(tester, timer('finish'));
      expect(timer('confirmed'), findsOneWidget);
      expect(f.server.writes, 1);
      expect(f.clock.ids, 1);
      final record = f.memory.records.values.single;
      expect(record.acknowledged, isTrue);
      expect(record.userId, account.owner);
      expect(record.event.area, area);
      expect(record.event.startedAt, started);
      expect(record.event.endedAt, f.clock.instant);
      expect(record.event.date.value, '2026-10-20');
      expect(f.server.reads, 2);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('reading-audio-unavailable')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'blocked authoritative reading plan refuses timing even when text is selected',
    (tester) async {
      final f = await mountReadingStudy(tester);
      await openReading(tester);
      final plan = studyPlan(0);
      final blocks = plan['blocks']! as List<Map<String, Object>>;
      final blocked = blocks.singleWhere(
        (b) => b['type'] == 'LISTENING_READING',
      );
      blocked['status'] = 'BLOCKED';
      blocked['item_count'] = 0;
      f.server.planOverride = plan;
      await begin(tester);
      expect(
        f.container.read(studySessionRecorderProvider).phase,
        StudyRecorderPhase.canceled,
      );
      expect(timer('elapsed'), findsNothing);
      expect(f.server.writes, 0);
      expect(f.clock.ids, 0);
      expect(f.memory.records, isEmpty);
    },
  );

  testWidgets('selected reading at a different profile level cannot start', (
    tester,
  ) async {
    final f = await mountReadingStudy(
      tester,
      level: PreviewLevel.n5,
      content: TestReadingRepository(
        (level) async =>
            decodeReadingMaterial(material(level: level.label), level),
      ),
    );
    await openReading(tester);
    expect(f.container.read(canStartStudyRecorderProvider(area)), isFalse);
    expect(tester.widget<FilledButton>(timer('start')).onPressed, isNull);
    expect(f.server.reads, 0);
  });

  testWidgets('held reload clears selection and interrupts running reading', (
    tester,
  ) async {
    final held = Completer<String>();
    var reads = 0;
    final f = await mountReadingStudy(
      tester,
      content: LocalReadingRepository(
        read: () =>
            ++reads == 1 ? Future.value(material(level: 'N4')) : held.future,
      ),
    );
    await openReading(tester);
    await begin(tester);
    await tapReading(
      tester,
      find.byKey(const Key('reading-reload')),
      settle: false,
    );
    await tester.pump();
    expect(f.container.read(readingSelectedPassageProvider), isNull);
    expect(f.container.read(canStartStudyRecorderProvider(area)), isFalse);
    expect(
      f.container.read(studySessionRecorderProvider).phase,
      StudyRecorderPhase.canceled,
    );
    expect(find.byKey(const Key('reading-loading')), findsOneWidget);
    held.complete(material(level: 'N4', version: 2));
    await tester.pumpAndSettle();
    expect(timer('elapsed'), findsNothing);
    expect(f.server.writes, 0);
    expect(f.clock.ids, 0);
    await openReading(tester);
    expect(f.container.read(canStartStudyRecorderProvider(area)), isTrue);
    expect(timer('elapsed'), findsNothing);
  });

  for (final action in ['reading-back', 'reading-restart']) {
    testWidgets('$action interrupts without creating a report', (tester) async {
      final f = await mountReadingStudy(tester);
      await openReading(tester);
      await begin(tester);
      await tapReading(tester, find.byKey(Key(action)));
      expect(
        f.container.read(studySessionRecorderProvider).phase,
        StudyRecorderPhase.canceled,
      );
      expect(f.server.writes, 0);
      expect(f.clock.ids, 0);
      expect(f.memory.records, isEmpty);
    });
  }

  testWidgets(
    'late preflight after leaving reading cannot start or publish timing',
    (tester) async {
      final f = await mountReadingStudy(tester);
      await openReading(tester);
      f.server.readWait = Completer<Object?>();
      await begin(tester, settle: false);
      expect(f.server.reads, 1);
      f.container.read(routerProvider).go('/study');
      await tester.pumpAndSettle();
      f.server.readWait!.complete(studyPlan(0));
      await tester.pumpAndSettle();
      expect(
        f.container.read(studySessionRecorderProvider).phase,
        StudyRecorderPhase.canceled,
      );
      expect(f.server.writes, 0);
      expect(f.clock.ids, 0);
      expect(find.text('Không gian học tập'), findsOneWidget);
    },
  );

  testWidgets(
    'reading frozen report retries unchanged through the existing SRS panel',
    (tester) async {
      final f = await mountReadingStudy(tester);
      await openReading(tester);
      await begin(tester);
      f.clock.advance(const Duration(seconds: 61));
      f.store.failStage = true;
      await tapReading(tester, timer('finish'));
      final event = f.container
          .read(studySessionRecorderProvider.notifier)
          .pendingEvent!;
      expect(f.server.writes, 0);
      f.container.read(routerProvider).go('/srs');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('srs-timer-frozen-report')), findsOneWidget);
      f.store.failStage = false;
      await tapReading(tester, find.byKey(const Key('srs-timer-retry')));
      final record = f.memory.records.values.single;
      expect(record.event.area, area);
      expect(sameStudyEvent(record.event, event), isTrue);
      expect(record.acknowledged, isTrue);
      expect(f.server.writes, 1);
      expect(f.clock.ids, 1);
    },
  );

  testWidgets(
    'old reading finish callback cannot finish a restarted interval',
    (tester) async {
      final f = await mountReadingStudy(tester);
      await openReading(tester);
      await begin(tester);
      final stale = tester.widget<FilledButton>(timer('finish')).onPressed!;
      await tapReading(tester, find.byKey(const Key('reading-restart')));
      await begin(tester);
      f.clock.advance(const Duration(seconds: 61));
      stale();
      await tester.pump();
      expect(
        f.container.read(studySessionRecorderProvider).phase,
        StudyRecorderPhase.running,
      );
      expect(f.server.writes, 0);
      await tapReading(tester, timer('finish'));
      expect(f.server.writes, 1);
    },
  );

  testWidgets('reading timer remains usable at 320px and 200 percent text', (
    tester,
  ) async {
    final f = await mountReadingStudy(
      tester,
      size: const Size(320, 640),
      scale: 2,
    );
    await openReading(tester);
    await begin(tester);
    f.clock.advance(const Duration(seconds: 61));
    await tapReading(tester, timer('finish'));
    expect(timer('confirmed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'logout clears but retains the timer date editor during a held save',
    (tester) async {
      final f = await mountReadingStudy(tester);
      await openReading(tester);
      await begin(tester);
      f.clock.advance(const Duration(seconds: 61));
      f.server.entered = Completer<void>();
      f.server.writeWait = Completer<void>();
      await tapReading(tester, timer('finish'), settle: false);
      expect(f.server.entered!.isCompleted, isTrue);
      f.h.access.change(null);
      await tester.pumpAndSettle();
      final hiddenDate = find.byKey(
        const Key('listening_reading-timer-date'),
        skipOffstage: false,
      );
      expect(hiddenDate, findsOneWidget);
      expect(tester.widget<TextField>(hiddenDate).controller!.text, isEmpty);
      expect(timer('confirmed'), findsNothing);
      f.server.writeWait!.complete();
      await tester.pumpAndSettle();
      expect(timer('confirmed'), findsNothing);
      expect(f.memory.records.values.single.userId, account.owner);
      expect(f.memory.records.values.single.isPending, isTrue);
    },
  );
}
