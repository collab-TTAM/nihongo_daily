// TEST ONLY Auth/profile, original N5 source and local read ports.
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/auth/application/account_provider.dart';
import 'package:nihongo_daily/features/auth/data/own_profile_repository.dart';
import 'package:nihongo_daily/features/curriculum/application/curriculum_provider.dart';
import 'package:nihongo_daily/features/curriculum/data/bundled_curriculum_repository.dart';
import 'package:nihongo_daily/features/curriculum/domain/curriculum.dart';
import 'package:nihongo_daily/features/quiz/application/quiz_history_provider.dart';
import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_history_repository.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_attempt.dart';
import 'package:nihongo_daily/features/settings/application/preview_preferences.dart';
import '../srs/account_fixtures.dart' as fixture;
import '../srs/account_widget_test.dart' show Harness;
import 'vocabulary_quiz_widget_test.dart' show tapQuiz;

final class _Ports
    implements
        VocabularyQuizHistorySource,
        VocabularyQuizAttemptStore,
        CurriculumRepository {
  _Ports(this.original);
  final List<CurriculumEntry> original;
  final harness = Harness();
  final operations = VocabularyQuizOperationDrain();
  List<OwnedVocabularyQuizAttempt> records = [];
  Completer<List<OwnedVocabularyQuizAttempt>>? waiting;
  Completer<List<CurriculumEntry>>? contentWaiting;
  bool fail = false;
  bool failContent = false;
  int reads = 0;
  int contentReads = 0;
  int writes = 0;

  @override
  VocabularyQuizHistoryRepository? createVocabularyQuizHistoryRepository() {
    final ready = harness.runtime.readyRuntime;
    if (ready == null) return null;
    return VocabularyQuizHistoryRepository(
      auth: harness.access,
      store: this,
      isReady: () => identical(harness.runtime.readyRuntime, ready),
      operations: operations,
    );
  }

  @override
  Future<List<CurriculumEntry>> load(
    CurriculumKind kind,
    PreviewLevel level,
  ) async {
    expect(kind, CurriculumKind.vocabulary);
    contentReads++;
    if (failContent) throw StateError('PRIVATE CONTENT PATH');
    return contentWaiting?.future ??
        Future<List<CurriculumEntry>>.value(
          level == PreviewLevel.n5 ? original : const <CurriculumEntry>[],
        );
  }

  @override
  Future<List<OwnedVocabularyQuizAttempt>> list(String ownerId) async {
    reads++;
    if (fail) throw StateError('PRIVATE STORAGE TOKEN');
    return waiting?.future ?? Future.value(records);
  }

  @override
  Future<OwnedVocabularyQuizAttempt> append(
    String ownerId,
    VocabularyQuizAttempt attempt,
  ) {
    writes++;
    throw StateError('Progress must never write');
  }
}

