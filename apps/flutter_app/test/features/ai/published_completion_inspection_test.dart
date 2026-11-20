// TEST ONLY Auth/ports/storage. Read-only view association, never release proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_receipt_lookup.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_session.dart';
import 'package:nihongo_daily/features/ai/data/conversation_receipt_store.dart';
import 'package:nihongo_daily/features/ai/domain/pending_conversation_command_envelope.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'accepted_completion_inspection_test.dart' as a;
import 'captured_conversation_session_test.dart' as f;
import 'lane_completion_reconciliation_test.dart' as h;
import 'session_completion_application_test.dart' as s;

Future<({CapturedConversationSession flow, f.Auth auth, f.Port port})>
published(String op, {bool Function()? ready}) async {
  final auth = f.Auth();
  final port = f.Port();
  final flow = CapturedConversationSession(
    auth: auth,
    transport: port,
    isReady: ready ?? () => true,
  );
  if (op != h.operations.first) await flow.start(f.start());
  await s.submit(flow, h.command(op));
  return (flow: flow, auth: auth, port: port);
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
      '$op inspects exact published view without effects or proof',
      () async {
        final p = await published(op);
        final command = h.command(op);
        final c = await h.completion(p.auth, command);
        final b = h.Backend(command.reference.encode());
        final store = h.store(b);
        final before = p.flow.snapshot;
        final sends = p.port.calls.length;
        for (var n = 0; n < 2; n++) {
          expect(
            p.flow.inspectPublishedCompletion(c.handle, store: store),
            same(before),
          );
          expect(p.flow.snapshot, same(before));
          expect(
            p.flow.captureAppliedCompletion(c.handle, store: store),
            isNull,
          );
          await s.submit(p.flow, command);
        }
        expect(p.port.calls, hasLength(sends));
        expect(c.port.calls, 1);
        expect(b.calls, isEmpty);
        expect(b.value, command.reference.encode());
        expect(p.flow.hasUnresolvedMutation, isFalse);
        expect(p.flow.isBusy, isFalse);
        expect(p.flow.retainedCommand, isNull);
        expect(() => before.messages.clear(), throwsUnsupportedError);
      },
    );
    test('$op rejects changed original and changed entire result', () async {
      final p = await published(op);
      final original = await h.completion(p.auth, h.command(op, changed: true));
      final result = await a.changedResult(p.auth, h.command(op));
      final b = h.Backend(null);
      final store = h.store(b);
      final before = p.flow.snapshot;
      expect(
        p.flow.inspectPublishedCompletion(original.handle, store: store),
        isNull,
      );
      expect(p.flow.inspectPublishedCompletion(result, store: store), isNull);
      expect(p.flow.snapshot, same(before));
      expect(b.calls, isEmpty);
    });
    test(
      '$op reconciled and cached replay is not normal publication evidence',
      () async {
        final p = await s.pending(op);
        final c = await h.completion(p.auth, h.command(op));
        final b = h.Backend(h.command(op).reference.encode());
        final store = h.store(b);
        expect(
          await p.flow.applyRetainedCompletion(c.handle, store: store),
          isTrue,
        );
        final before = p.flow.snapshot;
        final calls = List<String>.from(b.calls);
        final sends = p.port.calls.length;
        expect(
          p.flow.inspectPublishedCompletion(c.handle, store: store),
          isNull,
        );
        await s.submit(p.flow, h.command(op));
        expect(
          p.flow.inspectPublishedCompletion(c.handle, store: store),
          isNull,
        );
        expect(p.flow.snapshot, same(before));
        expect(p.port.calls, hasLength(sends));
        expect(b.calls, calls);
      },
    );
  }
  test(
    'old start and old turn cannot match after transcript advances or finishes',
    () async {
      final p = await published(h.operations.first);
      final start = await h.completion(p.auth, h.command(h.operations.first));
      await p.flow.turn(f.turn());
      final turn = await h.completion(p.auth, h.command(h.operations[1]));
      final b = h.Backend(null);
      final store = h.store(b);
      expect(
        p.flow.inspectPublishedCompletion(start.handle, store: store),
        isNull,
      );
      expect(
        p.flow.inspectPublishedCompletion(turn.handle, store: store),
        same(p.flow.snapshot),
      );
      p.port.reply = (_) =>
          f.response(h.operations[1], sequence: 4, message: f.message2);
      await p.flow.turn(f.turn(event: f.otherEvent));
      final later = p.flow.snapshot;
      await p.flow.start(
        f.start(),
      ); // Cached old success must not reset the view.
      await p.flow.turn(f.turn());
      expect(p.flow.snapshot, same(later));
      expect(
        p.flow.inspectPublishedCompletion(start.handle, store: store),
        isNull,
      );
      expect(
        p.flow.inspectPublishedCompletion(turn.handle, store: store),
        isNull,
      );
      p.port.reply = null;
      await p.flow.finish(f.finish());
      final finished = p.flow.snapshot;
      expect(
        p.flow.inspectPublishedCompletion(start.handle, store: store),
        isNull,
      );
      expect(
        p.flow.inspectPublishedCompletion(turn.handle, store: store),
        isNull,
      );
      expect(p.flow.snapshot, same(finished));
      expect(p.port.calls, hasLength(4));
      expect(b.calls, isEmpty);
    },
  );
  test('foreign Auth and project/owner stores grant no association', () async {
    final p = await published(h.operations.first);
    final foreign = f.Auth()..currentSession = p.auth.currentSession;
    final bad = await h.completion(foreign, h.command(h.operations.first));
    final good = await h.completion(p.auth, h.command(h.operations.first));
    final b = h.Backend(null);
    final ownStore = h.store(b);
    expect(
      p.flow.inspectPublishedCompletion(bad.handle, store: ownStore),
      isNull,
    );
    for (final project in [true, false]) {
      final store = ConversationReceiptStore(
        scope: PendingConversationCommandEnvelope.fromStart(
          projectUrl: project ? 'https://foreign.test' : h.origin,
          ownerId: project ? f.owner : f.otherEvent,
          request: f.start(),
        ).reference.scope,
        backend: b,
      );
      addTearDown(store.close);
      expect(
        p.flow.inspectPublishedCompletion(good.handle, store: store),
        isNull,
      );
    }
    expect(b.calls, isEmpty);
    expect(p.port.calls, hasLength(1));
  });
  for (final transition in [
    'refresh',
    'account',
    'revoke',
    'reader',
    'store',
  ]) {
    test('$transition cannot revive published association', () async {
      final p = await published(h.operations.first);
      final old = p.auth.currentSession;
      final c = await h.completion(p.auth, h.command(h.operations.first));
      final b = h.Backend(null);
      final store = h.store(b);
      switch (transition) {
        case 'refresh':
          p.auth.currentSession = ReviewSession(userId: f.owner);
        case 'account':
          p.auth.currentSession = ReviewSession(userId: f.otherEvent);
        case 'revoke':
          p.flow.revoke();
        case 'reader':
          c.reader.revoke();
        case 'store':
          await store.close();
      }
      expect(p.flow.inspectPublishedCompletion(c.handle, store: store), isNull);
      p.auth.currentSession = old;
      expect(p.flow.inspectPublishedCompletion(c.handle, store: store), isNull);
      expect(b.calls, isEmpty);
      expect(p.port.calls, hasLength(1));
    });
  }
  test(
    'missing publication and unresolved later command cannot expose old view',
    () async {
      final auth = f.Auth();
      final port = f.Port();
      final flow = CapturedConversationSession(
        auth: auth,
        transport: port,
        isReady: () => true,
      );
      final c = await h.completion(auth, h.command(h.operations.first));
      final b = h.Backend(null);
      final store = h.store(b);
      expect(flow.inspectPublishedCompletion(c.handle, store: store), isNull);
      await flow.start(f.start());
      final before = flow.snapshot;
      port.reply = (_) =>
          throw const AiTextFailure(AiTextErrorCode.providerUnavailable);
      await expectLater(
        flow.turn(f.turn()),
        throwsA(f.code(AiTextErrorCode.providerUnavailable)),
      );
      expect(flow.inspectPublishedCompletion(c.handle, store: store), isNull);
      expect(flow.snapshot, same(before));
      expect(flow.hasUnresolvedMutation, isTrue);
      expect(port.calls, hasLength(2));
      expect(b.calls, isEmpty);
    },
  );
  test(
    'lane acceptance with rejected transcript never becomes published evidence',
    () async {
      final p = await published(h.operations.first);
      final badResponse = f.response(
        h.operations[1],
        sequence: 0,
        message: f.message0,
      );
      p.port.reply = (_) => badResponse;
      await expectLater(
        p.flow.turn(f.turn()),
        throwsA(f.code(AiTextErrorCode.syncConflict)),
      );
      final c = await s.customCompletion(p.auth, h.operations[1], badResponse);
      final b = h.Backend(null);
      final store = h.store(b);
      expect(p.flow.inspectPublishedCompletion(c, store: store), isNull);
      expect(p.flow.snapshot.phase, ConversationSessionPhase.revoked);
      expect(p.port.calls, hasLength(2));
      expect(b.calls, isEmpty);
    },
  );
  for (final lateError in [false, true]) {
    test(
      'timeout/late drain cannot become published evidence error=$lateError',
      () async {
        final auth = f.Auth();
        final wire = Completer<Object?>();
        final port = f.Port()..reply = (_) => wire.future;
        final flow = CapturedConversationSession(
          auth: auth,
          transport: port,
          isReady: () => true,
          timeout: const Duration(milliseconds: 1),
        );
        final c = await h.completion(auth, h.command(h.operations.first));
        final b = h.Backend(null);
        final store = h.store(b);
        final sending = flow.start(f.start());
        expect(flow.inspectPublishedCompletion(c.handle, store: store), isNull);
        await expectLater(
          sending,
          throwsA(f.code(AiTextErrorCode.networkUnavailable)),
        );
        expect(flow.inspectPublishedCompletion(c.handle, store: store), isNull);
        if (lateError) {
          wire.completeError(StateError('PRIVATE_LATE'));
        } else {
          wire.complete(f.response(h.operations.first));
        }
        await f.settle();
        expect(flow.inspectPublishedCompletion(c.handle, store: store), isNull);
        expect(flow.snapshot.phase, ConversationSessionPhase.notStarted);
        expect(flow.hasUnresolvedMutation, isTrue);
        expect(port.calls, hasLength(1));
        expect(b.calls, isEmpty);
      },
    );
  }
  for (final target in [
    'reentry',
    'reader',
    'store',
    'refresh',
    'revoke',
    'throw',
  ]) {
    test('last session readiness $target cannot bypass final guards', () async {
      var armed = false;
      var checks = 0;
      late CapturedConversationSession flow;
      late CapturedConversationCompletion handle;
      late CapturedConversationReceiptLookup reader;
      late ConversationReceiptStore store;
      late f.Auth auth;
      Future<void>? nested;
      Future<void>? closing;
      final p = await published(
        h.operations.first,
        ready: () {
          if (armed && ++checks == 8) {
            armed = false;
            switch (target) {
              case 'reentry':
                expect(
                  flow.inspectPublishedCompletion(handle, store: store),
                  isNull,
                );
                expect(flow.retainedCommand, isNull);
                nested = expectLater(
                  flow.turn(f.turn()),
                  throwsA(isA<AiTextRequestPending>()),
                );
              case 'reader':
                reader.revoke();
              case 'store':
                closing = store.close();
              case 'refresh':
                auth.currentSession = ReviewSession(userId: f.owner);
              case 'revoke':
                flow.revoke();
              case 'throw':
                throw StateError('PRIVATE_READINESS');
            }
          }
          return true;
        },
      );
      flow = p.flow;
      auth = p.auth;
      final c = await h.completion(auth, h.command(h.operations.first));
      handle = c.handle;
      reader = c.reader;
      final b = h.Backend(null);
      store = h.store(b);
      final before = flow.snapshot;
      armed = true;
      final result = flow.inspectPublishedCompletion(handle, store: store);
      expect(armed, isFalse);
      expect(checks, 8);
      expect(result, target == 'reentry' ? same(before) : isNull);
      await nested;
      await closing;
      expect(flow.isBusy, isFalse);
      expect(p.port.calls, hasLength(1));
      expect(b.calls, isEmpty);
    });
  }
  for (final op in h.operations) {
    test(
      '$op confirmed clear mints proof only for exact published snapshot',
      () async {
        final p = await published(op);
        final command = h.command(op);
        final completion = await h.completion(p.auth, command);
        final backend = h.Backend(command.reference.encode());
        final store = h.store(backend);
        final before = p.flow.snapshot;
        final sends = p.port.calls.length;
        final application = await p.flow.acknowledgePublishedCompletion(
          completion.handle,
          store: store,
        );
        expect(application, isNotNull);
        expect(p.flow.snapshot, same(before));
        expect(backend.calls, ['read', 'clear', 'read']);
        expect(backend.value, isNull);
        expect(
          p.flow.captureAppliedCompletion(completion.handle, store: store),
          same(application),
        );
        expect(
          application!.consumeForTransport(auth: p.auth, store: store),
          isNotNull,
        );
        expect(
          p.flow.captureAppliedCompletion(completion.handle, store: store),
          isNull,
        );
        expect(p.port.calls, hasLength(sends));
      },
    );
  }
  test('stale published snapshot never clears or mints proof', () async {
    final p = await published(h.operations.first);
    final command = h.command(h.operations.first);
    final completion = await h.completion(p.auth, command);
    await p.flow.turn(f.turn());
    final backend = h.Backend(command.reference.encode());
    final store = h.store(backend);
    final before = p.flow.snapshot;
    expect(
      await p.flow.acknowledgePublishedCompletion(
        completion.handle,
        store: store,
      ),
      isNull,
    );
    expect(p.flow.snapshot, same(before));
    expect(
      p.flow.captureAppliedCompletion(completion.handle, store: store),
      isNull,
    );
    expect(backend.calls, isEmpty);
    expect(backend.value, command.reference.encode());
  });
  test('A-B-A during held clear cannot mint a late proof', () async {
    final p = await published(h.operations.first);
    final original = p.auth.currentSession;
    final command = h.command(h.operations.first);
    final completion = await h.completion(p.auth, command);
    final backend = h.Backend(command.reference.encode())
      ..holdClear = Completer<void>();
    final store = h.store(backend);
    final before = p.flow.snapshot;
    final acknowledging = p.flow.acknowledgePublishedCompletion(
      completion.handle,
      store: store,
    );
    await backend.clearEntered.future;
    expect(p.flow.isBusy, isTrue);
    expect(p.flow.snapshot, same(before));
    expect(
      p.flow.captureAppliedCompletion(completion.handle, store: store),
      isNull,
    );
    p.auth.currentSession = ReviewSession(userId: f.otherEvent);
    p.auth.currentSession = ReviewSession(userId: f.owner);
    backend.holdClear!.complete();
    expect(await acknowledging, isNull);
    expect(p.flow.snapshot.phase, ConversationSessionPhase.revoked);
    expect(p.flow.isCurrent, isFalse);
    expect(
      p.flow.captureAppliedCompletion(completion.handle, store: store),
      isNull,
    );
    expect(backend.value, isNull);
    expect(p.port.calls, hasLength(1));
    p.auth.currentSession = original;
  });
  for (final fault in ['clear', 'silent', 'confirm-read']) {
    test(
      'ambiguous published $fault clear failure retires without proof',
      () async {
        final p = await published(h.operations.first);
        final command = h.command(h.operations.first);
        final completion = await h.completion(p.auth, command);
        final backend = h.Backend(command.reference.encode())
          ..failClear = fault == 'clear'
          ..keepClear = fault == 'silent'
          ..failConfirm = fault == 'confirm-read';
        final store = h.store(backend);
        await expectLater(
          p.flow.acknowledgePublishedCompletion(
            completion.handle,
            store: store,
          ),
          throwsA(
            isA<ConversationReceiptStoreFailure>().having(
              (failure) => failure.code,
              'fixed storage failure',
              ConversationReceiptStoreError.unavailable,
            ),
          ),
        );
        expect(p.flow.snapshot.phase, ConversationSessionPhase.revoked);
        expect(
          p.flow.captureAppliedCompletion(completion.handle, store: store),
          isNull,
        );
        expect(
          backend.value,
          fault == 'confirm-read' ? isNull : command.reference.encode(),
        );
        expect(p.port.calls, hasLength(1));
      },
    );
  }
}