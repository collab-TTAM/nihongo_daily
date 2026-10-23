import 'dart:async';

import '../../srs/data/review_repository.dart';
import '../data/captured_ai_text_repository.dart';

/// One owner-created ready generation. Never reuse after a readiness barrier.
final class AiTextGeneration {}

abstract interface class OwnedAiTextTransport implements AiTextTransport {
  bool get isCurrent;
  void revoke();
  Future<void> close();
}

typedef AiTextTransportFactory =
    OwnedAiTextTransport Function({
      required ReviewAuth auth,
      required bool Function() isReady,
    });

/// Holds one capability and drains its transport before another can be built.
/// Contains no SDK/token/store/provider configuration and performs no request.
final class AiTextRuntimeOwner {
  AiTextRuntimeOwner({required AiTextTransportFactory createTransport})
    : _createTransport = createTransport;

  final AiTextTransportFactory _createTransport;
  final _retired = Expando<bool>('retired AI ready generation');
  final _changes = StreamController<void>.broadcast();
  late final Stream<void> changes = _changes.stream;
  _Lease? _lease;
  _Drain? _retiring;
  Completer<void>? _creating;
  int _epoch = 0;
  bool _closed = false;
  bool _failed = false;
  Future<void>? _closing;

  bool get isDraining => _retiring != null || _creating != null;
  bool get isFailed => _failed;

  CapturedAiTextRepository? acquire({
    required ReviewAuth auth,
    required AiTextGeneration generation,
    required bool Function() isReady,
  }) {
    if (_closed || _failed || isDraining || _retired[generation] == true) {
      return null;
    }
    // Register before any supplied getter/factory can synchronously reenter.
    final creating = Completer<void>();
    _creating = creating;
    OwnedAiTextTransport? orphan;
    try {
      final session = auth.currentSession;
      if (session == null || !isReady()) {
        invalidate();
        return null;
      }
      final existing = _lease;
      if (existing != null) {
        if (identical(existing.generation, generation) &&
            identical(existing.auth, auth) &&
            identical(existing.session, session) &&
            existing.repository.isCurrent &&
            existing.transport.isCurrent) {
          return existing.repository;
        }
        invalidate();
        return null;
      }
      final epoch = _epoch;
      bool ready() {
        if (_closed || _failed || epoch != _epoch) return false;
        try {
          return isReady() &&
              identical(auth.currentSession, session) &&
              isReady();
        } on Object {
          return false;
        }
      }

      orphan = _createTransport(auth: auth, isReady: ready);
      final repository = CapturedAiTextRepository(
        auth: auth,
        transport: orphan,
        isReady: ready,
      );
      if (!ready() || !orphan.isCurrent) {
        repository.revoke();
        return null;
      }
      _lease = _Lease(generation, auth, session, orphan, repository);
      orphan = null;
      _notify();
      return repository;
    } on Object {
      // Availability only; no raw factory/SDK/getter error crosses the owner.
      invalidate();
      return null;
    } finally {
      if (orphan != null) {
        _retired[generation] = true;
        _retire(orphan);
      }
      _creating = null;
      creating.complete();
    }
  }

  /// Call synchronously from every owner readiness transition.
  void check() {
    final lease = _lease;
    if (lease == null) return;
    try {
      if (lease.repository.isCurrent && lease.transport.isCurrent) return;
    } on Object {
      /* Revocation below fails closed. */
    }
    invalidate();
  }

  void invalidate() {
    _epoch++;
    final lease = _lease;
    if (lease == null) return;
    _lease = null;
    _retired[lease.generation] = true;
    lease.repository.revoke();
    _retire(lease.transport);
    _notify();
  }

  void _retire(OwnedAiTextTransport transport) {
    final drain = _Drain();
    _retiring = drain; // Install before supplied revoke/close can reenter.
    try {
      transport.revoke();
    } on Object {
      _failed = true;
    }
    unawaited(
      Future<void>.sync(transport.close).then<void>(
        (_) => _finishDrain(drain),
        onError: (Object _, StackTrace _) {
          _failed =
              true; // Unknown cleanup cannot authorize a fresh capability.
          _finishDrain(drain);
        },
      ),
    );
  }

  void _finishDrain(_Drain drain) {
    if (identical(_retiring, drain)) _retiring = null;
    drain.done.complete();
    _notify();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> close() => _closing ??= () async {
    _closed = true;
    invalidate();
    // A reentrant close during construction must also drain that orphan.
    while (_creating != null || _retiring != null) {
      final creating = _creating;
      final retiring = _retiring;
      await Future.wait<void>([
        if (creating != null) creating.future,
        if (retiring != null) retiring.done.future,
      ]);
    }
    // A paused UI listener must not hold SDK/resource shutdown open.
    unawaited(_changes.close());
    if (_failed) throw const AiTextFailure(AiTextErrorCode.internalError);
  }();
}

final class _Lease {
  const _Lease(
    this.generation,
    this.auth,
    this.session,
    this.transport,
    this.repository,
  );
  final AiTextGeneration generation;
  final ReviewAuth auth;
  final ReviewSession session;
  final OwnedAiTextTransport transport;
  final CapturedAiTextRepository repository;
}

final class _Drain {
  final done = Completer<void>();
}
