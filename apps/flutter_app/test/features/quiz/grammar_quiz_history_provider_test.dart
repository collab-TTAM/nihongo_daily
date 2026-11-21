// TEST ONLY account/profile and local memory ports; no hosted learner proof.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/features/auth/application/account_provider.dart';
import 'package:nihongo_daily/features/auth/application/account_startup_controller.dart';
import 'package:nihongo_daily/features/auth/data/own_profile_repository.dart';
import 'package:nihongo_daily/features/auth/presentation/account_startup_app.dart';
import 'package:nihongo_daily/features/quiz/application/grammar_quiz_history_provider.dart';
import 'package:nihongo_daily/features/quiz/application/quiz_history_provider.dart';
import 'package:nihongo_daily/features/quiz/data/grammar_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/data/grammar_quiz_history_repository.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz_attempt.dart';
import '../srs/account_fixtures.dart' as fixture;
import '../srs/account_widget_test.dart' show Harness;

final class _Store implements GrammarQuizAttemptStore {
  int reads = 0;
  @override
  Future<List<OwnedGrammarQuizAttempt>> list(String ownerId) async {
    reads++;
    return [];
  }

  @override
  Future<OwnedGrammarQuizAttempt> append(
    String ownerId,
    GrammarQuizAttempt attempt,
  ) => throw StateError('Provider test must not save');
}

final class _Source implements GrammarQuizHistorySource {
  _Source(this.harness);
  final Harness harness;
  final store = _Store();
  final operations = GrammarQuizOperationDrain();
  int creations = 0;
  bool fail = false;
  bool closed = false;
  @override
  GrammarQuizHistoryRepository? createGrammarQuizHistoryRepository() {
    creations++;
    if (fail) throw StateError('PRIVATE TOKEN PATH');
    final ready = harness.runtime.readyRuntime;
    if (closed || ready == null) return null;
    return GrammarQuizHistoryRepository(
      auth: ready.auth,
      store: store,
      operations: operations,
      isReady: () => !closed && identical(harness.runtime.readyRuntime, ready),
    );
  }
}

final class _Owner<T>
    implements AccountStartupRuntime<T>, GrammarQuizHistorySource {
  _Owner(this.account, this.source);
  @override
  final T account;
  final _Source source;
  final starting = Completer<void>();
  @override
  bool get canOfferLogin => false;
  @override
  Future<void> start() => starting.future;
  @override
  Future<void> close() async {
    source.closed = true;
    await source.operations.revokeAndDrain();
  }

  @override
  GrammarQuizHistoryRepository? createGrammarQuizHistoryRepository() =>
      source.createGrammarQuizHistoryRepository();
}

