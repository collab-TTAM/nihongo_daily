import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nihongo_daily/features/quiz/data/quiz_report_v2_adapter.dart';
import 'package:nihongo_daily/features/quiz/data/quiz_report_v2_transport.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_attempt.dart';

String _id(int value) =>
    'a2000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';

String _event(int value) =>
    'a3000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';

QuizReportV2Request _report() => QuizReportV2Request.fromVocabularyAttempt(
  VocabularyQuizAttempt.fromJson({
    'format_version': 2,
    'event_id': _event(1),
    'level': 'N5',
    'completed_at': '2026-11-10T05:00:00.123456Z',
    'answers': [
      {
        'item_id': _id(1),
        'content_version': 2,
        'selected_id': _id(1),
        'choices': [_id(1), _id(2), _id(3), _id(4)],
        'choice_content_versions': [2, 1, 2, 1],
      },
    ],
  }),
);

Map<String, Object?> _response(QuizReportV2Request report) => {
  'client_event_id': report.clientEventId,
  'quiz_type': report.quizType,
  'practice_kind': report.practiceKind,
  'jlpt_level': report.jlptLevel,
  'completed_at': report.completedAt,
  'answer_count': report.answers.length,
  'correct_count': report.answers.where((answer) => answer.isCorrect).length,
};

const _headers = {
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store',
  'x-content-type-options': 'nosniff',
};

http.Response _success(QuizReportV2Request report) =>
    http.Response(jsonEncode(_response(report)), 200, headers: _headers);

http.Response _lookupFound(QuizReportV2Request report) => http.Response(
  jsonEncode({'status': 'found', 'response': _response(report)}),
  200,
  headers: _headers,
);

final class _FakeAuth implements QuizReportV2Auth {
  _FakeAuth({Future<void> Function()? onCancel})
    : _events = onCancel == null
          ? StreamController<void>.broadcast(sync: true)
          : StreamController<void>(sync: true, onCancel: onCancel);

  final StreamController<void> _events;
  String? token = 'access-token-A';
  String userId = 'a1000000-0000-4000-8000-000000000001';
  int generation = 1;

  @override
  Stream<void> get sessionChanges => _events.stream;

  @override
  QuizReportV2CapturedSession? capture() => token == null
      ? null
      : QuizReportV2CapturedSession(
          userId: userId,
          accessToken: token!,
          generation: generation,
        );

  @override
  bool isCurrent(QuizReportV2CapturedSession captured) =>
      token == captured.accessToken &&
      userId == captured.userId &&
      generation == captured.generation;

  void switchAccount() {
    userId = 'a1000000-0000-4000-8000-000000000002';
    token = 'access-token-B';
    generation++;
    _events.add(null);
  }

  void rotateToken() {
    token = 'access-token-A-rotated';
    generation++;
    _events.add(null);
  }

  Future<void> dispose() => _events.close();
}

final class _AbortableMockClient extends http.BaseClient {
  _AbortableMockClient(this._handler);

  final Future<http.Response> Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final response = request
        .finalize()
        .drain<void>()
        .then((_) => _handler(request))
        .then(
          (value) => http.StreamedResponse(
            Stream<List<int>>.value(value.bodyBytes),
            value.statusCode,
            contentLength: value.bodyBytes.length,
            request: request,
            headers: value.headers,
          ),
        );

    final abortTrigger = request is http.AbortableRequest
        ? request.abortTrigger
        : null;
    if (abortTrigger == null) return response;

    final aborted = abortTrigger.then<http.StreamedResponse>((_) {
      throw http.ClientException('Request aborted', request.url);
    });
    return Future.any<http.StreamedResponse>([response, aborted]);
  }

  @override
  void close() {}
}

final class _DrainClient extends http.BaseClient {
  final requestSeen = Completer<http.AbortableRequest>();
  final release = Completer<void>();
  var closed = false;
  var sends = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sends++;
    final outbound = request as http.AbortableRequest;
    requestSeen.complete(outbound);
    final abortTrigger = outbound.abortTrigger;
    if (abortTrigger == null) {
      throw http.ClientException('Missing abort trigger', request.url);
    }
    await abortTrigger;
    await release.future;
    throw http.ClientException('Aborted', request.url);
  }

  @override
  void close() => closed = true;
}

