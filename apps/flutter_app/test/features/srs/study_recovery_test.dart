import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/srs/application/srs_study_controller.dart';
import 'package:nihongo_daily/features/srs/data/durable_review_repository.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/domain/srs_models.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';
import 'recovery_fixtures.dart';

void main() {
  late Directory directory;
  late NativeReviewJournal journal;
  late RecoveryHarness h;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nd-recovery-test-');
    journal = await NativeReviewJournal.open(directory);
    h = RecoveryHarness(journal);
  });
  tearDown(() async {
    h.dispose();
    await journal.close();
    await directory.delete(recursive: true);
  });
  Future<void> open() => h.controller.load(PreviewLevel.n5);
  test(
    'pending blocks queue new IDs rating and reload until explicit same-event retry',
    () async {
      await h.stage();
      await open();
      expect(h.controller.state.phase, SrsStudyPhase.recoveryReady);
      expect(h.controller.state.canRate, isFalse);
      expect(h.controller.state.canReload, isFalse);
      expect(h.controller.state.canRetry, isTrue);
      h.controller.reveal();
      await h.controller.rate(ReviewRating.easy);
      await open();
      expect(h.newIds, 0);
      expect(h.base.queue.calls, 0);
      expect(h.base.rpc.requests, isEmpty);
      await h.controller.retry();
      expect(h.base.rpc.requests.single, recoveryRequest());
      expect(h.base.queue.calls, 1);
      expect(h.controller.state.confirmed, 0);
      expect(h.controller.state.receipt, isNull);
    },
  );
  test(
    'multiple pending events all reconcile before loading selected level',
    () async {
      await h.stage();
      await h.stage(2);
      await open();
      await h.controller.retry();
      expect(h.controller.state.recoveryRemaining, 1);
      expect(h.base.queue.calls, 0);
      await h.controller.retry();
      expect(h.base.rpc.requests, [recoveryRequest(), recoveryRequest(2)]);
      expect(h.base.queue.calls, 1);
      expect(h.controller.state.phase, SrsStudyPhase.ready);
    },
  );
  test('retry taps while reconciling share one controller dispatch', () async {
    await h.stage();
    await open();
    final response = Completer<Object?>();
    h.base.rpc.reply = () => response.future;
    final one = h.controller.retry();
    await h.controller.retry();
    await open();
    await Future<void>.delayed(Duration.zero);
    expect(h.base.rpc.requests.length, 1);
    response.complete(h.base.rpc.response);
    await one;
  });
  test('storage read error blocks cards and manual recheck is safe', () async {
    await h.stage();
    h.store.failRead = true;
    await open();
    expect(h.controller.state.failure!.isLocalStorage, isTrue);
    expect(h.controller.state.failure!.messageVi, isNot(contains('PRIVATE')));
    expect(h.base.queue.calls, 0);
    h.store.failRead = false;
    await open();
    expect(h.controller.state.phase, SrsStudyPhase.recoveryReady);
  });
  test(
    'storage stage failure permits exact manual retry without new ID or RPC',
    () async {
      await open();
      h.controller.reveal();
      h.store.failStage = true;
      await h.controller.rate(ReviewRating.good);
      expect(h.base.rpc.requests, isEmpty);
      expect(h.controller.state.canRetry, isTrue);
      expect(h.controller.state.canReload, isFalse);
      expect(h.newIds, 1);
      h.store.failStage = false;
      await h.controller.retry();
      expect(h.newIds, 1);
      expect(h.base.rpc.requests.length, 1);
      expect(h.base.queue.calls, 2);
    },
  );
  test(
    'failed receipt persistence retains pending then replays original event',
    () async {
      await h.stage();
      await open();
      h.store.failResolution = true;
      await h.controller.retry();
      expect(h.controller.state.failure!.isLocalStorage, isTrue);
      expect(h.controller.state.canRetry, isTrue);
      expect(h.base.queue.calls, 0);
      h.store.failResolution = false;
      await h.controller.retry();
      expect(h.base.rpc.requests[0], h.base.rpc.requests[1]);
      expect(h.base.queue.calls, 1);
    },
  );
  test(
    'malformed or uncertain server outcome remains pending with explicit retry',
    () async {
      await h.stage();
      await open();
      h.base.rpc.reply = () async => {'fake': 'success'};
      await h.controller.retry();
      expect(h.controller.state.canRetry, isTrue);
      expect(h.controller.state.canReload, isFalse);
      expect(
        (await journal.list(
          h.base.auth.currentSession!.userId,
        )).single.isPending,
        isTrue,
      );
      h.base.rpc.reply = null;
      await h.controller.retry();
      expect(h.base.queue.calls, 1);
    },
  );
  test(
    'definitive rejection is durable and requires explicit authoritative reload',
    () async {
      await h.stage();
      await open();
      h.base.rpc.reply = () async => {
        'code': 'SYNC_CONFLICT',
        'message_vi': 'TEST ONLY stale',
        'retryable': false,
      };
      await h.controller.retry();
      expect(h.controller.state.canRetry, isFalse);
      expect(h.controller.state.canReload, isTrue);
      final owner = h.base.auth.currentSession!.userId;
      expect(
        (await journal.list(owner)).single.rejection!.code,
        ReviewErrorCode.syncConflict,
      );
      await open();
      expect(h.base.queue.calls, 1);
      expect(h.base.rpc.requests.length, 1);
      expect(h.controller.state.receipt, isNull);
    },
  );
  test('rejection write failure cannot discard unresolved event', () async {
    await h.stage();
    await open();
    h.store.failResolution = true;
    h.base.rpc.reply = () async => {
      'code': 'NOT_FOUND',
      'message_vi': 'TEST ONLY retired',
      'retryable': false,
    };
    await h.controller.retry();
    expect(h.controller.state.canReload, isFalse);
    expect(h.controller.state.canRetry, isTrue);
    expect(
      (await journal.list(h.base.auth.currentSession!.userId)).single.isPending,
      isTrue,
    );
  });
  test('logout during recovery clears pending and rejects late read', () async {
    await h.stage();
    h.store.readGate = Completer<void>();
    final load = open();
    h.base.auth.currentSession = null;
    h.controller.sessionChanged();
    h.store.readGate!.complete();
    await load;
    expect(h.controller.state.phase, SrsStudyPhase.signedOut);
    expect(h.controller.state.recoveryRequest, isNull);
    expect(h.base.queue.calls, 0);
  });
  test('A-B-A fresh login cannot revive old recovery result', () async {
    await h.stage();
    h.store.readGate = Completer<void>();
    final load = open();
    h.base.auth.currentSession = ReviewSession(
      userId: 'a1000000-0000-4000-8000-000000000002',
    );
    h.controller.sessionChanged();
    h.base.auth.currentSession = ReviewSession(
      userId: 'a1000000-0000-4000-8000-000000000001',
    );
    h.store.readGate!.complete();
    await load;
    expect(h.controller.state.recoveryRequest, isNull);
    expect(h.base.queue.calls, 0);
    h.store.readGate = null;
    await open();
    expect(h.controller.state.phase, SrsStudyPhase.recoveryReady);
  });
  test(
    'session switch during submit hides late receipt and preserves original owner journal',
    () async {
      await h.stage();
      await open();
      final reply = Completer<Object?>();
      h.base.rpc.reply = () => reply.future;
      final submit = h.controller.retry();
      await Future<void>.delayed(Duration.zero);
      h.base.auth.currentSession = ReviewSession(
        userId: 'a1000000-0000-4000-8000-000000000002',
      );
      h.controller.sessionChanged();
      reply.complete(h.base.rpc.response);
      await submit;
      expect(h.controller.state.recoveryRequest, isNull);
      expect(h.controller.state.receipt, isNull);
      expect(h.base.queue.calls, 0);
    },
  );
  test(
    'dispose while reading recovery cannot load curriculum or publish pending',
    () async {
      await h.stage();
      h.store.readGate = Completer<void>();
      final load = open();
      h.controller.dispose();
      h.store.readGate!.complete();
      await load;
      expect(h.controller.state.phase, SrsStudyPhase.unavailable);
      expect(h.base.queue.calls, 0);
    },
  );
  test(
    'queue failure after acknowledgment never re-dispatches resolved event',
    () async {
      await h.stage();
      await open();
      h.base.queue.loader = () => Future.error(StateError('PRIVATE'));
      await h.controller.retry();
      expect(h.controller.state.hasPendingEvent, isFalse);
      expect(h.controller.state.canReload, isTrue);
      h.base.queue.loader = null;
      await open();
      expect(h.base.rpc.requests.length, 1);
    },
  );
  test(
    'journal reads v1 history and rejects nondefinitive terminal resolution',
    () async {
      h.dispose();
      await journal.close();
      final path = File(
        '${directory.path}${Platform.pathSeparator}review-journal.ndjson',
      );
      await path.writeAsString(
        '${jsonEncode({'version': 1, 'kind': 'pending', 'user_id': 'a1000000-0000-4000-8000-000000000001', 'request': recoveryRequest()})}\n',
        flush: true,
      );
      journal = await NativeReviewJournal.open(directory);
      h = RecoveryHarness(journal);
      await expectLater(
        journal.reject(
          h.base.auth.currentSession!.userId,
          recoveryRequest()['client_event_id']! as String,
          ReviewFailure(ReviewErrorCode.unauthorized),
        ),
        throwsA(isA<ReviewStorageFailure>()),
      );
      await open();
      await h.controller.retry();
      expect(h.base.queue.calls, 1);
    },
  );
  test('synchronous revocation on loading prevents queue dispatch', () async {
    final subscription = h.controller.changes.listen((state) {
      if (state.phase == SrsStudyPhase.loading) h.controller.sessionChanged();
    });
    await open();
    expect(h.base.queue.calls, 0);
    expect(h.controller.state.phase, SrsStudyPhase.signedOut);
    await subscription.cancel();
  });
  test(
    'synchronous disposal on loading safely closes notification stream',
    () async {
      final subscription = h.controller.changes.listen((state) {
        if (state.phase == SrsStudyPhase.loading) h.controller.dispose();
      });
      await open();
      expect(h.base.queue.calls, 0);
      expect(h.controller.state.phase, SrsStudyPhase.unavailable);
      await subscription.cancel();
    },
  );
}
