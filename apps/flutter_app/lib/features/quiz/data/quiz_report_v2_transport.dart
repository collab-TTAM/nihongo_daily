import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../shared/network/strict_json.dart';
import '../../srs/data/supabase_review_binding.dart';
import 'quiz_report_v2_adapter.dart';

/// A short-lived snapshot from the caller-owned Supabase Auth lifecycle.
/// [generation] must change whenever the access token or account lifecycle changes.
final class QuizReportV2CapturedSession {
  const QuizReportV2CapturedSession({
    required this.userId,
    required this.accessToken,
    required this.generation,
  });

  final String userId;
  final String accessToken;
  final int generation;
}

abstract interface class QuizReportV2Auth {
  QuizReportV2CapturedSession? capture();
  bool isCurrent(QuizReportV2CapturedSession captured);
  Stream<void> get sessionChanges;
}

enum QuizReportV2TransportCode {
  unauthorized('UNAUTHORIZED', false),
  forbidden('FORBIDDEN', false),
  notFound('NOT_FOUND', false),
  validationFailure('VALIDATION_FAILURE', false),
  syncConflict('SYNC_CONFLICT', false),
  rateLimited('RATE_LIMITED', true),
  networkUnavailable('NETWORK_UNAVAILABLE', true),
  providerUnavailable('PROVIDER_UNAVAILABLE', true),
  internalError('INTERNAL_ERROR', false);

  const QuizReportV2TransportCode(this.wireCode, this.retryable);

  final String wireCode;
  final bool retryable;

  Set<int> get statuses => switch (this) {
    QuizReportV2TransportCode.unauthorized => {401},
    QuizReportV2TransportCode.forbidden => {403},
    QuizReportV2TransportCode.notFound => {404},
    QuizReportV2TransportCode.validationFailure => {400, 405, 413, 415},
    QuizReportV2TransportCode.syncConflict => {409},
    QuizReportV2TransportCode.rateLimited => {429},
    QuizReportV2TransportCode.networkUnavailable => {503},
    QuizReportV2TransportCode.providerUnavailable => {503},
    QuizReportV2TransportCode.internalError => {500},
  };

  String get messageVi => switch (this) {
    QuizReportV2TransportCode.unauthorized =>
      'Phiên đăng nhập không còn hợp lệ. Hãy đăng nhập lại.',
    QuizReportV2TransportCode.forbidden =>
      'Tài khoản hiện tại không được phép thực hiện thao tác này.',
    QuizReportV2TransportCode.notFound =>
      'Dịch vụ lưu kết quả chưa được cấu hình.',
    QuizReportV2TransportCode.validationFailure =>
      'Dữ liệu lượt kiểm tra không hợp lệ.',
    QuizReportV2TransportCode.syncConflict =>
      'Lượt kiểm tra đã có kết quả khác. Hãy tải lại lịch sử.',
    QuizReportV2TransportCode.rateLimited =>
      'Bạn thao tác quá nhanh. Hãy đợi một chút rồi thử lại.',
    QuizReportV2TransportCode.networkUnavailable =>
      'Chưa xác nhận được kết quả lưu. Hãy kiểm tra lịch sử trước khi gửi lại cùng mã lượt.',
    QuizReportV2TransportCode.providerUnavailable =>
      'Dịch vụ hiện tạm thời không khả dụng. Hãy kiểm tra lịch sử trước khi gửi lại.',
    QuizReportV2TransportCode.internalError =>
      'Không thể xác nhận kết quả. Vui lòng thử lại sau khi kiểm tra lịch sử.',
  };
}

final class QuizReportV2TransportFailure implements Exception {
  const QuizReportV2TransportFailure(this.code);

  final QuizReportV2TransportCode code;

  String get messageVi => code.messageVi;
  bool get retryable => code.retryable;

  @override
  String toString() => 'QuizReportV2TransportFailure(${code.wireCode})';
}

/// Opt-in HTTP transport only. It never changes local history or marks an
/// attempt saved. The caller owns Auth readiness and must retain the original
/// immutable report/event ID after an uncertain timeout or connection failure.
final class QuizReportV2HttpTransport {
  QuizReportV2HttpTransport({
    required String projectUrl,
    required String publishableKey,
    required QuizReportV2Auth auth,
    http.Client? client,
    Duration timeout = const Duration(seconds: 15),
  }) : _origin = SupabaseReviewBinding.validateProjectUrl(projectUrl),
       _publishableKey = SupabaseReviewBinding.validatePublicKey(
         publishableKey,
       ),
       _auth = auth,
       _timeout = _validateTimeout(timeout),
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  static Duration _validateTimeout(Duration value) {
    if (value <= Duration.zero || value > const Duration(seconds: 15)) {
      throw ArgumentError.value(value, 'timeout');
    }
    return value;
  }

