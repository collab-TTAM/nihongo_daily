// TEST ONLY unsigned JWTs, Auth HTTP responses and RPC server fixtures. Actual
// SDK serialization/lifecycle is tested; no JWT signature/hosted RLS evidence.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:nihongo_daily/features/srs/application/srs_study_provider.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/data/supabase_review_binding.dart';
import 'package:nihongo_daily/features/srs/domain/srs_models.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';
import 'package:supabase/supabase.dart';

const origin = 'https://example.supabase.invalid';
const key = 'sb_publishable_TEST_ONLY_1234567890';
const a = 'a1000000-0000-4000-8000-000000000001';
const b = 'a1000000-0000-4000-8000-000000000002';
const sid1 = 'c1000000-0000-4000-8000-000000000001';
const sid2 = 'c1000000-0000-4000-8000-000000000002';
const envelope = <String, Object>{
  'p_request': <String, Object>{'jlpt_level': 'N5', 'limit': 100},
};
String segment(Object value) =>
    base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
String token(
  String user,
  String sid,
  DateTime now, {
  String role = 'authenticated',
  int generation = 0,
}) =>
    '${segment({'alg': 'HS256', 'typ': 'JWT'})}.${segment({'sub': user, 'session_id': sid, 'role': role, 'aud': 'authenticated', 'iss': '$origin/auth/v1', 'exp': now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000, 'iat': now.millisecondsSinceEpoch ~/ 1000, 'fixture_generation': generation})}.${segment('TEST ONLY NOT A SIGNATURE')}';
final unauthorized = isA<ReviewTransportFailure>().having(
  (e) => e.code,
  'code',
  ReviewErrorCode.unauthorized,
);

