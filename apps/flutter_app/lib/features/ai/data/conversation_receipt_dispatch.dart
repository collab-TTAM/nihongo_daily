import 'dart:async';

import '../../srs/data/review_repository.dart';
import '../domain/conversation_receipt_reference.dart';
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
    required ReviewAuth auth,
    required ReviewSession capturedSession,
    required bool Function() isReady,
    required Future<T> Function(ReviewSession) dispatch,
  }) : _store = store,
       _reference = reference,
       _auth = auth,
       _session = capturedSession,
       _ready = isReady,
       _dispatch = dispatch {
    if (!store.scope.contains(reference) ||
        capturedSession.userId != reference.ownerId.toLowerCase()) {
      throw const ReceiptDispatchFailure(ReceiptDispatchError.unauthorized);
    }
  }

  // Weak identity claim across gates borrowing the SAME store. Never released:
  // a completed/failed attempt is not permission to replace a pending command.
  static final _usedStores = Expando<bool>();
  final ConversationReceiptStore _store;
  final ConversationReceiptReference _reference;
  final ReviewAuth _auth;
  final ReviewSession _session;
  final bool Function() _ready;
  final Future<T> Function(ReviewSession) _dispatch;
  bool _started = false;
  bool _revoked = false;
  Future<void> _drain = Future<void>.value();
  Future<void>? _closing;

  void revoke() => _revoked = true;

  void _check() {
    var current = false;
    if (!_revoked) {
      try {
        current =
            _ready() && identical(_auth.currentSession, _session) && _ready();
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
    if (_started || _usedStores[_store] == true) {
      return Future.error(
        const ReceiptDispatchFailure(ReceiptDispatchError.conflict),
      );
    }
    _started = true;
    _usedStores[_store] = true;
    final drained = Completer<void>();
    _drain = drained.future;
    final result = _run();
    unawaited(
      result.then<void>(
        (_) {
          drained.complete();
        },
        onError: (Object _, StackTrace _) {
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

  /// Revoke synchronously, then drain actual storage and callback completion.
  /// No timeout releases this wait. Does not clear/close the borrowed store.
  Future<void> close() {
    revoke();
    return _closing ??= _drain;
  }

  @override
  String toString() => 'ConversationReceiptDispatch';
}
