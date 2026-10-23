// TEST ONLY owned Auth/RPC/memory/clock and permissive plan. Original curriculum
// is read unchanged; current server QUIZ_REVIEW is still BLOCKED.
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/auth/application/account_provider.dart';
import 'package:nihongo_daily/features/curriculum/application/curriculum_provider.dart';
import 'package:nihongo_daily/features/curriculum/data/bundled_curriculum_repository.dart';
import 'package:nihongo_daily/features/curriculum/domain/curriculum.dart';
import 'package:nihongo_daily/features/daily_plan/application/daily_plan_provider.dart';
import 'package:nihongo_daily/features/daily_plan/application/srs_session_recorder_provider.dart';
import 'package:nihongo_daily/features/daily_plan/application/study_session_recorder.dart';
import 'package:nihongo_daily/features/daily_plan/data/durable_study_session_repository.dart'
    show sameStudyEvent;
import 'package:nihongo_daily/features/daily_plan/domain/daily_plan.dart';
import 'package:nihongo_daily/features/quiz/application/vocabulary_quiz_provider.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz.dart';
import 'package:nihongo_daily/features/settings/application/preview_preferences.dart';
import '../curriculum/curriculum_widget_test.dart'
    show FixtureCurriculumRepository;
import '../daily_plan/srs_session_timer_widget_test.dart' show TimerHarness;
import '../daily_plan/study_session_recovery_fixtures.dart';
import '../srs/account_fixtures.dart' as account;

const area = DailyPlanArea.quizReview;
Finder timer(String suffix) => find.byKey(Key('quiz_review-timer-$suffix'));
final originals = <PreviewLevel, List<CurriculumEntry>>{};

