// TEST ONLY unsigned JWT/Auth HTTP and streamed AI responses. Actual SDK session,
// http request/abort/stream behavior; no hosted Auth, provider or learner proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/data/supabase_ai_text_transport.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/data/supabase_review_binding.dart';
import 'package:supabase/supabase.dart';

const origin = 'https://example.supabase.invalid';
const key = 'sb_publishable_TEST_ONLY_1234567890';
const userA = 'a1000000-0000-4000-8000-000000000001';
const userB = 'a1000000-0000-4000-8000-000000000002';
const sid = 'c1000000-0000-4000-8000-000000000001';
late Map<String, Object?> fixtures;
Object? fixture(String operation, String kind) =>
    fixtures['${operation}_$kind'];
Map<String, Object> request(String operation) => Map<String, Object>.from(
  fixture(operation, 'request')! as Map<String, Object?>,
);
String output([String operation = 'tutor_explain']) =>
    jsonEncode(fixture(operation, 'response'));
TypeMatcher<AiTextFailure> failure(AiTextErrorCode code) =>
    isA<AiTextFailure>().having((f) => f.code, 'safe code', code);
String segment(Object value) =>
    base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
String token(
  DateTime now,
  String user,
  int generation, {
  String role = 'authenticated',
}) =>
    '${segment({'alg': 'HS256', 'typ': 'JWT'})}.${segment({'sub': user, 'session_id': sid, 'role': role, 'exp': now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000, 'fixture_generation': generation})}.${segment('TEST ONLY NOT A SIGNATURE')}';

final class _Http extends http.BaseClient {
  final requests = <http.BaseRequest>[];
  Future<http.StreamedResponse> Function(http.BaseRequest)? onSend;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    return Future<http.StreamedResponse>.sync(() => onSend!(request));
  }

  @override
  void close() {
    closed = true;
  }
}

http.StreamedResponse response(
  String text, {
  int status = 200,
  Map<String, String>? headers,
  int? length,
}) => http.StreamedResponse(
  Stream.value(utf8.encode(text)),
  status,
  headers: headers ?? {'content-type': 'application/json; charset=utf-8'},
  contentLength: length,
);

