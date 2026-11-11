import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/srs/data/browser_review_store.dart';
import 'package:nihongo_daily/features/srs/data/durable_review_repository.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/data/transactional_review_store.dart';
import 'package:nihongo_daily/features/srs/data/review_receipt_retention.dart';
import 'package:nihongo_daily/features/srs/domain/srs_models.dart';

import 'transactional_review_fixtures.dart' as fixture;
import 'receipt_retention_fixtures.dart' as retention;

@JS('indexedDB')
external _TestIndexedDbFactory? get _testIndexedDb;

extension type _TestIndexedDbFactory(JSObject _) implements JSObject {
  external _TestOpenRequest open(String name, int version);
}

extension type _TestRequest(JSObject _) implements JSObject {
  external JSAny? get result;
  external set onsuccess(JSFunction listener);
  external set onerror(JSFunction listener);
}

extension type _TestOpenRequest(JSObject _) implements _TestRequest {
  external set onblocked(JSFunction listener);
}

extension type _TestDatabase(JSObject _) implements JSObject {
  external _TestTransaction transaction(String store, String mode);
  external void close();
}

extension type _TestTransaction(JSObject _) implements JSObject {
  external _TestObjectStore objectStore(String name);
  external set oncomplete(JSFunction listener);
  external set onabort(JSFunction listener);
  external set onerror(JSFunction listener);
}

extension type _TestObjectStore(JSObject _) implements JSObject {
  external _TestRequest put(JSAny value, JSAny key);

  @JS('get')
  external _TestRequest read(JSAny key);
}

Future<_TestDatabase> _openTestDatabase(String name) async {
  final factory = _testIndexedDb;
  if (factory == null) throw StateError('IndexedDB unavailable in test');
  final opened = Completer<_TestDatabase>();
  final request = factory.open(name, 1);

  void fail() {
    if (!opened.isCompleted) {
      opened.completeError(StateError('IndexedDB test open failed'));
    }
  }

  request.onblocked = ((JSAny? _) {
    fail();
  }).toJS;
  request.onerror = ((JSAny? _) {
    fail();
  }).toJS;
  request.onsuccess = ((JSAny? _) {
    try {
      final database = _TestDatabase(request.result! as JSObject);
      if (opened.isCompleted) {
        database.close();
      } else {
        opened.complete(database);
      }
    } on Object {
      fail();
    }
  }).toJS;
  return opened.future;
}

Future<void> _writeRawState(String name, String raw) async {
  final database = await _openTestDatabase(name);
  try {
    final committed = Completer<void>();
    final transaction = database.transaction('journal', 'readwrite');

    void fail() {
      if (!committed.isCompleted) {
        committed.completeError(StateError('IndexedDB test write failed'));
      }
    }

    transaction.oncomplete = ((JSAny? _) {
      if (!committed.isCompleted) committed.complete();
    }).toJS;
    transaction.onabort = ((JSAny? _) {
      fail();
    }).toJS;
    transaction.onerror = ((JSAny? _) {
      fail();
    }).toJS;
    transaction.objectStore('journal').put(raw.toJS, 'state'.toJS);
    await committed.future;
  } finally {
    database.close();
  }
}

Future<String?> _readRawState(String name) async {
  final database = await _openTestDatabase(name);
  try {
    final committed = Completer<String?>();
    final transaction = database.transaction('journal', 'readonly');
    var read = false;
    String? value;

    void fail() {
      if (!committed.isCompleted) {
        committed.completeError(StateError('IndexedDB test read failed'));
      }
    }

    transaction.oncomplete = ((JSAny? _) {
      if (committed.isCompleted) return;
      if (read) {
        committed.complete(value);
      } else {
        fail();
      }
    }).toJS;
    transaction.onabort = ((JSAny? _) {
      fail();
    }).toJS;
    transaction.onerror = ((JSAny? _) {
      fail();
    }).toJS;

    final request = transaction.objectStore('journal').read('state'.toJS);
    request.onerror = ((JSAny? _) {
      fail();
    }).toJS;
    request.onsuccess = ((JSAny? _) {
      try {
        final raw = request.result;
        if (raw == null) {
          value = null;
        } else if (raw.isA<JSString>()) {
          value = (raw as JSString).toDart;
        } else {
          throw StateError('Unexpected IndexedDB test value');
        }
        read = true;
      } on Object {
        fail();
      }
    }).toJS;
    return await committed.future;
  } finally {
    database.close();
  }
}

// Actual browser IndexedDB; Auth/RPC responses below are TEST ONLY.
final class _Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(userId: fixture.owner);
}

final class _DelayedListStore implements DurableReviewStore {
  _DelayedListStore(this.delegate);

  final DurableReviewStore delegate;
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<List<StoredReview>> list(String userId) async {
    final snapshot = await delegate.list(userId);
    if (!started.isCompleted) started.complete();
    await release.future;
    return snapshot;
  }

  @override
  Future<StoredReview> stage(String userId, Map<String, Object> request) =>
      delegate.stage(userId, request);

  @override
  Future<void> acknowledge(
    String userId,
    String eventId,
    ReviewSuccess receipt,
  ) => delegate.acknowledge(userId, eventId, receipt);

