import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/auth/application/account_provider.dart';
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/application/account_startup_controller.dart';
import 'package:nihongo_daily/features/auth/application/account_session_refresh.dart';
import 'package:nihongo_daily/features/auth/data/own_profile_repository.dart';
import 'package:nihongo_daily/features/auth/presentation/account_startup_app.dart';
import 'package:nihongo_daily/features/srs/application/srs_study_runtime.dart';
import 'account_fixtures.dart' as fixture;
import 'account_widget_test.dart' show Harness;

// TEST ONLY action/Auth/profile ports; no token, OS vault or hosted identity.
final class FixtureRefreshAction implements AccountSessionRefreshAction {
  FixtureRefreshAction(this.call);
  final Future<void> Function() call;
  int calls = 0;
  @override
  Future<void> refresh() {
    calls++;
    return call();
  }
}

final class FixtureRefreshOwner
    implements
        AccountStartupRuntime<AccountController<SrsStudyRuntime>>,
        AccountSessionRefreshAction {
  FixtureRefreshOwner(this.harness, this.action);
  final Harness harness;
  final FixtureRefreshAction action;
  Completer<void>? startWait;
  @override
  AccountController<SrsStudyRuntime> get account => harness.runtime;
  @override
  bool get canOfferLogin => false;
  @override
  Future<void> start() async {
    await startWait?.future;
    harness.access.change(fixture.owner);
    await fixture.flush();
  }

  @override
  Future<void> refresh() => action.refresh();
  @override
  Future<void> close() async => harness.runtime.dispose();
}

