// TEST ONLY real captured flow with injected Auth/port; no hosted receipt proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/application/ai_conversation_controller.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_mutation.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_session.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

const owner = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const sessionId = 'abcdefab-0000-4000-8000-abcdefabcdef';
const startId = 'ABCDEFAB-1111-4000-8000-ABCDEFABCDEF';
const turnId = 'ABCDEFAB-2222-4000-8000-ABCDEFABCDEF';
const finishId = 'ABCDEFAB-3333-4000-8000-ABCDEFABCDEF';
const freshId = '44444444-4444-4444-8444-444444444444';
const message0 = 'abcdefab-1111-4000-8000-abcdefabcdef';
const message1 = 'abcdefab-2222-4000-8000-abcdefabcdef';
late Map<String, Object?> fixtures;

final class Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(userId: owner);
}

final class Port implements ConversationMutationTransport {
  final calls = <({String operation, Map<String, Object> body})>[];
  FutureOr<Object?> Function(String)? reply;
  @override
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String operation,
    required Map<String, Object> body,
  }) {
    calls.add((operation: operation, body: body));
    return Future<Object?>.sync(
      () => reply?.call(operation) ?? response(operation),
    );
  }
}

Object? response(String operation) {
  final json =
      jsonDecode(jsonEncode(fixtures['${operation}_response']))
          as Map<String, Object?>;
  if (operation == 'start_conversation') json['session_id'] = sessionId;
  if (operation != 'finish_conversation') {
    final message = json['assistant_message']! as Map<String, Object?>;
    message['sequence_no'] = operation == 'start_conversation' ? 0 : 2;
    message['id'] = operation == 'start_conversation' ? message0 : message1;
  }
  return json;
}

CapturedConversationSession flow(
  Port port, {
  Auth? auth,
  bool Function()? ready,
  Duration timeout = const Duration(seconds: 15),
}) => CapturedConversationSession(
  auth: auth ?? Auth(),
  transport: port,
  isReady: ready ?? () => true,
  timeout: timeout,
);
Future<void> start(
  AiConversationController controller, {
  String event = startId,
  AiTextLevel level = AiTextLevel.n4,
}) => controller.start(scenarioId: owner, level: level, clientEventId: event);
Future<void> settle() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.value();
  }
}

