// TEST ONLY Auth/profile and local read ports; no hosted learner evidence.
import 'dart:async';
import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/auth/application/account_provider.dart';
import 'package:nihongo_daily/features/auth/application/account_startup_controller.dart';
import 'package:nihongo_daily/features/auth/presentation/account_startup_app.dart';
import 'package:nihongo_daily/features/quiz/application/quiz_history_provider.dart';
import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_history_repository.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_attempt.dart';
import '../srs/account_fixtures.dart' as fixture;
import '../srs/account_widget_test.dart' show Harness;
import 'quiz_journal_fixtures.dart' show quizReport;

final class _ReadStore implements VocabularyQuizAttemptStore {
  _ReadStore(this.read);
  final Future<List<OwnedVocabularyQuizAttempt>> Function(String) read;
  @override
  Future<List<OwnedVocabularyQuizAttempt>> list(String ownerId) =>
      read(ownerId);
  @override
  Future<OwnedVocabularyQuizAttempt> append(
    String ownerId,
    VocabularyQuizAttempt attempt,
  ) => throw StateError('History view must never append');
}

final class _Owner<T>
    implements AccountStartupRuntime<T>, VocabularyQuizHistorySource {
  _Owner(this.account, this.source);
  @override
  final T account;
  final _Source source;
  final starting = Completer<void>();
  Completer<void>? closing;
  @override
  bool get canOfferLogin => false;
  @override
  Future<void> start() => starting.future;
  @override
  Future<void> close() async => await closing?.future;
  @override
  VocabularyQuizHistoryRepository? createVocabularyQuizHistoryRepository() =>
      source.createVocabularyQuizHistoryRepository();
}

final class _Source implements VocabularyQuizHistorySource {
  _Source(this.harness);
  final Harness harness;
  final operations = VocabularyQuizOperationDrain();
  int creations = 0;
  int reads = 0;
  Future<List<OwnedVocabularyQuizAttempt>> Function(String) response =
      (_) async => [];

  @override
  VocabularyQuizHistoryRepository? createVocabularyQuizHistoryRepository() {
    creations++;
    final ready = harness.runtime.readyRuntime;
    if (ready == null) return null;
    return VocabularyQuizHistoryRepository(
      auth: harness.access,
      store: _ReadStore((owner) {
        reads++;
        return response(owner);
      }),
      isReady: () => identical(harness.runtime.readyRuntime, ready),
      operations: operations,
    );
  }
}

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  Harness? harness,
  _Source? source,
}) async {
  final container = ProviderContainer(
    overrides: [
      if (harness != null)
        accountRuntimeProvider.overrideWithValue(harness.runtime),
      if (source != null) quizHistorySourceProvider.overrideWithValue(source),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await source?.operations.revokeAndDrain();
    await harness?.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const NihongoDailyApp(),
    ),
  );
  harness?.access.change(fixture.owner);
  container.read(routerProvider).go('/quiz/history');
  await tester.pumpAndSettle();
  return container;
}

