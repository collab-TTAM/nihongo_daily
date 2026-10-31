// TEST ONLY Auth/profile/memory/clock; original N5 source is read unchanged.
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
import 'package:nihongo_daily/features/quiz/application/quiz_attempt_factory.dart';
import 'package:nihongo_daily/features/quiz/application/quiz_history_provider.dart';
import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_history_repository.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_attempt.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_progress.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';
import '../curriculum/curriculum_widget_test.dart'
    show FixtureCurriculumRepository;
import '../srs/account_fixtures.dart' as fixture;
import '../srs/account_widget_test.dart' show Harness;
import 'vocabulary_quiz_widget_test.dart' show tapQuiz;

final class _Ports
    implements
        VocabularyQuizHistorySource,
        VocabularyQuizAttemptStore,
        CurriculumRepository {
  _Ports(this.current);
  List<CurriculumEntry> current;
  final harness = Harness();
  final operations = VocabularyQuizOperationDrain();
  final records = <String, OwnedVocabularyQuizAttempt>{};
  final saved = <VocabularyQuizAttempt>[];
  Completer<void>? waiting;
  Completer<void>? entered;
  int captures = 0;

  void seed(VocabularyQuizAttempt attempt) {
    records['${fixture.owner}/${attempt.eventId}'] = OwnedVocabularyQuizAttempt(
      fixture.owner,
      attempt,
    );
  }

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
  ) async => level == PreviewLevel.n5 ? current : const [];
  @override
  Future<List<OwnedVocabularyQuizAttempt>> list(String ownerId) async =>
      records.values.where((r) => r.ownerId == ownerId).toList();
  @override
  Future<OwnedVocabularyQuizAttempt> append(
    String ownerId,
    VocabularyQuizAttempt attempt,
  ) async {
    saved.add(attempt);
    final key = '$ownerId/${attempt.eventId}';
    final previous = records[key];
    if (previous != null &&
        !sameVocabularyQuizAttempt(previous.attempt, attempt)) {
      throw const VocabularyQuizHistoryConflict();
    }
    final record = records.putIfAbsent(
      key,
      () => OwnedVocabularyQuizAttempt(ownerId, attempt),
    );
    if (!(entered?.isCompleted ?? true)) entered!.complete();
    await waiting?.future;
    return record;
  }
}