Future<TimerHarness> mountQuizStudy(
  WidgetTester tester, {
  bool configured = true,
  PreviewLevel level = PreviewLevel.n4,
  CurriculumRepository? repository,
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
      curriculumRepositoryProvider.overrideWithValue(
        repository ??
            FixtureCurriculumRepository((_, level) async => originals[level]!),
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
  if (configured) f.h.access.change(account.owner);
  await tester.pumpAndSettle();
  f.container.read(routerProvider).go('/quiz');
  await tester.pumpAndSettle();
  return f;
}

Future<void> tap(
  WidgetTester tester,
  Finder target, {
  bool settle = true,
}) async {
  await tester.ensureVisible(target);
  await tester.pump();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pump();
  if (settle) await tester.pumpAndSettle();
}

Future<void> begin(WidgetTester tester, {bool settle = true}) async {
  await tester.enterText(timer('date'), '2026-10-20');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  await tap(tester, timer('start'), settle: settle);
}

Future<void> completeRound(WidgetTester tester, TimerHarness f) async {
  final level = f.container.read(previewLevelProvider);
  final questions = f.container
      .read(vocabularyQuizProvider(level))
      .asData!
      .value;
  for (final question in questions.take(10)) {
    await tap(
      tester,
      find.byKey(ValueKey('quiz-choice-${question.target.id}')),
    );
    await tap(tester, find.byKey(const Key('quiz-next')));
  }
}

void main() {
  setUpAll(() async {
    for (final level in PreviewLevel.values) {
      originals[level] = decodeCurriculum(
        await File('../../data/${level.name}/vocabulary.json').readAsString(),
        CurriculumKind.vocabulary,
        level,
      );
    }
  });

  testWidgets('public quiz has no account timer or invented study credit', (
    tester,
  ) async {
    final f = await mountQuizStudy(tester, configured: false);
    expect(find.byKey(const Key('quiz-prompt')), findsOneWidget);
    expect(timer('date'), findsNothing);
    expect(timer('start'), findsNothing);
    expect(f.server.reads, 0);
    expect(f.server.writes, 0);
    expect(f.clock.ids, 0);
  });

  testWidgets(
    'quiz explicit staged interval does not turn answers into minutes',
    (tester) async {
      final f = await mountQuizStudy(tester);
      final q = f.container
          .read(vocabularyQuizProvider(PreviewLevel.n4))
          .asData!
          .value
          .first;
      await tap(tester, find.byKey(ValueKey('quiz-choice-${q.target.id}')));
      expect(f.server.reads, 0);
      expect(f.server.writes, 0);
      expect(f.container.read(canStartStudyRecorderProvider(area)), isTrue);
      final started = f.clock.instant;
      await begin(tester);
      f.clock.advance(const Duration(seconds: 61));
      await tap(tester, timer('finish'));
      expect(timer('confirmed'), findsOneWidget);
      expect(find.byKey(const Key('quiz-result')), findsNothing);
      expect(find.byKey(const Key('quiz-feedback')), findsOneWidget);
      final record = f.memory.records.values.single;
      expect(record.acknowledged, isTrue);
      expect(record.userId, account.owner);
      expect(record.event.area, area);
      expect(record.event.date.value, '2026-10-20');
      expect(record.event.startedAt, started);
      expect(record.event.endedAt, f.clock.instant);
      expect(f.server.writes, 1);
      expect(f.server.reads, 2);
      expect(f.clock.ids, 1);
    },
  );

  testWidgets('blocked quiz server plan overrides loaded eligible questions', (
    tester,
  ) async {
    final f = await mountQuizStudy(tester);
    final plan = studyPlan(0);
    final block = (plan['blocks']! as List<Map<String, Object>>).singleWhere(
      (b) => b['type'] == 'QUIZ_REVIEW',
    );
    block['status'] = 'BLOCKED';
    block['item_count'] = 0;
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
  });

  testWidgets('quiz preview level must match the ready own profile', (
    tester,
  ) async {
    final f = await mountQuizStudy(tester, level: PreviewLevel.n5);
    expect(f.container.read(canStartStudyRecorderProvider(area)), isFalse);
    expect(tester.widget<FilledButton>(timer('start')).onPressed, isNull);
    expect(f.server.reads, 0);
  });

  for (final action in ['Làm lại bộ này', 'Bộ tiếp']) {
    testWidgets('$action cancels quiz time and rejects the former finish', (
      tester,
    ) async {
      final f = await mountQuizStudy(tester);
      await begin(tester);
      final stale = tester.widget<FilledButton>(timer('finish')).onPressed!;
      await completeRound(tester, f);
      expect(find.byKey(const Key('quiz-result')), findsOneWidget);
      expect(timer('elapsed'), findsOneWidget);
      expect(f.server.writes, 0);
      await tap(tester, find.text(action));
      expect(
        f.container.read(studySessionRecorderProvider).phase,
        StudyRecorderPhase.canceled,
      );
      expect(f.memory.records, isEmpty);
      await begin(tester);
      f.clock.advance(const Duration(seconds: 61));
      stale();
      await tester.pump();
      expect(
        f.container.read(studySessionRecorderProvider).phase,
        StudyRecorderPhase.running,
      );
      expect(f.server.writes, 0);
      await tap(tester, timer('finish'));
      expect(f.server.writes, 1);
      expect(f.clock.ids, 1);
    });
  }

  testWidgets('pending quiz refresh removes readiness and cancels timing', (
    tester,
  ) async {
    final held = Completer<List<CurriculumEntry>>();
    var calls = 0;
    final f = await mountQuizStudy(
      tester,
      repository: FixtureCurriculumRepository(
        (_, level) =>
            ++calls == 1 ? Future.value(originals[level]!) : held.future,
      ),
    );
    await begin(tester);
    f.container.invalidate(vocabularyQuizProvider(PreviewLevel.n4));
    await tester.pump();
    await tester.pump();
    expect(f.container.read(canStartStudyRecorderProvider(area)), isFalse);
    expect(
      f.container.read(studySessionRecorderProvider).phase,
      StudyRecorderPhase.canceled,
    );
    expect(find.text('Đang tải câu hỏi…'), findsOneWidget);
    held.complete(originals[PreviewLevel.n4]!);
    await tester.pumpAndSettle();
    expect(timer('elapsed'), findsNothing);
    expect(f.server.writes, 0);
    expect(f.clock.ids, 0);
  });

  testWidgets('late quiz preflight cannot start after route exit', (
    tester,
  ) async {
    final f = await mountQuizStudy(tester);
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
    expect(f.memory.records, isEmpty);
  });

  testWidgets('frozen quiz report retries unchanged through SRS', (
    tester,
  ) async {
    final f = await mountQuizStudy(tester);
    await begin(tester);
    f.clock.advance(const Duration(seconds: 61));
    f.store.failStage = true;
    await tap(tester, timer('finish'));
    final event = f.container
        .read(studySessionRecorderProvider.notifier)
        .pendingEvent!;
    expect(f.server.writes, 0);
    f.container.read(routerProvider).go('/srs');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('srs-timer-frozen-report')), findsOneWidget);
    f.store.failStage = false;
    await tap(tester, find.byKey(const Key('srs-timer-retry')));
    final record = f.memory.records.values.single;
    expect(sameStudyEvent(record.event, event), isTrue);
    expect(record.event.area, area);
    expect(record.acknowledged, isTrue);
    expect(f.server.writes, 1);
    expect(f.clock.ids, 1);
  });

  testWidgets('quiz timer works at 320px and 200 percent text', (tester) async {
    final f = await mountQuizStudy(
      tester,
      size: const Size(320, 640),
      scale: 2,
    );
    await begin(tester);
    f.clock.advance(const Duration(seconds: 61));
    await tap(tester, timer('finish'));
    expect(timer('confirmed'), findsOneWidget);
    expect(f.server.writes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'quiz date editor is retained and cleared on logout during save',
    (tester) async {
      final f = await mountQuizStudy(tester);
      await begin(tester);
      f.clock.advance(const Duration(seconds: 61));
      f.server.entered = Completer<void>();
      f.server.writeWait = Completer<void>();
      await tap(tester, timer('finish'), settle: false);
      expect(f.server.entered!.isCompleted, isTrue);
      f.h.access.change(null);
      await tester.pumpAndSettle();
      final editor = find.byKey(
        const Key('quiz_review-timer-date'),
        skipOffstage: false,
      );
      expect(editor, findsOneWidget);
      expect(tester.widget<TextField>(editor).controller!.text, isEmpty);
      expect(timer('confirmed'), findsNothing);
      f.server.writeWait!.complete();
      await tester.pumpAndSettle();
      expect(timer('confirmed'), findsNothing);
      expect(f.memory.records.values.single.userId, account.owner);
      expect(f.memory.records.values.single.isPending, isTrue);
    },
  );
}
