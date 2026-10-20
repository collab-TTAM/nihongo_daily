// TEST ONLY Auth/RPC/storage/clock. Real original exports are decoded outside
// widget fake time; native durability and hosted acceptance are separate gates.
import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/auth/application/account_provider.dart';
import 'package:nihongo_daily/features/auth/application/account_startup_controller.dart';
import 'package:nihongo_daily/features/auth/presentation/account_startup_app.dart';
import 'package:nihongo_daily/features/curriculum/application/curriculum_provider.dart';
import 'package:nihongo_daily/features/curriculum/data/bundled_curriculum_repository.dart';
import 'package:nihongo_daily/features/curriculum/domain/curriculum.dart';
import 'package:nihongo_daily/features/daily_plan/application/daily_plan_provider.dart';
import 'package:nihongo_daily/features/daily_plan/application/srs_session_recorder_provider.dart';
import 'package:nihongo_daily/features/daily_plan/application/study_session_recorder.dart';
import 'package:nihongo_daily/features/daily_plan/data/daily_plan_repository.dart';
import 'package:nihongo_daily/features/daily_plan/data/durable_study_session_repository.dart';
import 'package:nihongo_daily/features/daily_plan/domain/daily_plan.dart';
import 'package:nihongo_daily/features/settings/application/preview_preferences.dart';
import '../curriculum/curriculum_widget_test.dart'
    show FixtureCurriculumRepository;
import '../srs/account_fixtures.dart' as account;
import '../srs/study_fixtures.dart' show fixtureItem;
import 'srs_session_timer_widget_test.dart' show TimerHarness;
import 'study_recovery_widget_test.dart' show RecoverySource;
import 'study_session_recovery_fixtures.dart';

final originalReaderEntries =
    <(CurriculumKind, PreviewLevel), List<CurriculumEntry>>{};
CurriculumRepository readerData() => FixtureCurriculumRepository(
  (kind, level) async => originalReaderEntries[(kind, level)]!,
);
DailyPlanArea areaOf(CurriculumKind kind) => kind == CurriculumKind.vocabulary
    ? DailyPlanArea.vocabulary
    : DailyPlanArea.grammar;
Finder control(CurriculumKind kind, String suffix) =>
    find.byKey(Key('${kind.name}-timer-$suffix'));