void main() {
  late List<CurriculumEntry> original;
  late QuizQuestion question;
  setUpAll(() async {
    original = decodeCurriculum(
      await File('../../data/n5/vocabulary.json').readAsString(),
      CurriculumKind.vocabulary,
      PreviewLevel.n5,
    );
    question = buildVocabularyQuiz(original, PreviewLevel.n5).first;
  });

  OwnedVocabularyQuizAttempt report(int id, {bool correct = false}) {
    final round = QuizRound([question]);
    round.answer(
      question.id,
      correct
          ? question.target.id
          : question.choices.firstWhere((c) => c.id != question.target.id).id,
    );
    round.advance(question.id);
    return OwnedVocabularyQuizAttempt(
      fixture.owner,
      VocabularyQuizAttempt.capture(
        eventId: 'a5000000-0000-4000-8000-${id.toString().padLeft(12, '0')}',
        completedAt: DateTime.utc(2026, 10, 22, 0, id),
        round: round,
      ),
    );
  }

  Future<ProviderContainer> mount(
    WidgetTester tester,
    _Ports ports, {
    bool configured = true,
  }) async {
    final container = ProviderContainer(
      overrides: [
        if (configured)
          accountRuntimeProvider.overrideWithValue(ports.harness.runtime),
        if (configured) quizHistorySourceProvider.overrideWithValue(ports),
        curriculumRepositoryProvider.overrideWithValue(ports),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      final waiting = ports.waiting;
      if (waiting != null && !waiting.isCompleted) waiting.complete([]);
      final content = ports.contentWaiting;
      if (content != null && !content.isCompleted) content.complete(original);
      container.dispose();
      await ports.operations.revokeAndDrain();
      expect(ports.writes, 0);
      await ports.harness.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NihongoDailyApp(),
      ),
    );
    if (configured) ports.harness.access.change(fixture.owner);
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/progress');
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> load(WidgetTester tester) =>
      tapQuiz(tester, find.byKey(const Key('quiz-progress-load')));

  testWidgets('default progress never invents account or results', (
    tester,
  ) async {
    final ports = _Ports(original);
    await mount(tester, ports, configured: false);
    expect(find.byKey(const Key('quiz-progress-load')), findsNothing);
    expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
    expect(ports.reads, 0);
    expect(ports.contentReads, 0);
    await tapQuiz(tester, find.text('Mở tài khoản'));
    expect(find.text('Đăng nhập hiện chưa khả dụng.'), findsOneWidget);
  });

  testWidgets('profile readiness precedes explicit empty progress read', (
    tester,
  ) async {
    final ports = _Ports(original);
    ports.harness.delayed = Completer<OwnProfile>();
    await mount(tester, ports);
    expect(find.byKey(const Key('quiz-progress-load')), findsNothing);
    expect(ports.contentReads, 0);
    ports.harness.delayed!.complete(fixture.ownProfile());
    await tester.pumpAndSettle();
    expect(ports.reads, 0);
    expect(ports.contentReads, 0);
    await load(tester);
    expect(find.text('N5 · 0 bộ đã lưu'), findsOneWidget);
    expect(find.text('Câu đúng theo bài gốc: 0 / 0'), findsOneWidget);
    expect(find.text('Từ hiện tại đã luyện: 0'), findsOneWidget);
    expect(ports.reads, 1);
    expect(ports.contentReads, 1);
  });

  testWidgets(
    'dedup repeated errors and later correct clear review candidate',
    (tester) async {
      final ports = _Ports(original)
        ..records = [report(1), report(2), report(1)];
      await mount(tester, ports);
      await load(tester);
      expect(find.text('N5 · 2 bộ đã lưu'), findsOneWidget);
      expect(find.text('Câu đúng theo bài gốc: 0 / 2'), findsOneWidget);
      expect(find.text('Từ hiện tại đã luyện: 1'), findsOneWidget);
      expect(find.text('Từ cần ôn: 1'), findsOneWidget);
      expect(find.text(question.target.heading), findsOneWidget);
      expect(find.textContaining('Sai 2 lần'), findsOneWidget);
      expect(find.textContaining(fixture.owner), findsNothing);
      ports.records = [...ports.records, report(3, correct: true)];
      await load(tester);
      expect(find.text('N5 · 3 bộ đã lưu'), findsOneWidget);
      expect(find.text('Câu đúng theo bài gốc: 1 / 3'), findsOneWidget);
      expect(find.text('Từ cần ôn: 0'), findsOneWidget);
      expect(find.text(question.target.heading), findsNothing);
    },
  );

  testWidgets('reload clears previous data and redacts storage failure', (
    tester,
  ) async {
    final ports = _Ports(original)..records = [report(1)];
    await mount(tester, ports);
    await load(tester);
    expect(find.byKey(const Key('quiz-progress-summary')), findsOneWidget);
    ports.fail = true;
    await load(tester);
    expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
    expect(find.text(question.target.heading), findsNothing);
    expect(find.byKey(const Key('quiz-progress-error')), findsOneWidget);
    expect(find.textContaining('PRIVATE'), findsNothing);
    ports.fail = false;
    await load(tester);
    expect(find.text('N5 · 1 bộ đã lưu'), findsOneWidget);
  });

  testWidgets('content failure cannot publish partial historical totals', (
    tester,
  ) async {
    final ports = _Ports(original)..failContent = true;
    await mount(tester, ports);
    await load(tester);
    expect(find.byKey(const Key('quiz-progress-error')), findsOneWidget);
    expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
    expect(find.textContaining('PRIVATE'), findsNothing);
    expect(ports.reads, 0);
  });

  for (final nextOwner in [fixture.owner, fixture.other]) {
    testWidgets('held read cannot publish after replacement $nextOwner', (
      tester,
    ) async {
      final ports = _Ports(original);
      await mount(tester, ports);
      ports.waiting = Completer<List<OwnedVocabularyQuizAttempt>>();
      final button = find.byKey(const Key('quiz-progress-load'));
      await tester.ensureVisible(button);
      final stale = tester.widget<OutlinedButton>(button).onPressed!;
      await tester.tap(button);
      await tester.pump();
      stale();
      await tester.pump();
      expect(ports.reads, 1);
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      ports.harness.access.change(nextOwner);
      await tester.pumpAndSettle();
      ports.waiting!.complete([report(1)]);
      await tester.pumpAndSettle();
      stale();
      await tester.pumpAndSettle();
      expect(ports.reads, 1);
      expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
      expect(find.byKey(const Key('quiz-progress-error')), findsNothing);
      expect(find.text(question.target.heading), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'level replacement fences held source without retargeting account',
    (tester) async {
      final ports = _Ports(original)..records = [report(1)];
      final container = await mount(tester, ports);
      final profile = ports.harness.runtime.state.profile;
      ports.contentWaiting = Completer<List<CurriculumEntry>>();
      final loadButton = find.byKey(const Key('quiz-progress-load'));
      await tester.ensureVisible(loadButton);
      await tester.tap(loadButton);
      await tester.pump();
      final selector = tester.widget<DropdownButton<PreviewLevel>>(
        find.byKey(const Key('quiz-progress-level')),
      );
      selector.onChanged!(PreviewLevel.n4);
      await tester.pumpAndSettle();
      ports.contentWaiting!.complete(original);
      await tester.pumpAndSettle();
      expect(ports.reads, 0);
      expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
      ports.contentWaiting = null;
      await load(tester);
      expect(find.text('N4 · 0 bộ đã lưu'), findsOneWidget);
      expect(find.text(question.target.heading), findsNothing);
      expect(identical(ports.harness.runtime.state.profile, profile), isTrue);
      expect(container.read(previewLevelProvider), PreviewLevel.n5);
    },
  );

  testWidgets('retained progress load is inert before level rebuild', (
    tester,
  ) async {
    final ports = _Ports(original);
    final container = await mount(tester, ports);
    final button = find.byKey(const Key('quiz-progress-load'));
    final stale = tester.widget<OutlinedButton>(button).onPressed!;
    final selector = tester.widget<DropdownButton<PreviewLevel>>(
      find.byKey(const Key('quiz-progress-level')),
    );
    selector.onChanged!(PreviewLevel.n4);
    stale(); // Deliberately invoke before pumping the replacement panel.
    expect(ports.contentReads, 0);
    expect(ports.reads, 0);
    await tester.pumpAndSettle();
    await load(tester);
    expect(ports.contentReads, 1);
    expect(ports.reads, 1);
    expect(find.text('N4 · 0 bộ đã lưu'), findsOneWidget);
    expect(container.read(previewLevelProvider), PreviewLevel.n5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('held progress content cannot start history before rebuild', (
    tester,
  ) async {
    final ports = _Ports(original)..records = [report(1)];
    await mount(tester, ports);
    final held = Completer<List<CurriculumEntry>>();
    ports.contentWaiting = held;
    final button = find.byKey(const Key('quiz-progress-load'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(ports.contentReads, 1);
    expect(ports.reads, 0);
    final selector = tester.widget<DropdownButton<PreviewLevel>>(
      find.byKey(const Key('quiz-progress-level')),
    );
    selector.onChanged!(PreviewLevel.n4);
    held.complete(original);
    await tester.idle(); // Flush continuation without a replacement frame.
    expect(ports.reads, 0);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
    expect(find.byKey(const Key('quiz-progress-error')), findsNothing);
    expect(find.text(question.target.heading), findsNothing);
    ports.contentWaiting = null;
    await load(tester);
    expect(ports.contentReads, 2);
    expect(ports.reads, 1);
    expect(find.text('N4 · 0 bộ đã lưu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('level A-B-A before a frame never revives old progress load', (
    tester,
  ) async {
    final ports = _Ports(original)..records = [report(1)];
    await mount(tester, ports);
    final button = find.byKey(const Key('quiz-progress-load'));
    final stale = tester.widget<OutlinedButton>(button).onPressed!;
    final selector = tester.widget<DropdownButton<PreviewLevel>>(
      find.byKey(const Key('quiz-progress-level')),
    );
    selector.onChanged!(PreviewLevel.n4);
    selector.onChanged!(PreviewLevel.n5);
    stale();
    expect(ports.contentReads, 0);
    expect(ports.reads, 0);
    await tester.pumpAndSettle();
    stale();
    expect(ports.contentReads, 0);
    expect(ports.reads, 0);
    await load(tester);
    expect(ports.contentReads, 1);
    expect(ports.reads, 1);
    expect(find.text('N5 · 1 bộ đã lưu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('route exit fences late history failure', (tester) async {
    final ports = _Ports(original);
    final container = await mount(tester, ports);
    ports.waiting = Completer<List<OwnedVocabularyQuizAttempt>>();
    final button = find.byKey(const Key('quiz-progress-load'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    container.read(routerProvider).go('/settings');
    await tester.pumpAndSettle();
    ports.waiting!.completeError(StateError('PRIVATE LATE'));
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/progress');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
    expect(find.byKey(const Key('quiz-progress-error')), findsNothing);
    expect(ports.reads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress at 320px and 200 percent keeps original feedback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final ports = _Ports(original)..records = [report(1)];
    await mount(tester, ports);
    await load(tester);
    expect(find.text('N5 · 1 bộ đã lưu'), findsOneWidget);
    expect(find.text(question.target.heading), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
