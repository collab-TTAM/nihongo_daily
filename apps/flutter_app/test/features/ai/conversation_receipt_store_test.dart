// TEST ONLY memory port. Not a production storage fallback or OS/JWT proof.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/data/conversation_receipt_store.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_reference.dart';

const _project = 'https://receipt-store.supabase.invalid';
const _owner = 'a1000000-0000-4000-8000-000000000001';
const _other = 'a1000000-0000-4000-8000-000000000002';
const _event = 'b1000000-0000-4000-8000-000000000001';
const _next = 'b1000000-0000-4000-8000-000000000002';
ConversationReceiptScope _scope({
  String project = _project,
  String owner = _owner,
}) => ConversationReceiptScope(projectUrl: project, ownerId: owner);
ConversationReceiptReference _reference({
  String project = _project,
  String owner = _owner,
  String event = _event,
  bool finish = false,
}) => finish
    ? ConversationReceiptReference.fromFinish(
        projectUrl: project,
        ownerId: owner,
        request: FinishConversationRequest(
          sessionId: _owner,
          clientEventId: event,
        ),
      )
    : ConversationReceiptReference.fromStart(
        projectUrl: project,
        ownerId: owner,
        request: StartConversationRequest(
          scenarioId: _owner,
          level: AiTextLevel.n5,
          clientEventId: event,
        ),
      );

Matcher _error(ConversationReceiptStoreError code) =>
    isA<ConversationReceiptStoreFailure>()
        .having((e) => e.code, 'fixed code', code)
        .having(
          (e) => e.toString().contains('PRIVATE'),
          'no backend input',
          false,
        )
        .having((e) => e.toString().contains(_owner), 'no owner', false);

final class _Backend implements SecureConversationReceiptBackend {
  final values = <String, Object?>{};
  final calls = <String>[];
  Completer<void>? readWait;
  Completer<void>? writeWait;
  Completer<void>? clearWait;
  final writeEntered = Completer<void>();
  final readEntered = Completer<void>();
  bool failRead = false;
  bool failWrite = false;
  bool ambiguousWrite = false;
  bool failClear = false;
  @override
  Future<Object?> read(String target) async {
    calls.add('read');
    if (!readEntered.isCompleted) readEntered.complete();
    await readWait?.future;
    if (failRead) throw StateError('TEST_ONLY_PRIVATE_READ');
    return values[target];
  }

  @override
  Future<void> write(String target, String encoded) async {
    calls.add('write-begin');
    if (!writeEntered.isCompleted) writeEntered.complete();
    await writeWait?.future;
    if (failWrite) {
      if (ambiguousWrite) values[target] = encoded;
      throw StateError('TEST_ONLY_PRIVATE_WRITE');
    }
    values[target] = encoded;
    calls.add('write-end');
  }

  @override
  Future<void> clear(String target) async {
    calls.add('clear-begin');
    await clearWait?.future;
    if (failClear) throw StateError('TEST_ONLY_PRIVATE_CLEAR');
    values.remove(target);
    calls.add('clear-end');
  }

  void release() {
    for (final wait in [readWait, writeWait, clearWait]) {
      if (wait != null && !wait.isCompleted) wait.complete();
    }
  }
}

ConversationReceiptStore _open(
  _Backend backend, {
  ConversationReceiptScope? scope,
}) {
  final store = ConversationReceiptStore(
    scope: scope ?? _scope(),
    backend: backend,
  );
  addTearDown(() async {
    backend.release();
    await store.close();
  });
  return store;
}

String _target({String project = _project, String owner = _owner}) =>
    '${ConversationReceiptStore.targetPrefix}$project|${owner.toLowerCase()}';

