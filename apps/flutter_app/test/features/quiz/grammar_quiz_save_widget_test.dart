// TEST ONLY local reports/Auth/memory store; not hosted learner proof.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/quiz/application/grammar_quiz_attempt_factory.dart';
import 'package:nihongo_daily/features/quiz/application/grammar_quiz_history_provider.dart';
import 'package:nihongo_daily/features/quiz/application/grammar_quiz_provider.dart';
import 'package:nihongo_daily/features/quiz/data/grammar_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/data/grammar_quiz_history_repository.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz_attempt.dart';
import 'package:nihongo_daily/features/quiz/presentation/grammar_quiz_save_action.dart';
import 'package:nihongo_daily/features/quiz/presentation/grammar_quiz_screen.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';
import 'grammar_quiz_attempt_test.dart' as fixture;

final class _Auth implements ReviewAuth {
  ReviewSession? session = ReviewSession(userId: fixture.event);
  @override
  ReviewSession? get currentSession => session;
}

final class _Store implements GrammarQuizAttemptStore {
  final sent = <GrammarQuizAttempt>[];
  final rows = <String, OwnedGrammarQuizAttempt>{};
  Completer<void>? gate;
  bool fail = false;
  @override
  Future<OwnedGrammarQuizAttempt> append(
    String ownerId,
    GrammarQuizAttempt attempt,
  ) async {
    sent.add(attempt);
    final value = rows.putIfAbsent(
      attempt.eventId,
      () => OwnedGrammarQuizAttempt(ownerId, attempt),
    );
    await gate?.future;
    if (fail) throw StateError('PRIVATE TOKEN PATH');
    return value;
  }

  @override
  Future<List<OwnedGrammarQuizAttempt>> list(String ownerId) async =>
      rows.values.where((r) => r.ownerId == ownerId).toList();
}

GrammarQuizRound completed() {
  final value = fixture.round();
  while (!value.isComplete) {
    final question = value.current!;
    value.answer(question.id, question.target.id);
    value.advance(question.id);
  }
  return value;
}

