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
        return value;
      });
      final vault = createWindowsSessionCredentialVault(
        'https://fixture.supabase.co',
      );
      await vault.writeRefreshToken('TEST_ONLY_REFRESH_SECRET');
      expect(await vault.readRefreshToken(), 'TEST_ONLY_REFRESH_SECRET');
      await vault.clear();
      expect(await vault.readRefreshToken(), isNull);
      expect(calls.map((c) => c.method), ['write', 'read', 'clear', 'read']);
    },
  );
  test(
    'Windows platform failures never expose raw secret exception details',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(
          code: 'PRIVATE',
          message: 'PRIVATE_REFRESH_SECRET',
          details: {'token': 'PRIVATE'},
        );
      });
      final vault = createWindowsSessionCredentialVault(
        'https://fixture.supabase.co',
      );
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
      vault.clear(),
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
