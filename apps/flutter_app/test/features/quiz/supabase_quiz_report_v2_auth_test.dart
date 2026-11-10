import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nihongo_daily/features/quiz/data/supabase_quiz_report_v2_auth.dart';
import 'package:supabase/supabase.dart';

const _projectUrl = 'https://example.supabase.invalid';
const _publishableKey = 'sb_publishable_TEST_ONLY_1234567890';
const _userA = 'a1000000-0000-4000-8000-000000000001';
const _userB = 'a1000000-0000-4000-8000-000000000002';
const _sessionA = 'a2000000-0000-4000-8000-000000000001';
const _sessionB = 'a2000000-0000-4000-8000-000000000002';

String _token(String userId, String sessionId, int generation) {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'sub': userId,
            'aud': 'authenticated',
            'role': 'authenticated',
            'exp': now + 3600,
            'iat': now,
            'session_id': sessionId,
            'email': userId == _userA ? 'learner@example.test' : 'learner-b@example.test',
            'app_metadata': {'provider': 'email', 'providers': ['email']},
            'user_metadata': {},
            'generation': generation,
          }),
        ),
      )
      .replaceAll('=', '');
  return 'eyJhbGciOiJub25lIn0.' + payload + '.fixture-signature';
}

Map<String, Object?> _authResponse(
  String userId,
  String sessionId,
  int generation,
) {
  final now = DateTime.now().toUtc();
  return {
    'access_token': _token(userId, sessionId, generation),
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
    'refresh_token': 'fixture-refresh-' + generation.toString(),
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': userId == _userA ? 'learner@example.test' : 'learner-b@example.test',
      'app_metadata': {'provider': 'email', 'providers': ['email']},
      'user_metadata': {},
      'created_at': '2026-01-01T00:00:00.000Z',
    },
  };
}

void main() {
  test('captured snapshot is unavailable before SDK Auth readiness', () async {
    final client = MockClient((_) async => http.Response('{}', 404));
    final sdk = SupabaseClient(
      _projectUrl,
      _publishableKey,
      httpClient: client,
      authOptions: AuthClientOptions(autoRefreshToken: false),
    );
    final auth = SupabaseQuizReportV2Auth(client: sdk);

    expect(auth.capture(), isNull);

    await auth.dispose();
    await sdk.dispose();
    client.close();
  });

  test('refresh rotation invalidates the captured generation', () async {
    var generation = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/v1/token') &&
          request.url.queryParameters['grant_type'] == 'password') {
        return http.Response(
          jsonEncode(_authResponse(_userA, _sessionA, generation)),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/auth/v1/token') &&
          request.url.queryParameters['grant_type'] == 'refresh_token') {
        generation++;
        return http.Response(
          jsonEncode(_authResponse(_userA, _sessionA, generation)),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });
    final sdk = SupabaseClient(
      _projectUrl,
      _publishableKey,
      httpClient: client,
      authOptions: AuthClientOptions(autoRefreshToken: false),
    );
    final auth = SupabaseQuizReportV2Auth(client: sdk);

    await sdk.auth.signInWithPassword(
      email: 'learner@example.test',
      password: 'fixture-password',
    );
    final before = auth.capture();
    expect(before, isNotNull);
    expect(auth.isCurrent(before!), isTrue);

    await sdk.auth.refreshSession();
    final after = auth.capture();

    expect(after, isNotNull);
    expect(after!.generation, greaterThan(before.generation));
    expect(after.accessToken, isNot(before.accessToken));
    expect(auth.isCurrent(before), isFalse);
    expect(auth.isCurrent(after), isTrue);

    await auth.dispose();
    await sdk.dispose();
    client.close();
  });

  test('account replacement and logout fence the prior account snapshot', () async {
    var userId = _userA;
    var sessionId = _sessionA;
    var generation = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/v1/token') &&
          request.url.queryParameters['grant_type'] == 'password') {
        return http.Response(
          jsonEncode(_authResponse(userId, sessionId, generation)),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/auth/v1/logout')) {
        return http.Response('', 204);
      }
      return http.Response('{}', 404);
    });
    final sdk = SupabaseClient(
      _projectUrl,
      _publishableKey,
      httpClient: client,
      authOptions: AuthClientOptions(autoRefreshToken: false),
    );
    final auth = SupabaseQuizReportV2Auth(client: sdk);

    await sdk.auth.signInWithPassword(
      email: 'learner@example.test',
      password: 'fixture-password',
    );
    final accountA = auth.capture()!;

    userId = _userB;
    sessionId = _sessionB;
    generation++;
    await sdk.auth.signInWithPassword(
      email: 'learner-b@example.test',
      password: 'fixture-password',
    );
    final accountB = auth.capture();

    expect(accountB, isNotNull);
    expect(accountB!.userId, _userB);
    expect(auth.isCurrent(accountA), isFalse);
    expect(auth.isCurrent(accountB), isTrue);

    await sdk.auth.signOut(scope: SignOutScope.local);
    expect(auth.capture(), isNull);
    expect(auth.isCurrent(accountB), isFalse);

    await auth.dispose();
    await sdk.dispose();
    client.close();
  });

  test('disposing the observer invalidates every captured snapshot', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/v1/token')) {
        return http.Response(
          jsonEncode(_authResponse(_userA, _sessionA, 0)),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });
    final sdk = SupabaseClient(
      _projectUrl,
      _publishableKey,
      httpClient: client,
      authOptions: AuthClientOptions(autoRefreshToken: false),
    );
    final auth = SupabaseQuizReportV2Auth(client: sdk);

    await sdk.auth.signInWithPassword(
      email: 'learner@example.test',
      password: 'fixture-password',
    );
    final captured = auth.capture()!;

    await auth.dispose();

    expect(auth.capture(), isNull);
    expect(auth.isCurrent(captured), isFalse);

    await sdk.dispose();
    client.close();
  });
}