QuizReportV2HttpTransport _transport({
  required _FakeAuth auth,
  required http.Client client,
  Duration timeout = const Duration(seconds: 2),
}) => QuizReportV2HttpTransport(
  projectUrl: 'https://example.supabase.invalid',
  publishableKey: 'sb_publishable_TEST_ONLY_1234567890',
  auth: auth,
  client: client,
  timeout: timeout,
);

void main() {
  test('posts exact raw bytes with captured bearer and public key', () async {
    final auth = _FakeAuth();
    final report = _report();
    final expectedBody = report.encodeRawBody();
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/functions/v1/quiz-report-v2');
      expect(request.followRedirects, isFalse);
      expect(request.maxRedirects, 0);
      expect(request.headers['authorization'], 'Bearer access-token-A');
      expect(request.headers['apikey'], 'sb_publishable_TEST_ONLY_1234567890');
      expect(
        request.headers['content-type'],
        'application/json; charset=utf-8',
      );
      expect(request.bodyBytes, expectedBody);
      return _success(report);
    });
    final transport = _transport(auth: auth, client: client);

    final response = await transport.submit(report);

    expect(response.answerCount, 1);
    expect(response.correctCount, 1);
    transport.dispose();
    client.close();
    await auth.dispose();
  });

  test('no authenticated session never dispatches', () async {
    final auth = _FakeAuth()..token = null;
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return _success(_report());
    });
    final transport = _transport(auth: auth, client: client);

    await expectLater(
      transport.submit(_report()),
      throwsA(
        isA<QuizReportV2TransportFailure>().having(
          (error) => error.code,
          'code',
          QuizReportV2TransportCode.unauthorized,
        ),
      ),
    );
    expect(calls, 0);
    transport.dispose();
    client.close();
    await auth.dispose();
  });

  test('late account switch aborts request and rejects old response', () async {
    final auth = _FakeAuth();
    final report = _report();
    final responseGate = Completer<http.Response>();
    final requestSeen = Completer<http.AbortableRequest>();
    final client = _AbortableMockClient((request) {
      requestSeen.complete(request as http.AbortableRequest);
      return responseGate.future;
    });
    final transport = _transport(auth: auth, client: client);
    final pending = transport.submit(report);
    final outbound = await requestSeen.future;

    auth.switchAccount();
    final abortTrigger = outbound.abortTrigger;
    expect(abortTrigger, isNotNull);
    await abortTrigger!.timeout(const Duration(seconds: 1));
    responseGate.complete(_success(report));

    await expectLater(
      pending,
      throwsA(
        isA<QuizReportV2TransportFailure>().having(
          (error) => error.code,
          'code',
          QuizReportV2TransportCode.unauthorized,
        ),
      ),
    );
    transport.dispose();
    client.close();
    await auth.dispose();
  });

  test('token rotation aborts the captured generation', () async {
    final auth = _FakeAuth();
    final report = _report();
    final responseGate = Completer<http.Response>();
    final requestSeen = Completer<http.AbortableRequest>();
    final client = _AbortableMockClient((request) {
      requestSeen.complete(request as http.AbortableRequest);
      return responseGate.future;
    });
    final transport = _transport(auth: auth, client: client);
    final pending = transport.submit(report);
    final outbound = await requestSeen.future;

    auth.rotateToken();
    final abortTrigger = outbound.abortTrigger;
    expect(abortTrigger, isNotNull);
    await abortTrigger!.timeout(const Duration(seconds: 1));
    responseGate.complete(_success(report));

    await expectLater(
      pending,
      throwsA(
        isA<QuizReportV2TransportFailure>().having(
          (error) => error.code,
          'code',
          QuizReportV2TransportCode.unauthorized,
        ),
      ),
    );
    transport.dispose();
    client.close();
    await auth.dispose();
  });

  test('timeout is uncertain and never automatically retries', () async {
    final auth = _FakeAuth();
    final report = _report();
    final never = Completer<http.Response>();
    var calls = 0;
    final client = MockClient((_) {
      calls++;
      return never.future;
    });
    final transport = _transport(
      auth: auth,
      client: client,
      timeout: const Duration(milliseconds: 25),
    );

    await expectLater(
      transport.submit(report),
      throwsA(
        isA<QuizReportV2TransportFailure>()
            .having(
              (error) => error.code,
              'code',
              QuizReportV2TransportCode.networkUnavailable,
            )
            .having((error) => error.retryable, 'retryable', isTrue),
      ),
    );
    expect(calls, 1);
    transport.dispose();
    client.close();
    await auth.dispose();
  });

  test('maps a gateway auth rejection without exposing its body', () async {
    final auth = _FakeAuth();
    final client = MockClient(
      (_) async => http.Response('PRIVATE gateway detail', 401),
    );
    final transport = _transport(auth: auth, client: client);

    await expectLater(
      transport.submit(_report()),
      throwsA(
        isA<QuizReportV2TransportFailure>()
            .having(
              (error) => error.code,
              'code',
              QuizReportV2TransportCode.unauthorized,
            )
            .having(
              (error) => error.messageVi.contains('PRIVATE'),
              'redacted',
              isFalse,
            ),
      ),
    );
    transport.dispose();
    client.close();
    await auth.dispose();
  });

  test('conflict maps to a fixed safe error without server detail', () async {
    final auth = _FakeAuth();
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'code': 'SYNC_CONFLICT',
          'message_vi': 'PRIVATE SQL detail must not escape',
          'retryable': false,
        }),
        409,
        headers: _headers,
      ),
    );
    final transport = _transport(auth: auth, client: client);

    await expectLater(
      transport.submit(_report()),
      throwsA(
        isA<QuizReportV2TransportFailure>()
            .having(
              (error) => error.code,
              'code',
              QuizReportV2TransportCode.syncConflict,
            )
            .having(
              (error) => error.messageVi.contains('PRIVATE'),
              'redacted',
              isFalse,
            ),
      ),
    );
    transport.dispose();
    client.close();
    await auth.dispose();
  });

  test('oversized, redirected and non-JSON responses fail closed', () async {
    final auth = _FakeAuth();
    for (final response in [
      http.Response(
        List<String>.filled(16 * 1024 + 1, 'x').join(),
        200,
        headers: _headers,
      ),
      http.Response(
        '',
        302,
        headers: {..._headers, 'location': 'https://other.invalid'},
      ),
      http.Response('{}', 200, headers: {'content-type': 'text/plain'}),
    ]) {
      final client = MockClient((_) async => response);
      final transport = _transport(auth: auth, client: client);
      await expectLater(
        transport.submit(_report()),
        throwsA(
          isA<QuizReportV2TransportFailure>().having(
            (error) => error.code,
            'code',
            QuizReportV2TransportCode.internalError,
          ),
        ),
      );
      transport.dispose();
      client.close();
    }
    await auth.dispose();
  });

  test('rejects learner-style endpoint and secret-key configuration', () async {
    final auth = _FakeAuth();
    final client = MockClient((_) async => _success(_report()));
    expect(
      () => QuizReportV2HttpTransport(
        projectUrl: 'http://example.supabase.invalid',
        publishableKey: 'sb_publishable_TEST_ONLY_1234567890',
        auth: auth,
        client: client,
      ),
      throwsArgumentError,
    );
    expect(
      () => QuizReportV2HttpTransport(
        projectUrl: 'https://example.supabase.invalid',
        publishableKey: 'sb_secret_TEST_ONLY_1234567890',
        auth: auth,
        client: client,
      ),
      throwsArgumentError,
    );
    client.close();
    await auth.dispose();
  });

  test(
    'lookup receipt posts original bytes to the fixed replay-only endpoint',
    () async {
      final auth = _FakeAuth();
      final report = _report();
      final expectedBody = report.encodeRawBody();
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/functions/v1/quiz-report-v2-lookup');
        expect(request.followRedirects, isFalse);
        expect(request.maxRedirects, 0);
        expect(request.headers['authorization'], 'Bearer access-token-A');
        expect(
          request.headers['apikey'],
          'sb_publishable_TEST_ONLY_1234567890',
        );
        expect(request.bodyBytes, expectedBody);
        return _lookupFound(report);
      });
      final transport = _transport(auth: auth, client: client);

      final result = await transport.lookupReceipt(report);

      expect(result.clientEventId, report.clientEventId);
      expect(result.hasReceipt, isTrue);
      expect(result.response?.correctCount, 1);
      transport.dispose();
      client.close();
      await auth.dispose();
    },
  );

  test('lookup rejects duplicate envelope and nested receipt keys', () async {
    final auth = _FakeAuth();
    final report = _report();
    final found = _lookupFound(report).body;
    final bodies = [
      found.replaceFirst('{"status"', '{"status":"unresolved","status"'),
      found.replaceFirst(
        '"correct_count":1',
        '"correct_count":0,"correct_count":1',
      ),
    ];
    var calls = 0;
    final client = MockClient((request) async {
      expect(request.url.path, '/functions/v1/quiz-report-v2-lookup');
      return http.Response(bodies[calls++], 200, headers: _headers);
    });
    final transport = _transport(auth: auth, client: client);
    addTearDown(() async {
      await transport.close();
      client.close();
      await auth.dispose();
    });

    for (final body in bodies) {
      expect(body, isNot(found));
      expect(jsonDecode(body), jsonDecode(found));
      await expectLater(
        transport.lookupReceipt(report),
        throwsA(
          isA<QuizReportV2TransportFailure>().having(
            (failure) => failure.code,
            'code',
            QuizReportV2TransportCode.internalError,
          ),
        ),
      );
    }
    expect(calls, 2);
  });

  test(
    'unresolved receipt lookup never dispatches submit or claims a receipt',
    () async {
      final auth = _FakeAuth();
      final report = _report();
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.path, '/functions/v1/quiz-report-v2-lookup');
        return http.Response(
          jsonEncode({
            'status': 'unresolved',
            'client_event_id': report.clientEventId,
          }),
          200,
          headers: _headers,
        );
      });
      final transport = _transport(auth: auth, client: client);

      final result = await transport.lookupReceipt(report);

      expect(calls, 1);
      expect(result.isUnresolved, isTrue);
      expect(result.hasReceipt, isFalse);
      expect(result.response, isNull);
      transport.dispose();
      client.close();
      await auth.dispose();
    },
  );

  test(
    'late account switch aborts receipt lookup and rejects the old receipt',
    () async {
      final auth = _FakeAuth();
      final report = _report();
      final responseGate = Completer<http.Response>();
      final requestSeen = Completer<http.AbortableRequest>();
      final client = _AbortableMockClient((request) {
        requestSeen.complete(request as http.AbortableRequest);
        return responseGate.future;
      });
      final transport = _transport(auth: auth, client: client);
      final pending = transport.lookupReceipt(report);
      final outbound = await requestSeen.future;

      auth.switchAccount();
      final abortTrigger = outbound.abortTrigger;
      expect(abortTrigger, isNotNull);
      await abortTrigger!.timeout(const Duration(seconds: 1));
      responseGate.complete(_lookupFound(report));

      await expectLater(
        pending,
        throwsA(
          isA<QuizReportV2TransportFailure>().having(
            (error) => error.code,
            'code',
            QuizReportV2TransportCode.unauthorized,
          ),
        ),
      );
      transport.dispose();
      client.close();
      await auth.dispose();
    },
  );
  test('lookup rechecks Auth after listener cleanup', () async {
    final cleanupStarted = Completer<void>();
    final finishCleanup = Completer<void>();
    final auth = _FakeAuth(
      onCancel: () {
        cleanupStarted.complete();
        return finishCleanup.future;
      },
    );
    final client = MockClient((_) async => _lookupFound(_report()));
    final transport = _transport(auth: auth, client: client);
    addTearDown(() async {
      if (!finishCleanup.isCompleted) finishCleanup.complete();
      await transport.close();
      client.close();
      await auth.dispose();
    });

    final pending = transport.lookupReceipt(_report());
    final rejected = expectLater(
      pending,
      throwsA(
        isA<QuizReportV2TransportFailure>().having(
          (failure) => failure.code,
          'code',
          QuizReportV2TransportCode.unauthorized,
        ),
      ),
    );
    await cleanupStarted.future.timeout(const Duration(seconds: 1));
    auth.rotateToken();
    finishCleanup.complete();
    await rejected;
  });

  test('lookup redacts Auth listener cleanup failures', () async {
    final auth = _FakeAuth(
      onCancel: () => Future<void>.error(StateError('private cleanup detail')),
    );
    final client = MockClient((_) async => _lookupFound(_report()));
    final transport = _transport(auth: auth, client: client);
    addTearDown(() async {
      await transport.close();
      client.close();
      await auth.dispose();
    });

    await expectLater(
      transport.lookupReceipt(_report()),
      throwsA(
        isA<QuizReportV2TransportFailure>().having(
          (failure) => failure.code,
          'code',
          QuizReportV2TransportCode.internalError,
        ),
      ),
    );
  });

  test(
    'close aborts and drains an in-flight receipt lookup before release',
    () async {
      final auth = _FakeAuth();
      final report = _report();
      final client = _DrainClient();
      final transport = _transport(auth: auth, client: client);
      final pending = transport.lookupReceipt(report);
      final outbound = await client.requestSeen.future;

      var closed = false;
      final closing = transport.close().then<void>((_) {
        closed = true;
      });
      await outbound.abortTrigger!.timeout(const Duration(seconds: 1));
      expect(closed, isFalse);
      expect(client.closed, isFalse);
      await expectLater(
        transport.lookupReceipt(report),
        throwsA(
          isA<QuizReportV2TransportFailure>().having(
            (error) => error.code,
            'code',
            QuizReportV2TransportCode.networkUnavailable,
          ),
        ),
      );
      expect(client.sends, 1);

      client.release.complete();
      await expectLater(
        pending,
        throwsA(
          isA<QuizReportV2TransportFailure>().having(
            (error) => error.code,
            'code',
            QuizReportV2TransportCode.networkUnavailable,
          ),
        ),
      );
      await closing.timeout(const Duration(seconds: 1));
      expect(closed, isTrue);
      expect(client.closed, isFalse);
      transport.dispose();
      client.close();
      await auth.dispose();
    },
  );

  test(
    'close drains lookup while Auth listener cancellation is pending',
    () async {
      final cleanupStarted = Completer<void>();
      final finishCleanup = Completer<void>();
      final auth = _FakeAuth(
        onCancel: () {
          cleanupStarted.complete();
          return finishCleanup.future;
        },
      );
      final report = _report();
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.path, '/functions/v1/quiz-report-v2-lookup');
        return _lookupFound(report);
      });
      final transport = _transport(auth: auth, client: client);
      addTearDown(() async {
        if (!finishCleanup.isCompleted) finishCleanup.complete();
        await transport.close();
        client.close();
        await auth.dispose();
      });

      final pending = transport.lookupReceipt(report);
      await cleanupStarted.future.timeout(const Duration(seconds: 1));

      var closed = false;
      final closing = transport.close().then<void>((_) {
        closed = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(closed, isFalse);
      await expectLater(
        transport.lookupReceipt(report),
        throwsA(
          isA<QuizReportV2TransportFailure>().having(
            (failure) => failure.code,
            'code',
            QuizReportV2TransportCode.networkUnavailable,
          ),
        ),
      );
      expect(calls, 1);

      finishCleanup.complete();
      await expectLater(
        pending,
        throwsA(
          isA<QuizReportV2TransportFailure>().having(
            (failure) => failure.code,
            'code',
            QuizReportV2TransportCode.networkUnavailable,
          ),
        ),
      );
      await closing.timeout(const Duration(seconds: 1));
      expect(closed, isTrue);
      expect(calls, 1);
    },
  );

}