  @override
  Future<void> reject(String userId, String eventId, ReviewFailure rejection) =>
      delegate.reject(userId, eventId, rejection);
}

final class _Reviews implements ReviewRepository {
  _Reviews(this.auth, this.store);
  final _Auth auth;
  final TransactionalReviewStore store;
  int calls = 0;
  @override
  PreparedReview? prepare(SrsReview review) =>
      PreparedReview.restore(auth.currentSession!, review.toJson());
  @override
  Future<ReviewOutcome> submit(PreparedReview review) async {
    calls++;
    // Inspect through another transaction, after stage has committed.
    final records = await store.list(review.session.userId);
    expect(
      records.any(
        (r) => r.eventId == review.request['client_event_id'] && r.isPending,
      ),
      isTrue,
    );
    return fixture.receipt();
  }
}

void main() {
  var sequence = 0;
  String name() =>
      'nd-browser-test-${DateTime.now().microsecondsSinceEpoch}-${sequence++}';

  test(
    'real IndexedDB receipt retention preserves pending and original server replay',
    () async {
      final database = name();
      final a = await openBrowserReviewStore(
        databaseName: database,
        receiptRetention: ReviewReceiptRetention(keepCount: 2),
      );
      final b = await openBrowserReviewStore(
        databaseName: database,
        receiptRetention: ReviewReceiptRetention(keepCount: 2),
      );
      try {
        await retention.verifyRetentionStore(
          a,
          () => a.pruneReceipts(fixture.owner),
        );
        await Future.wait([
          a.pruneReceipts(fixture.owner),
          b.stage(fixture.owner, fixture.request(700)),
        ]);
        expect(
          (await b.list(fixture.owner)).where((r) => r.receipt != null).length,
          2,
        );
        expect(
          (await b.list(fixture.owner)).where((r) => r.isPending).length,
          2,
        );
        expect((await b.list(fixture.other)).single.receipt, isNotNull);
      } finally {
        await a.close();
        await b.close();
      }
      final restored = await openBrowserReviewStore(databaseName: database);
      try {
        expect(
          (await restored.list(fixture.owner)).where((r) => r.isPending).length,
          2,
        );
        expect(
          (await restored.list(
            fixture.owner,
          )).where((r) => r.rejection != null).length,
          1,
        );
      } finally {
        await restored.close();
      }
    },
  );

  test(
    'real IndexedDB reopen preserves exact pending and account isolation',
    () async {
      final database = name();
      var store = await openBrowserReviewStore(databaseName: database);
      await store.stage(fixture.owner, fixture.request(1));
      await store.close();
      store = await openBrowserReviewStore(databaseName: database);
      try {
        expect((await store.list(fixture.other)), isEmpty);
        final pending = (await store.list(fixture.owner)).single;
        expect(sameReviewRequest(pending.request, fixture.request(1)), isTrue);
        expect(pending.isPending, isTrue);
      } finally {
        await store.close();
      }
    },
  );

  test(
    'real IndexedDB two connections serialize duplicate and distinct writes',
    () async {
      final database = name();
      final a = await openBrowserReviewStore(databaseName: database);
      final b = await openBrowserReviewStore(databaseName: database);
      try {
        await Future.wait([
          a.stage(fixture.owner, fixture.request(1)),
          b.stage(fixture.owner, fixture.request(1)),
          b.stage(fixture.other, fixture.request(2)),
        ]);
        expect((await a.list(fixture.owner)).length, 1);
        expect((await b.list(fixture.other)).length, 1);
        await expectLater(
          b.stage(fixture.owner, {...fixture.request(1), 'rating': 3}),
          throwsA(isA<ReviewTransportFailure>()),
        );
        expect((await a.list(fixture.owner)).single.request['rating'], 2);
      } finally {
        await a.close();
        await b.close();
      }
    },
  );

  test(
    'real IndexedDB commits original receipt before replay and preserves rejection',
    () async {
      final database = name();
      var store = await openBrowserReviewStore(databaseName: database);
      final auth = _Auth();
      final delegate = _Reviews(auth, store);
      var repository = DurableReviewRepository(
        auth: auth,
        delegate: delegate,
        store: store,
      );
      final event = PreparedReview.restore(
        auth.currentSession!,
        fixture.request(1),
      );
      expect(await repository.submit(event), isA<ReviewSuccess>());
      expect(delegate.calls, 1);
      await store.stage(fixture.other, fixture.request(2));
      await store.reject(
        fixture.other,
        fixture.request(2)['client_event_id']! as String,
        ReviewFailure(ReviewErrorCode.syncConflict),
      );
      await store.close();
      store = await openBrowserReviewStore(databaseName: database);
      try {
        repository = DurableReviewRepository(
          auth: auth,
          delegate: delegate,
          store: store,
        );
        expect(await repository.recoverPending(), isEmpty);
        expect(await repository.submit(event), isA<ReviewSuccess>());
        expect(delegate.calls, 1);
        expect(
          (await store.list(fixture.other)).single.rejection?.code,
          ReviewErrorCode.syncConflict,
        );
        await expectLater(
          store.acknowledge(
            fixture.other,
            fixture.request(2)['client_event_id']! as String,
            fixture.receipt(),
          ),
          throwsA(isA<ReviewStorageFailure>()),
        );
        expect(
          (await store.list(fixture.other)).single.rejection?.code,
          ReviewErrorCode.syncConflict,
        );
      } finally {
        await store.close();
      }
    },
  );

  test(
    'real IndexedDB late User A recovery cannot publish after account switch',
    () async {
      final store = await openBrowserReviewStore(databaseName: name());
      final auth = _Auth();
      await store.stage(fixture.owner, fixture.request(1));
      final delayed = _DelayedListStore(store);
      final repository = DurableReviewRepository(
        auth: auth,
        delegate: _Reviews(auth, store),
        store: delayed,
      );
      final recovery = repository.recoverPending();
      try {
        await delayed.started.future;
        auth.currentSession = ReviewSession(userId: fixture.other);
        delayed.release.complete();

        await expectLater(
          recovery,
          throwsA(
            isA<ReviewTransportFailure>().having(
              (failure) => failure.code,
              'captured-session recovery after account switch',
              ReviewErrorCode.unauthorized,
            ),
          ),
        );
        final original = await store.list(fixture.owner);
        expect(original, hasLength(1));
        expect(original.single.isPending, isTrue);
        expect(await store.list(fixture.other), isEmpty);
      } finally {
        if (!delayed.release.isCompleted) delayed.release.complete();
        await store.close();
      }
    },
  );

  test(
    'real IndexedDB rejects uncertain settlement and closed handles safely',
    () async {
      final store = await openBrowserReviewStore(databaseName: name());
      await store.stage(fixture.owner, fixture.request(1));
      await expectLater(
        store.reject(
          fixture.owner,
          fixture.request(1)['client_event_id']! as String,
          ReviewFailure(ReviewErrorCode.unauthorized),
        ),
        throwsA(isA<ReviewStorageFailure>()),
      );
      expect((await store.list(fixture.owner)).single.isPending, isTrue);
      await store.close();
      await expectLater(
        store.list(fixture.owner),
        throwsA(isA<ReviewStorageFailure>()),
      );
      await expectLater(
        openBrowserReviewStore(databaseName: 'PRIVATE TOKEN / PATH'),
        throwsA(isA<ReviewStorageFailure>()),
      );
    },
  );

  test(
    'real IndexedDB corruption fails closed without rewriting state',
    () async {
      final database = name();
      final seed = await openBrowserReviewStore(databaseName: database);
      await seed.close();

      const corrupted = '{"version":1,"version":1,"records":[]}';
      await _writeRawState(database, corrupted);
      final store = await openBrowserReviewStore(databaseName: database);
      try {
        await expectLater(
          store.list(fixture.owner),
          throwsA(isA<ReviewStorageFailure>()),
        );
      } finally {
        await store.close();
      }

      expect(await _readRawState(database), corrupted);
    },
  );

  test(
    'real IndexedDB concurrent changed replay conflict preserves winner and owner isolation',
    () async {
      final database = name();
      final a = await openBrowserReviewStore(databaseName: database);
      final b = await openBrowserReviewStore(databaseName: database);
      try {
        final original = fixture.request(801);
        final changed = {...original, 'response_ms': 124};

        Future<Object> capture(Future<StoredReview> operation) async {
          try {
            return await operation;
          } on Object catch (error) {
            return error;
          }
        }

        final outcomes = await Future.wait([
          capture(a.stage(fixture.owner, original)),
          capture(b.stage(fixture.owner, changed)),
        ]);
        final accepted = outcomes.whereType<StoredReview>().single;
        final rejected = outcomes.whereType<ReviewTransportFailure>().single;
        expect(rejected.code, ReviewErrorCode.syncConflict);
        expect(accepted.eventId, original['client_event_id']);
        expect(
          accepted.request['response_ms'],
          anyOf(original['response_ms'], changed['response_ms']),
        );

        final ownerRecord = (await a.list(
          fixture.owner,
        )).singleWhere((record) => record.eventId == accepted.eventId);
        expect(ownerRecord.isPending, isTrue);
        expect(
          ownerRecord.request['response_ms'],
          accepted.request['response_ms'],
        );
        expect(await b.list(fixture.other), isEmpty);

        final sharedId = fixture.request(802);
        final otherOwner = {...sharedId, 'response_ms': 125};
        await Future.wait([
          a.stage(fixture.owner, sharedId),
          b.stage(fixture.other, otherOwner),
        ]);
        final ownerCopy = (await a.list(fixture.owner)).singleWhere(
          (record) => record.eventId == sharedId['client_event_id'],
        );
        final otherCopy = (await b.list(fixture.other)).single;
        expect(ownerCopy.eventId, otherCopy.eventId);
        expect(ownerCopy.request['response_ms'], 123);
        expect(otherCopy.request['response_ms'], 125);
        expect((await a.list(fixture.other)), isEmpty);
        expect((await b.list(fixture.owner)), hasLength(2));
      } finally {
        await a.close();
        await b.close();
      }
    },
  );
}
