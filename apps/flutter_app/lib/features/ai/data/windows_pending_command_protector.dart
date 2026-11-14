import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../srs/data/review_repository.dart';
import '../domain/conversation_receipt_reference.dart';
import '../domain/pending_conversation_command_envelope.dart';
import 'conversation_receipt_store.dart';

enum CommandProtectionError { unauthorized, invalidInput, unavailable, busy }

final class CommandProtectionFailure implements Exception {
  const CommandProtectionFailure(this.code);
  final CommandProtectionError code;
  @override
  String toString() => 'CommandProtectionFailure(${code.name})';
}

/// Optional captured-session byte capability. No storage, replay or release.
/// Host supplies trusted scope/readiness; scope syntax alone is not Auth.
final class WindowsPendingCommandProtector {
  WindowsPendingCommandProtector({
    required ReviewAuth auth,
    required ConversationReceiptScope scope,
    required bool Function() isReady,
  }) : _auth = auth,
       _scope = scope,
       _ready = isReady {
    try {
      _session = auth.currentSession!;
      if (_session.userId != scope.ownerId) throw const FormatException();
      _check();
    } on Object {
      throw const CommandProtectionFailure(CommandProtectionError.unauthorized);
    }
  }
  final ReviewAuth _auth;
  final ConversationReceiptScope _scope;
  final bool Function() _ready;
  late final ReviewSession _session;
  bool _revoked = false;
  bool _busy = false;
  bool _checking = false;
  Completer<void>? _drain;
  static const _channel = MethodChannel(
    'nihongo_daily/conversation_receipts_v1',
  );

  bool get isCurrent {
    // Supplied readiness/Auth getters may reenter. A nested read cannot establish
    // readiness or open a native operation while the outer check is unresolved.
    if (_revoked || _checking) return false;
    _checking = true;
    try {
      if (_ready() &&
          identical(_auth.currentSession, _session) &&
          _ready() &&
          identical(_auth.currentSession, _session) &&
          !_revoked) {
        return true;
      }
    } on Object {
      // Fixed failure below, never a callback's private exception.
    } finally {
      _checking = false;
    }
    revoke();
    return false;
  }

  void revoke() => _revoked = true;

  /// Revoke synchronously and wait for accepted native work to actually settle.
  /// This does not cancel OS work, clear storage or swallow the operation's
  /// result/error; its original caller must still observe that future.
  Future<void> revokeAndDrain() {
    revoke();
    return _drain?.future ?? Future<void>.value();
  }

  void _check() {
    if (!isCurrent) {
      throw const CommandProtectionFailure(CommandProtectionError.unauthorized);
    }
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    if (_busy || _checking) {
      throw const CommandProtectionFailure(CommandProtectionError.busy);
    }
    _busy =
        true; // Before callbacks/encoding/dispatch; release only on actual drain.
    final drain = Completer<void>();
    _drain = drain; // Publish before supplied readiness/Auth callbacks run.
    try {
      _check();
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
        throw const CommandProtectionFailure(
          CommandProtectionError.unavailable,
        );
      }
      final result = await action();
      _check();
      return result;
    } on CommandProtectionFailure {
      _check();
      rethrow;
    } on Object {
      _check();
      throw const CommandProtectionFailure(CommandProtectionError.unavailable);
    } finally {
      _busy = false;
      _drain = null;
      drain.complete();
    }
  }

  Future<Uint8List> _transform(
    String method,
    Uint8List input,
    int limit,
  ) async {
    final result = await _channel.invokeMethod<Object?>(method, {
      'target':
          '${ConversationReceiptStore.targetPrefix}${_scope.projectOrigin}|${_scope.ownerId}',
      'bytes': Uint8List.fromList(input),
    });
    _check(); // Never decode/expose plaintext from an old captured lifecycle.
    if (result is! Uint8List || result.isEmpty || result.length > limit) {
      throw const CommandProtectionFailure(CommandProtectionError.unavailable);
    }
    return Uint8List.fromList(result);
  }

  Future<Uint8List> protect(PendingConversationCommandEnvelope command) =>
      _run(() async {
        if (!_scope.contains(command.reference)) {
          throw const CommandProtectionFailure(
            CommandProtectionError.invalidInput,
          );
        }
        final plain = Uint8List.fromList(utf8.encode(command.encode()));
        return _transform('protectCommand', plain, 65536);
      });

  Future<PendingConversationCommandEnvelope> unprotect(Uint8List ciphertext) =>
      _run(() async {
        if (ciphertext.isEmpty || ciphertext.length > 65536) {
          throw const CommandProtectionFailure(
            CommandProtectionError.invalidInput,
          );
        }
        final plain = await _transform('unprotectCommand', ciphertext, 32768);
        return PendingConversationCommandEnvelope.decode(
          utf8.decode(plain),
          expectedScope: _scope,
        );
      });
}
