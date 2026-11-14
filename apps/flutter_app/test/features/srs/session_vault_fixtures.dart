import 'dart:async';
import 'package:nihongo_daily/features/auth/data/session_credential_vault.dart';

const vaultScenarios = [
  'read-write-clear',
  'canonical-scope',
  'invalid-origin',
  'invalid-secret',
  'malformed-read',
  'malformed-ack',
  'redacted-failure',
  'same-scope-serialization',
  'failed-write-recovery',
  'failed-read',
  'failed-clear',
  'independent-scopes',
];
void checkVault(bool value, String message) {
  if (!value) {
    throw StateError(message);
  }
}

// TEST ONLY port/secret values, never a user credential or OS vault.
final class FixtureCredentialBackend implements SessionCredentialBackend {
  final values = <String, String>{};
  int calls = 0;
  Completer<void>? delay;
  bool failWrite = false;
  bool failRead = false;
  bool failClear = false;
  Object? malformed;
  bool returnMalformed = false;
  @override
  Future<Object?> invoke(String method, Map<String, Object> args) async {
    calls++;
    if (returnMalformed) {
      return malformed;
    }
    final target = args['target']! as String;
    if (method == 'read') {
      if (failRead) {
        throw StateError('PRIVATE_READ_SECRET');
      }
      return values[target];
    }
    if (method == 'clear') {
      if (failClear) {
        throw StateError('PRIVATE_CLEAR_SECRET');
      }
      values.remove(target);
      return true;
    }
    await delay?.future;
    if (failWrite) {
      throw StateError('PRIVATE_REFRESH_SECRET / OS DETAILS');
    }
    values[target] = args['token']! as String;
    return true;
  }
}

Future<void> expectVaultFailure(
  Future<void> Function() action,
  SessionVaultError code,
) async {
  try {
    await action();
  } on SessionVaultFailure catch (error) {
    checkVault(error.code == code, 'wrong safe vault code');
    checkVault(!error.toString().contains('PRIVATE'), 'vault leaked raw error');
    return;
  }
  throw StateError('expected bounded vault failure');
}

