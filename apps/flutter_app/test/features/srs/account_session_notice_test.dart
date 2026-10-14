import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/auth/application/account_provider.dart';
import 'package:nihongo_daily/features/auth/application/account_session_notice.dart';
import 'package:nihongo_daily/features/auth/application/account_session_notice_provider.dart';
import 'package:nihongo_daily/features/srs/application/srs_study_provider.dart';
import 'account_widget_test.dart' show Harness;
import 'account_startup_test.dart' show Owner;
import 'package:nihongo_daily/features/auth/application/account_startup_controller.dart';
import 'package:nihongo_daily/features/auth/presentation/account_startup_app.dart';

// TEST ONLY display source/Auth/profile; notice is never an access gate.
final class Notices implements AccountSessionNoticeSource {
  @override
  AccountSessionNotice notice = AccountSessionNotice.none;
  final events = StreamController<AccountSessionNotice>.broadcast();
  @override
  Stream<AccountSessionNotice> get noticeChanges => events.stream;
  void emit(AccountSessionNotice value) {
    notice = value;
    events.add(value);
  }
}

Future<ProviderContainer> mount(
  WidgetTester tester,
  Harness harness,
  Notices notices,
) async {
  final container = ProviderContainer(
    overrides: [
      accountRuntimeProvider.overrideWithValue(harness.runtime),
      accountSessionNoticeSourceProvider.overrideWithValue(notices),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await notices.events.close();
    await harness.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const NihongoDailyApp(),
    ),
  );
  container.read(routerProvider).go('/auth');
  await tester.pumpAndSettle();
  return container;
}

final class NoticedOwner<T>
    implements AccountStartupRuntime<T>, AccountSessionNoticeSource {
  NoticedOwner(this.owner, this.notices);
  final Owner<T> owner;
  final Notices notices;
  @override
  T get account => owner.account;
  @override
  bool get canOfferLogin => owner.canOfferLogin;
  @override
  Future<void> start() => owner.start();
  @override
  Future<void> close() => owner.close();
  @override
  AccountSessionNotice get notice => notices.notice;
  @override
  Stream<AccountSessionNotice> get noticeChanges => notices.noticeChanges;
}

void main() {
  testWidgets('checking notice hides credentials without issuing login', (
    tester,
  ) async {
    final harness = Harness();
    final notices = Notices();
    final container = await mount(tester, harness, notices);
    await tester.enterText(
      find.byKey(const Key('account-password')),
      'TEST_ONLY_PASSWORD',
    );
    final field = tester.widget<TextField>(
      find.byKey(const Key('account-password')),
    );
    notices.emit(AccountSessionNotice.checking);
    await tester.pump();
    expect(find.text('Đang xác nhận phiên đăng nhập…'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(harness.access.signInCalls, 0);
    expect(field.controller!.text, isEmpty);
    expect(container.read(srsStudyRuntimeProvider), isNull);
  });
  testWidgets('failed notice shows fixed text and explicit login form', (
    tester,
  ) async {
    final harness = Harness();
    final notices = Notices()..notice = AccountSessionNotice.needsLogin;
    await mount(tester, harness, notices);
    expect(find.byKey(const Key('account-session-notice')), findsOneWidget);
    expect(find.byKey(const Key('account-email')), findsOneWidget);
    expect(find.textContaining('PRIVATE'), findsNothing);
    expect(harness.access.signInCalls, 0);
  });
  testWidgets('clearing display notice never grants study access', (
    tester,
  ) async {
    final harness = Harness();
    final notices = Notices()..notice = AccountSessionNotice.needsLogin;
    final container = await mount(tester, harness, notices);
    notices.emit(AccountSessionNotice.none);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-session-notice')), findsNothing);
    expect(container.read(srsStudyRuntimeProvider), isNull);
    expect(harness.queue.calls, 0);
  });
  testWidgets('notice error at 320px 200 percent has no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await mount(
      tester,
      Harness(),
      Notices()..notice = AccountSessionNotice.needsLogin,
    );
    expect(find.byKey(const Key('account-session-notice')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('notice stream errors redact and closure clears display', () async {
    final notices = Notices();
    final container = ProviderContainer(
      overrides: [
        accountSessionNoticeSourceProvider.overrideWithValue(notices),
      ],
    );
    expect(
      container.read(accountSessionNoticeProvider),
      AccountSessionNotice.none,
    );
    notices.events.addError(StateError('PRIVATE TOKEN SDK'));
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(accountSessionNoticeProvider),
      AccountSessionNotice.needsLogin,
    );
    await notices.events.close();
    expect(
      container.read(accountSessionNoticeProvider),
      AccountSessionNotice.none,
    );
    container.dispose();
  });
  test('replacing source cancels old display events', () async {
    final first = Notices();
    final second = Notices();
    final container = ProviderContainer(
      overrides: [accountSessionNoticeSourceProvider.overrideWithValue(first)],
    );
    expect(
      container.read(accountSessionNoticeProvider),
      AccountSessionNotice.none,
    );
    container.updateOverrides([
      accountSessionNoticeSourceProvider.overrideWithValue(second),
    ]);
    expect(
      container.read(accountSessionNoticeProvider),
      AccountSessionNotice.none,
    );
    first.emit(AccountSessionNotice.needsLogin);
    second.emit(AccountSessionNotice.checking);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(accountSessionNoticeProvider),
      AccountSessionNotice.checking,
    );
    container.dispose();
    await first.events.close();
    await second.events.close();
  });
  testWidgets('configured startup forwards only its owned display source', (
    tester,
  ) async {
    final harness = Harness();
    final notices = Notices();
    final owner = NoticedOwner(Owner(harness.runtime), notices);
    final controller = AccountStartupController(() async => owner);
    await tester.pumpWidget(AccountStartupApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-email')), findsOneWidget);
    notices.emit(AccountSessionNotice.checking);
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    notices.emit(AccountSessionNotice.needsLogin);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-session-notice')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await controller.close();
    await notices.events.close();
    await harness.close();
  });
}
