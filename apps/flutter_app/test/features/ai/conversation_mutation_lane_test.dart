// TEST ONLY captured hints/held ports; not HTTP, hosted receipts or remote drain.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/data/conversation_mutation_lane.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_mutation.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

const id = 'abcdefab-1234-0000-ffff-abcdefabcdef';
const e1 = '11111111-1111-4111-8111-111111111111';
const e2 = '22222222-2222-4222-8222-222222222222';
const e3 = '33333333-3333-4333-8333-333333333333';
late Map<String, Object?> fixtures;

final class Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(userId: id);
}

final class Port implements ConversationMutationTransport {
  final calls =
      <({String operation, ReviewSession session, Map<String, Object> body})>[];
  FutureOr<Object?> Function(String)? reply;
  @override
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String operation,
    required Map<String, Object> body,
  }) {
    calls.add((operation: operation, session: capturedSession, body: body));
    final handler = reply;
    return Future<Object?>.sync(
      () => handler == null
          ? fixtures['${operation}_response']
          : handler(operation),
    );
  }
}

Matcher code(AiTextErrorCode c) =>
    isA<AiTextFailure>().having((e) => e.code, 'code', c);
StartConversationRequest start([String event = e1]) => StartConversationRequest(
  scenarioId: id,
  level: AiTextLevel.n4,
  clientEventId: event,
);
ConversationTurnRequest turn([String event = e2, String text = '日']) =>
    ConversationTurnRequest(sessionId: id, clientEventId: event, textJa: text);
FinishConversationRequest finish([String event = e3]) =>
    FinishConversationRequest(sessionId: id, clientEventId: event);
