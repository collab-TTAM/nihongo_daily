// TEST ONLY ports/Auth. No storage clear, hosted receipt or result application.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_receipt_lookup.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_session.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_snapshot.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/ai/domain/pending_conversation_command_envelope.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'captured_conversation_session_test.dart' as f;
import 'recovered_command_receipt_lookup_test.dart' as r;

const origin = 'https://retained-completion.test';
PendingConversationCommandEnvelope command(String op) => switch (op) {
  'start_conversation' => PendingConversationCommandEnvelope.fromStart(
    projectUrl: origin,
    ownerId: f.owner,
    request: f.start(),
  ),
  'conversation_turn' => PendingConversationCommandEnvelope.fromTurn(
    projectUrl: origin,
    ownerId: f.owner,
    request: f.turn(),
  ),
  _ => PendingConversationCommandEnvelope.fromFinish(
    projectUrl: origin,
    ownerId: f.owner,
    request: f.finish(),
  ),
};
ConversationReceiptSnapshot completed(PendingConversationCommandEnvelope c) =>
    ConversationReceiptSnapshot.fromRows(c.reference, [
      {
        'user_id': f.owner,
        'operation': c.reference.operation.wireName,
        'client_event_id': c.reference.clientEventId,
        'status': 'COMPLETED',
        'response_json': f.response(c.reference.operation.wireName),
      },
    ]);
Future<void> submit(
  CapturedConversationSession flow,
  PendingConversationCommandEnvelope c,
) async {
  if (c.start != null) {
    await flow.start(c.start!);
  } else if (c.turn != null) {
    await flow.turn(c.turn!);
  } else {
    await flow.finish(c.finish!);
  }
}