void main() {
  late _Auth auth;
  late _Store store;
  late GrammarQuizOperationDrain operations;
  late GrammarQuizHistoryRepository history;
  late GrammarQuizRound round;
  var active = true;
  var captures = 0;
  var captureFails = false;
  GrammarQuizAttempt capture(
    GrammarQuizRound value,
    GrammarQuizAttemptKind kind,
  ) {
    captures++;
    if (captureFails) throw StateError('PRIVATE CAPTURE TOKEN');
    return GrammarQuizAttempt.capture(
      eventId: fixture.id(1000 + captures),
      completedAt: fixture.completed,
      round: value,
      kind: kind,
    );
  }

  setUp(() {
    auth = _Auth();
    store = _Store();
    operations = GrammarQuizOperationDrain();
    active = true;
    captures = 0;
    captureFails = false;
    round = completed();
    history = GrammarQuizHistoryRepository(
      auth: auth,
      store: store,
      isReady: () => active,
      operations: operations,
    );
  });
  tearDown(() async {
    final gate = store.gate;
    if (gate != null && !gate.isCompleted) gate.complete();
    await operations.revokeAndDrain();
  });
  Widget action({
    bool configured = true,
    GrammarQuizAttemptKind kind = GrammarQuizAttemptKind.primary,
  }) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: GrammarQuizSaveAction(
          key: ValueKey(round),
          round: round,
          kind: kind,
          history: configured ? history : null,
          capture: capture,
          isCurrent: () => active,
        ),
      ),
    ),
  );
  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('grammar-quiz-save')));
    await tester.pump();
  }

  test('grammar capture factory uses UUIDv4 UTC and explicit practice kind', () {
    final start = DateTime.now().toUtc();
    final a = captureGrammarQuizAttempt(round, GrammarQuizAttemptKind.primary);
    final b = captureGrammarQuizAttempt(
      round,
      GrammarQuizAttemptKind.correction,
    );
    expect(
      a.eventId,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(a.eventId, isNot(b.eventId));
    expect(a.completedAt.isUtc, isTrue);
    expect(!a.completedAt.isBefore(start), isTrue);
    expect(!a.completedAt.isAfter(DateTime.now().toUtc()), isTrue);
    expect(a.kind, GrammarQuizAttemptKind.primary);
    expect(b.kind, GrammarQuizAttemptKind.correction);
    expect(a.score, 4);
    expect(b.score, 4);
    expect(store.sent, isEmpty);
  });
  test('grammar capture factory rejects unfinished round', () {
    expect(
      () => captureGrammarQuizAttempt(
        fixture.round(),
        GrammarQuizAttemptKind.primary,
      ),
      throwsFormatException,
    );
  });
  testWidgets(
    'grammar save absent repository never captures or reports saved',
    (tester) async {
      await tester.pumpWidget(action(configured: false));
      expect(captures, 0);
      expect(store.sent, isEmpty);
      expect(find.byKey(const Key('grammar-quiz-save')), findsNothing);
      expect(find.byKey(const Key('grammar-quiz-saved')), findsNothing);
    },
  );
  testWidgets(
    'grammar save explicit duplicate taps coalesce without automatic save',
    (tester) async {
      store.gate = Completer<void>();
      await tester.pumpWidget(action());
      expect(captures, 1);
      expect(store.sent, isEmpty);
      final callback = tester
          .widget<FilledButton>(find.byKey(const Key('grammar-quiz-save')))
          .onPressed!;
      callback();
      callback();
      await tester.pump();
      expect(store.sent, hasLength(1));
      expect(find.byKey(const Key('grammar-quiz-saved')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('grammar-quiz-save')))
            .onPressed,
        isNull,
      );
      store.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('grammar-quiz-saved')), findsOneWidget);
      callback();
      await tester.pump();
      expect(store.sent, hasLength(1));
      expect(captures, 1);
    },
  );
  testWidgets(
    'grammar save failure retry retains exact captured event and time',
    (tester) async {
      store.fail = true;
      await tester.pumpWidget(action());
      await save(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('grammar-quiz-save-error')), findsOneWidget);
      expect(find.textContaining('PRIVATE'), findsNothing);
      final original = store.sent.single;
      store.fail = false;
      await save(tester);
      await tester.pumpAndSettle();
      expect(store.sent, hasLength(2));
      expect(identical(store.sent.last, original), isTrue);
      expect(store.rows, hasLength(1));
      expect(captures, 1);
      expect(find.byKey(const Key('grammar-quiz-saved')), findsOneWidget);
    },
  );
  testWidgets(
    'grammar capture failure cannot dispatch or manufacture success',
    (tester) async {
      captureFails = true;
      await tester.pumpWidget(action());
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('grammar-quiz-save')))
            .onPressed,
        isNull,
      );
      expect(store.sent, isEmpty);
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(find.byKey(const Key('grammar-quiz-saved')), findsNothing);
    },
  );
  for (final fail in [false, true]) {
    testWidgets(
      'grammar late save result cannot publish after account change error=$fail',
      (tester) async {
        store.gate = Completer<void>();
        store.fail = fail;
        await tester.pumpWidget(action());
        await save(tester);
        expect(store.sent, hasLength(1));
        active = false;
        auth.session = ReviewSession(userId: fixture.id(999));
        await tester.pumpWidget(action());
        store.gate!.complete();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('grammar-quiz-saved')), findsNothing);
        expect(find.byKey(const Key('grammar-quiz-save-error')), findsNothing);
        expect(find.textContaining('PRIVATE'), findsNothing);
        expect(store.rows.values.single.ownerId, fixture.event);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('grammar save works at 320 pixels and double text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(action());
    await tester.ensureVisible(find.byKey(const Key('grammar-quiz-save')));
    await save(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('grammar-quiz-saved')), findsOneWidget);
    expect(store.sent, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('grammar save disposal consumes late response without setState', (
    tester,
  ) async {
    store.gate = Completer<void>();
    await tester.pumpWidget(action());
    await save(tester);
    await tester.pumpWidget(const SizedBox());
    store.gate!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(store.sent, hasLength(1));
  });
  testWidgets('grammar primary and correction captures stay distinct', (
    tester,
  ) async {
    await tester.pumpWidget(action());
    await save(tester);
    await tester.pumpAndSettle();
    final primary = store.sent.single;
    round = completed();
    await tester.pumpWidget(action(kind: GrammarQuizAttemptKind.correction));
    expect(store.sent, hasLength(1));
    await save(tester);
    await tester.pumpAndSettle();
    expect(store.sent.last.kind, GrammarQuizAttemptKind.correction);
    expect(primary.kind, GrammarQuizAttemptKind.primary);
    expect(primary.score, 4);
    expect(store.sent.last.eventId, isNot(primary.eventId));
    expect(store.rows, hasLength(2));
  });
  testWidgets(
    'grammar screen completion wires explicit save to current provider',
    (tester) async {
      final questions = fixture.round().questions;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            grammarQuizHistoryRepositoryProvider.overrideWithValue(history),
            grammarQuizAttemptFactoryProvider.overrideWithValue(capture),
            grammarQuizProvider(
              PreviewLevel.n5,
            ).overrideWith((ref) async => questions),
          ],
          child: const MaterialApp(home: Scaffold(body: GrammarQuizScreen())),
        ),
      );
      await tester.pumpAndSettle();
      for (final q in questions) {
        final choice = find.byKey(ValueKey('grammar-choice-${q.target.id}'));
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        final next = find.byKey(const Key('grammar-quiz-next'));
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      expect(captures, 1);
      expect(store.sent, isEmpty);
      await tester.ensureVisible(find.byKey(const Key('grammar-quiz-save')));
      await save(tester);
      await tester.pumpAndSettle();
      expect(store.sent.single.kind, GrammarQuizAttemptKind.primary);
      expect(find.byKey(const Key('grammar-quiz-saved')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
