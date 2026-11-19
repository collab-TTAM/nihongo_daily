// TEST ONLY Auth/receipt/storage/dispatch. No hosted or production host proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_receipt_lookup.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_session.dart';
import 'package:nihongo_daily/features/ai/data/conversation_receipt_dispatch.dart';
import 'package:nihongo_daily/features/ai/data/conversation_receipt_store.dart';
import 'package:nihongo_daily/features/ai/domain/pending_conversation_command_envelope.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'captured_conversation_session_test.dart' as f;
import 'lane_completion_reconciliation_test.dart' as h;
import 'session_completion_application_test.dart' as s;

Matcher get conflict => isA<ReceiptDispatchFailure>().having(
  (e) => e.code,
  'fixed conflict',
  ReceiptDispatchError.conflict,
);

ConversationReceiptDispatch<int> gate(
  ConversationReceiptStore store,
  f.Auth auth,
  PendingConversationCommandEnvelope command, {
  bool legacy = false,
  bool Function()? ready,
  Future<int> Function(ReviewSession)? dispatch,
}) {
  final result = ConversationReceiptDispatch<int>(
    store: store,
    reference: command.reference,
    originalCommand: legacy ? null : command,
    auth: auth,
    capturedSession: auth.currentSession!,
    isReady: ready ?? () => true,
    dispatch: dispatch ?? (_) async => fail('unexpected dispatch'),
  );
  addTearDown(result.close);
  return result;
}

Future<void> blocked(
  ConversationReceiptStore store,
  f.Auth auth,
  PendingConversationCommandEnvelope command,
) async {
  await expectLater(gate(store, auth, command).submit(), throwsA(conflict));
}

