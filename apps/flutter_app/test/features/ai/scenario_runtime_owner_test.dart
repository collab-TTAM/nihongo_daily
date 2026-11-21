// TEST ONLY injected lifecycle/read/mutation ports, no SDK/hosted proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/application/ai_text_runtime_owner.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_mutation.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_scenarios.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_session.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

const id = '11111111-1111-4111-8111-111111111111';
late Map<String, Object?> fixtures;
List<Object> rows() => [
  {
    'id': id,
    'jlpt_level': 'N5',
    'title_vi': 'Tình huống',
    'title_ja': '会話',
    'description_vi': 'Mô tả',
    'content_version': 1,
    'is_active': true,
  },
];
final unauthorized = throwsA(
  isA<AiTextFailure>().having(
    (e) => e.code,
    'code',
    AiTextErrorCode.unauthorized,
  ),
);
Future<void> flush() => Future<void>.delayed(Duration.zero);

final class Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(userId: id);
}

class TextPort implements OwnedAiTextTransport {
  TextPort(this.ready);
  final bool Function() ready;
  bool revoked = false, badClose = false;
  int closes = 0;
  Completer<void>? heldClose;
  void Function()? onRevoke;
  @override
  bool get isCurrent => !revoked && ready();
  @override
  void revoke() {
    revoked = true;
    onRevoke?.call();
  }

  @override
  Future<void> close() async {
    closes++;
    revoke();
    await heldClose?.future;
    if (badClose) throw StateError('PRIVATE');
  }

  @override
  Future<Object?> tutorExplain({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) async => fixtures['tutor_explain_response'];
  @override
  Future<Object?> correctSentence({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) async => fixtures['correct_sentence_response'];
}

final class Port extends TextPort
    implements ConversationScenarioReadPort, ConversationMutationTransport {
  Port(super.ready);
  int reads = 0, mutations = 0;
  Completer<Object?>? heldRead;
  final pending = <Future<void>>{};
  @override
  Future<Object?> read({
    required ReviewSession capturedSession,
    required AiTextLevel level,
  }) {
    reads++;
    final result = heldRead?.future ?? Future<Object?>.value(rows());
    final drain = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    pending.add(drain);
    unawaited(drain.then<void>((_) => pending.remove(drain)));
    return result;
  }

  @override
  Future<void> close() async {
    await super.close();
    await Future.wait(pending.toList());
  }

  @override
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String operation,
    required Map<String, Object> body,
  }) async {
    mutations++;
    return fixtures['${operation}_response'];
  }
}

