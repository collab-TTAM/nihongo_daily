// TEST ONLY Auth/ports/storage. Not hosted Auth, native durability or UI recovery.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_receipt_lookup.dart';
import 'package:nihongo_daily/features/ai/data/conversation_mutation_lane.dart';
import 'package:nihongo_daily/features/ai/data/conversation_receipt_store.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_snapshot.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/ai/domain/pending_conversation_command_envelope.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'captured_conversation_session_test.dart' as f;
import 'recovered_command_receipt_lookup_test.dart' as r;

const origin = 'https://lane-reconciliation.test';
const operations = [
  'start_conversation',
  'conversation_turn',
  'finish_conversation',
];
PendingConversationCommandEnvelope command(String op, {bool changed = false}) =>
    switch (op) {
      'start_conversation' => PendingConversationCommandEnvelope.fromStart(
        projectUrl: origin,
        ownerId: f.owner,
        request: changed
            ? StartConversationRequest(
                scenarioId: f.otherEvent,
                level: f.start().level,
                clientEventId: f.startEvent,
              )
            : f.start(),
      ),
      'conversation_turn' => PendingConversationCommandEnvelope.fromTurn(
        projectUrl: origin,
        ownerId: f.owner,
        request: changed ? f.turn(text: 'changed trailing space ') : f.turn(),
      ),
      _ => PendingConversationCommandEnvelope.fromFinish(
        projectUrl: origin,
        ownerId: f.owner,
        request: changed ? f.finish(sessionId: f.otherEvent) : f.finish(),
      ),
    };
Future<Object> submit(
  ConversationMutationLane lane,
  PendingConversationCommandEnvelope c,
) => c.start != null
    ? lane.start(c.start!)
    : c.turn != null
    ? lane.turn(c.turn!)
    : lane.finish(c.finish!);

final class Backend implements SecureConversationReceiptBackend {
  Backend(this.value);
  String? value;
  final calls = <String>[];
  final clearEntered = Completer<void>();
  Completer<void>? holdClear;
  bool failClear = false;
  bool keepClear = false;
  bool failConfirm = false;
  void Function()? afterClear;
  @override
  Future<Object?> read(String target) async {
    calls.add('read');
    if (failConfirm && clearEntered.isCompleted) {
      throw StateError('PRIVATE_READ');
    }
    return value;
  }

  @override
  Future<void> write(String target, String encoded) async {
    calls.add('write');
    value = encoded;
  }

  @override
  Future<void> clear(String target) async {
    calls.add('clear');
    if (!clearEntered.isCompleted) {
      clearEntered.complete();
    }
    await holdClear?.future;
    if (failClear) {
      throw StateError('PRIVATE_CLEAR');
    }
    if (!keepClear) {
      value = null;
    }
    afterClear?.call();
  }
}

ConversationReceiptStore store(Backend backend) {
  final result = ConversationReceiptStore(
    scope: command(operations.first).reference.scope,
    backend: backend,
  );
  addTearDown(() async {
    if (backend.holdClear != null && !backend.holdClear!.isCompleted) {
      backend.holdClear!.complete();
    }
    await result.close();
  });
  return result;
}

Future<({ConversationMutationLane lane, f.Auth auth, f.Port port})> pending(
  String op, {
  bool Function()? ready,
}) async {
  final auth = f.Auth();
  final port = f.Port()
    ..reply = (_) =>
        throw const AiTextFailure(AiTextErrorCode.providerUnavailable);
  final lane = ConversationMutationLane(
    auth: auth,
    transport: port,
    isReady: ready ?? () => true,
  );
  await expectLater(
    submit(lane, command(op)),
    throwsA(f.code(AiTextErrorCode.providerUnavailable)),
  );
  return (lane: lane, auth: auth, port: port);
}

Future<
  ({
    CapturedConversationCompletion handle,
    r.OriginalPort port,
    CapturedConversationReceiptLookup reader,
  })
>
completion(ReviewAuth auth, PendingConversationCommandEnvelope c) async {
  final port = r.OriginalPort()
    ..result = ConversationReceiptSnapshot.fromRows(c.reference, [
      {
        'user_id': f.owner,
        'operation': c.reference.operation.wireName,
        'client_event_id': c.reference.clientEventId,
        'status': 'COMPLETED',
        'response_json': f.response(c.reference.operation.wireName),
      },
    ]);
  final reader = CapturedConversationReceiptLookup(
    auth: auth,
    port: port,
    isReady: () => true,
  );
  return (
    handle: (await reader.lookupCompletion(c))!,
    port: port,
    reader: reader,
  );
}