void main() {
  setUpAll(() {
    f.fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  for (final op in h.operations) {
    for (final changed in [false, true]) {
      test('$op full-original release changed=$changed', () async {
        final p = await s.pending(op);
        final command = h.command(op);
        final backend = h.Backend(command.reference.encode());
        final store = h.store(backend);
        final original = h.command(op, changed: changed);
        expect(original.reference.encode(), command.reference.encode());
        final first = gate(store, p.auth, original);
        await expectLater(first.submit(), throwsA(conflict));
        final c = await h.completion(p.auth, command);
        expect(p.flow.captureAppliedCompletion(c.handle, store: store), isNull);
        expect(
          await p.flow.applyRetainedCompletion(c.handle, store: store),
          isTrue,
        );
        final proof = p.flow.captureAppliedCompletion(c.handle, store: store)!;
        expect(proof.toString(), 'CapturedConversationApplication');
        final calls = [...backend.calls];
        expect(first.releaseAppliedCompletion(proof), !changed);
        expect(backend.calls, calls); // Release itself performs no storage I/O.
        await expectLater(first.submit(), throwsA(conflict));
        if (changed) {
          await blocked(store, p.auth, command);
          expect(backend.calls, calls);
        } else {
          var sends = 0;
          final nextCommand = PendingConversationCommandEnvelope.fromTurn(
            projectUrl: h.origin,
            ownerId: f.owner,
            request: f.turn(event: f.otherEvent),
          );
          final next = gate(
            store,
            p.auth,
            nextCommand,
            dispatch: (_) async => ++sends,
          );
          expect(await next.submit(), 1);
          expect(sends, 1);
          expect(backend.value, nextCommand.reference.encode());
          expect(first.releaseAppliedCompletion(proof), isFalse);
          expect(next.releaseAppliedCompletion(proof), isFalse);
          await expectLater(next.submit(), throwsA(conflict));
          await blocked(store, p.auth, nextCommand);
          expect(sends, 1);
          expect(backend.value, nextCommand.reference.encode());
        }
      });
    }
  }
  for (final transition in [
    'refresh',
    'account',
    'session',
    'reader',
    'store',
    'gate',
  ]) {
    test('applied proof cannot release after $transition', () async {
      final p = await s.pending(h.operations.first);
      final command = h.command(h.operations.first);
      final backend = h.Backend(command.reference.encode());
      final store = h.store(backend);
      final first = gate(store, p.auth, command);
      await expectLater(first.submit(), throwsA(conflict));
      final c = await h.completion(p.auth, command);
      expect(
        await p.flow.applyRetainedCompletion(c.handle, store: store),
        isTrue,
      );
      final proof = p.flow.captureAppliedCompletion(c.handle, store: store)!;
      final old = p.auth.currentSession;
      switch (transition) {
        case 'refresh':
          p.auth.currentSession = ReviewSession(userId: f.owner);
        case 'account':
          p.auth.currentSession = ReviewSession(userId: f.otherEvent);
        case 'session':
          p.flow.revoke();
        case 'reader':
          c.reader.revoke();
        case 'store':
          await store.close();
        case 'gate':
          await first.close();
      }
      final calls = [...backend.calls];
      expect(first.releaseAppliedCompletion(proof), isFalse);
      p.auth.currentSession = old;
      await blocked(store, p.auth, command);
      expect(backend.calls, calls);
      expect(backend.value, isNull);
    });
  }
  test(
    'legacy and wrong gate cannot consume proof or free owning claim',
    () async {
      final p = await s.pending(h.operations.first);
      final command = h.command(h.operations.first);
      final backend = h.Backend(command.reference.encode());
      final store = h.store(backend);
      final first = gate(store, p.auth, command, legacy: true);
      await expectLater(first.submit(), throwsA(conflict));
      final c = await h.completion(p.auth, command);
      expect(
        await p.flow.applyRetainedCompletion(c.handle, store: store),
        isTrue,
      );
      final proof = p.flow.captureAppliedCompletion(c.handle, store: store)!;
      final other = gate(store, p.auth, command);
      expect(first.releaseAppliedCompletion(proof), isFalse);
      await expectLater(other.submit(), throwsA(conflict));
      expect(other.releaseAppliedCompletion(proof), isFalse);
      expect(
        p.flow.captureAppliedCompletion(c.handle, store: store),
        same(proof),
      );
      expect(proof.consumeForTransport(auth: p.auth, store: store), isNotNull);
      expect(proof.consumeForTransport(auth: p.auth, store: store), isNull);
      await blocked(store, p.auth, command);
      expect(backend.calls, ['read', 'read', 'clear', 'read']);
    },
  );
  test('foreign Auth/store rejected without consuming genuine proof', () async {
    final p = await s.pending(h.operations.first);
    final command = h.command(h.operations.first);
    final backend = h.Backend(command.reference.encode());
    final store = h.store(backend);
    final first = gate(store, p.auth, command);
    await expectLater(first.submit(), throwsA(conflict));
    final c = await h.completion(p.auth, command);
    expect(
      await p.flow.applyRetainedCompletion(c.handle, store: store),
      isTrue,
    );
    final proof = p.flow.captureAppliedCompletion(c.handle, store: store)!;
    final foreignAuth = f.Auth()..currentSession = p.auth.currentSession;
    final foreignStore = ConversationReceiptStore(
      scope: PendingConversationCommandEnvelope.fromStart(
        projectUrl: 'https://foreign-proof.test',
        ownerId: f.owner,
        request: f.start(),
      ).reference.scope,
      backend: h.Backend(null),
    );
    addTearDown(foreignStore.close);
    expect(proof.consumeForTransport(auth: foreignAuth, store: store), isNull);
    expect(
      proof.consumeForTransport(auth: p.auth, store: foreignStore),
      isNull,
    );
    expect(first.releaseAppliedCompletion(proof), isTrue);
    expect(p.flow.captureAppliedCompletion(c.handle, store: store), isNull);
  });
  test('held confirmed clear exposes no proof before publication', () async {
    final p = await s.pending(h.operations.first);
    final command = h.command(h.operations.first);
    final backend = h.Backend(command.reference.encode())
      ..holdClear = Completer<void>();
    final store = h.store(backend);
    final first = gate(store, p.auth, command);
    await expectLater(first.submit(), throwsA(conflict));
    final c = await h.completion(p.auth, command);
    final applying = p.flow.applyRetainedCompletion(c.handle, store: store);
    await backend.clearEntered.future;
    expect(p.flow.captureAppliedCompletion(c.handle, store: store), isNull);
    await blocked(store, p.auth, command);
    backend.holdClear!.complete();
    expect(await applying, isTrue);
    expect(
      first.releaseAppliedCompletion(
        p.flow.captureAppliedCompletion(c.handle, store: store)!,
      ),
      isTrue,
    );
  });
  test(
    'preview and direct metadata clear cannot mint proof or release',
    () async {
      final p = await s.pending(h.operations.first);
      final command = h.command(h.operations.first);
      final backend = h.Backend(command.reference.encode());
      final store = h.store(backend);
      final first = gate(store, p.auth, command);
      await expectLater(first.submit(), throwsA(conflict));
      final c = await h.completion(p.auth, command);
      expect(p.flow.previewRetainedCompletion(c.handle), isNotNull);
      expect(p.flow.captureAppliedCompletion(c.handle, store: store), isNull);
      expect(
        await store.clearMatching(command.reference, isCurrent: () => true),
        isTrue,
      );
      expect(p.flow.captureAppliedCompletion(c.handle, store: store), isNull);
      expect(
        await p.flow.applyRetainedCompletion(c.handle, store: store),
        isFalse,
      );
      expect(p.flow.captureAppliedCompletion(c.handle, store: store), isNull);
      await blocked(store, p.auth, command);
    },
  );
  for (final lateError in [false, true]) {
    test(
      'real gate I/O must drain before release lateError=$lateError',
      () async {
        final p = await s.pending(h.operations.first);
        final command = h.command(h.operations.first);
        final backend = h.Backend(null);
        final store = h.store(backend);
        final wire = Completer<int>();
        final entered = Completer<void>();
        var sends = 0;
        final first = gate(
          store,
          p.auth,
          command,
          dispatch: (_) {
            sends++;
            entered.complete();
            return wire.future;
          },
        );
        final submitting = first.submit();
        final observed = lateError
            ? expectLater(submitting, throwsA(isA<ReceiptDispatchFailure>()))
            : expectLater(submitting, completion(1));
        await entered.future;
        final c = await h.completion(p.auth, command);
        expect(
          await p.flow.applyRetainedCompletion(c.handle, store: store),
          isTrue,
        );
        final proof = p.flow.captureAppliedCompletion(c.handle, store: store)!;
        expect(first.releaseAppliedCompletion(proof), isFalse);
        expect(
          p.flow.captureAppliedCompletion(c.handle, store: store),
          same(proof),
        );
        await blocked(store, p.auth, command);
        expect(sends, 1);
        if (lateError) {
          wire.completeError(StateError('PRIVATE_WIRE'));
        } else {
          wire.complete(1);
        }
        await observed;
        await f.settle();
        expect(first.releaseAppliedCompletion(proof), isTrue);
        expect(sends, 1);
      },
    );
  }
  for (final target in ['session', 'reader', 'close', 'reentry']) {
    test(
      'final release callback $target cannot revive or double-consume',
      () async {
        final p = await s.pending(h.operations.first);
        final command = h.command(h.operations.first);
        final backend = h.Backend(command.reference.encode());
        final store = h.store(backend);
        var armed = false;
        late CapturedConversationCompletion handle;
        late CapturedConversationReceiptLookup reader;
        late CapturedConversationApplication proof;
        late ConversationReceiptDispatch<int> first;
        first = gate(
          store,
          p.auth,
          command,
          ready: () {
            if (armed) {
              armed = false;
              switch (target) {
                case 'session':
                  p.flow.revoke();
                case 'reader':
                  reader.revoke();
                case 'close':
                  unawaited(first.close());
                case 'reentry':
                  expect(first.releaseAppliedCompletion(proof), isFalse);
              }
            }
            return true;
          },
        );
        await expectLater(first.submit(), throwsA(conflict));
        final c = await h.completion(p.auth, command);
        handle = c.handle;
        reader = c.reader;
        expect(
          await p.flow.applyRetainedCompletion(handle, store: store),
          isTrue,
        );
        proof = p.flow.captureAppliedCompletion(handle, store: store)!;
        armed = true;
        final calls = [...backend.calls];
        expect(first.releaseAppliedCompletion(proof), target == 'reentry');
        expect(backend.calls, calls);
        if (target != 'reentry') {
          await blocked(store, p.auth, command);
        }
      },
    );
  }
  for (final target in ['reader', 'consume-reentry']) {
    test(
      'last session currentness callback $target is fenced locally',
      () async {
        var armed = false;
        late CapturedConversationSession flow;
        late f.Auth auth;
        late CapturedConversationReceiptLookup reader;
        late CapturedConversationApplication proof;
        late ConversationReceiptStore store;
        final p = await s.pending(
          h.operations.first,
          ready: () {
            if (armed) {
              armed = false;
              if (target == 'reader') {
                reader.revoke();
              } else {
                expect(
                  proof.consumeForTransport(auth: auth, store: store),
                  isNull,
                );
              }
            }
            return true;
          },
        );
        flow = p.flow;
        auth = p.auth;
        final command = h.command(h.operations.first);
        final backend = h.Backend(command.reference.encode());
        store = h.store(backend);
        final first = gate(store, auth, command);
        await expectLater(first.submit(), throwsA(conflict));
        final c = await h.completion(auth, command);
        reader = c.reader;
        expect(
          await flow.applyRetainedCompletion(c.handle, store: store),
          isTrue,
        );
        proof = flow.captureAppliedCompletion(c.handle, store: store)!;
        armed = true;
        final calls = [...backend.calls];
        expect(
          first.releaseAppliedCompletion(proof),
          target == 'consume-reentry',
        );
        expect(backend.calls, calls);
        if (target == 'reader') {
          await blocked(store, auth, command);
        }
      },
    );
  }
  test('later session progress invalidates old application snapshot', () async {
    final p = await s.pending(h.operations.first);
    final command = h.command(h.operations.first);
    final backend = h.Backend(command.reference.encode());
    final store = h.store(backend);
    final first = gate(store, p.auth, command);
    await expectLater(first.submit(), throwsA(conflict));
    final c = await h.completion(p.auth, command);
    expect(
      await p.flow.applyRetainedCompletion(c.handle, store: store),
      isTrue,
    );
    final proof = p.flow.captureAppliedCompletion(c.handle, store: store)!;
    p.port.reply = (op) => f.response(op);
    await p.flow.turn(f.turn(event: f.otherEvent));
    expect(first.releaseAppliedCompletion(proof), isFalse);
    await blocked(store, p.auth, command);
  });
}