void main() {
  late DateTime now;
  late String nextUser;
  late int generation;
  late SupabaseClient sdk;
  late SupabaseReviewBinding auth;
  late MockClient authHttp;
  late _Http network;
  late bool ready;
  late bool brokenReady;
  late List<SupabaseAiTextTransport> transports;

  Future<void> login() async {
    await sdk.auth.signInWithPassword(
      email: 'fixture@example.invalid',
      password: 'TEST_ONLY_PASSWORD',
    );
    await Future<void>.delayed(Duration.zero);
  }

  SupabaseAiTextTransport make({
    Duration timeout = const Duration(seconds: 1),
    bool Function()? readiness,
  }) {
    final t = SupabaseAiTextTransport(
      client: sdk,
      auth: auth,
      isReady:
          readiness ??
          () {
            if (brokenReady) throw StateError('TEST_ONLY_SECRET');
            return ready;
          },
      projectUrl: origin,
      publishableKey: key,
      httpClient: network,
      now: () => now,
      timeout: timeout,
    );
    transports.add(t);
    return t;
  }

  Future<Object?> invoke(
    SupabaseAiTextTransport t, {
    String operation = 'tutor_explain',
    Map<String, Object>? body,
    ReviewSession? session,
  }) => operation == 'tutor_explain'
      ? t.tutorExplain(
          capturedSession: session ?? auth.currentSession!,
          body: body ?? request(operation),
        )
      : t.correctSentence(
          capturedSession: session ?? auth.currentSession!,
          body: body ?? request(operation),
        );

  setUpAll(() {
    fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  setUp(() async {
    now = DateTime.utc(2026, 10, 24);
    nextUser = userA;
    generation = 0;
    ready = true;
    brokenReady = false;
    transports = [];
    network = _Http()
      ..onSend = (r) async => response(output(r.url.path.split('/').last));
    authHttp = MockClient((r) async {
      if (r.url.path == '/auth/v1/logout') return http.Response('', 204);
      if (r.url.path != '/auth/v1/token') {
        throw StateError('Unexpected TEST ONLY Auth operation');
      }
      return http.Response(
        jsonEncode({
          'access_token': token(now, nextUser, generation),
          'refresh_token': 'TEST_ONLY_REFRESH',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': nextUser,
            'aud': 'authenticated',
            'role': 'authenticated',
            'created_at': '2026-10-24T00:00:00Z',
            'app_metadata': <String, Object>{},
            'user_metadata': <String, Object>{},
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    sdk = SupabaseClient(
      origin,
      key,
      httpClient: authHttp,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    auth = SupabaseReviewBinding(
      client: sdk,
      projectUrl: origin,
      publishableKey: key,
      httpClient: authHttp,
      now: () => now,
    );
    await login();
  });
  tearDown(() async {
    for (final t in transports) {
      await t.close();
    }
    auth.dispose();
    await sdk.dispose();
    authHttp.close();
    network.close();
  });

  test(
    'fixed text endpoints use captured SDK bearer and exact original frozen bodies',
    () async {
      final t = make();
      for (final operation in ['tutor_explain', 'correct_sentence']) {
        expect(
          await invoke(t, operation: operation),
          fixture(operation, 'response'),
        );
        final sent = network.requests.last as http.AbortableRequest;
        expect(sent.method, 'POST');
        expect(sent.url.toString(), '$origin/functions/v1/$operation');
        expect(sent.followRedirects, isFalse);
        expect(sent.maxRedirects, 0);
        expect(sent.headers['authorization'], 'Bearer ${token(now, userA, 0)}');
        expect(sent.headers['apikey'], key);
        expect(sent.headers['cache-control'], 'no-store');
        expect(jsonDecode(sent.body), fixture(operation, 'request'));
      }
      expect(network.requests, hasLength(2));
      expect(network.closed, isFalse);
    },
  );

  test(
    'construction rejects readiness getter and timeout or project mismatch safely',
    () {
      ready = false;
      expect(make, throwsA(failure(AiTextErrorCode.unauthorized)));
      ready = true;
      brokenReady = true;
      expect(make, throwsA(failure(AiTextErrorCode.unauthorized)));
      brokenReady = false;
      for (final timeout in [Duration.zero, const Duration(seconds: 16)]) {
        expect(() => make(timeout: timeout), throwsArgumentError);
      }
      expect(
        () => SupabaseAiTextTransport(
          client: sdk,
          auth: auth,
          isReady: () => true,
          projectUrl: 'https://other.invalid',
          publishableKey: key,
        ),
        throwsArgumentError,
      );
      expect(
        () => SupabaseAiTextTransport(
          client: sdk,
          auth: auth,
          isReady: () => true,
          projectUrl: origin,
          publishableKey: 'TEST_ONLY_PRIVATE_KEY',
        ),
        throwsArgumentError,
      );
      expect(network.requests, isEmpty);
    },
  );

  test(
    'wrong captured identity is rejected without retargeting or dispatch',
    () async {
      final t = make();
      await expectLater(
        invoke(t, session: ReviewSession(userId: userA)),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      expect(network.requests, isEmpty);
      expect(await invoke(t), fixture('tutor_explain', 'response'));
    },
  );

  test(
    'readiness loss or getter error permanently fences a capability',
    () async {
      for (final broken in [false, true]) {
        final t = make();
        brokenReady = broken;
        ready = false;
        await expectLater(
          invoke(t),
          throwsA(failure(AiTextErrorCode.unauthorized)),
        );
        ready = true;
        brokenReady = false;
        await expectLater(
          invoke(t),
          throwsA(failure(AiTextErrorCode.unauthorized)),
        );
      }
      expect(network.requests, isEmpty);
    },
  );

  test(
    'expiry is checked before dispatch and cannot revive with clock rollback',
    () async {
      final t = make();
      final session = auth.currentSession!;
      now = now.add(const Duration(hours: 2));
      await expectLater(
        invoke(t, session: session),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      now = now.subtract(const Duration(hours: 2));
      await expectLater(
        invoke(t, session: session),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      expect(network.requests, isEmpty);
    },
  );

  for (final change in ['refresh', 'account', 'logout']) {
    test(
      'SDK $change aborts held headers and never publishes with new credentials',
      () async {
        final t = make();
        final session = auth.currentSession!;
        final pending = Completer<http.StreamedResponse>();
        network.onSend = (_) => pending.future;
        final rejected = expectLater(
          invoke(t, session: session),
          throwsA(failure(AiTextErrorCode.unauthorized)),
        );
        final original = network.requests.single as http.AbortableRequest;
        if (change == 'logout') {
          await sdk.auth.signOut(scope: SignOutScope.local);
        } else {
          generation++;
          if (change == 'account') nextUser = userB;
          await login();
        }
        await Future<void>.delayed(Duration.zero);
        await rejected;
        expect(
          original.headers['authorization'],
          'Bearer ${token(now, userA, 0)}',
        );
        await expectLater(original.abortTrigger, completes);
        expect(t.isBusy, isTrue);
        var cancelled = false;
        final body = StreamController<List<int>>(
          onCancel: () {
            cancelled = true;
          },
        );
        pending.complete(http.StreamedResponse(body.stream, 200));
        await Future<void>.delayed(Duration.zero);
        expect(cancelled, isTrue);
        expect(t.isBusy, isFalse);
        expect(t.isCurrent, isFalse);
        await body.close();
        expect(network.requests, hasLength(1));
      },
    );
  }

  test(
    'unknown owner fields invalid contexts and byte overflow fail before HTTP',
    () async {
      final t = make();
      for (final body in [
        {...request('tutor_explain'), 'user_id': userA},
        {
          ...request('tutor_explain'),
          'context': <String, Object>{'recent_grammar_ids': <String>[]},
        },
        {...request('tutor_explain'), 'jlpt_level': 'UNKNOWN'},
        {...request('tutor_explain'), 'question_vi': ''},
        TutorExplainRequest(
          level: AiTextLevel.n5,
          questionVi: '\u0001' * 5000,
          recentGrammarIds: List.generate(
            100,
            (i) =>
                'a1000000-0000-4000-8000-${(i + 1).toString().padLeft(12, '0')}',
          ),
        ).toJson(),
      ]) {
        await expectLater(
          invoke(t, body: body),
          throwsA(failure(AiTextErrorCode.validationFailure)),
        );
      }
      expect(network.requests, isEmpty);
      expect(t.isBusy, isFalse);
    },
  );

  test(
    'single-flight registration precedes synchronous HTTP reentry',
    () async {
      final t = make();
      Future<void>? nested;
      network.onSend = (_) async {
        nested = expectLater(
          invoke(t, operation: 'correct_sentence'),
          throwsA(isA<AiTextRequestPending>()),
        );
        return response(output());
      };
      await invoke(t);
      await nested!;
      expect(network.requests, hasLength(1));
    },
  );

  test(
    'redirects are rejected and bodies cancelled without following Location',
    () async {
      final t = make();
      for (final code in [301, 302, 307, 308]) {
        var cancelled = false;
        final stream = StreamController<List<int>>(
          onCancel: () {
            cancelled = true;
          },
        );
        network.onSend = (_) async => http.StreamedResponse(
          stream.stream,
          code,
          headers: {'location': 'https://untrusted.invalid/TEST_ONLY_SECRET'},
        );
        await expectLater(
          invoke(t),
          throwsA(failure(AiTextErrorCode.internalError)),
        );
        await Future<void>.delayed(Duration.zero);
        expect(cancelled, isTrue);
        await stream.close();
      }
      expect(network.requests, hasLength(4));
    },
  );

  test(
    'unsupported media encoding and malformed declared lengths fail closed',
    () async {
      final t = make();
      for (final headers in <Map<String, String>>[
        {},
        {'content-type': 'text/html'},
        {'content-type': 'application/json; charset=latin1'},
        {'content-type': 'application/json', 'content-encoding': 'gzip'},
        {'content-type': 'application/json', 'content-length': '01'},
        {'content-type': 'application/json', 'content-length': '-1'},
        {'content-type': 'application/json', 'content-length': '1048577'},
        {
          'content-type': 'application/json',
          'Content-Type': 'application/json',
        },
      ]) {
        network.onSend = (_) async => response(output(), headers: headers);
        await expectLater(
          invoke(t),
          throwsA(failure(AiTextErrorCode.internalError)),
        );
      }
    },
  );

  test(
    'declared byte length must match actual bytes and SDK length metadata',
    () async {
      final t = make();
      final n = utf8.encode(output()).length;
      for (final declared in [n - 1, n + 1]) {
        network.onSend = (_) async => response(
          output(),
          headers: {
            'content-type': 'application/json',
            'content-length': '$declared',
          },
        );
        await expectLater(
          invoke(t),
          throwsA(failure(AiTextErrorCode.internalError)),
        );
      }
      network.onSend = (_) async => response(
        output(),
        length: n,
        headers: {
          'content-type': 'application/json',
          'content-length': '${n + 1}',
        },
      );
      await expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.internalError)),
      );
      network.onSend = (_) async => response(output(), length: n);
      expect(await invoke(t), fixture('tutor_explain', 'response'));
    },
  );

  test(
    'actual stream cap accepts exact limit and cancels one byte overflow',
    () async {
      final t = make(timeout: const Duration(seconds: 5));
      final base = utf8.encode(output());
      final exact = [
        ...base,
        ...List.filled(
          SupabaseAiTextTransport.maxResponseBytes - base.length,
          32,
        ),
      ];
      network.onSend = (_) async => http.StreamedResponse(
        Stream.value(exact),
        200,
        headers: {'content-type': 'application/json'},
      );
      expect(await invoke(t), fixture('tutor_explain', 'response'));
      var cancelled = false;
      final stream = StreamController<List<int>>(
        onCancel: () {
          cancelled = true;
        },
      );
      network.onSend = (_) async => http.StreamedResponse(
        stream.stream,
        200,
        headers: {'content-type': 'application/json'},
      );
      final rejected = expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.internalError)),
      );
      stream.add(exact);
      stream.add([32]);
      await rejected;
      await Future<void>.delayed(Duration.zero);
      expect(cancelled, isTrue);
      await stream.close();
    },
  );

  test(
    'split UTF8 succeeds while malformed truncated and BOM input is rejected',
    () async {
      final t = make();
      final valid = utf8.encode(output());
      network.onSend = (_) async => http.StreamedResponse(
        Stream.fromIterable(valid.map((b) => [b])),
        200,
        headers: {'content-type': 'application/json'},
      );
      expect(await invoke(t), fixture('tutor_explain', 'response'));
      for (final bytes in [
        [...valid, 0xc0, 0xaf],
        [...valid, 0xe3, 0x81],
        [239, 187, 191, ...valid],
      ]) {
        network.onSend = (_) async => http.StreamedResponse(
          Stream.value(bytes),
          200,
          headers: {'content-type': 'application/json'},
        );
        await expectLater(
          invoke(t),
          throwsA(failure(AiTextErrorCode.internalError)),
        );
      }
    },
  );

  test(
    'duplicate escaped nested keys excessive depth and malformed JSON are rejected',
    () async {
      final t = make();
      for (final text in [
        '{"answer_vi":"old","answer_vi":"new","examples":[],"practice":[]}',
        r'{"answer_vi":"old","\u0061nswer_vi":"new","examples":[],"practice":[]}',
        '{"answer_vi":"x","examples":[{"sentence_ja":"x","sentence_ja":"y","reading_ja":"x","translation_vi":"x"}],"practice":[]}',
        '${'[' * 17}0${']' * 17}',
        '${output()} trailing',
        '[]',
        'null',
        output('correct_sentence'),
      ]) {
        network.onSend = (_) async => response(text);
        await expectLater(
          invoke(t),
          throwsA(failure(AiTextErrorCode.internalError)),
        );
      }
    },
  );

  test('empty chunk floods are bounded and cancelled', () async {
    final t = make();
    var cancelled = false;
    final stream = StreamController<List<int>>(
      onCancel: () {
        cancelled = true;
      },
    );
    network.onSend = (_) async => http.StreamedResponse(
      stream.stream,
      200,
      headers: {'content-type': 'application/json'},
    );
    final rejected = expectLater(
      invoke(t),
      throwsA(failure(AiTextErrorCode.internalError)),
    );
    for (var i = 0; i <= SupabaseAiTextTransport.maxResponseReads; i++) {
      stream.add([]);
    }
    await rejected;
    await Future<void>.delayed(Duration.zero);
    expect(cancelled, isTrue);
    await stream.close();
  });

  test(
    'raw client and stream exceptions expose only fixed safe failures',
    () async {
      final t = make();
      for (final error in [
        http.ClientException('TEST_ONLY_RAW_SECRET'),
        StateError('TEST_ONLY_RAW_SECRET'),
      ]) {
        network.onSend = (_) => Future.error(error);
        try {
          await invoke(t);
          fail('expected safe failure');
        } on AiTextFailure catch (e) {
          expect(
            e.code,
            error is http.ClientException
                ? AiTextErrorCode.networkUnavailable
                : AiTextErrorCode.internalError,
          );
          expect(e.toString(), isNot(contains('SECRET')));
          expect(e.messageVi, isNot(contains('SECRET')));
        }
      }
      network.onSend = (_) async => http.StreamedResponse(
        Stream.error(StateError('TEST_ONLY_RAW_SECRET')),
        200,
        headers: {'content-type': 'application/json'},
      );
      await expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.internalError)),
      );
    },
  );

  test(
    'matching HTTP errors discard server text and clamp permanent retry flags',
    () async {
      final t = make();
      for (final entry in <AiTextErrorCode, int>{
        AiTextErrorCode.forbidden: 403,
        AiTextErrorCode.notFound: 404,
        AiTextErrorCode.validationFailure: 400,
        AiTextErrorCode.rateLimited: 429,
        AiTextErrorCode.networkUnavailable: 503,
        AiTextErrorCode.providerUnavailable: 503,
        AiTextErrorCode.syncConflict: 409,
        AiTextErrorCode.internalError: 500,
      }.entries) {
        network.onSend = (_) async => response(
          jsonEncode({
            'code': entry.key.wireName,
            'message_vi': 'TEST_ONLY_SERVER_SECRET',
            'retryable': true,
          }),
          status: entry.value,
        );
        await expectLater(
          invoke(t),
          throwsA(
            failure(entry.key)
                .having(
                  (f) => f.messageVi,
                  'fixed message',
                  entry.key.messageVi,
                )
                .having(
                  (f) => f.retryable,
                  'transient only',
                  [
                    AiTextErrorCode.rateLimited,
                    AiTextErrorCode.networkUnavailable,
                    AiTextErrorCode.providerUnavailable,
                  ].contains(entry.key),
                ),
          ),
        );
      }
      network.onSend = (_) async => response(output(), status: 409);
      await expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.syncConflict)),
      );
      network.onSend = (_) async =>
          response('{"code":"FORBIDDEN","message_vi":"raw","retryable":false}');
      await expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.internalError)),
      );
    },
  );

  test(
    'HTTP unauthorized revokes before reading an invalid gateway body',
    () async {
      final t = make();
      network.onSend = (_) async => response(
        'TEST_ONLY_RAW_SECRET',
        status: 401,
        headers: {'content-type': 'text/html'},
      );
      await expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      await expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      expect(network.requests, hasLength(1));
    },
  );

  for (final lateError in [false, true]) {
    test(
      'header timeout retains lock through late settlement error=$lateError',
      () async {
        final t = make(timeout: const Duration(milliseconds: 25));
        final pending = Completer<http.StreamedResponse>();
        network.onSend = (_) => pending.future;
        await expectLater(
          invoke(t),
          throwsA(failure(AiTextErrorCode.networkUnavailable)),
        );
        expect(t.isBusy, isTrue);
        await expectLater(
          (network.requests.single as http.AbortableRequest).abortTrigger,
          completes,
        );
        await expectLater(invoke(t), throwsA(isA<AiTextRequestPending>()));
        expect(network.requests, hasLength(1));
        var cancelled = false;
        final stream = StreamController<List<int>>(
          onCancel: () {
            cancelled = true;
          },
        );
        if (lateError) {
          pending.completeError(StateError('TEST_ONLY_LATE_SECRET'));
        } else {
          pending.complete(http.StreamedResponse(stream.stream, 200));
        }
        await Future<void>.delayed(Duration.zero);
        expect(t.isBusy, isFalse);
        expect(cancelled, !lateError);
        // No response ever owns this fixture stream in the late-error case.
        if (lateError) unawaited(stream.stream.drain<void>());
        await stream.close();
        network.onSend = (_) async => response(output());
        await invoke(t);
        expect(network.requests, hasLength(2));
      },
    );
  }

  test('body stall has one overall deadline and cancels its stream', () async {
    final t = make(timeout: const Duration(milliseconds: 50));
    var cancelled = false;
    final stream = StreamController<List<int>>(
      onCancel: () {
        cancelled = true;
      },
    );
    network.onSend = (_) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return http.StreamedResponse(
        stream.stream,
        200,
        headers: {'content-type': 'application/json'},
      );
    };
    await expectLater(
      invoke(t),
      throwsA(failure(AiTextErrorCode.networkUnavailable)),
    );
    await Future<void>.delayed(Duration.zero);
    expect(cancelled, isTrue);
    expect(t.isBusy, isFalse);
    await stream.close();
    expect(network.requests, hasLength(1));
  });

  test(
    'owner revoke fences a held body without closing borrowed SDK or HTTP',
    () async {
      final t = make();
      var listening = Completer<void>();
      var cancelled = false;
      final stream = StreamController<List<int>>(
        onListen: () => listening.complete(),
        onCancel: () {
          cancelled = true;
        },
      );
      network.onSend = (_) async => http.StreamedResponse(
        stream.stream,
        200,
        headers: {'content-type': 'application/json'},
      );
      final rejected = expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      await listening.future;
      t.revoke();
      await rejected;
      await Future<void>.delayed(Duration.zero);
      expect(cancelled, isTrue);
      expect(network.closed, isFalse);
      expect(sdk.auth.currentSession, isNotNull);
      await stream.close();
    },
  );

  test(
    'close is idempotent drains ignored abort and leaves borrowed clients open',
    () async {
      final t = make();
      final session = auth.currentSession!;
      final pending = Completer<http.StreamedResponse>();
      network.onSend = (_) => pending.future;
      final rejected = expectLater(
        invoke(t, session: session),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      var drained = false;
      final closing = t.close()
        ..then((_) {
          drained = true;
        });
      expect(identical(closing, t.close()), isTrue);
      await rejected;
      await Future<void>.delayed(Duration.zero);
      expect(drained, isFalse);
      pending.completeError(StateError('TEST_ONLY_LATE_SECRET'));
      await closing;
      expect(drained, isTrue);
      expect(network.closed, isFalse);
      expect(sdk.auth.currentSession, isNotNull);
    },
  );

  test(
    'repository preserves local pending while HTTP remains held after timeout',
    () async {
      final t = make(timeout: const Duration(milliseconds: 25));
      final repo = CapturedAiTextRepository(
        auth: auth,
        transport: t,
        isReady: () => ready,
      );
      final pending = Completer<http.StreamedResponse>();
      network.onSend = (_) => pending.future;
      final request = TutorExplainRequest(
        level: AiTextLevel.n5,
        questionVi: 'TEST ONLY',
      );
      await expectLater(
        repo.explain(request),
        throwsA(failure(AiTextErrorCode.networkUnavailable)),
      );
      await expectLater(
        repo.explain(request),
        throwsA(isA<AiTextRequestPending>()),
      );
      expect(network.requests, hasLength(1));
      pending.completeError(StateError('TEST_ONLY_LATE_SECRET'));
      await Future<void>.delayed(Duration.zero);
      network.onSend = (_) async => response(output());
      await repo.explain(request);
      expect(network.requests, hasLength(2));
    },
  );
  test(
    'uncooperative stream cancellation retains busy until cleanup settles',
    () async {
      final t = make(timeout: const Duration(milliseconds: 25));
      final cleanup = Completer<void>();
      var cancelled = false;
      final stream = StreamController<List<int>>(
        onCancel: () {
          cancelled = true;
          return cleanup.future;
        },
      );
      network.onSend = (_) async => http.StreamedResponse(
        stream.stream,
        200,
        headers: {'content-type': 'text/html'},
      );
      await expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.internalError)),
      );
      expect(cancelled, isTrue);
      expect(t.isBusy, isTrue);
      await expectLater(invoke(t), throwsA(isA<AiTextRequestPending>()));
      expect(network.requests, hasLength(1));
      cleanup.complete();
      await Future<void>.delayed(Duration.zero);
      expect(t.isBusy, isFalse);
      await stream.close();
    },
  );

  test(
    'cancellation failure permanently revokes without exposing raw detail',
    () async {
      final t = make();
      final stream = StreamController<List<int>>(
        onCancel: () =>
            Future<void>.error(StateError('TEST_ONLY_CANCEL_SECRET')),
      );
      network.onSend = (_) async => http.StreamedResponse(
        stream.stream,
        200,
        headers: {'content-type': 'text/html'},
      );
      await expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.internalError)),
      );
      expect(t.isCurrent, isFalse);
      await expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      expect(network.requests, hasLength(1));
      expect(network.closed, isFalse);
      await stream.close();
    },
  );
}
