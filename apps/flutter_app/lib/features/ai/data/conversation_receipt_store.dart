import '../domain/conversation_receipt_reference.dart';

enum ConversationReceiptStoreError {
  unavailable,
  corrupt,
  conflict,
  scope,
  revoked,
  owned,
}

final class ConversationReceiptStoreFailure implements Exception {
  const ConversationReceiptStoreFailure(this.code);
  final ConversationReceiptStoreError code;
  @override
  String toString() => 'ConversationReceiptStoreFailure(${code.name})';
}

/// Trusted secure-storage port. No production implementation/default is supplied.
/// Must bound I/O, confirm durable writes/clears and never log arguments/errors.
/// Memory/file/plaintext fallback is forbidden; test ports are TEST ONLY.
abstract interface class SecureConversationReceiptBackend {
  Future<Object?> read(String target);
  Future<void> write(String target, String encoded);
  Future<void> clear(String target);
}

enum ConversationReceiptStorePhase { open, failed, revoked, closed }

/// One pending metadata reference per project/owner. No replay or Auth grant.
/// Exclusivity is isolate-local, not cross-process locking/CAS or encryption.
final class ConversationReceiptStore {
  ConversationReceiptStore({
    required this.scope,
    required SecureConversationReceiptBackend backend,
  }) : _backend = backend,
       _target = '$targetPrefix${scope.projectOrigin}|${scope.ownerId}' {
    if (!_owners.add(_target)) {
      throw _failure(ConversationReceiptStoreError.owned);
    }
  }

  static const targetPrefix = 'NihongoDaily.ConversationReceipt.v1|';
  static final _owners = <String>{};
  final ConversationReceiptScope scope;
  final SecureConversationReceiptBackend _backend;
  final String _target;
  Future<void> _tail = Future<void>.value();
  Future<void>? _clearing;
  Future<void>? _closing;
  bool _revoked = false;
  bool _failed = false;
  bool _closed = false;

  ConversationReceiptStorePhase get phase => _closed
      ? ConversationReceiptStorePhase.closed
      : _revoked
      ? ConversationReceiptStorePhase.revoked
      : _failed
      ? ConversationReceiptStorePhase.failed
      : ConversationReceiptStorePhase.open;

  static ConversationReceiptStoreFailure _failure(
    ConversationReceiptStoreError code,
  ) => ConversationReceiptStoreFailure(code);

  void _check() {
    if (_revoked || _closed) {
      throw _failure(ConversationReceiptStoreError.revoked);
    }
    if (_failed) throw _failure(ConversationReceiptStoreError.unavailable);
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) {
      _check(); // Queued old work must not touch the backend after revocation.
      return action();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<ConversationReceiptReference?> _load() async {
    final Object? value;
    try {
      value = await _backend.read(_target);
    } on Object {
      _failed = true;
      throw _failure(ConversationReceiptStoreError.unavailable);
    }
    _check(); // Consume late data without publishing it into another lifecycle.
    if (value == null) return null;
    try {
      if (value is! String) throw const FormatException();
      final reference = ConversationReceiptReference.decode(value);
      if (!scope.contains(reference)) throw const FormatException();
      return reference;
    } on FormatException {
      _failed = true;
      throw _failure(ConversationReceiptStoreError.corrupt);
    }
  }

  Future<ConversationReceiptReference?> read() => _serial(_load);

  /// Save BEFORE dispatch in a future guarded host. Identical repeat is inert;
  /// another pending reference conflicts rather than overwriting/evicting it.
  /// Success is storage only: never authorization to send/retry an AI mutation.
  Future<void> reserve(ConversationReceiptReference reference) {
    if (!scope.contains(reference)) {
      return Future.error(_failure(ConversationReceiptStoreError.scope));
    }
    final encoded = reference.encode();
    return _serial(() async {
      final previous = await _load();
      if (previous != null) {
        if (previous.encode() != encoded) {
          throw _failure(ConversationReceiptStoreError.conflict);
        }
        return;
      }
      _check();
      try {
        await _backend.write(_target, encoded);
      } on Object {
        _failed = true;
        throw _failure(ConversationReceiptStoreError.unavailable);
      }
      _check(); // A late successful write cannot revive a retired store.
    });
  }

  /// Permanently revoke now; ordered clear follows all actual earlier I/O.
  /// Explicit retry after a failed clear is allowed, but never reopens this store.
  /// Local sign-out clear is not server receipt cancellation/new-event authority.
  Future<void> clearForSignOut() {
    if (_closing != null || _closed) {
      return Future.error(_failure(ConversationReceiptStoreError.revoked));
    }
    if (_clearing != null) return _clearing!;
    _revoked = true;
    final operation = _tail.then((_) async {
      try {
        await _backend.clear(_target);
      } on Object {
        _failed = true;
        throw _failure(ConversationReceiptStoreError.unavailable);
      }
    });
    final owned = operation.whenComplete(() {
      _clearing = null;
    });
    _clearing = owned;
    _tail = owned.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return owned;
  }

  /// Revoke immediately, preserve pending metadata and hold exclusive ownership
  /// until all actual operations settle. Borrowed backend remains caller-owned.
  Future<void> close() {
    if (_closing != null) return _closing!;
    _revoked = true;
    return _closing = _tail.then((_) {
      _closed = true;
      _owners.remove(_target);
    });
  }

  @override
  String toString() => 'ConversationReceiptStore';
}
