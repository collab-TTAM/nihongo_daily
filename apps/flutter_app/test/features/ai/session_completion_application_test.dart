// TEST ONLY Auth/ports/storage. No hosted learner or production-host activation.
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
import 'captured_conversation_session_test.dart' as f;
import 'lane_completion_reconciliation_test.dart' as h;
import 'recovered_command_receipt_lookup_test.dart' as r;
import 'retained_completion_inspection_test.dart' as i;

Future<Object> submit(
  CapturedConversationSession flow,
  PendingConversationCommandEnvelope c,
) => c.start != null
    ? flow.start(c.start!)
    : c.turn != null
    ? flow.turn(c.turn!)
    : flow.finish(c.finish!);
Future<({CapturedConversationSession flow, f.Auth auth, f.Port port})> pending(
  String op, {
  bool Function()? ready,
}) async {
  final auth = f.Auth();
  final port = f.Port();
  final flow = CapturedConversationSession(
    auth: auth,
    transport: port,
    isReady: ready ?? () => true,
  );
  if (op != h.operations.first) {
    await flow.start(f.start());
  }
  port.reply = (_) =>
      throw const AiTextFailure(AiTextErrorCode.providerUnavailable);
  await expectLater(
    submit(flow, h.command(op)),
    throwsA(f.code(AiTextErrorCode.providerUnavailable)),
  );
  return (flow: flow, auth: auth, port: port);
}

