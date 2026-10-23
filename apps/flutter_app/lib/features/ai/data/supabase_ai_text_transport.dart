import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import '../../srs/data/review_repository.dart';
import '../../srs/data/supabase_review_binding.dart';
import '../application/ai_text_runtime_owner.dart';
import '../domain/ai_text_models.dart';
import 'captured_ai_text_repository.dart';

/// Explicit owner-created capability, never installed by the default app.
/// Borrows SDK/Auth and captures one exact SDK Session/token plus ready generation.
/// The server still verifies the JWT; local claims are only fail-closed hints.
final class SupabaseAiTextTransport implements OwnedAiTextTransport {
  SupabaseAiTextTransport({
    required SupabaseClient client,
    required ReviewAuth auth,
    required bool Function() isReady,
    required String projectUrl,
    required String publishableKey,
    http.Client? httpClient,
    DateTime Function()? now,
    Duration timeout = const Duration(seconds: 15),
  }) : _client = client,
       _auth = auth,
       _ready = isReady,
       _origin = SupabaseReviewBinding.validateProjectUrl(projectUrl),
       _key = SupabaseReviewBinding.validatePublicKey(publishableKey),
       _now = now ?? DateTime.now,
       _timeout = timeout {
    if (timeout <= Duration.zero || timeout > const Duration(seconds: 15)) {
      throw ArgumentError('Expected timeout in (0,15 seconds]');
    }
    if (client.rest.url != '$_origin/rest/v1' ||
        client.auth.headers['apikey'] != _key) {
      throw ArgumentError('Supabase endpoint mismatch');
    }
    try {
      _session = auth.currentSession!;
      _sdkSession = client.auth.currentSession!;
      _token = _captureToken(_sdkSession, _session, _now());
      _requireCurrent();
    } on Object {
      throw const AiTextFailure(AiTextErrorCode.unauthorized);
    }
    // Allocate owned HTTP resources only after all construction guards succeed.
    _http = httpClient ?? http.Client();
    _ownsHttp = httpClient == null;
    _subscription = client.auth.onAuthStateChange.listen(
      (_) {
        if (!isCurrent) revoke();
      },
      onError: (Object _, StackTrace _) => revoke(),
      onDone: revoke,
    );
  }

  static const maxRequestBytes = 32768;
  static const maxResponseBytes = 1024 * 1024;
  static const maxResponseReads = 4096;
  final SupabaseClient _client;
  final ReviewAuth _auth;
  final bool Function() _ready;
  final String _origin;
  final String _key;
  final DateTime Function() _now;
  final Duration _timeout;
  late final ReviewSession _session;
  late final Session _sdkSession;
  late final _Token _token;
  late final http.Client _http;
  late final bool _ownsHttp;
  StreamSubscription<AuthState>? _subscription;
  _Attempt? _active;
  bool _revoked = false;
  Future<void>? _closing;

  bool get isBusy => _active != null;
  @override
  bool get isCurrent {
    if (_revoked) return false;
    try {
      if (_ready() &&
          identical(_auth.currentSession, _session) &&
          identical(_client.auth.currentSession, _sdkSession) &&
          _sdkSession.accessToken == _token.value &&
          _now().toUtc().isBefore(_token.expiresAt) &&
          _ready()) {
        return true;
      }
    } on Object {
      /* Fail closed without raw SDK/getter detail. */
    }
    revoke();
    return false;
  }

  /// Owner calls this synchronously on vault/profile/runtime readiness loss.
  /// SDK session changes are also observed; no sign-out or token writer is added.
  @override
  void revoke() {
    _revoked = true;
    _active?.stop();
  }

  /// Borrowed clients remain owned by the caller. Drain may wait for a custom
  /// client that ignores abort/cancellation; it never silently permits overlap.
  @override
  Future<void> close() => _closing ??= () async {
    revoke();
    final active = _active;
    await _subscription?.cancel();
    _subscription = null;
    if (_ownsHttp) _http.close();
    await active?.drained.future;
  }();

