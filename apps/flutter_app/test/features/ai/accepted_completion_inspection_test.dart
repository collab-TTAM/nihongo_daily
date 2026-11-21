// TEST ONLY ports/Auth/store. Read-only comparison, not application/release proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_receipt_lookup.dart';
import 'package:nihongo_daily/features/ai/data/conversation_mutation_lane.dart';
import 'package:nihongo_daily/features/ai/data/conversation_receipt_store.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_snapshot.dart';
import 'package:nihongo_daily/features/ai/domain/pending_conversation_command_envelope.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'captured_conversation_session_test.dart' as f;
import 'lane_completion_reconciliation_test.dart' as h;
import 'recovered_command_receipt_lookup_test.dart' as r;

Future<({ConversationMutationLane lane, f.Auth auth, f.Port port})> accepted(
  String op, {
  bool Function()? ready,
}) async {
  final auth = f.Auth();
  final port = f.Port();
  final lane = ConversationMutationLane(
    auth: auth,
    transport: port,
    isReady: ready ?? () => true,
  );
  await h.submit(lane, h.command(op));
  return (lane: lane, auth: auth, port: port);
}

Future<CapturedConversationCompletion> changedResult(
  ReviewAuth auth,
  PendingConversationCommandEnvelope c,
) async {
  final response = f.response(c.reference.operation.wireName);
  switch (c.reference.operation.wireName) {
    case 'start_conversation':
      response['session_id'] = f.otherEvent;
    case 'conversation_turn':
      (response['assistant_message']! as Map<String, Object?>)['text_ja'] =
          '別の応答';
    case 'finish_conversation':
      response['strengths_vi'] = ['Different TEST ONLY result'];
  }
  final port = r.OriginalPort()
    ..result = ConversationReceiptSnapshot.fromRows(c.reference, [
      {
        'user_id': f.owner,
        'operation': c.reference.operation.wireName,
        'client_event_id': c.reference.clientEventId,
        'status': 'COMPLETED',
        'response_json': response,
      },
    ]);
  final reader = CapturedConversationReceiptLookup(
    auth: auth,
    port: port,
    isReady: () => true,
  );
  return (await reader.lookupCompletion(c))!;
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
    test(
      '$op accepted result matches full completion without I/O or lane changes',
      () async {
        final p = await accepted(op);
        final command = h.command(op);
        final c = await h.completion(p.auth, command);
        final backend = h.Backend(command.reference.encode());
        final store = h.store(backend);
        final count = p.lane.retainedMutationCount;
        final result = p.lane.inspectAcceptedCompletion(c.handle, store: store);
        expect(result, same(c.handle.capture()!.receipt));
        expect(p.lane.hasUnresolvedMutation, isFalse);
        expect(p.lane.isBusy, isFalse);
        expect(p.lane.retainedMutationCount, count);
        expect(p.port.calls, hasLength(1));
        expect(backend.calls, isEmpty);
        expect(backend.value, command.reference.encode());
        await h.submit(p.lane, command);
        expect(p.port.calls, hasLength(1));
        expect(
          p.lane.inspectAcceptedCompletion(c.handle, store: store),
          same(result),
        );
      },
    );
    test(
      '$op metadata-equivalent changed original cannot match accepted result',
      () async {
        final p = await accepted(op);
        final c = await h.completion(p.auth, h.command(op, changed: true));
        final backend = h.Backend(h.command(op).reference.encode());
        final store = h.store(backend);
        expect(
          p.lane.inspectAcceptedCompletion(c.handle, store: store),
          isNull,
        );
        expect(backend.calls, isEmpty);
        expect(p.port.calls, hasLength(1));
        expect(p.lane.hasUnresolvedMutation, isFalse);
      },
    );
    test(
      '$op completed original with different response cannot match local success',
      () async {
        final p = await accepted(op);
        final c = await changedResult(p.auth, h.command(op));
        final backend = h.Backend(h.command(op).reference.encode());
        final store = h.store(backend);
        expect(p.lane.inspectAcceptedCompletion(c, store: store), isNull);
        expect(backend.calls, isEmpty);
        expect(p.port.calls, hasLength(1));
        expect(p.lane.isCurrent, isTrue);
      },
    );
  }
  test(
    'receipt-reconciled cache replay is not normal HTTP acceptance',
    () async {
      final p = await h.pending(h.operations.first);
      final command = h.command(h.operations.first);
      final c = await h.completion(p.auth, command);
      final backend = h.Backend(command.reference.encode());
      final store = h.store(backend);
      expect(await p.lane.reconcileCompleted(c.handle, store: store), isTrue);
      final calls = List<String>.from(backend.calls);
      expect(p.lane.inspectAcceptedCompletion(c.handle, store: store), isNull);
      await h.submit(p.lane, command);
      expect(p.lane.inspectAcceptedCompletion(c.handle, store: store), isNull);
      expect(p.port.calls, hasLength(1));
      expect(backend.calls, calls);
      expect(p.lane.hasUnresolvedMutation, isFalse);
    },
  );
  test(
    'foreign Auth sharing exact session hint cannot inspect cached result',
    () async {
      final p = await accepted(h.operations.first);
      final foreign = f.Auth()..currentSession = p.auth.currentSession;
      final c = await h.completion(foreign, h.command(h.operations.first));
      final b = h.Backend(null);
      final store = h.store(b);
      expect(p.lane.inspectAcceptedCompletion(c.handle, store: store), isNull);
      expect(b.calls, isEmpty);
      expect(p.lane.retainedMutationCount, 1);
    },
  );
  test('foreign project store is rejected without touching it', () async {
    final p = await accepted(h.operations.first);
    final command = h.command(h.operations.first);
    final c = await h.completion(p.auth, command);
    final b = h.Backend(null);
    final foreign = ConversationReceiptStore(
      scope: PendingConversationCommandEnvelope.fromStart(
        projectUrl: 'https://foreign.test',
        ownerId: f.owner,
        request: f.start(),
      ).reference.scope,
      backend: b,
    );
    addTearDown(foreign.close);
    expect(p.lane.inspectAcceptedCompletion(c.handle, store: foreign), isNull);
    expect(b.calls, isEmpty);
    expect(p.port.calls, hasLength(1));
  });
  for (final transition in [
    'refresh',
    'account',
    'revoke',
    'reader',
    'store',
  ]) {
    test(
      'accepted inspection rejects $transition and cannot revive retired lane',
      () async {
        final p = await accepted(h.operations.first);
        final old = p.auth.currentSession;
        final c = await h.completion(p.auth, h.command(h.operations.first));
        final b = h.Backend(null);
        final store = h.store(b);
        switch (transition) {
          case 'refresh':
            p.auth.currentSession = ReviewSession(userId: f.owner);
          case 'account':
            p.auth.currentSession = ReviewSession(userId: f.otherEvent);
          case 'revoke':
            p.lane.revoke();
          case 'reader':
            c.reader.revoke();
          case 'store':
            await store.close();
        }
        expect(
          p.lane.inspectAcceptedCompletion(c.handle, store: store),
          isNull,
        );
        p.auth.currentSession = old;
        expect(
          p.lane.inspectAcceptedCompletion(c.handle, store: store),
          isNull,
        );
        expect(b.calls, isEmpty);
        expect(p.port.calls, hasLength(1));
      },
    );
  }
  test(
    'missing slot and unresolved other command never expose accepted receipt',
    () async {
      final auth = f.Auth();
      final port = f.Port();
      final lane = ConversationMutationLane(
        auth: auth,
        transport: port,
        isReady: () => true,
      );
      final c = await h.completion(auth, h.command(h.operations.first));
      final b = h.Backend(null);
      final store = h.store(b);
      expect(lane.inspectAcceptedCompletion(c.handle, store: store), isNull);
      await h.submit(lane, h.command(h.operations.first));
      port.reply = (_) =>
          throw const AiTextFailure(AiTextErrorCode.providerUnavailable);
      await expectLater(
        lane.turn(f.turn()),
        throwsA(f.code(AiTextErrorCode.providerUnavailable)),
      );
      expect(lane.inspectAcceptedCompletion(c.handle, store: store), isNull);
      expect(lane.hasUnresolvedMutation, isTrue);
      expect(port.calls, hasLength(2));
      expect(b.calls, isEmpty);
    },
  );
  for (final lateError in [false, true]) {
    test(
      'timeout and actual late drain cannot become accepted success error=$lateError',
      () async {
        final auth = f.Auth();
        final wire = Completer<Object?>();
        final port = f.Port()..reply = (_) => wire.future;
        final lane = ConversationMutationLane(
          auth: auth,
          transport: port,
          isReady: () => true,
          timeout: const Duration(milliseconds: 1),
        );
        final c = await h.completion(auth, h.command(h.operations.first));
        final b = h.Backend(null);
        final store = h.store(b);
        final sending = lane.start(f.start());
        expect(lane.inspectAcceptedCompletion(c.handle, store: store), isNull);
        await expectLater(
          sending,
          throwsA(f.code(AiTextErrorCode.networkUnavailable)),
        );
        expect(lane.inspectAcceptedCompletion(c.handle, store: store), isNull);
        if (lateError) {
          wire.completeError(StateError('PRIVATE_LATE'));
        } else {
          wire.complete(f.response(h.operations.first));
        }
        await f.settle();
        expect(lane.inspectAcceptedCompletion(c.handle, store: store), isNull);
        expect(lane.hasUnresolvedMutation, isTrue);
        expect(port.calls, hasLength(1));
        expect(b.calls, isEmpty);
      },
    );
  }
  for (final target in ['reentry', 'reader', 'store', 'refresh']) {
    test(
      'final readiness $target cannot bypass inspection reservation/terminal flags',
      () async {
        var armed = false;
        var checks = 0;
        late ConversationMutationLane lane;
        late CapturedConversationCompletion handle;
        late CapturedConversationReceiptLookup reader;
        late ConversationReceiptStore store;
        late f.Auth auth;
        Future<void>? nested;
        Future<void>? closing;
        final p = await accepted(
          h.operations.first,
          ready: () {
            if (armed && ++checks == 3) {
              armed = false;
              switch (target) {
                case 'reentry':
                  expect(
                    lane.inspectAcceptedCompletion(handle, store: store),
                    isNull,
                  );
                  nested = expectLater(
                    lane.turn(f.turn()),
                    throwsA(isA<AiTextRequestPending>()),
                  );
                case 'reader':
                  reader.revoke();
                case 'store':
                  closing = store.close();
                case 'refresh':
                  auth.currentSession = ReviewSession(userId: f.owner);
              }
            }
            return true;
          },
        );
        lane = p.lane;
        auth = p.auth;
        final c = await h.completion(auth, h.command(h.operations.first));
        handle = c.handle;
        reader = c.reader;
        final b = h.Backend(null);
        store = h.store(b);
        armed = true;
        final result = lane.inspectAcceptedCompletion(handle, store: store);
        expect(armed, isFalse);
        expect(result, target == 'reentry' ? isNotNull : isNull);
        await nested;
        await closing;
        expect(p.port.calls, hasLength(1));
        expect(b.calls, isEmpty);
      },
    );
  }
}