Future<TimerHarness> mountReaderTimer(
  WidgetTester tester,
  CurriculumKind kind, {
  bool configured = true,
  PreviewLevel level = PreviewLevel.n4,
  CurriculumRepository? content,
  bool settled = true,
  Size size = const Size(1200, 900),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final f = TimerHarness(); // Auth listeners belong to this testWidgets zone.
  f.h.queue.items = [fixtureItem(level: PreviewLevel.n4)];
  f.container = ProviderContainer(
    overrides: [
      if (configured) accountRuntimeProvider.overrideWithValue(f.h.runtime),
      if (configured) durableStudySourceProvider.overrideWithValue(f.source),
      studyRecorderClockProvider.overrideWithValue(f.clock),
      curriculumRepositoryProvider.overrideWithValue(content ?? readerData()),
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
  if (configured) {
    f.h.access.change(account.owner);
  }
  await tester.pumpAndSettle();
  f.container.read(routerProvider).go('/${kind.name}');
  if (settled) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  return f;
}

Future<void> readerTap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pump();
}

Future<void> beginReader(
  WidgetTester tester,
  CurriculumKind kind, {
  bool settled = true,
}) async {
  await tester.enterText(control(kind, 'date'), '2026-10-20');
  await readerTap(tester, control(kind, 'start'));
  if (settled) {
    await tester.pumpAndSettle();
  }
}

Future<void> chooseReaderLevel(WidgetTester tester, String level) async {
  await readerTap(tester, find.byKey(const Key('curriculum-level')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(level).last);
  await tester.pumpAndSettle();
}

final class ReaderOwnedRuntime<T>
    implements AccountStartupRuntime<T>, DurableStudySessionSource {
  ReaderOwnedRuntime(this.account, this.source);
  @override
  final T account;
  final RecoverySource source;
  Completer<void>? closing;
  @override
  bool get canOfferLogin => false;
  @override
  Future<void> start() async {}
  @override
  Future<void> close() async => await closing?.future;
  @override
  DurableStudySessionRepository? createDurableStudySessionRepository() =>
      source.createDurableStudySessionRepository();
}

void main() {
  setUpAll(() async {
    for (final kind in CurriculumKind.values) {
      for (final level in PreviewLevel.values) {
        originalReaderEntries[(kind, level)] = decodeCurriculum(
          await File(
            '../../data/${level.name}/${kind.name}.json',
          ).readAsString(),
          kind,
          level,
        );
      }
    }
  });

  for (final kind in CurriculumKind.values) {
    testWidgets('unconfigured ${kind.name} reads originals without recording', (
      tester,
    ) async {
      final f = await mountReaderTimer(tester, kind, configured: false);
      expect(
        find.byKey(
          ValueKey(originalReaderEntries[(kind, PreviewLevel.n4)]!.first.id),
        ),
        findsOneWidget,
      );
      expect(control(kind, 'date'), findsNothing);
      expect(control(kind, 'start'), findsNothing);
      expect(control(kind, 'confirmed'), findsNothing);
      expect(f.server.reads, 0);
      expect(f.server.writes, 0);
      expect(f.h.queue.calls, 0);
    });

    testWidgets(
      'configured ${kind.name} explicitly times and confirms one report',
      (tester) async {
        final f = await mountReaderTimer(tester, kind);
        expect(f.server.reads, 0);
        expect(f.server.writes, 0);
        expect(f.h.queue.calls, 0);
        expect(
          f.container.read(canStartStudyRecorderProvider(areaOf(kind))),
          isTrue,
        );
        await tester.enterText(control(kind, 'date'), '2026-02-29');
        await readerTap(tester, control(kind, 'start'));
        await tester.pumpAndSettle();
        expect(control(kind, 'validation'), findsOneWidget);
        expect(f.server.reads, 0);
        await beginReader(tester, kind);
        expect(control(kind, 'elapsed'), findsOneWidget);
        expect(f.server.reads, 1);
        expect(f.server.writes, 0);
        f.clock.advance(const Duration(seconds: 61));
        await tester.pump(const Duration(seconds: 1));
        f.server.writeWait = Completer();
        f.server.entered = Completer();
        await readerTap(tester, control(kind, 'finish'));
        expect(f.server.entered!.isCompleted, isTrue);
        expect(control(kind, 'finish'), findsNothing);
        expect(control(kind, 'start'), findsNothing);
        expect(control(kind, 'confirmed'), findsNothing);
        expect(control(kind, 'frozen-report'), findsOneWidget);
        expect(f.server.writes, 1);
        f.server.writeWait!.complete();
        await tester.pumpAndSettle();
        expect(control(kind, 'confirmed'), findsOneWidget);
        expect(find.text('Ngày 2026-10-20: 45/120 phút'), findsOneWidget);
        final record = (await f.memory.list(account.owner)).single;
        expect(record.acknowledged, isTrue);
        expect(record.event.area, areaOf(kind));
        expect(record.event.date, DailyPlanDate('2026-10-20'));
        expect(
          record.event.endedAt.difference(record.event.startedAt),
          const Duration(seconds: 61),
        );
        expect(f.server.writes, 1);
        expect(f.server.reads, 2);
        expect(f.clock.ids, 1);
        expect(f.h.queue.calls, 0);
      },
    );
  }

  testWidgets(
    'public N5 cannot credit an N4 profile, changing to N4 permits explicit start',
    (tester) async {
      final f = await mountReaderTimer(
        tester,
        CurriculumKind.vocabulary,
        level: PreviewLevel.n5,
      );
      expect(
        tester
            .widget<FilledButton>(control(CurriculumKind.vocabulary, 'start'))
            .onPressed,
        isNull,
      );
      expect(f.container.read(accountStateProvider).profile!.level, 'N4');
      expect(f.server.reads, 0);
      await chooseReaderLevel(tester, 'N4');
      expect(
        tester
            .widget<FilledButton>(control(CurriculumKind.vocabulary, 'start'))
            .onPressed,
        isNotNull,
      );
      expect(f.container.read(accountStateProvider).profile!.level, 'N4');
      expect(f.server.reads, 0);
      expect(f.server.writes, 0);
    },
  );

  for (final condition in ['loading', 'error', 'empty', 'wrong-level']) {
    testWidgets('$condition content cannot start a reader report', (
      tester,
    ) async {
      final waiting = Completer<List<CurriculumEntry>>();
      addTearDown(() {
        if (!waiting.isCompleted) {
          waiting.complete([]);
        }
      });
      final content = FixtureCurriculumRepository((kind, level) {
        if (condition == 'loading') {
          return waiting.future;
        }
        if (condition == 'error') {
          return Future.error(StateError('PRIVATE ASSET TOKEN'));
        }
        return Future.value(
          condition == 'empty'
              ? []
              : originalReaderEntries[(kind, PreviewLevel.n5)]!,
        );
      });
      final f = await mountReaderTimer(
        tester,
        CurriculumKind.grammar,
        content: content,
        settled: condition != 'loading',
      );
      expect(
        tester
            .widget<FilledButton>(control(CurriculumKind.grammar, 'start'))
            .onPressed,
        isNull,
      );
      expect(
        f.container.read(canStartStudyRecorderProvider(DailyPlanArea.grammar)),
        isFalse,
      );
      expect(find.textContaining('PRIVATE ASSET TOKEN'), findsNothing);
      expect(f.server.reads, 0);
      expect(f.server.writes, 0);
    });
  }

  testWidgets(
    'refresh with retained data cancels timing until a settled reload',
    (tester) async {
      final pending = Completer<List<CurriculumEntry>>();
      var loads = 0;
      final content = FixtureCurriculumRepository((kind, level) {
        if (loads++ == 0) {
          return Future.value(originalReaderEntries[(kind, level)]!);
        }
        return pending.future;
      });
      addTearDown(() {
        if (!pending.isCompleted) {
          pending.complete(
            originalReaderEntries[(
              CurriculumKind.vocabulary,
              PreviewLevel.n4,
            )]!,
          );
        }
      });
      final f = await mountReaderTimer(
        tester,
        CurriculumKind.vocabulary,
        content: content,
      );
      await beginReader(tester, CurriculumKind.vocabulary);
      f.container.invalidate(curriculumProvider(CurriculumKind.vocabulary));
      await tester.pump();
      await tester.pump();
      expect(
        f.container
            .read(curriculumProvider(CurriculumKind.vocabulary))
            .isLoading,
        isTrue,
      );
      expect(
        f.container.read(
          canStartStudyRecorderProvider(DailyPlanArea.vocabulary),
        ),
        isFalse,
      );
      expect(
        f.container.read(studySessionRecorderProvider).phase,
        StudyRecorderPhase.canceled,
      );
      expect(
        tester
            .widget<FilledButton>(control(CurriculumKind.vocabulary, 'start'))
            .onPressed,
        isNull,
      );
      pending.complete(
        originalReaderEntries[(CurriculumKind.vocabulary, PreviewLevel.n4)]!,
      );
      await tester.pumpAndSettle();
      expect(
        f.container.read(
          canStartStudyRecorderProvider(DailyPlanArea.vocabulary),
        ),
        isTrue,
      );
      expect(control(CurriculumKind.vocabulary, 'elapsed'), findsNothing);
      expect(f.server.reads, 1);
      expect(f.server.writes, 0);
      expect(f.clock.ids, 0);
    },
  );

  testWidgets(
    'pending reports block reads and another ready area cannot replace blocked grammar',
    (tester) async {
      final f = await mountReaderTimer(tester, CurriculumKind.grammar);
      await f.memory.stage(account.owner, studyEvent());
      await beginReader(tester, CurriculumKind.grammar);
      expect(find.textContaining('Hãy xử lý buổi học còn chờ'), findsOneWidget);
      expect(f.server.reads, 0);
      expect(f.server.writes, 0);
      await f.memory.reject(
        account.owner,
        studyEvent().clientEventId,
        DailyPlanErrorCode.forbidden,
      );
      final plan = studyPlan(0);
      final blocks = plan['blocks']! as List<Map<String, Object>>;
      final grammar = blocks.singleWhere((b) => b['type'] == 'GRAMMAR');
      grammar['status'] = 'BLOCKED';
      grammar['item_count'] = 0;
      f.server.planOverride = plan;
      await beginReader(tester, CurriculumKind.grammar);
      expect(control(CurriculumKind.grammar, 'elapsed'), findsNothing);
      expect(f.server.reads, 1);
      expect(f.server.writes, 0);
      expect(f.clock.ids, 0);
    },
  );

  testWidgets(
    'unstaged grammar report survives SRS and vocabulary routes with exact explicit retry',
    (tester) async {
      final f = await mountReaderTimer(tester, CurriculumKind.grammar);
      await beginReader(tester, CurriculumKind.grammar);
      f.clock.advance(const Duration(minutes: 1));
      f.store.failStage = true;
      await readerTap(tester, control(CurriculumKind.grammar, 'finish'));
      await tester.pumpAndSettle();
      final frozen = f.container
          .read(studySessionRecorderProvider.notifier)
          .pendingEvent!;
      expect(await f.memory.list(account.owner), isEmpty);
      expect(f.server.writes, 0);
      f.container.read(routerProvider).go('/srs');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('srs-timer-report-area')), findsOneWidget);
      expect(find.byKey(const Key('srs-timer-frozen-report')), findsOneWidget);
      expect(find.byKey(const Key('srs-timer-start')), findsNothing);
      expect(
        identical(
          f.container.read(studySessionRecorderProvider.notifier).pendingEvent,
          frozen,
        ),
        isTrue,
      );
      f.container.read(routerProvider).go('/vocabulary');
      await tester.pumpAndSettle();
      expect(control(CurriculumKind.vocabulary, 'report-area'), findsOneWidget);
      expect(
        control(CurriculumKind.vocabulary, 'frozen-report'),
        findsOneWidget,
      );
      expect(control(CurriculumKind.vocabulary, 'start'), findsNothing);
      expect(
        tester
            .widget<TextField>(control(CurriculumKind.vocabulary, 'date'))
            .enabled,
        isFalse,
      );
      f.store.failStage = false;
      f.server.writeFailure = const DailyPlanFailure(
        DailyPlanErrorCode.networkUnavailable,
      );
      f.server.commitBeforeFailure = true;
      await readerTap(tester, control(CurriculumKind.vocabulary, 'retry'));
      await tester.pumpAndSettle();
      final pending = (await f.memory.list(account.owner)).single;
      expect(pending.isPending, isTrue);
      expect(sameStudyEvent(pending.event, frozen), isTrue);
      expect(f.server.writes, 1);
      expect(f.clock.ids, 1);
      f.server.writeFailure = null;
      await readerTap(tester, control(CurriculumKind.vocabulary, 'retry'));
      await tester.pumpAndSettle();
      final resolved = (await f.memory.list(account.owner)).single;
      expect(resolved.acknowledged, isTrue);
      expect(sameStudyEvent(resolved.event, frozen), isTrue);
      expect(resolved.event.area, DailyPlanArea.grammar);
      expect(control(CurriculumKind.vocabulary, 'confirmed'), findsOneWidget);
      expect(f.server.committed.length, 1);
      expect(f.server.writes, 2);
      expect(f.clock.ids, 1);
    },
  );

  testWidgets(
    'empty search, level, route and background cancel unfinished reader time',
    (tester) async {
      final f = await mountReaderTimer(tester, CurriculumKind.vocabulary);
      for (final cause in ['search', 'level', 'route', 'background']) {
        await beginReader(tester, CurriculumKind.vocabulary);
        f.clock.advance(const Duration(seconds: 30));
        if (cause == 'search') {
          final search = find.byKey(const Key('curriculum-search'));
          await tester.ensureVisible(search);
          await tester.enterText(
            search,
            'no-original-entry-matches-this-query',
          );
          await tester.pumpAndSettle();
          expect(control(CurriculumKind.vocabulary, 'elapsed'), findsNothing);
          await tester.enterText(search, '');
          await tester.pumpAndSettle();
        } else if (cause == 'level') {
          await chooseReaderLevel(tester, 'N5');
          expect(control(CurriculumKind.vocabulary, 'elapsed'), findsNothing);
          await chooseReaderLevel(tester, 'N4');
        } else if (cause == 'route') {
          f.container.read(routerProvider).go('/grammar');
          await tester.pumpAndSettle();
          f.container.read(routerProvider).go('/vocabulary');
          await tester.pumpAndSettle();
        } else {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          await tester.pump();
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpAndSettle();
        }
        expect(
          f.container.read(studySessionRecorderProvider).phase,
          StudyRecorderPhase.canceled,
          reason: cause,
        );
        expect(f.server.writes, 0, reason: cause);
        expect(f.clock.ids, 0, reason: cause);
        expect(await f.memory.list(account.owner), isEmpty);
      }
      expect(f.server.reads, 4);
    },
  );

  testWidgets(
    'late vocabulary preflight cannot cancel a new grammar interval',
    (tester) async {
      final f = await mountReaderTimer(tester, CurriculumKind.vocabulary);
      final held = f.server.readWait = Completer<Object?>();
      await beginReader(tester, CurriculumKind.vocabulary, settled: false);
      expect(f.server.reads, 1);
      f.server.readWait = null;
      f.container.read(routerProvider).go('/grammar');
      await tester.pumpAndSettle();
      await beginReader(tester, CurriculumKind.grammar);
      held.complete(studyPlan(0));
      await tester.pumpAndSettle();
      expect(
        f.container.read(studySessionRecorderProvider).area,
        DailyPlanArea.grammar,
      );
      expect(
        f.container.read(studySessionRecorderProvider).phase,
        StudyRecorderPhase.running,
      );
      expect(control(CurriculumKind.grammar, 'elapsed'), findsOneWidget);
      expect(f.server.writes, 0);
    },
  );

  testWidgets(
    'logout retains a cleared hidden reader date and fences late accepted save',
    (tester) async {
      final f = await mountReaderTimer(tester, CurriculumKind.vocabulary);
      await beginReader(tester, CurriculumKind.vocabulary);
      f.clock.advance(const Duration(minutes: 1));
      f.server.writeWait = Completer();
      f.server.entered = Completer();
      await readerTap(tester, control(CurriculumKind.vocabulary, 'finish'));
      expect(f.server.entered!.isCompleted, isTrue);
      final state = tester.state(control(CurriculumKind.vocabulary, 'date'));
      f.h.access.change(null);
      await tester.pumpAndSettle();
      final hidden = find.byKey(
        const Key('vocabulary-timer-date'),
        skipOffstage: false,
      );
      expect(identical(tester.state(hidden), state), isTrue);
      expect(tester.widget<TextField>(hidden).enabled, isFalse);
      expect(tester.widget<TextField>(hidden).controller!.text, isEmpty);
      f.server.writeWait!.complete();
      await tester.pumpAndSettle();
      expect(control(CurriculumKind.vocabulary, 'confirmed'), findsNothing);
      expect(control(CurriculumKind.vocabulary, 'frozen-report'), findsNothing);
      expect((await f.memory.list(account.owner)).single.isPending, isTrue);
      f.h.access.change(account.other);
      await tester.pumpAndSettle();
      expect(await f.memory.list(account.other), isEmpty);
      expect(control(CurriculumKind.vocabulary, 'frozen-report'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'grammar at 320px 200 percent distinguishes confirmed reload failure',
    (tester) async {
      final f = await mountReaderTimer(
        tester,
        CurriculumKind.grammar,
        size: const Size(320, 640),
        scale: 2,
      );
      await beginReader(tester, CurriculumKind.grammar);
      f.clock.advance(const Duration(minutes: 1));
      f.server.readFailure = const DailyPlanFailure(
        DailyPlanErrorCode.networkUnavailable,
      );
      await readerTap(tester, control(CurriculumKind.grammar, 'finish'));
      await tester.pumpAndSettle();
      expect(
        find.text('Buổi học đã được ghi nhận. Chưa tải được tiến độ mới.'),
        findsOneWidget,
      );
      expect(control(CurriculumKind.grammar, 'progress'), findsNothing);
      expect((await f.memory.list(account.owner)).single.acknowledged, isTrue);
      expect(f.server.writes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'owned reader exit retains timer EditableText while revoking and draining',
    (tester) async {
      final f = TimerHarness();
      final owner = ReaderOwnedRuntime(f.h.runtime, f.source);
      final startup = AccountStartupController(() async => owner);
      addTearDown(() async {
        if (!(owner.closing?.isCompleted ?? true)) {
          owner.closing!.complete();
        }
        await tester.pumpWidget(const SizedBox());
        await startup.close();
        await f.h.close();
      });
      await tester.pumpWidget(AccountStartupApp(controller: startup));
      await tester.pumpAndSettle();
      f.h.access.change(account.owner);
      await tester.pumpAndSettle();
      f.container = ProviderScope.containerOf(
        tester.element(find.byType(NihongoDailyApp)),
      );
      f.container.read(previewLevelProvider.notifier).state = PreviewLevel.n4;
      // Use the actual bundled N4 provider, observed in the real async zone,
      // before navigating. No fake asset I/O runs under the widget clock.
      final content = curriculumProvider(CurriculumKind.grammar);
      final subscription = await tester.runAsync(() async {
        final listener = f.container.listen(content, (_, _) {});
        try {
          await f.container.read(content.future);
          return listener;
        } catch (_) {
          listener.close();
          rethrow;
        }
      });
      addTearDown(() => subscription?.close());
      final router = f.container.read(routerProvider);
      router.go('/grammar');
      await tester.pumpAndSettle();
      await beginReader(tester, CurriculumKind.grammar);
      final field = tester.state(control(CurriculumKind.grammar, 'date'));
      owner.closing = Completer();
      var exited = false;
      final exiting = tester.binding.handleRequestAppExit().then((value) {
        exited = true;
        return value;
      });
      await tester.pump();
      await tester.pump();
      expect(exited, isFalse);
      expect(startup.account, isNull);
      expect(startup.durableStudySource, isNull);
      expect(identical(f.container.read(routerProvider), router), isTrue);
      expect(control(CurriculumKind.grammar, 'date'), findsNothing);
      final hidden = find.byKey(
        const Key('grammar-timer-date'),
        skipOffstage: false,
      );
      expect(identical(tester.state(hidden), field), isTrue);
      expect(tester.widget<TextField>(hidden).enabled, isFalse);
      expect(tester.widget<TextField>(hidden).controller!.text, isEmpty);
      final editable = tester.widget<EditableText>(
        find.descendant(
          of: hidden,
          matching: find.byType(EditableText, skipOffstage: false),
          skipOffstage: false,
        ),
      );
      expect(editable.focusNode.canRequestFocus, isFalse);
      expect(f.server.writes, 0);
      owner.closing!.complete();
      expect(await exiting, AppExitResponse.exit);
      expect(tester.takeException(), isNull);
    },
  );
}
