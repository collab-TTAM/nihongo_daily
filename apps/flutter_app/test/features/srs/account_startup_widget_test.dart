import 'dart:async';
import 'dart:ui' show AppExitResponse;
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

final class DeferredCloseOwner<T> implements AccountStartupRuntime<T> {
  DeferredCloseOwner(this.owner);
  final Owner<T> owner;
  Completer<void>? closeWait;
  int closes = 0;
  bool failClose = false;
  @override
  T get account => owner.account;
  @override
  bool get canOfferLogin => owner.canOfferLogin;
  @override
  Future<void> start() => owner.start();
  @override
  Future<void> close() async {
    closes++;
    await closeWait?.future;
    if (failClose) throw StateError('PRIVATE TOKEN PATH');
    await owner.close();
  }
}

void main() {
  testWidgets('cancelable exit awaits owned drain and coalesces requests', (
    tester,
  ) async {
    final harness = Harness();
    final owner = DeferredCloseOwner(Owner(harness.runtime))
      ..closeWait = Completer();
    final controller = AccountStartupController(() async => owner);
    await tester.pumpWidget(AccountStartupApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-email')), findsOneWidget);
    var completed = 0;
    final first = tester.binding.handleRequestAppExit().then((response) {
      completed++;
      return response;
    });
    final second = tester.binding.handleRequestAppExit();
    await tester.pump();
    expect(completed, 0);
    expect(owner.closes, 1);
    expect(controller.account, isNull);
    // Binding walks exit observers asynchronously. Render after drain entered.
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Đang đóng phiên an toàn…'), findsOneWidget);
    owner.closeWait!.complete();
    expect(await first, AppExitResponse.exit);
    expect(await second, AppExitResponse.exit);
    expect(owner.closes, 1);
    await tester.pumpWidget(const SizedBox());
    await controller.close();
    await harness.close();
  });
  testWidgets('failed exit cancels with fixed text and explicit close retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = Harness();
    final owner = DeferredCloseOwner(Owner(harness.runtime))..failClose = true;
    var opens = 0;
    final controller = AccountStartupController(() async {
      opens++;
      return owner;
    });
    await tester.pumpWidget(AccountStartupApp(controller: controller));
    await tester.pumpAndSettle();
    expect(await tester.binding.handleRequestAppExit(), AppExitResponse.cancel);
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa thể đóng phiên an toàn.'), findsOneWidget);
    expect(find.textContaining('PRIVATE'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(controller.account, isNull);
    expect(tester.takeException(), isNull);
    // No timer, resume, login or factory retry can restart this fenced host.
    controller.resume();
    await controller.retry();
    expect(opens, 1);
    expect(owner.closes, 1);
    owner.failClose = false;
    expect(await tester.binding.handleRequestAppExit(), AppExitResponse.exit);
    expect(owner.closes, 2);
    await tester.pumpWidget(const SizedBox());
    await controller.close();
    await harness.close();
  });
  testWidgets('exit during factory drains late owner before allowing exit', (
    tester,
  ) async {
    final harness = Harness();
    final owner = DeferredCloseOwner(Owner(harness.runtime));
    // Keep the concrete account type inferred from the owned harness.
    final waiting = Completer<void>();
    final controller = AccountStartupController(() async {
      await waiting.future;
      return owner;
    });
    await tester.pumpWidget(AccountStartupApp(controller: controller));
    await tester.pump();
    var exited = false;
    final exit = tester.binding.handleRequestAppExit().then((response) {
      exited = true;
      return response;
    });
    await tester.pump();
    expect(exited, isFalse);
    expect(find.byType(TextField), findsNothing);
    waiting.complete();
    expect(await exit, AppExitResponse.exit);
    expect(owner.owner.starts, 0);
    expect(owner.closes, 1);
    expect(controller.account, isNull);
    await tester.pumpWidget(const SizedBox());
    await controller.close();
    await harness.close();
  });
  testWidgets('exit during restore cannot publish late account success', (
    tester,
  ) async {
    final harness = Harness();
    final owner = DeferredCloseOwner(
      Owner(harness.runtime)..startWait = Completer(),
    );
    final controller = AccountStartupController(() async => owner);
    await tester.pumpWidget(AccountStartupApp(controller: controller));
    await tester.pump();
    final exit = tester.binding.handleRequestAppExit();
    await tester.pump();
    expect(owner.closes, 0);
    owner.owner.startWait!.complete();
    expect(await exit, AppExitResponse.exit);
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(controller.account, isNull);
    expect(owner.closes, 1);
    await tester.pumpWidget(const SizedBox());
    await controller.close();
    await harness.close();
  });
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
