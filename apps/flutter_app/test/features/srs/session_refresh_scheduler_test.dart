import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/auth/application/session_refresh_scheduler.dart';

// TEST ONLY clock/timer/lease/refresh, not SDK/OS/hosted Auth proof.
final class TestTimer implements Timer {
  TestTimer(this.delay, this.callback);
  final Duration delay;
  final void Function() callback;
  @override
  bool isActive = true;
  @override
  int tick = 0;
  @override
  void cancel() => isActive = false;
  void fire({bool stale = false}) {
    if (!isActive && !stale) return;
    isActive = false;
    tick++;
    callback();
  }
}

final class Harness {
  Harness() {
    lease = RefreshLease(Object(), now.add(const Duration(hours: 1)));
    scheduler = SessionRefreshScheduler(
      current: () => lease,
      now: () => now,
      timer: (delay, callback) {
        final timer = TestTimer(delay, callback);
        timers.add(timer);
        return timer;
      },
      refresh: () async {
        calls++;
        await waiting?.future;
        if (fail) throw StateError('PRIVATE TOKEN');
        if (rotate && lease != null) {
          lease = RefreshLease(
            lease!.identity,
            now.add(const Duration(hours: 1)),
          );
        }
      },
    );
  }
  DateTime now = DateTime.utc(2026, 10, 14);
  RefreshLease? lease;
  late final SessionRefreshScheduler scheduler;
  final timers = <TestTimer>[];
  Completer<void>? waiting;
  bool fail = false;
  bool rotate = true;
  int calls = 0;
  void due() {
    now = lease!.expiresAt.subtract(SessionRefreshScheduler.leadTime);
    timers.last.fire();
  }
}

Future<void> flush() async {
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('refresh schedule starts 60 seconds before accepted expiry', () async {
    final h = Harness();
    h.scheduler.update();
    expect(h.timers.single.delay, const Duration(minutes: 59));
    h.due();
    await flush();
    expect(h.calls, 1);
    expect(h.scheduler.phase, SessionRefreshPhase.scheduled);
    expect(h.timers.last.delay, const Duration(minutes: 59));
    h.scheduler.dispose();
  });
  test('logout cancels timers and rejects already queued callback', () async {
    final h = Harness();
    h.scheduler.update();
    final old = h.timers.single;
    h.lease = null;
    h.scheduler.update();
    old.fire(stale: true);
    await flush();
    expect(h.calls, 0);
    expect(h.scheduler.phase, SessionRefreshPhase.idle);
    h.scheduler.dispose();
  });
  test('account A B A replaces identity before stale callback', () async {
    final h = Harness();
    h.scheduler.update();
    final old = h.timers.single;
    h.lease = RefreshLease(Object(), h.lease!.expiresAt);
    h.scheduler.update();
    old.fire(stale: true);
    await flush();
    expect(h.calls, 0);
    h.due();
    await flush();
    expect(h.calls, 1);
    h.scheduler.dispose();
  });
  test('foreground resume catches overdue valid lease exactly once', () async {
    final h = Harness();
    h.scheduler.update();
    h.now = h.lease!.expiresAt.subtract(const Duration(seconds: 20));
    h.scheduler.update();
    expect(h.timers.last.delay, Duration.zero);
    h.timers.last.fire();
    h.scheduler.update();
    await flush();
    expect(h.calls, 1);
    h.scheduler.dispose();
  });
  test('expired foreground lease never dispatches or restores', () async {
    final h = Harness();
    h.scheduler.update();
    final old = h.timers.single;
    h.now = h.lease!.expiresAt;
    h.scheduler.update();
    old.fire(stale: true);
    await flush();
    expect(h.calls, 0);
    expect(h.scheduler.phase, SessionRefreshPhase.idle);
    h.scheduler.dispose();
  });
  test('in-flight refresh suppresses timer and repeated resume', () async {
    final h = Harness()..waiting = Completer();
    h.scheduler.update();
    final old = h.timers.single;
    h.due();
    h.scheduler.update();
    old.fire(stale: true);
    h.scheduler.update();
    expect(h.calls, 1);
    h.waiting!.complete();
    await flush();
    expect(h.calls, 1);
    h.scheduler.dispose();
  });
  test('failure has no timer or resume retry for same lease', () async {
    final h = Harness()..fail = true;
    h.scheduler.update();
    h.due();
    await flush();
    h.scheduler.update();
    expect(h.calls, 1);
    expect(h.scheduler.phase, SessionRefreshPhase.failed);
    expect(h.timers.where((timer) => timer.isActive), isEmpty);
    h.scheduler.dispose();
  });
  test('unchanged SDK expiry cannot create immediate refresh loop', () async {
    final h = Harness()..rotate = false;
    h.scheduler.update();
    h.due();
    await flush();
    h.scheduler.update();
    expect(h.calls, 1);
    expect(h.timers.where((timer) => timer.isActive), isEmpty);
    h.scheduler.dispose();
  });
  test('short rotated expiry is bounded by minimum interval', () async {
    final h = Harness()..rotate = false;
    h.scheduler.update();
    h.due();
    await flush();
    h.lease = RefreshLease(
      h.lease!.identity,
      h.now.add(const Duration(seconds: 10)),
    );
    h.scheduler.update();
    expect(h.timers.where((timer) => timer.isActive), isEmpty);
    expect(h.calls, 1);
    h.scheduler.dispose();
  });
  test('clock rollback and long lifetimes rearm bounded timers', () async {
    final h = Harness();
    h.lease = RefreshLease(Object(), h.now.add(const Duration(days: 3)));
    h.scheduler.update();
    expect(h.timers.last.delay, const Duration(hours: 24));
    h.now = h.now.subtract(const Duration(hours: 1));
    h.timers.last.fire();
    await flush();
    expect(h.calls, 0);
    expect(h.timers.last.delay, const Duration(hours: 24));
    h.scheduler.dispose();
  });
  test('dispose while refresh pending never rearms late result', () async {
    final h = Harness()..waiting = Completer();
    h.scheduler.update();
    h.due();
    h.scheduler.dispose();
    h.waiting!.complete();
    await flush();
    h.scheduler.update();
    expect(h.scheduler.phase, SessionRefreshPhase.closed);
    expect(h.timers.where((timer) => timer.isActive), isEmpty);
  });
  test('malformed or throwing expiry hints fail closed', () {
    final scheduler = SessionRefreshScheduler(
      current: () => throw StateError('PRIVATE'),
      refresh: () async => fail('must not dispatch'),
    );
    scheduler.update();
    expect(scheduler.phase, SessionRefreshPhase.idle);
    scheduler.dispose();
    final h = Harness();
    h.lease = RefreshLease(Object(), DateTime.utc(10000));
    h.scheduler.update();
    expect(h.timers, isEmpty);
    h.scheduler.dispose();
  });
}
