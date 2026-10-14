import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/srs/data/durable_review_repository.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/domain/srs_models.dart';

const a = 'a1000000-0000-4000-8000-000000000001';
const b = 'a1000000-0000-4000-8000-000000000002';
const event = 'b2000000-0000-4000-8000-000000000001';
Map<String, Object> request() => {
  'client_event_id': event,
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

// TEST ONLY Auth/RPC/store ports. Native journal cases use actual disposable disk.
final class Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(userId: a);
}

final class Reviews implements ReviewRepository {
  Reviews(this.auth);
  final Auth auth;
  int calls = 0;
  final requests = <Map<String, Object>>[];
  Completer<ReviewOutcome>? reply;
  @override
  PreparedReview? prepare(SrsReview review) => auth.currentSession == null
      ? null
      : PreparedReview.restore(auth.currentSession!, review.toJson());
  @override
  Future<ReviewOutcome> submit(PreparedReview review) {
    calls++;
    requests.add(review.request);
    return reply?.future ?? Future.value(receipt());
  }
}

final class Store implements DurableReviewStore {
  final records = <String, StoredReview>{};
  bool failStage = false;
  bool failAck = false;
  bool failRead = false;
  Completer<void>? gate;
  Completer<void>? readGate;
  @override
  Future<List<StoredReview>> list(String userId) async {
    await readGate?.future;
    if (failRead) throw StateError('PRIVATE PATH/TOKEN');
    return records.values.where((r) => r.userId == userId).toList();
  }

  @override
  Future<StoredReview> stage(String userId, Map<String, Object> request) async {
    await gate?.future;
    if (failStage) throw StateError('PRIVATE PATH/TOKEN');
    final key = '$userId/${request['client_event_id']}';
    final existing = records[key];
    if (existing != null && !sameReviewRequest(existing.request, request)) {
      throw const ReviewTransportFailure(ReviewErrorCode.syncConflict);
    }
    return records.putIfAbsent(
      key,
      () => StoredReview(userId: userId, request: request),
    );
  }

  @override
  Future<void> acknowledge(
    String userId,
    String eventId,
    ReviewSuccess result,
  ) async {
    if (failAck) throw StateError('PRIVATE PATH/TOKEN');
    final key = '$userId/$eventId';
    final old = records[key]!;
    records[key] = StoredReview(
      userId: userId,
      request: old.request,
      receipt: result,
    );
  }
}

