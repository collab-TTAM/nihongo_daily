import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/application/account_provider.dart';
import 'package:nihongo_daily/features/auth/data/own_profile_repository.dart';
import 'package:nihongo_daily/features/srs/application/srs_study_provider.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'account_fixtures.dart' as fixture;
import 'study_fixtures.dart' as study;

// TEST ONLY credential/Auth/profile/curriculum/RPC. No hosted learner proof.
final class Harness {
  Harness() {
    runtime = AccountController<SrsStudyRuntime>(
      access: access,
      ensureProfile: () {
        profiles++;
        if (failProfile) return Future.error(StateError('PRIVATE TOKEN SQL'));
        return delayed?.future ??
            Future.value(fixture.ownProfile(access.currentSession!.userId));
      },
      buildStudyRuntime: (auth, changes) => SrsStudyRuntime(
        auth: auth,
        reviews: RpcReviewRepository(auth: auth, transport: rpc),
        queue: queue,
        sessionChanges: changes,
      ),
    );
  }
  final access = fixture.FakeAccountAccess();
  final queue = study.FixtureStudyQueue();
  final rpc = study.FixtureStudyRpc();
  late final AccountController<SrsStudyRuntime> runtime;
  Completer<OwnProfile>? delayed;
  bool failProfile = false;
  int profiles = 0;
  Future<void> close() async {
    runtime.dispose();
    if (!access.events.isClosed) await access.events.close();
  }
}

Future<ProviderContainer> mount(
  WidgetTester tester, {
  Harness? h,
  Size size = const Size(1100, 900),
  double scale = 1,
}) async {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      if (h != null) accountRuntimeProvider.overrideWithValue(h.runtime),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await h?.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: const NihongoDailyApp(),
      ),
    ),
  );
  container.read(routerProvider).go('/auth');
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('account route has no fake login while unconfigured', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('Đăng nhập hiện chưa khả dụng.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'credential buffers clear and profile barrier precedes study runtime',
    (tester) async {
      final h = Harness()..delayed = Completer();
      final container = await mount(tester, h: h);
      await tester.enterText(
        find.byKey(const Key('account-email')),
        'fixture@example.invalid',
      );
      await tester.enterText(
        find.byKey(const Key('account-password')),
        'TEST_ONLY_PASSWORD',
      );
      final password = tester.widget<TextField>(
        find.byKey(const Key('account-password')),
      );
      expect(password.obscureText, isTrue);
      await tester.tap(find.text('Đăng nhập'));
      await tester.pump();
      expect(password.controller!.text, isEmpty);
      expect(container.read(srsStudyRuntimeProvider), isNull);
      expect(h.queue.calls, 0);
      expect(find.text('Đang chuẩn bị hồ sơ học tập…'), findsOneWidget);
      h.delayed!.complete(fixture.ownProfile());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-profile-name')), findsOneWidget);
      await tester.tap(find.text('Ôn tập'));
      await tester.pumpAndSettle();
      expect(h.queue.calls, 1);
      expect(find.text('猫'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('profile error is redacted and explicit retry gates study', (
    tester,
  ) async {
    final h = Harness()..failProfile = true;
    final container = await mount(tester, h: h);
    h.access.change(fixture.owner);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-error')), findsOneWidget);
    expect(find.textContaining('PRIVATE'), findsNothing);
    expect(container.read(srsStudyRuntimeProvider), isNull);
    h.failProfile = false;
    await tester.tap(find.text('Tải lại hồ sơ'));
    await tester.pumpAndSettle();
    expect(h.profiles, 2);
    expect(container.read(srsStudyRuntimeProvider), isNotNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('logout error immediately clears old study data', (tester) async {
    final h = Harness();
    final container = await mount(tester, h: h);
    h.access.change(fixture.owner);
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/srs');
    await tester.pumpAndSettle();
    expect(find.text('猫'), findsOneWidget);
    h.access.failSignOut = true;
    final logout = h.runtime.signOut();
    expect(h.runtime.readyRuntime, isNull);
    await logout;
    await tester.pumpAndSettle();
    expect(find.text('猫'), findsNothing);
    container.read(routerProvider).go('/auth');
    await tester.pumpAndSettle();
    expect(
      find.text('Chưa xác nhận đăng xuất. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('account-profile-name')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'account form at 320 pixels and 200 percent text remains usable',
    (tester) async {
      final h = Harness();
      await mount(tester, h: h, size: const Size(320, 700), scale: 2);
      await tester.ensureVisible(find.text('Đăng nhập'));
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.byKey(const Key('account-password')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