  @override
  Future<Object?> tutorExplain({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) => _send('tutor_explain', capturedSession, body);

  @override
  Future<Object?> correctSentence({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) => _send('correct_sentence', capturedSession, body);

  void _requireCurrent() {
    if (!isCurrent) throw const AiTextFailure(AiTextErrorCode.unauthorized);
  }

  Future<Object?> _send(
    String operation,
    ReviewSession session,
    Map<String, Object> body,
  ) async {
    _requireCurrent();
    if (!identical(session, _session)) {
      throw const AiTextFailure(AiTextErrorCode.unauthorized);
    }
    if (isBusy) throw const AiTextRequestPending();
    // Register before caller-supplied map getters or HTTP can reenter.
    late final _Attempt attempt;
    attempt = _Attempt(_timeout, () {
      if (identical(_active, attempt)) _active = null;
    }, revoke);
    _active = attempt;
    http.StreamedResponse? response;
    StreamIterator<List<int>>? iterator;
    var bodyComplete = false;
    void guard() {
      _requireCurrent();
      if (attempt.stopped || attempt.elapsed.elapsed >= _timeout) {
        attempt.stop();
        throw const AiTextFailure(AiTextErrorCode.networkUnavailable);
      }
    }

    try {
      final requestBody = _requestBody(operation, body);
      if (requestBody.length > maxRequestBytes) {
        throw const AiTextFailure(AiTextErrorCode.validationFailure);
      }
      final request =
          http.AbortableRequest(
              'POST',
              Uri.parse('$_origin/functions/v1/$operation'),
              abortTrigger: attempt.abort.future,
            )
            ..followRedirects = false
            ..maxRedirects = 0
            ..headers.addAll({
              'apikey': _key,
              'authorization': 'Bearer ${_token.value}',
              'content-type': 'application/json; charset=utf-8',
              'accept': 'application/json',
              'cache-control': 'no-store',
            })
            ..bodyBytes = requestBody;
      guard(); // Immediately before actual dispatch: never consult current token.
      attempt.headerPending = true;
      final pending = Future<http.StreamedResponse>.sync(
        () => _http.send(request),
      );
      unawaited(
        pending.then<void>(
          (lateResponse) {
            attempt.headerPending = false;
            if (attempt.stopped) attempt.discard(lateResponse.stream);
            attempt.release();
          },
          onError: (Object _, StackTrace _) {
            attempt.headerPending = false;
            attempt.release();
          },
        ),
      );
      response = await attempt.wait<http.StreamedResponse>(pending);
      guard();
      if (response.isRedirect ||
          response.statusCode >= 300 && response.statusCode < 400) {
        throw const AiTextFailure(AiTextErrorCode.internalError);
      }
      // Status identity errors take precedence even for an invalid gateway body.
      if (response.statusCode == 401) {
        revoke();
        throw const AiTextFailure(AiTextErrorCode.unauthorized);
      }
      final type = _header(response.headers, 'content-type') ?? '';
      final encoding = _header(response.headers, 'content-encoding');
      if (!RegExp(
            r'^application/json(?:\s*;\s*charset=utf-8)?$',
            caseSensitive: false,
          ).hasMatch(type) ||
          encoding != null && encoding.toLowerCase() != 'identity') {
        throw _httpFailure(response.statusCode);
      }
      final length = _header(response.headers, 'content-length');
      if (length != null &&
          !RegExp(r'^(0|[1-9][0-9]{0,9})$').hasMatch(length)) {
        throw const AiTextFailure(AiTextErrorCode.internalError);
      }
      final declared = length == null
          ? response.contentLength
          : int.parse(length);
      if (declared != null && (declared < 0 || declared > maxResponseBytes) ||
          response.contentLength != null &&
              declared != response.contentLength) {
        throw const AiTextFailure(AiTextErrorCode.internalError);
      }
      final bytes = BytesBuilder(copy: false);
      iterator = StreamIterator(response.stream);
      var reads = 0;
      while (true) {
        guard();
        if (++reads > maxResponseReads) throw const FormatException();
        final more = await attempt.wait(iterator.moveNext());
        guard();
        if (!more) {
          bodyComplete = true;
          break;
        }
        final chunk = iterator.current;
        if (bytes.length + chunk.length > maxResponseBytes) {
          throw const FormatException();
        }
        bytes.add(chunk);
      }
      if (declared != null && bytes.length != declared) {
        throw const FormatException();
      }
      final raw = _decodeJson(bytes.takeBytes());
      guard();
      if (response.statusCode != 200) {
        throw _httpFailure(response.statusCode, raw);
      }
      final result = operation == 'tutor_explain'
          ? TutorExplanation.fromJson(raw).toJson()
          : SentenceCorrection.fromJson(raw).toJson();
      guard();
      return result;
    } on AiTextFailure {
      _requireCurrent();
      rethrow;
    } on http.ClientException {
      _requireCurrent();
      throw const AiTextFailure(AiTextErrorCode.networkUnavailable);
    } on Object {
      _requireCurrent();
      throw const AiTextFailure(AiTextErrorCode.internalError);
    } finally {
      Future<void>? cleanup;
      if (iterator != null && !bodyComplete) {
        cleanup = Future<void>.sync(iterator.cancel);
        attempt.cancel(cleanup);
      } else if (response != null) {
        if (!bodyComplete) cleanup = attempt.discard(response.stream);
      }
      // Normal cancellation settles before returning when it cooperates. A
      // stalled cancel is bounded by the same deadline and keeps the busy lease.
      if (cleanup != null && !attempt.stopped) {
        try {
          await attempt.wait<void>(cleanup);
        } on Object {
          /* Retain original safe outcome. */
        }
      }
      attempt.finish();
    }
  }
}

final class _Token {
  const _Token(this.value, this.expiresAt);
  final String value;
  final DateTime expiresAt;
}

_Token _captureToken(Session session, ReviewSession owner, DateTime now) {
  final token = session.accessToken;
  if (session.tokenType.toLowerCase() != 'bearer' ||
      token.length > 8192 ||
      token.contains(RegExp(r'\s'))) {
    throw const FormatException();
  }
  final parts = token.split('.');
  if (parts.length != 3 || parts.any((p) => p.isEmpty)) {
    throw const FormatException();
  }
  final payload = _decodeJson(base64Url.decode(base64Url.normalize(parts[1])));
  if (payload is! Map<String, Object?> ||
      payload['role'] != 'authenticated' ||
      payload['sub'] is! String ||
      payload['session_id'] is! String ||
      payload['exp'] is! int) {
    throw const FormatException();
  }
  final user = ReviewSession(userId: session.user.id).userId;
  ReviewSession(userId: payload['session_id']! as String);
  final exp = payload['exp']! as int;
  if ((payload['sub']! as String).toLowerCase() != user ||
      owner.userId != user ||
      exp < 1 ||
      exp > 253402300799) {
    throw const FormatException();
  }
  final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  if (!now.toUtc().isBefore(expiry)) throw const FormatException();
  return _Token(token, expiry);
}

List<int> _requestBody(String operation, Map<String, Object> body) {
  try {
    final level = AiTextLevel.values.singleWhere(
      (l) => l.wireName == body['jlpt_level'],
    );
    final Map<String, Object> validated;
    if (operation == 'tutor_explain') {
      if (body.length != 3 ||
          !body.keys.toSet().containsAll({
            'jlpt_level',
            'question_vi',
            'context',
          })) {
        throw const FormatException();
      }
      final context = body['context'];
      if (context is! Map<String, Object?> ||
          context.length != 2 ||
          !context.keys.toSet().containsAll({
            'recent_grammar_ids',
            'recent_vocabulary_ids',
          })) {
        throw const FormatException();
      }
      validated = TutorExplainRequest(
        level: level,
        questionVi: body['question_vi']! as String,
        recentGrammarIds: (context['recent_grammar_ids']! as List<Object?>)
            .cast<String>(),
        recentVocabularyIds:
            (context['recent_vocabulary_ids']! as List<Object?>).cast<String>(),
      ).toJson();
    } else {
      if (body.length != 2 ||
          !body.keys.toSet().containsAll({'jlpt_level', 'sentence_ja'})) {
        throw const FormatException();
      }
      validated = CorrectSentenceRequest(
        level: level,
        sentenceJa: body['sentence_ja']! as String,
      ).toJson();
    }
    return utf8.encode(jsonEncode(validated));
  } on Object {
    throw const AiTextFailure(AiTextErrorCode.validationFailure);
  }
}

String? _header(Map<String, String> headers, String name) {
  final matches = headers.entries
      .where((e) => e.key.toLowerCase() == name)
      .toList();
  if (matches.length > 1) throw const FormatException();
  return matches.isEmpty ? null : matches.single.value;
}

AiTextFailure _httpFailure(int status, [Object? raw]) {
  if (raw is Map<String, Object?> &&
      raw.length == 3 &&
      raw['message_vi'] is String &&
      (raw['message_vi']! as String).isNotEmpty &&
      (raw['message_vi']! as String).length <= 1000 &&
      (raw['message_vi']! as String).runes.length <= 500 &&
      raw['retryable'] is bool) {
    for (final code in AiTextErrorCode.values) {
      final expected = switch (code) {
        AiTextErrorCode.unauthorized => 401,
        AiTextErrorCode.forbidden => 403,
        AiTextErrorCode.notFound => 404,
        AiTextErrorCode.validationFailure => 400,
        AiTextErrorCode.rateLimited => 429,
        AiTextErrorCode.syncConflict => 409,
        AiTextErrorCode.networkUnavailable ||
        AiTextErrorCode.providerUnavailable => 503,
        AiTextErrorCode.internalError => 500,
      };
      if (raw['code'] == code.wireName && status == expected) {
        final transient =
            code == AiTextErrorCode.networkUnavailable ||
            code == AiTextErrorCode.providerUnavailable ||
            code == AiTextErrorCode.rateLimited;
        return AiTextFailure(
          code,
          retryable: transient && raw['retryable'] == true,
        );
      }
    }
  }
  final code = switch (status) {
    401 => AiTextErrorCode.unauthorized,
    403 => AiTextErrorCode.forbidden,
    404 => AiTextErrorCode.notFound,
    400 || 413 || 415 => AiTextErrorCode.validationFailure,
    409 => AiTextErrorCode.syncConflict,
    429 => AiTextErrorCode.rateLimited,
    408 || 499 || >= 500 => AiTextErrorCode.networkUnavailable,
    _ => AiTextErrorCode.internalError,
  };
  // No automatic retry; uncertain requests may already have incurred provider cost.
  return AiTextFailure(code);
}

/// Preflight bounded JSON nesting and duplicate (including escaped) keys before
/// dart:convert can overwrite them. dart:convert still validates full grammar.
Object? _decodeJson(List<int> bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 239 &&
      bytes[1] == 187 &&
      bytes[2] == 191) {
    throw const FormatException();
  }
  final text = utf8.decode(bytes, allowMalformed: false);
  final stack = <_JsonFrame>[];
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (c == 34) {
      final start = i++;
      while (i < text.length && text.codeUnitAt(i) != 34) {
        if (text.codeUnitAt(i) == 92) i++;
        i++;
      }
      if (i >= text.length) throw const FormatException();
      if (stack.isNotEmpty && stack.last.expectKey) {
        final key = jsonDecode(text.substring(start, i + 1)) as String;
        if (!stack.last.keys.add(key)) throw const FormatException();
        stack.last.expectKey = false;
      }
    } else if (c == 123 || c == 91) {
      if (stack.length >= 16) throw const FormatException();
      stack.add(_JsonFrame(c == 123));
    } else if (c == 125 || c == 93) {
      if (stack.isEmpty) throw const FormatException();
      stack.removeLast();
    } else if (c == 44 && stack.isNotEmpty) {
      stack.last.expectKey = stack.last.object;
    }
  }
  if (stack.isNotEmpty) throw const FormatException();
  return jsonDecode(text);
}

