// TEST ONLY lifecycle/ports/storage. Not SDK/JWT/native or learner acceptance.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/application/ai_text_runtime_owner.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_mutation.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_receipt_lookup.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_session.dart';
import 'package:nihongo_daily/features/ai/data/conversation_receipt_store.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_reference.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_snapshot.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'captured_conversation_session_test.dart' as f;
import 'lane_completion_reconciliation_test.dart' as h;
import 'recovered_command_receipt_lookup_test.dart' as r;
import 'retained_completion_inspection_test.dart' as i;
import 'session_completion_application_test.dart' as s;

final class Inner
    implements
        OwnedAiTextTransport,
        ConversationMutationTransport,
        ConversationReceiptReadPort,
        ConversationOriginalReceiptReadPort {
  final mutations = f.Port();
  final reads = r.OriginalPort();
  bool revoked = false;
  int closes = 0;
  @override
  bool get isCurrent => !revoked;
  @override
  void revoke() => revoked = true;
  @override
  Future<void> close() async {
    closes++;
  }

  @override
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String operation,
    required Map<String, Object> body,
  }) => mutations.invoke(
    capturedSession: capturedSession,
    operation: operation,
    body: body,
  );
  @override
  Future<Object?> tutorExplain({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) async => throw StateError('UNUSED');
  @override
  Future<Object?> correctSentence({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) async => throw StateError('UNUSED');
  @override
  Future<ConversationReceiptSnapshot> lookupReceipt(
    ConversationReceiptReference ref,
  ) => reads.lookupReceipt(ref);
  @override
  Future<ConversationReceiptSnapshot> lookupStartReceipt(
    ConversationReceiptReference ref,
    StartConversationRequest request,
  ) => reads.lookupStartReceipt(ref, request);
  @override
  Future<ConversationReceiptSnapshot> lookupTurnReceipt(
    ConversationReceiptReference ref,
    ConversationTurnRequest request,
  ) => reads.lookupTurnReceipt(ref, request);
  @override
  Future<ConversationReceiptSnapshot> lookupFinishReceipt(
    ConversationReceiptReference ref,
    FinishConversationRequest request,
  ) => reads.lookupFinishReceipt(ref, request);
}

Future<
  ({
    AiTextRuntimeOwner owner,
    f.Auth auth,
    AiTextGeneration generation,
    CapturedConversationSession flow,
    CapturedConversationReceiptLookup? reader,
    CapturedConversationCompletion handle,
    h.Backend backend,
    ConversationReceiptStore storage,
    Inner inner,
    List<Inner> created,
  })
>
setup(String op, {bool withReader = true, bool Function()? ready}) async {
  final inner = Inner();
  final created = <Inner>[];
  final owner = AiTextRuntimeOwner(
    createTransport: ({required auth, required isReady}) {
      created.add(inner);
      return inner;
    },
  );
  final auth = f.Auth();
  final generation = AiTextGeneration();
  final flow = owner.acquireConversation(
    auth: auth,
    generation: generation,
    isReady: ready ?? () => true,
  )!;
  if (op != h.operations.first) {
    await flow.start(f.start());
  }
  inner.mutations.reply = (_) =>
      throw const AiTextFailure(AiTextErrorCode.providerUnavailable);
  await expectLater(
    s.submit(flow, h.command(op)),
    throwsA(f.code(AiTextErrorCode.providerUnavailable)),
  );
  inner.reads.result = i.completed(h.command(op));
  final reader = withReader
      ? owner.acquireReceiptLookup(
          auth: auth,
          generation: generation,
          isReady: ready ?? () => true,
        )!
      : null;
  final handle = reader == null
      ? (await h.completion(auth, h.command(op))).handle
      : (await reader.lookupCompletion(h.command(op)))!;
  final backend = h.Backend(h.command(op).reference.encode());
  final storage = h.store(backend);
  addTearDown(() async {
    if (backend.holdClear != null && !backend.holdClear!.isCompleted) {
      backend.holdClear!.complete();
    }
    await owner.close();
  });
  return (
    owner: owner,
    auth: auth,
    generation: generation,
    flow: flow,
    reader: reader,
    handle: handle,
    backend: backend,
    storage: storage,
    inner: inner,
    created: created,
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
  for (final op in h.operations) {
    test(
      'exact owned $op reader/session/store applies without creating another lease',
      () async {
        final p = await setup(op);
        final sends = p.inner.mutations.calls.length;
        expect(
          await p.owner.applyRetainedConversationCompletion(
            p.handle,
            store: p.storage,
          ),
          isTrue,
        );
        expect(p.created, hasLength(1));
        expect(p.backend.calls, ['read', 'clear', 'read']);
        expect(
          p.flow.snapshot.phase,
          op == h.operations.last
              ? ConversationSessionPhase.finished
              : ConversationSessionPhase.active,
        );
        expect(
          p.owner.acquireConversation(
            auth: p.auth,
            generation: p.generation,
            isReady: () => true,
          ),
          same(p.flow),
        );
        expect(
          p.owner.acquireReceiptLookup(
            auth: p.auth,
            generation: p.generation,
            isReady: () => true,
          ),
          same(p.reader),
        );
        await s.submit(p.flow, h.command(op));
        expect(p.inner.mutations.calls, hasLength(sends));
        expect(p.inner.reads.calls, 1);
        expect(p.storage.phase, ConversationReceiptStorePhase.open);
      },
    );
  }
  test(
    'same Auth foreign reader rejected before its getters or storage run',
    () async {
      final p = await setup(h.operations.first);
      var armed = false;
      var reads = 0;
      final port = r.OriginalPort()
        ..result = i.completed(h.command(h.operations.first));
      final sibling = CapturedConversationReceiptLookup(
        auth: p.auth,
        port: port,
        isReady: () {
          if (armed) {
            reads++;
            throw StateError('PRIVATE');
          }
          return true;
        },
      );
      final handle = (await sibling.lookupCompletion(
        h.command(h.operations.first),
      ))!;
      armed = true;
      expect(handle.captureForReader(p.reader!), isNull);
      expect(
        await p.owner.applyRetainedConversationCompletion(
          handle,
          store: p.storage,
        ),
        isFalse,
      );
      expect(reads, 0);
      expect(p.backend.calls, isEmpty);
      expect(p.flow.hasUnresolvedMutation, isTrue);
      expect(p.created, hasLength(1));
    },
  );
  test('missing retained reader is not acquired implicitly', () async {
    final p = await setup(h.operations.first, withReader: false);
    expect(
      await p.owner.applyRetainedConversationCompletion(
        p.handle,
        store: p.storage,
      ),
      isFalse,
    );
    expect(p.backend.calls, isEmpty);
    expect(p.inner.reads.calls, 0);
    expect(p.flow.hasUnresolvedMutation, isTrue);
    expect(p.created, hasLength(1));
  });
  test('missing retained conversation is not created implicitly', () async {
    final inner = Inner()
      ..reads.result = i.completed(h.command(h.operations.first));
    final owner = AiTextRuntimeOwner(
      createTransport: ({required auth, required isReady}) => inner,
    );
    addTearDown(owner.close);
    final auth = f.Auth();
    final generation = AiTextGeneration();
    final reader = owner.acquireReceiptLookup(
      auth: auth,
      generation: generation,
      isReady: () => true,
    )!;
    final handle = (await reader.lookupCompletion(
      h.command(h.operations.first),
    ))!;
    final backend = h.Backend(h.command(h.operations.first).reference.encode());
    expect(
      await owner.applyRetainedConversationCompletion(
        handle,
        store: h.store(backend),
      ),
      isFalse,
    );
    expect(backend.calls, isEmpty);
    expect(
      owner
          .acquireConversation(
            auth: auth,
            generation: generation,
            isReady: () => true,
          )!
          .snapshot
          .phase,
      ConversationSessionPhase.notStarted,
    );
    expect(inner.mutations.calls, isEmpty);
  });
  test('foreign store scope leaves lease and pending unchanged', () async {
    final p = await setup(h.operations.first);
    final backend = h.Backend(p.backend.value);
    final foreign = ConversationReceiptStore(
      scope: ConversationReceiptScope(
        projectUrl: 'https://foreign.test',
        ownerId: f.owner,
      ),
      backend: backend,
    );
    addTearDown(foreign.close);
    expect(
      await p.owner.applyRetainedConversationCompletion(
        p.handle,
        store: foreign,
      ),
      isFalse,
    );
    expect(backend.calls, isEmpty);
    expect(p.flow.hasUnresolvedMutation, isTrue);
    expect(p.flow.isCurrent, isTrue);
  });
  test('storage failure retires sibling lease with fixed error', () async {
    final p = await setup(h.operations.first);
    p.backend.failClear = true;
    await expectLater(
      p.owner.applyRetainedConversationCompletion(p.handle, store: p.storage),
      throwsA(f.code(AiTextErrorCode.internalError)),
    );
    expect(p.flow.snapshot.phase, ConversationSessionPhase.revoked);
    expect(p.reader!.isCurrent, isFalse);
    expect(
      p.owner.acquireConversation(
        auth: p.auth,
        generation: p.generation,
        isReady: () => true,
      ),
      isNull,
    );
    expect(p.created, hasLength(1));
  });
  test(
    'held application blocks capability creation and concurrent application',
    () async {
      final p = await setup(h.operations.first);
      p.backend.holdClear = Completer<void>();
      final applying = p.owner.applyRetainedConversationCompletion(
        p.handle,
        store: p.storage,
      );
      await p.backend.clearEntered.future;
      expect(p.owner.isDraining, isTrue);
      expect(
        p.owner.acquireConversation(
          auth: p.auth,
          generation: p.generation,
          isReady: () => true,
        ),
        isNull,
      );
      expect(
        p.owner.acquireReceiptLookup(
          auth: p.auth,
          generation: p.generation,
          isReady: () => true,
        ),
        isNull,
      );
      expect(
        await p.owner.applyRetainedConversationCompletion(
          p.handle,
          store: p.storage,
        ),
        isFalse,
      );
      expect(p.created, hasLength(1));
      p.backend.holdClear!.complete();
      expect(await applying, isTrue);
      expect(p.owner.isDraining, isFalse);
    },
  );
  test(
    'close waits actual application storage drain without closing borrowed store',
    () async {
      final p = await setup(h.operations.first);
      p.backend.holdClear = Completer<void>();
      final applying = p.owner.applyRetainedConversationCompletion(
        p.handle,
        store: p.storage,
      );
      await p.backend.clearEntered.future;
      var closed = false;
      final closing = p.owner.close().then((_) => closed = true);
      await f.settle();
      expect(closed, isFalse);
      p.backend.holdClear!.complete();
      expect(await applying, isFalse);
      await closing;
      expect(closed, isTrue);
      expect(p.flow.snapshot.phase, ConversationSessionPhase.revoked);
      expect(p.storage.phase, ConversationReceiptStorePhase.open);
      expect(
        await p.owner.applyRetainedConversationCompletion(
          p.handle,
          store: p.storage,
        ),
        isFalse,
      );
    },
  );
  test('refresh during held clear cannot revive old generation', () async {
    final p = await setup(h.operations.first);
    final original = p.auth.currentSession;
    p.backend.holdClear = Completer<void>();
    final applying = p.owner.applyRetainedConversationCompletion(
      p.handle,
      store: p.storage,
    );
    await p.backend.clearEntered.future;
    p.auth.currentSession = ReviewSession(userId: f.owner);
    p.backend.holdClear!.complete();
    expect(await applying, isFalse);
    p.auth.currentSession = original;
    expect(
      p.owner.acquireConversation(
        auth: p.auth,
        generation: p.generation,
        isReady: () => true,
      ),
      isNull,
    );
    expect(p.inner.mutations.calls, hasLength(1));
  });
  test(
    'reservation precedes readiness reentry and prevents another transport',
    () async {
      var armed = false;
      late AiTextRuntimeOwner owner;
      late f.Auth auth;
      late AiTextGeneration generation;
      late CapturedConversationCompletion handle;
      late ConversationReceiptStore storage;
      Future<bool>? nested;
      final p = await setup(
        h.operations.first,
        ready: () {
          if (armed) {
            armed = false;
            expect(owner.isDraining, isTrue);
            expect(
              owner.acquireConversation(
                auth: auth,
                generation: generation,
                isReady: () => true,
              ),
              isNull,
            );
            nested = owner.applyRetainedConversationCompletion(
              handle,
              store: storage,
            );
          }
          return true;
        },
      );
      owner = p.owner;
      auth = p.auth;
      generation = p.generation;
      handle = p.handle;
      storage = p.storage;
      armed = true;
      expect(
        await owner.applyRetainedConversationCompletion(handle, store: storage),
        isTrue,
      );
      expect(await nested, isFalse);
      expect(p.created, hasLength(1));
    },
  );
}
