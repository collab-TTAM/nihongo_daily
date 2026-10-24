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

void main() {
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
