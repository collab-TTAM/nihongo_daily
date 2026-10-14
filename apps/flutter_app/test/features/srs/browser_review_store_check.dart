import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/srs/data/browser_review_store.dart';
import 'package:nihongo_daily/features/srs/data/durable_review_repository.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/data/transactional_review_store.dart';
import 'package:nihongo_daily/features/srs/data/review_receipt_retention.dart';
import 'package:nihongo_daily/features/srs/domain/srs_models.dart';

import 'transactional_review_fixtures.dart' as fixture;
import 'receipt_retention_fixtures.dart' as retention;

// Actual browser IndexedDB; Auth/RPC responses below are TEST ONLY.
final class _Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(userId: fixture.owner);
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
}
