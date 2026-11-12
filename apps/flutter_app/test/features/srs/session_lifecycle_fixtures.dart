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

final class MemoryVault
    implements SessionCredentialBackend, SessionCredentialOwnerLeaseBackend {
  String? secret;
  Completer<void>? writeWait;
  Completer<void>? readWait;
  Completer<void>? clearWait;
  bool failWrite = false;
  // Simulate an OS write that commits before its response is lost.
  bool commitWriteThenFail = false;
  bool failRead = false;
  bool failClear = false;
  final operations = <String>[];
  int writes = 0;
  int clears = 0;
  bool ownerHeld = false;
  bool failAcquireOwner = false;
  bool failReleaseOwner = false;
  int ownerAcquires = 0;
  int ownerReleases = 0;

  @override
  Future<bool> acquireOwner(String target) async {
    ownerAcquires++;
    if (failAcquireOwner) throw StateError('PRIVATE OS OWNER');
    if (ownerHeld) return false;
    ownerHeld = true;
    return true;
  }

  @override
  Future<bool> releaseOwner(String target) async {
    ownerReleases++;
    if (failReleaseOwner) throw StateError('PRIVATE OS OWNER');
    if (!ownerHeld) return false;
    ownerHeld = false;
    return true;
  }

  @override
  Future<Object?> invoke(String method, Map<String, Object> args) async {
    operations.add(
      method,
    ); // Method names only; never record credential values.
    if (method == 'read') {
      await readWait?.future;
      if (failRead) throw StateError('PRIVATE OS ERROR');
      return secret;
    }
    if (method == 'write') {
      writes++;
      await writeWait?.future;
      final token = args['token'] as String;
      if (commitWriteThenFail) {
        secret = token;
        throw StateError('PRIVATE OS ERROR AFTER COMMIT');
      }
      if (failWrite) throw StateError('PRIVATE OS ERROR');
      secret = token;
      return true;
    }
    clears++;
    await clearWait?.future;
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
  Completer<void>? logoutWait;
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
    await logoutWait?.future;
    if (failLogout) throw StateError('PRIVATE LOGOUT ERROR');
    change(null, null);
  }
}

