import 'dart:async';
import 'dart:convert';

import 'package:nihongo_daily/features/srs/data/durable_review_repository.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/data/transactional_review_store.dart';

const owner = 'a1000000-0000-4000-8000-000000000001';
const other = 'a1000000-0000-4000-8000-000000000002';
Map<String, Object> request(int index) => {
  'client_event_id':
      'b2000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
  'item_type': 'VOCABULARY',
  'item_id': 'b3000000-0000-4000-8000-000000000001',
  'rating': 2,
  'is_correct': true,
  'response_ms': 123,
  'occurred_at': '2026-10-14T02:00:00.123456789+07:00',
};
ReviewSuccess receipt() =>
    decodeReviewOutcome({
          'srs_state': 'REVIEW',
          'next_review_at': '2026-10-15T02:00:00.123456789Z',
          'interval_days': 1,
          'difficulty': 0.5,
          'review_count': 2,
        })
        as ReviewSuccess;
void check(bool value, String message) {
  if (!value) throw StateError(message);
}

/// TEST ONLY atomic port. It cannot prove IndexedDB/real browser durability.
final class LedgerFixture implements ReviewLedgerTransactions {
  String? data;
  bool failCommit = false;
  bool closed = false;
  Future<void> _tail = Future.value();
  @override
  Future<T> transact<T>(
    bool write,
    T Function(String?, void Function(String)) operation,
  ) {
    final result = _tail.then((_) {
      if (closed) throw StateError('PRIVATE BROWSER ERROR');
      var replacement = data;
      final result = operation(data, (next) {
        if (!write) throw StateError('read-only');
        replacement = next;
      });
      if (failCommit) throw StateError('PRIVATE QUOTA ERROR');
      data = replacement;
      return result;
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  @override
  Future<void> close() async {
    closed = true;
    await _tail;
  }
}

Future<void> expectFailure(
  Future<Object?> operation, {
  bool conflict = false,
}) async {
  var failed = false;
  try {
    await operation;
  } on ReviewStorageFailure {
    failed = !conflict;
  } on ReviewTransportFailure catch (error) {
    failed = conflict && error.code == ReviewErrorCode.syncConflict;
  }
  check(failed, 'missing expected safe storage/conflict failure');
}

Future<void> verifyTransactional(String scenario) async {
  final port = LedgerFixture();
  final store = TransactionalReviewStore(port);
  if (scenario == 'immutable-history') {
    await store.stage(owner, request(1));
    await store.stage(other, request(1));
    await store.acknowledge(
      owner,
      request(1)['client_event_id']! as String,
      receipt(),
    );
    await store.reject(
      other,
      request(1)['client_event_id']! as String,
      ReviewFailure(ReviewErrorCode.syncConflict),
    );
    final reopened = TransactionalReviewStore(port);
    check((await reopened.list(owner)).single.receipt != null, 'receipt lost');
    check(
      (await reopened.list(other)).single.rejection != null,
      'rejection/account lost',
    );
    check(
      sameReviewRequest(
        (await reopened.list(owner)).single.request,
        request(1),
      ),
      'exact event/time changed',
    );
    await expectFailure(
      reopened.stage(owner, {...request(1), 'rating': 3}),
      conflict: true,
    );
    await expectFailure(
      reopened.reject(
        owner,
        request(1)['client_event_id']! as String,
        ReviewFailure(ReviewErrorCode.notFound),
      ),
    );
    check(
      (await reopened.list(owner)).single.receipt != null,
      'immutable receipt overwritten',
    );
  } else if (scenario == 'rollback') {
    await store.stage(owner, request(1));
    final original = port.data;
    port.failCommit = true;
    await expectFailure(
      store.acknowledge(
        owner,
        request(1)['client_event_id']! as String,
        receipt(),
      ),
    );
    check(port.data == original, 'failed transaction changed history');
    port.failCommit = false;
    check(
      (await store.list(owner)).single.isPending,
      'failed commit settled pending',
    );
  } else if (scenario == 'malformed') {
    for (final raw in [
      '{"version":1,"version":1,"records":[]}',
      '{"version":2,"records":[]}',
      '{"version":1,"records":[],"extra":true}',
      '[]',
      '{bad',
    ]) {
      port.data = raw;
      await expectFailure(store.list(owner));
      check(port.data == raw, 'corruption silently rewritten');
    }
    port.data = null;
    await store.stage(owner, request(1));
    final valid = port.data!;
    final parsed = jsonDecode(valid) as Map<String, Object?>;
    final entries = parsed['records']! as List<Object?>;
    entries.add(entries.single);
    port.data = jsonEncode(parsed);
    await expectFailure(store.list(owner));
    for (final mutation in <Map<String, Object?>>[
      {'user_id': owner.toUpperCase()},
      {
        'request': {...request(1), 'response_ms': '123'},
      },
      {'receipt': ReviewFailure(ReviewErrorCode.internalError).toJson()},
      {
        'receipt': receipt().toJson(),
        'rejection': ReviewFailure(ReviewErrorCode.syncConflict).toJson(),
      },
      {'rejection': ReviewFailure(ReviewErrorCode.unauthorized).toJson()},
      {'extra': true},
    ]) {
      final raw = jsonDecode(valid) as Map<String, Object?>;
      final entry =
          (raw['records']! as List<Object?>).single! as Map<String, Object?>;
      entry.addAll(mutation);
      port.data = jsonEncode(raw);
      await expectFailure(store.list(owner));
    }
    port.data = jsonEncode({
      'version': 1,
      'records': [
        for (var i = 1; i <= 150; i++)
          {
            'user_id': owner,
            'request': request(i),
            'receipt': null,
            'rejection': null,
          },
      ],
    });
    await expectFailure(
      store.list(owner),
    ); // Restore cannot evade reservations.
  } else if (scenario == 'event-cap') {
    for (var i = 1; i <= TransactionalReviewStore.maxEvents; i++) {
      await store.stage(owner, request(i));
      await store.acknowledge(
        owner,
        request(i)['client_event_id']! as String,
        receipt(),
      );
    }
    final before = port.data;
    await expectFailure(store.stage(other, request(513)));
    check(port.data == before, 'full-cap history evicted/partially replaced');
    check(
      (await store.list(owner)).length == TransactionalReviewStore.maxEvents,
      'full-cap receipt history lost',
    );
  } else if (scenario == 'reservations') {
    var staged = 0;
    for (var i = 1; i <= TransactionalReviewStore.maxEvents; i++) {
      try {
        await store.stage(owner, request(i));
        staged++;
      } on ReviewStorageFailure {
        break;
      }
    }
    check(
      staged > 0 && staged < TransactionalReviewStore.maxEvents,
      'missing reserved receipt capacity',
    );
    final before = port.data;
    await expectFailure(store.stage(other, request(500)));
    check(port.data == before, 'capacity failure partially committed');
    await store.acknowledge(
      owner,
      request(1)['client_event_id']! as String,
      receipt(),
    );
    await store.stage(other, request(500));
    check(
      (await store.list(other)).length == 1,
      'receipt did not free reserved bytes',
    );
  } else if (scenario == 'uncertain') {
    await store.stage(owner, request(1));
    for (final code in [
      ReviewErrorCode.internalError,
      ReviewErrorCode.unauthorized,
      ReviewErrorCode.networkUnavailable,
    ]) {
      await expectFailure(
        store.reject(
          owner,
          request(1)['client_event_id']! as String,
          ReviewFailure(code),
        ),
      );
    }
    check(
      (await store.list(owner)).single.isPending,
      'uncertain result settled',
    );
  } else if (scenario == 'concurrent') {
    await Future.wait([
      store.stage(owner, request(1)),
      store.stage(owner, request(1)),
      store.stage(other, request(2)),
    ]);
    check(
      (await store.list(owner)).length == 1 &&
          (await store.list(other)).length == 1,
      'concurrent fixture write lost/duplicated record',
    );
    await store.close();
    await expectFailure(store.list(owner));
  } else {
    throw StateError('unknown transactional scenario');
  }
}

const scenarios = [
  'immutable-history',
  'rollback',
  'malformed',
  'reservations',
  'uncertain',
  'concurrent',
  'event-cap',
];
Future<void> main() async {
  for (final scenario in scenarios) {
    await verifyTransactional(scenario);
  }
}
