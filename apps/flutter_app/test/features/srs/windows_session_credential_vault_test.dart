import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/auth/data/session_credential_vault.dart';
import 'package:nihongo_daily/features/auth/data/windows_session_credential_vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nihongo_daily/session_vault_v1');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });
  test(
    'Windows method channel uses only bounded scoped credential arguments',
    () async {
      String? value;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        final args = call.arguments as Map;
        expect(
          args['target'],
          'NihongoDaily.Refresh.v1|https://fixture.supabase.co',
        );
        if (call.method == 'write') {
          expect(args.keys.toSet(), {'target', 'token'});
          value = args['token'] as String;
          return true;
        }
        expect(args.keys.toSet(), {'target'});
        if (call.method == 'clear') {
          value = null;
          return true;
        }
        if (call.method == 'acquireOwner' || call.method == 'releaseOwner') {
          return true;
        }
        return value;
      });
      final vault = createWindowsSessionCredentialVault(
        'https://fixture.supabase.co',
      );
      await vault.acquireOwner();
      await vault.writeRefreshToken('TEST_ONLY_REFRESH_SECRET');
      expect(await vault.readRefreshToken(), 'TEST_ONLY_REFRESH_SECRET');
      await vault.clear();
      expect(await vault.readRefreshToken(), isNull);
      await vault.releaseOwner();
      expect(calls.map((c) => c.method), [
        'acquireOwner',
        'write',
        'read',
        'clear',
        'read',
        'releaseOwner',
      ]);
    },
  );

  test(
    'Windows vault rejects storage calls outside its acquired owner lease',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'acquireOwner' || call.method == 'releaseOwner') {
          return true;
        }
        if (call.method == 'write' || call.method == 'clear') return true;
        if (call.method == 'read') return null;
        throw MissingPluginException();
      });
      final vault = createWindowsSessionCredentialVault(
        'https://fixture.supabase.co',
      );
      Future<void> unavailable<T>(Future<T> operation) async {
        await expectLater(
          operation,
          throwsA(
            isA<SessionVaultFailure>().having(
              (error) => error.code,
              'owner lease required',
              SessionVaultError.unavailable,
            ),
          ),
        );
      }

      await unavailable(vault.readRefreshToken());
      await unavailable(vault.writeRefreshToken('TEST_ONLY_REFRESH'));
      await unavailable(vault.clear());
      expect(calls, isEmpty);

      await vault.acquireOwner();
      await vault.writeRefreshToken('TEST_ONLY_REFRESH');
      await vault.releaseOwner();

      await unavailable(vault.readRefreshToken());
      await unavailable(vault.writeRefreshToken('TEST_ONLY_REFRESH'));
      await unavailable(vault.clear());
      expect(calls, ['acquireOwner', 'write', 'releaseOwner']);
    },
  );

  test(
    'failed Windows owner release retains the lease for an explicit retry',
    () async {
      var releaseCalls = 0;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'acquireOwner') return true;
        if (call.method == 'releaseOwner') return ++releaseCalls > 1;
        if (call.method == 'read') return 'TEST_ONLY_REFRESH_SECRET';
        return true;
      });
      final vault = createWindowsSessionCredentialVault(
        'https://fixture.supabase.co',
      );
      await vault.acquireOwner();
      await expectLater(
        vault.releaseOwner(),
        throwsA(
          isA<SessionVaultFailure>().having(
            (error) => error.code,
            'failed release remains owned',
            SessionVaultError.unavailable,
          ),
        ),
      );
      expect(await vault.readRefreshToken(), 'TEST_ONLY_REFRESH_SECRET');
      await vault.releaseOwner();
      await expectLater(
        vault.readRefreshToken(),
        throwsA(
          isA<SessionVaultFailure>().having(
            (error) => error.code,
            'released facade is fenced',
            SessionVaultError.unavailable,
          ),
        ),
      );
      expect(releaseCalls, 2);
      expect(calls, ['acquireOwner', 'releaseOwner', 'read', 'releaseOwner']);
    },
  );

  test('Windows owner lease uses only the canonical project target', () async {
    final calls = <MethodCall>[];
    var allowAcquire = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      expect(call.method, anyOf('acquireOwner', 'releaseOwner'));
      expect(call.arguments, {
        'target': 'NihongoDaily.Refresh.v1|https://fixture.supabase.co',
      });
      if (call.method == 'acquireOwner') return allowAcquire;
      return true;
    });
    final vault = createWindowsSessionCredentialVault(
      'https://fixture.supabase.co',
    );
    await vault.acquireOwner();
    await vault.releaseOwner();
    expect(calls.map((call) => call.method), ['acquireOwner', 'releaseOwner']);

    allowAcquire = false;
    await expectLater(
      vault.acquireOwner(),
      throwsA(
        isA<SessionVaultFailure>().having(
          (error) => error.code,
          'busy owner lease',
          SessionVaultError.unavailable,
        ),
      ),
    );
    expect(calls.last.method, 'acquireOwner');
  });

  test(
    'Windows platform failures never expose raw secret exception details',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'acquireOwner' || call.method == 'releaseOwner') {
          return true;
        }
        throw PlatformException(
          code: 'PRIVATE',
          message: 'PRIVATE_REFRESH_SECRET',
          details: {'token': 'PRIVATE'},
        );
      });
      final vault = createWindowsSessionCredentialVault(
        'https://fixture.supabase.co',
      );
      await vault.acquireOwner();
      await expectLater(
        vault.readRefreshToken(),
        throwsA(
          isA<SessionVaultFailure>().having(
            (e) => e.toString().contains('PRIVATE'),
            'safe error',
            false,
          ),
        ),
      );
      await vault.releaseOwner();
    },
  );
  test(
    'unsupported platform has no file browser or plaintext fallback',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        return true;
      });
      final vault = createWindowsSessionCredentialVault(
        'https://fixture.supabase.co',
      );
      await expectLater(
        vault.acquireOwner(),
        throwsA(
          isA<SessionVaultFailure>().having(
            (e) => e.code,
            'unsupported owner lease',
            SessionVaultError.unavailable,
          ),
        ),
      );
      for (final action in [
        () async {
          await vault.readRefreshToken();
        },
        () => vault.writeRefreshToken('TEST_ONLY'),
        vault.clear,
      ]) {
        await expectLater(
          action(),
          throwsA(
            isA<SessionVaultFailure>().having(
              (e) => e.code,
              'unsupported',
              SessionVaultError.unavailable,
            ),
          ),
        );
      }
      expect(calls, 0);
    },
  );
  test('missing Windows channel fails safely without success', () async {
    final vault = createWindowsSessionCredentialVault(
      'https://fixture.supabase.co',
    );
    await expectLater(
      vault.acquireOwner(),
      throwsA(
        isA<SessionVaultFailure>().having(
          (e) => e.code,
          'missing channel',
          SessionVaultError.unavailable,
        ),
      ),
    );
  });
}