const scenarios = [
  'empty-start',
  'empty-start-login',
  'restore-barrier',
  'login-barrier',
  'rotation-barrier',
  'logout-during-refresh',
  'account-switch',
  'replacement-login-drains-pending-rotation',
  'replacement-login-waits-for-out-of-band-session-clear',
  'logout-during-write',
  'logout-during-restore',
  'logout-during-login',
  'write-error',
  'read-error',
  'clear-error-retry',
  'close-retries-failed-cleanup',
  'uncertain-rotation-write-failure-requires-clear-before-owner-release',
  'sdk-logout-error',
  'revocation',
  'dispose-ready',
  'dispose-during-auth',
  'same-session-event',
  'same-session-event-during-write',
  'same-session-secret-rotation-during-write',
  'duplicate-auth',
  'closed-stream',
  'queued-old-rotation',
  'exclusive-owner',
  'logout-failure-late-login',
  'login-during-late-cleanup',
  'logout-during-failed-state-retry',
  'owner-lease-order',
  'owner-lock-failure-no-storage-access',
  'owner-release-failure-retains-owner',
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
    if (scenario == 'owner-lock-failure-no-storage-access') {
      backend.secret = 'TEST_ONLY_SAVED';
      backend.failAcquireOwner = true;
      await fails(access.start());
      await fails(login());
      check(
        backend.operations.isEmpty &&
            backend.secret == 'TEST_ONLY_SAVED' &&
            sdk.restores == 0 &&
            sdk.logins == 0 &&
            !backend.ownerHeld,
        'busy process lease touched saved credentials or dispatched Auth',
      );
      backend.failAcquireOwner = false;
      return;
    }
    if (scenario == 'owner-release-failure-retains-owner') {
      await access.start();
      await login();
      backend.failReleaseOwner = true;
      var closeFailed = false;
      try {
        await access.close();
      } on SessionVaultFailure {
        closeFailed = true;
      }
      check(
        closeFailed &&
            backend.ownerHeld &&
            PersistentAccountAccess.isTargetOwned(vault.target),
        'failed native lease release freed the local owner',
      );
      backend.failReleaseOwner = false;
      await access.close();
      check(
        !backend.ownerHeld &&
            !PersistentAccountAccess.isTargetOwned(vault.target),
        'close retry did not release both owner slots',
      );
      return;
    }
    if (scenario == 'owner-lease-order') {
      await access.start();
      check(
        backend.ownerAcquires == 1 &&
            backend.ownerHeld &&
            backend.operations.first == 'read',
        'vault read started before native owner acquisition',
      );
      await access.close();
      check(
        backend.ownerReleases == 1 && !backend.ownerHeld,
        'caller close did not release the native owner',
      );
      return;
    }
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
        var logoutSettled = false;
        final logout = access.signOut().then((_) => logoutSettled = true);
        await flush();
        check(
          !logoutSettled && access.currentSession == null,
          'logout resolved before the held restore drained',
        );
        await fails(login());
        sdk.authWait!.complete();
        await startError;
        await logout;
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
    if (scenario == 'empty-start-login') {
      await login();
      check(
        sdk.logins == 1 &&
            access.currentSession?.userId == owner &&
            backend.secret == sdk.secret,
        'empty-vault startup rejected the first explicit login',
      );
      return;
    }
    if (scenario == 'replacement-login-waits-for-out-of-band-session-clear') {
      await login();
      backend.clearWait = Completer<void>();
      backend.failClear = true;
      // Queue SDK delivery before signIn reserves its operation microtask.
      scheduleMicrotask(() => sdk.change(null, null));
      sdk.nextOwner = other;
      sdk.nextSecret = 'TEST_ONLY_B_AFTER_OUT_OF_BAND_CLEAR';
      final replacementError = fails(
        access.signIn('fixture@example.invalid', 'TEST_ONLY_PASSWORD'),
      );
      try {
        await flush();
        check(
          backend.clears == 1 &&
              access.currentSession == null &&
              backend.secret == 'TEST_ONLY_ROTATED_1',
          'out-of-band sign-out did not hold the credential clear',
        );

        check(
          sdk.logins == 1 &&
              sdk.logouts == 1 &&
              backend.clears == 1 &&
              access.currentSession == null,
          'replacement password Auth bypassed the pending clear',
        );

        backend.clearWait!.complete();
        await replacementError;
        check(
          sdk.logins == 1 &&
              sdk.session == null &&
              backend.secret == 'TEST_ONLY_ROTATED_1' &&
              access.phase == SessionPersistencePhase.failed,
          'failed out-of-band/compensating clear allowed replacement Auth',
        );
      } finally {
        // Never let a failed assertion strand the shared project owner behind
        // a held fake clear and cascade into later lifecycle scenarios.
        if (!backend.clearWait!.isCompleted) {
          backend.clearWait!.complete();
        }
        backend.failClear = false;
        try {
          await replacementError;
        } on Object {
          // Drain the fixture operation while preserving the original failure.
        }
      }
      await login();
      check(
        sdk.logins == 2 &&
            sdk.logouts == 2 &&
            access.currentSession?.userId == other &&
            backend.secret == 'TEST_ONLY_B_AFTER_OUT_OF_BAND_CLEAR' &&
            backend.operations.join(' -> ') ==
                'read -> write -> clear -> clear -> clear -> write',
        'explicit cleanup retry did not clear A before persisting B',
      );
      return;
    }
    if (scenario == 'replacement-login-drains-pending-rotation') {
      await login();
      backend.writeWait = Completer<void>();
      sdk.change(owner, 'TEST_ONLY_A_ROTATED_PENDING', sameSession: true);
      await flush();
      check(
        backend.writes == 2 && access.currentSession == null,
        'out-of-band A rotation did not hold the persistence barrier',
      );

      sdk.nextOwner = other;
      sdk.nextSecret = 'TEST_ONLY_B_AFTER_PENDING_ROTATION';
      sdk.authWait = Completer<void>();
      final replacement = access.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await flush();
      check(
        access.currentSession == null &&
            sdk.logins == 1 &&
            sdk.logouts == 1 &&
            backend.secret == 'TEST_ONLY_ROTATED_1',
        'replacement Auth bypassed the pending A rotation drain',
      );

      backend.writeWait!.complete();
      for (var i = 0; i < 8 && sdk.logins < 2; i++) {
        await flush();
      }
      check(
        backend.secret == null &&
            access.currentSession == null &&
            sdk.logins == 2 &&
            sdk.logouts == 1,
        'B password grant did not wait for A write and exact-project clear',
      );

      sdk.authWait!.complete();
      await replacement;
      check(
        access.currentSession?.userId == other &&
            backend.secret == 'TEST_ONLY_B_AFTER_PENDING_ROTATION' &&
            backend.operations.join(' -> ') ==
                'read -> write -> write -> clear -> write',
        'replacement login did not persist only B after draining A',
      );
      return;
    }
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
    if (scenario == 'login-during-late-cleanup') {
      sdk.authWait = Completer();
      final error = fails(login());
      var logoutSettled = false;
      final logout = access.signOut().then((_) => logoutSettled = true);
      await flush();
      check(
        sdk.logouts == 1 && backend.secret == null && !logoutSettled,
        'logout did not clear immediately while waiting for Auth',
      );
      sdk.logoutWait = Completer();
      sdk.authWait!.complete();
      await flush();
      await fails(login());
      check(sdk.logins == 1, 'new login raced cancelled operation cleanup');
      check(
        sdk.logouts == 2 && !logoutSettled,
        'logout resolved before the final SDK cleanup',
      );
      sdk.logoutWait!.complete();
      await error;
      await logout;
      check(
        sdk.session == null && backend.secret == null,
        'late cleanup retained credentials',
      );
      return;
    }
    if (scenario == 'logout-during-failed-state-retry') {
      backend.failWrite = true;
      await fails(login());
      backend.failWrite = false;
      sdk.logoutWait = Completer();
      final error = fails(login());
      await flush();
      final logout = access.signOut();
      sdk.logoutWait!.complete();
      await logout;
      await error;
      check(
        sdk.logins == 1 && sdk.session == null && backend.secret == null,
        'failed-state recovery ignored logout',
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
    if (scenario == 'same-session-event') {
      await login();
      await flush();
      final writes = backend.writes;
      sdk.change(owner, 'TEST_ONLY_ROTATED_1', sameSession: true);
      await flush();
      check(
        backend.writes == writes && access.currentSession != null,
        'same-session event rewrote vault or revoked readiness',
      );
      return;
    }
    if (scenario == 'same-session-event-during-write') {
      backend.writeWait = Completer();
      final pending = login();
      await flush();
      check(
        backend.writes == 1 && access.currentSession == null,
        'initial persistence did not remain pending',
      );
      sdk.change(owner, 'TEST_ONLY_ROTATED_1', sameSession: true);
      await flush();
      check(
        backend.writes == 1,
        'duplicate pending event queued a second write',
      );
      backend.writeWait!.complete();
      await pending;
      check(
        access.currentSession != null,
        'original write did not publish readiness',
      );
      return;
    }
    if (scenario == 'same-session-secret-rotation-during-write') {
      backend.writeWait = Completer();
      final pending = login();
      await flush();
      check(
        backend.writes == 1 && access.currentSession == null,
        'initial persistence did not remain pending',
      );
      sdk.change(owner, 'TEST_ONLY_ROTATED_2', sameSession: true);
      await flush();
      check(
        backend.writes == 1 && access.currentSession == null,
        'secret rotation published before its write',
      );
      backend.writeWait!.complete();
      await pending;
      check(
        backend.writes == 2 &&
            backend.secret == 'TEST_ONLY_ROTATED_2' &&
            access.currentSession != null,
        'obsolete secret won over same-session rotation',
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
        if (scenario == 'logout-during-login') {
          var logoutSettled = false;
          final close = access.signOut().then((_) => logoutSettled = true);
          await flush();
          check(
            !logoutSettled && access.currentSession == null,
            'logout resolved before the held password Auth drained',
          );
          await fails(login());
          sdk.authWait!.complete();
          await failure;
          await close;
        } else {
          final close = access.close();
          sdk.authWait!.complete();
          await failure;
          await close;
        }
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
    if (scenario ==
        'uncertain-rotation-write-failure-requires-clear-before-owner-release') {
      backend.commitWriteThenFail = true;
      backend.failClear = true;
      sdk.nextSecret = 'TEST_ONLY_ROTATED_2';
      await fails(access.refresh());
      check(
        backend.secret == 'TEST_ONLY_ROTATED_2' &&
            access.currentSession == null &&
            access.phase == SessionPersistencePhase.failed &&
            backend.clears == 1,
        'ambiguous write result granted access or skipped compensating clear',
      );

      var closeFailed = false;
      try {
        await access.close();
      } on SessionVaultFailure {
        closeFailed = true;
      }
      check(
        closeFailed &&
            backend.secret == 'TEST_ONLY_ROTATED_2' &&
            backend.ownerHeld &&
            PersistentAccountAccess.isTargetOwned(vault.target),
        'caller close released the owner after an uncertain credential write',
      );

      backend.failClear = false;
      await access.close();
      check(
        backend.secret == null &&
            sdk.session == null &&
            !backend.ownerHeld &&
            !PersistentAccountAccess.isTargetOwned(vault.target),
        'close retry did not clear the uncertain credential before release',
      );
      final operations = backend.operations.join(' -> ');
      check(
        operations == 'read -> write -> write -> clear -> clear -> clear',
        'uncertain credential write cleanup order changed: $operations',
      );
      return;
    }
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
    } else if (scenario == 'logout-during-refresh') {
      final originalSecret = backend.secret;
      sdk.authWait = Completer<void>();
      sdk.nextOwner = owner;
      sdk.nextSecret = 'TEST_ONLY_LATE_A_REFRESH';
      final pending = fails(access.refresh());
      await flush();
      check(
        access.currentSession == null && backend.secret == originalSecret,
        'explicit refresh published before its rotated secret was saved',
      );

      var logoutSettled = false;
      final logout = access.signOut().then((_) => logoutSettled = true);
      await flush();
      check(
        !logoutSettled && backend.secret == null && sdk.session == null,
        'logout did not clear immediately while awaiting the late refresh drain',
      );
      await fails(login());
      check(sdk.logins == 1, 'replacement login raced the late User A refresh');

      sdk.authWait!.complete();
      await pending;
      await logout;
      await flush();
      check(
        backend.secret == null &&
            sdk.session == null &&
            access.currentSession == null,
        'late User A refresh resurrected after logout',
      );

      sdk.nextOwner = other;
      sdk.nextSecret = 'TEST_ONLY_B_REFRESH_AFTER_LATE_A';
      await login();
      check(
        access.currentSession?.userId == other &&
            backend.secret == 'TEST_ONLY_B_REFRESH_AFTER_LATE_A',
        'User B did not authenticate after the late refresh was drained',
      );
      return;
    } else if (scenario == 'queued-old-rotation') {
      final writes = backend.writes;
      sdk.change(owner, 'TEST_ONLY_OLD', sameSession: true);
      sdk.change(other, 'TEST_ONLY_OTHER');
      await flush();
      check(
        backend.writes == writes + 1 &&
            backend.secret == 'TEST_ONLY_OTHER' &&
            access.currentSession?.userId == other,
        'obsolete queued secret was written',
      );
    } else if (scenario == 'account-switch') {
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
    } else if (scenario == 'close-retries-failed-cleanup') {
      backend.failClear = true;
      await fails(access.signOut());
      check(
        backend.secret == 'TEST_ONLY_ROTATED_1' && sdk.session == null,
        'failed logout clear did not retain only an uncertain vault value',
      );
      var closeFailed = false;
      try {
        await access.close();
      } on SessionVaultFailure catch (error) {
        closeFailed = true;
        check(!error.toString().contains('PRIVATE'), 'unsafe close error');
      }
      check(closeFailed, 'close ignored a failed credential clear');
      check(
        PersistentAccountAccess.isTargetOwned(vault.target),
        'failed close released the credential owner',
      );
      backend.failClear = false;
      await access.close();
      check(
        backend.secret == null &&
            sdk.session == null &&
            !PersistentAccountAccess.isTargetOwned(vault.target),
        'close retry released the owner before successful cleanup',
      );
      return;
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
