// TEST ONLY ports, not actual Windows/Auth/hosted provider proof.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/data/conversation_receipt_dispatch.dart';
import 'package:nihongo_daily/features/ai/data/conversation_receipt_store.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_reference.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

const owner = 'a1000000-0000-4000-8000-000000000001';
const event = 'b1000000-0000-4000-8000-000000000001';
const origin = 'https://dispatch.supabase.invalid';
final reference = ConversationReceiptReference.fromStart(
  projectUrl: origin,
  ownerId: owner,
  request: StartConversationRequest(
    scenarioId: owner,
    level: AiTextLevel.n5,
    clientEventId: event,
  ),
);
Matcher failure(ReceiptDispatchError code) => isA<ReceiptDispatchFailure>()
    .having((e) => e.code, 'code', code)
    .having((e) => e.toString().contains('PRIVATE'), 'safe', false);

final class Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(userId: owner);
}

final class Backend implements SecureConversationReceiptBackend {
  Object? value;
  final calls = <String>[];
  final entered = Completer<void>();
  Completer<void>? writeWait;
  bool failRead = false;
  bool failWrite = false;
  @override
  Future<Object?> read(String target) async {
    calls.add('read');
    if (failRead) throw StateError('PRIVATE_READ');
    return value;
  }

  @override
  Future<void> write(String target, String encoded) async {
    calls.add('write-begin');
    entered.complete();
    await writeWait?.future;
    if (failWrite) throw StateError('PRIVATE_WRITE');
    value = encoded;
    calls.add('write-end');
  }

  @override
  Future<void> clear(String target) async {
    calls.add('clear');
    value = null;
  }
}

