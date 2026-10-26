// TEST ONLY ports and original contract fixture. No live Auth/provider proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/application/ai_text_runtime_owner.dart';
import 'package:nihongo_daily/features/ai/data/receipt_guarded_ai_transport.dart';
import 'package:nihongo_daily/features/ai/data/conversation_receipt_store.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_mutation.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_session.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_scenarios.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_reference.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

const owner = 'a1000000-0000-4000-8000-000000000001';
const event = 'b1000000-0000-4000-8000-000000000001';
final scope = ConversationReceiptScope(
  projectUrl: 'https://owned.supabase.invalid',
  ownerId: owner,
);
final start = StartConversationRequest(
  scenarioId: owner,
  level: AiTextLevel.n5,
  clientEventId: event,
);
Matcher code(AiTextErrorCode c) => isA<AiTextFailure>()
    .having((e) => e.code, 'code', c)
    .having((e) => e.toString().contains('PRIVATE'), 'safe', false);

final class Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(userId: owner);
}

final class Backend implements SecureConversationReceiptBackend {
  Object? value;
  bool fail = false;
  Completer<void>? wait;
  final entered = Completer<void>();
  @override
  Future<Object?> read(String target) async => value;
  @override
  Future<void> write(String target, String encoded) async {
    entered.complete();
    await wait?.future;
    if (fail) throw StateError('PRIVATE');
    value = encoded;
  }

  @override
  Future<void> clear(String target) async {
    throw StateError('clear forbidden');
  }
}

