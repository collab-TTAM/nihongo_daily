import 'dart:async';
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/data/own_profile_repository.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'own_profile_fixtures.dart' as profile;

const owner = profile.owner;
const other = profile.other;
void check(bool value, String message) {
  if (!value) throw StateError(message);
}

final class FakeAccountAccess implements AccountAccess {
  @override
  ReviewSession? currentSession;
  final events = StreamController<void>.broadcast(sync: true);
  @override
  Stream<void> get sessionChanges => events.stream;
  int signInCalls = 0;
  int signOutCalls = 0;
  Completer<void>? signInWait;
  bool failSignIn = false;
  bool failSignOut = false;
  @override
  Future<void> signIn(String email, String password) async {
    signInCalls++;
    await signInWait?.future;
    if (failSignIn) throw StateError('PRIVATE TOKEN / PASSWORD');
    change(owner);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (failSignOut) throw StateError('PRIVATE TOKEN');
    change(null);
  }

  void change(String? user) {
    currentSession = user == null ? null : ReviewSession(userId: user);
    events.add(null);
  }
}

final class StudyHandle {
  StudyHandle(this.auth, this.changes);
  final ReviewAuth auth;
  final Stream<void> changes;
}

OwnProfile ownProfile([String id = owner]) =>
    decodeOwnProfile(profile.profile(id), id);
Future<void> flush() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> verifyAccount(String scenario) async {
  final access = FakeAccountAccess();
  var profileCalls = 0;
  Completer<OwnProfile>? delayed;
  var failProfile = false;
  final controller = AccountController<StudyHandle>(
    access: access,
    ensureProfile: () {
      profileCalls++;
      if (failProfile) return Future.error(StateError('PRIVATE SQL TOKEN'));
      return delayed?.future ??
          Future.value(ownProfile(access.currentSession!.userId));
    },
    buildStudyRuntime: (auth, changes) => StudyHandle(auth, changes),
  );
  try {
    if (scenario == 'profile-barrier') {
      delayed = Completer();
      access.change(owner);
      check(
        controller.state.phase == AccountPhase.loadingProfile &&
            controller.readyRuntime == null,
        'study activated before profile',
      );
      delayed.complete(ownProfile());
      await flush();
      check(
        controller.state.phase == AccountPhase.ready &&
            identical(
              controller.readyRuntime!.auth.currentSession,
              access.currentSession,
            ),
        'profile did not gate authenticated runtime',
      );
    } else if (scenario == 'credentials-duplicate') {
      await controller.signIn('bad', 'SECRET');
      check(access.signInCalls == 0, 'invalid credentials dispatched');
      access.signInWait = Completer();
      final first = controller.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await controller.signIn('fixture@example.invalid', 'TEST_ONLY_PASSWORD');
      check(access.signInCalls == 1, 'duplicate sign-in dispatched');
      check(
        controller.state.profile == null && controller.state.messageVi == null,
        'credential state leaked data',
      );
      access.signInWait!.complete();
      await first;
      await flush();
      check(
        controller.state.phase == AccountPhase.ready && profileCalls == 1,
        'valid sign-in/profile failed',
      );
    } else if (scenario == 'profile-retry') {
      failProfile = true;
      access.change(owner);
      await flush();
      check(
        controller.state.phase == AccountPhase.profileError &&
            controller.readyRuntime == null,
        'profile error activated study',
      );
      failProfile = false;
      await controller.retryProfile();
      check(
        controller.state.phase == AccountPhase.ready,
        'profile retry failed',
      );
    } else if (scenario == 'late-profile') {
      delayed = Completer();
      access.change(owner);
      final original = delayed;
      delayed = Completer();
      access.change(other);
      final next = delayed;
      original.complete(ownProfile());
      await flush();
      check(
        controller.state.profile == null && controller.readyRuntime == null,
        'old account profile appeared',
      );
      next.complete(ownProfile(other));
      await flush();
      check(
        controller.state.profile!.id == other,
        'new account profile missing',
      );
    } else if (scenario == 'logout-failure') {
      access.change(owner);
      await flush();
      final old = controller.readyRuntime!;
      access.failSignOut = true;
      final logout = controller.signOut();
      check(
        old.auth.currentSession == null && controller.state.profile == null,
        'logout did not synchronously clear study/profile',
      );
      await logout;
      check(
        controller.state.phase == AccountPhase.signOutError &&
            controller.readyRuntime == null,
        'failed logout restored old data',
      );
      access.change(owner);
      await flush();
      check(
        controller.readyRuntime == null,
        'auth event bypassed failed logout fence',
      );
      access.failSignOut = false;
      await controller.signOut();
      check(
        controller.state.phase == AccountPhase.signedOut,
        'logout retry failed',
      );
    } else if (scenario == 'late-signin-after-logout') {
      access.signInWait = Completer();
      final login = controller.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await controller.signOut();
      check(controller.readyRuntime == null, 'logout fence absent');
      access.signInWait!.complete();
      await login;
      await flush();
      check(
        controller.state.phase == AccountPhase.signedOut &&
            controller.readyRuntime == null &&
            access.currentSession == null &&
            profileCalls == 0,
        'late SDK sign-in resurrected a logged-out account',
      );
    } else if (scenario == 'closed-lifecycle') {
      access.change(owner);
      await flush();
      await access.events.close();
      check(
        controller.state.phase == AccountPhase.unavailable &&
            controller.readyRuntime == null,
        'closed lifecycle kept study enabled',
      );
    } else if (scenario == 'reentrant-revoke') {
      final sub = controller.changes.listen((state) {
        if (state.phase == AccountPhase.loadingProfile)
          unawaited(controller.signOut());
      });
      access.change(owner);
      await flush();
      check(
        profileCalls == 0 && controller.state.phase == AccountPhase.signedOut,
        'reentrant revocation dispatched profile or leaked nested event',
      );
      await sub.cancel();
    } else if (scenario == 'dispose-pending') {
      delayed = Completer();
      access.change(owner);
      controller.dispose();
      delayed.complete(ownProfile());
      await flush();
      check(
        controller.readyRuntime == null,
        'disposed controller exposed late profile',
      );
    } else if (scenario == 'reentrant-dispose') {
      final sub = controller.changes.listen((state) {
        if (state.phase == AccountPhase.ready) controller.dispose();
      });
      access.change(owner);
      await flush();
      check(
        controller.readyRuntime == null,
        'dispose during event left runtime enabled',
      );
      await sub.cancel();
    } else {
      throw StateError('unknown account scenario');
    }
  } finally {
    controller.dispose();
    if (!access.events.isClosed) await access.events.close();
  }
}

const scenarios = [
  'profile-barrier',
  'credentials-duplicate',
  'profile-retry',
  'late-profile',
  'logout-failure',
  'late-signin-after-logout',
  'closed-lifecycle',
  'reentrant-revoke',
  'dispose-pending',
  'reentrant-dispose',
];
