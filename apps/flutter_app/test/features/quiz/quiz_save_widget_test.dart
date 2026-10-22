// TEST ONLY Auth/profile/local memory ports and fixed attempt clock.
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/auth/application/account_provider.dart';
import 'package:nihongo_daily/features/curriculum/data/bundled_curriculum_repository.dart';
import 'package:nihongo_daily/features/curriculum/domain/curriculum.dart';
import 'package:nihongo_daily/features/quiz/application/quiz_attempt_factory.dart';
import 'package:nihongo_daily/features/quiz/application/quiz_history_provider.dart';
import 'package:nihongo_daily/features/quiz/application/vocabulary_quiz_provider.dart';
import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_history_repository.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_attempt.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_progress.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';
import '../srs/account_fixtures.dart' as fixture;
import '../srs/account_widget_test.dart' show Harness;
import 'vocabulary_quiz_widget_test.dart' show tapQuiz;

final class _Store implements VocabularyQuizAttemptStore {
  final records = <String, OwnedVocabularyQuizAttempt>{};
  final attempts = <VocabularyQuizAttempt>[];
  Completer<void>? waiting;
  bool fail = false;
  @override
  Future<OwnedVocabularyQuizAttempt> append(
    String ownerId,
    VocabularyQuizAttempt attempt,
  ) async {
    attempts.add(attempt);
    final key = '$ownerId/${attempt.eventId}';
    final previous = records[key];
    if (previous != null &&
        !sameVocabularyQuizAttempt(previous.attempt, attempt)) {
      throw const VocabularyQuizHistoryConflict();
    }
    final record = previous ?? OwnedVocabularyQuizAttempt(ownerId, attempt);
    records[key] = record;
    await waiting?.future;
    if (fail) throw StateError('PRIVATE PATH TOKEN');
    return record;
  }

  @override
  Future<List<OwnedVocabularyQuizAttempt>> list(String ownerId) async =>
      records.values.where((r) => r.ownerId == ownerId).toList();
}

final class _Source implements VocabularyQuizHistorySource {
  _Source(this.harness, this.store);
  final Harness harness;
  final _Store store;
  final operations = VocabularyQuizOperationDrain();
  @override
  VocabularyQuizHistoryRepository? createVocabularyQuizHistoryRepository() {
    final ready = harness.runtime.readyRuntime;
    if (ready == null) return null;
    return VocabularyQuizHistoryRepository(
      auth: harness.access,
      store: store,
      isReady: () => identical(harness.runtime.readyRuntime, ready),
      operations: operations,
    );
  }
}

