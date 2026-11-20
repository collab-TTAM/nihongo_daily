// TEST ONLY independent captured flow/Auth/storage/inner HTTP ports.
// Not owned SDK or hosted learner proof; owner action is intentionally unwired.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/application/ai_text_runtime_owner.dart';
import 'package:nihongo_daily/features/ai/application/receipt_ai_runtime_owner.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_mutation.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_scenarios.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_session.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_receipt_lookup.dart';
import 'package:nihongo_daily/features/ai/data/conversation_receipt_store.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_reference.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_snapshot.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/ai/data/receipt_guarded_ai_transport.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/ai/domain/pending_conversation_command_envelope.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'captured_conversation_session_test.dart' as f;
import 'lane_completion_reconciliation_test.dart' as h;
import 'session_completion_application_test.dart' as s;

final class Inner
    implements
        OwnedAiTextTransport,
        ConversationMutationTransport,
        ConversationScenarioReadPort,
        ConversationReceiptReadPort,
        ConversationOriginalReceiptReadPort {
  bool revoked = false;
  int sends = 0;
  int closes = 0;
  Completer<Object?>? wire;
  ConversationReceiptSnapshot? receipt;
  bool failNext = false;
  final entered = Completer<void>();
  Map<String, Object>? sent;
  @override
  bool get isCurrent => !revoked;
  @override
  void revoke() => revoked = true;
  @override
  Future<void> close() async {
    closes++;
  }

  @override
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String operation,
    required Map<String, Object> body,
  }) async {
    sends++;
    sent = body;
    if (!entered.isCompleted) {
      entered.complete();
    }
    if (failNext) {
      failNext = false;
      throw StateError('TEST_ONLY_HTTP_FAILURE');
    }
    return wire == null ? f.response(operation) : await wire!.future;
  }

  @override
  Future<Object?> read({
    required ReviewSession capturedSession,
    required AiTextLevel level,
  }) async => <Object?>[];
  Future<ConversationReceiptSnapshot> _readReceipt() async {
    final value = receipt;
    if (value == null) {
      throw const AiTextFailure(AiTextErrorCode.internalError);
    }
    return value;
  }

  @override
  Future<ConversationReceiptSnapshot> lookupReceipt(
    ConversationReceiptReference reference,
  ) => _readReceipt();

  @override
  Future<ConversationReceiptSnapshot> lookupStartReceipt(
    ConversationReceiptReference reference,
    StartConversationRequest original,
  ) => _readReceipt();

  @override
  Future<ConversationReceiptSnapshot> lookupTurnReceipt(
    ConversationReceiptReference reference,
    ConversationTurnRequest original,
  ) => _readReceipt();

  @override
  Future<ConversationReceiptSnapshot> lookupFinishReceipt(
    ConversationReceiptReference reference,
    FinishConversationRequest original,
  ) => _readReceipt();

  @override
  Future<Object?> tutorExplain({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) async => null;
  @override
  Future<Object?> correctSentence({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) async => null;
}

Future<Object?> invoke(
  ReceiptGuardedAiTransport t,
  f.Auth auth,
  PendingConversationCommandEnvelope c,
) => t.invoke(
  capturedSession: auth.currentSession!,
  operation: c.reference.operation.wireName,
  body: c.start?.toJson() ?? c.turn?.toJson() ?? c.finish!.toJson(),
);
void main() {
  setUpAll(() {
    f.fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  test(
    'same captured session applies then explicitly releases one next turn',
    () async {
      final auth = f.Auth();
      final c = h.command(h.operations.first);
      final backend = h.Backend(c.reference.encode());
      final store = h.store(backend);
      final inner = Inner();
      final t = ReceiptGuardedAiTransport(
        inner: inner,
        store: store,
        auth: auth,
        capturedSession: auth.currentSession!,
        isReady: () => true,
      );
      addTearDown(t.close);
      final flow = CapturedConversationSession(
        auth: auth,
        transport: t,
        isReady: () => true,
      );
      await expectLater(
        flow.start(c.start!),
        throwsA(f.code(AiTextErrorCode.syncConflict)),
      );
      final completed = await h.completion(auth, c);
      expect(
        await flow.applyRetainedCompletion(completed.handle, store: store),
        isTrue,
      );
      final before = flow.snapshot;
      final proof = flow.captureAppliedCompletion(
        completed.handle,
        store: store,
      )!;
      expect(inner.sends, 0);
      expect(t.releaseAppliedCompletion(proof), isTrue);
      await flow.turn(f.turn(event: f.otherEvent));
      expect(inner.sends, 1);
      expect(flow.snapshot.messages.length, before.messages.length + 1);
      expect(backend.value, isNotNull);
      // Successful raw HTTP cannot acknowledge/clear the next pending command.
      expect(t.releaseAppliedCompletion(proof), isFalse);
      await expectLater(
        flow.finish(f.finish()),
        throwsA(f.code(AiTextErrorCode.syncConflict)),
      );
      expect(inner.sends, 1);
      await t.close();
      expect(backend.value, isNotNull);
      expect(inner.closes, 1);
    },
  );
  test(
    'owner applies and consumes exact completion proof before next mutation',
    () async {
      final auth = f.Auth();
      final pendingCommand = h.command(h.operations.first);
      final backend = h.Backend(null);
      final store = ConversationReceiptStore(
        scope: pendingCommand.reference.scope,
        backend: backend,
      );
      final inner = Inner()..failNext = true;
      final owner = ReceiptAiRuntimeOwner(
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
      addTearDown(owner.close);
      final generation = AiTextGeneration();
      bool ready() => true;
      expect(
        owner.runtime.acquire(
          auth: auth,
          generation: generation,
          isReady: ready,
        ),
        isNotNull,
      );
      final flow = owner.runtime.acquireConversation(
        auth: auth,
        generation: generation,
        isReady: ready,
      )!;
      final reader = owner.runtime.acquireReceiptLookup(
        auth: auth,
        generation: generation,
        isReady: ready,
      )!;
      await expectLater(
        flow.start(pendingCommand.start!),
        throwsA(f.code(AiTextErrorCode.internalError)),
      );
      expect(backend.value, pendingCommand.reference.encode());
      inner.receipt = ConversationReceiptSnapshot.fromRows(
        pendingCommand.reference,
        [
          {
            'user_id': f.owner,
            'operation': pendingCommand.reference.operation.wireName,
            'client_event_id': pendingCommand.reference.clientEventId,
            'status': 'COMPLETED',
            'response_json': f.response(
              pendingCommand.reference.operation.wireName,
            ),
          },
        ],
      );
      final completion = await reader.lookupCompletion(pendingCommand);
      expect(completion, isNotNull);
      final foreign = await h.completion(auth, pendingCommand);
      expect(
        await owner.applyRetainedConversationCompletion(foreign.handle),
        isFalse,
      );
      expect(backend.value, pendingCommand.reference.encode());
      expect(
        await owner.releaseAppliedConversationCompletion(completion!),
        isFalse,
      );
      expect(backend.value, pendingCommand.reference.encode());
      expect(
        await owner.applyRetainedConversationCompletion(completion),
        isTrue,
      );
      expect(backend.value, isNull);
      expect(
        flow.captureAppliedCompletion(completion, store: store),
        isNotNull,
      );
      expect(
        await owner.releaseAppliedConversationCompletion(foreign.handle),
        isFalse,
      );
      expect(
        await owner.releaseAppliedConversationCompletion(completion),
        isTrue,
      );
      expect(flow.captureAppliedCompletion(completion, store: store), isNull);
      final next = f.turn(event: f.otherEvent);
      await flow.turn(next);
      expect(inner.sends, 2);
      expect(inner.sent, next.toJson());
      expect(backend.value, isNotNull);
    },
  );

  test(
    'owner acknowledges normal-success completion on the same retained lease',
    () async {
      final auth = f.Auth();
      final command = h.command(h.operations.first);
      final backend = h.Backend(null);
      final store = ConversationReceiptStore(
        scope: command.reference.scope,
        backend: backend,
      );
      final inner = Inner();
      final owner = ReceiptAiRuntimeOwner(
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
      addTearDown(owner.close);
      final generation = AiTextGeneration();
      bool ready() => true;
      expect(
        owner.runtime.acquire(
          auth: auth,
          generation: generation,
          isReady: ready,
        ),
        isNotNull,
      );
      final flow = owner.runtime.acquireConversation(
        auth: auth,
        generation: generation,
        isReady: ready,
      )!;
      final reader = owner.runtime.acquireReceiptLookup(
        auth: auth,
        generation: generation,
        isReady: ready,
      )!;
      await flow.start(command.start!);
      final published = flow.snapshot;
      inner.receipt = ConversationReceiptSnapshot.fromRows(
        command.reference,
        [
          {
            'user_id': f.owner,
            'operation': command.reference.operation.wireName,
            'client_event_id': command.reference.clientEventId,
            'status': 'COMPLETED',
            'response_json': f.response('start_conversation'),
          },
        ],
      );
      final completion = await reader.lookupCompletion(command);
      expect(completion, isNotNull);
      expect(
        flow.inspectPublishedCompletion(completion!, store: store),
        same(published),
      );
      expect(
        await owner.acknowledgePublishedConversationCompletion(completion),
        isTrue,
      );
      expect(backend.calls, ['read', 'read', 'write', 'read', 'clear', 'read']);
      expect(backend.value, isNull);
      expect(flow.snapshot, same(published));
      expect(flow.captureAppliedCompletion(completion, store: store), isNull);
      await flow.start(command.start!); // Exact replay stays local and unchanged.
      expect(flow.snapshot, same(published));
      expect(inner.sends, 1);
      final next = f.turn(event: f.otherEvent);
      await flow.turn(next);
      expect(inner.sends, 2);
      expect(inner.sent, next.toJson());
      expect(backend.value, isNotNull);
    },
  );

  for (final op in h.operations) {
    for (final changed in [false, true]) {
      test(
        '$op exact transport releases only matching original changed=$changed',
        () async {
          final p = await s.pending(op);
          final c = h.command(op);
          final backend = h.Backend(c.reference.encode());
          final store = h.store(backend);
          final inner = Inner();
          final t = ReceiptGuardedAiTransport(
            inner: inner,
            store: store,
            auth: p.auth,
            capturedSession: p.auth.currentSession!,
            isReady: () => true,
          );
          addTearDown(t.close);
          await expectLater(
            invoke(t, p.auth, h.command(op, changed: changed)),
            throwsA(f.code(AiTextErrorCode.syncConflict)),
          );
          final completed = await h.completion(p.auth, c);
          expect(
            await p.flow.applyRetainedCompletion(
              completed.handle,
              store: store,
            ),
            isTrue,
          );
          final proof = p.flow.captureAppliedCompletion(
            completed.handle,
            store: store,
          )!;
          final calls = [...backend.calls];
          expect(t.releaseAppliedCompletion(proof), !changed);
          expect(backend.calls, calls);
          expect(inner.sends, 0);
          if (changed) {
            await expectLater(
              invoke(t, p.auth, c),
              throwsA(f.code(AiTextErrorCode.syncConflict)),
            );
          } else {
            final next = h.command('conversation_turn');
            final result = await invoke(t, p.auth, next);
            expect(result, isNotNull);
            expect(inner.sends, 1);
            expect(inner.sent, next.turn!.toJson());
            expect(backend.value, next.reference.encode());
            expect(t.releaseAppliedCompletion(proof), isFalse);
            await expectLater(
              invoke(t, p.auth, next),
              throwsA(f.code(AiTextErrorCode.syncConflict)),
            );
            expect(inner.sends, 1);
          }
          await t.close();
          expect(inner.closes, 1);
        },
      );
    }
  }
  for (final transition in [
    'refresh',
    'account',
    'revoke',
    'close',
    'reader',
    'store',
  ]) {
    test('transport release cannot reopen after $transition', () async {
      final p = await s.pending(h.operations.first);
      final c = h.command(h.operations.first);
      final backend = h.Backend(c.reference.encode());
      final store = h.store(backend);
      final inner = Inner();
      final t = ReceiptGuardedAiTransport(
        inner: inner,
        store: store,
        auth: p.auth,
        capturedSession: p.auth.currentSession!,
        isReady: () => true,
      );
      addTearDown(t.close);
      await expectLater(
        invoke(t, p.auth, c),
        throwsA(f.code(AiTextErrorCode.syncConflict)),
      );
      final completed = await h.completion(p.auth, c);
      expect(
        await p.flow.applyRetainedCompletion(completed.handle, store: store),
        isTrue,
      );
      final proof = p.flow.captureAppliedCompletion(
        completed.handle,
        store: store,
      )!;
      switch (transition) {
        case 'refresh':
          p.auth.currentSession = ReviewSession(userId: f.owner);
        case 'account':
          p.auth.currentSession = ReviewSession(userId: f.otherEvent);
        case 'revoke':
          t.revoke();
        case 'close':
          await t.close();
        case 'reader':
          completed.reader.revoke();
        case 'store':
          await store.close();
      }
      expect(t.releaseAppliedCompletion(proof), isFalse);
      await expectLater(invoke(t, p.auth, c), throwsA(isA<AiTextFailure>()));
      expect(inner.sends, 0);
    });
  }
  for (final lateError in [false, true]) {
    test(
      'held actual transport cannot release early lateError=$lateError',
      () async {
        final p = await s.pending(h.operations.first);
        final c = h.command(h.operations.first);
        final backend = h.Backend(null);
        final store = h.store(backend);
        final inner = Inner()..wire = Completer<Object?>();
        final t = ReceiptGuardedAiTransport(
          inner: inner,
          store: store,
          auth: p.auth,
          capturedSession: p.auth.currentSession!,
          isReady: () => true,
        );
        addTearDown(t.close);
        final sending = invoke(t, p.auth, c);
        final observed = lateError
            ? expectLater(sending, throwsA(isA<AiTextFailure>()))
            : expectLater(sending, completion(isNotNull));
        await inner.entered.future;
        final completed = await h.completion(p.auth, c);
        expect(
          await p.flow.applyRetainedCompletion(completed.handle, store: store),
          isTrue,
        );
        final proof = p.flow.captureAppliedCompletion(
          completed.handle,
          store: store,
        )!;
        expect(t.releaseAppliedCompletion(proof), isFalse);
        await expectLater(
          invoke(t, p.auth, c),
          throwsA(f.code(AiTextErrorCode.syncConflict)),
        );
        if (lateError) {
          inner.wire!.completeError(StateError('PRIVATE_HTTP'));
        } else {
          inner.wire!.complete(f.response(h.operations.first));
        }
        await observed;
        await f.settle();
        expect(t.releaseAppliedCompletion(proof), isTrue);
        expect(inner.sends, 1);
      },
    );
  }
  for (final target in ['close', 'reentry', 'final-refresh']) {
    test('release callbacks $target preserve fencing', () async {
      final p = await s.pending(h.operations.first);
      final c = h.command(h.operations.first);
      final backend = h.Backend(c.reference.encode());
      final store = h.store(backend);
      final inner = Inner();
      var armed = false;
      var checks = 0;
      late ReceiptGuardedAiTransport t;
      late CapturedConversationApplication proof;
      Future<Object?>? nested;
      t = ReceiptGuardedAiTransport(
        inner: inner,
        store: store,
        auth: p.auth,
        capturedSession: p.auth.currentSession!,
        isReady: () {
          if (armed) {
            checks++;
            if (target == 'close') {
              armed = false;
              unawaited(t.close());
            }
            if (target == 'reentry') {
              armed = false;
              expect(t.releaseAppliedCompletion(proof), isFalse);
              nested = invoke(t, p.auth, c);
            }
            // Initial transport check reads twice; gate checks call it twice more;
            // replacement occurs during the transport check AFTER gate release.
            if (target == 'final-refresh' && checks == 7) {
              armed = false;
              p.auth.currentSession = ReviewSession(userId: f.owner);
            }
          }
          return true;
        },
      );
      addTearDown(t.close);
      await expectLater(
        invoke(t, p.auth, c),
        throwsA(f.code(AiTextErrorCode.syncConflict)),
      );
      final completed = await h.completion(p.auth, c);
      expect(
        await p.flow.applyRetainedCompletion(completed.handle, store: store),
        isTrue,
      );
      proof = p.flow.captureAppliedCompletion(completed.handle, store: store)!;
      armed = true;
      expect(t.releaseAppliedCompletion(proof), target == 'reentry');
      if (nested != null) {
        await expectLater(
          nested,
          throwsA(f.code(AiTextErrorCode.syncConflict)),
        );
      }
      expect(inner.sends, 0);
      if (target != 'reentry') {
        await expectLater(invoke(t, p.auth, c), throwsA(isA<AiTextFailure>()));
      }
    });
  }
}
