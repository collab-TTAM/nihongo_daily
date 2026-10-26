// TEST ONLY actual SDK/account + Windows receipt channel/Credential Manager.
// Auth/JWT/profile/HTTP are synthetic; no hosted service or learner credential.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';
import 'package:nihongo_daily/features/ai/application/account_receipt_ai_runtime.dart';
import 'package:nihongo_daily/features/ai/application/supabase_account_receipt_ai_runtime.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/data/conversation_receipt_store.dart';
import 'package:nihongo_daily/features/ai/data/windows_conversation_receipt_store.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_reference.dart';
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/data/own_profile_repository.dart';
import 'package:nihongo_daily/features/auth/data/supabase_account_access.dart';
import 'package:nihongo_daily/features/auth/data/persistent_account_access.dart';
import 'package:nihongo_daily/features/auth/data/windows_session_credential_vault.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/data/supabase_review_binding.dart';

const sdkReceiptPhases = {
  'receipt-sdk-write',
  'receipt-sdk-reopen',
  'receipt-sdk-clear',
  'receipt-sdk-absent',
  'receipt-sdk-cleanup',
  'receipt-persist-write',
  'receipt-persist-reopen',
  'receipt-persist-clear',
  'receipt-persist-absent',
  'receipt-persist-cleanup',
};
const _user = 'a1000000-0000-4000-8000-000000000001';
const _event = 'b1000000-0000-4000-8000-000000000001';
const _key = 'sb_publishable_TEST_ONLY_1234567890';
const _channel = MethodChannel('nihongo_daily/conversation_receipts_v1');
final _request = StartConversationRequest(
  scenarioId: _user,
  level: AiTextLevel.n5,
  clientEventId: _event,
);
void _check(bool value) {
  if (!value) throw const FormatException('SDK receipt verification failed');
}

String _part(Object value) =>
    base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
Future<Object?> _read(
  ConversationReceiptScope scope,
) => _channel.invokeMethod<Object?>('read', {
  'target':
      '${ConversationReceiptStore.targetPrefix}${scope.projectOrigin}|${scope.ownerId}',
});
String _expected(ConversationReceiptScope scope) =>
    ConversationReceiptReference.fromStart(
      projectUrl: scope.projectOrigin,
      ownerId: _user,
      request: _request,
    ).encode();

// TEST ONLY ownership adapter around the real SDK/binding. Mirrors the private
// production port's dual lifecycle signals; not an alternate production Auth.
final class _PersistentSdk implements RefreshableAccountAccess {
  _PersistentSdk(this.client, this.binding) {
    _binding = binding.sessionChanges.listen((_) => _events.add(null));
    _auth = client.auth.onAuthStateChange.listen((_) => _events.add(null));
  }
  final SupabaseClient client;
  final SupabaseReviewBinding binding;
  final _events = StreamController<void>.broadcast();
  late final StreamSubscription<void> _binding;
  late final StreamSubscription<AuthState> _auth;
  @override
  ReviewSession? get currentSession => binding.currentSession;
  @override
  String? get currentRefreshToken =>
      currentSession == null ? null : client.auth.currentSession?.refreshToken;
  @override
  Stream<void> get sessionChanges => _events.stream;
  @override
  Future<void> signIn(String email, String password) =>
      SupabaseAccountAccess(binding).signIn(email, password);
  @override
  Future<void> signOut() => binding.signOutLocally();
  @override
  Future<void> restore(String token) async {
    await client.auth.setSession(token);
  }

  @override
  Future<void> refresh() async {
    await client.auth.refreshSession();
  }

  Future<void> close() async {
    await _binding.cancel();
    await _auth.cancel();
    await _events.close();
  }
}

final class _Http extends http.BaseClient {
  _Http(this.scope, this.bearer) {
    unawaited(
      reply.future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
  }
  final ConversationReceiptScope scope;
  final String bearer;
  final entered = Completer<void>();
  final reply = Completer<http.StreamedResponse>();
  final aborted = Completer<void>();
  int sends = 0;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sends++;
    _check(request is http.AbortableRequest);
    final r = request as http.AbortableRequest;
    _check(
      r.url.toString() ==
              '${scope.projectOrigin}/functions/v1/start_conversation' &&
          r.method == 'POST' &&
          !r.followRedirects &&
          r.maxRedirects == 0 &&
          r.headers['authorization'] == 'Bearer $bearer' &&
          r.headers['apikey'] == _key &&
          jsonEncode(jsonDecode(r.body)) == jsonEncode(_request.toJson()),
    );
    _check(await _read(scope) == _expected(scope));
    unawaited(r.abortTrigger!.then((_) => aborted.complete()));
    entered.complete();
    return reply.future; // Deliberately ignores abort until test releases it.
  }