Future<void> _load(WidgetTester tester) async {
  final button = find.byKey(const Key('quiz-history-load'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

Future<void> _filterHistory(WidgetTester tester, String label) async {
  final selector = find.byKey(const Key('quiz-history-level'));
  await tester.ensureVisible(selector);
  await tester.pumpAndSettle();
  await tester.tap(selector);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _pageHistory(WidgetTester tester, String direction) async {
  final button = find.byKey(Key('quiz-history-$direction'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  expect(button.hitTestable(), findsOneWidget);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _errorsHistory(WidgetTester tester) async {
  final toggle = find.byKey(const Key('quiz-history-errors-only'));
  await tester.ensureVisible(toggle);
  await tester.pumpAndSettle();
  expect(toggle.hitTestable(), findsOneWidget);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

List<String> _shownHistory(WidgetTester tester) => tester
    .widgetList<ListTile>(find.byType(ListTile))
    .map((tile) => tile.key)
    .whereType<ValueKey<String>>()
    .map((key) => key.value)
    .where((key) => key.startsWith('quiz-history-'))
    .toList();

void main() {
  testWidgets('errors filter reuses snapshot and resets pages', (tester) async {
    final h = Harness();
    final source = _Source(h)
      ..response = (owner) async => [
        for (var i = 1; i <= 41; i++)
          OwnedVocabularyQuizAttempt(owner, quizReport(i, correct: i.isEven)),
      ];
    await _mount(tester, harness: h, source: source);
    await _load(tester);
    await tester.pumpAndSettle();
    await _pageHistory(tester, 'older');
    final older = find.byKey(const Key('quiz-history-older'));
    final stale = tester.widget<OutlinedButton>(older).onPressed!;
    await _errorsHistory(tester);
    expect(find.text('21 bộ đã lưu'), findsOneWidget);
    expect(find.text('Câu đúng theo bài gốc: 0 / 21'), findsOneWidget);
    expect(_shownHistory(tester), [
      for (var i = 41; i >= 3; i -= 2) 'quiz-history-${quizReport(i).eventId}',
    ]);
    stale();
    await tester.pumpAndSettle();
    expect(_shownHistory(tester).length, 20);
    await _pageHistory(tester, 'older');
    expect(_shownHistory(tester).length, 1);
    await _errorsHistory(tester);
    expect(find.text('41 bộ đã lưu'), findsOneWidget);
    expect(find.text('Câu đúng theo bài gốc: 20 / 41'), findsOneWidget);
    expect(_shownHistory(tester).length, 20);
    expect(source.reads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('errors filter empty reload and owner reset', (tester) async {
    final h = Harness();
    final source = _Source(h)
      ..response = (owner) async => [
        OwnedVocabularyQuizAttempt(owner, quizReport(1, correct: true)),
      ];
    await _mount(tester, harness: h, source: source);
    await _errorsHistory(tester);
    expect(source.reads, 0);
    await _load(tester);
    await tester.pumpAndSettle();
    expect(find.text('0 bộ đã lưu'), findsOneWidget);
    expect(find.text('Câu đúng theo bài gốc: 0 / 0'), findsOneWidget);
    expect(_shownHistory(tester), isEmpty);
    expect(find.textContaining('Không có bộ quiz có câu sai'), findsOneWidget);
    await _load(tester);
    await tester.pumpAndSettle();
    expect(find.text('0 bộ đã lưu'), findsOneWidget);
    expect(source.reads, 2);
    await h.runtime.signOut();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quiz-history-errors-only')), findsNothing);
    h.access.change(fixture.other);
    await tester.pumpAndSettle();
    final toggle = tester.widget<CheckboxListTile>(
      find.byKey(const Key('quiz-history-errors-only')),
    );
    expect(toggle.value, isFalse);
    await _load(tester);
    await tester.pumpAndSettle();
    expect(find.text('1 bộ đã lưu'), findsOneWidget);
    expect(source.reads, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history pages bound newest-first rows and preserve totals', (
    tester,
  ) async {
    final h = Harness();
    final attempts = [
      for (var i = 1; i <= 41; i++) quizReport(i, correct: i.isEven),
    ];
    final source = _Source(h)
      ..response = (owner) async => [
        for (final attempt in attempts.reversed)
          OwnedVocabularyQuizAttempt(owner, attempt),
        OwnedVocabularyQuizAttempt(owner, attempts.first),
      ];
    await _mount(tester, harness: h, source: source);
    await _load(tester);
    await tester.pumpAndSettle();
    List<String> keys(int first, int count) => [
      for (final attempt in attempts.reversed.skip(first).take(count))
        'quiz-history-${attempt.eventId}',
    ];
    expect(_shownHistory(tester), keys(0, 20));
    expect(find.text('41 bộ đã lưu'), findsOneWidget);
    expect(find.text('Câu đúng theo bài gốc: 20 / 41'), findsOneWidget);
    expect(find.text('Hiển thị 1–20 / 41 bộ (mới nhất trước)'), findsOneWidget);
    final newer = find.byKey(const Key('quiz-history-newer'));
    final older = find.byKey(const Key('quiz-history-older'));
    expect(tester.widget<OutlinedButton>(newer).onPressed, isNull);
    await _pageHistory(tester, 'older');
    expect(_shownHistory(tester), keys(20, 20));
    expect(
      find.text('Hiển thị 21–40 / 41 bộ (mới nhất trước)'),
      findsOneWidget,
    );
    await _pageHistory(tester, 'older');
    expect(_shownHistory(tester), keys(40, 1));
    expect(
      find.text('Hiển thị 41–41 / 41 bộ (mới nhất trước)'),
      findsOneWidget,
    );
    expect(tester.widget<OutlinedButton>(older).onPressed, isNull);
    await _pageHistory(tester, 'newer');
    expect(_shownHistory(tester), keys(20, 20));
    await _pageHistory(tester, 'newer');
    expect(_shownHistory(tester), keys(0, 20));
    expect(find.text('Câu đúng theo bài gốc: 20 / 41'), findsOneWidget);
    expect(source.reads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history pages reset on filter and explicit reload failure', (
    tester,
  ) async {
    final h = Harness();
    final attempts = [
      for (var i = 1; i <= 42; i++)
        VocabularyQuizAttempt.fromJson({
          ...quizReport(i).toJson(),
          'level': i.isEven ? 'N4' : 'N5',
        }),
    ];
    final source = _Source(h)
      ..response = (owner) async => [
        for (final attempt in attempts)
          OwnedVocabularyQuizAttempt(owner, attempt),
      ];
    await _mount(tester, harness: h, source: source);
    await _load(tester);
    await tester.pumpAndSettle();
    await _pageHistory(tester, 'older');
    await _filterHistory(tester, 'N4');
    expect(find.text('21 bộ đã lưu'), findsOneWidget);
    expect(_shownHistory(tester).length, 20);
    expect(find.text('Hiển thị 1–20 / 21 bộ (mới nhất trước)'), findsOneWidget);
    final older = find.byKey(const Key('quiz-history-older'));
    final beforeReload = tester.widget<OutlinedButton>(older).onPressed!;
    await _pageHistory(tester, 'older');
    expect(_shownHistory(tester), ['quiz-history-${attempts[1].eventId}']);
    expect(source.reads, 1);
    final held = Completer<List<OwnedVocabularyQuizAttempt>>();
    addTearDown(() {
      if (!held.isCompleted) held.complete([]);
    });
    source.response = (_) => held.future;
    await _load(tester);
    expect(find.byKey(const Key('quiz-history-range')), findsNothing);
    expect(find.byKey(const Key('quiz-history-older')), findsNothing);
    expect(_shownHistory(tester), isEmpty);
    beforeReload();
    held.completeError(StateError('PRIVATE PAGE STORAGE PATH'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quiz-history-error')), findsOneWidget);
    expect(find.textContaining('PRIVATE'), findsNothing);
    expect(find.byKey(const Key('quiz-history-summary')), findsNothing);
    expect(find.byKey(const Key('quiz-history-range')), findsNothing);
    source.response = (owner) async => [
      for (final attempt in attempts)
        OwnedVocabularyQuizAttempt(owner, attempt),
    ];
    await _load(tester);
    await tester.pumpAndSettle();
    beforeReload();
    await tester.pumpAndSettle();
    expect(find.text('N4'), findsOneWidget);
    expect(find.text('Hiển thị 1–20 / 21 bộ (mới nhất trước)'), findsOneWidget);
    await _filterHistory(tester, 'N5');
    expect(_shownHistory(tester).first, 'quiz-history-${attempts[40].eventId}');
    expect(source.reads, 3);
    source.response = (owner) async => [
      for (final attempt in attempts.take(40))
        OwnedVocabularyQuizAttempt(owner, attempt),
    ];
    await _load(tester);
    await tester.pumpAndSettle();
    expect(_shownHistory(tester).length, 20);
    expect(find.text('20 bộ đã lưu'), findsOneWidget);
    expect(older, findsNothing);
    expect(find.byKey(const Key('quiz-history-newer')), findsNothing);
    expect(source.reads, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retired page callbacks cannot skip or revive an old view', (
    tester,
  ) async {
    final h = Harness();
    final source = _Source(h)
      ..response = (owner) async => [
        for (var i = 1; i <= 41; i++)
          OwnedVocabularyQuizAttempt(owner, quizReport(i)),
      ];
    final container = await _mount(tester, harness: h, source: source);
    await _load(tester);
    await tester.pumpAndSettle();
    final older = find.byKey(const Key('quiz-history-older'));
    final first = tester.widget<OutlinedButton>(older).onPressed!;
    first();
    first(); // A duplicate callback before the next frame cannot skip page2.
    await tester.pumpAndSettle();
    expect(
      find.text('Hiển thị 21–40 / 41 bộ (mới nhất trước)'),
      findsOneWidget,
    );
    await _pageHistory(tester, 'newer');
    first(); // Same page offset after newer/older ABA is a different revision.
    await tester.pumpAndSettle();
    expect(find.text('Hiển thị 1–20 / 41 bộ (mới nhất trước)'), findsOneWidget);
    final beforeFilter = tester.widget<OutlinedButton>(older).onPressed!;
    await _filterHistory(tester, 'N4');
    expect(_shownHistory(tester), isEmpty);
    expect(find.byKey(const Key('quiz-history-range')), findsNothing);
    await _filterHistory(tester, 'Tất cả cấp độ');
    beforeFilter();
    await tester.pumpAndSettle();
    expect(find.text('Hiển thị 1–20 / 41 bộ (mới nhất trước)'), findsOneWidget);
    final retired = tester.widget<OutlinedButton>(older).onPressed!;
    container.invalidate(quizHistoryRepositoryProvider);
    container.read(quizHistoryRepositoryProvider);
    retired(); // Captured capability is replaced before the frame.
    await tester.pumpAndSettle();
    expect(_shownHistory(tester), isEmpty);
    expect(source.reads, 1);
    await _load(tester);
    await tester.pumpAndSettle();
    final beforeLogout = tester.widget<OutlinedButton>(older).onPressed!;
    await _pageHistory(tester, 'older');
    await h.runtime.signOut();
    await tester.pumpAndSettle();
    expect(_shownHistory(tester), isEmpty);
    expect(older, findsNothing);
    h.access.change(fixture.other);
    await tester.pumpAndSettle();
    beforeLogout();
    await tester.pumpAndSettle();
    expect(_shownHistory(tester), isEmpty);
    await _load(tester);
    await tester.pumpAndSettle();
    beforeLogout();
    await tester.pumpAndSettle();
    expect(find.text('Hiển thị 1–20 / 41 bộ (mới nhất trước)'), findsOneWidget);
    final disposed = tester.widget<OutlinedButton>(older).onPressed!;
    container.read(routerProvider).go('/quiz');
    await tester.pumpAndSettle();
    disposed();
    await tester.pumpAndSettle();
    expect(source.reads, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history paging controls work at320px and200percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = Harness();
    final source = _Source(h)
      ..response = (owner) async => [
        for (var i = 1; i <= 21; i++)
          OwnedVocabularyQuizAttempt(owner, quizReport(i)),
      ];
    await _mount(tester, harness: h, source: source);
    await _load(tester);
    await tester.pumpAndSettle();
    expect(_shownHistory(tester).length, 20);
    await _pageHistory(tester, 'older');
    expect(_shownHistory(tester), ['quiz-history-${quizReport(1).eventId}']);
    expect(
      find.text('Hiển thị 21–21 / 21 bộ (mới nhất trước)'),
      findsOneWidget,
    );
    await _pageHistory(tester, 'newer');
    expect(_shownHistory(tester).length, 20);
    expect(source.reads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history level filters rows and totals without another read', (
    tester,
  ) async {
    final h = Harness();
    final n5 = quizReport(1);
    final n4 = VocabularyQuizAttempt.fromJson({
      ...quizReport(2, correct: true).toJson(),
      'level': 'N4',
    });
    final source = _Source(h)
      ..response = (owner) async => [
        OwnedVocabularyQuizAttempt(owner, n5),
        OwnedVocabularyQuizAttempt(owner, n4),
        OwnedVocabularyQuizAttempt(owner, n5),
      ];
    await _mount(tester, harness: h, source: source);
    await _load(tester);
    await tester.pumpAndSettle();
    expect(find.text('2 bộ đã lưu'), findsOneWidget);
    expect(find.text('Câu đúng theo bài gốc: 1 / 2'), findsOneWidget);
    await _filterHistory(tester, 'N4');
    expect(find.text('1 bộ đã lưu'), findsOneWidget);
    expect(find.text('Câu đúng theo bài gốc: 1 / 1'), findsOneWidget);
    expect(find.byKey(ValueKey('quiz-history-${n4.eventId}')), findsOneWidget);
    expect(find.byKey(ValueKey('quiz-history-${n5.eventId}')), findsNothing);
    await _filterHistory(tester, 'N5');
    expect(find.text('Câu đúng theo bài gốc: 0 / 1'), findsOneWidget);
    expect(find.byKey(ValueKey('quiz-history-${n5.eventId}')), findsOneWidget);
    expect(find.byKey(ValueKey('quiz-history-${n4.eventId}')), findsNothing);
    await _filterHistory(tester, 'Tất cả cấp độ');
    expect(find.text('2 bộ đã lưu'), findsOneWidget);
    expect(find.text('Câu đúng theo bài gốc: 1 / 2'), findsOneWidget);
    expect(source.reads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history filter is local across empty reload and owner reset', (
    tester,
  ) async {
    final h = Harness();
    final source = _Source(h)
      ..response = (owner) async => [
        OwnedVocabularyQuizAttempt(owner, quizReport(1)),
      ];
    await _mount(tester, harness: h, source: source);
    await _filterHistory(tester, 'N4');
    expect(source.reads, 0);
    expect(find.byKey(const Key('quiz-history-summary')), findsNothing);
    await _load(tester);
    await tester.pumpAndSettle();
    expect(find.text('0 bộ đã lưu'), findsOneWidget);
    expect(find.text('Câu đúng theo bài gốc: 0 / 0'), findsOneWidget);
    expect(
      find.text('Chưa có kết quả quiz đã lưu cho cấp độ này.'),
      findsOneWidget,
    );
    final n4 = VocabularyQuizAttempt.fromJson({
      ...quizReport(2, correct: true).toJson(),
      'level': 'N4',
    });
    source.response = (owner) async => [OwnedVocabularyQuizAttempt(owner, n4)];
    await _load(tester);
    await tester.pumpAndSettle();
    expect(find.text('1 bộ đã lưu'), findsOneWidget);
    expect(find.text('Câu đúng theo bài gốc: 1 / 1'), findsOneWidget);
    expect(source.reads, 2);
    await h.runtime.signOut();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quiz-history-level')), findsNothing);
    expect(find.byKey(const Key('quiz-history-summary')), findsNothing);
    h.access.change(fixture.other);
    await tester.pumpAndSettle();
    expect(find.text('Tất cả cấp độ'), findsOneWidget);
    expect(find.byKey(const Key('quiz-history-summary')), findsNothing);
    await _load(tester);
    await tester.pumpAndSettle();
    expect(find.text('1 bộ đã lưu'), findsOneWidget);
    expect(source.reads, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history summary follows loaded snapshot', (tester) async {
    final h = Harness();
    final source = _Source(h)
      ..response = (owner) async => [
        OwnedVocabularyQuizAttempt(owner, quizReport(1, correct: true)),
        OwnedVocabularyQuizAttempt(owner, quizReport(2)),
        OwnedVocabularyQuizAttempt(owner, quizReport(1, correct: true)),
      ];
    await _mount(tester, harness: h, source: source);
    expect(find.byKey(const Key('quiz-history-summary')), findsNothing);
    await _load(tester);
    await tester.pumpAndSettle();
    expect(find.text('2 bộ đã lưu'), findsOneWidget);
    expect(find.text('Câu đúng theo bài gốc: 1 / 2'), findsOneWidget);
    expect(source.reads, 1);
    source.response = (_) async => throw StateError('PRIVATE SUMMARY');
    await _load(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quiz-history-summary')), findsNothing);
    expect(find.text('Câu đúng theo bài gốc: 1 / 2'), findsNothing);
    expect(find.byKey(const Key('quiz-history-error')), findsOneWidget);
    expect(find.textContaining('PRIVATE'), findsNothing);
    source.response = (_) async => [];
    await _load(tester);
    await tester.pumpAndSettle();
    expect(find.text('0 bộ đã lưu'), findsOneWidget);
    expect(find.text('Câu đúng theo bài gốc: 0 / 0'), findsOneWidget);
    expect(source.reads, 3);
    await h.runtime.signOut();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quiz-history-summary')), findsNothing);
    expect(source.reads, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retired history callback cannot read', (tester) async {
    final h = Harness();
    final source = _Source(h);
    final container = await _mount(tester, harness: h, source: source);
    final button = find.byKey(const Key('quiz-history-load'));
    final stale = tester.widget<OutlinedButton>(button).onPressed!;
    final old = container.read(quizHistoryRepositoryProvider);
    container.invalidate(quizHistoryRepositoryProvider);
    expect(container.read(quizHistoryRepositoryProvider), isNot(same(old)));
    stale(); // No replacement frame yet; old repository itself is still ready.
    await tester.pumpAndSettle();
    expect(source.reads, 0);
    expect(find.byKey(const Key('quiz-history-error')), findsNothing);
    await _load(tester);
    await tester.pumpAndSettle();
    expect(source.reads, 1);
    expect(find.textContaining('Chưa có kết quả quiz'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposed history load callback stays inert', (tester) async {
    final h = Harness();
    final source = _Source(h);
    final container = await _mount(tester, harness: h, source: source);
    final button = find.byKey(const Key('quiz-history-load'));
    final stale = tester.widget<OutlinedButton>(button).onPressed!;
    // Disposal does not depend on the quiz route's async asset loading.
    container.read(routerProvider).go('/settings');
    await tester.pumpAndSettle();
    expect(button, findsNothing);
    stale();
    await tester.pumpAndSettle();
    expect(source.reads, 0);
    expect(tester.takeException(), isNull);
    container.read(routerProvider).go('/quiz/history');
    await tester.pumpAndSettle();
    await _load(tester);
    await tester.pumpAndSettle();
    expect(source.reads, 1);
    expect(find.textContaining('Chưa có kết quả quiz'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview history never invents a source', (tester) async {
    await _mount(tester);
    expect(find.text('Mở tài khoản'), findsOneWidget);
    expect(find.byKey(const Key('quiz-history-load')), findsNothing);
    await tester.tap(find.text('Mở tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập hiện chưa khả dụng.'), findsOneWidget);
  });

  testWidgets('profile barrier gates history and load is explicit', (
    tester,
  ) async {
    final h = Harness()..delayed = Completer();
    final source = _Source(h);
    final container = await _mount(tester, harness: h, source: source);
    expect(container.read(quizHistoryRepositoryProvider), isNull);
    expect(source.creations, 0);
    h.delayed!.complete(fixture.ownProfile());
    await tester.pumpAndSettle();
    expect(source.reads, 0);
    await _load(tester);
    await tester.pumpAndSettle();
    expect(source.reads, 1);
    expect(find.textContaining('Chưa có kết quả quiz'), findsOneWidget);
  });

  testWidgets('held read disables duplicate loading and shows score', (
    tester,
  ) async {
    final h = Harness();
    final wait = Completer<List<OwnedVocabularyQuizAttempt>>();
    final source = _Source(h)..response = (_) => wait.future;
    await _mount(tester, harness: h, source: source);
    await _load(tester);
    expect(find.text('Đang tải lịch sử…'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('quiz-history-load')),
    );
    expect(button.onPressed, isNull);
    expect(source.reads, 1);
    wait.complete([
      OwnedVocabularyQuizAttempt(fixture.owner, quizReport(1, correct: true)),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('N5 · 1 / 1'), findsOneWidget);
    expect(find.textContaining('2026-10-20T00:01:00.000Z'), findsOneWidget);
    expect(find.textContaining(fixture.owner), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reload clears prior results and redacts errors', (tester) async {
    final h = Harness();
    final source = _Source(h)
      ..response = (owner) async => [
        OwnedVocabularyQuizAttempt(owner, quizReport(1)),
      ];
    await _mount(tester, harness: h, source: source);
    await _load(tester);
    await tester.pumpAndSettle();
    expect(find.text('N5 · 0 / 1'), findsOneWidget);
    source.response = (_) async => throw StateError('PRIVATE TOKEN PATH');
    await _load(tester);
    await tester.pumpAndSettle();
    expect(find.text('N5 · 0 / 1'), findsNothing);
    expect(find.byKey(const Key('quiz-history-error')), findsOneWidget);
    expect(find.textContaining('PRIVATE'), findsNothing);
    await tester.pump(const Duration(seconds: 30));
    expect(source.reads, 2);
    source.response = (_) async => [];
    await _load(tester);
    await tester.pumpAndSettle();
    expect(source.reads, 3);
    expect(find.byKey(const Key('quiz-history-error')), findsNothing);
  });

  for (final lateError in [false, true]) {
    testWidgets('account replacement hides late history error=$lateError', (
      tester,
    ) async {
      final h = Harness();
      final wait = Completer<List<OwnedVocabularyQuizAttempt>>();
      final source = _Source(h)..response = (_) => wait.future;
      final container = await _mount(tester, harness: h, source: source);
      await _load(tester);
      final old = container.read(quizHistoryRepositoryProvider);
      await h.runtime.signOut();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quiz-history-load')), findsNothing);
      h.access.change(lateError ? fixture.other : fixture.owner);
      await tester.pumpAndSettle();
      expect(
        identical(container.read(quizHistoryRepositoryProvider), old),
        isFalse,
      );
      if (lateError) {
        wait.completeError(StateError('PRIVATE OLD OWNER'));
      } else {
        wait.complete([
          OwnedVocabularyQuizAttempt(
            fixture.owner,
            quizReport(1, correct: true),
          ),
        ]);
      }
      await tester.pumpAndSettle();
      expect(find.text('N5 · 1 / 1'), findsNothing);
      expect(find.byKey(const Key('quiz-history-error')), findsNothing);
      expect(source.reads, 1);
      source.response = (_) async => [];
      await _load(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('Chưa có kết quả quiz'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('owned host publishes history and revokes it during exit', (
    tester,
  ) async {
    final h = Harness();
    final source = _Source(h)
      ..response = (owner) async => [
        OwnedVocabularyQuizAttempt(owner, quizReport(1)),
      ];
    final owner = _Owner(h.runtime, source);
    final controller = AccountStartupController(() async => owner);
    addTearDown(() async {
      if (!owner.starting.isCompleted) owner.starting.complete();
      if (!(owner.closing?.isCompleted ?? true)) owner.closing!.complete();
      await tester.pumpWidget(const SizedBox());
      await controller.close();
      await source.operations.revokeAndDrain();
      await h.close();
    });
    expect(controller.quizHistorySource, isNull);
    await tester.pumpWidget(AccountStartupApp(controller: controller));
    await tester.pump();
    expect(controller.quizHistorySource, isNull);
    owner.starting.complete();
    await tester.pumpAndSettle();
    expect(identical(controller.quizHistorySource, owner), isTrue);
    h.access.change(fixture.owner);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NihongoDailyApp)),
    );
    container.read(routerProvider).go('/quiz/history');
    await tester.pumpAndSettle();
    await _load(tester);
    await tester.pumpAndSettle();
    expect(find.text('N5 · 0 / 1'), findsOneWidget);
    owner.closing = Completer<void>();
    final exit = tester.binding.handleRequestAppExit();
    await tester.pump();
    await tester.pump();
    expect(controller.quizHistorySource, isNull);
    expect(find.text('N5 · 0 / 1', skipOffstage: false), findsNothing);
    owner.closing!.complete();
    expect(await exit, AppExitResponse.exit);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history at 320px and large text remains readable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = Harness();
    final source = _Source(h)
      ..response = (owner) async => [
        OwnedVocabularyQuizAttempt(owner, quizReport(1)),
      ];
    await _mount(tester, harness: h, source: source);
    await _load(tester);
    await tester.pumpAndSettle();
    expect(find.text('N5 · 0 / 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