  static const int maxResponseBytes = 16 * 1024;
  static final RegExp _jsonContentType = RegExp(
    r'^application/json(?:\s*;\s*charset=utf-8)?$',
    caseSensitive: false,
  );
  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  final String _origin;
  final String _publishableKey;
  final QuizReportV2Auth _auth;
  final Duration _timeout;
  final http.Client _client;
  final bool _ownsClient;
  final Set<void Function()> _activeAborts = {};
  final Set<Completer<void>> _activeOperations = {};
  Future<void>? _closing;
  bool _closed = false;

  Uri get _submitEndpoint =>
      Uri.parse(_origin).replace(path: '/functions/v1/quiz-report-v2');
  Uri get _lookupEndpoint =>
      Uri.parse(_origin).replace(path: '/functions/v1/quiz-report-v2-lookup');

  Future<QuizReportV2Response> submit(QuizReportV2Request report) =>
      _send<QuizReportV2Response>(
        report,
        endpoint: _submitEndpoint,
        decodeSuccess: report.decodeResponse,
      );

  /// Replay-only lookup of the exact original request. It never submits or
  /// retries; unresolved remains unknown until a later explicit reconciliation.
  Future<QuizReportV2LookupResult> lookupReceipt(QuizReportV2Request report) =>
      _send<QuizReportV2LookupResult>(
        report,
        endpoint: _lookupEndpoint,
        decodeSuccess: report.decodeLookupResponse,
      );

  Future<T> _send<T>(
    QuizReportV2Request report, {
    required Uri endpoint,
    required T Function(Object?) decodeSuccess,
  }) {
    if (_closed) {
      return Future<T>.error(
        const QuizReportV2TransportFailure(
          QuizReportV2TransportCode.networkUnavailable,
        ),
      );
    }
    final settled = Completer<void>();
    _activeOperations.add(settled);
    return _sendActive<T>(
      report,
      endpoint: endpoint,
      decodeSuccess: decodeSuccess,
    ).whenComplete(() {
      _activeOperations.remove(settled);
      if (!settled.isCompleted) settled.complete();
    });
  }

