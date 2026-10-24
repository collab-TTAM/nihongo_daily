import 'dart:async';
import '../../srs/data/review_repository.dart';
import '../domain/conversation_requests.dart';
import '../domain/conversation_responses.dart';
import 'captured_ai_text_repository.dart';

/// Borrowed trusted port. Must bind captured credentials/ready generation and
/// bounded HTTP/JSON immediately before dispatch. No global user client/retries.
abstract interface class ConversationMutationTransport {
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String operation,
    required Map<String, Object> body,
  });
}

/// One immutable event, not a global conversation coordinator or durable receipt.
/// Caller must retain this object for uncertain retry; never rebuild with a new ID.
final class CapturedConversationMutation<T extends Object> {
  CapturedConversationMutation._({
    required ReviewAuth auth,
    required ConversationMutationTransport transport,
    required bool Function() isReady,
    required String operation,
    required Map<String, Object> body,
    required T Function(Object?) decode,
    required Duration timeout,
  }) : _auth = auth,
       _transport = transport,
       _ready = isReady,
       _operation = operation,
       _body = Map.unmodifiable(body),
       _decode = decode,
       _timeout = timeout,
       _session = _capture(auth) {
    if (timeout <= Duration.zero || timeout > const Duration(seconds: 15)) {
      throw ArgumentError('Expected timeout in (0,15 seconds]');
    }
    _requireCurrent();
  }
  static CapturedConversationMutation<StartConversationResponse> start({
    required ReviewAuth auth,
    required ConversationMutationTransport transport,
    required bool Function() isReady,
    required StartConversationRequest request,
    Duration timeout = const Duration(seconds: 15),
  }) => CapturedConversationMutation._(
    auth: auth,
    transport: transport,
    isReady: isReady,
    operation: 'start_conversation',
    body: request.toJson(),
    decode: StartConversationResponse.fromJson,
    timeout: timeout,
  );
  static CapturedConversationMutation<ConversationTurnResponse> turn({
    required ReviewAuth auth,
    required ConversationMutationTransport transport,
    required bool Function() isReady,
    required ConversationTurnRequest request,
    Duration timeout = const Duration(seconds: 15),
  }) => CapturedConversationMutation._(
    auth: auth,
    transport: transport,
    isReady: isReady,
    operation: 'conversation_turn',
    body: request.toJson(),
    decode: ConversationTurnResponse.fromJson,
    timeout: timeout,
  );
  static CapturedConversationMutation<FinishConversationResponse> finish({
    required ReviewAuth auth,
    required ConversationMutationTransport transport,
    required bool Function() isReady,
    required FinishConversationRequest request,
    Duration timeout = const Duration(seconds: 15),
  }) => CapturedConversationMutation._(
    auth: auth,
    transport: transport,
    isReady: isReady,
    operation: 'finish_conversation',
    body: request.toJson(),
    decode: FinishConversationResponse.fromJson,
    timeout: timeout,
  );
  final ReviewAuth _auth;
  final ConversationMutationTransport _transport;
  final bool Function() _ready;
  final String _operation;
  final Map<String, Object> _body;
  final T Function(Object?) _decode;
  final Duration _timeout;
  final ReviewSession _session;
  Object? _inFlight;
  T? _accepted;
  bool _revoked = false;
  bool get isBusy => _inFlight != null;
  bool get isCurrent {
    if (_revoked) return false;
    try {
      if (_ready() && identical(_auth.currentSession, _session) && _ready()) {
        return true;
      }
    } on Object {
      /* Safe fail closed. */
    }
    revoke();
    return false;
  }

  void revoke() {
    _revoked = true;
    _accepted = null;
  }

  void _requireCurrent() {
    if (!isCurrent) {
      throw const AiTextFailure(AiTextErrorCode.unauthorized);
    }
  }

  /// Explicit send/retry of the same captured wire. Completed success is reused
  /// locally; uncertain timeout is not success and stays busy until actual drain.
  Future<T> submit() async {
    _requireCurrent();
    final accepted = _accepted;
    if (accepted != null) return accepted;
    if (isBusy) throw const AiTextRequestPending();
    final ticket = Object();
    _inFlight = ticket;
    var finished = false;
    var settled = false;
    void release() {
      if (finished && settled && identical(_inFlight, ticket)) {
        _inFlight = null;
      }
    }

    final operation = Future<Object?>.sync(() {
      _requireCurrent();
      return _transport.invoke(
        capturedSession: _session,
        operation: _operation,
        body: _body,
      );
    });
    unawaited(
      operation.then<void>(
        (_) {
          settled = true;
          release();
        },
        onError: (Object _, StackTrace _) {
          settled = true;
          release();
        },
      ),
    );
    try {
      final value = await operation.timeout(_timeout);
      _requireCurrent();
      final failure = _serverFailure(value);
      if (failure != null) {
        throw failure;
      }
      final result = _decode(value);
      _requireCurrent();
      _accepted = result;
      return result;
    } on AiTextRequestPending {
      _requireCurrent();
      rethrow;
    } on AiTextFailure catch (e) {
      _requireCurrent();
      if (e.code == AiTextErrorCode.unauthorized) {
        revoke();
      }
      throw _safeFailure(e.code, e.retryable);
    } on TimeoutException {
      _requireCurrent();
      throw const AiTextFailure(
        AiTextErrorCode.networkUnavailable,
        retryable: true,
      );
    } on Object {
      _requireCurrent();
      throw const AiTextFailure(AiTextErrorCode.internalError);
    } finally {
      finished = true;
      release();
    }
  }
}

ReviewSession _capture(ReviewAuth auth) {
  try {
    final session = auth.currentSession;
    if (session != null) return session;
  } on Object {
    /* No SDK details. */
  }
  throw const AiTextFailure(AiTextErrorCode.unauthorized);
}

AiTextFailure _safeFailure(AiTextErrorCode code, bool retryable) {
  final transient =
      code == AiTextErrorCode.networkUnavailable ||
      code == AiTextErrorCode.providerUnavailable ||
      code == AiTextErrorCode.rateLimited;
  return AiTextFailure(code, retryable: retryable && transient);
}

AiTextFailure? _serverFailure(Object? value) {
  if (value is! Map<String, Object?> || !value.containsKey('code')) return null;
  final message = value['message_vi'];
  final retryable = value['retryable'];
  final codes = AiTextErrorCode.values.where(
    (c) => c.wireName == value['code'],
  );
  if (value.length != 3 ||
      codes.length != 1 ||
      message is! String ||
      message.isEmpty ||
      message.length > 1000 ||
      message.runes.length > 500 ||
      retryable is! bool) {
    return const AiTextFailure(AiTextErrorCode.internalError);
  }
  return _safeFailure(codes.single, retryable);
}