Future<CapturedConversationCompletion> customCompletion(
  ReviewAuth auth,
  String op,
  Map<String, Object?> response,
) async {
  final c = h.command(op);
  final port = r.OriginalPort()..result = i.completed(c, response: response);
  final reader = CapturedConversationReceiptLookup(
    auth: auth,
    port: port,
    isReady: () => true,
  );
  return (await reader.lookupCompletion(c))!;
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
      '$op applies once after confirmed clear and replay preserves later progress',
      () async {
        final p = await pending(op);
        final c = await h.completion(p.auth, h.command(op));
        final backend = h.Backend(h.command(op).reference.encode());
        final storage = h.store(backend);
        final before = p.flow.snapshot;
        final sends = p.port.calls.length;
        expect(
          await p.flow.applyRetainedCompletion(c.handle, store: storage),
          isTrue,
        );
        final applied = p.flow.snapshot;
        expect(applied, isNot(same(before)));
        expect(
          applied.phase,
          op == h.operations.last
              ? ConversationSessionPhase.finished
              : ConversationSessionPhase.active,
        );
        expect(applied.sessionId, f.session);
        expect(applied.messages.length, op == 'conversation_turn' ? 2 : 1);
        expect(applied.summary != null, op == h.operations.last);
        expect(() => applied.messages.clear(), throwsUnsupportedError);
        expect(p.flow.retainedCommand, isNull);
        expect(p.flow.canRetryRetained, isFalse);
        expect(p.flow.hasUnresolvedMutation, isFalse);
        expect(p.flow.isBusy, isFalse);
        expect(backend.calls, ['read', 'clear', 'read']);
        expect(backend.value, isNull);
        await submit(p.flow, h.command(op));
        expect(p.flow.snapshot, same(applied));
        expect(p.port.calls, hasLength(sends));
        expect(c.port.calls, 1);
        expect(
          await p.flow.applyRetainedCompletion(c.handle, store: storage),
          isFalse,
        );
        expect(backend.calls, ['read', 'clear', 'read']);
        if (op == h.operations.last) {
          await expectLater(
            p.flow.turn(f.turn()),
            throwsA(f.code(AiTextErrorCode.syncConflict)),
          );
          expect(p.port.calls, hasLength(sends));
        } else {
          p.port.reply = (operation) =>
              f.response(operation, sequence: 3, message: f.message2);
          await p.flow.turn(f.turn(event: f.otherEvent));
          final later = p.flow.snapshot;
          expect(later.messages.length, applied.messages.length + 1);
          await submit(p.flow, h.command(op));
          expect(p.flow.snapshot, same(later));
          expect(p.port.calls, hasLength(sends + 1));
        }
      },
    );
    test(
      '$op changed full original sharing metadata never clears or applies',
      () async {
        final p = await pending(op);
        final c = await h.completion(p.auth, h.command(op, changed: true));
        final backend = h.Backend(h.command(op).reference.encode());
        final before = p.flow.snapshot;
        final original = p.flow.retainedCommand;
        expect(
          await p.flow.applyRetainedCompletion(
            c.handle,
            store: h.store(backend),
          ),
          isFalse,
        );
        expect(backend.calls, isEmpty);
        expect(p.flow.snapshot, same(before));
        expect(p.flow.retainedCommand, same(original));
        expect(p.flow.hasUnresolvedMutation, isTrue);
      },
    );
    test(
      '$op held clear leaves old transcript visible and fences commands and nested apply',
      () async {
        final p = await pending(op);
        final c = await h.completion(p.auth, h.command(op));
        final backend = h.Backend(h.command(op).reference.encode())
          ..holdClear = Completer<void>();
        final storage = h.store(backend);
        final before = p.flow.snapshot;
        final sends = p.port.calls.length;
        final applying = p.flow.applyRetainedCompletion(
          c.handle,
          store: storage,
        );
        await backend.clearEntered.future;
        expect(p.flow.snapshot, same(before));
        expect(p.flow.isBusy, isTrue);
        expect(p.flow.retainedCommand, isNull);
        expect(p.flow.previewRetainedCompletion(c.handle), isNull);
        expect(p.flow.inspectRetainedCompletion(c.handle), isNull);
        await p.flow.retryRetained();
        await expectLater(
          p.flow.finish(f.finish()),
          throwsA(isA<AiTextRequestPending>()),
        );
        expect(
          await p.flow.applyRetainedCompletion(c.handle, store: storage),
          isFalse,
        );
        expect(p.port.calls, hasLength(sends));
        expect(backend.calls, ['read', 'clear']);
        backend.holdClear!.complete();
        expect(await applying, isTrue);
        expect(p.flow.snapshot, isNot(same(before)));
        expect(p.flow.isBusy, isFalse);
        expect(p.port.calls, hasLength(sends));
      },
    );
  }
  for (final bad in ['start-sequence', 'turn-sequence', 'turn-id']) {
    test(
      'invalid prospective transcript $bad causes no storage effect',
      () async {
        final op = bad == 'start-sequence'
            ? h.operations.first
            : 'conversation_turn';
        final p = await pending(op);
        final response = f.response(
          op,
          sequence: bad == 'turn-sequence' ? 0 : 2,
          message: bad == 'turn-id' ? f.message0.toUpperCase() : f.message1,
        );
        if (bad == 'start-sequence') {
          (response['assistant_message']!
                  as Map<String, Object?>)['sequence_no'] =
              1;
        }
        final handle = await customCompletion(p.auth, op, response);
        final backend = h.Backend(h.command(op).reference.encode());
        final before = p.flow.snapshot;
        expect(
          await p.flow.applyRetainedCompletion(handle, store: h.store(backend)),
          isFalse,
        );
        expect(backend.calls, isEmpty);
        expect(p.flow.snapshot, same(before));
        expect(p.flow.hasUnresolvedMutation, isTrue);
      },
    );
  }
  test('foreign Auth with identical hint leaves pending untouched', () async {
    final p = await pending(h.operations.first);
    final foreign = f.Auth()..currentSession = p.auth.currentSession;
    final c = await h.completion(foreign, h.command(h.operations.first));
    final backend = h.Backend(h.command(h.operations.first).reference.encode());
    final before = p.flow.snapshot;
    expect(
      await p.flow.applyRetainedCompletion(c.handle, store: h.store(backend)),
      isFalse,
    );
    expect(backend.calls, isEmpty);
    expect(p.flow.snapshot, same(before));
    expect(p.flow.hasUnresolvedMutation, isTrue);
  });
  test('foreign store cannot change transcript or pending', () async {
    final p = await pending(h.operations.first);
    final c = await h.completion(p.auth, h.command(h.operations.first));
    final backend = h.Backend(h.command(h.operations.first).reference.encode());
    final foreign = ConversationReceiptStore(
      scope: PendingConversationCommandEnvelope.fromStart(
        projectUrl: 'https://foreign.test',
        ownerId: f.owner,
        request: f.start(),
      ).reference.scope,
      backend: backend,
    );
    addTearDown(foreign.close);
    final before = p.flow.snapshot;
    final retained = p.flow.retainedCommand;
    expect(
      await p.flow.applyRetainedCompletion(c.handle, store: foreign),
      isFalse,
    );
    expect(backend.calls, isEmpty);
    expect(p.flow.snapshot, same(before));
    expect(p.flow.retainedCommand, same(retained));
  });
  for (final absent in [false, true]) {
    test(
      'missing/mismatched metadata cannot become applied success absent=$absent',
      () async {
        final p = await pending(h.operations.first);
        final c = await h.completion(p.auth, h.command(h.operations.first));
        final backend = h.Backend(
          absent ? null : h.command(h.operations.last).reference.encode(),
        );
        final sends = p.port.calls.length;
        expect(
          await p.flow.applyRetainedCompletion(
            c.handle,
            store: h.store(backend),
          ),
          isFalse,
        );
        expect(backend.calls, ['read']);
        expect(p.flow.snapshot.phase, ConversationSessionPhase.revoked);
        expect(p.flow.retainedCommand, isNull);
        await expectLater(
          p.flow.start(f.start()),
          throwsA(f.code(AiTextErrorCode.unauthorized)),
        );
        expect(p.port.calls, hasLength(sends));
      },
    );
  }
  for (final fault in ['clear', 'silent', 'confirm-read']) {
    test('storage $fault failure never publishes candidate', () async {
      final p = await pending(h.operations.first);
      final c = await h.completion(p.auth, h.command(h.operations.first));
      final backend =
          h.Backend(h.command(h.operations.first).reference.encode())
            ..failClear = fault == 'clear'
            ..keepClear = fault == 'silent'
            ..failConfirm = fault == 'confirm-read';
      await expectLater(
        p.flow.applyRetainedCompletion(c.handle, store: h.store(backend)),
        throwsA(
          isA<ConversationReceiptStoreFailure>().having(
            (e) => e.code,
            'fixed',
            ConversationReceiptStoreError.unavailable,
          ),
        ),
      );
      expect(p.flow.snapshot.phase, ConversationSessionPhase.revoked);
      expect(p.flow.snapshot.messages, isEmpty);
      expect(p.flow.canRetryRetained, isFalse);
      expect(p.port.calls, hasLength(1));
    });
  }
  for (final transition in ['refresh', 'account', 'revoke', 'reader']) {
    test(
      'held clear $transition cannot publish late candidate or revive A',
      () async {
        final p = await pending(h.operations.first);
        final original = p.auth.currentSession;
        final c = await h.completion(p.auth, h.command(h.operations.first));
        final backend = h.Backend(
          h.command(h.operations.first).reference.encode(),
        )..holdClear = Completer<void>();
        final applying = p.flow.applyRetainedCompletion(
          c.handle,
          store: h.store(backend),
        );
        await backend.clearEntered.future;
        if (transition == 'revoke') {
          p.flow.revoke();
        } else if (transition == 'reader') {
          c.reader.revoke();
        } else {
          p.auth.currentSession = ReviewSession(
            userId: transition == 'refresh' ? f.owner : f.otherEvent,
          );
        }
        backend.holdClear!.complete();
        expect(await applying, isFalse);
        expect(p.flow.snapshot.phase, ConversationSessionPhase.revoked);
        p.auth.currentSession = original;
        await expectLater(
          p.flow.start(f.start()),
          throwsA(f.code(AiTextErrorCode.unauthorized)),
        );
        expect(p.port.calls, hasLength(1));
      },
    );
  }
  test('signout during clear never publishes a candidate', () async {
    final p = await pending(h.operations.first);
    final c = await h.completion(p.auth, h.command(h.operations.first));
    final backend = h.Backend(h.command(h.operations.first).reference.encode())
      ..holdClear = Completer<void>();
    final storage = h.store(backend);
    final applying = expectLater(
      p.flow.applyRetainedCompletion(c.handle, store: storage),
      throwsA(
        isA<ConversationReceiptStoreFailure>().having(
          (e) => e.code,
          'revoked',
          ConversationReceiptStoreError.revoked,
        ),
      ),
    );
    await backend.clearEntered.future;
    final logout = storage.clearForSignOut();
    backend.holdClear!.complete();
    await Future.wait<void>([applying, logout]);
    expect(p.flow.snapshot.phase, ConversationSessionPhase.revoked);
    expect(backend.value, isNull);
    expect(p.port.calls, hasLength(1));
  });
  for (final lateError in [false, true]) {
    test(
      'actual wire drain required before application lateError=$lateError',
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
        await expectLater(
          flow.start(f.start()),
          throwsA(f.code(AiTextErrorCode.networkUnavailable)),
        );
        final c = await h.completion(auth, h.command(h.operations.first));
        final backend = h.Backend(
          h.command(h.operations.first).reference.encode(),
        );
        final storage = h.store(backend);
        final before = flow.snapshot;
        expect(
          await flow.applyRetainedCompletion(c.handle, store: storage),
          isFalse,
        );
        expect(backend.calls, isEmpty);
        expect(flow.snapshot, same(before));
        if (lateError) {
          wire.completeError(StateError('PRIVATE_LATE'));
        } else {
          wire.complete(f.response(h.operations.first));
        }
        await f.settle();
        expect(
          await flow.applyRetainedCompletion(c.handle, store: storage),
          isTrue,
        );
        expect(flow.snapshot.phase, ConversationSessionPhase.active);
        expect(port.calls, hasLength(1));
      },
    );
  }
  test(
    'session final readiness after lane release can revoke publication',
    () async {
      var armed = false;
      var reached = false;
      late CapturedConversationSession flow;
      final p = await pending(
        h.operations.first,
        ready: () {
          if (armed && !flow.hasUnresolvedMutation) {
            armed = false;
            reached = true;
            flow.revoke();
          }
          return true;
        },
      );
      flow = p.flow;
      final c = await h.completion(p.auth, h.command(h.operations.first));
      final backend = h.Backend(
        h.command(h.operations.first).reference.encode(),
      )..afterClear = () => armed = true;
      expect(
        await flow.applyRetainedCompletion(c.handle, store: h.store(backend)),
        isFalse,
      );
      expect(reached, isTrue);
      expect(backend.value, isNull);
      expect(flow.snapshot.phase, ConversationSessionPhase.revoked);
      expect(flow.snapshot.messages, isEmpty);
      expect(p.port.calls, hasLength(1));
    },
  );
  test(
    'session final readiness reentry sees no partial projection or command authority',
    () async {
      var armed = false;
      late CapturedConversationSession flow;
      late CapturedConversationCompletion handle;
      late ConversationReceiptStore storage;
      Future<void>? nestedCommand;
      Future<bool>? nestedApply;
      final p = await pending(
        h.operations.first,
        ready: () {
          if (armed && !flow.hasUnresolvedMutation) {
            armed = false;
            nestedCommand = expectLater(
              flow.turn(f.turn()),
              throwsA(isA<AiTextRequestPending>()),
            );
            nestedApply = flow.applyRetainedCompletion(handle, store: storage);
            expect(flow.retainedCommand, isNull);
            expect(flow.previewRetainedCompletion(handle), isNull);
          }
          return true;
        },
      );
      flow = p.flow;
      final c = await h.completion(p.auth, h.command(h.operations.first));
      handle = c.handle;
      final backend = h.Backend(
        h.command(h.operations.first).reference.encode(),
      )..afterClear = () => armed = true;
      storage = h.store(backend);
      expect(
        await flow.applyRetainedCompletion(handle, store: storage),
        isTrue,
      );
      await nestedCommand;
      expect(await nestedApply, isFalse);
      expect(flow.snapshot.phase, ConversationSessionPhase.active);
      expect(flow.snapshot.messages, hasLength(1));
      expect(p.port.calls, hasLength(1));
    },
  );
}