Future<void> verifyVault(String scenario) async {
  final backend = FixtureCredentialBackend();
  final vault = SessionCredentialVault(
    projectUrl: 'https://fixture.supabase.co',
    backend: backend,
  );
  if (scenario == 'read-write-clear') {
    checkVault(
      await vault.readRefreshToken() == null,
      'missing value not null',
    );
    await vault.writeRefreshToken('TEST_ONLY_REFRESH_FIRST');
    await vault.writeRefreshToken('TEST_ONLY_REFRESH_SECOND');
    checkVault(
      await vault.readRefreshToken() == 'TEST_ONLY_REFRESH_SECOND',
      'replacement was not authoritative',
    );
    await vault.clear();
    await vault.clear();
    checkVault(await vault.readRefreshToken() == null, 'clear was not durable');
  } else if (scenario == 'canonical-scope') {
    final alias = SessionCredentialVault(
      projectUrl: 'https://FIXTURE.supabase.co:443/',
      backend: backend,
    );
    checkVault(alias.target == vault.target, 'same HTTPS origin split scope');
    await alias.writeRefreshToken('TEST_ONLY_REFRESH');
    checkVault(await vault.readRefreshToken() != null, 'canonical scope lost');
  } else if (scenario == 'invalid-origin') {
    for (final url in [
      'http://fixture.supabase.co',
      'https://user:private@fixture.supabase.co',
      'https://fixture.supabase.co/rest/v1',
      'https://fixture.supabase.co?token=PRIVATE',
      'https://fixture.supabase.co#PRIVATE',
      'https://',
      'https://fixture.supabase.co:70000',
    ]) {
      await expectVaultFailure(() async {
        SessionCredentialVault(projectUrl: url, backend: backend);
      }, SessionVaultError.invalidInput);
    }
    checkVault(backend.calls == 0, 'invalid origin touched backend');
  } else if (scenario == 'invalid-secret') {
    for (final token in ['', 'x' * 2049, 'a\nsecret', 'a\u0000b', ' a', '秘密']) {
      await expectVaultFailure(
        () => vault.writeRefreshToken(token),
        SessionVaultError.invalidInput,
      );
    }
    checkVault(backend.calls == 0, 'invalid secret reached backend');
    await vault.writeRefreshToken('x' * 2048);
    checkVault(
      (await vault.readRefreshToken())!.length == 2048,
      'bound rejected',
    );
  } else if (scenario == 'malformed-read') {
    backend.returnMalformed = true;
    for (final value in [
      true,
      <String, Object>{},
      '',
      'x' * 2049,
      'a\nsecret',
    ]) {
      backend.malformed = value;
      await expectVaultFailure(() async {
        await vault.readRefreshToken();
      }, SessionVaultError.corrupt);
    }
  } else if (scenario == 'malformed-ack') {
    backend.returnMalformed = true;
    for (final value in [null, false, 'true', 1]) {
      backend.malformed = value;
      await expectVaultFailure(
        () => vault.writeRefreshToken('TEST_ONLY_REFRESH'),
        SessionVaultError.corrupt,
      );
      await expectVaultFailure(vault.clear, SessionVaultError.corrupt);
    }
  } else if (scenario == 'redacted-failure') {
    backend.failWrite = true;
    await expectVaultFailure(
      () => vault.writeRefreshToken('TEST_ONLY_REFRESH'),
      SessionVaultError.unavailable,
    );
  } else if (scenario == 'same-scope-serialization') {
    backend.delay = Completer();
    final another = SessionCredentialVault(
      projectUrl: 'https://fixture.supabase.co/',
      backend: backend,
    );
    final write = vault.writeRefreshToken('TEST_ONLY_REFRESH');
    final clear = another.clear();
    final read = another.readRefreshToken();
    await Future<void>.delayed(Duration.zero);
    checkVault(backend.calls == 1, 'same scope reordered pending operations');
    backend.delay!.complete();
    await write;
    await clear;
    checkVault(await read == null, 'late write resurrected cleared secret');
  } else if (scenario == 'failed-write-recovery') {
    await vault.writeRefreshToken('TEST_ONLY_ORIGINAL');
    backend.failWrite = true;
    await expectVaultFailure(
      () => vault.writeRefreshToken('TEST_ONLY_NEW'),
      SessionVaultError.unavailable,
    );
    checkVault(
      await vault.readRefreshToken() == 'TEST_ONLY_ORIGINAL',
      'failed fixture write erased previous secret',
    );
    backend.failWrite = false;
    await vault.clear();
    await vault.writeRefreshToken('TEST_ONLY_RETRY');
    checkVault(
      await vault.readRefreshToken() != null,
      'queue remained poisoned',
    );
  } else if (scenario == 'failed-read') {
    await vault.writeRefreshToken('TEST_ONLY_ORIGINAL');
    backend.failRead = true;
    await expectVaultFailure(() async {
      await vault.readRefreshToken();
    }, SessionVaultError.unavailable);
    backend.failRead = false;
    checkVault(
      await vault.readRefreshToken() == 'TEST_ONLY_ORIGINAL',
      'read failure was treated as missing or changed stored secret',
    );
  } else if (scenario == 'failed-clear') {
    await vault.writeRefreshToken('TEST_ONLY_ORIGINAL');
    backend.failClear = true;
    await expectVaultFailure(vault.clear, SessionVaultError.unavailable);
    checkVault(
      await vault.readRefreshToken() == 'TEST_ONLY_ORIGINAL',
      'clear failure was acknowledged as missing',
    );
    backend.failClear = false;
    await vault.clear();
    checkVault(await vault.readRefreshToken() == null, 'clear retry failed');
  } else if (scenario == 'independent-scopes') {
    backend.delay = Completer();
    final otherBackend = FixtureCredentialBackend();
    final other = SessionCredentialVault(
      projectUrl: 'https://other.supabase.co',
      backend: otherBackend,
    );
    final pending = vault.writeRefreshToken('TEST_ONLY_A');
    await other.writeRefreshToken('TEST_ONLY_B');
    checkVault(
      await other.readRefreshToken() == 'TEST_ONLY_B',
      'other blocked',
    );
    backend.delay!.complete();
    await pending;
    await vault.clear();
    checkVault(await other.readRefreshToken() == 'TEST_ONLY_B', 'other erased');
  } else {
    throw StateError('unknown vault scenario');
  }
}