final class Harness {
  Harness() {
    owner = AiTextRuntimeOwner(
      createTransport: ({required auth, required isReady}) {
        final p = Port(isReady);
        ports.add(p);
        return p;
      },
    );
  }
  final auth = Auth();
  final ports = <Port>[];
  late final AiTextRuntimeOwner owner;
  var generation = AiTextGeneration();
  bool ready = true;
  CapturedConversationScenarios? acquire() => owner.acquireScenarios(
    auth: auth,
    generation: generation,
    isReady: () => ready,
  );
  CapturedConversationSession? conversation() => owner.acquireConversation(
    auth: auth,
    generation: generation,
    isReady: () => ready,
  );
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
    'one retained catalog shares lease without dispatch or resetting finished conversation',
    () async {
      final h = Harness();
      addTearDown(h.owner.close);
      final catalog = h.acquire()!;
      final flow = h.conversation()!;
      expect(identical(h.acquire(), catalog), isTrue);
      expect(h.ports, hasLength(1));
      expect(h.ports.single.reads, 0);
      expect(h.ports.single.mutations, 0);
      await flow.start(
        StartConversationRequest.fromJson(
          fixtures['start_conversation_request'],
        ),
      );
      await flow.finish(
        FinishConversationRequest.fromJson(
          fixtures['finish_conversation_request'],
        ),
      );
      expect(await catalog.load(AiTextLevel.n5), hasLength(1));
      expect(identical(h.acquire(), catalog), isTrue);
      expect(identical(h.conversation(), flow), isTrue);
      expect(flow.snapshot.phase, ConversationSessionPhase.finished);
      expect(h.ports.single.mutations, 2);
      await h.owner.close();
      expect(catalog.isCurrent, isFalse);
      expect(h.ports.single.closes, 1);
    },
  );
  test(
    'optional read interface absent leaves existing text lease available',
    () async {
      final a = Auth();
      late TextPort port;
      final g = AiTextGeneration();
      final o = AiTextRuntimeOwner(
        createTransport: ({required auth, required isReady}) =>
            port = TextPort(isReady),
      );
      addTearDown(o.close);
      expect(
        o.acquireScenarios(auth: a, generation: g, isReady: () => true),
        isNull,
      );
      expect(o.acquire(auth: a, generation: g, isReady: () => true), isNotNull);
      expect(port.revoked, isFalse);
      expect(port.closes, 0);
    },
  );
  test(
    'invalidate revokes catalog before transport callbacks and new generation waits for actual read drain',
    () async {
      final h = Harness();
      addTearDown(h.owner.close);
      final old = h.acquire()!;
      final port = h.ports.single;
      port.heldRead = Completer<Object?>();
      final work = old.load(AiTextLevel.n5);
      final rejected = expectLater(work, unauthorized);
      var observed = false;
      port.onRevoke = () {
        observed = true;
        expect(old.isCurrent, isFalse);
      };
      h.owner.invalidate();
      expect(observed, isTrue);
      expect(old.isCurrent, isFalse);
      final retired = h.generation;
      h.generation = AiTextGeneration();
      expect(h.acquire(), isNull);
      expect(h.ports, hasLength(1));
      port.heldRead!.complete(rows());
      await rejected;
      await flush();
      final fresh = h.acquire()!;
      expect(identical(old, fresh), isFalse);
      expect(h.ports, hasLength(2));
      expect(
        h.owner.acquireScenarios(
          auth: h.auth,
          generation: retired,
          isReady: () => true,
        ),
        isNull,
      );
    },
  );
  for (final mode in ['same-user', 'other-user', 'logout', 'ready']) {
    test(
      'owner check fences retained catalog and sibling flow permanently mode=$mode',
      () async {
        final h = Harness();
        addTearDown(h.owner.close);
        final reader = h.acquire()!;
        final flow = h.conversation()!;
        final original = h.auth.currentSession;
        switch (mode) {
          case 'same-user':
            h.auth.currentSession = ReviewSession(userId: id);
          case 'other-user':
            h.auth.currentSession = ReviewSession(
              userId: '22222222-2222-4222-8222-222222222222',
            );
          case 'logout':
            h.auth.currentSession = null;
          case 'ready':
            h.ready = false;
        }
        h.owner.check();
        expect(reader.isCurrent, isFalse);
        expect(flow.isCurrent, isFalse);
        h.auth.currentSession = original;
        h.ready = true;
        await flush();
        expect(h.acquire(), isNull);
        expect(h.ports, hasLength(1));
        await expectLater(reader.load(AiTextLevel.n5), unauthorized);
      },
    );
  }
  test(
    'revoked catalog makes check retire all siblings before rebuilding',
    () async {
      final h = Harness();
      addTearDown(h.owner.close);
      final reader = h.acquire()!;
      final flow = h.conversation()!;
      reader.revoke();
      h.owner.check();
      expect(flow.isCurrent, isFalse);
      expect(h.ports.single.revoked, isTrue);
      await flush();
      expect(h.acquire(), isNull);
    },
  );
  test(
    'failed cleanup blocks replacement catalog without raw failure',
    () async {
      final h = Harness();
      final reader = h.acquire()!;
      h.ports.single.badClose = true;
      h.owner.invalidate();
      await flush();
      expect(reader.isCurrent, isFalse);
      expect(h.owner.isFailed, isTrue);
      h.generation = AiTextGeneration();
      expect(h.acquire(), isNull);
      await expectLater(
        h.owner.close(),
        throwsA(
          isA<AiTextFailure>().having(
            (e) => e.code,
            'code',
            AiTextErrorCode.internalError,
          ),
        ),
      );
    },
  );
  test(
    'readiness reentry and reentrant close never publish orphan catalog',
    () async {
      final a = Auth();
      late AiTextRuntimeOwner o;
      Future<void>? closing;
      var entered = false;
      final allocated = <Port>[];
      o = AiTextRuntimeOwner(
        createTransport: ({required auth, required isReady}) {
          final p = Port(isReady);
          allocated.add(p);
          return p;
        },
      );
      final g = AiTextGeneration();
      final reader = o.acquireScenarios(
        auth: a,
        generation: g,
        isReady: () {
          if (!entered) {
            entered = true;
            expect(
              o.acquireScenarios(auth: a, generation: g, isReady: () => true),
              isNull,
            );
            closing = o.close();
          }
          return true;
        },
      );
      expect(reader, isNull);
      await closing;
      expect(
        o.acquireScenarios(
          auth: a,
          generation: AiTextGeneration(),
          isReady: () => true,
        ),
        isNull,
      );
      expect(allocated.length, lessThanOrEqualTo(1));
      for (final p in allocated) {
        expect(p.revoked, isTrue);
        expect(p.closes, 1);
      }
    },
  );
}