void main() {
  setUpAll(() {
    fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  test(
    'missing capability unavailable and construction never dispatches',
    () async {
      final absent = AiConversationController();
      expect(absent.state.phase, AiConversationPhase.unavailable);
      expect(absent.state.conversation, isNull);
      expect(absent.canStart, isFalse);
      expect(absent.canTurn, isFalse);
      expect(absent.canFinish, isFalse);
      expect(absent.canRetry, isFalse);
      await start(absent);
      await absent.retryPending();
      absent.dispose();
      final port = Port();
      final controller = AiConversationController(session: flow(port));
      addTearDown(controller.dispose);
      expect(controller.state.phase, AiConversationPhase.ready);
      expect(
        controller.state.conversation!.phase,
        ConversationSessionPhase.notStarted,
      );
      expect(controller.canStart, isTrue);
      expect(controller.canTurn, isFalse);
      controller.recheck();
      await controller.retryPending();
      expect(port.calls, isEmpty);
    },
  );
  test(
    'explicit progression uses exact caller events and captured session only',
    () async {
      final port = Port();
      final controller = AiConversationController(session: flow(port));
      addTearDown(controller.dispose);
      await start(controller);
      final first = controller.state.conversation!;
      expect(first.sessionId, sessionId);
      expect(controller.canStart, isFalse);
      expect(controller.canTurn, isTrue);
      const text = '  日\u3099😀  ';
      await controller.turn(textJa: text, clientEventId: turnId);
      expect(port.calls[0].body, {
        'scenario_id': owner,
        'jlpt_level': 'N4',
        'client_event_id': startId,
      });
      expect(port.calls[1].body, {
        'session_id': sessionId,
        'text_ja': text,
        'client_event_id': turnId,
      });
      final active = controller.state.conversation!;
      expect(active.messages.map((m) => m.sequenceNo), [0, 2]);
      expect(first.messages, hasLength(1));
      expect(() => active.messages.clear(), throwsUnsupportedError);
      await controller.finish(clientEventId: finishId);
      expect(port.calls[2].body, {
        'session_id': sessionId,
        'client_event_id': finishId,
      });
      expect(controller.state.phase, AiConversationPhase.ready);
      expect(
        controller.state.conversation!.phase,
        ConversationSessionPhase.finished,
      );
      expect(controller.state.conversation!.summary!.errors, isEmpty);
      expect(
        controller.state.conversation!.summary!.srsRecommendations,
        isEmpty,
      );
      expect(controller.canStart, isFalse);
      expect(controller.canTurn, isFalse);
      expect(controller.canFinish, isFalse);
      expect(controller.canRetry, isFalse);
      await start(controller, event: freshId);
      await controller.turn(textJa: 'new', clientEventId: freshId);
      await controller.finish(clientEventId: freshId);
      expect(port.calls, hasLength(3));
      expect(controller.state.failure!.code, AiTextErrorCode.syncConflict);
    },
  );
  test(
    'invalid phase UUID N3 and Unicode limits stay local without retained command',
    () async {
      final port = Port();
      final controller = AiConversationController(session: flow(port));
      addTearDown(controller.dispose);
      await controller.turn(textJa: 'a', clientEventId: turnId);
      expect(controller.state.failure!.code, AiTextErrorCode.syncConflict);
      await start(controller, event: 'private invalid event');
      expect(controller.state.failure!.code, AiTextErrorCode.validationFailure);
      await start(controller, level: AiTextLevel.n3);
      expect(controller.state.failure!.code, AiTextErrorCode.validationFailure);
      expect(port.calls, isEmpty);
      expect(controller.canStart, isTrue);
      await start(controller, level: AiTextLevel.n5);
      for (final text in ['', List.filled(5001, '😀').join()]) {
        await controller.turn(textJa: text, clientEventId: turnId);
        expect(
          controller.state.failure!.code,
          AiTextErrorCode.validationFailure,
        );
        expect(controller.canTurn, isTrue);
        expect(controller.canRetry, isFalse);
      }
      expect(port.calls, hasLength(1));
      await controller.turn(
        textJa: List.filled(5000, '😀').join(),
        clientEventId: turnId,
      );
      expect(port.calls, hasLength(2));
      expect(controller.state.conversation!.messages, hasLength(2));
    },
  );
  test(
    'duplicate taps port and readiness reentry cannot create another command',
    () async {
      final port = Port();
      AiConversationController? controller;
      final nested = <Future<void>>[];
      var reenter = false;
      late CapturedConversationSession captured;
      captured = flow(
        port,
        ready: () {
          final view = controller;
          if (reenter && view != null) {
            nested.add(start(view, event: freshId));
            expect(view.canStart, isFalse);
            final nestedState = view.state;
            if (captured.isCheckingAvailability) {
              expect(nestedState.phase, AiConversationPhase.unavailable);
              expect(nestedState.conversation, isNull);
            }
          }
          return true;
        },
      );
      controller = AiConversationController(session: captured);
      addTearDown(controller.dispose);
      final held = Completer<Object?>();
      port.reply = (_) {
        nested.add(controller!.finish(clientEventId: finishId));
        return held.future;
      };
      reenter = true;
      final first = start(controller);
      await settle();
      expect(controller.state.phase, AiConversationPhase.loading);
      await start(controller, event: freshId);
      await controller.turn(textJa: 'tap', clientEventId: turnId);
      await controller.retryPending();
      expect(port.calls, hasLength(1));
      reenter = false;
      held.complete(response('start_conversation'));
      await first;
      await Future.wait(nested);
      expect(port.calls, hasLength(1));
      expect(
        controller.state.conversation!.phase,
        ConversationSessionPhase.active,
      );
    },
  );
  for (final operation in AiConversationOperation.values) {
    for (final lateError in [false, true]) {
      test(
        'uncertain ${operation.name} lateError=$lateError retries exact DTO after drain',
        () async {
          final port = Port();
          final controller = AiConversationController(
            session: flow(port, timeout: const Duration(milliseconds: 25)),
          );
          addTearDown(controller.dispose);
          if (operation != AiConversationOperation.start) {
            await start(controller);
          }
          final before = controller.state.conversation;
          final held = Completer<Object?>();
          port.reply = (_) => held.future;
          final Future<void> first = switch (operation) {
            AiConversationOperation.start => start(controller),
            AiConversationOperation.turn => controller.turn(
              textJa: '  exact 日\u3099😀  ',
              clientEventId: turnId,
            ),
            AiConversationOperation.finish => controller.finish(
              clientEventId: finishId,
            ),
          };
          await first;
          expect(controller.state.phase, AiConversationPhase.error);
          expect(
            controller.state.failure!.code,
            AiTextErrorCode.networkUnavailable,
          );
          expect(controller.state.hasUnresolvedMutation, isTrue);
          expect(identical(controller.state.conversation, before), isTrue);
          expect(controller.state.operation, operation);
          expect(controller.canRetry, isFalse);
          final count = port.calls.length;
          final original = Map<String, Object>.from(port.calls.last.body);
          await controller.retryPending();
          await start(controller, event: freshId);
          await controller.turn(textJa: 'edited', clientEventId: freshId);
          await controller.finish(clientEventId: freshId);
          expect(port.calls, hasLength(count));
          if (lateError) {
            held.completeError(StateError('private late token/detail'));
          } else {
            held.complete(response(port.calls.last.operation));
          }
          await settle();
          controller.recheck();
          expect(controller.state.hasUnresolvedMutation, isTrue);
          expect(identical(controller.state.conversation, before), isTrue);
          expect(controller.canStart, isFalse);
          expect(controller.canTurn, isFalse);
          expect(controller.canFinish, isFalse);
          expect(controller.canRetry, isTrue);
          expect(port.calls, hasLength(count));
          port.reply = response;
          await controller.retryPending();
          expect(port.calls, hasLength(count + 1));
          expect(port.calls.last.body, original);
          expect(controller.state.hasUnresolvedMutation, isFalse);
          expect(controller.canRetry, isFalse);
          expect(
            controller.state.conversation!.phase,
            operation == AiConversationOperation.finish
                ? ConversationSessionPhase.finished
                : ConversationSessionPhase.active,
          );
          expect(
            controller.state.conversation!.messages,
            hasLength(operation == AiConversationOperation.turn ? 2 : 1),
          );
          await controller.retryPending();
          expect(port.calls, hasLength(count + 1));
        },
      );
    }
  }
  test(
    'retryable provider failure permits only explicit original event retry',
    () async {
      final port = Port()
        ..reply = (_) => {
          'code': 'PROVIDER_UNAVAILABLE',
          'message_vi': 'private detail',
          'retryable': true,
        };
      final controller = AiConversationController(session: flow(port));
      addTearDown(controller.dispose);
      await start(controller);
      expect(controller.state.failure!.messageVi, isNot(contains('private')));
      expect(controller.canRetry, isTrue);
      controller.recheck();
      await start(controller, event: freshId);
      expect(port.calls, hasLength(1));
      expect(controller.canRetry, isTrue);
      port.reply = response;
      await controller.retryPending();
      expect(port.calls, hasLength(2));
      expect(port.calls[0].body, port.calls[1].body);
    },
  );
  test(
    'local pending from shared transport can retry identical event without fresh ID',
    () async {
      final port = Port()..reply = (_) => throw const AiTextRequestPending();
      final controller = AiConversationController(session: flow(port));
      addTearDown(controller.dispose);
      await start(controller);
      expect(controller.state.phase, AiConversationPhase.pending);
      expect(controller.state.hasUnresolvedMutation, isTrue);
      expect(controller.canRetry, isTrue);
      expect(controller.canStart, isFalse);
      port.reply = response;
      await controller.retryPending();
      expect(port.calls, hasLength(2));
      expect(port.calls[0].body, port.calls[1].body);
    },
  );
  for (final malformed in [false, true]) {
    test(
      'nonretryable malformed=$malformed retains uncertainty without retry or reset',
      () async {
        final port = Port()
          ..reply = (_) => malformed
              ? {'private': 'malformed output'}
              : {
                  'code': 'SYNC_CONFLICT',
                  'message_vi': 'private SQL',
                  'retryable': true,
                };
        final captured = flow(port);
        final controller = AiConversationController(session: captured);
        await start(controller);
        expect(controller.state.phase, AiConversationPhase.error);
        expect(controller.state.failure!.retryable, isFalse);
        expect(controller.state.failure!.messageVi, isNot(contains('private')));
        expect(controller.state.hasUnresolvedMutation, isTrue);
        expect(controller.canRetry, isFalse);
        await controller.retryPending();
        await start(controller, event: freshId);
        expect(port.calls, hasLength(1));
        controller.dispose();
        expect(captured.isCurrent, isTrue);
        expect(captured.hasUnresolvedMutation, isTrue);
        final remount = AiConversationController(session: captured);
        addTearDown(remount.dispose);
        expect(remount.state.phase, AiConversationPhase.pending);
        expect(remount.canRetry, isFalse);
        expect(remount.canStart, isFalse);
        await start(remount, event: freshId);
        expect(port.calls, hasLength(1));
      },
    );
  }
  for (final lateError in [false, true]) {
    test(
      'readiness loss and A-B-A clear projection and fence late error=$lateError',
      () async {
        final auth = Auth();
        final original = auth.currentSession;
        final port = Port();
        final captured = flow(port, auth: auth);
        final controller = AiConversationController(session: captured);
        addTearDown(controller.dispose);
        await start(controller);
        final held = Completer<Object?>();
        port.reply = (_) => held.future;
        final request = controller.turn(
          textJa: 'private',
          clientEventId: turnId,
        );
        await settle();
        auth.currentSession = ReviewSession(userId: owner);
        expect(controller.state.phase, AiConversationPhase.unavailable);
        expect(controller.state.conversation, isNull);
        expect(controller.state.operation, isNull);
        expect(controller.state.failure, isNull);
        auth.currentSession = original;
        if (lateError) {
          held.completeError(StateError('private late error'));
        } else {
          held.complete(response('conversation_turn'));
        }
        await request;
        expect(controller.state.conversation, isNull);
        expect(controller.canRetry, isFalse);
        expect(controller.canStart, isFalse);
        expect(captured.isCurrent, isFalse);
        expect(port.calls, hasLength(2));
      },
    );
  }
  test(
    'getter failure 401 and readiness false permanently redact view',
    () async {
      for (final mode in ['getter', 'readiness', '401']) {
        var ready = true;
        var broken = false;
        final port = Port();
        final controller = AiConversationController(
          session: flow(
            port,
            ready: () {
              if (broken) throw StateError('private getter/token');
              return ready;
            },
          ),
        );
        await start(controller);
        if (mode == 'getter') broken = true;
        if (mode == 'readiness') ready = false;
        if (mode == '401') {
          port.reply = (_) => {
            'code': 'UNAUTHORIZED',
            'message_vi': 'private token',
            'retryable': true,
          };
          await controller.turn(textJa: 'private', clientEventId: turnId);
        }
        expect(controller.state.phase, AiConversationPhase.unavailable);
        expect(controller.state.conversation, isNull);
        broken = false;
        ready = true;
        controller.recheck();
        expect(controller.canStart, isFalse);
        expect(controller.canRetry, isFalse);
        controller.dispose();
      }
    },
  );
  test(
    'void hints read current state and stream errors closure invalidate borrowed view',
    () async {
      for (final close in [false, true]) {
        final port = Port();
        final captured = flow(port);
        final hints = StreamController<void>.broadcast();
        final controller = AiConversationController(
          session: captured,
          availabilityChanges: hints.stream,
        );
        final seen = <AiConversationPhase>[];
        final listener = controller.changes.listen(
          (_) => seen.add(controller.state.phase),
        );
        await start(controller);
        hints.add(null);
        await settle();
        expect(seen, contains(AiConversationPhase.ready));
        expect(port.calls, hasLength(1));
        if (close) {
          await hints.close();
        } else {
          hints.addError(StateError('private stream'));
        }
        await settle();
        expect(controller.state.phase, AiConversationPhase.unavailable);
        expect(captured.isCurrent, isTrue);
        expect(captured.snapshot.messages, hasLength(1));
        await listener.cancel();
        controller.dispose();
        if (!close) await hints.close();
      }
    },
  );
  test(
    'disposal with paused listener clears view but retains borrowed finished flow',
    () async {
      final port = Port();
      final captured = flow(port);
      final controller = AiConversationController(session: captured);
      await start(controller);
      await controller.finish(clientEventId: finishId);
      final paused = controller.changes.listen((_) {});
      paused.pause();
      controller.dispose();
      controller.dispose();
      expect(controller.state.conversation, isNull);
      expect(captured.isCurrent, isTrue);
      expect(captured.snapshot.phase, ConversationSessionPhase.finished);
      final remount = AiConversationController(session: captured);
      addTearDown(remount.dispose);
      expect(
        remount.state.conversation!.phase,
        ConversationSessionPhase.finished,
      );
      expect(remount.canStart, isFalse);
      await start(remount, event: freshId);
      expect(port.calls, hasLength(2));
      await paused.cancel();
    },
  );
  test(
    'externally held event is not replaced or automatically replayed by new view',
    () async {
      final port = Port();
      final captured = flow(port);
      final held = Completer<Object?>();
      port.reply = (_) => held.future;
      final external = captured.start(
        StartConversationRequest(
          scenarioId: owner,
          level: AiTextLevel.n4,
          clientEventId: startId,
        ),
      );
      await settle();
      final controller = AiConversationController(session: captured);
      addTearDown(controller.dispose);
      expect(controller.canStart, isFalse);
      await start(controller, event: freshId);
      expect(port.calls, hasLength(1));
      held.complete(response('start_conversation'));
      await external;
      controller.recheck();
      expect(
        controller.state.conversation!.phase,
        ConversationSessionPhase.active,
      );
      expect(controller.canTurn, isTrue);
      expect(controller.canRetry, isFalse);
      expect(port.calls, hasLength(1));
    },
  );
  test(
    'disposed timeout view cannot recover by remounting or accept late success',
    () async {
      final port = Port();
      final captured = flow(port, timeout: const Duration(milliseconds: 25));
      final first = AiConversationController(session: captured);
      final held = Completer<Object?>();
      port.reply = (_) => held.future;
      await start(first);
      expect(first.state.hasUnresolvedMutation, isTrue);
      first.dispose();
      expect(first.state.conversation, isNull);
      expect(captured.isCurrent, isTrue);
      final remount = AiConversationController(session: captured);
      addTearDown(remount.dispose);
      held.complete(response('start_conversation'));
      await settle();
      remount.recheck();
      expect(first.state.phase, AiConversationPhase.unavailable);
      expect(remount.state.hasUnresolvedMutation, isTrue);
      expect(
        remount.state.conversation!.phase,
        ConversationSessionPhase.notStarted,
      );
      expect(remount.canStart, isFalse);
      expect(remount.canRetry, isFalse);
      await remount.retryPending();
      await start(remount, event: freshId);
      expect(port.calls, hasLength(1));
    },
  );
}