final class _JsonFrame {
  _JsonFrame(this.object) : expectKey = object;
  final bool object;
  bool expectKey;
  final keys = <String>{};
}

final class _Attempt {
  _Attempt(Duration timeout, this.onDrained, this.onCleanupFailure) {
    timer = Timer(timeout, stop);
  }
  final void Function() onDrained;
  final void Function() onCleanupFailure;
  final elapsed = Stopwatch()..start();
  final abort = Completer<void>();
  final drained = Completer<void>();
  final stops = StreamController<void>.broadcast(sync: true);
  late final Timer timer;
  bool stopped = false;
  bool headerPending = false;
  bool finished = false;
  int cleanups = 0;
  Future<void> discard(Stream<List<int>> stream) {
    final cleanup = Future<void>.sync(
      () =>
          stream.listen((_) {}, onError: (Object _, StackTrace _) {}).cancel(),
    );
    cancel(cleanup);
    return cleanup;
  }

  void stop() {
    if (stopped) return;
    stopped = true;
    timer.cancel();
    abort.complete();
    stops.add(null);
  }

  Future<T> wait<T>(Future<T> pending) async {
    if (stopped) throw const AiTextFailure(AiTextErrorCode.networkUnavailable);
    final result = Completer<T>();
    final subscription = stops.stream.listen((_) {
      if (!result.isCompleted) {
        result.completeError(
          const AiTextFailure(AiTextErrorCode.networkUnavailable),
        );
      }
    });
    unawaited(
      pending.then<void>(
        (value) {
          if (!result.isCompleted) result.complete(value);
        },
        onError: (Object error, StackTrace trace) {
          if (!result.isCompleted) result.completeError(error, trace);
        },
      ),
    );
    try {
      return await result.future;
    } finally {
      await subscription.cancel();
    }
  }

  void cancel(Future<void> cleanup) {
    cleanups++;
    unawaited(
      cleanup.then<void>(
        (_) {
          cleanups--;
          release();
        },
        onError: (Object _, StackTrace _) {
          // A failed cancellation cannot authorize another call on this port.
          onCleanupFailure();
          cleanups--;
          release();
        },
      ),
    );
  }

  void finish() {
    finished = true;
    stop();
    release();
  }

  void release() {
    if (finished && !headerPending && cleanups == 0 && !drained.isCompleted) {
      onDrained();
      drained.complete();
      unawaited(stops.close());
    }
  }
}