Future<void> mountRefresh(
  WidgetTester tester,
  Harness h,
  AccountSessionRefreshAction? action,
) async {
  final container = ProviderContainer(
    overrides: [
      accountRuntimeProvider.overrideWithValue(h.runtime),
      accountSessionRefreshActionProvider.overrideWithValue(action),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await h.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const NihongoDailyApp(),
    ),
  );
  container.read(routerProvider).go('/auth');
  h.access.change(fixture.owner);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'startup refresh action is published only for the active owner',
    () async {
      final h = Harness();
      final action = FixtureRefreshAction(() async {});
      final owner = FixtureRefreshOwner(h, action)..startWait = Completer();
      final controller = AccountStartupController(() async => owner);
      final opening = controller.start();
      await fixture.flush();
      expect(controller.refreshAction, isNull);
      owner.startWait!.complete();
      await opening;
      expect(identical(controller.refreshAction, owner), isTrue);
      await controller.refreshAction!.refresh();
      expect(action.calls, 1);
      final closing = controller.close();
      expect(controller.refreshAction, isNull);
      await closing;
      await h.close();
    },
  );
  testWidgets('owned startup host supplies its exact refresh action', (
    tester,
  ) async {
    final h = Harness();
    final action = FixtureRefreshAction(() async {});
    final owner = FixtureRefreshOwner(h, action);
    final controller = AccountStartupController(() async => owner);
    await tester.pumpWidget(AccountStartupApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-refresh')), findsOneWidget);
    await tester.tap(find.byKey(const Key('account-refresh')));
    await tester.pumpAndSettle();
    expect(action.calls, 1);
    await tester.pumpWidget(const SizedBox());
    await controller.close();
    await h.close();
    expect(tester.takeException(), isNull);
  });
  testWidgets('refresh is absent without an explicitly owned action', (
    tester,
  ) async {
    final h = Harness();
    await mountRefresh(tester, h, null);
    expect(h.runtime.readyRuntime, isNotNull);
    expect(find.byKey(const Key('account-refresh')), findsNothing);
  });
  testWidgets(
    'manual refresh dispatches once and waits for profile readiness',
    (tester) async {
      final h = Harness();
      final rotation = Completer<void>();
      final profile = Completer<OwnProfile>();
      final action = FixtureRefreshAction(() async {
        final captured = h.access.currentSession;
        h.access.currentSession = null;
        h.access.events.add(null);
        await rotation.future;
        h.access.currentSession = captured;
        h.access.events.add(null);
      });
      await mountRefresh(tester, h, action);
      h.delayed = profile;
      final button = tester.widget<OutlinedButton>(
        find.byKey(const Key('account-refresh')),
      );
      button.onPressed!();
      button.onPressed!();
      await tester.pump();
      expect(action.calls, 1);
      expect(h.runtime.readyRuntime, isNull);
      expect(find.byKey(const Key('account-profile-name')), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Đang xác nhận phiên đăng nhập…'), findsOneWidget);
      expect(find.text('Đăng xuất'), findsOneWidget);
      rotation.complete();
      await tester.pump();
      await tester.pump();
      expect(h.runtime.readyRuntime, isNull);
      expect(find.text('Đang chuẩn bị hồ sơ học tập…'), findsOneWidget);
      expect(find.byKey(const Key('account-refresh')), findsNothing);
      profile.complete(fixture.ownProfile());
      await tester.pumpAndSettle();
      expect(h.runtime.readyRuntime, isNotNull);
      expect(find.byKey(const Key('account-refresh')), findsOneWidget);
      expect(action.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('refresh failure is fixed and only explicit retry dispatches', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = Harness();
    var fail = true;
    final action = FixtureRefreshAction(() async {
      if (fail) throw StateError('PRIVATE TOKEN PATH');
    });
    await mountRefresh(tester, h, action);
    await tester.ensureVisible(find.byKey(const Key('account-refresh')));
    await tester.tap(find.byKey(const Key('account-refresh')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-refresh-error')), findsOneWidget);
    expect(find.textContaining('PRIVATE'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(action.calls, 1);
    fail = false;
    await tester.ensureVisible(find.byKey(const Key('account-refresh')));
    await tester.tap(find.byKey(const Key('account-refresh')));
    await tester.pumpAndSettle();
    expect(action.calls, 2);
    expect(find.byKey(const Key('account-refresh-error')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('logout during manual refresh rejects late error display', (
    tester,
  ) async {
    final h = Harness();
    final waiting = Completer<void>();
    final action = FixtureRefreshAction(() => waiting.future);
    await mountRefresh(tester, h, action);
    await tester.tap(find.byKey(const Key('account-refresh')));
    await tester.pump();
    await tester.tap(find.text('Đăng xuất'));
    await tester.pump();
    expect(h.runtime.readyRuntime, isNull);
    waiting.completeError(StateError('PRIVATE LATE TOKEN'));
    await tester.pumpAndSettle();
    expect(h.access.signOutCalls, 1);
    expect(find.byKey(const Key('account-refresh-error')), findsNothing);
    expect(find.byKey(const Key('account-email')), findsOneWidget);
    expect(find.byKey(const Key('account-refresh')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('account switch does not inherit an old refresh failure', (
    tester,
  ) async {
    final h = Harness();
    final waiting = Completer<void>();
    final action = FixtureRefreshAction(() => waiting.future);
    await mountRefresh(tester, h, action);
    await tester.tap(find.byKey(const Key('account-refresh')));
    h.access.change(fixture.other);
    await tester.pump();
    waiting.completeError(StateError('PRIVATE OLD OWNER'));
    await tester.pumpAndSettle();
    expect(h.runtime.state.profile!.id, fixture.other);
    expect(find.byKey(const Key('account-refresh-error')), findsNothing);
    expect(action.calls, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unmount drains late refresh display without setState error', (
    tester,
  ) async {
    final h = Harness();
    final waiting = Completer<void>();
    final action = FixtureRefreshAction(() => waiting.future);
    await mountRefresh(tester, h, action);
    await tester.tap(find.byKey(const Key('account-refresh')));
    await tester.pumpWidget(const SizedBox());
    waiting.completeError(StateError('PRIVATE DISPOSED'));
    await tester.pump();
    expect(action.calls, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('same-session restoration discards prior refresh feedback', (
    tester,
  ) async {
    final h = Harness();
    final waiting = Completer<void>();
    final action = FixtureRefreshAction(() => waiting.future);
    await mountRefresh(tester, h, action);
    final captured = h.access.currentSession;
    await tester.tap(find.byKey(const Key('account-refresh')));
    h.access.currentSession = null;
    h.access.events.add(null);
    h.access.currentSession = captured;
    h.access.events.add(null);
    await fixture.flush();
    expect(identical(h.runtime.readySession, captured), isTrue);
    waiting.completeError(StateError('PRIVATE PRIOR GENERATION'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-refresh-error')), findsNothing);
    expect(h.runtime.readyRuntime, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