void main() {
  setUpAll(() {
    f.fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  for (final op in operations) {
    test(
      '$op confirmed clear caches exact result without redispatch and allows next event',
      () async {
        final p = await pending(op);
        final c = await completion(p.auth, command(op));
        final backend = Backend(command(op).reference.encode());
        final storage = store(backend);
        final result = c.handle.capture()!.receipt;
        final expected = result.start ?? result.turn ?? result.finish;
        expect(
          await p.lane.reconcileCompleted(c.handle, store: storage),
          isTrue,
        );
        expect(backend.calls, ['read', 'clear', 'read']);
        expect(backend.value, isNull);
        expect(p.lane.hasUnresolvedMutation, isFalse);
        expect(p.lane.retainedMutationCount, 1);
        expect(await submit(p.lane, command(op)), same(expected));
        expect(p.port.calls, hasLength(1));
        expect(c.port.calls, 1);
        expect(
          await p.lane.reconcileCompleted(c.handle, store: storage),
          isFalse,
        );
        expect(backend.calls, ['read', 'clear', 'read']);
        p.port.reply = null;
        await p.lane.start(f.start(f.otherEvent));
        expect(p.port.calls, hasLength(2));
      },
    );
    test('$op same metadata cannot substitute changed full original', () async {
      final p = await pending(op);
      final changed = command(op, changed: true);
      expect(changed.reference.encode(), command(op).reference.encode());
      final c = await completion(p.auth, changed);
      final backend = Backend(command(op).reference.encode());
      expect(
        await p.lane.reconcileCompleted(c.handle, store: store(backend)),
        isFalse,
      );
      expect(backend.calls, isEmpty);
      expect(p.lane.hasUnresolvedMutation, isTrue);
      expect(p.lane.isCurrent, isTrue);
      expect(p.port.calls, hasLength(1));
    });
  }
  test(
    'different Auth object with identical session hint cannot clear',
    () async {
      final p = await pending(operations.first);
      final foreign = f.Auth()..currentSession = p.auth.currentSession;
      final c = await completion(foreign, command(operations.first));
      final backend = Backend(command(operations.first).reference.encode());
      expect(
        await p.lane.reconcileCompleted(c.handle, store: store(backend)),
        isFalse,
      );
      expect(backend.calls, isEmpty);
      expect(p.lane.hasUnresolvedMutation, isTrue);
      expect(p.port.calls, hasLength(1));
    },
  );
  test('foreign project store never receives a clear or read', () async {
    final p = await pending(operations.first);
    final c = await completion(p.auth, command(operations.first));
    final backend = Backend(command(operations.first).reference.encode());
    final foreign = ConversationReceiptStore(
      scope: PendingConversationCommandEnvelope.fromStart(
        projectUrl: 'https://foreign.test',
        ownerId: f.owner,
        request: f.start(),
      ).reference.scope,
      backend: backend,
    );
    addTearDown(foreign.close);
    expect(await p.lane.reconcileCompleted(c.handle, store: foreign), isFalse);
    expect(backend.calls, isEmpty);
    expect(p.lane.hasUnresolvedMutation, isTrue);
    expect(p.lane.isCurrent, isTrue);
  });
  for (final absent in [false, true]) {
    test(
      'missing/mismatched metadata never authorizes release absent=$absent',
      () async {
        final p = await pending(operations.first);
        final c = await completion(p.auth, command(operations.first));
        final value = absent
            ? null
            : command(operations.last).reference.encode();
        final backend = Backend(value);
        expect(
          await p.lane.reconcileCompleted(c.handle, store: store(backend)),
          isFalse,
        );
        expect(backend.calls, ['read']);
        expect(backend.value, value);
        expect(p.lane.isCurrent, isFalse);
        await expectLater(
          p.lane.start(f.start(f.otherEvent)),
          throwsA(f.code(AiTextErrorCode.unauthorized)),
        );
        expect(p.port.calls, hasLength(1));
      },
    );
  }
  for (final fault in ['clear', 'silent', 'confirm-read']) {
    test(
      'unconfirmed $fault failure retires lane without a cached success',
      () async {
        final p = await pending(operations.first);
        final c = await completion(p.auth, command(operations.first));
        final backend = Backend(command(operations.first).reference.encode())
          ..failClear = fault == 'clear'
          ..keepClear = fault == 'silent'
          ..failConfirm = fault == 'confirm-read';
        await expectLater(
          p.lane.reconcileCompleted(c.handle, store: store(backend)),
          throwsA(
            isA<ConversationReceiptStoreFailure>()
                .having(
                  (e) => e.code,
                  'fixed',
                  ConversationReceiptStoreError.unavailable,
                )
                .having(
                  (e) => e.toString().contains('PRIVATE'),
                  'redacted',
                  false,
                ),
          ),
        );
        expect(p.lane.isCurrent, isFalse);
        expect(p.lane.retainedMutationCount, 0);
        expect(p.port.calls, hasLength(1));
      },
    );
  }
  test(
    'held clear reserves lane before callbacks and blocks all concurrent submissions',
    () async {
      final p = await pending(operations.first);
      final c = await completion(p.auth, command(operations.first));
      final backend = Backend(command(operations.first).reference.encode())
        ..holdClear = Completer<void>();
      final storage = store(backend);
      final settling = p.lane.reconcileCompleted(c.handle, store: storage);
      await backend.clearEntered.future;
      expect(p.lane.isBusy, isTrue);
      expect(p.lane.hasUnresolvedMutation, isTrue);
      await expectLater(
        p.lane.finish(f.finish()),
        throwsA(isA<AiTextRequestPending>()),
      );
      await expectLater(
        p.lane.reconcileCompleted(c.handle, store: storage),
        throwsA(isA<AiTextRequestPending>()),
      );
      expect(backend.value, command(operations.first).reference.encode());
      backend.holdClear!.complete();
      expect(await settling, isTrue);
      expect(p.port.calls, hasLength(1));
    },
  );
  for (final transition in ['refresh', 'account', 'revoke', 'reader']) {
    test('late clear after $transition never releases a live lane', () async {
      final p = await pending(operations.first);
      final originalSession = p.auth.currentSession;
      final c = await completion(p.auth, command(operations.first));
      final backend = Backend(command(operations.first).reference.encode())
        ..holdClear = Completer<void>();
      final settling = p.lane.reconcileCompleted(
        c.handle,
        store: store(backend),
      );
      await backend.clearEntered.future;
      if (transition == 'revoke') {
        p.lane.revoke();
      } else if (transition == 'reader') {
        c.reader.revoke();
      } else {
        p.auth.currentSession = ReviewSession(
          userId: transition == 'refresh' ? f.owner : f.otherEvent,
        );
      }
      backend.holdClear!.complete();
      expect(await settling, isFalse);
      expect(p.lane.isCurrent, isFalse);
      p.auth.currentSession = originalSession;
      await expectLater(
        submit(p.lane, command(operations.first)),
        throwsA(f.code(AiTextErrorCode.unauthorized)),
      );
      expect(p.port.calls, hasLength(1));
      expect(backend.value, isNull);
    });
  }
  test('actual timed out wire must drain before any storage clear', () async {
    final auth = f.Auth();
    final wire = Completer<Object?>();
    final port = f.Port()..reply = (_) => wire.future;
    final lane = ConversationMutationLane(
      auth: auth,
      transport: port,
      isReady: () => true,
      timeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      lane.start(f.start()),
      throwsA(f.code(AiTextErrorCode.networkUnavailable)),
    );
    final c = await completion(auth, command(operations.first));
    final backend = Backend(command(operations.first).reference.encode());
    final storage = store(backend);
    expect(await lane.reconcileCompleted(c.handle, store: storage), isFalse);
    expect(backend.calls, isEmpty);
    wire.complete(f.response(operations.first));
    await f.settle();
    expect(await lane.reconcileCompleted(c.handle, store: storage), isTrue);
    expect(port.calls, hasLength(1));
  });
  test(
    'signout during actual clear retires lane and waits for storage drain',
    () async {
      final p = await pending(operations.first);
      final c = await completion(p.auth, command(operations.first));
      final backend = Backend(command(operations.first).reference.encode())
        ..holdClear = Completer<void>();
      final storage = store(backend);
      final settling = expectLater(
        p.lane.reconcileCompleted(c.handle, store: storage),
        throwsA(
          isA<ConversationReceiptStoreFailure>().having(
            (e) => e.code,
            'revoked',
            ConversationReceiptStoreError.revoked,
          ),
        ),
      );
      await backend.clearEntered.future;
      final logout = storage.clearForSignOut();
      backend.holdClear!.complete();
      await Future.wait<void>([settling, logout]);
      expect(p.lane.isCurrent, isFalse);
      expect(backend.value, isNull);
      expect(p.port.calls, hasLength(1));
    },
  );
  test(
    'final readiness cannot dispatch a nested command during reconciliation',
    () async {
      var armed = false;
      late ConversationMutationLane lane;
      Future<void>? nested;
      final p = await pending(
        operations.first,
        ready: () {
          if (armed) {
            armed = false;
            nested = expectLater(
              lane.finish(f.finish()),
              throwsA(isA<AiTextRequestPending>()),
            );
          }
          return true;
        },
      );
      lane = p.lane;
      final c = await completion(p.auth, command(operations.first));
      final backend = Backend(command(operations.first).reference.encode())
        ..afterClear = () => armed = true;
      expect(
        await lane.reconcileCompleted(c.handle, store: store(backend)),
        isTrue,
      );
      await nested;
      expect(p.port.calls, hasLength(1));
    },
  );
}
