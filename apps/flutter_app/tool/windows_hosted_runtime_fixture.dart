// Manual-only hosted staging fixture. Never used by the learner entrypoint.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/application/persistent_supabase_runtime.dart';
import 'package:nihongo_daily/features/auth/data/persistent_account_access.dart';
import 'package:nihongo_daily/features/auth/data/windows_session_credential_vault.dart';
import 'package:nihongo_daily/features/srs/data/durable_review_repository.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/data/supabase_review_binding.dart';

const _phases = {'login-a', 'restore-a', 'logout-a', 'login-b', 'cleanup'};

final class _HostedSettings {
  const _HostedSettings({
    required this.projectUrl,
    required this.publishableKey,
    required this.emailA,
    required this.passwordA,
    required this.emailB,
    required this.passwordB,
  });

  final String projectUrl;
  final String publishableKey;
  final String emailA;
  final String passwordA;
  final String emailB;
  final String passwordB;
}

String _required(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty || value.length > 4096) {
    throw const FormatException('Hosted staging configuration unavailable');
  }
  return value;
}

_HostedSettings _settings() {
  final projectUrl = SupabaseReviewBinding.validateProjectUrl(
    _required('ND_STAGING_SUPABASE_URL'),
  );
  final uri = Uri.parse(projectUrl);
  if (uri.scheme != 'https' ||
      uri.port != 443 ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      !const {'', '/'}.contains(uri.path) ||
      !RegExp(r'^[a-z0-9-]+\.supabase\.co$').hasMatch(uri.host)) {
    throw const FormatException('Hosted staging project unavailable');
  }
  final publishableKey = SupabaseReviewBinding.validatePublicKey(
    _required('ND_STAGING_SUPABASE_PUBLISHABLE_KEY'),
  );
  final emailA = _required('ND_STAGING_USER_A_EMAIL').trim();
  final passwordA = _required('ND_STAGING_USER_A_PASSWORD');
  final emailB = _required('ND_STAGING_USER_B_EMAIL').trim();
  final passwordB = _required('ND_STAGING_USER_B_PASSWORD');
  final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (emailA.length > 254 ||
      emailB.length > 254 ||
      !emailPattern.hasMatch(emailA) ||
      !emailPattern.hasMatch(emailB) ||
      emailA.toLowerCase() == emailB.toLowerCase() ||
      passwordA.length > 4096 ||
      passwordB.length > 4096) {
    throw const FormatException('Hosted staging accounts unavailable');
  }
  return _HostedSettings(
    projectUrl: projectUrl,
    publishableKey: publishableKey,
    emailA: emailA,
    passwordA: passwordA,
    emailB: emailB,
    passwordB: passwordB,
  );
}

void _check(bool value) {
  if (!value) {
    throw const FormatException('Hosted Windows runtime check failed');
  }
}

/// Auth-only fixture store. No review event is staged or dispatched by this probe.
final class _EmptyReviewStore implements DurableReviewStore {
  @override
  Future<List<StoredReview>> list(String userId) async => const <StoredReview>[];

  @override
  Future<StoredReview> stage(
    String userId,
    Map<String, Object> request,
  ) async {
    throw const ReviewStorageFailure();
  }

  @override
  Future<void> acknowledge(
    String userId,
    String eventId,
    ReviewSuccess receipt,
  ) async {
    throw const ReviewStorageFailure();
  }

  @override
  Future<void> reject(
    String userId,
    String eventId,
    ReviewFailure rejection,
  ) async {
    throw const ReviewStorageFailure();
  }
}

void _requireReady(PersistentSupabaseRuntime runtime) {
  final session = runtime.persistence.currentSession;
  final profile = runtime.account.state.profile;
  _check(runtime.persistence.phase == SessionPersistencePhase.ready);
  _check(runtime.account.state.phase == AccountPhase.ready);
  _check(runtime.account.readyRuntime != null);
  _check(session != null && profile != null && profile.id == session.userId);
}

Future<void> _signInAndWait(
  PersistentSupabaseRuntime runtime,
  String email,
  String password,
) async {
  await runtime.account.signIn(email, password);
  await runtime.account.waitForCurrentProfile();
  _requireReady(runtime);
}

Future<void> verifyWindowsHostedRuntimePhase(
  String phase,
  _HostedSettings settings,
) async {
  final vault = createWindowsSessionCredentialVault(settings.projectUrl);
  if (phase == 'cleanup') {
    await vault.acquireOwner();
    var cleared = false;
    try {
      await vault.clear();
      _check(await vault.readRefreshToken() == null);
      cleared = true;
    } finally {
      // On failure, process exit abandons the native mutex; do not release a
      // project owner while a failed credential clear may still be unresolved.
      if (cleared) await vault.releaseOwner();
    }
    return;
  }

  final runtime = PersistentSupabaseRuntime(
    projectUrl: settings.projectUrl,
    publishableKey: settings.publishableKey,
    vault: vault,
    store: _EmptyReviewStore(),
  );
  var closed = false;
  try {
    switch (phase) {
      case 'login-a':
        await runtime.start();
        _check(runtime.persistence.phase == SessionPersistencePhase.idle);
        _check(await vault.readRefreshToken() == null);
        await _signInAndWait(runtime, settings.emailA, settings.passwordA);
        final saved = await vault.readRefreshToken();
        _check(saved != null && saved.isNotEmpty);
        await runtime.close();
        closed = true;
        _check(await vault.readRefreshToken() == saved);
        break;
      case 'restore-a':
        // This is a fresh Windows process. start() must restore through GoTrue,
        // persist its current refresh value, and provision A's own profile.
        await runtime.start();
        await runtime.account.waitForCurrentProfile();
        _requireReady(runtime);
        final saved = await vault.readRefreshToken();
        _check(saved != null && saved.isNotEmpty);
        await runtime.close();
        closed = true;
        _check(await vault.readRefreshToken() == saved);
        break;
      case 'logout-a':
        await runtime.start();
        await runtime.account.waitForCurrentProfile();
        _requireReady(runtime);
        await runtime.account.signOut();
        _check(runtime.account.state.phase == AccountPhase.signedOut);
        _check(runtime.persistence.currentSession == null);
        _check(await vault.readRefreshToken() == null);
        await runtime.close();
        closed = true;
        break;
      case 'login-b':
        await runtime.start();
        _check(await vault.readRefreshToken() == null);
        await _signInAndWait(runtime, settings.emailB, settings.passwordB);
        final saved = await vault.readRefreshToken();
        _check(saved != null && saved.isNotEmpty);
        await runtime.account.signOut();
        _check(runtime.account.state.phase == AccountPhase.signedOut);
        _check(await vault.readRefreshToken() == null);
        await runtime.close();
        closed = true;
        break;
      default:
        throw const FormatException('Hosted Windows runtime phase unavailable');
    }
  } finally {
    if (!closed) await runtime.close();
  }
}

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox.shrink());
  var passed = false;
  try {
    if (!Platform.isWindows ||
        arguments.length != 1 ||
        !_phases.contains(arguments.single)) {
      throw const FormatException('Hosted Windows runtime phase unavailable');
    }
    final settings = _settings();
    await verifyWindowsHostedRuntimePhase(arguments.single, settings);
    passed = true;
  } on Object {
    // Do not print exception text, emails, passwords, access tokens or refresh tokens.
    stderr.writeln('Hosted Windows runtime verification failed');
  }
  await stdout.flush();
  await stderr.flush();
  exit(passed ? 0 : 1);
}
