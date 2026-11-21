// TEST ONLY local history/Auth ports; no hosted identity, sync or mastery proof.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/quiz/application/grammar_quiz_history_provider.dart';
import 'package:nihongo_daily/features/quiz/data/grammar_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/data/grammar_quiz_history_repository.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz_attempt.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'native_grammar_quiz_journal_test.dart' as fixture;

final class _Auth implements ReviewAuth {
  ReviewSession? session = ReviewSession(userId: fixture.ownerA);
  @override
  ReviewSession? get currentSession => session;
}

final class _Store implements GrammarQuizAttemptStore {
  final rows = <OwnedGrammarQuizAttempt>[];
  int reads = 0;
  bool fail = false;
  Completer<void>? wait;
  @override
  Future<List<OwnedGrammarQuizAttempt>> list(String ownerId) async {
    reads++;
    final snapshot = rows.where((r) => r.ownerId == ownerId).toList();
    await wait?.future;
    if (fail) throw StateError('PRIVATE TOKEN PATH');
    return snapshot;
  }

  @override
  Future<OwnedGrammarQuizAttempt> append(
    String ownerId,
    GrammarQuizAttempt attempt,
  ) => throw StateError('History must never write');
}

OwnedGrammarQuizAttempt row(int n, {String? kind, String? level}) {
  final json = fixture.attempt(n).toJson();
  if (kind != null) json['practice_kind'] = kind;
  if (level != null) json['level'] = level;
  return OwnedGrammarQuizAttempt(
    fixture.ownerA,
    GrammarQuizAttempt.fromJson(json),
  );
}

