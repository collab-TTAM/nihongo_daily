// TEST ONLY injected Auth/port. No HTTP, server receipt or hosted learner proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_mutation.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_session.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/ai/domain/retained_conversation_command.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

const owner = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const session = 'abcdefab-0000-4000-8000-abcdefabcdef';
const startEvent = '11111111-1111-4111-8111-111111111111';
const turnEvent = '22222222-2222-4222-8222-222222222222';
const finishEvent = '33333333-3333-4333-8333-333333333333';
const otherEvent = '44444444-4444-4444-8444-444444444444';
const message0 = 'abcdefab-1111-4000-8000-abcdefabcdef';
const message1 = 'abcdefab-2222-4000-8000-abcdefabcdef';
const message2 = 'abcdefab-3333-4000-8000-abcdefabcdef';
late Map<String, Object?> fixtures;

final class Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(userId: owner);
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
    return Future<Object?>.sync(() {
      if (reply != null) return reply!(operation);
      return response(operation);
    });
  }
}

Map<String, Object?> response(
  String operation, {
  int sequence = 2,
  String message = message1,
}) {
  final result =
      jsonDecode(jsonEncode(fixtures['${operation}_response']))
          as Map<String, Object?>;
  if (operation == 'start_conversation') result['session_id'] = session;
  if (operation != 'finish_conversation') {
    final m = result['assistant_message']! as Map<String, Object?>;
    m['sequence_no'] = operation == 'start_conversation' ? 0 : sequence;
    m['id'] = operation == 'start_conversation' ? message0 : message;
  }
  return result;
}

StartConversationRequest start([String event = startEvent]) =>
    StartConversationRequest(
      scenarioId: owner,
      level: AiTextLevel.n4,
      clientEventId: event,
    );
ConversationTurnRequest turn({
  String event = turnEvent,
  String text = '  日\u3099  ',
  String sessionId = session,
}) => ConversationTurnRequest(
  sessionId: sessionId,
  clientEventId: event,
  textJa: text,
);
FinishConversationRequest finish({
  String event = finishEvent,
  String sessionId = session,
}) => FinishConversationRequest(sessionId: sessionId, clientEventId: event);
Matcher code(AiTextErrorCode c) =>
    isA<AiTextFailure>().having((e) => e.code, 'code', c);
Future<void> settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.value();
  }
}

Map<String, Object>? retainedBody(RetainedConversationCommand? command) =>
    switch (command) {
      RetainedConversationStart(:final request) => request.toJson(),
      RetainedConversationTurn(:final request) => request.toJson(),
      RetainedConversationFinish(:final request) => request.toJson(),
      null => null,
    };

