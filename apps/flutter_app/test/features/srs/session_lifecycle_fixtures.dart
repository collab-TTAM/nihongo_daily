// TEST ONLY opaque secrets and in-memory SDK/OS ports, never live credentials.
import 'dart:async';
import 'package:nihongo_daily/features/auth/data/persistent_account_access.dart';
import 'package:nihongo_daily/features/auth/data/session_credential_vault.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

const owner = 'a1000000-0000-4000-8000-000000000001';
const other = 'a1000000-0000-4000-8000-000000000002';
void check(bool value, String message) {
  if (!value) throw StateError(message);
}

Future<void> flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> fails(Future<void> operation) async {
  try {
    await operation;
  } on ReviewTransportFailure catch (error) {
    check(!error.toString().contains('PRIVATE'), 'unsafe error');
    return;
  }
  throw StateError('operation unexpectedly succeeded');
}

final class MemoryVault implements SessionCredentialBackend {
  String? secret;
  Completer<void>? writeWait;
  Completer<void>? readWait;
  bool failWrite = false;
  bool failRead = false;
  bool failClear = false;
  int writes = 0;
  int clears = 0;
  @override
  Future<Object?> invoke(String method, Map<String, Object> args) async {
    if (method == 'read') {
      await readWait?.future;
      if (failRead) throw StateError('PRIVATE OS ERROR');
      return secret;
    }
    if (method == 'write') {
      writes++;
      await writeWait?.future;
      if (failWrite) throw StateError('PRIVATE OS ERROR');
      secret = args['token'] as String;
      return true;
    }
    clears++;
    if (failClear) throw StateError('PRIVATE OS ERROR');
    secret = null;
    return true;
  }
}

final class MemorySdk implements RefreshableAccountAccess {
  ReviewSession? session;
  String? secret;
  String nextOwner = owner;
  String nextSecret = 'TEST_ONLY_ROTATED_1';
  final events = StreamController<void>.broadcast(sync: true);
  Completer<void>? authWait;
  bool failAuth = false;
  bool failLogout = false;
  int logouts = 0;
  int logins = 0;
  int restores = 0;
  @override
  ReviewSession? get currentSession => session;
  @override
  String? get currentRefreshToken => secret;
  @override
  Stream<void> get sessionChanges => events.stream;
  void change(String? id, String? token, {bool sameSession = false}) {
    if (!sameSession) session = id == null ? null : ReviewSession(userId: id);
    secret = token;
    events.add(null);
  }

  Future<void> authenticate() async {
    await authWait?.future;
    if (failAuth) throw StateError('PRIVATE HTTP PASSWORD');
    change(nextOwner, nextSecret);
  }

  @override
  Future<void> signIn(String email, String password) {
    logins++;
    return authenticate();
  }

  @override
  Future<void> restore(String refreshToken) {
    restores++;
    check(refreshToken == 'TEST_ONLY_SAVED', 'wrong saved refresh secret');
    return authenticate();
  }

  @override
  Future<void> refresh() => authenticate();
  @override
  Future<void> signOut() async {
    logouts++;
    if (failLogout) throw StateError('PRIVATE LOGOUT ERROR');
    change(null, null);
  }
}

const scenarios = [
  'empty-start',
  'restore-barrier',
  'login-barrier',
  'rotation-barrier',
  'account-switch',
  'logout-during-write',
  'logout-during-restore',
  'logout-during-login',
  'write-error',
  'read-error',
  'clear-error-retry',
  'sdk-logout-error',
  'revocation',
  'dispose-ready',
  'dispose-during-auth',
  'duplicate-auth',
  'closed-stream',
  'queued-old-rotation',
  'exclusive-owner',
  'logout-failure-late-login',
];