void main() {
  late String originalJson;
  late List<CurriculumEntry> original;
  late List<QuizQuestion> deck;
  setUpAll(() async {
    originalJson = await File('../../data/n5/vocabulary.json').readAsString();
    original = decodeCurriculum(
      originalJson,
      CurriculumKind.vocabulary,
      PreviewLevel.n5,
    );
    deck = buildVocabularyQuiz(original, PreviewLevel.n5);
  });
  VocabularyQuizAttempt report(
    List<QuizQuestion> questions,
    int id, {
    bool correct = false,
  }) {
    final round = QuizRound(questions);
    for (final q in questions) {
      round.answer(
        q.id,
        correct
            ? q.target.id
            : q.choices.firstWhere((c) => c.id != q.target.id).id,
      );
      round.advance(q.id);
    }
    return VocabularyQuizAttempt.capture(
      eventId: 'a6000000-0000-4000-8000-${id.toString().padLeft(12, '0')}',
      completedAt: DateTime.utc(2026, 10, 23, 0, id),
      round: round,
    );
  }

  Future<ProviderContainer> mount(
    WidgetTester tester,
    _Ports ports, {
    Size size = const Size(1100, 900),
    double scale = 1,
    StateProvider<CurriculumRepository>? source,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = ProviderContainer(
      overrides: [
        accountRuntimeProvider.overrideWithValue(ports.harness.runtime),
        quizHistorySourceProvider.overrideWithValue(ports),
        if (source == null)
          curriculumRepositoryProvider.overrideWithValue(ports)
        else
          curriculumRepositoryProvider.overrideWith((ref) => ref.watch(source)),
        quizAttemptFactoryProvider.overrideWithValue((round) {
          final count = ++ports.captures;
          return VocabularyQuizAttempt.capture(
            eventId:
                'a7000000-0000-4000-8000-${count.toString().padLeft(12, '0')}',
            completedAt: DateTime.utc(2026, 10, 23, 12, 0, count),
            round: round,
          );
        }),
      ],
    );
    addTearDown(() async {
      if (!(ports.waiting?.isCompleted ?? true)) ports.waiting!.complete();
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await ports.operations.revokeAndDrain();
      await ports.harness.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NihongoDailyApp(),
      ),
    );
    ports.harness.access.change(fixture.owner);
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/progress');
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> load(WidgetTester tester) =>
      tapQuiz(tester, find.byKey(const Key('quiz-progress-load')));
  Future<void> practice(WidgetTester tester) =>
      tapQuiz(tester, find.byKey(const Key('quiz-review-start')));
  Future<void> answer(WidgetTester tester, QuizQuestion question) async {
    await tapQuiz(
      tester,
      find.byKey(ValueKey('quiz-choice-${question.target.id}')),
    );
    await tapQuiz(tester, find.byKey(const Key('quiz-next')));
  }

  testWidgets('empty current progress offers no fabricated focused practice', (
    tester,
  ) async {
    final ports = _Ports(original);
    await mount(tester, ports);
    await load(tester);
    expect(find.byKey(const Key('quiz-review-start')), findsNothing);
    expect(find.byKey(const Key('quiz-prompt')), findsNothing);
    expect(ports.saved, isEmpty);
    expect(ports.captures, 0);
  });

  testWidgets(
    'focused review preserves priority choices and explicit save clears candidates',
    (tester) async {
      final ports = _Ports(original)
        ..seed(report([deck[0]], 1))
        ..seed(report([deck[2]], 2))
        ..seed(report([deck[2]], 3));
      await mount(tester, ports);
      await load(tester);
      await practice(tester);
      expect(find.text('Luyện lại 2 từ cần ôn'), findsOneWidget);
      expect(find.text(deck[2].target.heading), findsOneWidget);
      for (final c in deck[2].choices) {
        expect(find.byKey(ValueKey('quiz-choice-${c.id}')), findsOneWidget);
      }
      expect(
        find.byKey(const Key('quiz_review-timer-date'), skipOffstage: false),
        findsNothing,
      );
      await answer(tester, deck[2]);
      expect(find.text(deck[0].target.heading), findsOneWidget);
      await answer(tester, deck[0]);
      expect(find.text('Kết quả bộ này: 2 / 2'), findsOneWidget);
      expect(ports.saved, isEmpty);
      await tapQuiz(tester, find.byKey(const Key('quiz-save')));
      expect(find.byKey(const Key('quiz-saved')), findsOneWidget);
      expect(ports.saved, hasLength(1));
      expect(ports.saved.single.answers.map((a) => a.itemId), [
        deck[2].target.id,
        deck[0].target.id,
      ]);
      await tapQuiz(tester, find.byKey(const Key('quiz-review-back')));
      await load(tester);
      expect(find.text('Từ cần ôn: 0'), findsOneWidget);
      expect(find.byKey(const Key('quiz-review-start')), findsNothing);
    },
  );

  testWidgets(
    'retained review action cannot reuse a replaced progress projection',
    (tester) async {
      final ports = _Ports(original)..seed(report([deck.first], 1));
      await mount(tester, ports);
      await load(tester);
      final stale = tester
          .widget<FilledButton>(find.byKey(const Key('quiz-review-start')))
          .onPressed!;
      ports.seed(report([deck.first], 2, correct: true));
      await load(tester);
      stale();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quiz-prompt')), findsNothing);
      expect(find.byKey(const Key('quiz-review-start')), findsNothing);
      expect(ports.saved, isEmpty);
    },
  );

  testWidgets(
    'source replacement rejects retained review before the next frame',
    (tester) async {
      final ports = _Ports(original)..seed(report([deck.first], 1));
      final source = StateProvider<CurriculumRepository>((ref) => ports);
      final container = await mount(tester, ports, source: source);
      await load(tester);
      final stale = tester
          .widget<FilledButton>(find.byKey(const Key('quiz-review-start')))
          .onPressed!;
      container.read(source.notifier).state = FixtureCurriculumRepository(
        (_, _) async => original,
      );
      stale();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
      expect(find.byKey(const Key('quiz-prompt')), findsNothing);
      expect(ports.saved, isEmpty);
      expect(ports.captures, 0);
    },
  );

  testWidgets(
    'changed content version excludes old mistakes from focused practice',
    (tester) async {
      final ports = _Ports(original)..seed(report([deck.first], 1));
      await mount(tester, ports);
      await load(tester);
      expect(find.byKey(const Key('quiz-review-start')), findsOneWidget);
      // New valid objects/versions represent an explicit source publication.
      ports.current = decodeCurriculum(
        originalJson.replaceAll('"content_version": 1', '"content_version": 2'),
        CurriculumKind.vocabulary,
        PreviewLevel.n5,
      );
      expect(ports.current.first.contentVersion, 2);
      await load(tester);
      expect(find.text('Từ cần ôn: 0'), findsOneWidget);
      expect(find.byKey(const Key('quiz-review-start')), findsNothing);
      expect(ports.saved, isEmpty);
    },
  );

  testWidgets(
    'focused save remains original-owner only after logout and late completion',
    (tester) async {
      final ports = _Ports(original)..seed(report([deck.first], 1));
      await mount(tester, ports);
      await load(tester);
      await practice(tester);
      await answer(tester, deck.first);
      ports.waiting = Completer<void>();
      ports.entered = Completer<void>();
      final save = find.byKey(const Key('quiz-save'));
      await tester.ensureVisible(save);
      await tester.pump();
      expect(save.hitTestable(), findsOneWidget);
      await tester.tap(save);
      await tester.pump();
      expect(ports.entered!.isCompleted, isTrue);
      ports.harness.access.change(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quiz-saved')), findsNothing);
      ports.harness.access.change(fixture.other);
      await tester.pumpAndSettle();
      ports.waiting!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quiz-saved')), findsNothing);
      expect(find.byKey(const Key('quiz-prompt')), findsNothing);
      expect((await ports.list(fixture.other)), isEmpty);
      expect((await ports.list(fixture.owner)), hasLength(2));
    },
  );

  testWidgets(
    'level change closes focused quiz and rejects its retained answer',
    (tester) async {
      final ports = _Ports(original)..seed(report([deck.first], 1));
      await mount(tester, ports);
      await load(tester);
      await practice(tester);
      final stale = tester
          .widget<OutlinedButton>(
            find.byKey(ValueKey('quiz-choice-${deck.first.target.id}')),
          )
          .onPressed!;
      await tapQuiz(tester, find.byKey(const Key('quiz-progress-level')));
      await tester.tap(find.text('N4').last);
      await tester.pumpAndSettle();
      stale();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quiz-prompt')), findsNothing);
      expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
      expect(ports.saved, isEmpty);
      expect(ports.captures, 0);
    },
  );

  testWidgets(
    'reopening focused review resets answers and fences its old back action',
    (tester) async {
      final ports = _Ports(original)..seed(report([deck.first], 1));
      await mount(tester, ports);
      await load(tester);
      await practice(tester);
      final staleBack = tester
          .widget<OutlinedButton>(find.byKey(const Key('quiz-review-back')))
          .onPressed!;
      await tapQuiz(
        tester,
        find.byKey(ValueKey('quiz-choice-${deck.first.target.id}')),
      );
      expect(find.byKey(const Key('quiz-feedback')), findsOneWidget);
      await tapQuiz(tester, find.byKey(const Key('quiz-review-back')));
      await practice(tester);
      staleBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quiz-prompt')), findsOneWidget);
      expect(find.byKey(const Key('quiz-feedback')), findsNothing);
      expect(ports.saved, isEmpty);
      expect(ports.captures, 0);
    },
  );

  testWidgets(
    'focused practice uses real controls at 320px and 200 percent text',
    (tester) async {
      final ports = _Ports(original)..seed(report([deck.first], 1));
      await mount(tester, ports, size: const Size(320, 640), scale: 2);
      await load(tester);
      await practice(tester);
      await answer(tester, deck.first);
      await tapQuiz(tester, find.byKey(const Key('quiz-save')));
      expect(find.byKey(const Key('quiz-saved')), findsOneWidget);
      expect(ports.saved, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  // Child practice capability regressions; all prior cases remain unchanged.
  for (final phase in ['choice', 'next', 'save']) {
    testWidgets('focused source A B A retires child $phase before frame', (
      tester,
    ) async {
      final ports = _Ports(original)..seed(report([deck.first], 1));
      final source = StateProvider<CurriculumRepository>((ref) => ports);
      final container = await mount(tester, ports, source: source);
      await load(tester);
      await practice(tester);
      final q = deck.first;
      late VoidCallback stale;
      if (phase == 'choice') {
        stale = tester
            .widget<OutlinedButton>(
              find.byKey(ValueKey('quiz-choice-${q.target.id}')),
            )
            .onPressed!;
      } else {
        await tapQuiz(
          tester,
          find.byKey(ValueKey('quiz-choice-${q.target.id}')),
        );
        if (phase == 'next') {
          stale = tester
              .widget<FilledButton>(find.byKey(const Key('quiz-next')))
              .onPressed!;
        } else {
          await tapQuiz(tester, find.byKey(const Key('quiz-next')));
          stale = tester
              .widget<FilledButton>(find.byKey(const Key('quiz-save')))
              .onPressed!;
        }
      }
      final captures = ports.captures;
      container.read(source.notifier).state = FixtureCurriculumRepository(
        (_, _) async => throw StateError('Retired source must not load'),
      );
      container.read(curriculumRepositoryProvider);
      container.read(source.notifier).state = ports;
      expect(container.read(curriculumRepositoryProvider), same(ports));
      stale();
      await tester.idle(); // No replacement frame yet.
      expect(ports.captures, captures);
      expect(ports.saved, isEmpty);
      if (phase == 'choice') {
        expect(find.byKey(const Key('quiz-feedback')), findsNothing);
      }
      if (phase == 'next') {
        expect(find.byKey(const Key('quiz-result')), findsNothing);
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quiz-prompt')), findsNothing);
      expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
      await load(tester);
      await practice(tester);
      stale();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quiz-feedback')), findsNothing);
      await answer(tester, q);
      expect(find.text('Kết quả bộ này: 1 / 1'), findsOneWidget);
      expect(ports.captures, captures + 1);
      expect(ports.saved, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('focused accepted save cannot publish after explicit back', (
    tester,
  ) async {
    final ports = _Ports(original)..seed(report([deck.first], 1));
    await mount(tester, ports);
    await load(tester);
    await practice(tester);
    await answer(tester, deck.first);
    ports.waiting = Completer<void>();
    ports.entered = Completer<void>();
    await tapQuiz(tester, find.byKey(const Key('quiz-save')));
    expect(ports.entered!.isCompleted, isTrue);
    expect(ports.saved, hasLength(1));
    await tapQuiz(tester, find.byKey(const Key('quiz-review-back')));
    ports.waiting!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quiz-saved')), findsNothing);
    expect(find.byKey(const Key('quiz-save-error')), findsNothing);
    expect(find.text('Câu đúng theo bài gốc: 0 / 1'), findsOneWidget);
    expect(ports.captures, 1);
    expect(ports.saved, hasLength(1));
    // Accepted storage is not rolled back; only an explicit reload observes it.
    await load(tester);
    expect(find.text('Câu đúng theo bài gốc: 1 / 2'), findsOneWidget);
    expect(find.text('Từ cần ôn: 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'focused factory replacement retires captured next before frame',
    (tester) async {
      final ports = _Ports(original)..seed(report([deck.first], 1));
      final container = await mount(tester, ports);
      await load(tester);
      await practice(tester);
      await tapQuiz(
        tester,
        find.byKey(ValueKey('quiz-choice-${deck.first.target.id}')),
      );
      final stale = tester
          .widget<FilledButton>(find.byKey(const Key('quiz-next')))
          .onPressed!;
      int replacements = 0;
      VocabularyQuizAttempt replacement(QuizRound round) {
        replacements++;
        return captureQuizAttempt(round);
      }

      container.updateOverrides([
        accountRuntimeProvider.overrideWithValue(ports.harness.runtime),
        quizHistorySourceProvider.overrideWithValue(ports),
        curriculumRepositoryProvider.overrideWithValue(ports),
        quizAttemptFactoryProvider.overrideWithValue(replacement),
      ]);
      container.read(quizAttemptFactoryProvider);
      stale();
      expect(ports.captures, 0);
      expect(replacements, 0);
      expect(ports.saved, isEmpty);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quiz-prompt')), findsNothing);
      expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
      await load(tester);
      await practice(tester);
      await answer(tester, deck.first);
      expect(replacements, 1);
      expect(ports.captures, 0);
      expect(ports.saved, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  // End child practice capability regressions.
}