void main() {
  late Auth auth;
  late Reviews delegate;
  late Store store;
  late DurableReviewRepository repository;
  PreparedReview prepared([Map<String, Object>? value]) =>
      PreparedReview.restore(auth.currentSession!, value ?? request());
  setUp(() {
    auth = Auth();
    delegate = Reviews(auth);
    store = Store();
    repository = DurableReviewRepository(
      auth: auth,
      delegate: delegate,
      store: store,
    );
  });

  test('restore retains fractional offset wire identity and is immutable', () {
    final original = request();
    final restored = prepared(original);
    original['response_ms'] = 99;
    expect(restored.request, request());
    expect(() => restored.request['rating'] = 1, throwsUnsupportedError);
  });
  test(
    'restore rejects unknown fields malformed types and inconsistent rating',
    () {
      final bad = [
        {...request(), 'user_id': a},
        {...request()}..remove('occurred_at'),
        {...request(), 'rating': 2.0},
        {...request(), 'is_correct': false},
        {...request(), 'response_ms': -1},
        {...request(), 'occurred_at': '2026-02-30T02:00:00Z'},
        {...request(), 'item_type': 'FORGED'},
        {...request(), 'client_event_id': 'not-a-uuid'},
        {...request(), 'token': 'PRIVATE'},
      ];
      for (final input in bad) {
        expect(() => prepared(input), throwsA(isA<Object>()));
      }
    },
  );
  test(
    'storage failure before dispatch sends no RPC and leaks no details',
    () async {
      store.failStage = true;
      final outcome = await repository.submit(prepared()) as ReviewFailure;
      expect(outcome.code, ReviewErrorCode.internalError);
      expect(outcome.messageVi, isNot(contains('PRIVATE')));
      expect(delegate.calls, 0);
    },
  );
  test(
    'pending is stored before RPC and identical concurrent taps share dispatch',
    () async {
      delegate.reply = Completer<ReviewOutcome>();
      final p = prepared();
      final one = repository.submit(p);
      final two = repository.submit(p);
      expect(identical(one, two), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(store.records.values.single.receipt, isNull);
      expect(delegate.calls, 1);
      delegate.reply!.complete(receipt());
      expect(await one, isA<ReviewSuccess>());
    },
  );
  test(
    'changed concurrent same-ID payload conflicts without dispatch',
    () async {
      delegate.reply = Completer<ReviewOutcome>();
      final one = repository.submit(prepared());
      final changed = await repository.submit(
        prepared({...request(), 'rating': 1}),
      );
      expect((changed as ReviewFailure).code, ReviewErrorCode.syncConflict);
      delegate.reply!.complete(receipt());
      await one;
      expect(delegate.calls, 1);
    },
  );
  test(
    'receipt write failure retains exact pending event for manual replay',
    () async {
      store.failAck = true;
      expect(await repository.submit(prepared()), isA<ReviewFailure>());
      expect(store.records.values.single.receipt, isNull);
      final recovered = await repository.recoverPending();
      expect(recovered.single.request, request());
      store.failAck = false;
      expect(await repository.submit(recovered.single), isA<ReviewSuccess>());
      expect(delegate.calls, 2);
      expect(delegate.requests[0], delegate.requests[1]);
    },
  );
  test('durable original receipt avoids new RPC and is not pending', () async {
    final p = prepared();
    final first = await repository.submit(p) as ReviewSuccess;
    final second = await repository.submit(p) as ReviewSuccess;
    expect(second.toJson(), first.toJson());
    expect(delegate.calls, 1);
    expect(await repository.recoverPending(), isEmpty);
  });
  test('changed stored same-ID payload conflicts without second RPC', () async {
    await repository.submit(prepared());
    final changed = await repository.submit(
      prepared({...request(), 'rating': 1}),
    );
    expect((changed as ReviewFailure).code, ReviewErrorCode.syncConflict);
    expect(delegate.calls, 1);
  });
  test('logout during pending disk write prevents dispatch', () async {
    store.gate = Completer<void>();
    final result = repository.submit(prepared());
    auth.currentSession = null;
    store.gate!.complete();
    expect((await result as ReviewFailure).code, ReviewErrorCode.unauthorized);
    expect(delegate.calls, 0);
    expect(store.records.values.single.userId, a);
  });
  test(
    'switch during RPC stores receipt for original owner but rejects UI result',
    () async {
      delegate.reply = Completer<ReviewOutcome>();
      final result = repository.submit(prepared());
      await Future<void>.delayed(Duration.zero);
      auth.currentSession = ReviewSession(userId: b);
      delegate.reply!.complete(receipt());
      expect(
        (await result as ReviewFailure).code,
        ReviewErrorCode.unauthorized,
      );
      expect(store.records.values.single.userId, a);
      expect(store.records.values.single.receipt, isNotNull);
      expect(await repository.recoverPending(), isEmpty);
    },
  );
  test('A-B-A during recovery rejects old lifecycle', () async {
    store.readGate = Completer<void>();
    final result = repository.recoverPending();
    auth.currentSession = ReviewSession(userId: b);
    auth.currentSession = ReviewSession(userId: a);
    store.readGate!.complete();
    await expectLater(result, throwsA(isA<ReviewTransportFailure>()));
  });
  test(
    'recovery storage errors are redacted and signed-out recovery is blocked',
    () async {
      store.failRead = true;
      await expectLater(
        repository.recoverPending(),
        throwsA(isA<ReviewStorageFailure>()),
      );
      auth.currentSession = null;
      await expectLater(
        repository.recoverPending(),
        throwsA(isA<ReviewTransportFailure>()),
      );
    },
  );
  test(
    'fresh same-owner session rebinds pending only on explicit recovery',
    () async {
      store.failAck = true;
      final old = prepared();
      await repository.submit(old);
      auth.currentSession = ReviewSession(userId: a);
      expect(
        (await repository.submit(old) as ReviewFailure).code,
        ReviewErrorCode.unauthorized,
      );
      final recovered = (await repository.recoverPending()).single;
      expect(identical(recovered.session, auth.currentSession), isTrue);
      expect(recovered.request, old.request);
    },
  );

  group('native disk journal', () {
    late Directory directory;
    NativeReviewJournal? journal;
    File file() =>
        File('${directory.path}${Platform.pathSeparator}review-journal.ndjson');
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('nd-review-test-');
      journal = await NativeReviewJournal.open(directory);
    });
    tearDown(() async {
      await journal?.close();
      await directory.delete(recursive: true);
    });
    test(
      'concurrent duplicate stages append once and isolate owners',
      () async {
        await Future.wait(
          List.generate(10, (_) => journal!.stage(a, request())),
        );
        expect((await journal!.list(a)).length, 1);
        expect(await journal!.list(b), isEmpty);
        expect(
          const LineSplitter().convert(await file().readAsString()).length,
          1,
        );
        await expectLater(
          journal!.stage(a, {...request(), 'rating': 1}),
          throwsA(isA<ReviewTransportFailure>()),
        );
      },
    );
    test(
      'receipt survives reopen and cannot be changed or assigned to B',
      () async {
        await journal!.stage(a, request());
        await expectLater(
          journal!.acknowledge(b, event, receipt()),
          throwsA(isA<ReviewStorageFailure>()),
        );
        await journal!.acknowledge(a, event, receipt());
        await journal!.acknowledge(a, event, receipt());
        final changed =
            decodeReviewOutcome({...receipt().toJson(), 'review_count': 3})
                as ReviewSuccess;
        await expectLater(
          journal!.acknowledge(a, event, changed),
          throwsA(isA<ReviewStorageFailure>()),
        );
        await journal!.close();
        journal = await NativeReviewJournal.open(directory);
        expect(
          (await journal!.list(a)).single.receipt!.toJson(),
          receipt().toJson(),
        );
        expect(
          const LineSplitter().convert(await file().readAsString()).length,
          2,
        );
      },
    );
    test(
      'interrupted receipt tail retains pending and complete corruption is rejected',
      () async {
        await journal!.stage(a, request());
        await journal!.close();
        journal = null;
        await file().writeAsString(
          '{"kind":"receipt"',
          mode: FileMode.append,
          flush: true,
        );
        journal = await NativeReviewJournal.open(directory);
        expect((await journal!.list(a)).single.receipt, isNull);
        await journal!.close();
        journal = null;
        await file().writeAsString(
          '{"invalid":true}\n',
          mode: FileMode.append,
          flush: true,
        );
        await expectLater(
          NativeReviewJournal.open(directory),
          throwsA(isA<ReviewStorageFailure>()),
        );
      },
    );
    test(
      'duplicate keys and oversized journal fail closed without deleting history',
      () async {
        await journal!.close();
        journal = null;
        await file().writeAsString('{"version":1,"version":1}\n', flush: true);
        await expectLater(
          NativeReviewJournal.open(directory),
          throwsA(isA<ReviewStorageFailure>()),
        );
        expect(
          await file().readAsString(),
          contains('"version":1,"version":1'),
        );
        await file().writeAsBytes(
          List.filled(NativeReviewJournal.maxBytes + 1, 32),
        );
        await expectLater(
          NativeReviewJournal.open(directory),
          throwsA(isA<ReviewStorageFailure>()),
        );
      },
    );
    test(
      'event capacity blocks new writes without losing pending history',
      () async {
        for (var i = 0; i < NativeReviewJournal.maxEvents; i++) {
          await journal!.stage(a, {
            ...request(),
            'client_event_id':
                'b2000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
          });
        }
        final length = await file().length();
        await expectLater(
          journal!.stage(b, request()),
          throwsA(isA<ReviewStorageFailure>()),
        );
        expect(await file().length(), length);
        expect((await journal!.list(a)).length, NativeReviewJournal.maxEvents);
        expect(await journal!.list(b), isEmpty);
      },
    );
    test(
      'same-process second writer is rejected and close is idempotent',
      () async {
        await expectLater(
          NativeReviewJournal.open(directory),
          throwsA(isA<ReviewStorageFailure>()),
        );
        await journal!.close();
        await journal!.close();
        journal = await NativeReviewJournal.open(directory);
        expect(await journal!.list(a), isEmpty);
      },
    );
  });
}
