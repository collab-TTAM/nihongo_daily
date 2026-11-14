import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/auth/data/session_credential_vault.dart';
import 'package:nihongo_daily/features/auth/data/windows_review_directory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nihongo_daily/session_vault_v1');
  const origin = 'https://example.supabase.invalid';
  final path =
      'C:\\Users\\学習者\\AppData\\Local\\NihongoDaily\\ReviewJournal\\v1\\${'a' * 64}';
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'directory channel has canonical scope and preserves Unicode OS path',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'reviewDirectory');
            expect(call.arguments, {
              'target': 'NihongoDaily.Refresh.v1|$origin',
            });
            return path;
          });
      expect((await resolveWindowsReviewDirectory(origin)).path, path);
    },
  );
  test(
    'malformed or failed path result never falls back to cwd or temp',
    () async {
      for (final value in <Object?>[
        null,
        123,
        'relative/path',
        '\\\\server\\share',
        'C:\\Users\\..\\bad',
        'C:\\PRIVATE',
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (_) async => value);
        await expectLater(
          resolveWindowsReviewDirectory(origin),
          throwsA(isA<SessionVaultFailure>()),
        );
      }
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw PlatformException(
              code: 'PRIVATE',
              message: 'PRIVATE PATH',
            ),
          );
      await expectLater(
        resolveWindowsReviewDirectory(origin),
        throwsA(isA<SessionVaultFailure>()),
      );
    },
  );
  test('unsupported platform does not call native directory handler', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          calls++;
          return path;
        });
    await expectLater(
      resolveWindowsReviewDirectory(origin),
      throwsA(isA<SessionVaultFailure>()),
    );
    expect(calls, 0);
  });
}