void main() {
  setUpAll(() {
    fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  test(
    'one lane serializes typed operations and reuses identical event success locally',
    () async {
      final auth = Auth();
      final port = Port();
      final lane = ConversationMutationLane(
        auth: auth,
        transport: port,
        isReady: () => true,
      );
      expect(port.calls, isEmpty);
      final first = await lane.start(start());
      expect(identical(await lane.start(start()), first), isTrue);
      await lane.turn(turn());
      await lane.finish(finish());
      expect(port.calls, hasLength(3));
      expect(port.calls.map((c) => c.operation), [
        'start_conversation',
        'conversation_turn',
        'finish_conversation',
      ]);
      expect(lane.retainedMutationCount, 3);
      expect(lane.hasUnresolvedMutation, isFalse);
      expect(lane.isBusy, isFalse);
    },
  );
  test('different typed operations cannot overlap a held start', () async {
    final auth = Auth();
    final port = Port();
    final held = Completer<Object?>();
    port.reply = (_) => held.future;
    final lane = ConversationMutationLane(
      auth: auth,
      transport: port,
      isReady: () => true,
    );
    final first = lane.start(start());
    expect(lane.isBusy, isTrue);
    await expectLater(lane.turn(turn()), throwsA(isA<AiTextRequestPending>()));
    await expectLater(
      lane.finish(finish()),
      throwsA(isA<AiTextRequestPending>()),
    );
    expect(port.calls, hasLength(1));
    held.complete(fixtures['start_conversation_response']);
    await first;
    expect(lane.hasUnresolvedMutation, isFalse);
  });
  test(
    'changed replay body scenario level session and UUID case are rejected before dispatch',
    () async {
      final auth = Auth();
      final port = Port();
      final lane = ConversationMutationLane(
        auth: auth,
        transport: port,
        isReady: () => true,
      );
      await lane.start(start());
      for (final request in [
        StartConversationRequest(
          scenarioId: e2,
          level: AiTextLevel.n4,
          clientEventId: e1,
        ),
        StartConversationRequest(
          scenarioId: id,
          level: AiTextLevel.n5,
          clientEventId: e1,
        ),
      ]) {
        await expectLater(
          lane.start(request),
          throwsA(code(AiTextErrorCode.syncConflict)),
        );
      }
      await lane.turn(turn());
      await expectLater(
        lane.turn(turn(e2, 'changed')),
        throwsA(code(AiTextErrorCode.syncConflict)),
      );
      await expectLater(
        lane.turn(
          ConversationTurnRequest(
            sessionId: e1,
            clientEventId: e2,
            textJa: '日',
          ),
        ),
        throwsA(code(AiTextErrorCode.syncConflict)),
      );
      final alpha = start(id);
      await lane.start(alpha);
      await expectLater(
        lane.start(start(id.toUpperCase())),
        throwsA(code(AiTextErrorCode.syncConflict)),
      );
      expect(port.calls, hasLength(3));
    },
  );
  test(
    'event IDs are operation scoped and success replay cannot evict another slot',
    () async {
      final auth = Auth();
      final port = Port();
      final lane = ConversationMutationLane(
        auth: auth,
        transport: port,
        isReady: () => true,
        maxMutations: 3,
      );
      await lane.start(start(e1));
      await lane.turn(turn(e1));
      await lane.finish(finish(e1));
      await lane.start(start(e1));
      expect(port.calls, hasLength(3));
      expect(lane.retainedMutationCount, 3);
    },
  );
  for (final lateError in [false, true]) {
    test(
      'uncertain timeout keeps same event reservation even after wire drain error=$lateError',
      () async {
        final auth = Auth();
        final port = Port();
        final held = Completer<Object?>();
        port.reply = (_) => held.future;
        final lane = ConversationMutationLane(
          auth: auth,
          transport: port,
          isReady: () => true,
          timeout: const Duration(milliseconds: 5),
        );
        await expectLater(
          lane.turn(turn()),
          throwsA(code(AiTextErrorCode.networkUnavailable)),
        );
        expect(lane.isBusy, isTrue);
        expect(lane.hasUnresolvedMutation, isTrue);
        await expectLater(
          lane.finish(finish()),
          throwsA(isA<AiTextRequestPending>()),
        );
        await expectLater(
          lane.turn(turn(e3)),
          throwsA(isA<AiTextRequestPending>()),
        );
        await expectLater(
          lane.turn(turn(e2, 'changed')),
          throwsA(code(AiTextErrorCode.syncConflict)),
        );
        if (lateError) {
          held.completeError(StateError('PRIVATE_LATE'));
        } else {
          held.complete(fixtures['conversation_turn_response']);
        }
        await Future<void>.delayed(Duration.zero);
        expect(lane.isBusy, isFalse);
        expect(lane.hasUnresolvedMutation, isTrue);
        await expectLater(
          lane.finish(finish()),
          throwsA(isA<AiTextRequestPending>()),
        );
        expect(port.calls, hasLength(1));
        port.reply = null;
        await lane.turn(turn());
        expect(identical(port.calls[0].body, port.calls[1].body), isTrue);
        expect(lane.hasUnresolvedMutation, isFalse);
        await lane.finish(finish());
        expect(port.calls, hasLength(3));
      },
    );
  }
  test(
    'provider failure reserves original event and cached older replay cannot bypass uncertainty',
    () async {
      final auth = Auth();
      final port = Port();
      final lane = ConversationMutationLane(
        auth: auth,
        transport: port,
        isReady: () => true,
      );
      await lane.start(start());
      port.reply = (_) => throw const AiTextFailure(
        AiTextErrorCode.providerUnavailable,
        retryable: true,
      );
      await expectLater(
        lane.turn(turn()),
        throwsA(code(AiTextErrorCode.providerUnavailable)),
      );
      expect(lane.hasUnresolvedMutation, isTrue);
      await expectLater(
        lane.start(start()),
        throwsA(isA<AiTextRequestPending>()),
      );
      expect(port.calls, hasLength(2));
      port.reply = null;
      await lane.turn(turn());
      await lane.start(start());
      expect(port.calls, hasLength(3));
    },
  );
  test(
    'capacity is bounded without eviction while existing replay still works',
    () async {
      final auth = Auth();
      final port = Port();
      final lane = ConversationMutationLane(
        auth: auth,
        transport: port,
        isReady: () => true,
        maxMutations: 1,
      );
      await lane.turn(turn());
      await expectLater(
        lane.finish(finish()),
        throwsA(code(AiTextErrorCode.rateLimited)),
      );
      await lane.turn(turn());
      expect(port.calls, hasLength(1));
      expect(lane.retainedMutationCount, 1);
      expect(lane.hasUnresolvedMutation, isFalse);
    },
  );
  test(
    'synchronous port and readiness reentry cannot dispatch another operation',
    () async {
      final auth = Auth();
      final port = Port();
      var probe = false;
      Future<void>? getterNested;
      late ConversationMutationLane lane;
      lane = ConversationMutationLane(
        auth: auth,
        transport: port,
        isReady: () {
          if (probe) {
            probe = false;
            getterNested = expectLater(
              lane.finish(finish()),
              throwsA(isA<AiTextRequestPending>()),
            );
          }
          return true;
        },
      );
      Future<void>? portNested;
      port.reply = (op) {
        portNested = expectLater(
          lane.turn(turn()),
          throwsA(isA<AiTextRequestPending>()),
        );
        return fixtures['${op}_response'];
      };
      probe = true;
      await lane.start(start());
      await getterNested;
      await portNested;
      expect(port.calls, hasLength(1));
    },
  );
  for (final error in [false, true]) {
    test(
      'revoke drops publication and A B A cannot revive while late work drains error=$error',
      () async {
        final auth = Auth();
        final original = auth.currentSession;
        final port = Port();
        final held = Completer<Object?>();
        port.reply = (_) => held.future;
        final lane = ConversationMutationLane(
          auth: auth,
          transport: port,
          isReady: () => true,
        );
        final rejected = expectLater(
          lane.turn(turn()),
          throwsA(code(AiTextErrorCode.unauthorized)),
        );
        auth.currentSession = ReviewSession(userId: e1);
        expect(lane.isCurrent, isFalse);
        auth.currentSession = original;
        expect(lane.retainedMutationCount, 0);
        expect(lane.isBusy, isTrue);
        if (error) {
          held.completeError(StateError('PRIVATE'));
        } else {
          held.complete(fixtures['conversation_turn_response']);
        }
        await rejected;
        expect(lane.isBusy, isFalse);
        await expectLater(
          lane.finish(finish()),
          throwsA(code(AiTextErrorCode.unauthorized)),
        );
        expect(port.calls, hasLength(1));
      },
    );
  }
  test(
    'ready getter failure and unauthorized response revoke the whole lane safely',
    () async {
      final auth = Auth();
      final port = Port();
      var broken = false;
      final lane = ConversationMutationLane(
        auth: auth,
        transport: port,
        isReady: () {
          if (broken) throw StateError('PRIVATE');
          return true;
        },
      );
      await lane.start(start());
      broken = true;
      await expectLater(
        lane.start(start()),
        throwsA(code(AiTextErrorCode.unauthorized)),
      );
      expect(lane.retainedMutationCount, 0);
      final next = ConversationMutationLane(
        auth: auth,
        transport: port,
        isReady: () => true,
      );
      port.reply = (_) => {
        'code': 'UNAUTHORIZED',
        'message_vi': 'PRIVATE',
        'retryable': false,
      };
      await expectLater(
        next.turn(turn()),
        throwsA(code(AiTextErrorCode.unauthorized)),
      );
      expect(next.isCurrent, isFalse);
      expect(next.retainedMutationCount, 0);
      expect(port.calls, hasLength(2));
    },
  );
  test(
    'same-user replacement explicit revoke and invalid limits cannot create dispatch',
    () async {
      final auth = Auth();
      final port = Port();
      final lane = ConversationMutationLane(
        auth: auth,
        transport: port,
        isReady: () => true,
      );
      auth.currentSession = ReviewSession(userId: id);
      await expectLater(
        lane.start(start()),
        throwsA(code(AiTextErrorCode.unauthorized)),
      );
      final next = ConversationMutationLane(
        auth: auth,
        transport: port,
        isReady: () => true,
      );
      next.revoke();
      await expectLater(
        next.turn(turn()),
        throwsA(code(AiTextErrorCode.unauthorized)),
      );
      for (final limit in [0, 1001]) {
        expect(
          () => ConversationMutationLane(
            auth: auth,
            transport: port,
            isReady: () => true,
            maxMutations: limit,
          ),
          throwsArgumentError,
        );
      }
      for (final timeout in [Duration.zero, const Duration(seconds: 16)]) {
        expect(
          () => ConversationMutationLane(
            auth: auth,
            transport: port,
            isReady: () => true,
            timeout: timeout,
          ),
          throwsArgumentError,
        );
      }
      expect(port.calls, isEmpty);
    },
  );
}
