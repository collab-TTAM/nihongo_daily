// TEST ONLY mock messenger; actual OS/runtime composition still needs Windows CI.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/application/windows_receipt_ai_runtime.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_reference.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nihongo_daily/conversation_receipts_v1');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });
  for (final clear in [false, true]) {
    test('Windows runtime explicit lifecycle clear=$clear', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });
      final scope = ConversationReceiptScope(
        projectUrl: 'https://life.invalid',
        ownerId: 'a1000000-0000-4000-8000-000000000001',
      );
      final owner = createWindowsReceiptAiRuntimeOwner(
        scope: scope,
        createTransport: ({required auth, required isReady, required store}) =>
            throw StateError('Factory must stay unused'),
      );
      expect(calls, isEmpty);
      if (clear) {
        await owner.signOut();
        expect(calls.length, 1);
        expect(calls.single.method, 'clear');
        expect(calls.single.arguments, {
          'target':
              'NihongoDaily.ConversationReceipt.v1|https://life.invalid|a1000000-0000-4000-8000-000000000001',
        });
      } else {
        await owner.close();
        expect(calls, isEmpty);
      }
    });
  }
  test(
    'Windows failed clear requires explicit retry and no synthetic success',
    () async {
      var calls = 0;
      var confirmed = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        return confirmed;
      });
      final owner = createWindowsReceiptAiRuntimeOwner(
        scope: ConversationReceiptScope(
          projectUrl: 'https://life.invalid',
          ownerId: 'a1000000-0000-4000-8000-000000000001',
        ),
        createTransport: ({required auth, required isReady, required store}) =>
            throw StateError('Factory must stay unused'),
      );
      final error = isA<AiTextFailure>().having(
        (e) => e.code,
        'code',
        AiTextErrorCode.internalError,
      );
      await expectLater(owner.signOut(), throwsA(error));
      await expectLater(owner.close(), throwsA(error));
      expect(calls, 1);
      confirmed = true;
      await owner.signOut();
      expect(calls, 2);
    },
  );
}
