// TEST ONLY storage/transport ports around actual runtime owner/session/decorator.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/application/receipt_ai_runtime_owner.dart';
import 'package:nihongo_daily/features/ai/application/ai_text_runtime_owner.dart';
import 'package:nihongo_daily/features/ai/data/conversation_receipt_store.dart';
import 'package:nihongo_daily/features/ai/data/receipt_guarded_ai_transport.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'receipt_guarded_ai_transport_test.dart' as f;

final class Backend implements SecureConversationReceiptBackend {
  Object? value;
  bool failClear = false;
  Completer<void>? clearWait;
  Completer<void>? writeWait;
  final entered = Completer<void>();
  final clearing = Completer<void>();
  final calls = <String>[];
  @override
  Future<Object?> read(String target) async => value;
  @override
  Future<void> write(String target, String encoded) async {
    calls.add('write-begin');
    entered.complete();
    await writeWait?.future;
    value = encoded;
    calls.add('write-end');
  }

  @override
  Future<void> clear(String target) async {
    calls.add('clear-begin');
    if (!clearing.isCompleted) clearing.complete();
    await clearWait?.future;
    if (failClear) throw StateError('PRIVATE_CLEAR');
    value = null;
    calls.add('clear-end');
  }
}

void main() {
  late Backend backend;
  late ConversationReceiptStore store;
  late f.Auth auth;
  late f.Inner inner;
  late ReceiptAiRuntimeOwner owner;
  setUp(() {
    backend = Backend();
    store = ConversationReceiptStore(scope: f.scope, backend: backend);
    auth = f.Auth();
    inner = f.Inner();
    owner = ReceiptAiRuntimeOwner(
      store: store,
      createTransport: ({required auth, required isReady, required store}) =>
          ReceiptGuardedAiTransport(
            inner: inner,
            store: store,
            auth: auth,
            capturedSession: auth.currentSession!,
            isReady: isReady,
          ),
    );
    addTearDown(store.close);
  });
  void expectClaimed() {
    expect(
      () => ConversationReceiptStore(scope: f.scope, backend: backend),
      throwsA(isA<ConversationReceiptStoreFailure>()),
    );
  }

  Future<void> released() async {
    final next = ConversationReceiptStore(scope: f.scope, backend: backend);
    await next.close();
  }

  test(
    'construction does not create a transport or storage operation',
    () async {
      expect(backend.calls, isEmpty);
      expect(inner.closes, 0);
      expectClaimed();
      await owner.close();
      expect(backend.calls, isEmpty);
      await released();
    },
  );
  test(
    'preserve close retains pending metadata and forbids later implicit signout',
    () async {
      backend.value = 'TEST_ONLY_PENDING';
      final closing = owner.close();
      expect(identical(owner.close(), closing), true);
      await closing;
      expect(backend.value, 'TEST_ONLY_PENDING');
      expect(backend.calls, isEmpty);
      await expectLater(
        owner.signOut(),
        throwsA(f.code(AiTextErrorCode.internalError)),
      );
      expect(backend.value, 'TEST_ONLY_PENDING');
      await released();
    },
  );
  test(
    'signout shares pending clear and releases only after confirmed success',
    () async {
      backend.value = 'TEST_ONLY_PENDING';
      backend.clearWait = Completer<void>();
      final signing = owner.signOut();
      await backend.clearing.future;
      expect(identical(owner.signOut(), signing), true);
      expect(identical(owner.close(), signing), true);
      expectClaimed();
      expect(backend.value, 'TEST_ONLY_PENDING');
      backend.clearWait!.complete();
      await signing;
      expect(backend.value, isNull);
      expect(store.phase, ConversationReceiptStorePhase.closed);
      await released();
    },
  );
  test(
    'failed clear keeps claim and explicit retry cannot be bypassed by close',
    () async {
      backend.value = 'TEST_ONLY_PENDING';
      backend.failClear = true;
      await expectLater(
        owner.signOut(),
        throwsA(f.code(AiTextErrorCode.internalError)),
      );
      expectClaimed();
      expect(backend.value, 'TEST_ONLY_PENDING');
      expect(store.phase, ConversationReceiptStorePhase.revoked);
      await expectLater(
        owner.close(),
        throwsA(f.code(AiTextErrorCode.internalError)),
      );
      expect(backend.calls, ['clear-begin']);
      backend.failClear = false;
      await owner.signOut();
      expect(backend.calls, ['clear-begin', 'clear-begin', 'clear-end']);
      await released();
    },
  );
  for (final clear in [false, true]) {
    test('shutdown waits held receipt write clear=$clear', () async {
      backend.writeWait = Completer<void>();
      final flow = owner.runtime.acquireConversation(
        auth: auth,
        generation: AiTextGeneration(),
        isReady: () => true,
      )!;
      final sending = expectLater(
        flow.start(f.start),
        throwsA(f.code(AiTextErrorCode.unauthorized)),
      );
      await backend.entered.future;
      var ended = false;
      final shutdown = (clear ? owner.signOut() : owner.close()).then((_) {
        ended = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(inner.revoked, true);
      expect(inner.sends, 0);
      expect(inner.closes, 0);
      expect(ended, false);
      expectClaimed();
      expect(backend.calls, ['write-begin']);
      backend.writeWait!.complete();
      await sending;
      await shutdown;
      expect(inner.sends, 0);
      expect(inner.closes, 1);
      expect(
        backend.calls,
        clear
            ? ['write-begin', 'write-end', 'clear-begin', 'clear-end']
            : ['write-begin', 'write-end'],
      );
      expect(backend.value, clear ? isNull : isNotNull);
      await released();
    });
  }
  for (final error in [false, true]) {
    test(
      'signout waits actual late HTTP error=$error before deleting pending metadata',
      () async {
        inner.wire = Completer<Object?>();
        final flow = owner.runtime.acquireConversation(
          auth: auth,
          generation: AiTextGeneration(),
          isReady: () => true,
        )!;
        final sending = expectLater(
          flow.start(f.start),
          throwsA(f.code(AiTextErrorCode.unauthorized)),
        );
        await inner.entered.future;
        final shutdown = owner.signOut();
        await Future<void>.delayed(Duration.zero);
        expect(inner.revoked, true);
        expectClaimed();
        expect(backend.value, isNotNull);
        expect(backend.calls, ['write-begin', 'write-end']);
        if (error) {
          inner.wire!.completeError(StateError('PRIVATE_LATE'));
        } else {
          inner.wire!.complete({'TEST_ONLY': 'late'});
        }
        await sending;
        await shutdown;
        expect(inner.closes, 1);
        expect(backend.value, isNull);
        expect(backend.calls.last, 'clear-end');
        await released();
      },
    );
  }
  test('failed owned drain never clears or releases the store', () async {
    inner.badClose = true;
    owner.runtime.acquireConversation(
      auth: auth,
      generation: AiTextGeneration(),
      isReady: () => true,
    );
    backend.value = 'TEST_ONLY_PENDING';
    await expectLater(
      owner.signOut(),
      throwsA(f.code(AiTextErrorCode.internalError)),
    );
    expect(backend.calls, isEmpty);
    expect(backend.value, 'TEST_ONLY_PENDING');
    expectClaimed();
    await expectLater(
      owner.signOut(),
      throwsA(f.code(AiTextErrorCode.internalError)),
    );
    expect(inner.closes, 1);
    expect(backend.calls, isEmpty);
  });
}