void main() {
  late DateTime now;
  late String nextUser;
  late String nextSid;
  late int generation;
  late SupabaseClient sdk;
  late SupabaseReviewBinding binding;
  late MockClient network;
  late Future<http.Response> Function(http.Request) rpc;
  final requests = <http.Request>[];

  Future<void> login() async {
    await sdk.auth.signInWithPassword(
      email: 'fixture@example.invalid',
      password: 'TEST_ONLY_NOT_A_PASSWORD',
    );
    await Future<void>.delayed(Duration.zero);
  }

  Future<Object?> invoke([ReviewSession? session]) => binding.invoke(
    capturedSession: session ?? binding.currentSession!,
    function: 'get_review_queue',
    params: envelope,
  );
  setUp(() {
    now = DateTime.utc(2026, 10, 14, 3);
    nextUser = a;
    nextSid = sid1;
    generation = 0;
    requests.clear();
    rpc = (_) async => http.Response(
      jsonEncode({
        'jlpt_level': 'N5',
        'server_time': '2026-10-14T03:00:00Z',
        'items': <Object>[],
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
    network = MockClient((request) async {
      if (request.url.path == '/auth/v1/token') {
        return http.Response(
          jsonEncode({
            'access_token': token(
              nextUser,
              nextSid,
              now,
              generation: generation,
            ),
            'refresh_token': 'TEST_ONLY_REFRESH_TOKEN',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': nextUser,
              'aud': 'authenticated',
              'role': 'authenticated',
              'created_at': '2026-10-14T00:00:00Z',
              'app_metadata': <String, Object>{},
              'user_metadata': <String, Object>{},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/auth/v1/logout') return http.Response('', 204);
      requests.add(request);
      return rpc(request);
    });
    sdk = SupabaseClient(
      origin,
      key,
      httpClient: network,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    binding = SupabaseReviewBinding(
      client: sdk,
      projectUrl: origin,
      publishableKey: key,
      httpClient: network,
      now: () => now,
    );
  });
  tearDown(() async {
    binding.dispose();
    await sdk.dispose();
    network.close();
  });

  test('unconfigured signed-out SDK cannot dispatch', () async {
    expect(binding.currentSession, isNull);
    await expectLater(invoke(ReviewSession(userId: a)), throwsA(unauthorized));
    expect(requests, isEmpty);
  });
  test(
    'real SDK POST uses only captured bearer public key and ownerless envelope',
    () async {
      await login();
      await invoke();
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.toString(), '$origin/rest/v1/rpc/get_review_queue');
      expect(request.headers['apikey'], key);
      expect(request.headers['authorization'], 'Bearer ${token(a, sid1, now)}');
      expect(jsonDecode(request.body), envelope);
      expect(request.url.hasQuery, isFalse);
      expect(request.followRedirects, isFalse);
    },
  );
  test(
    'SDK refresh retains identity and next POST uses refreshed captured token',
    () async {
      await login();
      final session = binding.currentSession!;
      generation = 1;
      await sdk.auth.refreshSession();
      await Future<void>.delayed(Duration.zero);
      expect(identical(session, binding.currentSession), isTrue);
      await invoke(session);
      expect(
        requests.single.headers['authorization'],
        'Bearer ${token(a, sid1, now, generation: 1)}',
      );
    },
  );
  test(
    'same-user signedIn for same server lifecycle preserves pending work',
    () async {
      await login();
      final session = binding.currentSession;
      generation = 1;
      await login();
      expect(identical(session, binding.currentSession), isTrue);
    },
  );
  test(
    'same-user new server session and A B A revoke old prepared identity',
    () async {
      await login();
      final first = binding.currentSession!;
      nextSid = sid2;
      await login();
      expect(identical(first, binding.currentSession), isFalse);
      await expectLater(invoke(first), throwsA(unauthorized));
      final second = binding.currentSession!;
      nextUser = b;
      nextSid = sid1;
      await login();
      nextUser = a;
      nextSid = sid2;
      await login();
      await expectLater(invoke(second), throwsA(unauthorized));
      expect(requests, isEmpty);
    },
  );
  test('logout immediately prevents another RPC', () async {
    await login();
    final session = binding.currentSession!;
    await sdk.auth.signOut(scope: SignOutScope.local);
    expect(binding.currentSession, isNull);
    await expectLater(invoke(session), throwsA(unauthorized));
  });
  test(
    'in-flight refresh never changes dispatched Authorization header',
    () async {
      await login();
      final reply = Completer<http.Response>();
      final dispatched = Completer<void>();
      rpc = (_) {
        dispatched.complete();
        return reply.future;
      };
      final pending = invoke();
      await dispatched.future;
      generation = 1;
      await sdk.auth.refreshSession();
      await Future<void>.delayed(Duration.zero);
      reply.complete(http.Response('{}', 200));
      await pending;
      expect(
        requests.single.headers['authorization'],
        'Bearer ${token(a, sid1, now)}',
      );
    },
  );
  test('late old SDK response cannot enter another account', () async {
    await login();
    final reply = Completer<http.Response>();
    final dispatched = Completer<void>();
    rpc = (_) {
      dispatched.complete();
      return reply.future;
    };
    final pending = invoke();
    await dispatched.future;
    nextUser = b;
    nextSid = sid2;
    await login();
    reply.complete(http.Response('{}', 200));
    await expectLater(pending, throwsA(unauthorized));
  });
  test(
    'expiry hint clears SDK binding instead of silently refreshing or dispatching',
    () async {
      await login();
      final session = binding.currentSession!;
      now = now.add(const Duration(hours: 1));
      await expectLater(invoke(session), throwsA(unauthorized));
      expect(binding.currentSession, isNull);
      expect(requests, isEmpty);
    },
  );
  test('HTTP failures are fixed safe codes and never auto-retry', () async {
    await login();
    for (final pair in <int, ReviewErrorCode>{
      400: ReviewErrorCode.validationFailure,
      401: ReviewErrorCode.unauthorized,
      403: ReviewErrorCode.forbidden,
      404: ReviewErrorCode.notFound,
      409: ReviewErrorCode.syncConflict,
      429: ReviewErrorCode.rateLimited,
      500: ReviewErrorCode.networkUnavailable,
      302: ReviewErrorCode.internalError,
    }.entries) {
      rpc = (_) async =>
          http.Response('TEST ONLY raw sensitive body', pair.key);
      final before = requests.length;
      await expectLater(
        invoke(),
        throwsA(
          isA<ReviewTransportFailure>().having(
            (e) => e.code,
            'safe code',
            pair.value,
          ),
        ),
      );
      expect(requests.length, before + 1);
    }
  });
  test(
    'network exception is retryable uncertainty without raw details',
    () async {
      await login();
      rpc = (_) async =>
          throw http.ClientException('TEST ONLY raw token detail');
      await expectLater(
        invoke(),
        throwsA(
          isA<ReviewTransportFailure>()
              .having(
                (e) => e.code,
                'safe code',
                ReviewErrorCode.networkUnavailable,
              )
              .having((e) => e.retryable, 'retryable', true),
        ),
      );
      expect(requests.length, 1);
    },
  );
  test(
    'oversized and malformed HTTP success cannot become saved review',
    () async {
      await login();
      final repository = RpcReviewRepository(auth: binding, transport: binding);
      final prepared = repository.prepare(
        SrsReview(
          clientEventId: b,
          itemType: LearningItemType.vocabulary,
          itemId: a,
          rating: ReviewRating.good,
          isCorrect: true,
          responseMs: 123,
          occurredAt: now,
        ),
      )!;
      for (final response in [
        http.Response('x' * (1024 * 1024 + 1), 200),
        http.Response('not JSON', 200),
        http.Response('{"unexpected":true}', 200),
      ]) {
        rpc = (_) async => response;
        expect(
          await repository.submit(prepared),
          isA<ReviewFailure>().having(
            (e) => e.code,
            'safe code',
            ReviewErrorCode.internalError,
          ),
        );
      }
    },
  );
  test(
    'SDK unsafe Auth and RPC logs are suppressed even with root ALL sink',
    () async {
      final records = <LogRecord>[];
      final oldLevel = Logger.root.level;
      Logger.root.level = Level.ALL;
      final subscription = Logger.root.onRecord.listen(records.add);
      addTearDown(() async {
        await subscription.cancel();
        Logger.root.level = oldLevel;
      });
      await login();
      rpc = (_) async =>
          http.Response('TEST ONLY sensitive SQL/token body', 500);
      await expectLater(invoke(), throwsA(isA<ReviewTransportFailure>()));
      expect(
        records.where(
          (record) =>
              record.loggerName.startsWith('supabase.auth') ||
              record.loggerName.startsWith('supabase.postgrest'),
        ),
        isEmpty,
      );
    },
  );
  test(
    'invalid origins privileged keys and SDK endpoint mismatch fail closed',
    () {
      for (final url in [
        'http://example.supabase.invalid',
        '$origin/?x=1',
        '$origin/#x',
        'https://user:pass@example.supabase.invalid',
        '$origin/path',
        'https://other.supabase.invalid',
      ]) {
        expect(
          () => SupabaseReviewBinding(
            client: sdk,
            projectUrl: url,
            publishableKey: key,
          ),
          throwsArgumentError,
        );
      }
      for (final bad in [
        'sb_secret_TEST_ONLY',
        '$key\n',
        '$key ',
        token(a, sid1, now, role: 'service_role'),
        'not a key',
      ]) {
        expect(
          () => SupabaseReviewBinding(
            client: sdk,
            projectUrl: origin,
            publishableKey: bad,
          ),
          throwsArgumentError,
        );
      }
    },
  );
  test(
    'chunked oversized body without content-length fails before SDK parsing',
    () async {
      await login();
      final chunked = MockClient.streaming(
        (request, _) async => http.StreamedResponse(
          Stream.fromIterable([
            List<int>.filled(1024 * 1024, 120),
            [120],
          ]),
          200,
        ),
      );
      final second = SupabaseReviewBinding(
        client: sdk,
        projectUrl: origin,
        publishableKey: key,
        httpClient: chunked,
        now: () => now,
      );
      addTearDown(() {
        second.dispose();
        chunked.close();
      });
      await expectLater(
        second.invoke(
          capturedSession: second.currentSession!,
          function: 'get_review_queue',
          params: envelope,
        ),
        throwsA(
          isA<ReviewTransportFailure>().having(
            (e) => e.code,
            'bounded',
            ReviewErrorCode.internalError,
          ),
        ),
      );
    },
  );
  test(
    'malformed server session id revokes SDK hint rather than dispatching',
    () async {
      await login();
      final session = binding.currentSession!;
      nextSid = 'not a session UUID';
      await login();
      expect(binding.currentSession, isNull);
      await expectLater(invoke(session), throwsA(unauthorized));
      expect(requests, isEmpty);
    },
  );
  test(
    'runtime factory uses SDK binding without changing default provider',
    () async {
      await login();
      final runtime = createSupabaseStudyRuntime(binding);
      expect(identical(runtime.auth, binding), isTrue);
      expect(
        await runtime.queue.load(binding.currentSession!, PreviewLevel.n5),
        isEmpty,
      );
    },
  );
  test(
    'disposal revokes late replies but does not sign out borrowed SDK',
    () async {
      await login();
      final reply = Completer<http.Response>();
      final dispatched = Completer<void>();
      rpc = (_) {
        dispatched.complete();
        return reply.future;
      };
      final pending = invoke();
      await dispatched.future;
      binding.dispose();
      binding.dispose();
      expect(sdk.auth.currentSession, isNotNull);
      reply.complete(http.Response('{}', 200));
      await expectLater(pending, throwsA(unauthorized));
    },
  );
}
