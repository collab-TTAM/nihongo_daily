import 'dart:async';
import 'dart:io';

import 'package:nihongo_daily/features/srs/data/review_connection_registry.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

// TEST ONLY captured connections, never SDK/JWT/HTTP/credential evidence.
void check(bool value, String label) {
  if (!value) throw StateError(label);
}

Future<void> main() async {
  const a = '11111111-1111-4111-8111-111111111111';
  const b = '22222222-2222-4222-8222-222222222222';
  var now = DateTime.utc(2026, 10, 14);
  final registry = ReviewConnectionRegistry(now: () => now);
  final observed = <String?>[];
  final subscription = registry.sessionChanges.listen(
    (_) => observed.add(registry.currentSession?.userId),
  );
  void begin(String user, CapturedReviewRpc rpc) => registry.begin(
    userId: user,
    expiresAt: now.add(const Duration(hours: 1)),
    rpc: rpc,
  );
  final envelope = <String, Object>{
    'p_request': <String, Object>{'jlpt_level': 'N5', 'limit': 100},
  };
  Future<Object?> invoke(ReviewSession session) => registry.invoke(
    capturedSession: session,
    function: 'get_review_queue',
    params: envelope,
  );
  Future<void> unauthorized(Future<Object?> future) async {
    try {
      await future;
      throw StateError('Expected revoked identity');
    } on ReviewTransportFailure catch (error) {
      check(
        error.code == ReviewErrorCode.unauthorized,
        'safe revoked identity',
      );
    }
  }

  try {
    check(registry.currentSession == null, 'initial unavailable');
    begin(a, (_, __) async => 'captured A');
    final first = registry.currentSession!;
    check(observed.length == 1 && observed.last == a, 'sync begin');
    final deferred = Completer<Object?>();
    registry.refresh(
      userId: a,
      expiresAt: now.add(const Duration(hours: 2)),
      rpc: (_, __) => deferred.future,
    );
    check(
      identical(first, registry.currentSession),
      'refresh retains identity',
    );
    final pending = invoke(first);
    registry.refresh(
      userId: a,
      expiresAt: now.add(const Duration(hours: 2)),
      rpc: (_, __) async => 'fresh',
    );
    deferred.complete('captured old lease');
    check(await pending == 'captured old lease', 'refresh does not redirect');
    check(await invoke(first) == 'fresh', 'next dispatch uses fresh lease');
    begin(b, (_, __) async => 'B');
    begin(a, (_, __) async => 'A again');
    await unauthorized(invoke(first));
    final late = Completer<Object?>();
    begin(a, (_, __) => late.future);
    final old = invoke(registry.currentSession!);
    registry.end();
    late.complete('ignored');
    await unauthorized(old);
    begin(a, (_, __) async => throw Exception('TEST ONLY sensitive detail'));
    try {
      await invoke(registry.currentSession!);
      throw StateError('Expected safe error');
    } on ReviewTransportFailure catch (error) {
      check(
        error.code == ReviewErrorCode.internalError,
        'redacted unknown failure',
      );
    }
    begin(a, (_, params) async {
      final inner = params['p_request'] as Map;
      try {
        inner['limit'] = 1;
        throw StateError('Expected immutable envelope');
      } on UnsupportedError {
        return 'immutable';
      }
    });
    check(
      await invoke(registry.currentSession!) == 'immutable',
      'frozen envelope',
    );
    envelope['user_id'] = b;
    try {
      await invoke(registry.currentSession!);
      throw StateError('Expected rejected owner');
    } on ReviewTransportFailure catch (error) {
      check(error.code == ReviewErrorCode.validationFailure, 'owner rejected');
    }
    envelope.remove('user_id');
    final expiring = registry.currentSession!;
    now = now.add(const Duration(hours: 1));
    await unauthorized(invoke(expiring));
    check(observed.last == null, 'expiry sync clear');
    begin(a, (_, __) async => null);
    registry.dispose();
    check(
      registry.currentSession == null && observed.last == null,
      'dispose sync clear',
    );
    stdout.writeln(
      'PASS: captured-connection lifecycle/refresh/expiry/immutable envelope/revoked-result checks; TEST ONLY, no SDK/JWT claim',
    );
  } finally {
    registry.dispose();
    await subscription.cancel();
  }
}
