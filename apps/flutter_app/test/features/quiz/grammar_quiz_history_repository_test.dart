// TEST ONLY Auth/held result ports around a real native journal; not hosted proof.
import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/quiz/data/grammar_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/data/grammar_quiz_history_repository.dart';
import 'package:nihongo_daily/features/quiz/data/native_grammar_quiz_journal.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz_attempt.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'native_grammar_quiz_journal_test.dart' show ownerA, ownerB, attempt;

final class _Auth implements ReviewAuth {
  ReviewSession? session = ReviewSession(userId: ownerA);
  void Function()? onRead;
  @override
  ReviewSession? get currentSession {
    onRead?.call();
    return session;
  }
}

final class _Store implements GrammarQuizAttemptStore {
  _Store(this.inner);
  final NativeGrammarQuizJournal inner;
  var appends = 0;
  var lists = 0;
  Completer<void>? gate;
  Completer<void> entered = Completer<void>();
  Object? fault;
  void Function()? onAppend;
  OwnedGrammarQuizAttempt? returned;
  List<OwnedGrammarQuizAttempt>? rows;
  void hold() {
    gate = Completer<void>();
    entered = Completer<void>();
  }

  Future<void> settle() async {
    if (!entered.isCompleted) entered.complete();
    await gate?.future;
    if (fault != null) throw fault!;
  }

  @override
  Future<OwnedGrammarQuizAttempt> append(
    String ownerId,
    GrammarQuizAttempt attempt,
  ) async {
    appends++;
    onAppend?.call();
    final result = await inner.append(ownerId, attempt);
    await settle();
    return returned ?? result;
  }

  @override
  Future<List<OwnedGrammarQuizAttempt>> list(String ownerId) async {
    lists++;
    final result = await inner.list(ownerId);
    await settle();
    return rows ?? result;
  }
}

final class _ChangingList extends ListBase<OwnedGrammarQuizAttempt> {
  _ChangingList(this.record, this.onRead);
  final OwnedGrammarQuizAttempt record;
  final void Function() onRead;
  @override
  int get length => 1;
  @override
  set length(int value) => throw UnsupportedError('TEST ONLY immutable');
  @override
  OwnedGrammarQuizAttempt operator [](int index) {
    onRead();
    return record;
  }

  @override
  void operator []=(int index, OwnedGrammarQuizAttempt value) =>
      throw UnsupportedError('TEST ONLY immutable');
}

