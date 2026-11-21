import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/auth/application/account_startup_controller.dart';

// TEST ONLY owners, not Auth/OS evidence.
final class Owner<T> implements AccountStartupRuntime<T> {
  Owner(this.account);
  @override
  final T account;
  @override
  bool canOfferLogin = true;
  bool failStart = false;
  bool failClose = false;
  Completer<void>? startWait;
  int starts = 0;
  int closes = 0;
  @override
  Future<void> start() async {
    starts++;
    await startWait?.future;
    if (failStart) throw StateError('PRIVATE TOKEN');
  }

  @override
  Future<void> close() async {
    closes++;
    if (failClose) throw StateError('PRIVATE SQL');
  }
}

void main() {
  test(
    'startup publishes account only after start and never duplicates',
    () async {
      final owner = Owner('account')..startWait = Completer();
      var opens = 0;
      final controller = AccountStartupController(() async {
        opens++;
        return owner;
      });
      final operation = controller.start();
      await Future<void>.delayed(Duration.zero);
      expect(controller.account, isNull);
      expect(controller.phase, AccountStartupPhase.loading);
      await controller.start();
      expect(opens, 1);
      owner.startWait!.complete();
      await operation;
      expect(controller.account, 'account');
      await controller.close();
      expect(controller.account, isNull);
      expect(owner.closes, 1);
    },
  );
  test('restore error offers fenced login only with explicit action', () async {
    final owner = Owner('account')..failStart = true;
    final controller = AccountStartupController(() async => owner);
    await controller.start();
    expect(controller.phase, AccountStartupPhase.restoreError);
    expect(controller.account, isNull);
    owner.canOfferLogin = false;
    controller.offerLogin();
    expect(controller.account, isNull);
    owner.canOfferLogin = true;
    controller.offerLogin();
    expect(controller.account, 'account');
    await controller.close();
  });
  test('factory failure redacts and requires explicit retry', () async {
    var opens = 0;
    final owner = Owner('account');
    final controller = AccountStartupController(() async {
      if (++opens == 1) throw StateError('PRIVATE TOKEN');
      return owner;
    });
    await controller.start();
    expect(controller.phase, AccountStartupPhase.openError);
    expect(controller.canOfferLogin, isFalse);
    expect(opens, 1);
    await controller.retry();
    expect(controller.account, 'account');
    await controller.close();
  });
  test('retry drains old owner before replacement', () async {
    final first = Owner('old')..failStart = true;
    final second = Owner('new');
    var opens = 0;
    final controller = AccountStartupController(() async {
      if (++opens == 1) return first;
      expect(first.closes, 1);
      return second;
    });
    await controller.start();
    await controller.retry();
    expect(controller.account, 'new');
    await controller.close();
  });
  test(
    'cleanup failure blocks replacement and retains owner for retry',
    () async {
      final owner = Owner('old')
        ..failStart = true
        ..failClose = true;
      var opens = 0;
      final controller = AccountStartupController(() async {
        opens++;
        return owner;
      });
      await controller.start();
      await controller.retry();
      expect(controller.phase, AccountStartupPhase.cleanupError);
      expect(controller.account, isNull);
      expect(opens, 1);
      owner.failClose = false;
      await controller.close();
      expect(owner.closes, 2);
    },
  );
  test(
    'close during pending factory drains late owner without starting',
    () async {
      final waiting = Completer<AccountStartupRuntime<String>>();
      final owner = Owner('late');
      final controller = AccountStartupController(() => waiting.future);
      final opening = controller.start();
      await Future<void>.delayed(Duration.zero);
      final closing = controller.close();
      waiting.complete(owner);
      await opening;
      await closing;
      expect(controller.account, isNull);
      expect(owner.starts, 0);
      expect(owner.closes, 1);
    },
  );
  test('close during restore cannot publish late success', () async {
    final owner = Owner('late')..startWait = Completer();
    final controller = AccountStartupController(() async => owner);
    final opening = controller.start();
    await Future<void>.delayed(Duration.zero);
    final closing = controller.close();
    owner.startWait!.complete();
    await opening;
    await closing;
    expect(controller.phase, AccountStartupPhase.closed);
    expect(controller.account, isNull);
    expect(owner.closes, 1);
  });
  test('awaited close failure remains safe and retryable', () async {
    final owner = Owner('account')..failClose = true;
    final controller = AccountStartupController(() async => owner);
    await controller.start();
    await expectLater(
      controller.close(),
      throwsA(isA<AccountStartupCleanupFailure>()),
    );
    expect(controller.account, isNull);
    owner.failClose = false;
    await controller.close();
    expect(owner.closes, 2);
  });
}
