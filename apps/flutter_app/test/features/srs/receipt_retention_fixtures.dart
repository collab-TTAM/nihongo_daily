import 'dart:convert';
import 'package:nihongo_daily/features/srs/data/durable_review_repository.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/data/review_receipt_retention.dart';
import 'package:nihongo_daily/features/srs/data/transactional_review_store.dart';
import 'package:nihongo_daily/features/srs/domain/srs_models.dart';
import 'transactional_review_fixtures.dart' as fixture;

Future<void> stageReceipt(DurableReviewStore store, int id) async {
  await store.stage(fixture.owner, fixture.request(id));
  await store.acknowledge(
    fixture.owner,
    fixture.request(id)['client_event_id']! as String,
    fixture.receipt(),
  );
}

final class _Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(userId: fixture.owner);
}

/// TEST ONLY immutable server receipt ledger. Hosted/native SQL is not called.
final class _ReplayServer implements ReviewRepository {
  final requests = <String, Map<String, Object>>{};
  int calls = 0;
  int events = 0;
  @override
  PreparedReview? prepare(SrsReview review) => null;
  @override
  Future<ReviewOutcome> submit(PreparedReview review) async {
    calls++;
    final id = review.request['client_event_id']! as String;
    final original = requests[id];
    if (original != null && !sameReviewRequest(original, review.request)) {
      return ReviewFailure(ReviewErrorCode.syncConflict);
    }
    if (original == null) {
      requests[id] = review.request;
      events++;
    }
    return fixture.receipt();
  }
}

Future<void> verifyRetentionStore(
  DurableReviewStore store,
  Future<int> Function() prune,
) async {
  final auth = _Auth();
  final server = _ReplayServer();
  final repository = DurableReviewRepository(
    auth: auth,
    delegate: server,
    store: store,
  );
  for (var i = 1; i <= 3; i++) {
    fixture.check(
      await repository.submit(
            PreparedReview.restore(auth.currentSession!, fixture.request(i)),
          )
          is ReviewSuccess,
      'initial receipt not saved',
    );
  }
  await prune();
  fixture.check(
    !(await store.list(
      fixture.owner,
    )).any((r) => r.eventId == fixture.request(1)['client_event_id']),
    'old receipt not pruned',
  );
  fixture.check(
    (await repository.recoverPending()).isEmpty,
    'receipt pruning fabricated pending',
  );
  final original = PreparedReview.restore(
    auth.currentSession!,
    fixture.request(1),
  );
  fixture.check(
    await repository.submit(original) is ReviewSuccess,
    'pruned original did not revalidate server replay',
  );
  fixture.check(
    server.events == 3 && server.calls == 4,
    'receipt replay fabricated a new server event',
  );
  fixture.check(
    jsonEncode(
          (await store.list(fixture.owner))
              .firstWhere(
                (r) => r.eventId == original.request['client_event_id'],
              )
              .receipt!
              .toJson(),
        ) ==
        jsonEncode(fixture.receipt().toJson()),
    'revalidated receipt changed',
  );
  // Retention before a new event preserves uncertain and definitive rejections.
  await store.stage(fixture.owner, fixture.request(500));
  await store.stage(fixture.owner, fixture.request(501));
  await store.reject(
    fixture.owner,
    fixture.request(501)['client_event_id']! as String,
    ReviewFailure(ReviewErrorCode.syncConflict),
  );
  await store.stage(fixture.other, fixture.request(502));
  await store.acknowledge(
    fixture.other,
    fixture.request(502)['client_event_id']! as String,
    fixture.receipt(),
  );
  await prune();
  final own = await store.list(fixture.owner);
  fixture.check(
    own.any(
      (r) =>
          r.eventId == fixture.request(500)['client_event_id'] && r.isPending,
    ),
    'retention dropped pending',
  );
  fixture.check(
    own.any((r) => r.rejection != null),
    'retention dropped rejection',
  );
  fixture.check(
    (await store.list(fixture.other)).single.receipt != null,
    'retention touched other owner',
  );
}

Future<void> verifyTransactionalRetention(String scenario) async {
  final port = fixture.LedgerFixture();
  final store = TransactionalReviewStore(
    port,
    receiptRetention: ReviewReceiptRetention(keepCount: 2),
  );
  if (scenario == 'replay-protection') {
    await verifyRetentionStore(store, () => store.pruneReceipts(fixture.owner));
  } else if (scenario == 'many-reviews') {
    for (var i = 1; i <= 600; i++) {
      await stageReceipt(store, i);
    }
    fixture.check(
      (await store.list(fixture.owner)).length <= 3,
      'enabled receipt cache grew unbounded',
    );
    fixture.check(
      await store.pruneReceipts(fixture.owner) == 1,
      'explicit maintenance did not enforce strict limit',
    );
    fixture.check(
      (await store.list(fixture.owner)).length == 2,
      'strict retained-count mismatch',
    );
  } else if (scenario == 'rollback-default') {
    final unconfigured = TransactionalReviewStore(port);
    for (var i = 1; i <= 3; i++) {
      await stageReceipt(unconfigured, i);
    }
    fixture.check(
      await unconfigured.pruneReceipts(fixture.owner) == 0,
      'default retention erased history',
    );
    final before = port.data;
    port.failCommit = true;
    await fixture.expectFailure(store.pruneReceipts(fixture.owner));
    fixture.check(
      port.data == before,
      'failed pruning committed partial deletion',
    );
    port.failCommit = false;
    fixture.check(
      await store.pruneReceipts(fixture.owner) == 1,
      'safe prune retry failed',
    );
  } else if (scenario == 'selection') {
    for (final count in [0, 257]) {
      var rejected = false;
      try {
        ReviewReceiptRetention(keepCount: count);
      } on ArgumentError {
        rejected = true;
      }
      fixture.check(rejected, 'invalid retention limit accepted');
    }
    final input = [
      for (var i = 1; i <= 4; i++)
        StoredReview(
          userId: fixture.owner,
          request: fixture.request(i),
          receipt: fixture.receipt(),
        ),
      StoredReview(userId: fixture.owner, request: fixture.request(5)),
      StoredReview(
        userId: fixture.owner,
        request: fixture.request(6),
        rejection: ReviewFailure(ReviewErrorCode.syncConflict),
      ),
      StoredReview(
        userId: fixture.other,
        request: fixture.request(7),
        receipt: fixture.receipt(),
      ),
    ];
    final selected = ReviewReceiptRetention(
      keepCount: 2,
    ).retain(input, fixture.owner);
    fixture.check(
      input.length == 7 && selected.length == 5,
      'selection mutated source/nonreceipt history',
    );
    fixture.check(
      selected.first.eventId == fixture.request(3)['client_event_id'],
      'retention ordering was not stage order',
    );
  } else {
    throw StateError('unknown retention scenario');
  }
}

const scenarios = [
  'selection',
  'replay-protection',
  'many-reviews',
  'rollback-default',
];