final class Inner
    implements
        OwnedAiTextTransport,
        ConversationMutationTransport,
        ConversationScenarioReadPort {
  bool revoked = false;
  bool badClose = false;
  int closes = 0;
  int sends = 0;
  int reads = 0;
  Map<String, Object>? sent;
  ReviewSession? session;
  String? op;
  Completer<Object?>? wire;
  final entered = Completer<void>();
  @override
  bool get isCurrent => !revoked;
  @override
  void revoke() {
    revoked = true;
  }

  @override
  Future<void> close() async {
    closes++;
    if (badClose) throw StateError('PRIVATE');
  }

  @override
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String operation,
    required Map<String, Object> body,
  }) async {
    sends++;
    sent = body;
    op = operation;
    session = capturedSession;
    entered.complete();
    if (wire != null) return wire!.future;
    return 'TEST_ONLY_RESPONSE';
  }

  @override
  Future<Object?> read({
    required ReviewSession capturedSession,
    required AiTextLevel level,
  }) async {
    reads++;
    return <Object?>[];
  }

  @override
  Future<Object?> tutorExplain({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) async => 'text';
  @override
  Future<Object?> correctSentence({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) async => 'correction';
}

void main() {
  late Auth auth;
  late Backend backend;
  late Inner inner;
  late ConversationReceiptStore store;
  ReceiptGuardedAiTransport open({bool Function()? ready}) =>
      ReceiptGuardedAiTransport(
        inner: inner,
        store: store,
        auth: auth,
        capturedSession: auth.currentSession!,
        isReady: ready ?? () => true,
      );
  setUp(() {
    auth = Auth();
    backend = Backend();
    inner = Inner();
    store = ConversationReceiptStore(scope: scope, backend: backend);
    addTearDown(store.close);
  });
  final requests = <String, Map<String, Object>>{
    'start_conversation': start.toJson(),
    'conversation_turn': ConversationTurnRequest(
      sessionId: owner,
      clientEventId: event,
      textJa: '  日\u3099  ',
    ).toJson(),
    'finish_conversation': FinishConversationRequest(
      sessionId: owner,
      clientEventId: event,
    ).toJson(),
  };
  test(
    'pending receipt retains original conflict and different event busy',
    () async {
      final reference = ConversationReceiptReference.fromStart(
        projectUrl: scope.projectOrigin,
        ownerId: owner,
        request: start,
      );
      backend.value = reference.encode();
      final t = open();
      addTearDown(t.close);
      final session = CapturedConversationSession(
        auth: auth,
        transport: t,
        isReady: () => true,
      );
      final other = StartConversationRequest(
        scenarioId: owner,
        level: AiTextLevel.n5,
        clientEventId: 'b2000000-0000-4000-8000-000000000002',
      );
      for (var i = 0; i < 3; i++) {
        await expectLater(
          session.start(start),
          throwsA(code(AiTextErrorCode.syncConflict)),
        );
        await expectLater(
          session.start(other),
          throwsA(isA<AiTextRequestPending>()),
        );
        expect(session.hasUnresolvedMutation, isTrue);
        expect(session.isCurrent, isTrue);
        expect(inner.sends, 0);
        expect(backend.value, reference.encode());
      }
    },
  );
  for (final entry in requests.entries) {
    test(
      'typed ${entry.key} persists metadata before immutable exact wire',
      () async {
        backend.wait = Completer<void>();
        final t = open();
        final body = Map<String, Object>.from(entry.value);
        final sent = t.invoke(
          capturedSession: auth.currentSession!,
          operation: entry.key,
          body: body,
        );
        await backend.entered.future;
        expect(inner.sends, 0);
        body['client_event_id'] = owner;
        backend.wait!.complete();
        expect(await sent, 'TEST_ONLY_RESPONSE');
        expect(inner.sent, entry.value);
        expect(inner.op, entry.key);
        expect(identical(inner.session, auth.currentSession), true);
        expect(
          () => inner.sent!['client_event_id'] = owner,
          throwsUnsupportedError,
        );
        final ref = ConversationReceiptReference.decode(
          backend.value! as String,
        );
        expect(ref.clientEventId, event);
        expect(ref.operation.wireName, entry.key);
        await expectLater(
          t.invoke(
            capturedSession: auth.currentSession!,
            operation: entry.key,
            body: entry.value,
          ),
          throwsA(code(AiTextErrorCode.syncConflict)),
        );
        await t.close();
        expect(inner.closes, 1);
        expect(backend.value, isNotNull);
      },
    );
  }
  test('storage failure never reaches owned wire', () async {
    backend.fail = true;
    final t = open();
    await expectLater(
      t.invoke(
        capturedSession: auth.currentSession!,
        operation: 'start_conversation',
        body: start.toJson(),
      ),
      throwsA(code(AiTextErrorCode.internalError)),
    );
    expect(inner.sends, 0);
    await t.close();
  });
  test('preexisting receipt blocks even identical original event', () async {
    backend.value = ConversationReceiptReference.fromStart(
      projectUrl: scope.projectOrigin,
      ownerId: owner,
      request: start,
    ).encode();
    final t = open();
    await expectLater(
      t.invoke(
        capturedSession: auth.currentSession!,
        operation: 'start_conversation',
        body: start.toJson(),
      ),
      throwsA(code(AiTextErrorCode.syncConflict)),
    );
    expect(inner.sends, 0);
    await t.close();
  });
  for (final error in [false, true]) {
    test(
      'runtime owner drains late owned HTTP error=$error before next generation',
      () async {
        inner.wire = Completer<Object?>();
        var created = 0;
        late ReceiptGuardedAiTransport transport;
        final runtime = AiTextRuntimeOwner(
          createTransport: ({required auth, required isReady}) {
            created++;
            return transport = open(ready: isReady);
          },
        );
        final generation = AiTextGeneration();
        final session = runtime.acquireConversation(
          auth: auth,
          generation: generation,
          isReady: () => true,
        )!;
        final result = expectLater(
          session.start(start),
          throwsA(code(AiTextErrorCode.unauthorized)),
        );
        await inner.entered.future;
        runtime.invalidate();
        expect(transport.isCurrent, false);
        expect(inner.revoked, true);
        expect(runtime.isDraining, true);
        expect(
          runtime.acquireConversation(
            auth: auth,
            generation: AiTextGeneration(),
            isReady: () => true,
          ),
          isNull,
        );
        expect(created, 1);
        if (error) {
          inner.wire!.completeError(StateError('PRIVATE_HTTP'));
        } else {
          final fixtures =
              jsonDecode(
                    File(
                      '../../contracts/v0.1/fixtures.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, Object?>;
          inner.wire!.complete(fixtures['start_conversation_response']);
        }
        await result;
        await runtime.close();
        expect(inner.closes, 1);
        expect(backend.value, isNotNull);
      },
    );
  }
  test(
    'runtime invalidation waits storage and prevents late first HTTP',
    () async {
      backend.wait = Completer<void>();
      final runtime = AiTextRuntimeOwner(
        createTransport: ({required auth, required isReady}) =>
            open(ready: isReady),
      );
      final session = runtime.acquireConversation(
        auth: auth,
        generation: AiTextGeneration(),
        isReady: () => true,
      )!;
      final result = expectLater(
        session.start(start),
        throwsA(code(AiTextErrorCode.unauthorized)),
      );
      await backend.entered.future;
      runtime.invalidate();
      var closed = false;
      final closing = runtime.close().then((_) {
        closed = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(closed, false);
      expect(inner.sends, 0);
      expect(inner.closes, 0);
      backend.wait!.complete();
      await result;
      await closing;
      expect(inner.sends, 0);
      expect(inner.closes, 1);
      expect(backend.value, isNotNull);
    },
  );
  test('scenario and text delegate without writing receipt', () async {
    final t = open();
    expect(
      await t.read(
        capturedSession: auth.currentSession!,
        level: AiTextLevel.n5,
      ),
      isEmpty,
    );
    expect(
      await t.tutorExplain(capturedSession: auth.currentSession!, body: {}),
      'text',
    );
    expect(
      await t.correctSentence(capturedSession: auth.currentSession!, body: {}),
      'correction',
    );
    expect(backend.value, isNull);
    await t.close();
  });
  test('private cleanup failure stays fixed and closes once', () async {
    inner.badClose = true;
    final t = open();
    await expectLater(t.close(), throwsA(code(AiTextErrorCode.internalError)));
    await expectLater(t.close(), throwsA(code(AiTextErrorCode.internalError)));
    expect(inner.closes, 1);
  });
  for (final operation in ['invalid', 'start_conversation']) {
    test('invalid operation or body never writes $operation', () async {
      final t = open();
      await expectLater(
        t.invoke(
          capturedSession: auth.currentSession!,
          operation: operation,
          body: {'PRIVATE': event},
        ),
        throwsA(code(AiTextErrorCode.validationFailure)),
      );
      expect(backend.value, isNull);
      expect(inner.sends, 0);
      await t.close();
    });
  }
}