void main() {
  test(
    'reserve keeps one exact original reference and never overwrites uncertainty',
    () async {
      final backend = _Backend();
      final store = _open(backend);
      expect(await store.read(), isNull);
      final original = _reference();
      await store.reserve(original);
      expect(backend.values[_target()], original.encode());
      await store.reserve(
        ConversationReceiptReference.decode(original.encode()),
      );
      expect(backend.calls.where((c) => c == 'write-begin'), hasLength(1));
      for (final alternative in [
        _reference(event: _next),
        _reference(finish: true),
      ]) {
        await expectLater(
          store.reserve(alternative),
          throwsA(_error(ConversationReceiptStoreError.conflict)),
        );
        expect(backend.values[_target()], original.encode());
      }
      expect((await store.read())!.encode(), original.encode());
      expect(store.phase, ConversationReceiptStorePhase.open);
    },
  );

  test(
    'scope canonicalizes only partition metadata and isolates owner project and namespace',
    () async {
      final backend = _Backend();
      final scope = _scope(
        project: 'HTTPS://RECEIPT-STORE.SUPABASE.INVALID:443/',
        owner: _owner.toUpperCase(),
      );
      final store = _open(backend, scope: scope);
      expect(scope.ownerId, _owner);
      expect(scope.contains(_reference(owner: _owner.toUpperCase())), isTrue);
      expect(_reference().scope.projectOrigin, scope.projectOrigin);
      expect(_reference().scope.ownerId, scope.ownerId);
      expect(scope.toString(), 'ConversationReceiptScope');
      expect(
        () => ConversationReceiptStore(scope: _scope(), backend: _Backend()),
        throwsA(_error(ConversationReceiptStoreError.owned)),
      );
      for (final foreign in [
        _reference(owner: _other),
        _reference(project: '$_project:444'),
      ]) {
        await expectLater(
          store.reserve(foreign),
          throwsA(_error(ConversationReceiptStoreError.scope)),
        );
      }
      expect(backend.calls, isEmpty);
      final other = _open(backend, scope: _scope(owner: _other));
      await other.reserve(_reference(owner: _other));
      final port = _open(backend, scope: _scope(project: '$_project:444'));
      await port.reserve(_reference(project: '$_project:444'));
      await store.reserve(_reference());
      expect(backend.values, hasLength(3));
      expect(
        backend.values.keys.every(
          (key) => key.startsWith(ConversationReceiptStore.targetPrefix),
        ),
        isTrue,
      );
      expect(
        backend.values.keys.any(
          (key) => key.startsWith('NihongoDaily.Refresh.'),
        ),
        isFalse,
      );
    },
  );

  test(
    'corrupt wrong-scope noncanonical token and nonstring storage fail closed without deletion',
    () async {
      for (final value in <Object?>[
        1,
        true,
        <Object?>[],
        'TEST_ONLY_PRIVATE_TOKEN',
        '${_reference().encode()} ',
        _reference(owner: _other).encode(),
      ]) {
        final backend = _Backend()..values[_target()] = value;
        final store = _open(backend);
        await expectLater(
          store.read(),
          throwsA(_error(ConversationReceiptStoreError.corrupt)),
        );
        expect(store.phase, ConversationReceiptStorePhase.failed);
        await expectLater(
          store.reserve(_reference()),
          throwsA(_error(ConversationReceiptStoreError.unavailable)),
        );
        expect(backend.calls, ['read']);
        expect(backend.values[_target()], value);
        await store.close();
      }
    },
  );

  for (final writing in [false, true]) {
    test(
      'backend failure is fixed and forbids fallback or reuse writing=$writing',
      () async {
        final backend = _Backend()
          ..failRead = !writing
          ..failWrite = writing;
        final store = _open(backend);
        await expectLater(
          store.reserve(_reference()),
          throwsA(_error(ConversationReceiptStoreError.unavailable)),
        );
        final calls = List<String>.from(backend.calls);
        expect(store.phase, ConversationReceiptStorePhase.failed);
        await expectLater(
          store.read(),
          throwsA(_error(ConversationReceiptStoreError.unavailable)),
        );
        expect(backend.calls, calls);
        expect(backend.values, isEmpty);
        backend.failRead = false;
        backend.failWrite = false;
        await store.clearForSignOut();
        await store.close();
        final fresh = _open(backend);
        expect(await fresh.read(), isNull);
        await fresh.reserve(_reference());
        expect(backend.values[_target()], _reference().encode());
      },
    );
  }

  test(
    'signout revokes now and orders clear after actual late write and queued work',
    () async {
      final backend = _Backend()..writeWait = Completer<void>();
      final store = _open(backend);
      final writing = expectLater(
        store.reserve(_reference()),
        throwsA(_error(ConversationReceiptStoreError.revoked)),
      );
      await backend.writeEntered.future;
      final queued = expectLater(
        store.reserve(_reference(event: _next)),
        throwsA(_error(ConversationReceiptStoreError.revoked)),
      );
      final clearing = store.clearForSignOut();
      expect(store.phase, ConversationReceiptStorePhase.revoked);
      expect(store.clearForSignOut(), same(clearing));
      final reading = expectLater(
        store.read(),
        throwsA(_error(ConversationReceiptStoreError.revoked)),
      );
      expect(backend.calls, ['read', 'write-begin']);
      backend.writeWait!.complete();
      await Future.wait<void>([writing, queued, reading, clearing]);
      expect(backend.calls, [
        'read',
        'write-begin',
        'write-end',
        'clear-begin',
        'clear-end',
      ]);
      expect(backend.values, isEmpty);
      await expectLater(
        store.reserve(_reference()),
        throwsA(_error(ConversationReceiptStoreError.revoked)),
      );
    },
  );

  test(
    'close preserves pending metadata and ownership until late write actually drains',
    () async {
      final backend = _Backend()..writeWait = Completer<void>();
      final store = _open(backend);
      final writing = expectLater(
        store.reserve(_reference()),
        throwsA(_error(ConversationReceiptStoreError.revoked)),
      );
      await backend.writeEntered.future;
      final closing = store.close();
      expect(store.close(), same(closing));
      expect(store.phase, ConversationReceiptStorePhase.revoked);
      expect(
        () => ConversationReceiptStore(scope: _scope(), backend: backend),
        throwsA(_error(ConversationReceiptStoreError.owned)),
      );
      backend.writeWait!.complete();
      await writing;
      await closing;
      expect(store.phase, ConversationReceiptStorePhase.closed);
      expect(backend.values[_target()], _reference().encode());
      expect(backend.calls, ['read', 'write-begin', 'write-end']);
      final fresh = _open(backend);
      expect((await fresh.read())!.encode(), _reference().encode());
      await expectLater(
        fresh.reserve(_reference(event: _next)),
        throwsA(_error(ConversationReceiptStoreError.conflict)),
      );
    },
  );

  test(
    'late read cannot publish after close or release the owner before drain',
    () async {
      final backend = _Backend()
        ..values[_target()] = _reference().encode()
        ..readWait = Completer<void>();
      final store = _open(backend);
      final reading = expectLater(
        store.read(),
        throwsA(_error(ConversationReceiptStoreError.revoked)),
      );
      await backend.readEntered.future;
      final closing = store.close();
      expect(
        () => ConversationReceiptStore(scope: _scope(), backend: backend),
        throwsA(_error(ConversationReceiptStoreError.owned)),
      );
      backend.readWait!.complete();
      await reading;
      await closing;
      final fresh = _open(backend);
      expect((await fresh.read())!.clientEventId, _event);
      expect(backend.calls, ['read', 'read']);
    },
  );

  test(
    'failed clear remains revoked and explicit retry never reopens access',
    () async {
      final backend = _Backend()
        ..values[_target()] = _reference().encode()
        ..failClear = true;
      final store = _open(backend);
      await expectLater(
        store.clearForSignOut(),
        throwsA(_error(ConversationReceiptStoreError.unavailable)),
      );
      expect(backend.values[_target()], _reference().encode());
      expect(store.phase, ConversationReceiptStorePhase.revoked);
      backend.failClear = false;
      await store.clearForSignOut();
      expect(backend.values, isEmpty);
      await expectLater(
        store.read(),
        throwsA(_error(ConversationReceiptStoreError.revoked)),
      );
      expect(store.toString(), 'ConversationReceiptStore');
    },
  );

  test(
    'queued reserves serialize and cannot replace the first pending receipt',
    () async {
      final backend = _Backend()..writeWait = Completer<void>();
      final store = _open(backend);
      final first = store.reserve(_reference());
      await backend.writeEntered.future;
      final next = expectLater(
        store.reserve(_reference(event: _next)),
        throwsA(_error(ConversationReceiptStoreError.conflict)),
      );
      backend.writeWait!.complete();
      await first;
      await next;
      expect(backend.calls, ['read', 'write-begin', 'write-end', 'read']);
      expect(backend.values[_target()], _reference().encode());
    },
  );

  test(
    'signout still clears an ambiguous failed write after its actual completion',
    () async {
      final backend = _Backend()
        ..writeWait = Completer<void>()
        ..failWrite = true
        ..ambiguousWrite = true;
      final store = _open(backend);
      final writing = expectLater(
        store.reserve(_reference()),
        throwsA(_error(ConversationReceiptStoreError.unavailable)),
      );
      await backend.writeEntered.future;
      final clearing = store.clearForSignOut();
      expect(backend.calls, ['read', 'write-begin']);
      backend.writeWait!.complete();
      await writing;
      await clearing;
      expect(backend.calls, [
        'read',
        'write-begin',
        'clear-begin',
        'clear-end',
      ]);
      expect(backend.values, isEmpty);
      expect(store.phase, ConversationReceiptStorePhase.revoked);
    },
  );
}