void main() {
  late Directory directory;
  late NativeGrammarQuizJournal journal;
  late _Store store;
  late _Auth auth;
  late GrammarQuizOperationDrain operations;
  var ready = true;
  void Function()? onReady;
  GrammarQuizHistoryRepository make() => GrammarQuizHistoryRepository(
    auth: auth,
    store: store,
    isReady: () {
      onReady?.call();
      return ready;
    },
    operations: operations,
  );
  final changed = isA<GrammarQuizSessionChanged>();
  final storageFailure = isA<GrammarQuizStorageFailure>();
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nd-grammar-captured-');
    journal = await NativeGrammarQuizJournal.open(directory);
    store = _Store(journal);
    auth = _Auth();
    operations = GrammarQuizOperationDrain();
    ready = true;
    onReady = null;
  });
  tearDown(() async {
    if (store.gate != null && !store.gate!.isCompleted) store.gate!.complete();
    await operations.revokeAndDrain();
    await journal.close();
    await directory.delete(recursive: true);
  });

  test(
    'captured grammar saves primary correction and isolates current owner',
    () async {
      final a = make();
      await a.save(attempt(0));
      await a.save(attempt(1));
      final records = await a.load();
      expect(records.map((r) => r.attempt.score).toList(), [1, 0]);
      expect(records.every((r) => r.ownerId == ownerA), isTrue);
      expect(() => records.clear(), throwsUnsupportedError);
      auth.session = ReviewSession(userId: ownerB);
      await expectLater(a.load(), throwsA(changed));
      final b = make();
      expect(await b.load(), isEmpty);
      await b.save(attempt(0));
      expect((await b.load()).single.ownerId, ownerB);
      expect(await journal.list(ownerA), hasLength(2));
      expect(await journal.list(ownerB), hasLength(1));
    },
  );

  test(
    'captured grammar coalesces identical in-flight event and rejects conflict',
    () async {
      final repo = make();
      store.hold();
      final first = repo.save(attempt(0));
      final second = repo.save(
        GrammarQuizAttempt.fromJson(attempt(0).toJson()),
      );
      expect(identical(first, second), isTrue);
      final conflict = GrammarQuizAttempt.fromJson(
        attempt(0).toJson()..['practice_kind'] = 'correction',
      );
      await expectLater(
        repo.save(conflict),
        throwsA(isA<GrammarQuizHistoryConflict>()),
      );
      await store.entered.future;
      expect(store.appends, 1);
      store.gate!.complete();
      await first;
      await second;
      await repo.save(attempt(0));
      expect(await journal.list(ownerA), hasLength(1));
    },
  );

  test(
    'captured grammar registers event before a storage callback reenters save',
    () async {
      final repo = make();
      Future<OwnedGrammarQuizAttempt>? nested;
      store.onAppend = () {
        nested = repo.save(attempt(0));
      };
      final outer = repo.save(attempt(0));
      await outer;
      expect(identical(outer, nested), isTrue);
      expect(store.appends, 1);
      expect(await journal.list(ownerA), hasLength(1));
    },
  );

  for (final operation in ['save', 'load']) {
    for (final outcome in ['success', 'private error']) {
      test(
        'captured grammar fences late $operation $outcome through A B A',
        () async {
          await journal.append(ownerA, attempt(0));
          final old = make();
          store.hold();
          final Future<Object?> pending = operation == 'save'
              ? old.save(attempt(1))
              : old.load();
          final rejected = expectLater(pending, throwsA(changed));
          await store.entered.future;
          auth.session = ReviewSession(userId: ownerB);
          if (outcome == 'private error') {
            store.fault = StateError('TEST ONLY PRIVATE');
          }
          store.gate!.complete();
          await rejected;
          final calls = store.appends + store.lists;
          store.fault = null;
          await expectLater(old.load(), throwsA(changed));
          expect(store.appends + store.lists, calls);
          expect(await make().load(), isEmpty);
          auth.session = ReviewSession(userId: ownerA);
          await expectLater(old.load(), throwsA(changed));
          expect(await make().load(), hasLength(operation == 'save' ? 2 : 1));
        },
      );
    }
  }

  for (final operation in ['save', 'load']) {
    test(
      'captured grammar rejects replaced session before scheduled $operation dispatch',
      () async {
        final repo = make();
        final Future<Object?> pending = operation == 'save'
            ? repo.save(attempt(0))
            : repo.load();
        auth.session = ReviewSession(userId: ownerA);
        await expectLater(pending, throwsA(changed));
        expect(store.appends + store.lists, 0);
      },
    );
  }

  test(
    'captured grammar drain revokes immediately and waits accepted storage',
    () async {
      final repo = make();
      store.hold();
      final saving = repo.save(attempt(0));
      final rejected = expectLater(saving, throwsA(changed));
      await store.entered.future;
      var drained = false;
      final drain = operations.revokeAndDrain().then((_) => drained = true);
      expect(operations.isClosing, isTrue);
      await expectLater(repo.load(), throwsA(changed));
      expect(drained, isFalse);
      expect(store.appends, 1);
      expect(store.lists, 0);
      store.gate!.complete();
      await rejected;
      await drain;
      expect(drained, isTrue);
      expect(await journal.list(ownerA), hasLength(1));
      expect(() => make(), throwsA(changed));
    },
  );

  for (final port in ['readiness', 'Auth']) {
    test(
      'captured grammar rejects nested checks without revoking healthy $port operation',
      () async {
        final repo = make();
        var invoked = false;
        late Future<void> nested;
        void reenter() {
          if (invoked) return;
          invoked = true;
          nested = expectLater(repo.load(), throwsA(changed));
        }

        if (port == 'readiness') {
          onReady = reenter;
        } else {
          auth.onRead = reenter;
        }
        await repo.save(attempt(0));
        await nested;
        expect(invoked, isTrue);
        expect(store.appends, 1);
        expect(store.lists, 0);
        onReady = null;
        auth.onRead = null;
        expect(await repo.load(), hasLength(1));
      },
    );
  }

  for (final port in ['readiness', 'Auth']) {
    test(
      'captured grammar rechecks session changed inside $port getter',
      () async {
        final repo = make();
        void replace() => auth.session = ReviewSession(userId: ownerB);
        if (port == 'readiness') {
          onReady = replace;
        } else {
          auth.onRead = replace;
        }
        await expectLater(repo.save(attempt(0)), throwsA(changed));
        expect(store.appends + store.lists, 0);
        onReady = null;
        auth.onRead = null;
        auth.session = ReviewSession(userId: ownerA);
        await expectLater(repo.load(), throwsA(changed));
        expect(await make().load(), isEmpty);
      },
    );
  }

  test(
    'captured grammar rejects unready absent or throwing Auth before storage',
    () async {
      ready = false;
      expect(() => make(), throwsA(changed));
      ready = true;
      auth.session = null;
      expect(() => make(), throwsA(changed));
      auth.onRead = () => throw StateError('TEST ONLY PRIVATE');
      expect(() => make(), throwsA(changed));
      expect(store.appends + store.lists, 0);
    },
  );

  test(
    'captured grammar redacts raw storage errors and allows explicit healthy retry',
    () async {
      final repo = make();
      store.fault = StateError('TEST ONLY PRIVATE PATH');
      await expectLater(repo.load(), throwsA(storageFailure));
      store.fault = null;
      await repo.save(attempt(0));
      expect(await repo.load(), hasLength(1));
      store.returned = OwnedGrammarQuizAttempt(ownerB, attempt(1));
      await expectLater(repo.save(attempt(1)), throwsA(storageFailure));
      store.returned = OwnedGrammarQuizAttempt(ownerA, attempt(1));
      await expectLater(repo.save(attempt(0)), throwsA(storageFailure));
      store.returned = null;
      expect(await repo.load(), hasLength(2));
    },
  );

  test(
    'captured grammar validates sorts and deduplicates returned records',
    () async {
      final repo = make();
      final zero = OwnedGrammarQuizAttempt(ownerA, attempt(0));
      final one = OwnedGrammarQuizAttempt(ownerA, attempt(1));
      store.rows = [one, zero, zero];
      final rows = await repo.load();
      expect(rows.map((r) => r.attempt.eventId).toList(), [
        zero.attempt.eventId,
        one.attempt.eventId,
      ]);
      expect(() => rows.clear(), throwsUnsupportedError);
      store.rows = [OwnedGrammarQuizAttempt(ownerB, attempt(0))];
      await expectLater(repo.load(), throwsA(storageFailure));
      store.rows = List.filled(10001, zero);
      await expectLater(repo.load(), throwsA(storageFailure));
      store.rows = [
        zero,
        OwnedGrammarQuizAttempt(
          ownerA,
          GrammarQuizAttempt.fromJson(
            attempt(0).toJson()..['practice_kind'] = 'correction',
          ),
        ),
      ];
      await expectLater(
        repo.load(),
        throwsA(isA<GrammarQuizHistoryConflict>()),
      );
      store.rows = null;
      expect(await repo.load(), isEmpty);
    },
  );
  test(
    'captured grammar rechecks owner after result validation callbacks',
    () async {
      final repo = make();
      store.rows = _ChangingList(
        OwnedGrammarQuizAttempt(ownerA, attempt(0)),
        () => auth.session = ReviewSession(userId: ownerB),
      );
      await expectLater(repo.load(), throwsA(changed));
      expect(store.lists, 1);
      expect(store.appends, 0);
      store.rows = null;
      expect(await make().load(), isEmpty);
    },
  );
}
