// TEST ONLY owned-session hints and injected ports; no HTTP/hosted receipts.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_mutation.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

const id = '11111111-1111-4111-8111-111111111111';
const event = '22222222-2222-4222-8222-222222222222';
late Map<String, Object?> fixtures;

final class Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(userId: id);
}

final class CallbackAuth implements ReviewAuth {
  final ReviewSession session = ReviewSession(userId: id);
  void Function()? beforeRead;
  @override
  ReviewSession get currentSession {
    beforeRead?.call();
    return session;
  }
}

final class Port implements ConversationMutationTransport {
  final calls =
      <({ReviewSession session, String operation, Map<String, Object> body})>[];
  FutureOr<Object?> Function(String)? reply;
  @override
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String operation,
    required Map<String, Object> body,
  }) {
    calls.add((session: capturedSession, operation: operation, body: body));
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
void main() {
  setUpAll(() {
    fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  test(
    'three typed mutations send exact frozen requests and cache success without redispatch',
    () async {
      final auth = Auth();
      final port = Port();
      final start = CapturedConversationMutation.start(
        auth: auth,
        transport: port,
        isReady: () => true,
        request: StartConversationRequest.fromJson(
          fixtures['start_conversation_request'],
        ),
      );
      final turn = CapturedConversationMutation.turn(
        auth: auth,
        transport: port,
        isReady: () => true,
        request: ConversationTurnRequest.fromJson(
          fixtures['conversation_turn_request'],
        ),
      );
      final finish = CapturedConversationMutation.finish(
        auth: auth,
        transport: port,
        isReady: () => true,
        request: FinishConversationRequest.fromJson(
          fixtures['finish_conversation_request'],
        ),
      );
      final a = await start.submit();
      expect(a.toJson(), fixtures['start_conversation_response']);
      expect(identical(a, await start.submit()), isTrue);
      expect(
        (await turn.submit()).toJson(),
        fixtures['conversation_turn_response'],
      );
      expect(
        (await finish.submit()).toJson(),
        fixtures['finish_conversation_response'],
      );
      expect(port.calls, hasLength(3));
      for (final call in port.calls) {
        expect(call.body, fixtures['${call.operation}_request']);
        expect(identical(call.session, auth.currentSession), isTrue);
        expect(() => call.body['client_event_id'] = id, throwsUnsupportedError);
      }
    },
  );
  test(
    'explicit retry keeps exact accepted event body and fixed safe failures',
    () async {
      final auth = Auth();
      final port = Port();
      final request = ConversationTurnRequest(
        sessionId: id,
        clientEventId: event,
        textJa: '  日\u3099  ',
      );
      final op = CapturedConversationMutation.turn(
        auth: auth,
        transport: port,
        isReady: () => true,
        request: request,
      );
      port.reply = (_) => throw const AiTextFailure(
        AiTextErrorCode.providerUnavailable,
        retryable: true,
      );
      await expectLater(
        op.submit(),
        throwsA(code(AiTextErrorCode.providerUnavailable)),
      );
      expect(port.calls, hasLength(1));
      expect(op.isBusy, isFalse);
      port.reply = null;
      await op.submit();
      expect(port.calls, hasLength(2));
      expect(identical(port.calls.first.body, port.calls.last.body), isTrue);
      expect(port.calls.last.body, request.toJson());
    },
  );
  test('singleflight registers before synchronous port reentry', () async {
    final auth = Auth();
    final port = Port();
    final held = Completer<Object?>();
    final op = CapturedConversationMutation.turn(
      auth: auth,
      transport: port,
      isReady: () => true,
      request: ConversationTurnRequest(
        sessionId: id,
        clientEventId: event,
        textJa: '日',
      ),
    );
    Future<void>? nested;
    port.reply = (_) {
      nested = expectLater(op.submit(), throwsA(isA<AiTextRequestPending>()));
      return held.future;
    };
    final first = op.submit();
    await nested;
    expect(op.isBusy, isTrue);
    await expectLater(op.submit(), throwsA(isA<AiTextRequestPending>()));
    expect(port.calls, hasLength(1));
    held.complete(fixtures['conversation_turn_response']);
    await first;
    expect(op.isBusy, isFalse);
  });
  for (final lateError in [false, true]) {
    test(
      'timeout holds actual drain and late response cannot cache success error=$lateError',
      () async {
        final auth = Auth();
        final port = Port();
        final held = Completer<Object?>();
        port.reply = (_) => held.future;
        final op = CapturedConversationMutation.turn(
          auth: auth,
          transport: port,
          isReady: () => true,
          request: ConversationTurnRequest(
            sessionId: id,
            clientEventId: event,
            textJa: '日',
          ),
          timeout: const Duration(milliseconds: 5),
        );
        await expectLater(
          op.submit(),
          throwsA(code(AiTextErrorCode.networkUnavailable)),
        );
        expect(op.isBusy, isTrue);
        await expectLater(op.submit(), throwsA(isA<AiTextRequestPending>()));
        expect(port.calls, hasLength(1));
        if (lateError) {
          held.completeError(StateError('PRIVATE_LATE'));
        } else {
          held.complete(fixtures['conversation_turn_response']);
        }
        await Future<void>.delayed(Duration.zero);
        expect(op.isBusy, isFalse);
        expect(port.calls, hasLength(1));
        port.reply = null;
        await op.submit();
        expect(port.calls, hasLength(2));
        expect(identical(port.calls.first.body, port.calls.last.body), isTrue);
      },
    );
  }
  for (final lateError in [false, true]) {
    test(
      'account identity replacement rejects late result and returning A cannot revive error=$lateError',
      () async {
        final auth = Auth();
        final original = auth.currentSession;
        final port = Port();
        final held = Completer<Object?>();
        port.reply = (_) => held.future;
        final op = CapturedConversationMutation.start(
          auth: auth,
          transport: port,
          isReady: () => true,
          request: StartConversationRequest(
            scenarioId: id,
            level: AiTextLevel.n4,
            clientEventId: event,
          ),
        );
        final rejected = expectLater(
          op.submit(),
          throwsA(code(AiTextErrorCode.unauthorized)),
        );
        auth.currentSession = ReviewSession(userId: event);
        expect(op.isCurrent, isFalse);
        auth.currentSession = original;
        if (lateError) {
          held.completeError(StateError('PRIVATE_LATE'));
        } else {
          held.complete(fixtures['start_conversation_response']);
        }
        await rejected;
        await expectLater(
          op.submit(),
          throwsA(code(AiTextErrorCode.unauthorized)),
        );
        expect(port.calls, hasLength(1));
      },
    );
  }
  test(
    'readiness loss and explicit revoke invalidate cached success permanently',
    () async {
      final auth = Auth();
      final port = Port();
      var ready = true;
      final op = CapturedConversationMutation.finish(
        auth: auth,
        transport: port,
        isReady: () => ready,
        request: FinishConversationRequest(sessionId: id, clientEventId: event),
      );
      await op.submit();
      ready = false;
      expect(op.isCurrent, isFalse);
      ready = true;
      await expectLater(
        op.submit(),
        throwsA(code(AiTextErrorCode.unauthorized)),
      );
      expect(port.calls, hasLength(1));
      final second = CapturedConversationMutation.finish(
        auth: auth,
        transport: port,
        isReady: () => true,
        request: FinishConversationRequest(sessionId: id, clientEventId: event),
      );
      second.revoke();
      await expectLater(
        second.submit(),
        throwsA(code(AiTextErrorCode.unauthorized)),
      );
      expect(port.calls, hasLength(1));
    },
  );
  test(
    'unauthorized server error permanently revokes and raw wire message is discarded',
    () async {
      final auth = Auth();
      final port = Port()
        ..reply = (_) => {
          'code': 'UNAUTHORIZED',
          'message_vi': 'PRIVATE_TOKEN',
          'retryable': true,
        };
      final op = CapturedConversationMutation.turn(
        auth: auth,
        transport: port,
        isReady: () => true,
        request: ConversationTurnRequest(
          sessionId: id,
          clientEventId: event,
          textJa: '日',
        ),
      );
      try {
        await op.submit();
        fail('expected error');
      } on AiTextFailure catch (e) {
        expect(e.code, AiTextErrorCode.unauthorized);
        expect(e.retryable, isFalse);
        expect(e.messageVi, isNot(contains('PRIVATE')));
        expect(e.toString(), isNot(contains('PRIVATE')));
      }
      port.reply = null;
      await expectLater(
        op.submit(),
        throwsA(code(AiTextErrorCode.unauthorized)),
      );
      expect(port.calls, hasLength(1));
    },
  );
  test(
    'malformed response unknown exceptions and invalid errors stay fixed and uncached',
    () async {
      final auth = Auth();
      final port = Port();
      final op = CapturedConversationMutation.finish(
        auth: auth,
        transport: port,
        isReady: () => true,
        request: FinishConversationRequest(sessionId: id, clientEventId: event),
      );
      for (final bad in <Object?>[
        null,
        {'PRIVATE': true},
        {'code': 'SYNC_CONFLICT', 'message_vi': 'PRIVATE', 'retryable': 'yes'},
        {
          'code': 'INTERNAL_ERROR',
          'message_vi': 'PRIVATE',
          'retryable': false,
          'scores': <String, Object?>{},
        },
      ]) {
        port.reply = (_) => bad;
        await expectLater(
          op.submit(),
          throwsA(code(AiTextErrorCode.internalError)),
        );
      }
      port.reply = (_) => throw StateError('PRIVATE_HTTP');
      await expectLater(
        op.submit(),
        throwsA(code(AiTextErrorCode.internalError)),
      );
      port.reply = null;
      await op.submit();
      expect(port.calls, hasLength(6));
    },
  );
  test(
    'nontransient errors never advertise retryable and getters fail closed',
    () async {
      final auth = Auth();
      final port = Port()
        ..reply = (_) => throw const AiTextFailure(
          AiTextErrorCode.syncConflict,
          retryable: true,
        );
      final op = CapturedConversationMutation.finish(
        auth: auth,
        transport: port,
        isReady: () => true,
        request: FinishConversationRequest(sessionId: id, clientEventId: event),
      );
      try {
        await op.submit();
        fail('expected error');
      } on AiTextFailure catch (e) {
        expect(e.code, AiTextErrorCode.syncConflict);
        expect(e.retryable, isFalse);
      }
      var failReady = false;
      final gated = CapturedConversationMutation.finish(
        auth: auth,
        transport: port,
        isReady: () {
          if (failReady) throw StateError('PRIVATE');
          return true;
        },
        request: FinishConversationRequest(sessionId: id, clientEventId: event),
      );
      failReady = true;
      await expectLater(
        gated.submit(),
        throwsA(code(AiTextErrorCode.unauthorized)),
      );
      expect(port.calls, hasLength(1));
    },
  );
  test(
    'no-session unavailable readiness and invalid timeout construct no dispatch',
    () {
      final auth = Auth();
      final port = Port();
      final request = FinishConversationRequest(
        sessionId: id,
        clientEventId: event,
      );
      for (final timeout in [Duration.zero, const Duration(seconds: 16)]) {
        expect(
          () => CapturedConversationMutation.finish(
            auth: auth,
            transport: port,
            isReady: () => true,
            request: request,
            timeout: timeout,
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => CapturedConversationMutation.finish(
          auth: auth,
          transport: port,
          isReady: () => false,
          request: request,
        ),
        throwsA(code(AiTextErrorCode.unauthorized)),
      );
      auth.currentSession = null;
      expect(
        () => CapturedConversationMutation.finish(
          auth: auth,
          transport: port,
          isReady: () => true,
          request: request,
        ),
        throwsA(code(AiTextErrorCode.unauthorized)),
      );
      expect(port.calls, isEmpty);
    },
  );
  test(
    'new same-user identity never inherits the captured operation',
    () async {
      final auth = Auth();
      final port = Port();
      final op = CapturedConversationMutation.finish(
        auth: auth,
        transport: port,
        isReady: () => true,
        request: FinishConversationRequest(sessionId: id, clientEventId: event),
      );
      auth.currentSession = ReviewSession(userId: id);
      await expectLater(
        op.submit(),
        throwsA(code(AiTextErrorCode.unauthorized)),
      );
      expect(port.calls, isEmpty);
    },
  );
  for (final afterResponse in [false, true]) {
    for (final replaceSession in [false, true]) {
      test('last readiness retires $afterResponse/$replaceSession', () async {
        final auth = Auth();
        final captured = auth.currentSession;
        final port = Port();
        var armed = false;
        var checks = 0;
        late CapturedConversationMutation<Object> op;
        op = CapturedConversationMutation.finish(
          auth: auth,
          transport: port,
          isReady: () {
            if (armed && ++checks == 2) {
              if (replaceSession) {
                auth.currentSession = ReviewSession(userId: id);
              } else {
                op.revoke();
              }
            }
            return true;
          },
          request: FinishConversationRequest(
            sessionId: id,
            clientEventId: event,
          ),
        );
        if (afterResponse) {
          port.reply = (_) {
            armed = true;
            return fixtures['finish_conversation_response'];
          };
        } else {
          armed = true;
        }
        await expectLater(
          op.submit(),
          throwsA(code(AiTextErrorCode.unauthorized)),
        );
        expect(checks, 2);
        expect(port.calls, hasLength(afterResponse ? 1 : 0));
        expect(op.isBusy, isFalse);
        armed = false;
        auth.currentSession = captured;
        expect(op.isCurrent, isFalse);
        await expectLater(
          op.submit(),
          throwsA(code(AiTextErrorCode.unauthorized)),
        );
        expect(port.calls, hasLength(afterResponse ? 1 : 0));
      });
    }
  }

  for (final authGetter in [false, true]) {
    test('standalone readiness blocks submit auth=$authGetter', () async {
      final auth = CallbackAuth();
      final port = Port();
      var armed = false;
      var nestedCalls = 0;
      Future<void>? checked;
      late CapturedConversationMutation<Object> op;
      void reenter() {
        if (!armed) return;
        armed = false;
        nestedCalls++;
        expect(op.isCurrent, isFalse);
        checked = expectLater(
          op.submit(),
          throwsA(isA<AiTextRequestPending>()),
        );
      }

      op = CapturedConversationMutation.finish(
        auth: auth,
        transport: port,
        isReady: () {
          if (!authGetter) reenter();
          return true;
        },
        request: FinishConversationRequest(sessionId: id, clientEventId: event),
      );
      if (authGetter) auth.beforeRead = reenter;
      armed = true;
      expect(op.isCurrent, isTrue);
      await checked!;
      expect(nestedCalls, 1);
      expect(port.calls, isEmpty);
      expect(op.isBusy, isFalse);
      final result = await op.submit();
      expect(port.calls, hasLength(1));
      armed = true;
      expect(op.isCurrent, isTrue);
      await checked!;
      expect(nestedCalls, 2);
      expect(port.calls, hasLength(1));
      expect(await op.submit(), same(result));
      expect(port.calls, hasLength(1));
    });
  }
}
