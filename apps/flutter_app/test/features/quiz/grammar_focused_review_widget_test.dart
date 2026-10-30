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
import '../srs/account_fixtures.dart' as fixture;
import '../srs/account_widget_test.dart' show Harness;
import 'vocabulary_quiz_widget_test.dart' show tapQuiz;
import 'grammar_quiz_test.dart' show sample;
import 'package:nihongo_daily/features/quiz/application/grammar_quiz_attempt_factory.dart';

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
  int expectedWrites = 0;
  bool failSave = false;
  Completer<OwnedGrammarQuizAttempt>? saveWait;
  final attempts = <GrammarQuizAttempt>[];

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
  ) async {
    writes++;
    attempts.add(attempt);
    if (failSave) throw StateError('PRIVATE SAVE TOKEN');
    final result = saveWait == null
        ? OwnedGrammarQuizAttempt(ownerId, attempt)
        : await saveWait!.future;
    records = [...records, result];
    return result;
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
    GrammarQuizAttemptFactory? capture,
  }) async {
    final container = ProviderContainer(
      overrides: [
        if (configured)
          accountRuntimeProvider.overrideWithValue(ports.harness.runtime),
        if (configured)
          grammarQuizHistorySourceProvider.overrideWithValue(ports),
        curriculumRepositoryProvider.overrideWithValue(ports),
        if (capture != null)
          grammarQuizAttemptFactoryProvider.overrideWithValue(capture),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      final waiting = ports.waiting;
      if (waiting != null && !waiting.isCompleted) waiting.complete([]);
      final content = ports.contentWaiting;
      if (content != null && !content.isCompleted) content.complete(original);
      final save = ports.saveWait;
      if (save != null && !save.isCompleted && ports.attempts.isNotEmpty) {
        save.complete(
          OwnedGrammarQuizAttempt(fixture.owner, ports.attempts.last),
        );
      }
      container.dispose();
      await ports.operations.revokeAndDrain();
      expect(ports.writes, ports.expectedWrites);
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

  Future<void> start(WidgetTester tester) =>
      tapQuiz(tester, find.byKey(const Key('grammar-focused-start')));
  Future<void> finishOne(WidgetTester tester) async {
    await tapQuiz(
      tester,
      find.byKey(ValueKey('grammar-choice-${question.target.id}')),
    );
    await tapQuiz(tester, find.byKey(const Key('grammar-quiz-next')));
  }

  testWidgets(
    'focused grammar explicit start preserves choices and saves correction only',
    (tester) async {
      final ports = _Ports(original)
        ..records = [report(1)]
        ..expectedWrites = 1;
      await mount(tester, ports);
      expect(find.byKey(const Key('grammar-focused-start')), findsNothing);
      await load(tester);
      await start(tester);
      expect(find.text('Luyện lại 1 mẫu cần ôn'), findsOneWidget);
      for (final choice in question.choices) {
        expect(
          find.byKey(ValueKey('grammar-choice-${choice.id}')),
          findsOneWidget,
        );
      }
      expect(ports.reads, 1);
      expect(ports.contentReads, 1);
      expect(ports.writes, 0);
      await finishOne(tester);
      expect(ports.writes, 0);
      expect(find.text('Kết quả theo bài gốc: 1 / 1'), findsOneWidget);
      await tapQuiz(tester, find.byKey(const Key('grammar-quiz-save')));
      expect(find.byKey(const Key('grammar-quiz-saved')), findsOneWidget);
      expect(ports.attempts.single.kind, GrammarQuizAttemptKind.correction);
      expect(ports.attempts.single.score, 1);
      expect(
        sameGrammarQuizAttempt(ports.records.first.attempt, report(1).attempt),
        isTrue,
      );
      await tapQuiz(tester, find.byKey(const Key('grammar-focused-back')));
      expect(
        find.text('Vòng gốc · Câu đúng theo bài gốc: 0 / 1'),
        findsOneWidget,
      );
      expect(find.text('Mẫu cần ôn: 1'), findsOneWidget);
      expect(ports.reads, 1);
      expect(ports.contentReads, 1);
      await load(tester);
      expect(
        find.text('Vòng gốc · Câu đúng theo bài gốc: 0 / 1'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('grammar-focused-start')), findsOneWidget);
    },
  );
  testWidgets(
    'empty correct-only correction and unready progress cannot start practice',
    (tester) async {
      final ports = _Ports(original);
      ports.harness.delayed = Completer<OwnProfile>();
      await mount(tester, ports);
      expect(find.byKey(const Key('grammar-focused-start')), findsNothing);
      ports.harness.delayed!.complete(fixture.ownProfile());
      await tester.pumpAndSettle();
      await load(tester);
      expect(find.byKey(const Key('grammar-focused-start')), findsNothing);
      ports.records = [report(1, correct: true)];
      await load(tester);
      expect(find.byKey(const Key('grammar-focused-start')), findsNothing);
      ports.records = [report(1)];
      tester
          .widget<DropdownButton<GrammarQuizAttemptKind>>(
            find.byKey(const Key('grammar-progress-kind')),
          )
          .onChanged!(GrammarQuizAttemptKind.correction);
      await tester.pumpAndSettle();
      await load(tester);
      expect(find.byKey(const Key('grammar-focused-start')), findsNothing);
      expect(ports.writes, 0);
    },
  );
  testWidgets('focused stale start after level selection cannot dispatch', (
    tester,
  ) async {
    final ports = _Ports(original)..records = [report(1)];
    await mount(tester, ports);
    await load(tester);
    final stale = tester
        .widget<FilledButton>(find.byKey(const Key('grammar-focused-start')))
        .onPressed!;
    tester
        .widget<DropdownButton<PreviewLevel>>(
          find.byKey(const Key('grammar-progress-level')),
        )
        .onChanged!(PreviewLevel.n4);
    stale();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('grammar-focused-back')), findsNothing);
    expect(ports.reads, 1);
    expect(ports.contentReads, 1);
    expect(ports.writes, 0);
  });
  testWidgets(
    'focused back fences retained answer and old start before frame',
    (tester) async {
      final ports = _Ports(original)..records = [report(1)];
      await mount(tester, ports);
      await load(tester);
      final oldStart = tester
          .widget<FilledButton>(find.byKey(const Key('grammar-focused-start')))
          .onPressed!;
      await start(tester);
      final oldAnswer = tester
          .widget<OutlinedButton>(
            find.byKey(ValueKey('grammar-choice-${question.target.id}')),
          )
          .onPressed!;
      tester
          .widget<OutlinedButton>(find.byKey(const Key('grammar-focused-back')))
          .onPressed!();
      oldAnswer();
      oldStart();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('grammar-focused-back')), findsNothing);
      await start(tester);
      oldAnswer();
      await tester.pumpAndSettle();
      expect(find.text('Đúng theo bài gốc.'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('grammar-quiz-next')))
            .onPressed,
        isNull,
      );
      expect(ports.reads, 1);
      expect(ports.contentReads, 1);
    },
  );
  testWidgets('focused practice account replacement retires retained actions', (
    tester,
  ) async {
    final ports = _Ports(original)..records = [report(1)];
    await mount(tester, ports);
    await load(tester);
    await start(tester);
    final oldAnswer = tester
        .widget<OutlinedButton>(
          find.byKey(ValueKey('grammar-choice-${question.target.id}')),
        )
        .onPressed!;
    final oldBack = tester
        .widget<OutlinedButton>(find.byKey(const Key('grammar-focused-back')))
        .onPressed!;
    ports.harness.access.change(fixture.other);
    oldAnswer();
    oldBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('grammar-focused-back')), findsNothing);
    expect(find.text(question.target.heading), findsNothing);
    expect(ports.writes, 0);
  });
  testWidgets('focused source replacement disposes practice and stale back', (
    tester,
  ) async {
    final ports = _Ports(original)..records = [report(1)];
    final container = await mount(tester, ports);
    await load(tester);
    await start(tester);
    final oldBack = tester
        .widget<OutlinedButton>(find.byKey(const Key('grammar-focused-back')))
        .onPressed!;
    container.updateOverrides([
      accountRuntimeProvider.overrideWithValue(ports.harness.runtime),
      grammarQuizHistorySourceProvider.overrideWithValue(ports),
      curriculumRepositoryProvider.overrideWithValue(_OtherSource(original)),
    ]);
    container.read(curriculumRepositoryProvider);
    oldBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('grammar-focused-back')), findsNothing);
    expect(find.byKey(const Key('grammar-progress-summary')), findsNothing);
    expect(ports.reads, 1);
  });
  testWidgets('focused manual save retry retains original correction event', (
    tester,
  ) async {
    final ports = _Ports(original)
      ..records = [report(1)]
      ..expectedWrites = 2
      ..failSave = true;
    await mount(tester, ports);
    await load(tester);
    await start(tester);
    await finishOne(tester);
    await tapQuiz(tester, find.byKey(const Key('grammar-quiz-save')));
    expect(find.byKey(const Key('grammar-quiz-saved')), findsNothing);
    expect(find.textContaining('PRIVATE'), findsNothing);
    ports.failSave = false;
    await tapQuiz(tester, find.byKey(const Key('grammar-quiz-save')));
    expect(find.byKey(const Key('grammar-quiz-saved')), findsOneWidget);
    expect(ports.attempts, hasLength(2));
    expect(
      sameGrammarQuizAttempt(ports.attempts.first, ports.attempts.last),
      isTrue,
    );
    expect(ports.attempts.last.kind, GrammarQuizAttemptKind.correction);
    expect(ports.records, hasLength(2));
  });
  testWidgets('focused held save cannot publish after back', (tester) async {
    final ports = _Ports(original)
      ..records = [report(1)]
      ..expectedWrites = 1
      ..saveWait = Completer<OwnedGrammarQuizAttempt>();
    await mount(tester, ports);
    await load(tester);
    await start(tester);
    await finishOne(tester);
    await tapQuiz(tester, find.byKey(const Key('grammar-quiz-save')));
    expect(ports.writes, 1);
    await tapQuiz(tester, find.byKey(const Key('grammar-focused-back')));
    ports.saveWait!.complete(
      OwnedGrammarQuizAttempt(fixture.owner, ports.attempts.single),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('grammar-quiz-saved')), findsNothing);
    expect(
      find.text('Vòng gốc · Câu đúng theo bài gốc: 0 / 1'),
      findsOneWidget,
    );
    expect(find.text('Mẫu cần ôn: 1'), findsOneWidget);
    expect(ports.reads, 1);
  });
  testWidgets('focused grammar fits narrow double-scale display', (
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
    await start(tester);
    await finishOne(tester);
    expect(find.text('Kết quả theo bài gốc: 1 / 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'focused every batch and restart save is correction with fresh event',
    (tester) async {
      final source = [
        for (var i = 0; i < 12; i++)
          sample(
            i,
            id: 'a6000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
          ),
      ];
      final deck = buildGrammarQuiz(source, PreviewLevel.n5);
      final initial = <OwnedGrammarQuizAttempt>[];
      for (var offset = 0; offset < 12; offset += 10) {
        final round = GrammarQuizRound(deck.skip(offset).take(10).toList());
        for (final q in round.questions) {
          round.answer(
            q.id,
            q.choices.firstWhere((c) => c.id != q.target.id).id,
          );
          round.advance(q.id);
        }
        initial.add(
          OwnedGrammarQuizAttempt(
            fixture.owner,
            GrammarQuizAttempt.capture(
              eventId:
                  'a7000000-0000-4000-8000-${offset.toString().padLeft(12, '0')}',
              completedAt: DateTime.utc(2026, 10, 22, 0, offset),
              round: round,
              kind: GrammarQuizAttemptKind.primary,
            ),
          ),
        );
      }
      final ports = _Ports(source)
        ..records = List.of(initial)
        ..expectedWrites = 3;
      await mount(tester, ports);
      await load(tester);
      await start(tester);
      final selected = [deck[10], deck[11], ...deck.take(10)];
      Future<void> finish(List<GrammarQuizQuestion> batch) async {
        for (final q in batch) {
          await tapQuiz(
            tester,
            find.byKey(ValueKey('grammar-choice-${q.target.id}')),
          );
          await tapQuiz(tester, find.byKey(const Key('grammar-quiz-next')));
        }
        await tapQuiz(tester, find.byKey(const Key('grammar-quiz-save')));
        expect(find.byKey(const Key('grammar-quiz-saved')), findsOneWidget);
      }

      await finish(selected.take(10).toList());
      await tapQuiz(tester, find.byKey(const Key('grammar-quiz-restart')));
      await finish(selected.take(10).toList());
      await tapQuiz(tester, find.byKey(const Key('grammar-quiz-batch')));
      await finish(selected.skip(10).toList());
      expect(ports.attempts.map((a) => a.answers.length).toList(), [10, 10, 2]);
      expect(
        ports.attempts.every(
          (a) => a.kind == GrammarQuizAttemptKind.correction,
        ),
        isTrue,
      );
      expect(ports.attempts.map((a) => a.eventId).toSet(), hasLength(3));
      for (var i = 0; i < 2; i++) {
        expect(
          sameGrammarQuizAttempt(ports.records[i].attempt, initial[i].attempt),
          isTrue,
        );
      }
      await tapQuiz(tester, find.byKey(const Key('grammar-focused-back')));
      expect(
        find.text('Vòng gốc · Câu đúng theo bài gốc: 0 / 12'),
        findsOneWidget,
      );
      expect(ports.reads, 1);
      expect(ports.contentReads, 1);
    },
  );
  testWidgets(
    'focused capture factory replacement retires old practice before frame',
    (tester) async {
      final ports = _Ports(original)..records = [report(1)];
      final container = await mount(
        tester,
        ports,
        capture: captureGrammarQuizAttempt,
      );
      await load(tester);
      await start(tester);
      final oldAnswer = tester
          .widget<OutlinedButton>(
            find.byKey(ValueKey('grammar-choice-${question.target.id}')),
          )
          .onPressed!;
      final GrammarQuizAttemptFactory replacement = (round, kind) =>
          captureGrammarQuizAttempt(round, kind);
      container.updateOverrides([
        accountRuntimeProvider.overrideWithValue(ports.harness.runtime),
        grammarQuizHistorySourceProvider.overrideWithValue(ports),
        curriculumRepositoryProvider.overrideWithValue(ports),
        grammarQuizAttemptFactoryProvider.overrideWithValue(replacement),
      ]);
      expect(
        container.read(grammarQuizAttemptFactoryProvider),
        same(replacement),
      );
      oldAnswer();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('grammar-focused-back')), findsNothing);
      expect(find.byKey(const Key('grammar-progress-summary')), findsNothing);
      expect(ports.writes, 0);
      expect(ports.reads, 1);
      expect(ports.contentReads, 1);
    },
  );
}
