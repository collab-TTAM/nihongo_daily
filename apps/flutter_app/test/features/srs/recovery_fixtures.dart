// TEST ONLY Auth/RPC/queue. Forwarding store uses actual disposable native disk.
import 'dart:async';
import 'package:nihongo_daily/features/srs/application/srs_study_controller.dart';
import 'package:nihongo_daily/features/srs/data/durable_review_repository.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'study_fixtures.dart';

Map<String, Object> recoveryRequest([int id = 1]) => {
  'client_event_id':
      'c2000000-0000-4000-8000-${id.toString().padLeft(12, '0')}',
  'item_type': 'VOCABULARY',
  'item_id': fixtureItem(id: id).itemId,
  'rating': 2,
  'is_correct': true,
  'response_ms': 200,
  'occurred_at': '2026-10-14T02:00:00.123456789+07:00',
};

final class RecoveryStore implements DurableReviewStore {
  RecoveryStore(this.journal);
  final NativeReviewJournal journal;
  bool failRead = false;
  bool failStage = false;
  bool failResolution = false;
  Completer<void>? readGate;
  @override
  Future<List<StoredReview>> list(String userId) async {
    await readGate?.future;
    if (failRead) throw StateError('PRIVATE STORAGE PATH');
    return journal.list(userId);
  }

  @override
  Future<StoredReview> stage(String userId, Map<String, Object> request) {
    if (failStage) throw const ReviewStorageFailure();
    return journal.stage(userId, request);
  }

  @override
  Future<void> acknowledge(
    String userId,
    String eventId,
    ReviewSuccess receipt,
  ) {
    if (failResolution) throw const ReviewStorageFailure();
    return journal.acknowledge(userId, eventId, receipt);
  }

  @override
  Future<void> reject(String userId, String eventId, ReviewFailure rejection) {
    if (failResolution) throw const ReviewStorageFailure();
    return journal.reject(userId, eventId, rejection);
  }
}

final class RecoveryHarness {
  RecoveryHarness(NativeReviewJournal journal)
    : store = RecoveryStore(journal) {
    repository = DurableReviewRepository(
      auth: base.auth,
      delegate: base.repository,
      store: store,
    );
    controller = SrsStudyController(
      auth: base.auth,
      reviews: repository,
      queue: base.queue,
      now: () => base.instant,
      eventId: () =>
          'd2000000-0000-4000-8000-${(++newIds).toString().padLeft(12, '0')}',
    );
  }
  final base = StudyHarness();
  final RecoveryStore store;
  late final DurableReviewRepository repository;
  late final SrsStudyController controller;
  int newIds = 0;
  Future<void> stage([int id = 1]) async {
    await store.journal.stage(
      base.auth.currentSession!.userId,
      recoveryRequest(id),
    );
  }

  void dispose() {
    controller.dispose();
    base.dispose();
  }
}