  @override
  void close() => closed = true;
}

Future<void> verifyWindowsSdkReceiptPhase(String phase, String runScope) async {
  _check(RegExp(r'^bridge-[a-f0-9]{32}$').hasMatch(runScope));
  final persistent = phase.startsWith('receipt-persist-');
  if (persistent) {
    phase = phase.replaceFirst('receipt-persist-', 'receipt-sdk-');
  }
  final origin = persistent
      ? 'https://$runScope-persistent-receipt.invalid'
      : 'https://$runScope-sdk-receipt.invalid';
  final vault = createWindowsSessionCredentialVault(origin);
  final incoming = switch (phase) {
    'receipt-sdk-write' => 'TEST_ONLY_SAVED',
    'receipt-sdk-reopen' => 'TEST_ONLY_ROTATED_1',
    _ => 'TEST_ONLY_ROTATED_2',
  };
  final rotated = phase == 'receipt-sdk-write'
      ? 'TEST_ONLY_ROTATED_1'
      : phase == 'receipt-sdk-reopen'
      ? 'TEST_ONLY_ROTATED_2'
      : 'TEST_ONLY_ROTATED_3';
  final scope = ConversationReceiptScope(projectUrl: origin, ownerId: _user);
  if (phase == 'receipt-sdk-cleanup') {
    final store = createWindowsConversationReceiptStore(scope: scope);
    var failed = false;
    try {
      await store.clearForSignOut();
      await store.close();
    } on Object {
      failed = true;
    }
    if (persistent) {
      try {
        await vault.clear();
      } on Object {
        failed = true;
      }
    }
    _check(!failed);
    _check(await _read(scope) == null);
    return;
  }
  if (persistent && phase == 'receipt-sdk-absent') {
    _check(
      await vault.readRefreshToken() == null && await _read(scope) == null,
    );
    final empty = createWindowsConversationReceiptStore(scope: scope);
    await empty.close();
    return;
  }
  if (persistent && phase == 'receipt-sdk-write') {
    _check(
      await vault.readRefreshToken() == null && await _read(scope) == null,
    );
    await vault.writeRefreshToken(
      incoming,
    ); // Only synthetic seed, unique test scope.
  }
  final now = DateTime.now().toUtc();
  final bearer =
      '${_part({'alg': 'HS256', 'typ': 'JWT'})}.${_part({'sub': _user, 'session_id': _event, 'role': 'authenticated', 'exp': now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000})}.${_part('TEST ONLY NOT A SIGNATURE')}';
  var refreshCalls = 0;
  final authHttp = MockClient((r) async {
    _check(r.url.origin == origin);
    if (r.url.path == '/auth/v1/logout') return http.Response('', 204);
    _check(r.url.path == '/auth/v1/token');
    if (persistent) {
      refreshCalls++;
      _check(refreshCalls == 1);
      _check(r.url.queryParameters['grant_type'] == 'refresh_token');
      final body = jsonDecode(r.body) as Map<String, Object?>;
      _check(body['refresh_token'] == incoming);
    }
    return http.Response(
      jsonEncode({
        'access_token': bearer,
        'refresh_token': persistent ? rotated : 'TEST_ONLY_REFRESH',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': _user,
          'aud': 'authenticated',
          'role': 'authenticated',
          'created_at': '2026-10-26T00:00:00Z',
          'app_metadata': <String, Object>{},
          'user_metadata': <String, Object>{},
        },
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  final sdk = SupabaseClient(
    origin,
    _key,
    httpClient: authHttp,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final binding = SupabaseReviewBinding(
    client: sdk,
    projectUrl: origin,
    publishableKey: _key,
    httpClient: authHttp,
    now: () => now,
  );
  final network = _Http(scope, bearer);
  AccountController<ReviewAuth>? account;
  AccountReceiptAiRuntime<ReviewAuth>? owner;
  ConversationReceiptStore? store;
  _PersistentSdk? port;
  PersistentAccountAccess? persistence;
  try {
    if (persistent) {
      port = _PersistentSdk(sdk, binding);
      persistence = PersistentAccountAccess(sdk: port, vault: vault);
      _check(persistence.currentSession == null);
      await persistence.start();
      _check(await vault.readRefreshToken() == rotated);
      _check(persistence.currentSession != null && refreshCalls == 1);
    } else {
      await sdk.auth.signInWithPassword(
        email: 'fixture@example.invalid',
        password: 'TEST_ONLY_PASSWORD',
      );
    }
    await Future<void>.delayed(Duration.zero);
    final profile = Completer<OwnProfile>();
    final controller = AccountController<ReviewAuth>(
      access: persistence ?? SupabaseAccountAccess(binding),
      ensureProfile: () async {
        if (persistent) {
          _check(await vault.readRefreshToken() == rotated);
          _check(persistence!.currentSession != null);
        }
        return profile.future;
      },
      buildStudyRuntime: (auth, changes) => auth,
    );
    account = controller;
    final receiptStore = createWindowsConversationReceiptStore(scope: scope);
    store = receiptStore;
    final source = createSupabaseAccountReceiptAiRuntime(
      client: sdk,
      account: controller,
      authForRuntime: (auth) => auth,
      projectUrl: origin,
      publishableKey: _key,
      store: receiptStore,
      httpClient: network,
      now: () => now,
    );
    owner = source;
    _check(source.createAiConversationSession() == null && network.sends == 0);
    final ready = controller.changes.firstWhere(
      (s) => s.phase == AccountPhase.ready,
    );
    profile.complete(
      decodeOwnProfile({
        'id': _user,
        'display_name': 'TEST ONLY',
        'preferred_jlpt': 'N5',
        'daily_target_minutes': 120,
        'timezone': 'Asia/Saigon',
      }, _user),
    );
    await ready;
    final session = source.createAiConversationSession()!;
    switch (phase) {
      case 'receipt-sdk-write':
        _check(await _read(scope) == null);
        final rejected = session
            .start(_request)
            .then<void>(
              (_) {
                throw const FormatException('Retired SDK result accepted');
              },
              onError: (Object error, StackTrace _) {
                _check(
                  error is AiTextFailure &&
                      error.code == AiTextErrorCode.unauthorized,
                );
              },
            );
        // Observe an early port failure instead of hanging solely on entry.
        await Future.any<void>([network.entered.future, rejected]);
        _check(network.entered.isCompleted && network.sends == 1);
        var done = false;
        final closing = source.close().then((_) => done = true);
        await network.aborted.future;
        _check(!done && await _read(scope) == _expected(scope));
        _check(
          !session.isCurrent &&
              !network.closed &&
              sdk.auth.currentSession != null,
        );
        try {
          final unexpected = createWindowsConversationReceiptStore(
            scope: scope,
          );
          await unexpected.close();
          throw const FormatException('Store claim released early');
        } on ConversationReceiptStoreFailure catch (error) {
          _check(error.code == ConversationReceiptStoreError.owned);
        }
        network.reply.completeError(StateError('TEST_ONLY_LATE_HTTP'));
        await rejected;
        await closing;
        _check(
          done && await _read(scope) == _expected(scope) && network.sends == 1,
        );
      case 'receipt-sdk-reopen':
        _check(await _read(scope) == _expected(scope));
        var blocked = false;
        try {
          await session.start(_request);
        } on AiTextFailure catch (error) {
          blocked = error.code == AiTextErrorCode.syncConflict;
        }
        _check(blocked && network.sends == 0);
        await source.close();
        _check(await _read(scope) == _expected(scope));
      case 'receipt-sdk-clear':
        _check(await _read(scope) == _expected(scope));
        await source.clearForSignOut();
        _check(await _read(scope) == null && network.sends == 0);
        _check(sdk.auth.currentSession != null); // Local metadata clear only.
        await controller.signOut();
        _check(sdk.auth.currentSession == null);
        if (persistent) {
          _check(await vault.readRefreshToken() == null);
        }
      case 'receipt-sdk-absent':
        _check(await _read(scope) == null && network.sends == 0);
        await source.close();
      default:
        throw const FormatException('Invalid SDK receipt phase');
    }
    _check(!network.closed);
    if (persistent && phase != 'receipt-sdk-clear') {
      _check(await vault.readRefreshToken() == rotated);
    }
  } finally {
    if (network.sends > 0 && !network.reply.isCompleted) {
      network.reply.completeError(StateError('TEST_ONLY_CLEANUP'));
    }
    if (owner != null) {
      await owner.close();
    } else if (store != null) {
      await store.close();
    }
    account?.dispose();
    await persistence?.close();
    if (persistent && phase != 'receipt-sdk-clear') {
      _check(await vault.readRefreshToken() == rotated);
    }
    await port?.close();
    binding.dispose();
    await sdk.dispose();
    authHttp.close();
    network.close();
  }
}
