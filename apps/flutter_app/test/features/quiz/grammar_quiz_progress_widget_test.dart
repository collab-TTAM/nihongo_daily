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
import 'package:nihongo_daily/features/quiz/application/grammar_quiz_history_provider.dart';
import 'package:nihongo_daily/features/quiz/data/grammar_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/data/grammar_quiz_history_repository.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz_attempt.dart';
import 'package:nihongo_daily/features/settings/application/preview_preferences.dart';
import '../srs/account_fixtures.dart' as fixture;
import '../srs/account_widget_test.dart' show Harness;
import 'vocabulary_quiz_widget_test.dart' show tapQuiz;

final class _Ports
    implements
        GrammarQuizHistorySource,
        GrammarQuizAttemptStore,
        CurriculumRepository {
  _Ports(this.original);
  final List<CurriculumEntry> original;
  final harness = Harness();
  final operations = GrammarQuizOperationDrain();
  List<OwnedGrammarQuizAttempt> records = [];
  Completer<List<OwnedGrammarQuizAttempt>>? waiting;
  Completer<List<CurriculumEntry>>? contentWaiting;
  bool fail = false;
  bool failContent = false;
  int reads = 0;
  int contentReads = 0;
  int writes = 0;

  @override
  GrammarQuizHistoryRepository? createGrammarQuizHistoryRepository() {
    final ready = harness.runtime.readyRuntime;
    if (ready == null) return null;
    return GrammarQuizHistoryRepository(
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
    expect(kind, CurriculumKind.grammar);
    contentReads++;
    if (failContent) throw StateError('PRIVATE CONTENT PATH');
    return contentWaiting?.future ??
        Future<List<CurriculumEntry>>.value(
          level == PreviewLevel.n5 ? original : const <CurriculumEntry>[],
        );
  }

  @override
  Future<List<OwnedGrammarQuizAttempt>> list(String ownerId) async {
    reads++;
    if (fail) throw StateError('PRIVATE STORAGE TOKEN');
    return waiting?.future ?? Future.value(records);
  }

  @override
  Future<OwnedGrammarQuizAttempt> append(
    String ownerId,
    GrammarQuizAttempt attempt,
  ) {
    writes++;
    throw StateError('Progress must never write');
  }
}

final class _OtherSource implements CurriculumRepository {
  _OtherSource(this.entries);
  final List<CurriculumEntry> entries;
  int reads = 0;
  @override
  Future<List<CurriculumEntry>> load(
    CurriculumKind kind,
    PreviewLevel level,
  ) async {
    reads++;
    return entries;
  }
}

void main() {
  late List<CurriculumEntry> original;
  late GrammarQuizQuestion question;
  setUpAll(() async {
    original = decodeCurriculum(
      await File('../../data/n5/grammar.json').readAsString(),
      CurriculumKind.grammar,
      PreviewLevel.n5,
    );
    question = buildGrammarQuiz(original, PreviewLevel.n5).first;
  });

  OwnedGrammarQuizAttempt report(int id, {bool correct = false}) {
    final round = GrammarQuizRound([question]);
    round.answer(
      question.id,
      correct
          ? question.target.id
          : question.choices.firstWhere((c) => c.id != question.target.id).id,
    );
    round.advance(question.id);
    return OwnedGrammarQuizAttempt(
      fixture.owner,
      GrammarQuizAttempt.capture(
        eventId: 'a5000000-0000-4000-8000-${id.toString().padLeft(12, '0')}',
        completedAt: DateTime.utc(2026, 10, 22, 0, id),
        round: round,
        kind: GrammarQuizAttemptKind.primary,
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
        if (configured)
          grammarQuizHistorySourceProvider.overrideWithValue(ports),
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
    container.read(routerProvider).go('/quiz/grammar/progress');
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> load(WidgetTester tester) =>
      tapQuiz(tester, find.byKey(const Key('grammar-progress-load')));

  testWidgets('default progress never invents account or results', (
    tester,
  ) async {
    final ports = _Ports(original);
    await mount(tester, ports, configured: false);
    expect(find.byKey(const Key('grammar-progress-load')), findsNothing);
    expect(find.byKey(const Key('grammar-progress-summary')), findsNothing);
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
    expect(find.byKey(const Key('grammar-progress-load')), findsNothing);
    expect(ports.contentReads, 0);
    ports.harness.delayed!.complete(fixture.ownProfile());
    await tester.pumpAndSettle();
    expect(ports.reads, 0);
    expect(ports.contentReads, 0);
    await load(tester);
    expect(find.text('Vòng gốc · N5 · 0 bộ đã lưu'), findsOneWidget);
    expect(
      find.text('Vòng gốc · Câu đúng theo bài gốc: 0 / 0'),
      findsOneWidget,
    );
    expect(find.text('Mẫu hiện tại đã luyện: 0'), findsOneWidget);
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
      expect(find.text('Vòng gốc · N5 · 2 bộ đã lưu'), findsOneWidget);
      expect(
        find.text('Vòng gốc · Câu đúng theo bài gốc: 0 / 2'),
        findsOneWidget,
      );
      expect(find.text('Mẫu hiện tại đã luyện: 1'), findsOneWidget);
      expect(find.text('Mẫu cần ôn: 1'), findsOneWidget);
      expect(find.text(question.target.heading), findsOneWidget);
      expect(find.textContaining('Sai 2 lần'), findsOneWidget);
      expect(find.textContaining(fixture.owner), findsNothing);
      ports.records = [...ports.records, report(3, correct: true)];
      await load(tester);
      expect(find.text('Vòng gốc · N5 · 3 bộ đã lưu'), findsOneWidget);
      expect(
        find.text('Vòng gốc · Câu đúng theo bài gốc: 1 / 3'),
        findsOneWidget,
      );
      expect(find.text('Mẫu cần ôn: 0'), findsOneWidget);
      expect(find.text(question.target.heading), findsNothing);
    },
  );

  testWidgets('reload clears previous data and redacts storage failure', (
    tester,
  ) async {
    final ports = _Ports(original)..records = [report(1)];
    await mount(tester, ports);
    await load(tester);
    expect(find.byKey(const Key('grammar-progress-summary')), findsOneWidget);
    ports.fail = true;
    await load(tester);
    expect(find.byKey(const Key('grammar-progress-summary')), findsNothing);
    expect(find.text(question.target.heading), findsNothing);
    expect(find.byKey(const Key('grammar-progress-error')), findsOneWidget);
    expect(find.textContaining('PRIVATE'), findsNothing);
    ports.fail = false;
    await load(tester);
    expect(find.text('Vòng gốc · N5 · 1 bộ đã lưu'), findsOneWidget);
  });

  testWidgets('content failure cannot publish partial historical totals', (
    tester,
  ) async {
    final ports = _Ports(original)..failContent = true;
    await mount(tester, ports);
    await load(tester);
    expect(find.byKey(const Key('grammar-progress-error')), findsOneWidget);
    expect(find.byKey(const Key('grammar-progress-summary')), findsNothing);
    expect(find.textContaining('PRIVATE'), findsNothing);
    expect(ports.reads, 0);
  });

  for (final nextOwner in [fixture.owner, fixture.other]) {
    testWidgets('held read cannot publish after replacement $nextOwner', (
      tester,
    ) async {
      final ports = _Ports(original);
      await mount(tester, ports);
      ports.waiting = Completer<List<OwnedGrammarQuizAttempt>>();
      final button = find.byKey(const Key('grammar-progress-load'));
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
      expect(find.byKey(const Key('grammar-progress-summary')), findsNothing);
      expect(find.byKey(const Key('grammar-progress-error')), findsNothing);
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
      final loadButton = find.byKey(const Key('grammar-progress-load'));
      await tester.ensureVisible(loadButton);
      await tester.tap(loadButton);
      await tester.pump();
      final selector = tester.widget<DropdownButton<PreviewLevel>>(
        find.byKey(const Key('grammar-progress-level')),
      );
      selector.onChanged!(PreviewLevel.n4);
      await tester.pumpAndSettle();
      ports.contentWaiting!.complete(original);
      await tester.pumpAndSettle();
      expect(ports.reads, 0);
      expect(find.byKey(const Key('grammar-progress-summary')), findsNothing);
      ports.contentWaiting = null;
      await load(tester);
      expect(find.text('Vòng gốc · N4 · 0 bộ đã lưu'), findsOneWidget);
      expect(find.text(question.target.heading), findsNothing);
      expect(identical(ports.harness.runtime.state.profile, profile), isTrue);
      expect(container.read(previewLevelProvider), PreviewLevel.n5);
    },
  );

  testWidgets('retired selector keeps new view level', (tester) async {
    final ports = _Ports(original);
    final container = await mount(tester, ports);
    final selector = tester.widget<DropdownButton<PreviewLevel>>(
      find.byKey(const Key('grammar-progress-level')),
    );
    final old = container.read(grammarQuizHistoryRepositoryProvider);
    container.invalidate(grammarQuizHistoryRepositoryProvider);
    expect(
      container.read(grammarQuizHistoryRepositoryProvider),
      isNot(same(old)),
    );
    selector.onChanged!(PreviewLevel.n4);
    await tester.pumpAndSettle();
    final fresh = tester.widget<DropdownButton<PreviewLevel>>(
      find.byKey(const Key('grammar-progress-level')),
    );
    expect(fresh.value, PreviewLevel.n5);
    expect(ports.contentReads, 0);
    expect(ports.reads, 0);
    await load(tester);
    expect(find.text('Vòng gốc · N5 · 0 bộ đã lưu'), findsOneWidget);
    expect(ports.contentReads, 1);
    expect(ports.reads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposed progress selector stays inert', (tester) async {
    final ports = _Ports(original);
    final container = await mount(tester, ports);
    final selector = tester.widget<DropdownButton<PreviewLevel>>(
      find.byKey(const Key('grammar-progress-level')),
    );
    container.read(routerProvider).go('/settings');
    await tester.pumpAndSettle();
    selector.onChanged!(PreviewLevel.n4);
    await tester.pumpAndSettle();
    expect(ports.contentReads, 0);
    expect(ports.reads, 0);
    expect(tester.takeException(), isNull);
    container.read(routerProvider).go('/quiz/grammar/progress');
    await tester.pumpAndSettle();
    await load(tester);
    expect(find.text('Vòng gốc · N5 · 0 bộ đã lưu'), findsOneWidget);
    expect(ports.contentReads, 1);
    expect(ports.reads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retained progress load is inert before level rebuild', (
    tester,
  ) async {
    final ports = _Ports(original);
    final container = await mount(tester, ports);
    final button = find.byKey(const Key('grammar-progress-load'));
    final stale = tester.widget<OutlinedButton>(button).onPressed!;
    final selector = tester.widget<DropdownButton<PreviewLevel>>(
      find.byKey(const Key('grammar-progress-level')),
    );
    selector.onChanged!(PreviewLevel.n4);
    stale(); // Deliberately invoke before pumping the replacement panel.
    expect(ports.contentReads, 0);
    expect(ports.reads, 0);
    await tester.pumpAndSettle();
    await load(tester);
    expect(ports.contentReads, 1);
    expect(ports.reads, 1);
    expect(find.text('Vòng gốc · N4 · 0 bộ đã lưu'), findsOneWidget);
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
    final button = find.byKey(const Key('grammar-progress-load'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(ports.contentReads, 1);
    expect(ports.reads, 0);
    final selector = tester.widget<DropdownButton<PreviewLevel>>(
      find.byKey(const Key('grammar-progress-level')),
    );
    selector.onChanged!(PreviewLevel.n4);
    held.complete(original);
    await tester.idle(); // Flush continuation without a replacement frame.
    expect(ports.reads, 0);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('grammar-progress-summary')), findsNothing);
    expect(find.byKey(const Key('grammar-progress-error')), findsNothing);
    expect(find.text(question.target.heading), findsNothing);
    ports.contentWaiting = null;
    await load(tester);
    expect(ports.contentReads, 2);
    expect(ports.reads, 1);
    expect(find.text('Vòng gốc · N4 · 0 bộ đã lưu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('level A-B-A before a frame never revives old progress load', (
    tester,
  ) async {
    final ports = _Ports(original)..records = [report(1)];
    await mount(tester, ports);
    final button = find.byKey(const Key('grammar-progress-load'));
    final stale = tester.widget<OutlinedButton>(button).onPressed!;
    final selector = tester.widget<DropdownButton<PreviewLevel>>(
      find.byKey(const Key('grammar-progress-level')),
    );
    selector.onChanged!(PreviewLevel.n4);
    stale();
    expect(ports.contentReads, 0);
    await tester.pumpAndSettle();
    tester
        .widget<DropdownButton<PreviewLevel>>(
          find.byKey(const Key('grammar-progress-level')),
        )
        .onChanged!(PreviewLevel.n5);
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
    expect(find.text('Vòng gốc · N5 · 1 bộ đã lưu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'grammar progress correction selection clears primary and requires explicit reload',
    (tester) async {
      final ports = _Ports(original)
        ..records = [report(1), report(1), report(2)];
      final corrected = report(3, correct: true).attempt.toJson()
        ..['practice_kind'] = 'correction';
      ports.records.add(
        OwnedGrammarQuizAttempt(
          fixture.owner,
          GrammarQuizAttempt.fromJson(corrected),
        ),
      );
      await mount(tester, ports);
      await load(tester);
      expect(find.text('Vòng gốc · N5 · 2 bộ đã lưu'), findsOneWidget);
      expect(find.text('Mẫu cần ôn: 1'), findsOneWidget);
      final button = tester
          .widget<OutlinedButton>(
            find.byKey(const Key('grammar-progress-load')),
          )
          .onPressed!;
      final kind = tester
          .widget<DropdownButton<GrammarQuizAttemptKind>>(
            find.byKey(const Key('grammar-progress-kind')),
          )
          .onChanged!;
      kind(GrammarQuizAttemptKind.correction);
      button();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('grammar-progress-summary')), findsNothing);
      expect(ports.reads, 1);
      await load(tester);
      expect(find.text('Vòng luyện sai · N5 · 1 bộ đã lưu'), findsOneWidget);
      expect(
        find.text('Vòng luyện sai · Câu đúng theo bài gốc: 1 / 1'),
        findsOneWidget,
      );
      expect(find.text('Mẫu cần ôn: 0'), findsOneWidget);
      kind(GrammarQuizAttemptKind.primary);
      await tester.pumpAndSettle();
      expect(find.text('Vòng luyện sai · N5 · 1 bộ đã lưu'), findsOneWidget);
      expect(ports.reads, 2);
    },
  );
  testWidgets(
    'grammar progress kind replacement retires held success or error',
    (tester) async {
      final ports = _Ports(original)..records = [report(1)];
      await mount(tester, ports);
      ports.waiting = Completer<List<OwnedGrammarQuizAttempt>>();
      await tester.ensureVisible(
        find.byKey(const Key('grammar-progress-load')),
      );
      await tester.tap(find.byKey(const Key('grammar-progress-load')));
      await tester.pump();
      tester
          .widget<DropdownButton<GrammarQuizAttemptKind>>(
            find.byKey(const Key('grammar-progress-kind')),
          )
          .onChanged!(GrammarQuizAttemptKind.correction);
      ports.waiting!.completeError(StateError('PRIVATE OLD OWNER'));
      await tester.pumpAndSettle();
      ports.waiting = null;
      expect(find.byKey(const Key('grammar-progress-summary')), findsNothing);
      expect(find.byKey(const Key('grammar-progress-error')), findsNothing);
      expect(find.textContaining('PRIVATE'), findsNothing);
      await load(tester);
      expect(find.text('Vòng luyện sai · N5 · 0 bộ đã lưu'), findsOneWidget);
    },
  );
  testWidgets('grammar progress fits 320 pixels and 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final ports = _Ports(original)..records = [report(1)];
    await mount(tester, ports);
    await load(tester);
    expect(find.text('Vòng gốc · N5 · 1 bộ đã lưu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('grammar source A B A before frame retires original load', (
    tester,
  ) async {
    final ports = _Ports(original);
    final container = await mount(tester, ports);
    final stale = tester
        .widget<OutlinedButton>(find.byKey(const Key('grammar-progress-load')))
        .onPressed!;
    final other = _OtherSource(original);
    void replace(CurriculumRepository source) {
      container.updateOverrides([
        accountRuntimeProvider.overrideWithValue(ports.harness.runtime),
        grammarQuizHistorySourceProvider.overrideWithValue(ports),
        curriculumRepositoryProvider.overrideWithValue(source),
      ]);
      expect(container.read(curriculumRepositoryProvider), same(source));
    }

    replace(other);
    replace(ports);
    stale();
    expect(ports.contentReads, 0);
    expect(other.reads, 0);
    await tester.pumpAndSettle();
    stale();
    expect(ports.contentReads, 0);
    await load(tester);
    expect(ports.contentReads, 1);
    expect(ports.reads, 1);
  });
  testWidgets(
    'grammar source replacement discards held content before history',
    (tester) async {
      final ports = _Ports(original)
        ..contentWaiting = Completer<List<CurriculumEntry>>();
      final container = await mount(tester, ports);
      await tester.ensureVisible(
        find.byKey(const Key('grammar-progress-load')),
      );
      await tester.tap(find.byKey(const Key('grammar-progress-load')));
      await tester.pump();
      final other = _OtherSource(original);
      container.updateOverrides([
        accountRuntimeProvider.overrideWithValue(ports.harness.runtime),
        grammarQuizHistorySourceProvider.overrideWithValue(ports),
        curriculumRepositoryProvider.overrideWithValue(other),
      ]);
      expect(container.read(curriculumRepositoryProvider), same(other));
      ports.contentWaiting!.complete(original);
      await tester.pumpAndSettle();
      ports.contentWaiting = null;
      expect(ports.reads, 0);
      expect(find.byKey(const Key('grammar-progress-summary')), findsNothing);
      await load(tester);
      expect(other.reads, 1);
      expect(ports.reads, 1);
      expect(find.text('Vòng gốc · N5 · 0 bộ đã lưu'), findsOneWidget);
    },
  );
  testWidgets('grammar recommendation opens original context without I O', (
    tester,
  ) async {
    final ports = _Ports(original)..records = [report(1)];
    await mount(tester, ports);
    await load(tester);
    final entry = question.target;
    expect(entry.notes, isNotEmpty);
    expect(entry.mistakes, isNotEmpty);
    expect(entry.examples, isNotEmpty);
    expect(find.text(entry.explanationVi), findsNothing);
    await tapQuiz(
      tester,
      find.byKey(ValueKey('grammar-progress-item-${entry.id}')),
    );
    expect(find.text(entry.explanationVi), findsOneWidget);
    for (final note in entry.notes) {
      expect(find.text(note), findsOneWidget);
    }
    for (final mistake in entry.mistakes) {
      expect(find.text(mistake), findsOneWidget);
    }
    for (final example in entry.examples) {
      expect(find.text(example.japanese), findsOneWidget);
      expect(find.text(example.reading), findsOneWidget);
      expect(find.text(example.vietnamese), findsOneWidget);
    }
    expect(
      find.text('Âm thanh chưa khả dụng trong phần ôn này.'),
      findsOneWidget,
    );
    expect(ports.reads, 1);
    expect(ports.contentReads, 1);
    expect(ports.writes, 0);
    // An expanded tile's center is inside its selectable children. Hit the
    // actual header to collapse instead of tapping the whole expanded subtree.
    await tapQuiz(tester, find.text(entry.heading));
    expect(find.text(entry.explanationVi), findsNothing);
    expect(ports.reads, 1);
    expect(ports.contentReads, 1);
    await tapQuiz(tester, find.text(entry.heading));
    expect(find.text(entry.explanationVi), findsOneWidget);
    expect(ports.reads, 1);
    expect(ports.contentReads, 1);
    expect(ports.writes, 0);
  });
  testWidgets('grammar optional context absent stays explicitly unavailable', (
    tester,
  ) async {
    final entry = question.target;
    final sparse = CurriculumEntry(
      id: entry.id,
      kind: entry.kind,
      level: entry.level,
      contentVersion: entry.contentVersion,
      heading: entry.heading,
      caption: entry.caption,
      reading: entry.reading,
      meaningVi: entry.meaningVi,
      explanationVi: entry.explanationVi,
      hasAudioReference: entry.hasAudioReference,
      notes: [],
      mistakes: [],
      examples: [],
    );
    final ports = _Ports([
      for (final e in original) e.id == entry.id ? sparse : e,
    ])..records = [report(1)];
    await mount(tester, ports);
    await load(tester);
    await tapQuiz(
      tester,
      find.byKey(ValueKey('grammar-progress-item-${entry.id}')),
    );
    expect(find.text(entry.explanationVi), findsOneWidget);
    expect(
      find.text('Bài gốc chưa có lưu ý cách dùng cho mẫu này.'),
      findsOneWidget,
    );
    expect(
      find.text('Bài gốc chưa có lỗi thường gặp cho mẫu này.'),
      findsOneWidget,
    );
    expect(find.text('Bài gốc chưa có ví dụ cho mẫu này.'), findsOneWidget);
    expect(find.text('Ví dụ gốc'), findsNothing);
    expect(ports.reads, 1);
    expect(ports.contentReads, 1);
    expect(ports.writes, 0);
  });
  testWidgets('expanded grammar context clears on actual account replacement', (
    tester,
  ) async {
    final ports = _Ports(original)..records = [report(1)];
    await mount(tester, ports);
    await load(tester);
    await tapQuiz(
      tester,
      find.byKey(ValueKey('grammar-progress-item-${question.target.id}')),
    );
    expect(find.text(question.target.explanationVi), findsOneWidget);
    ports.harness.access.change(fixture.other);
    await tester.pumpAndSettle();
    expect(find.text(question.target.explanationVi), findsNothing);
    expect(find.byKey(const Key('grammar-progress-summary')), findsNothing);
    expect(ports.reads, 1);
    expect(ports.contentReads, 1);
    expect(ports.writes, 0);
  });
  testWidgets('expanded grammar context fits narrow double scale view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final ports = _Ports(original)..records = [report(1)];
    await mount(tester, ports);
    await load(tester);
    await tapQuiz(
      tester,
      find.byKey(ValueKey('grammar-progress-item-${question.target.id}')),
    );
    expect(find.text(question.target.explanationVi), findsOneWidget);
    await tester.ensureVisible(
      find.text('Âm thanh chưa khả dụng trong phần ôn này.'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Âm thanh chưa khả dụng trong phần ôn này.').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    expect(ports.reads, 1);
    expect(ports.contentReads, 1);
    expect(ports.writes, 0);
  });
  // Current-deck coverage UI uses the existing explicit load snapshot only.
  testWidgets('grammar coverage labels update only on explicit matching load', (
    tester,
  ) async {
    final ports = _Ports(original);
    await mount(tester, ports);
    expect(find.textContaining('Mẫu chưa có kết quả khớp:'), findsNothing);
    expect(ports.reads, 0);
    final count = buildGrammarQuiz(original, PreviewLevel.n5).length;
    await load(tester);
    expect(
      find.text('Mẫu có câu hỏi trong nội dung hiện tại: $count'),
      findsOneWidget,
    );
    expect(find.text('Mẫu chưa có kết quả khớp: $count'), findsOneWidget);
    expect(find.text('Mẫu có lần trả lời gần nhất đúng: 0'), findsOneWidget);
    ports.records = [report(1)];
    await tester.pumpAndSettle();
    expect(ports.reads, 1);
    expect(find.text('Mẫu chưa có kết quả khớp: $count'), findsOneWidget);
    await load(tester);
    expect(find.text('Mẫu chưa có kết quả khớp: ${count - 1}'), findsOneWidget);
    expect(find.text('Mẫu cần ôn: 1'), findsOneWidget);
    ports.records = [report(1), report(2, correct: true)];
    await load(tester);
    expect(find.text('Mẫu chưa có kết quả khớp: ${count - 1}'), findsOneWidget);
    expect(find.text('Mẫu có lần trả lời gần nhất đúng: 1'), findsOneWidget);
    expect(find.text('Mẫu cần ôn: 0'), findsOneWidget);
    expect(ports.reads, 3);
    expect(ports.contentReads, 3);
    expect(ports.writes, 0);
    expect(tester.takeException(), isNull);
  });
  // Recall UI regression; original fixture remains unchanged.
  testWidgets(
    'grammar recall milestone reloads selected kind without cross credit',
    (tester) async {
      final ports = _Ports(original);
      await mount(tester, ports);
      expect(find.textContaining('đạt mốc ôn cách ngày:'), findsNothing);
      await load(tester);
      expect(
        find.text('Vòng gốc · N5 · Mẫu đạt mốc ôn cách ngày: 0'),
        findsOneWidget,
      );
      OwnedGrammarQuizAttempt spaced(
        int id,
        int day, {
        bool correct = true,
        bool correction = false,
      }) {
        final base = report(id, correct: correct);
        final json = base.attempt.toJson();
        json['completed_at'] = DateTime.utc(
          2026,
          10,
          20 + day,
        ).toIso8601String();
        json['practice_kind'] = correction ? 'correction' : 'primary';
        return OwnedGrammarQuizAttempt(
          base.ownerId,
          GrammarQuizAttempt.fromJson(json),
        );
      }

      final primary = [for (var i = 0; i < 3; i++) spaced(i + 1, i)];
      final corrections = [
        for (var i = 0; i < 3; i++) spaced(i + 10, i, correction: true),
      ];
      ports.records = [...primary, ...corrections, primary.first];
      await tester.pumpAndSettle();
      expect(ports.reads, 1);
      expect(
        find.text('Vòng gốc · N5 · Mẫu đạt mốc ôn cách ngày: 0'),
        findsOneWidget,
      );
      await load(tester);
      expect(
        find.text('Vòng gốc · N5 · Mẫu đạt mốc ôn cách ngày: 1'),
        findsOneWidget,
      );
      expect(find.textContaining('ít nhất 24 giờ'), findsOneWidget);
      expect(
        find.textContaining('không xác nhận đã thuộc bài'),
        findsOneWidget,
      );
      ports.records = [
        ...primary,
        ...corrections,
        spaced(4, 3, correct: false),
      ];
      await tester.pumpAndSettle();
      expect(
        find.text('Vòng gốc · N5 · Mẫu đạt mốc ôn cách ngày: 1'),
        findsOneWidget,
      );
      await load(tester);
      expect(
        find.text('Vòng gốc · N5 · Mẫu đạt mốc ôn cách ngày: 0'),
        findsOneWidget,
      );
      expect(find.text('Mẫu cần ôn: 1'), findsOneWidget);
      await tapQuiz(tester, find.byKey(const Key('grammar-progress-kind')));
      await tapQuiz(tester, find.text('Vòng luyện sai').last);
      expect(find.textContaining('đạt mốc ôn cách ngày:'), findsNothing);
      expect(ports.reads, 3);
      await load(tester);
      expect(
        find.text('Vòng luyện sai · N5 · Mẫu đạt mốc ôn cách ngày: 1'),
        findsOneWidget,
      );
      expect(find.text('Mẫu cần ôn: 0'), findsOneWidget);
      expect(
        find.text('Vòng gốc · N5 · Mẫu đạt mốc ôn cách ngày: 0'),
        findsNothing,
      );
      ports.harness.access.change(fixture.other);
      await tester.pumpAndSettle();
      expect(find.textContaining('đạt mốc ôn cách ngày:'), findsNothing);
      expect(ports.reads, 4);
      expect(ports.contentReads, 4);
      expect(ports.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
  // End recall UI regression.
  // End current-deck coverage UI regression.
}
