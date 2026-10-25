// TEST ONLY ports; no disk persistence, hosted receipt or route activation.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_session.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/application/ai_conversation_controller.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'captured_conversation_session_test.dart' as f;

void main() {
  setUpAll(() {
    f.fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  for (final operation in [
    'start_conversation',
    'conversation_turn',
    'finish_conversation',
  ]) {
    test(
      'retained original retries exact $operation once without view or new event',
      () async {
        final auth = f.Auth();
        final port = f.Port();
        final flow = CapturedConversationSession(
          auth: auth,
          transport: port,
          isReady: () => true,
        );
        if (operation != 'start_conversation') await flow.start(f.start());
        port.reply = (_) => {
          'code': 'PROVIDER_UNAVAILABLE',
          'message_vi': 'PRIVATE',
          'retryable': true,
        };
        Future<void> submit() async {
          switch (operation) {
            case 'start_conversation':
              await flow.start(f.start());
            case 'conversation_turn':
              await flow.turn(f.turn(text: '  日\u3099😀  '));
            case 'finish_conversation':
              await flow.finish(f.finish());
          }
        }

        await expectLater(
          submit(),
          throwsA(f.code(AiTextErrorCode.providerUnavailable)),
        );
        final count = port.calls.length;
        final original = port.calls.last;
        expect(flow.canRetryRetained, isTrue);
        expect(flow.hasUnresolvedMutation, isTrue);
        expect(port.calls, hasLength(count));
        port.reply = f.response;
        await flow.retryRetained();
        expect(port.calls, hasLength(count + 1));
        expect(port.calls.last.operation, original.operation);
        expect(port.calls.last.body, original.body);
        expect(port.calls.last.session, same(original.session));
        expect(flow.canRetryRetained, isFalse);
        expect(flow.hasUnresolvedMutation, isFalse);
        expect(
          flow.snapshot.phase,
          operation == 'finish_conversation'
              ? ConversationSessionPhase.finished
              : ConversationSessionPhase.active,
        );
        await flow.retryRetained();
        expect(port.calls, hasLength(count + 1));
      },
    );
  }
  test(
    'retained host retry survives disposed view while legacy remount stays blocked',
    () async {
      final port = f.Port()
        ..reply = (_) => {
          'code': 'PROVIDER_UNAVAILABLE',
          'message_vi': 'PRIVATE',
          'retryable': true,
        };
      final flow = CapturedConversationSession(
        auth: f.Auth(),
        transport: port,
        isReady: () => true,
      );
      final view = AiConversationController(session: flow);
      await view.start(
        scenarioId: f.owner,
        level: AiTextLevel.n4,
        clientEventId: f.startEvent,
      );
      view.dispose();
      final next = AiConversationController(session: flow);
      expect(next.canRetry, isFalse);
      expect(next.canStart, isFalse);
      expect(flow.canRetryRetained, isTrue);
      port.reply = f.response;
      await flow.retryRetained();
      expect(port.calls, hasLength(2));
      expect(next.state.conversation!.phase, ConversationSessionPhase.active);
      next.dispose();
      expect(flow.isCurrent, isTrue);
    },
  );
  test(
    'same-user replacement and A B A revoke retained command without dispatch',
    () async {
      final auth = f.Auth();
      final original = auth.currentSession;
      final port = f.Port()
        ..reply = (_) => {
          'code': 'NETWORK_UNAVAILABLE',
          'message_vi': 'PRIVATE',
          'retryable': true,
        };
      final flow = CapturedConversationSession(
        auth: auth,
        transport: port,
        isReady: () => true,
      );
      await expectLater(
        flow.start(f.start()),
        throwsA(f.code(AiTextErrorCode.networkUnavailable)),
      );
      auth.currentSession = ReviewSession(userId: original!.userId);
      expect(flow.canRetryRetained, isFalse);
      auth.currentSession = original;
      await flow.retryRetained();
      expect(flow.canRetryRetained, isFalse);
      expect(port.calls, hasLength(1));
      expect(flow.snapshot.phase, ConversationSessionPhase.revoked);
    },
  );
  test('nonretryable failure never gains retained retry authority', () async {
    final port = f.Port()
      ..reply = (_) => {
        'code': 'SYNC_CONFLICT',
        'message_vi': 'PRIVATE',
        'retryable': true,
      };
    final flow = CapturedConversationSession(
      auth: f.Auth(),
      transport: port,
      isReady: () => true,
    );
    await expectLater(
      flow.start(f.start()),
      throwsA(f.code(AiTextErrorCode.syncConflict)),
    );
    expect(flow.hasUnresolvedMutation, isTrue);
    expect(flow.canRetryRetained, isFalse);
    await flow.retryRetained();
    expect(port.calls, hasLength(1));
  });
  test(
    'foreign pending event cannot replace retained original command',
    () async {
      final port = f.Port()
        ..reply = (_) => {
          'code': 'NETWORK_UNAVAILABLE',
          'message_vi': 'PRIVATE',
          'retryable': true,
        };
      final flow = CapturedConversationSession(
        auth: f.Auth(),
        transport: port,
        isReady: () => true,
      );
      await expectLater(
        flow.start(f.start()),
        throwsA(f.code(AiTextErrorCode.networkUnavailable)),
      );
      await expectLater(
        flow.start(f.start(f.otherEvent)),
        throwsA(isA<AiTextRequestPending>()),
      );
      expect(flow.canRetryRetained, isTrue);
      port.reply = f.response;
      await flow.retryRetained();
      expect(port.calls, hasLength(2));
      expect(port.calls.last.body['client_event_id'], f.startEvent);
    },
  );
  test(
    'timed-out command waits for actual wire drain before retained retry',
    () async {
      final held = Completer<Object?>();
      final port = f.Port()..reply = (_) => held.future;
      final flow = CapturedConversationSession(
        auth: f.Auth(),
        transport: port,
        isReady: () => true,
        timeout: const Duration(milliseconds: 10),
      );
      await expectLater(
        flow.start(f.start()),
        throwsA(f.code(AiTextErrorCode.networkUnavailable)),
      );
      expect(flow.canRetryRetained, isFalse);
      await flow.retryRetained();
      expect(port.calls, hasLength(1));
      held.completeError(StateError('PRIVATE_LATE'));
      await f.settle();
      expect(flow.canRetryRetained, isTrue);
      port.reply = f.response;
      await flow.retryRetained();
      expect(port.calls, hasLength(2));
      expect(flow.canRetryRetained, isFalse);
    },
  );
  test(
    'reentrant readiness and concurrent host retry cannot dispatch twice',
    () async {
      final port = f.Port()
        ..reply = (_) => {
          'code': 'NETWORK_UNAVAILABLE',
          'message_vi': 'PRIVATE',
          'retryable': true,
        };
      var probe = false;
      late CapturedConversationSession flow;
      flow = CapturedConversationSession(
        auth: f.Auth(),
        transport: port,
        isReady: () {
          if (probe) unawaited(flow.retryRetained());
          return true;
        },
      );
      await expectLater(
        flow.start(f.start()),
        throwsA(f.code(AiTextErrorCode.networkUnavailable)),
      );
      probe = true;
      expect(flow.canRetryRetained, isTrue);
      await f.settle();
      expect(port.calls, hasLength(1));
      probe = false;
      final held = Completer<Object?>();
      port.reply = (_) => held.future;
      final first = flow.retryRetained();
      await flow.retryRetained();
      expect(port.calls, hasLength(2));
      expect(flow.canRetryRetained, isFalse);
      held.complete(f.response('start_conversation'));
      await first;
      expect(flow.hasUnresolvedMutation, isFalse);
      expect(port.calls, hasLength(2));
    },
  );
}
