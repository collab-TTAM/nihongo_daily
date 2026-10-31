// TEST ONLY ports. No SDK/HTTP or hosted receipt proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/application/ai_text_runtime_owner.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_mutation.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_session.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

const id = '11111111-1111-4111-8111-111111111111';
late Map<String, Object?> fixture;

final class Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(userId: id);
}

final class Port
    implements OwnedAiTextTransport, ConversationMutationTransport {
  Port(this.ready);
  final bool Function() ready;
  bool revoked = false;
  int calls = 0, closes = 0;
  Completer<Object?>? held;
  Completer<void>? drain;
  bool badClose = false;
  @override
  bool get isCurrent => !revoked && ready();
  @override
  void revoke() {
    revoked = true;
  }

  @override
  Future<void> close() async {
    closes++;
    revoke();
    await drain?.future;
    if (badClose) throw StateError('private cleanup');
  }

  @override
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String operation,
    required Map<String, Object> body,
  }) async {
    calls++;
    return held?.future ?? fixture['${operation}_response'];
  }

  @override
  Future<Object?> tutorExplain({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) async => fixture['tutor_explain_response'];
  @override
  Future<Object?> correctSentence({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) async => fixture['correct_sentence_response'];
}

void main() {
  setUpAll(() {
    fixture =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  test(
    'one retained conversation shares owner transport and completed session cannot reset',
    () async {
      final auth = Auth();
      final ports = <Port>[];
      final generation = AiTextGeneration();
      final owner = AiTextRuntimeOwner(
        createTransport: ({required auth, required isReady}) {
          final p = Port(isReady);
          ports.add(p);
          return p;
        },
      );
      CapturedConversationSession? acquire() => owner.acquireConversation(
        auth: auth,
        generation: generation,
        isReady: () => true,
      );
      final flow = acquire()!;
      expect(identical(acquire(), flow), isTrue);
      expect(
        owner.acquire(auth: auth, generation: generation, isReady: () => true),
        isNotNull,
      );
      await flow.start(
        StartConversationRequest.fromJson(
          fixture['start_conversation_request'],
        ),
      );
      await flow.finish(
        FinishConversationRequest.fromJson(
          fixture['finish_conversation_request'],
        ),
      );
      expect(identical(acquire(), flow), isTrue);
      expect(flow.snapshot.phase, ConversationSessionPhase.finished);
      expect(ports, hasLength(1));
      expect(ports.single.calls, 2);
      await owner.close();
      expect(flow.snapshot.messages, isEmpty);
      expect(ports.single.closes, 1);
    },
  );
  test(
    'invalidate clears conversation synchronously and fresh generation waits for drain',
    () async {
      final auth = Auth();
      final ports = <Port>[];
      final owner = AiTextRuntimeOwner(
        createTransport: ({required auth, required isReady}) {
          final p = Port(isReady);
          ports.add(p);
          return p;
        },
      );
      final oldGen = AiTextGeneration();
      final next = AiTextGeneration();
      CapturedConversationSession? get(AiTextGeneration g) => owner
          .acquireConversation(auth: auth, generation: g, isReady: () => true);
      final old = get(oldGen)!;
      await old.start(
        StartConversationRequest.fromJson(
          fixture['start_conversation_request'],
        ),
      );
      ports.single.drain = Completer<void>();
      owner.invalidate();
      expect(old.snapshot.messages, isEmpty);
      expect(owner.isDraining, isTrue);
      expect(get(next), isNull);
      expect(get(oldGen), isNull);
      expect(ports, hasLength(1));
      ports.single.drain!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(get(oldGen), isNull);
      final fresh = get(next)!;
      expect(identical(old, fresh), isFalse);
      expect(fresh.snapshot.phase, ConversationSessionPhase.notStarted);
      expect(ports, hasLength(2));
      await owner.close();
    },
  );
  test(
    'same-user identity loss permanently revokes retained conversation',
    () async {
      final auth = Auth();
      final owner = AiTextRuntimeOwner(
        createTransport: ({required auth, required isReady}) => Port(isReady),
      );
      final g = AiTextGeneration();
      final flow = owner.acquireConversation(
        auth: auth,
        generation: g,
        isReady: () => true,
      )!;
      await flow.start(
        StartConversationRequest.fromJson(
          fixture['start_conversation_request'],
        ),
      );
      auth.currentSession = ReviewSession(userId: id);
      owner.check();
      expect(flow.snapshot.messages, isEmpty);
      expect(
        owner.acquireConversation(
          auth: auth,
          generation: g,
          isReady: () => true,
        ),
        isNull,
      );
      await owner.close();
    },
  );
  test(
    'readiness reentry and reentrant close cannot publish an orphan conversation',
    () async {
      final auth = Auth();
      late AiTextRuntimeOwner owner;
      var entered = false;
      Future<void>? closing;
      owner = AiTextRuntimeOwner(
        createTransport: ({required auth, required isReady}) => Port(isReady),
      );
      final g = AiTextGeneration();
      final flow = owner.acquireConversation(
        auth: auth,
        generation: g,
        isReady: () {
          if (!entered) {
            entered = true;
            expect(
              owner.acquireConversation(
                auth: auth,
                generation: g,
                isReady: () => true,
              ),
              isNull,
            );
            closing = owner.close();
          }
          return true;
        },
      );
      expect(flow, isNull);
      await closing;
      expect(
        owner.acquireConversation(
          auth: auth,
          generation: AiTextGeneration(),
          isReady: () => true,
        ),
        isNull,
      );
    },
  );
  test(
    'failed shared cleanup cannot authorize replacement conversation',
    () async {
      final auth = Auth();
      late Port port;
      final owner = AiTextRuntimeOwner(
        createTransport: ({required auth, required isReady}) =>
            port = Port(isReady),
      );
      final flow = owner.acquireConversation(
        auth: auth,
        generation: AiTextGeneration(),
        isReady: () => true,
      )!;
      port.badClose = true;
      owner.invalidate();
      await Future<void>.delayed(Duration.zero);
      expect(flow.isCurrent, isFalse);
      expect(owner.isFailed, isTrue);
      expect(
        owner.acquireConversation(
          auth: auth,
          generation: AiTextGeneration(),
          isReady: () => true,
        ),
        isNull,
      );
      await expectLater(owner.close(), throwsA(isA<AiTextFailure>()));
    },
  );
  test(
    'unresolved conversation factory cannot create a replacement or new event',
    () async {
      final auth = Auth();
      late Port port;
      var allocations = 0;
      final owner = AiTextRuntimeOwner(
        createTransport: ({required auth, required isReady}) {
          allocations++;
          return port = Port(isReady);
        },
      );
      final generation = AiTextGeneration();
      CapturedConversationSession? acquire() => owner.acquireConversation(
        auth: auth,
        generation: generation,
        isReady: () => true,
      );
      final flow = acquire()!;
      port.held = Completer<Object?>();
      final request = StartConversationRequest.fromJson(
        fixture['start_conversation_request'],
      );
      final sending = flow.start(request);
      expect(identical(acquire(), flow), isTrue);
      final failed = expectLater(sending, throwsA(isA<AiTextFailure>()));
      port.held!.completeError(StateError('TEST_ONLY_PRIVATE_FAILURE'));
      await failed;
      expect(flow.hasUnresolvedMutation, isTrue);
      expect(identical(acquire(), flow), isTrue);
      await expectLater(
        flow.start(
          StartConversationRequest(
            scenarioId: request.scenarioId,
            level: request.level,
            clientEventId: '33333333-3333-4333-8333-333333333333',
          ),
        ),
        throwsA(isA<AiTextRequestPending>()),
      );
      expect(allocations, 1);
      expect(port.calls, 1);
      port.held = null;
      await flow.start(request);
      expect(flow.hasUnresolvedMutation, isFalse);
      expect(port.calls, 2);
      await owner.close();
    },
  );
}
