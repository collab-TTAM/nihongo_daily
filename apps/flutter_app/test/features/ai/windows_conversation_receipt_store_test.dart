// TEST ONLY mock channel, not Windows Credential Manager or native restart proof.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/data/conversation_receipt_store.dart';
import 'package:nihongo_daily/features/ai/data/windows_conversation_receipt_store.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_reference.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';

const origin = 'https://receipt-channel.supabase.invalid';
const owner = 'a1000000-0000-4000-8000-000000000001';
const event = 'b1000000-0000-4000-8000-000000000001';
const channel = MethodChannel('nihongo_daily/conversation_receipts_v1');
final scope = ConversationReceiptScope(projectUrl: origin, ownerId: owner);
final reference = ConversationReceiptReference.fromStart(
  projectUrl: origin,
  ownerId: owner,
  request: StartConversationRequest(
    scenarioId: owner,
    level: AiTextLevel.n5,
    clientEventId: event,
  ),
);
Matcher get unavailable => isA<ConversationReceiptStoreFailure>()
    .having((e) => e.code, 'code', ConversationReceiptStoreError.unavailable)
    .having((e) => e.toString().contains('PRIVATE'), 'safe error', false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    calls.clear();
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });
  ConversationReceiptStore open() {
    final store = createWindowsConversationReceiptStore(scope: scope);
    addTearDown(store.close);
    return store;
  }

  test(
    'fixed receipt channel sends scoped metadata only and strict confirmed actions',
    () async {
      String? saved;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'read') return saved;
        if (call.method == 'write') {
          saved =
              (call.arguments as Map<Object?, Object?>)['reference']! as String;
          return true;
        }
        if (call.method == 'clear') {
          saved = null;
          return true;
        }
        throw StateError('Unexpected method');
      });
      final store = open();
      await store.reserve(reference);
      expect((await store.read())!.encode(), reference.encode());
      await store.clearForSignOut();
      expect(saved, isNull);
      expect(calls.map((c) => c.method), ['read', 'write', 'read', 'clear']);
      for (final call in calls) {
        expect(call.arguments, {
          'target': '${ConversationReceiptStore.targetPrefix}$origin|$owner',
          if (call.method == 'write') 'reference': reference.encode(),
        });
      }
    },
  );

  test('unsupported platform dispatches nothing', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    final store = open();
    await expectLater(store.read(), throwsA(unavailable));
    expect(calls, isEmpty);
  });

  test(
    'missing native receiver fails closed without simulated success',
    () async {
      final store = open();
      await expectLater(store.reserve(reference), throwsA(unavailable));
      expect(store.phase, ConversationReceiptStorePhase.failed);
    },
  );

  test('private native error details never escape', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(
        code: 'PRIVATE_CODE',
        message: 'PRIVATE_TOKEN',
        details: {'PRIVATE': owner},
      );
    });
    await expectLater(open().read(), throwsA(unavailable));
  });

  for (final ack in <Object?>[null, false, 'true', 1]) {
    test('write acknowledgment must be actual bool true ack=$ack', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'read' ? null : ack,
      );
      final store = open();
      await expectLater(store.reserve(reference), throwsA(unavailable));
      expect(store.phase, ConversationReceiptStorePhase.failed);
    });
    test('clear acknowledgment must be actual bool true ack=$ack', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => ack);
      final store = open();
      await expectLater(store.clearForSignOut(), throwsA(unavailable));
      expect(store.phase, ConversationReceiptStorePhase.revoked);
    });
  }

  for (final value in <Object?>[
    true,
    1,
    'PRIVATE_RAW',
    '${reference.encode()} ',
    reference.encode().replaceFirst(
      owner,
      'a1000000-0000-4000-8000-000000000002',
    ),
  ]) {
    test('corrupt native value cannot become a receipt value=$value', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => value);
      final store = open();
      await expectLater(store.read(), throwsA(unavailable));
      expect(store.phase, ConversationReceiptStorePhase.failed);
    });
  }
}
