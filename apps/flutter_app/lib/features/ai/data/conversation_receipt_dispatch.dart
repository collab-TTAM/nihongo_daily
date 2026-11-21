import 'dart:async';

import '../../srs/data/review_repository.dart';
import '../domain/conversation_receipt_reference.dart';
import '../domain/pending_conversation_command_envelope.dart';
import 'captured_conversation_session.dart';
import 'conversation_receipt_store.dart';

enum ReceiptDispatchError { unavailable, conflict, unauthorized }

final class ReceiptDispatchFailure implements Exception {
  const ReceiptDispatchFailure(this.code);
  final ReceiptDispatchError code;
  @override
  String toString() => 'ReceiptDispatchFailure(${code.name})';
}

/// One explicit first attempt, not a retry/reconciliation capability. Borrows all
/// ports. Host binds an immutable original command and captured credentials in
/// dispatch, and supplies vault/profile/runtime-generation readiness in isReady.
/// No app default uses this component. No metadata authorizes provider replay.
final class ConversationReceiptDispatch<T> {
  ConversationReceiptDispatch({
    required ConversationReceiptStore store,
    required ConversationReceiptReference reference,
    PendingConversationCommandEnvelope? originalCommand,
    required ReviewAuth auth,
    required ReviewSession capturedSession,
    required bool Function() isReady,
    required Future<T> Function(ReviewSession) dispatch,
  }) : _store = store,
       _reference = reference,
       _command = originalCommand,
       _auth = auth,
       _session = capturedSession,
       _ready = isReady,
       _dispatch = dispatch {
    if (originalCommand != null &&
        originalCommand.reference.encode() != reference.encode()) {
      throw const ReceiptDispatchFailure(ReceiptDispatchError.conflict);
    }
    if (!store.scope.contains(reference) ||
        capturedSession.userId != reference.ownerId.toLowerCase()) {
      throw const ReceiptDispatchFailure(ReceiptDispatchError.unauthorized);
    }
  }

  // Weak identity claim across gates borrowing the SAME store. Only the exact
  // gate can release after verified application, full original and actual drain.
  // Legacy metadata-only gates remain terminal; absence/success grants nothing.
  static final _usedStores = Expando<Object>();
  final ConversationReceiptStore _store;
  final ConversationReceiptReference _reference;
  final PendingConversationCommandEnvelope? _command;
  final ReviewAuth _auth;
  final ReviewSession _session;
  final bool Function() _ready;
  final Future<T> Function(ReviewSession) _dispatch;
  bool _started = false;
  bool _settled = false;
  bool _releasing = false;
  bool _revoked = false;
  Future<void> _drain = Future<void>.value();
  Future<void>? _closing;

  void revoke() => _revoked = true;

  void _check() {
    var current = false;
    if (!_revoked) {
      try {
        current =
            _ready() &&
            identical(_auth.currentSession, _session) &&
            _ready() &&
            identical(_auth.currentSession, _session);
      } on Object {
        // Supplied getters never leak details and cannot restore a retired gate.
      }
    }
    if (!current || _revoked) {
      revoke();
      throw const ReceiptDispatchFailure(ReceiptDispatchError.unauthorized);
    }
  }

  Future<T> submit() {
    // Reserve before any external getter/storage/dispatch can reenter.
    if (_started || _usedStores[_store] != null) {
      return Future.error(
        const ReceiptDispatchFailure(ReceiptDispatchError.conflict),
      );
    }
    _started = true;
    _usedStores[_store] = this;
    final drained = Completer<void>();
    _drain = drained.future;
    final result = _run();
    unawaited(
      result.then<void>(
        (_) {
          _settled = true;
          drained.complete();
        },
        onError: (Object _, StackTrace _) {
          _settled = true;
          drained.complete();
        },
      ),
    );
    return result;
  }

  Future<T> _run() async {
    try {
      _check();
      final previous = await _store.read();
      _check();
      // Even identical metadata from an earlier process/capability is not a
      // retained original command or proof that a provider call never happened.
      if (previous != null) {
        throw const ReceiptDispatchFailure(ReceiptDispatchError.conflict);
      }
      await _store.reserve(_reference);
      _check(); // Confirm actual persistence and freshly captured readiness.
      final value = await _dispatch(_session);
      _check(); // Consume late responses without publishing after retirement.
      return value;
    } on ReceiptDispatchFailure {
      _check();
      rethrow;
    } on Object {
      _check();
      // No raw storage/HTTP details, fallback, implicit retry or success inference.
      throw const ReceiptDispatchFailure(ReceiptDispatchError.unavailable);
    }
  }

  /// Explicit trusted-host step. Never inferred from absent metadata, a receipt
  /// read, public timeout, or an apply-success boolean. Retires this gate forever;
  /// only a new explicit command may subsequently claim this same borrowed store.
  bool releaseAppliedCompletion(CapturedConversationApplication application) {
    final original = _command;
    if (!_started ||
        !_settled ||
        _revoked ||
        _closing != null ||
        _releasing ||
        original == null ||
        !identical(_usedStores[_store], this)) {
      return false;
    }
    _releasing = true;
    try {
      _check();
      final pair = application.consumeForTransport(auth: _auth, store: _store);
      if (pair == null ||
          pair.command.encode() != original.encode() ||
          _revoked ||
          _closing != null ||
          !_settled ||
          !identical(_usedStores[_store], this)) {
        return false;
      }
      // No external callback/await between final proof/claim checks and release.
      _revoked = true;
      _usedStores[_store] = null;
      return true;
    } on Object {
      revoke();
      return false;
    } finally {
      _releasing = false;
    }
  }

  /// Revoke synchronously, then drain actual storage and callback completion.
  /// No timeout releases this wait. Does not clear/close the borrowed store.
  Future<void> close() {
    revoke();
    return _closing ??= _drain;
  }

  @override
  String toString() => 'ConversationReceiptDispatch';
}
