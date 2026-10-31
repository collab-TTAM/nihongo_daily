import 'dart:async';
import '../../auth/application/account_controller.dart';
import '../../srs/data/review_repository.dart';
import '../data/ai_text_repository_source.dart';
import '../data/ai_conversation_source.dart';
import '../data/ai_conversation_scenario_source.dart';
import '../data/captured_ai_text_repository.dart';
import '../data/captured_conversation_session.dart';
import '../data/captured_conversation_scenarios.dart';
import '../data/conversation_receipt_store.dart';
import 'ai_text_runtime_owner.dart';
import 'receipt_ai_runtime_owner.dart';

/// Explicit single-partition composition. Owns receipt lifecycle; borrows account,
/// SDK and trusted runtime-to-Auth accessor. Host must bind the transport/store to
/// the same configured project and await cleanup before replacing this owner.
final class AccountReceiptAiRuntime<T extends Object>
    implements
        AiTextRepositorySource,
        AiConversationSource,
        AiConversationScenarioSource {
  AccountReceiptAiRuntime({
    required AccountController<T> account,
    required ReviewAuth Function(T runtime) authForRuntime,
    required ConversationReceiptStore store,
    required ReceiptAiTransportFactory createTransport,
  }) : _account = account,
       _authForRuntime = authForRuntime,
       _ownerId = store.scope.ownerId,
       _owner = ReceiptAiRuntimeOwner(
         store: store,
         createTransport: createTransport,
       ) {
    _subscription = _account.changes.listen(
      (_) => _sync(),
      onError: (Object _, StackTrace _) => _break(),
      onDone: _break,
    );
  }
  final AccountController<T> _account;
  final ReviewAuth Function(T runtime) _authForRuntime;
  final String _ownerId;
  final ReceiptAiRuntimeOwner _owner;
  late final StreamSubscription<AccountState> _subscription;
  T? _readyRuntime;
  ReviewSession? _session;
  ReviewAuth? _auth;
  AiTextGeneration? _generation;
  bool _syncing = false;
  bool _stopped = false;
  bool _broken = false;
  Future<void>? _canceling;

  @override
  Stream<void> get aiTextChanges => _owner.runtime.changes;
  @override
  Stream<void> get aiConversationChanges => _owner.runtime.changes;
  @override
  Stream<void> get aiConversationScenarioChanges => _owner.runtime.changes;

  void _break() {
    _broken = true;
    _owner.runtime.invalidate();
  }

  void _sync() {
    if (_syncing) return;
    _syncing = true;
    try {
      final ready = !_stopped && !_broken ? _account.readyRuntime : null;
      final session = ready == null ? null : _account.readySession;
      if (!identical(ready, _readyRuntime) || !identical(session, _session)) {
        _owner.runtime
            .invalidate(); // Before invoking a trusted external accessor.
        _readyRuntime = ready;
        _session = session;
        _auth = null;
        _generation = null;
        if (ready != null && session != null && session.userId == _ownerId) {
          try {
            final auth = _authForRuntime(ready);
            if (_matches(ready, session) &&
                identical(auth.currentSession, session) &&
                _matches(ready, session)) {
              _auth = auth;
              _generation = AiTextGeneration();
            }
          } on Object {
            _break(); // No supplied getter details escape as availability state.
          }
        }
      }
      _owner.runtime.check();
    } finally {
      _syncing = false;
    }
  }

  bool _matches(T ready, ReviewSession session) =>
      !_stopped &&
      !_broken &&
      session.userId == _ownerId &&
      identical(_readyRuntime, ready) &&
      identical(_session, session) &&
      identical(_account.readyRuntime, ready) &&
      identical(_account.readySession, session);

  bool _prepare() {
    if (_syncing) return false;
    _sync();
    return _auth != null && _generation != null && _session != null;
  }

  @override
  CapturedAiTextRepository? createAiTextRepository() {
    if (!_prepare()) return null;
    final ready = _readyRuntime!;
    final session = _session!;
    return _owner.runtime.acquire(
      auth: _auth!,
      generation: _generation!,
      isReady: () => _matches(ready, session),
    );
  }

  @override
  CapturedConversationSession? createAiConversationSession() {
    if (!_prepare()) return null;
    final ready = _readyRuntime!;
    final session = _session!;
    return _owner.runtime.acquireConversation(
      auth: _auth!,
      generation: _generation!,
      isReady: () => _matches(ready, session),
    );
  }

  @override
  CapturedConversationScenarios? createAiConversationScenarios() {
    if (!_prepare()) return null;
    final ready = _readyRuntime!;
    final session = _session!;
    return _owner.runtime.acquireScenarios(
      auth: _auth!,
      generation: _generation!,
      isReady: () => _matches(ready, session),
    );
  }

  Future<void> _stop(Future<void> Function() action) {
    _stopped = true;
    // Delegate chooses preserve/clear mode and revokes BEFORE any async cleanup.
    final pending = action();
    _canceling ??= _subscription.cancel();
    return Future.wait<void>([pending, _canceling!]).then<void>(
      (_) {},
      onError: (Object _, StackTrace _) =>
          throw const AiTextFailure(AiTextErrorCode.internalError),
    );
  }

  /// Preserve metadata, drain actual work and release this partition. Borrowed
  /// account/Auth remain owned by host. Cannot bypass a failed explicit clear.
  Future<void> close() => _stop(_owner.close);

  /// Local metadata cleanup only, after actual drain. Host independently revokes
  /// account/Auth and awaits BOTH operations before reporting successful logout.
  /// Failure retains store ownership; only an explicit repeat retries the clear.
  Future<void> clearForSignOut() => _stop(_owner.signOut);
}