void main() {
  late Harness h;
  late _Source source;
  late ProviderContainer container;
  final changed = throwsA(isA<GrammarQuizSessionChanged>());

  Future<void> mount(
    WidgetTester tester, {
    bool withAccount = true,
    bool withSource = true,
  }) async {
    h = Harness();
    source = _Source(h);
    container = ProviderContainer(
      overrides: [
        if (withAccount) accountRuntimeProvider.overrideWithValue(h.runtime),
        if (withSource)
          grammarQuizHistorySourceProvider.overrideWithValue(source),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      source.closed = true;
      await source.operations.revokeAndDrain();
      await h.close();
    });
    // Attach this container to Flutter's vsync rather than the standalone
    // Riverpod Timer.run scheduler inside testWidgets' FakeAsync zone.
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const SizedBox()),
    );
  }

  testWidgets(
    'grammar history provider default is absent and performs no I O',
    (tester) async {
      await mount(tester, withAccount: false, withSource: false);
      expect(container.read(grammarQuizHistorySourceProvider), isNull);
      expect(container.read(grammarQuizHistoryRepositoryProvider), isNull);
      expect(source.creations, 0);
      expect(source.store.reads, 0);
    },
  );

  testWidgets('grammar history source alone cannot bypass missing account', (
    tester,
  ) async {
    await mount(tester, withAccount: false);
    h.access.change(fixture.owner);
    await tester.pump();
    expect(container.read(grammarQuizHistoryRepositoryProvider), isNull);
    expect(source.creations, 0);
  });

  testWidgets(
    'grammar history ready account without source remains unavailable',
    (tester) async {
      await mount(tester, withSource: false);
      h.access.change(fixture.owner);
      await tester.pump();
      expect(h.runtime.readyRuntime, isNotNull);
      expect(container.read(grammarQuizHistoryRepositoryProvider), isNull);
      expect(source.creations, 0);
    },
  );

  testWidgets(
    'grammar history waits own profile then acquires without storage',
    (tester) async {
      await mount(tester);
      h.delayed = Completer<OwnProfile>();
      h.access.change(fixture.owner);
      await tester.pump();
      expect(container.read(grammarQuizHistoryRepositoryProvider), isNull);
      expect(source.creations, 0);
      h.delayed!.complete(fixture.ownProfile());
      await tester.pump();
      final repository = container.read(grammarQuizHistoryRepositoryProvider)!;
      expect(source.creations, 1);
      expect(source.store.reads, 0);
      expect(
        container.read(grammarQuizHistoryRepositoryProvider),
        same(repository),
      );
      expect(container.read(quizHistorySourceProvider), isNull);
      expect(container.read(quizHistoryRepositoryProvider), isNull);
      expect(await repository.load(), isEmpty);
      expect(source.store.reads, 1);
    },
  );

  testWidgets('grammar history failed profile and failed source remain safe', (
    tester,
  ) async {
    await mount(tester);
    h.failProfile = true;
    h.access.change(fixture.owner);
    await tester.pump();
    expect(container.read(grammarQuizHistoryRepositoryProvider), isNull);
    expect(source.creations, 0);
    h.failProfile = false;
    source.fail = true;
    await h.runtime.retryProfile();
    await tester.pump();
    expect(container.read(grammarQuizHistoryRepositoryProvider), isNull);
    expect(source.creations, 1);
    expect(source.store.reads, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grammar history captured provider cannot revive through A B A', (
    tester,
  ) async {
    await mount(tester);
    h.access.change(fixture.owner);
    await tester.pump();
    final old = container.read(grammarQuizHistoryRepositoryProvider)!;
    await h.runtime.signOut();
    expect(container.read(grammarQuizHistoryRepositoryProvider), isNull);
    await expectLater(old.load(), changed);
    h.access.change(fixture.other);
    await tester.pump();
    final other = container.read(grammarQuizHistoryRepositoryProvider)!;
    expect(other, isNot(same(old)));
    h.access.change(fixture.owner);
    await tester.pump();
    await expectLater(other.load(), changed);
    await expectLater(old.load(), changed);
    expect(source.store.reads, 0);
    expect(
      await container.read(grammarQuizHistoryRepositoryProvider)!.load(),
      isEmpty,
    );
    expect(source.store.reads, 1);
  });

  testWidgets(
    'configured startup forwards grammar source only after start and fences close',
    (tester) async {
      final harness = Harness();
      final supplied = _Source(harness);
      final owner = _Owner(harness.runtime, supplied);
      final controller = AccountStartupController(() async => owner);
      await tester.pumpWidget(AccountStartupApp(controller: controller));
      await tester.pump();
      expect(find.byType(NihongoDailyApp), findsNothing);
      expect(supplied.creations, 0);
      owner.starting.complete();
      await tester.pumpAndSettle();
      final scoped = ProviderScope.containerOf(
        tester.element(find.byType(NihongoDailyApp)),
      );
      expect(scoped.read(grammarQuizHistorySourceProvider), same(owner));
      expect(scoped.read(grammarQuizHistoryRepositoryProvider), isNull);
      harness.access.change(fixture.owner);
      await tester.pumpAndSettle();
      final captured = scoped.read(grammarQuizHistoryRepositoryProvider)!;
      expect(supplied.store.reads, 0);
      final closing = controller.close();
      expect(controller.grammarQuizHistorySource, isNull);
      await closing;
      await expectLater(captured.load(), changed);
      await tester.pumpAndSettle();
      expect(find.byType(NihongoDailyApp), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await harness.close();
      expect(tester.takeException(), isNull);
    },
  );
}