void main() {
  late List<QuizQuestion> questions;
  late Harness harness;
  late _Store store;
  late _Source source;
  int captures = 0;

  setUpAll(() async {
    final entries = decodeCurriculum(
      await File('../../data/n5/vocabulary.json').readAsString(),
      CurriculumKind.vocabulary,
      PreviewLevel.n5,
    );
    questions = buildVocabularyQuiz(entries, PreviewLevel.n5).take(1).toList();
  });

  setUp(() {
    harness = Harness();
    store = _Store();
    source = _Source(harness, store);
    captures = 0;
  });

  Future<ProviderContainer> mount(
    WidgetTester tester, {
    bool signIn = true,
    bool failCapture = false,
  }) async {
    final container = ProviderContainer(
      overrides: [
        accountRuntimeProvider.overrideWithValue(harness.runtime),
        quizHistorySourceProvider.overrideWithValue(source),
        vocabularyQuizProvider(
          PreviewLevel.n5,
        ).overrideWith((ref) async => questions),
        quizAttemptFactoryProvider.overrideWithValue((round) {
          captures++;
          if (failCapture) throw StateError('PRIVATE CAPTURE');
          final tail = captures.toString().padLeft(12, '0');
          return VocabularyQuizAttempt.capture(
            eventId: 'a4000000-0000-4000-8000-$tail',
            completedAt: DateTime.utc(2026, 10, 22),
            round: round,
          );
        }),
      ],
    );
    addTearDown(() async {
      final waiting = store.waiting;
      if (waiting != null && !waiting.isCompleted) waiting.complete();
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await source.operations.revokeAndDrain();
      await harness.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NihongoDailyApp(),
      ),
    );
    if (signIn) harness.access.change(fixture.owner);
    await tester.pumpAndSettle();
    expect(harness.runtime.readyRuntime != null, signIn);
    expect(container.read(quizHistoryRepositoryProvider) != null, signIn);
    container.read(routerProvider).go('/quiz');
    await tester.pumpAndSettle();
    expect(find.text('Câu 1 / 1'), findsOneWidget);
    return container;
  }

  Future<void> finish(WidgetTester tester) async {
    await tapQuiz(
      tester,
      find.byKey(ValueKey('quiz-choice-${questions.single.target.id}')),
    );
    expect(find.text('Đúng theo bài gốc.'), findsOneWidget);
    await tapQuiz(tester, find.byKey(const Key('quiz-next')));
    expect(find.text('Kết quả bộ này: 1 / 1'), findsOneWidget);
  }

  test('secure factory returns distinct validated UTC reports', () async {
    try {
      final round = QuizRound(questions);
      final question = questions.single;
      round.answer(question.id, question.target.id);
      round.advance(question.id);
      final first = captureQuizAttempt(round);
      final second = captureQuizAttempt(round);
      expect(first.eventId, isNot(second.eventId));
      expect(first.eventId[14], '4');
      expect(first.completedAt.isUtc, isTrue);
      expect(second.completedAt.isUtc, isTrue);
      expect(first.score, 1);
      expect(
        sameVocabularyQuizAttempt(
          first,
          VocabularyQuizAttempt.fromJson(first.toJson()),
        ),
        isTrue,
      );
    } finally {
      await harness.close();
    }
  });

  testWidgets('explicit save keeps one identity and appears in history', (
    tester,
  ) async {
    final container = await mount(tester);
    expect(captures, 0);
    await finish(tester);
    expect(captures, 1);
    expect(store.attempts, isEmpty);
    final button = find.byKey(const Key('quiz-save'));
    final stale = tester.widget<FilledButton>(button).onPressed!;
    await tapQuiz(tester, button);
    stale();
    await tester.pumpAndSettle();
    expect(store.records, hasLength(1));
    expect(store.attempts, hasLength(1));
    expect(find.byKey(const Key('quiz-saved')), findsOneWidget);
    container.read(routerProvider).go('/quiz/history');
    await tester.pumpAndSettle();
    await tapQuiz(tester, find.byKey(const Key('quiz-history-load')));
    expect(find.text('N5 · 1 / 1'), findsOneWidget);
  });

  testWidgets('uncertain save retries exactly the same captured event', (
    tester,
  ) async {
    store.fail = true;
    await mount(tester);
    await finish(tester);
    await tapQuiz(tester, find.byKey(const Key('quiz-save')));
    expect(find.byKey(const Key('quiz-save-error')), findsOneWidget);
    expect(find.textContaining('PRIVATE'), findsNothing);
    expect(find.byKey(const Key('quiz-saved')), findsNothing);
    expect(store.records, hasLength(1));
    final original = store.attempts.single;
    store.fail = false;
    await tapQuiz(tester, find.byKey(const Key('quiz-save')));
    expect(captures, 1);
    expect(store.records, hasLength(1));
    expect(identical(store.attempts.last, original), isTrue);
    expect(find.byKey(const Key('quiz-saved')), findsOneWidget);
  });

  testWidgets('guest round is never assigned after login', (tester) async {
    await mount(tester, signIn: false);
    await finish(tester);
    harness.access.change(fixture.owner);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quiz-save')), findsNothing);
    expect(captures, 0);
    await tapQuiz(tester, find.text('Làm lại bộ này'));
    await finish(tester);
    expect(captures, 1);
    await tapQuiz(tester, find.byKey(const Key('quiz-save')));
    expect(store.records.values.single.ownerId, fixture.owner);
  });

  for (final nextOwner in [fixture.owner, fixture.other]) {
    testWidgets('held save hides revoked result for $nextOwner', (
      tester,
    ) async {
      await mount(tester);
      await finish(tester);
      store.waiting = Completer<void>();
      final save = find.byKey(const Key('quiz-save'));
      await tester.ensureVisible(save);
      final stale = tester.widget<FilledButton>(save).onPressed!;
      await tester.tap(save);
      await tester.pump();
      stale();
      await tester.pump();
      expect(store.attempts, hasLength(1));
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await harness.runtime.signOut();
      harness.access.change(nextOwner);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quiz-result')), findsNothing);
      expect(find.byKey(const Key('quiz-save')), findsNothing);
      store.waiting!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quiz-saved')), findsNothing);
      expect(find.byKey(const Key('quiz-save-error')), findsNothing);
      stale();
      await tester.pumpAndSettle();
      expect(store.attempts, hasLength(1));
      expect(store.records.values.single.ownerId, fixture.owner);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('same-user replacement revokes the unfinished round', (
    tester,
  ) async {
    await mount(tester);
    await tapQuiz(
      tester,
      find.byKey(ValueKey('quiz-choice-${questions.single.target.id}')),
    );
    final nextButton = tester.widget<FilledButton>(
      find.byKey(const Key('quiz-next')),
    );
    final next = nextButton.onPressed!;
    harness.access.change(fixture.owner);
    await tester.pumpAndSettle();
    next();
    await tester.pumpAndSettle();
    expect(captures, 0);
    expect(store.attempts, isEmpty);
    expect(find.byKey(const Key('quiz-feedback')), findsNothing);
    await tapQuiz(tester, find.text('Làm lại bộ này'));
    await finish(tester);
    expect(captures, 1);
    await tapQuiz(tester, find.byKey(const Key('quiz-save')));
    expect(store.records, hasLength(1));
  });

  testWidgets('capture failure never dispatches or claims saved', (
    tester,
  ) async {
    await mount(tester, failCapture: true);
    await finish(tester);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('quiz-save')),
    );
    expect(button.onPressed, isNull);
    expect(store.attempts, isEmpty);
    expect(find.textContaining('PRIVATE'), findsNothing);
    expect(find.byKey(const Key('quiz-saved')), findsNothing);
  });

  testWidgets('save result at 320px and large text stays readable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await mount(tester);
    await finish(tester);
    await tapQuiz(tester, find.byKey(const Key('quiz-save')));
    expect(find.byKey(const Key('quiz-saved')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