  Future<T> _sendActive<T>(
    QuizReportV2Request report, {
    required Uri endpoint,
    required T Function(Object?) decodeSuccess,
  }) async {
    if (_closed) {
      throw const QuizReportV2TransportFailure(
        QuizReportV2TransportCode.networkUnavailable,
      );
    }

    late final Uint8List raw;
    try {
      raw = Uint8List.fromList(report.encodeRawBody());
    } on Object {
      throw const QuizReportV2TransportFailure(
        QuizReportV2TransportCode.validationFailure,
      );
    }
    if (raw.isEmpty || raw.length > QuizReportV2Request.maxRawBodyBytes) {
      throw const QuizReportV2TransportFailure(
        QuizReportV2TransportCode.validationFailure,
      );
    }

    late final QuizReportV2CapturedSession captured;
    try {
      final value = _auth.capture();
      if (value == null ||
          !_uuid.hasMatch(value.userId) ||
          value.userId != value.userId.toLowerCase() ||
          !_validToken(value.accessToken) ||
          value.generation < 0 ||
          !_auth.isCurrent(value)) {
        throw const FormatException();
      }
      captured = value;
    } on Object {
      throw const QuizReportV2TransportFailure(
        QuizReportV2TransportCode.unauthorized,
      );
    }

    final abortSignal = Completer<void>();
    void abort() {
      if (!abortSignal.isCompleted) abortSignal.complete();
    }

    _activeAborts.add(abort);
    StreamSubscription<void>? subscription;
    var authStreamClosed = false;
    bool authCurrent() {
      if (authStreamClosed) return false;
      try {
        return _auth.isCurrent(captured);
      } on Object {
        return false;
      }
    }

    void cancelResponse(Stream<List<int>> stream) {
      unawaited(stream.listen((_) {}).cancel());
    }

    void requireCurrent({Stream<List<int>>? responseStream}) {
      if (authStreamClosed || !authCurrent()) {
        abort();
        if (responseStream != null) cancelResponse(responseStream);
        throw const QuizReportV2TransportFailure(
          QuizReportV2TransportCode.unauthorized,
        );
      }
      if (_closed) {
        abort();
        if (responseStream != null) cancelResponse(responseStream);
        throw const QuizReportV2TransportFailure(
          QuizReportV2TransportCode.networkUnavailable,
        );
      }
    }

    final clock = Stopwatch()..start();
    Duration remaining() {
      final value = _timeout - clock.elapsed;
      if (value <= Duration.zero) throw TimeoutException('deadline');
      return value;
    }

    late final T result;
    try {
      subscription = _auth.sessionChanges.listen(
        (_) {
          if (!authCurrent()) abort();
        },
        onError: (Object _, StackTrace __) {
          authStreamClosed = true;
          abort();
        },
        onDone: () {
          authStreamClosed = true;
          abort();
        },
      );
      requireCurrent();

      final outbound =
          http.AbortableRequest(
              'POST',
              endpoint,
              abortTrigger: abortSignal.future,
            )
            ..followRedirects = false
            ..maxRedirects = 0
            ..headers.addAll({
              'accept': 'application/json',
              'content-type': 'application/json; charset=utf-8',
              'apikey': _publishableKey,
              'authorization': 'Bearer ${captured.accessToken}',
            })
            ..bodyBytes = raw;

      final response = await _client
          .send(outbound)
          .timeout(
            remaining(),
            onTimeout: () {
              abort();
              throw TimeoutException('deadline');
            },
          );
      requireCurrent(responseStream: response.stream);

      final actualUrl = response.request?.url;
      if ((actualUrl != null &&
              (actualUrl.origin != endpoint.origin ||
                  actualUrl.path != endpoint.path)) ||
          (response.statusCode >= 300 && response.statusCode < 400)) {
        cancelResponse(response.stream);
        throw const QuizReportV2TransportFailure(
          QuizReportV2TransportCode.internalError,
        );
      }

      if (response.statusCode == 408 ||
          response.statusCode == 502 ||
          response.statusCode == 504) {
        cancelResponse(response.stream);
        throw const QuizReportV2TransportFailure(
          QuizReportV2TransportCode.networkUnavailable,
        );
      }

      final safeJsonHeaders =
          _jsonContentType.hasMatch(response.headers['content-type'] ?? '') &&
          _hasNoStore(response.headers['cache-control']) &&
          response.headers['x-content-type-options']?.toLowerCase() ==
              'nosniff';
      if (!safeJsonHeaders) {
        cancelResponse(response.stream);
        if (response.statusCode != 200) {
          throw _statusFailure(response.statusCode);
        }
        throw const QuizReportV2TransportFailure(
          QuizReportV2TransportCode.internalError,
        );
      }
      final declaredLength = response.contentLength;
      if (declaredLength != null && declaredLength > maxResponseBytes) {
        abort();
        cancelResponse(response.stream);
        throw const QuizReportV2TransportFailure(
          QuizReportV2TransportCode.internalError,
        );
      }

      final responseBytes = await _readBounded(response.stream).timeout(
        remaining(),
        onTimeout: () {
          abort();
          throw TimeoutException('deadline');
        },
      );
      requireCurrent();

      if (response.statusCode == 200) {
        final decoded = decodeStrictJson(responseBytes);
        try {
          result = decodeSuccess(decoded);
        } on Object {
          throw const QuizReportV2TransportFailure(
            QuizReportV2TransportCode.internalError,
          );
        }
      } else {
        throw _decodeFailure(response.statusCode, responseBytes);
      }
    } on QuizReportV2TransportFailure {
      rethrow;
    } on TimeoutException {
      if (_closed) {
        throw const QuizReportV2TransportFailure(
          QuizReportV2TransportCode.networkUnavailable,
        );
      }
      if (authStreamClosed || !authCurrent()) {
        throw const QuizReportV2TransportFailure(
          QuizReportV2TransportCode.unauthorized,
        );
      }
      throw const QuizReportV2TransportFailure(
        QuizReportV2TransportCode.networkUnavailable,
      );
    } on http.ClientException {
      if (_closed) {
        throw const QuizReportV2TransportFailure(
          QuizReportV2TransportCode.networkUnavailable,
        );
      }
      if (authStreamClosed || !authCurrent()) {
        throw const QuizReportV2TransportFailure(
          QuizReportV2TransportCode.unauthorized,
        );
      }
      throw const QuizReportV2TransportFailure(
        QuizReportV2TransportCode.networkUnavailable,
      );
    } on FormatException {
      throw const QuizReportV2TransportFailure(
        QuizReportV2TransportCode.internalError,
      );
    } on Object {
      if (_closed) {
        throw const QuizReportV2TransportFailure(
          QuizReportV2TransportCode.networkUnavailable,
        );
      }
      if (authStreamClosed || !authCurrent()) {
        throw const QuizReportV2TransportFailure(
          QuizReportV2TransportCode.unauthorized,
        );
      }
      throw const QuizReportV2TransportFailure(
        QuizReportV2TransportCode.internalError,
      );
    } finally {
      try {
        await subscription?.cancel();
      } on Object {
        throw const QuizReportV2TransportFailure(
          QuizReportV2TransportCode.internalError,
        );
      } finally {
        _activeAborts.remove(abort);
      }
    }

    // Auth or the transport can retire while listener cleanup is pending.
    requireCurrent();
    return result;
  }