void main() {
  late Backend backend;
  late Auth auth;
  late ConversationReceiptStore store;
  var ready = true;
  var wires = 0;
  ConversationReceiptDispatch<String> gate({
    Future<String> Function(ReviewSession)? dispatch,
    bool Function()? check,
  }) => ConversationReceiptDispatch(
    store: store,
    reference: reference,
    auth: auth,
    capturedSession: auth.currentSession!,
    isReady: check ?? () => ready,
    dispatch:
        dispatch ??
        (session) async {
          wires++;
          expect(identical(session, auth.currentSession), true);
          expect(backend.value, reference.encode());
          return 'accepted';
        },
  );
  setUp(() {
    backend = Backend();
    auth = Auth();
    ready = true;
    wires = 0;
    store = ConversationReceiptStore(scope: reference.scope, backend: backend);
    addTearDown(store.close);
  });
  test(
    'confirmed receipt precedes one explicit dispatch and close preserves it',
    () async {
      final g = gate();
      expect(await g.submit(), 'accepted');
      expect(wires, 1);
      expect(backend.calls, ['read', 'read', 'write-begin', 'write-end']);
      await expectLater(
        g.submit(),
        throwsA(failure(ReceiptDispatchError.conflict)),
      );
      await g.close();
      expect(backend.value, reference.encode());
      expect(backend.calls.contains('clear'), false);
    },
  );
  for (final old in [
    reference.encode(),
    reference.encode().replaceFirst(event, owner),
  ]) {
    test('preexisting metadata never grants redispatch $old', () async {
      backend.value = old;
      await expectLater(
        gate().submit(),
        throwsA(failure(ReceiptDispatchError.conflict)),
      );
      expect(wires, 0);
      expect(backend.value, old);
      expect(backend.calls, ['read']);
    });
  }
  for (final write in [false, true]) {
    test('storage failure stops wire write=$write', () async {
      backend.failRead = !write;
      backend.failWrite = write;
      final g = gate();
      await expectLater(
        g.submit(),
        throwsA(failure(ReceiptDispatchError.unavailable)),
      );
      expect(wires, 0);
      await expectLater(
        g.submit(),
        throwsA(failure(ReceiptDispatchError.conflict)),
      );
    });
  }
  for (final change in [
    'revoke',
    'readiness',
    'same-account',
    'other-account',
    'A-B-A',
  ]) {
    test('late persisted write cannot cross $change', () async {
      backend.writeWait = Completer<void>();
      final g = gate();
      final result = expectLater(
        g.submit(),
        throwsA(failure(ReceiptDispatchError.unauthorized)),
      );
      await backend.entered.future;
      if (change == 'revoke') {
        g.revoke();
      } else if (change == 'readiness') {
        ready = false;
      } else if (change == 'same-account') {
        auth.currentSession = ReviewSession(userId: owner);
      } else {
        auth.currentSession = ReviewSession(userId: event);
        if (change == 'A-B-A') {
          auth.currentSession = ReviewSession(userId: owner);
        }
      }
      expect(wires, 0);
      backend.writeWait!.complete();
      await result;
      await g.close();
      expect(backend.value, reference.encode());
      expect(wires, 0);
      expect(backend.calls.contains('clear'), false);
    });
  }
  for (final error in [false, true]) {
    test(
      'close waits actual wire and redacts late result error=$error',
      () async {
        final wire = Completer<String>();
        final entered = Completer<void>();
        final g = gate(
          dispatch: (_) {
            wires++;
            entered.complete();
            return wire.future;
          },
        );
        final result = expectLater(
          g.submit(),
          throwsA(failure(ReceiptDispatchError.unauthorized)),
        );
        await entered.future;
        var closed = false;
        final closing = g.close().then((_) {
          closed = true;
        });
        await Future<void>.delayed(Duration.zero);
        expect(closed, false);
        if (error) {
          wire.completeError(StateError('PRIVATE_HTTP'));
        } else {
          wire.complete('PRIVATE_OLD_SUCCESS');
        }
        await result;
        await closing;
        expect(wires, 1);
        expect(backend.value, reference.encode());
      },
    );
  }
  test(
    'readiness getter reentrant close cannot escape registered actual drain',
    () async {
      late ConversationReceiptDispatch<String> g;
      Future<void>? closing;
      var closed = false;
      g = gate(
        check: () {
          closing ??= g.close().then((_) {
            closed = true;
          });
          expect(closed, false);
          return true;
        },
      );
      await expectLater(
        g.submit(),
        throwsA(failure(ReceiptDispatchError.unauthorized)),
      );
      await closing;
      expect(closed, true);
      expect(backend.calls, isEmpty);
      expect(wires, 0);
    },
  );
  test(
    'reentrant submit is rejected before getter can duplicate dispatch',
    () async {
      late ConversationReceiptDispatch<String> g;
      Future<void>? duplicate;
      g = gate(
        check: () {
          duplicate ??= expectLater(
            g.submit(),
            throwsA(failure(ReceiptDispatchError.conflict)),
          );
          return true;
        },
      );
      expect(await g.submit(), 'accepted');
      await duplicate;
      expect(wires, 1);
    },
  );
  test('private getter errors stay fixed', () async {
    await expectLater(
      gate(check: () => throw StateError('PRIVATE')).submit(),
      throwsA(failure(ReceiptDispatchError.unauthorized)),
    );
  });
  test('private dispatch errors stay fixed', () async {
    await expectLater(
      gate(dispatch: (_) async => throw StateError('PRIVATE')).submit(),
      throwsA(failure(ReceiptDispatchError.unavailable)),
    );
  });
  test(
    'two gates borrowing one store cannot both pass an empty read',
    () async {
      backend.writeWait = Completer<void>();
      final first = gate();
      final second = gate();
      final sent = first.submit();
      await backend.entered.future;
      await expectLater(
        second.submit(),
        throwsA(failure(ReceiptDispatchError.conflict)),
      );
      expect(backend.calls, ['read', 'read', 'write-begin']);
      backend.writeWait!.complete();
      expect(await sent, 'accepted');
      expect(wires, 1);
      await first.close();
      await expectLater(
        gate().submit(),
        throwsA(failure(ReceiptDispatchError.conflict)),
      );
      expect(wires, 1);
    },
  );
  test('foreign captured owner is rejected before any I/O', () {
    expect(
      () => ConversationReceiptDispatch<String>(
        store: store,
        reference: reference,
        auth: auth,
        capturedSession: ReviewSession(userId: event),
        isReady: () => true,
        dispatch: (_) async {
          wires++;
          return 'wrong';
        },
      ),
      throwsA(failure(ReceiptDispatchError.unauthorized)),
    );
    expect(backend.calls, isEmpty);
    expect(wires, 0);
  });
}