void main() {
  setUpAll(() {
    fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  test(
    'explicit progression captures session and finishes without derived writes',
    () async {
      final auth = Auth();
      final port = Port();
      final flow = CapturedConversationSession(
        auth: auth,
        transport: port,
        isReady: () => true,
      );
      final empty = flow.snapshot;
      expect(empty.phase, ConversationSessionPhase.notStarted);
      expect(empty.sessionId, isNull);
      expect(empty.messages, isEmpty);
      expect(empty.summary, isNull);
      expect(port.calls, isEmpty);
      await flow.start(start());
      final active = flow.snapshot;
      expect(active.phase, ConversationSessionPhase.active);
      expect(active.sessionId, session);
      expect(active.messages.single.id, message0);
      final reply = await flow.turn(turn(sessionId: session.toUpperCase()));
      expect(reply.assistantMessage.sequenceNo, 2);
      expect(
        port.calls[1].body,
        turn(sessionId: session.toUpperCase()).toJson(),
      );
      expect(
        port.calls.every((c) => identical(c.session, auth.currentSession)),
        isTrue,
      );
      final summary = await flow.finish(finish());
      final done = flow.snapshot;
      expect(done.phase, ConversationSessionPhase.finished);
      expect(done.messages.map((m) => m.sequenceNo), [0, 2]);
      expect(identical(done.summary, summary), isTrue);
      expect(summary.errors, isEmpty);
      expect(summary.srsRecommendations, isEmpty);
      expect(active.messages, hasLength(1));
      expect(empty.messages, isEmpty);
      expect(() => done.messages.clear(), throwsUnsupportedError);
      expect(port.calls.map((c) => c.operation), [
        'start_conversation',
        'conversation_turn',
        'finish_conversation',
      ]);
      expect(flow.isBusy, isFalse);
      expect(flow.hasUnresolvedMutation, isFalse);
    },
  );
  test(
    'pre-start foreign-session and post-finish operations never dispatch',
    () async {
      final port = Port();
      final flow = CapturedConversationSession(
        auth: Auth(),
        transport: port,
        isReady: () => true,
      );
      await expectLater(
        flow.turn(turn()),
        throwsA(code(AiTextErrorCode.syncConflict)),
      );
      await expectLater(
        flow.finish(finish()),
        throwsA(code(AiTextErrorCode.syncConflict)),
      );
      expect(port.calls, isEmpty);
      await flow.start(start());
      await expectLater(
        flow.turn(turn(sessionId: owner)),
        throwsA(code(AiTextErrorCode.syncConflict)),
      );
      await expectLater(
        flow.finish(finish(sessionId: owner)),
        throwsA(code(AiTextErrorCode.syncConflict)),
      );
      await expectLater(
        flow.start(start(otherEvent)),
        throwsA(code(AiTextErrorCode.syncConflict)),
      );
      expect(port.calls, hasLength(1));
      await flow.finish(finish());
      final snapshot = flow.snapshot;
      await expectLater(
        flow.turn(turn()),
        throwsA(code(AiTextErrorCode.syncConflict)),
      );
      await expectLater(
        flow.start(start()),
        throwsA(code(AiTextErrorCode.syncConflict)),
      );
      await expectLater(
        flow.finish(finish(event: otherEvent)),
        throwsA(code(AiTextErrorCode.syncConflict)),
      );
      expect(port.calls, hasLength(2));
      expect(identical(flow.snapshot, snapshot), isTrue);
    },
  );
  test(
    'identical replay cannot append twice or roll back later progress',
    () async {
      final port = Port();
      final flow = CapturedConversationSession(
        auth: Auth(),
        transport: port,
        isReady: () => true,
      );
      final first = await flow.start(start());
      final second = await flow.turn(turn());
      port.reply = (op) => response(op, sequence: 7, message: message2);
      await flow.turn(turn(event: otherEvent));
      final state = flow.snapshot;
      expect(identical(await flow.start(start()), first), isTrue);
      expect(identical(await flow.turn(turn()), second), isTrue);
      expect(identical(flow.snapshot, state), isTrue);
      expect(state.messages.map((m) => m.sequenceNo), [0, 2, 7]);
      expect(port.calls, hasLength(3));
      final done = await flow.finish(finish());
      expect(identical(await flow.finish(finish()), done), isTrue);
      expect(port.calls, hasLength(4));
    },
  );
  test(
    'same operation event with changed wire conflicts without changing projection',
    () async {
      final port = Port();
      final flow = CapturedConversationSession(
        auth: Auth(),
        transport: port,
        isReady: () => true,
      );
      await flow.start(start());
      await flow.turn(turn());
      final state = flow.snapshot;
      await expectLater(
        flow.turn(turn(text: 'changed private text')),
        throwsA(code(AiTextErrorCode.syncConflict)),
      );
      await expectLater(
        flow.start(
          StartConversationRequest(
            scenarioId: otherEvent,
            level: AiTextLevel.n4,
            clientEventId: startEvent,
          ),
        ),
        throwsA(code(AiTextErrorCode.syncConflict)),
      );
      expect(identical(flow.snapshot, state), isTrue);
      expect(port.calls, hasLength(2));
      expect(flow.isCurrent, isTrue);
    },
  );
  test(
    'same UUID remains scoped by operation through start turn finish',
    () async {
      final port = Port();
      final flow = CapturedConversationSession(
        auth: Auth(),
        transport: port,
        isReady: () => true,
      );
      await flow.start(start(startEvent));
      await flow.turn(turn(event: startEvent));
      await flow.finish(finish(event: startEvent));
      expect(port.calls, hasLength(3));
      expect(flow.snapshot.phase, ConversationSessionPhase.finished);
    },
  );
  for (final invalid in [
    'duplicate sequence',
    'backward sequence',
    'duplicate message UUID',
  ]) {
    test(
      'invalid new response $invalid terminally clears publication',
      () async {
        final port = Port();
        final flow = CapturedConversationSession(
          auth: Auth(),
          transport: port,
          isReady: () => true,
        );
        await flow.start(start());
        await flow.turn(turn());
        port.reply = (op) => response(
          op,
          sequence: invalid == 'duplicate sequence'
              ? 2
              : invalid == 'backward sequence'
              ? 1
              : 4,
          message: invalid == 'duplicate message UUID'
              ? message0.toUpperCase()
              : message2,
        );
        final failure = code(AiTextErrorCode.syncConflict);
        await expectLater(flow.turn(turn(event: otherEvent)), throwsA(failure));
        expect(flow.snapshot.phase, ConversationSessionPhase.revoked);
        expect(flow.snapshot.sessionId, isNull);
        expect(flow.snapshot.messages, isEmpty);
        expect(flow.snapshot.summary, isNull);
        await expectLater(
          flow.turn(turn(event: otherEvent)),
          throwsA(code(AiTextErrorCode.unauthorized)),
        );
        await expectLater(
          flow.finish(finish()),
          throwsA(code(AiTextErrorCode.unauthorized)),
        );
        expect(port.calls, hasLength(3));
      },
    );
  }
  for (final operation in [
    'start_conversation',
    'conversation_turn',
    'finish_conversation',
  ]) {
    for (final lateError in [false, true]) {
      test(
        'uncertain $operation late error=$lateError keeps exact retry and projection',
        () async {
          final port = Port();
          final flow = CapturedConversationSession(
            auth: Auth(),
            transport: port,
            isReady: () => true,
            timeout: const Duration(milliseconds: 25),
          );
          if (operation != 'start_conversation') await flow.start(start());
          final before = flow.snapshot;
          final held = Completer<Object?>();
          port.reply = (_) => held.future;
          Future<Object> send() => switch (operation) {
            'start_conversation' => flow.start(start()),
            'conversation_turn' => flow.turn(turn()),
            _ => flow.finish(finish()),
          };
          final request = send();
          expect(flow.retainedCommand, isNull);
          await expectLater(send(), throwsA(isA<AiTextRequestPending>()));
          await expectLater(
            request,
            throwsA(code(AiTextErrorCode.networkUnavailable)),
          );
          expect(identical(flow.snapshot, before), isTrue);
          expect(flow.isBusy, isTrue);
          expect(flow.retainedCommand, isNull);
          expect(flow.hasUnresolvedMutation, isTrue);
          final count = port.calls.length;
          await expectLater(send(), throwsA(isA<AiTextRequestPending>()));
          if (lateError) {
            held.completeError(StateError('private late provider detail'));
          } else {
            held.complete(response(operation));
          }
          await settle();
          expect(flow.isBusy, isFalse);
          final retained = flow.retainedCommand;
          expect(retainedBody(retained), port.calls.last.body);
          expect(flow.hasUnresolvedMutation, isTrue);
          expect(identical(flow.snapshot, before), isTrue);
          final Future<Object> fresh = switch (operation) {
            'start_conversation' => flow.start(start(otherEvent)),
            'conversation_turn' => flow.turn(turn(event: otherEvent)),
            _ => flow.finish(finish(event: otherEvent)),
          };
          await expectLater(fresh, throwsA(isA<AiTextRequestPending>()));
          if (operation != 'start_conversation') {
            await expectLater(
              flow.start(start()),
              throwsA(isA<AiTextRequestPending>()),
            );
          }
          expect(port.calls, hasLength(count));
          expect(identical(flow.retainedCommand, retained), isTrue);
          port.reply = (op) => response(op);
          await send();
          expect(port.calls.last.body, port.calls[count - 1].body);
          expect(flow.hasUnresolvedMutation, isFalse);
          expect(flow.retainedCommand, isNull);
          expect(
            flow.snapshot.phase,
            operation == 'finish_conversation'
                ? ConversationSessionPhase.finished
                : ConversationSessionPhase.active,
          );
          expect(
            flow.snapshot.messages,
            hasLength(operation == 'conversation_turn' ? 2 : 1),
          );
          expect(port.calls, hasLength(count + 1));
        },
      );
    }
  }
  test(
    'provider and malformed failures retain original event without optimistic advancement',
    () async {
      final port = Port();
      final flow = CapturedConversationSession(
        auth: Auth(),
        transport: port,
        isReady: () => true,
      );
      await flow.start(start());
      final state = flow.snapshot;
      port.reply = (_) => {
        'code': 'PROVIDER_UNAVAILABLE',
        'message_vi': 'private provider detail',
        'retryable': true,
      };
      await expectLater(
        flow.turn(turn()),
        throwsA(code(AiTextErrorCode.providerUnavailable)),
      );
      expect(identical(flow.snapshot, state), isTrue);
      port.reply = (_) => {'assistant_message': 'private malformed response'};
      await expectLater(
        flow.turn(turn()),
        throwsA(code(AiTextErrorCode.internalError)),
      );
      await expectLater(
        flow.finish(finish()),
        throwsA(isA<AiTextRequestPending>()),
      );
      expect(identical(flow.snapshot, state), isTrue);
      port.reply = (op) => response(op);
      await flow.turn(turn());
      expect(flow.snapshot.messages, hasLength(2));
      expect(port.calls, hasLength(4));
    },
  );
  test(
    'port and readiness reentry cannot overlap and nested read is redacted',
    () async {
      final port = Port();
      late CapturedConversationSession flow;
      var installed = false;
      var reenter = false;
      final nested = <Future<Object>>[];
      final nestedPhases = <ConversationSessionPhase>[];
      flow = CapturedConversationSession(
        auth: Auth(),
        transport: port,
        isReady: () {
          if (installed && reenter) {
            reenter = false;
            nestedPhases.add(flow.snapshot.phase);
            nested.add(flow.finish(finish()));
          }
          return true;
        },
      );
      installed = true;
      port.reply = (op) {
        nested.add(flow.start(start()));
        return response(op);
      };
      // Attach handlers immediately: rejected futures may settle before outer send.
      final errors = <Object>[];
      void observe() {
        for (final future in nested) {
          unawaited(
            future.then<void>(
              (_) => fail('Unexpected nested success'),
              onError: (Object e, StackTrace _) {
                errors.add(e);
              },
            ),
          );
        }
        nested.clear();
      }

      reenter = true;
      final first = flow.start(start());
      observe();
      await first;
      expect(errors, hasLength(2));
      expect(errors.every((e) => e is AiTextRequestPending), isTrue);
      expect(nestedPhases, [ConversationSessionPhase.revoked]);
      expect(port.calls, hasLength(1));
      expect(flow.snapshot.phase, ConversationSessionPhase.active);
    },
  );
  for (final lateError in [false, true]) {
    test(
      'explicit revoke fences A B A late response error=$lateError and retains drain',
      () async {
        final auth = Auth();
        final port = Port();
        final flow = CapturedConversationSession(
          auth: auth,
          transport: port,
          isReady: () => true,
        );
        await flow.start(start());
        final a = auth.currentSession;
        final held = Completer<Object?>();
        port.reply = (_) => held.future;
        final request = flow.turn(turn());
        auth.currentSession = ReviewSession(userId: otherEvent);
        flow.revoke();
        auth.currentSession = a;
        expect(flow.snapshot.messages, isEmpty);
        expect(flow.isBusy, isTrue);
        final check = expectLater(
          request,
          throwsA(code(AiTextErrorCode.unauthorized)),
        );
        if (lateError) {
          held.completeError(StateError('private late error'));
        } else {
          held.complete(response('conversation_turn'));
        }
        await check;
        expect(flow.isBusy, isFalse);
        expect(flow.isCurrent, isFalse);
        await expectLater(
          flow.start(start()),
          throwsA(code(AiTextErrorCode.unauthorized)),
        );
        expect(port.calls, hasLength(2));
      },
    );
  }
  test(
    'readiness loss getter failure same-user replacement and 401 clear summaries permanently',
    () async {
      for (final loss in ['ready', 'getter', 'same user', '401']) {
        final auth = Auth();
        final port = Port();
        var ready = true;
        var throws = false;
        final flow = CapturedConversationSession(
          auth: auth,
          transport: port,
          isReady: () {
            if (throws) throw StateError('private getter detail');
            return ready;
          },
        );
        await flow.start(start());
        if (loss == '401') {
          port.reply = (_) => {
            'code': 'UNAUTHORIZED',
            'message_vi': 'private',
            'retryable': false,
          };
          await expectLater(
            flow.finish(finish()),
            throwsA(code(AiTextErrorCode.unauthorized)),
          );
        } else {
          await flow.finish(finish());
          expect(flow.snapshot.summary, isNotNull);
          if (loss == 'ready') ready = false;
          if (loss == 'getter') throws = true;
          if (loss == 'same user') {
            auth.currentSession = ReviewSession(userId: owner);
          }
        }
        expect(flow.snapshot.phase, ConversationSessionPhase.revoked);
        expect(flow.snapshot.messages, isEmpty);
        expect(flow.snapshot.summary, isNull);
        ready = true;
        throws = false;
        await expectLater(
          flow.finish(finish()),
          throwsA(code(AiTextErrorCode.unauthorized)),
        );
        expect(port.calls, hasLength(2));
      }
    },
  );
  test(
    'bounded lane capacity cannot discard history and finish implicitly',
    () async {
      final port = Port();
      final flow = CapturedConversationSession(
        auth: Auth(),
        transport: port,
        isReady: () => true,
        maxMutations: 2,
      );
      await flow.start(start());
      await flow.turn(turn());
      final state = flow.snapshot;
      await expectLater(
        flow.finish(finish()),
        throwsA(code(AiTextErrorCode.rateLimited)),
      );
      expect(identical(flow.snapshot, state), isTrue);
      expect(flow.hasUnresolvedMutation, isFalse);
      expect(flow.retainedCommand, isNull);
      await flow.turn(turn());
      expect(port.calls, hasLength(2));
    },
  );

  for (final operation in [
    'start_conversation',
    'conversation_turn',
    'finish_conversation',
  ]) {
    test(
      'retained $operation preserves full original without authority',
      () async {
        final port = Port();
        final flow = CapturedConversationSession(
          auth: Auth(),
          transport: port,
          isReady: () => true,
        );
        expect(flow.retainedCommand, isNull);
        if (operation != 'start_conversation') await flow.start(start());
        final originalStart = StartConversationRequest(
          scenarioId: owner.toUpperCase(),
          level: AiTextLevel.n5,
          clientEventId: startEvent,
        );
        final originalTurn = turn(text: '  か\u3099\n日本語 😀  ');
        final originalFinish = finish(sessionId: session.toUpperCase());
        Future<Object> send() => switch (operation) {
          'start_conversation' => flow.start(originalStart),
          'conversation_turn' => flow.turn(originalTurn),
          _ => flow.finish(originalFinish),
        };
        port.reply = (_) =>
            throw const AiTextFailure(AiTextErrorCode.providerUnavailable);
        await expectLater(
          send(),
          throwsA(code(AiTextErrorCode.providerUnavailable)),
        );
        final retained = flow.retainedCommand;
        final Object? original = switch (retained) {
          RetainedConversationStart(:final request) => request,
          RetainedConversationTurn(:final request) => request,
          RetainedConversationFinish(:final request) => request,
          null => null,
        };
        expect(
          identical(original, switch (operation) {
            'start_conversation' => originalStart,
            'conversation_turn' => originalTurn,
            _ => originalFinish,
          }),
          isTrue,
        );
        final sentBody = Map<String, Object>.of(port.calls.last.body);
        expect(retainedBody(retained), sentBody);
        expect(retained.toString(), 'RetainedConversationCommand');
        // A caller-owned projection cannot replace the frozen original DTO.
        retainedBody(retained)!.clear();
        expect(retainedBody(flow.retainedCommand), sentBody);
        expect(flow.canRetryRetained, isFalse);
        final count = port.calls.length;
        await flow.retryRetained();
        final Future<Object> changed = switch (operation) {
          'start_conversation' => flow.start(start()),
          'conversation_turn' => flow.turn(turn(text: 'different')),
          _ => flow.finish(finish()),
        };
        await expectLater(changed, throwsA(code(AiTextErrorCode.syncConflict)));
        final Future<Object> fresh = switch (operation) {
          'start_conversation' => flow.start(start(otherEvent)),
          'conversation_turn' => flow.turn(turn(event: otherEvent)),
          _ => flow.finish(finish(event: otherEvent)),
        };
        await expectLater(fresh, throwsA(isA<AiTextRequestPending>()));
        expect(identical(flow.retainedCommand, retained), isTrue);
        expect(flow.canRetryRetained, isFalse);
        expect(flow.hasUnresolvedMutation, isTrue);
        expect(port.calls, hasLength(count));
        // Existing explicit exact-input submission remains the only action here.
        port.reply = (op) => response(op);
        await send();
        expect(port.calls.last.body, sentBody);
        expect(port.calls, hasLength(count + 1));
        expect(flow.retainedCommand, isNull);
        expect(flow.hasUnresolvedMutation, isFalse);
      },
    );
  }

  for (final loss in ['readiness', 'getter', 'refresh', 'logout', 'A B A']) {
    test('retained command redacted permanently after $loss', () async {
      final auth = Auth();
      final originalSession = auth.currentSession;
      final port = Port();
      var ready = true;
      var getterThrows = false;
      final flow = CapturedConversationSession(
        auth: auth,
        transport: port,
        isReady: () {
          if (getterThrows) throw StateError('private readiness detail');
          return ready;
        },
      );
      await flow.start(start());
      port.reply = (_) => throw const AiTextFailure(
        AiTextErrorCode.providerUnavailable,
        retryable: true,
      );
      await expectLater(flow.turn(turn()), throwsA(isA<AiTextFailure>()));
      expect(flow.retainedCommand, isA<RetainedConversationTurn>());
      if (loss == 'readiness') ready = false;
      if (loss == 'getter') getterThrows = true;
      if (loss == 'refresh') {
        auth.currentSession = ReviewSession(userId: owner);
      }
      if (loss == 'logout') auth.currentSession = null;
      if (loss == 'A B A') {
        auth.currentSession = ReviewSession(userId: otherEvent);
        flow.revoke();
        auth.currentSession = originalSession;
      }
      expect(flow.retainedCommand, isNull);
      ready = true;
      getterThrows = false;
      auth.currentSession = originalSession;
      expect(flow.retainedCommand, isNull);
      expect(flow.canRetryRetained, isFalse);
      await flow.retryRetained();
      expect(port.calls, hasLength(2));
    });
  }

  test('retained read redacts readiness and transport reentry', () async {
    late CapturedConversationSession flow;
    final port = Port();
    var inspect = false;
    final nested = <RetainedConversationCommand?>[];
    flow = CapturedConversationSession(
      auth: Auth(),
      transport: port,
      isReady: () {
        if (inspect) nested.add(flow.retainedCommand);
        return true;
      },
    );
    port.reply = (_) {
      nested.add(flow.retainedCommand);
      throw const AiTextFailure(AiTextErrorCode.providerUnavailable);
    };
    await expectLater(flow.start(start()), throwsA(isA<AiTextFailure>()));
    inspect = true;
    expect(flow.retainedCommand, isA<RetainedConversationStart>());
    expect(nested.length, greaterThan(1));
    expect(nested.every((value) => value == null), isTrue);
    expect(port.calls, hasLength(1));
  });
}