  static bool _validToken(String value) =>
      value.isNotEmpty &&
      value.length <= 8192 &&
      !value.contains(RegExp(r'\s')) &&
      value.codeUnits.every((unit) => unit >= 0x21 && unit <= 0x7e);

  static bool _hasNoStore(String? value) =>
      value != null &&
      value
          .split(',')
          .any((directive) => directive.trim().toLowerCase() == 'no-store');

  static Future<Uint8List> _readBounded(Stream<List<int>> stream) async {
    final iterator = StreamIterator<List<int>>(stream);
    final bytes = BytesBuilder(copy: false);
    var length = 0;
    var completed = false;
    try {
      while (await iterator.moveNext()) {
        final chunk = iterator.current;
        length += chunk.length;
        if (length > maxResponseBytes) throw const FormatException();
        bytes.add(chunk);
      }
      completed = true;
      return bytes.takeBytes();
    } finally {
      if (!completed) await iterator.cancel();
    }
  }

  static QuizReportV2TransportFailure _statusFailure(int status) {
    final code = switch (status) {
      400 || 405 || 413 || 415 => QuizReportV2TransportCode.validationFailure,
      401 => QuizReportV2TransportCode.unauthorized,
      403 => QuizReportV2TransportCode.forbidden,
      404 => QuizReportV2TransportCode.notFound,
      409 => QuizReportV2TransportCode.syncConflict,
      429 => QuizReportV2TransportCode.rateLimited,
      500 => QuizReportV2TransportCode.internalError,
      503 => QuizReportV2TransportCode.networkUnavailable,
      _ => QuizReportV2TransportCode.internalError,
    };
    return QuizReportV2TransportFailure(code);
  }

  static QuizReportV2TransportFailure _decodeFailure(
    int status,
    Uint8List raw,
  ) {
    final value = decodeStrictJson(raw);
    if (value is! Map<String, Object?> ||
        value.length != 3 ||
        !value.keys.toSet().containsAll({'code', 'message_vi', 'retryable'}) ||
        value['message_vi'] is! String ||
        (value['message_vi'] as String).isEmpty ||
        (value['message_vi'] as String).length > 500 ||
        value['retryable'] is! bool) {
      throw const FormatException();
    }
    QuizReportV2TransportCode? code;
    for (final candidate in QuizReportV2TransportCode.values) {
      if (candidate.wireCode == value['code']) {
        code = candidate;
        break;
      }
    }
    if (code == null ||
        !code.statuses.contains(status) ||
        value['retryable'] != code.retryable) {
      throw const FormatException();
    }
    return QuizReportV2TransportFailure(code);
  }

  /// Revoke new calls, abort active requests and drain them before release.
  /// The caller-owned runtime must await this before disposing its Auth observer.
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    for (final abort in _activeAborts.toList()) {
      abort();
    }
    while (_activeOperations.isNotEmpty) {
      await Future.wait(
        _activeOperations.map((operation) => operation.future).toList(),
      );
    }
    if (_ownsClient) {
      try {
        _client.close();
      } on Object {
        // Raw client cleanup details never cross this boundary.
      }
    }
  }

  /// Fire-and-forget compatibility. Resource owners must await [close].
  void dispose() {
    unawaited(close());
  }
}

/// Borrowed from the caller-owned Supabase runtime; callers must not dispose it.
abstract interface class QuizReportV2TransportSource {
  QuizReportV2HttpTransport? get quizReportV2Transport;
}