Future<void> verifyLifecycle(String scenario) async {
  final sdk = MemorySdk();
  final backend = MemoryVault();
  final vault = SessionCredentialVault(
    projectUrl: 'https://lifecycle-test.supabase.invalid',
    backend: backend,
  );
  final access = PersistentAccountAccess(sdk: sdk, vault: vault);
  Future<void> login() =>
      access.signIn('fixture@example.invalid', 'TEST_ONLY_PASSWORD');
  try {
    if (scenario == 'restore-barrier' || scenario == 'logout-during-restore') {
      backend.secret = 'TEST_ONLY_SAVED';
      sdk.authWait = Completer();
      final start = access.start();
      final startError = scenario == 'logout-during-restore'
          ? fails(start)
          : null;
      await flush();
      check(
        sdk.restores == 1 && access.currentSession == null,
        'restore bypassed server',
      );
      if (scenario == 'logout-during-restore') {
        await access.signOut();
        sdk.authWait!.complete();
        await startError;
        check(
          backend.secret == null &&
              sdk.session == null &&
              access.currentSession == null,
          'late restore resurrected',
        );
      } else {
        backend.writeWait = Completer();
        sdk.authWait!.complete();
        await flush();
        check(
          access.currentSession == null && backend.secret == 'TEST_ONLY_SAVED',
          'restore before saved rotation',
        );
        backend.writeWait!.complete();
        await start;
        check(
          access.currentSession?.userId == owner &&
              backend.secret == sdk.secret,
          'restore rotation lost',
        );
      }
      return;
    }
    if (scenario == 'read-error') {
      backend.failRead = true;
      await fails(access.start());
      check(
        access.currentSession == null &&
            access.phase == SessionPersistencePhase.failed,
        'read error accepted',
      );
      backend.failRead = false;
      await login();
      check(
        access.currentSession?.userId == owner,
        'read error cannot recover explicitly',
      );
      return;
    }
    await access.start();
    if (scenario == 'exclusive-owner') {
      var rejected = false;
      try {
        PersistentAccountAccess(sdk: MemorySdk(), vault: vault);
      } on SessionVaultFailure {
        rejected = true;
      }
      check(rejected, 'two active vault lifecycle owners');
      await access.close();
      final next = PersistentAccountAccess(sdk: sdk, vault: vault);
      await next.start();
      await next.close();
      return;
    }
    if (scenario == 'logout-failure-late-login') {
      sdk.authWait = Completer();
      final error = fails(login());
      sdk.failLogout = true;
      await fails(access.signOut());
      sdk.failLogout = false;
      sdk.authWait!.complete();
      await error;
      check(
        sdk.session == null &&
            backend.secret == null &&
            access.currentSession == null,
        'logout failure allowed late login',
      );
      return;
    }
    if (scenario == 'empty-start') {
      check(
        sdk.restores == 0 &&
            access.currentSession == null &&
            backend.writes == 0,
        'empty store manufactured session',
      );
      return;
    }
    if (scenario == 'duplicate-auth' ||
        scenario == 'logout-during-login' ||
        scenario == 'dispose-during-auth') {
      sdk.authWait = Completer();
      final first = login();
      if (scenario == 'duplicate-auth') {
        await fails(login());
        sdk.authWait!.complete();
        await first;
        check(sdk.logins == 1, 'duplicate login');
      } else {
        final failure = fails(first);
        final close = scenario == 'dispose-during-auth'
            ? access.close()
            : access.signOut();
        if (scenario == 'logout-during-login') await close;
        sdk.authWait!.complete();
        await failure;
        await close;
        check(
          backend.secret == null &&
              sdk.session == null &&
              access.currentSession == null,
          'late login resurrected',
        );
      }
      return;
    }
    if (scenario == 'login-barrier' || scenario == 'write-error') {
      backend.writeWait = Completer();
      backend.failWrite = scenario == 'write-error';
      final pending = login();
      final failure = scenario == 'write-error' ? fails(pending) : null;
      await flush();
      check(access.currentSession == null, 'login before write');
      backend.writeWait!.complete();
      if (failure != null) {
        await failure;
        check(
          access.phase == SessionPersistencePhase.failed &&
              backend.secret == null,
          'write failure left usable session',
        );
        backend.failWrite = false;
        backend.writeWait = null;
        await login();
      } else {
        await pending;
      }
      check(access.currentSession?.userId == owner, 'login never became saved');
      return;
    }
    await login();
    if (scenario == 'rotation-barrier') {
      backend.writeWait = Completer();
      sdk.nextSecret = 'TEST_ONLY_ROTATED_2';
      sdk.authWait = Completer();
      final pending = access.refresh();
      sdk.events.add(null); // A queued old SDK event cannot bypass refresh.
      await flush();
      check(
        access.currentSession == null,
        'old event reopened refreshing session',
      );
      sdk.authWait!.complete();
      await flush();
      check(access.currentSession == null, 'rotation before persistence');
      backend.writeWait!.complete();
      await pending;
      check(
        backend.secret == 'TEST_ONLY_ROTATED_2' &&
            access.currentSession != null,
        'rotation not saved',
      );
    } else if (scenario == 'account-switch' ||
        scenario == 'queued-old-rotation') {
      backend.writeWait = Completer();
      sdk.change(owner, 'TEST_ONLY_OLD', sameSession: true);
      await flush();
      sdk.change(other, 'TEST_ONLY_OTHER');
      check(access.currentSession == null, 'account switch retained identity');
      backend.writeWait!.complete();
      await flush();
      check(
        backend.secret == 'TEST_ONLY_OTHER' &&
            access.currentSession?.userId == other,
        'old write won over other account',
      );
    } else if (scenario == 'logout-during-write') {
      backend.writeWait = Completer();
      sdk.change(owner, 'TEST_ONLY_PENDING', sameSession: true);
      await flush();
      final logout = access.signOut();
      check(access.currentSession == null, 'logout did not immediately revoke');
      backend.writeWait!.complete();
      await logout;
      check(
        backend.secret == null && access.currentSession == null,
        'old write survived clear',
      );
    } else if (scenario == 'clear-error-retry' ||
        scenario == 'sdk-logout-error') {
      backend.failClear = scenario == 'clear-error-retry';
      sdk.failLogout = scenario == 'sdk-logout-error';
      await fails(access.signOut());
      check(
        access.currentSession == null && backend.clears > 0 && sdk.logouts > 0,
        'logout failure skipped cleanup',
      );
      backend.failClear = false;
      sdk.failLogout = false;
      await access.signOut();
      check(
        backend.secret == null && sdk.session == null,
        'logout retry failed',
      );
    } else if (scenario == 'revocation') {
      sdk.change(null, null);
      check(access.currentSession == null, 'revoked identity visible');
      await flush();
      check(backend.secret == null, 'revoked token retained');
    } else if (scenario == 'dispose-ready') {
      final saved = backend.secret;
      await access.close();
      check(
        saved != null &&
            backend.secret == saved &&
            access.currentSession == null,
        'shutdown deleted saved session',
      );
      await fails(login());
    } else if (scenario == 'closed-stream') {
      await sdk.events.close();
      await flush();
      check(
        access.currentSession == null &&
            access.phase == SessionPersistencePhase.failed,
        'closed stream left access open',
      );
    }
  } finally {
    await access.close();
    await sdk.events.close();
  }
}
