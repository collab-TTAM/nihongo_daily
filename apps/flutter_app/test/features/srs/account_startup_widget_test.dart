import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/auth/application/account_startup_controller.dart';
import 'package:nihongo_daily/features/auth/presentation/account_startup_app.dart';
import 'account_startup_test.dart' show Owner;
import 'account_widget_test.dart' show Harness;

final class ResumableOwner<T>
    implements AccountStartupRuntime<T>, ResumableAccountStartup {
  ResumableOwner(this.owner);
  final Owner<T> owner;
  int resumes = 0;
  @override
  T get account => owner.account;
  @override
  bool get canOfferLogin => owner.canOfferLogin;
  @override
  Future<void> start() => owner.start();
  @override
  Future<void> close() => owner.close();
  @override
  void resume() => resumes++;
}

void main() {
  testWidgets(
    'startup loading hides account and late restore enters real account route',
    (tester) async {
      final harness = Harness();
      final owner = Owner(harness.runtime)..startWait = Completer();
      final controller = AccountStartupController(() async => owner);
      await tester.pumpWidget(AccountStartupApp(controller: controller));
      await tester.pump();
      expect(find.text('Đang khôi phục phiên đăng nhập…'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      owner.startWait!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-email')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await controller.close();
      await harness.close();
    },
  );
  testWidgets(
    'restore error is redacted and explicit login opens existing form',
    (tester) async {
      final harness = Harness();
      final owner = Owner(harness.runtime)..failStart = true;
      final controller = AccountStartupController(() async => owner);
      await tester.pumpWidget(AccountStartupApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Đăng nhập lại'), findsOneWidget);
      await tester.tap(find.text('Đăng nhập lại'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-password')), findsOneWidget);
      expect(harness.access.signInCalls, 0);
      await tester.pumpWidget(const SizedBox());
      await controller.close();
      await harness.close();
    },
  );
  testWidgets('factory retry and 320px 200 percent errors have no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = Harness();
    final owner = Owner(harness.runtime);
    var opens = 0;
    final controller = AccountStartupController(() async {
      if (++opens == 1) throw StateError('PRIVATE');
      return owner;
    });
    await tester.pumpWidget(AccountStartupApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập lại'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Thử khởi động lại'));
    await tester.pumpAndSettle();
    expect(opens, 2);
    expect(find.byKey(const Key('account-email')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await controller.close();
    await harness.close();
  });
  testWidgets('unmount during restore cleans late owner without rebuilding', (
    tester,
  ) async {
    final harness = Harness();
    final owner = Owner(harness.runtime)..startWait = Completer();
    final controller = AccountStartupController(() async => owner);
    await tester.pumpWidget(AccountStartupApp(controller: controller));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    owner.startWait!.complete();
    await tester.pump();
    await controller.close();
    expect(controller.account, isNull);
    expect(owner.closes, 1);
    expect(tester.takeException(), isNull);
    await harness.close();
  });
  testWidgets(
    'foreground resume forwards only after startup and never after unmount',
    (tester) async {
      final harness = Harness();
      final owner = Owner(harness.runtime)..startWait = Completer();
      final resumable = ResumableOwner(owner);
      final controller = AccountStartupController(() async => resumable);
      await tester.pumpWidget(AccountStartupApp(controller: controller));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(resumable.resumes, 0);
      owner.startWait!.complete();
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(resumable.resumes, 1);
      await tester.pumpWidget(const SizedBox());
      await controller.close();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(resumable.resumes, 1);
      await harness.close();
    },
  );
}