void main() {
  late _Auth auth;
  late _Store store;
  late GrammarQuizOperationDrain operations;
  late GrammarQuizHistoryRepository repository;
  late ProviderContainer container;
  setUp(() {
    auth = _Auth();
    store = _Store();
    operations = GrammarQuizOperationDrain();
    repository = GrammarQuizHistoryRepository(
      auth: auth,
      store: store,
      isReady: () => true,
      operations: operations,
    );
  });
  Future<void> mount(
    WidgetTester tester, {
    bool configured = true,
    bool quiz = false,
  }) async {
    container = ProviderContainer(
      overrides: [
        if (configured)
          grammarQuizHistoryRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(() async {
      final gate = store.wait;
      if (gate != null && !gate.isCompleted) gate.complete();
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await operations.revokeAndDrain();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NihongoDailyApp(),
      ),
    );
    container
        .read(routerProvider)
        .go(quiz ? '/quiz/grammar' : '/quiz/grammar/history');
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String key, String label) async {
    await tap(tester, key);
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  List<String> shown(WidgetTester tester) => tester
      .widgetList<ListTile>(find.byType(ListTile))
      .map((w) => w.key)
      .whereType<ValueKey<String>>()
      .map((key) => key.value)
      .where((key) => key.startsWith('grammar-history-'))
      .toList();

  testWidgets(
    'grammar history route link remains unavailable without account storage',
    (tester) async {
      await mount(tester, configured: false, quiz: true);
      await tap(tester, 'grammar-quiz-history-link');
      expect(find.text('Lịch sử quiz ngữ pháp trên thiết bị'), findsOneWidget);
      expect(find.textContaining('Lịch sử chưa khả dụng.'), findsOneWidget);
      expect(find.byKey(const Key('grammar-history-load')), findsNothing);
      expect(store.reads, 0);
    },
  );
  testWidgets(
    'grammar history loads explicitly and never merges primary correction totals',
    (tester) async {
      store.rows.addAll([row(0), row(1), row(2)]);
      await mount(tester);
      expect(store.reads, 0);
      await tap(tester, 'grammar-history-load');
      expect(store.reads, 1);
      expect(find.text('Vòng gốc: 2 bộ đã lưu'), findsOneWidget);
      expect(
        find.text('Vòng gốc · Câu đúng theo bài gốc: 2 / 2'),
        findsOneWidget,
      );
      expect(shown(tester), [
        'grammar-history-${fixture.event(2)}',
        'grammar-history-${fixture.event(0)}',
      ]);
      await select(tester, 'grammar-history-kind', 'Vòng luyện sai');
      expect(find.text('Vòng luyện sai: 1 bộ đã lưu'), findsOneWidget);
      expect(
        find.text('Vòng luyện sai · Câu đúng theo bài gốc: 0 / 1'),
        findsOneWidget,
      );
      expect(shown(tester), ['grammar-history-${fixture.event(1)}']);
      expect(store.reads, 1);
    },
  );
  testWidgets(
    'grammar history pages in selected order and rejects stale page callback',
    (tester) async {
      store.rows.addAll([for (var i = 0; i < 90; i++) row(i)]);
      await mount(tester);
      await tap(tester, 'grammar-history-load');
      expect(shown(tester), hasLength(20));
      expect(shown(tester).first, 'grammar-history-${fixture.event(88)}');
      final older = tester
          .widget<OutlinedButton>(
            find.byKey(const Key('grammar-history-older')),
          )
          .onPressed!;
      older();
      await tester.pumpAndSettle();
      expect(shown(tester).first, 'grammar-history-${fixture.event(48)}');
      older();
      await tester.pumpAndSettle();
      expect(shown(tester).first, 'grammar-history-${fixture.event(48)}');
      final oldKind = tester
          .widget<DropdownButton<GrammarQuizAttemptKind>>(
            find.byKey(const Key('grammar-history-kind')),
          )
          .onChanged!;
      await tap(tester, 'grammar-history-oldest-first');
      oldKind(GrammarQuizAttemptKind.correction);
      await tester.pumpAndSettle();
      expect(find.text('Vòng gốc: 45 bộ đã lưu'), findsOneWidget);
      expect(shown(tester).first, 'grammar-history-${fixture.event(0)}');
      await select(tester, 'grammar-history-kind', 'Vòng luyện sai');
      expect(shown(tester).first, 'grammar-history-${fixture.event(1)}');
      expect(shown(tester), hasLength(20));
      expect(store.reads, 1);
    },
  );
  testWidgets(
    'grammar history level error filters and empty selection do not reread',
    (tester) async {
      store.rows.addAll([row(0), row(1, kind: 'primary'), row(2, level: 'N4')]);
      await mount(tester);
      await tap(tester, 'grammar-history-load');
      await select(tester, 'grammar-history-level', 'N4');
      expect(find.text('Vòng gốc: 2 bộ đã lưu'), findsOneWidget);
      await tap(tester, 'grammar-history-errors-only');
      expect(shown(tester), ['grammar-history-${fixture.event(1)}']);
      await select(tester, 'grammar-history-level', 'N5');
      expect(shown(tester), isEmpty);
      expect(
        find.text('Không có bộ quiz có câu sai trong bộ lọc này.'),
        findsOneWidget,
      );
      expect(store.reads, 1);
    },
  );
  testWidgets(
    'grammar history safe error explicit retry and genuine empty state',
    (tester) async {
      store.fail = true;
      await mount(tester);
      await tap(tester, 'grammar-history-load');
      expect(find.byKey(const Key('grammar-history-error')), findsOneWidget);
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(find.byKey(const Key('grammar-history-summary')), findsNothing);
      store.fail = false;
      await tap(tester, 'grammar-history-load');
      expect(store.reads, 2);
      expect(
        find.text('Chưa có kết quả quiz được lưu trên thiết bị này.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('grammar-history-error')), findsNothing);
    },
  );
  for (final error in [false, true]) {
    testWidgets(
      'grammar history late result and old callback fenced before source frame error=$error',
      (tester) async {
        store.rows.add(row(0));
        store.wait = Completer<void>();
        await mount(tester);
        final load = tester
            .widget<OutlinedButton>(
              find.byKey(const Key('grammar-history-load')),
            )
            .onPressed!;
        load();
        load();
        await tester.pump();
        expect(store.reads, 1);
        final kind = tester
            .widget<DropdownButton<GrammarQuizAttemptKind>>(
              find.byKey(const Key('grammar-history-kind')),
            )
            .onChanged;
        store.fail = error;
        auth.session = ReviewSession(userId: fixture.ownerB);
        container.updateOverrides([
          grammarQuizHistoryRepositoryProvider.overrideWithValue(null),
        ]);
        load();
        kind?.call(
          GrammarQuizAttemptKind.correction,
        ); // Captured before replacement frame, never dispatch.
        await tester.pump();
        store.wait!.complete();
        await tester.pumpAndSettle();
        expect(find.textContaining('Lịch sử chưa khả dụng.'), findsOneWidget);
        expect(find.byKey(const Key('grammar-history-summary')), findsNothing);
        expect(find.byKey(const Key('grammar-history-error')), findsNothing);
        expect(store.reads, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'grammar history source replacement clears rows and rejects idle old load',
    (tester) async {
      store.rows.add(row(0));
      await mount(tester);
      await tap(tester, 'grammar-history-load');
      final oldLoad = tester
          .widget<OutlinedButton>(find.byKey(const Key('grammar-history-load')))
          .onPressed!;
      auth.session = ReviewSession(userId: fixture.ownerB);
      store.rows.add(
        OwnedGrammarQuizAttempt(fixture.ownerB, fixture.attempt(2)),
      );
      final next = GrammarQuizHistoryRepository(
        auth: auth,
        store: store,
        isReady: () => true,
        operations: operations,
      );
      container.updateOverrides([
        grammarQuizHistoryRepositoryProvider.overrideWithValue(next),
      ]);
      oldLoad();
      await tester.pumpAndSettle();
      expect(store.reads, 1);
      expect(find.byKey(const Key('grammar-history-summary')), findsNothing);
      expect(shown(tester), isEmpty);
      await tap(tester, 'grammar-history-load');
      expect(shown(tester), ['grammar-history-${fixture.event(2)}']);
      oldLoad();
      await tester.pumpAndSettle();
      expect(store.reads, 2);
      expect(shown(tester), ['grammar-history-${fixture.event(2)}']);
    },
  );

  testWidgets(
    'grammar history disposal consumes held read without late publication',
    (tester) async {
      store.rows.add(row(0));
      store.wait = Completer<void>();
      await mount(tester);
      final load = tester
          .widget<OutlinedButton>(find.byKey(const Key('grammar-history-load')))
          .onPressed!;
      load();
      await tester.pump();
      expect(store.reads, 1);
      await tester.pumpWidget(const SizedBox());
      store.wait!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(store.reads, 1);
    },
  );

  testWidgets(
    'grammar history narrow layout separates kind and pages without writes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      store.rows.addAll([for (var i = 0; i < 46; i++) row(i)]);
      await mount(tester);
      await tap(tester, 'grammar-history-load');
      await select(tester, 'grammar-history-kind', 'Vòng luyện sai');
      await tap(tester, 'grammar-history-older');
      expect(shown(tester), hasLength(3));
      expect(store.reads, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