void main() {
  setUpAll(() {
    f.fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  Future<({CapturedConversationSession flow, f.Auth auth, f.Port port})>
  pending(String op, {bool Function()? ready}) async {
    final auth = f.Auth();
    final port = f.Port();
    final flow = CapturedConversationSession(
      auth: auth,
      transport: port,
      isReady: ready ?? () => true,
    );
    if (op != 'start_conversation') await flow.start(f.start());
    port.reply = (_) =>
        throw const AiTextFailure(AiTextErrorCode.providerUnavailable);
    await expectLater(
      submit(flow, command(op)),
      throwsA(f.code(AiTextErrorCode.providerUnavailable)),
    );
    return (flow: flow, auth: auth, port: port);
  }

  Future<({CapturedConversationCompletion handle, r.OriginalPort port})>
  completion(
    ReviewAuth auth,
    PendingConversationCommandEnvelope c, {
    bool Function()? ready,
  }) async {
    final port = r.OriginalPort()..result = completed(c);
    final reader = CapturedConversationReceiptLookup(
      auth: auth,
      port: port,
      isReady: ready ?? () => true,
    );
    return (handle: (await reader.lookupCompletion(c))!, port: port);
  }

  for (final op in [
    'start_conversation',
    'conversation_turn',
    'finish_conversation',
  ]) {
    test('inspect exact pending $op without applying or releasing', () async {
      final p = await pending(op);
      final c = await completion(p.auth, command(op));
      final snapshot = p.flow.snapshot;
      final retained = p.flow.retainedCommand;
      final sends = p.port.calls.length;
      expect(p.flow.inspectRetainedCompletion(c.handle), same(c.port.result));
      expect(p.flow.inspectRetainedCompletion(c.handle), same(c.port.result));
      expect(p.flow.snapshot, same(snapshot));
      expect(p.flow.retainedCommand, same(retained));
      expect(p.flow.hasUnresolvedMutation, isTrue);
      expect(p.flow.canRetryRetained, isFalse);
      expect(p.port.calls, hasLength(sends));
      expect(c.port.calls, 1);
      expect(c.port.legacyCalls, 0);
    });
  }
  test(
    'operation/event/session/text/UUID spelling mismatch cannot match retained command',
    () async {
      final p = await pending('conversation_turn');
      final before = p.flow.snapshot;
      final variants = [
        PendingConversationCommandEnvelope.fromFinish(
          projectUrl: origin,
          ownerId: f.owner,
          request: FinishConversationRequest(
            sessionId: f.session,
            clientEventId: f.turnEvent,
          ),
        ),
        for (final req in [
          f.turn(event: f.otherEvent),
          f.turn(sessionId: f.owner),
          f.turn(sessionId: f.session.toUpperCase()),
          f.turn(text: '${f.turn().textJa} '),
          f.turn(text: '  ぢ  '),
        ])
          PendingConversationCommandEnvelope.fromTurn(
            projectUrl: origin,
            ownerId: f.owner,
            request: req,
          ),
      ];
      for (final variant in variants) {
        final c = await completion(p.auth, variant);
        expect(c.handle.isCurrent, isTrue);
        expect(p.flow.inspectRetainedCompletion(c.handle), isNull);
        expect(p.flow.snapshot, same(before));
        expect(p.flow.hasUnresolvedMutation, isTrue);
        expect(c.port.calls, 1);
      }
      expect(p.port.calls, hasLength(2));
    },
  );
  test(
    'equal owner/session hint in different Auth object is insufficient',
    () async {
      final p = await pending('start_conversation');
      final other = f.Auth()..currentSession = p.auth.currentSession;
      final c = await completion(other, command('start_conversation'));
      expect(c.handle.isCurrent, isTrue);
      expect(p.flow.inspectRetainedCompletion(c.handle), isNull);
      expect(p.flow.hasUnresolvedMutation, isTrue);
      expect(p.port.calls, hasLength(1));
    },
  );
  test('idle session without unresolved command cannot inspect', () async {
    final auth = f.Auth();
    final port = f.Port();
    final flow = CapturedConversationSession(
      auth: auth,
      transport: port,
      isReady: () => true,
    );
    final c = await completion(auth, command('start_conversation'));
    expect(flow.inspectRetainedCompletion(c.handle), isNull);
    await flow.start(f.start());
    expect(flow.inspectRetainedCompletion(c.handle), isNull);
    expect(flow.snapshot.phase, ConversationSessionPhase.active);
    expect(port.calls, hasLength(1));
  });
  test(
    'inspection waits actual timed-out wire drain and never applies late result',
    () async {
      final auth = f.Auth();
      final held = Completer<Object?>();
      final port = f.Port()..reply = (_) => held.future;
      final flow = CapturedConversationSession(
        auth: auth,
        transport: port,
        isReady: () => true,
        timeout: const Duration(milliseconds: 10),
      );
      final c = await completion(auth, command('start_conversation'));
      final request = expectLater(
        flow.start(f.start()),
        throwsA(f.code(AiTextErrorCode.networkUnavailable)),
      );
      expect(flow.inspectRetainedCompletion(c.handle), isNull);
      await request;
      expect(flow.inspectRetainedCompletion(c.handle), isNull);
      held.complete(f.response('start_conversation'));
      await f.settle();
      expect(flow.inspectRetainedCompletion(c.handle), same(c.port.result));
      expect(flow.snapshot.phase, ConversationSessionPhase.notStarted);
      expect(flow.hasUnresolvedMutation, isTrue);
      expect(port.calls, hasLength(1));
    },
  );
  for (final revoke in [false, true]) {
    test(
      'completion readiness reentry redacts and cannot publish after revoke=$revoke',
      () async {
        final p = await pending('start_conversation');
        var armed = false;
        var nested = 0;
        late CapturedConversationCompletion handle;
        final c = await completion(
          p.auth,
          command('start_conversation'),
          ready: () {
            if (armed) {
              nested++;
              expect(p.flow.inspectRetainedCompletion(handle), isNull);
              if (revoke) p.flow.revoke();
            }
            return true;
          },
        );
        handle = c.handle;
        armed = true;
        final result = p.flow.inspectRetainedCompletion(handle);
        expect(nested, greaterThan(0));
        if (revoke) {
          expect(result, isNull);
        } else {
          expect(result, same(c.port.result));
        }
        armed = false;
        expect(p.flow.isCheckingAvailability, isFalse);
        expect(p.flow.isCurrent, !revoke);
        expect(p.port.calls, hasLength(1));
        expect(c.port.calls, 1);
      },
    );
  }
  test('refresh during completion capture suppresses inspection', () async {
    final p = await pending('start_conversation');
    var armed = false;
    final c = await completion(
      p.auth,
      command('start_conversation'),
      ready: () {
        if (armed) {
          p.auth.currentSession = ReviewSession(userId: f.owner);
        }
        return true;
      },
    );
    armed = true;
    expect(p.flow.inspectRetainedCompletion(c.handle), isNull);
    armed = false;
    expect(c.handle.isCurrent, isFalse);
    expect(p.flow.isCurrent, isFalse);
    expect(p.flow.retainedCommand, isNull);
    expect(p.port.calls, hasLength(1));
    expect(c.port.calls, 1);
  });
  test(
    'refresh permanently retires session inspection even on A return',
    () async {
      final p = await pending('start_conversation');
      final c = await completion(p.auth, command('start_conversation'));
      final original = p.auth.currentSession;
      p.auth.currentSession = ReviewSession(userId: f.owner);
      expect(p.flow.inspectRetainedCompletion(c.handle), isNull);
      p.auth.currentSession = original;
      expect(p.flow.inspectRetainedCompletion(c.handle), isNull);
      expect(p.flow.isCurrent, isFalse);
      expect(p.flow.retainedCommand, isNull);
      expect(p.port.calls, hasLength(1));
    },
  );
}
