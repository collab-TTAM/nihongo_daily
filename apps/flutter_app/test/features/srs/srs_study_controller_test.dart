import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/srs/application/srs_study_controller.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/domain/srs_models.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

import 'study_fixtures.dart';

void main() {
  late StudyHarness h;
  setUp(() => h = StudyHarness());
  tearDown(() => h.dispose());

  test('level change loads a fresh queue and resets revealed content', () async {
    await h.open();
    h.controller.reveal();
    h.queue.items = [fixtureItem(id: 2, level: PreviewLevel.n4)];
    await h.controller.changeLevel(PreviewLevel.n4);
    expect(h.controller.selectedLevel, PreviewLevel.n4);
    expect(h.queue.lastLevel, PreviewLevel.n4);
    expect(h.controller.state.item!.prompt, '犬');
    expect(h.controller.state.answerVisible, isFalse);
    expect(h.controller.state.confirmed, 0);
    expect(h.rpc.requests, isEmpty);
    await h.controller.changeLevel(PreviewLevel.n4);
    expect(h.queue.calls, 2);
  });

  test('level changes cannot race a queue load', () async {
    final pending = Completer<List<SrsStudyItem>>();
    h.queue.loader = () => pending.future;
    final load = h.open();
    await h.controller.changeLevel(PreviewLevel.n4);
    expect(h.controller.selectedLevel, PreviewLevel.n5);
    expect(h.queue.calls, 1);
    pending.complete([fixtureItem()]);
    await load;
    expect(h.controller.state.item!.level, PreviewLevel.n5);
  });

  for (final code in ['NETWORK_UNAVAILABLE', 'SYNC_CONFLICT']) {
    test('level change preserves a pending or rejected $code event', () async {
      await h.open();
      h.controller.reveal();
      final response = Completer<Object?>();
      h.rpc.reply = () => response.future;
      final save = h.controller.rate(ReviewRating.good);
      await h.controller.changeLevel(PreviewLevel.n4);
      expect(h.controller.selectedLevel, PreviewLevel.n5);
      expect(h.queue.calls, 1);
      final original = Map<String, Object>.from(h.rpc.requests.single);
      response.complete({
        'code': code,
        'message_vi': 'TEST ONLY',
        'retryable': code == 'NETWORK_UNAVAILABLE',
      });
      await save;
      await h.controller.changeLevel(PreviewLevel.n4);
      expect(h.controller.selectedLevel, PreviewLevel.n5);
      expect(h.controller.state.hasPendingEvent, isTrue);
      expect(h.controller.state.confirmed, 0);
      expect(h.queue.calls, 1);
      expect(h.rpc.requests.single, original);
      expect(h.ids, 1);
      if (code == 'NETWORK_UNAVAILABLE') {
        h.rpc.reply = null;
        await h.controller.retry();
        expect(h.rpc.requests.last, original);
      } else {
        // Rejection still requires the existing explicit discard/reload action.
        expect(h.controller.state.canReload, isTrue);
        await h.controller.load(PreviewLevel.n5);
        expect(h.controller.state.hasPendingEvent, isFalse);
      }
    });
  }

  test('failed selected queue stays selected and logout clears it', () async {
    await h.open();
    final pending = Completer<List<SrsStudyItem>>();
    h.queue.loader = () => pending.future;
    final change = h.controller.changeLevel(PreviewLevel.n4);
    pending.completeError(StateError('PRIVATE QUEUE'));
    await change;
    expect(h.controller.selectedLevel, PreviewLevel.n4);
    expect(h.controller.state.item, isNull);
    expect(h.controller.state.failure!.messageVi, isNot(contains('PRIVATE')));
    h.queue.loader = null;
    h.queue.items = [fixtureItem(level: PreviewLevel.n4)];
    await h.controller.load(h.controller.selectedLevel!);
    expect(h.queue.lastLevel, PreviewLevel.n4);
    expect(h.controller.state.item!.level, PreviewLevel.n4);
    h.auth.currentSession = null;
    h.controller.sessionChanged();
    expect(h.controller.selectedLevel, isNull);
    expect(h.controller.state.item, isNull);
    await h.controller.changeLevel(PreviewLevel.n5);
    expect(h.queue.calls, 3);
    expect(h.controller.state.phase, SrsStudyPhase.signedOut);
  });

  test('no account cannot load curriculum or submit a review', () async {
    h.auth.currentSession = null;
    await h.open();
    h.controller.reveal();
    await h.controller.rate(ReviewRating.easy);
    expect(h.controller.state.phase, SrsStudyPhase.signedOut);
    expect(h.queue.calls, 0);
    expect(h.rpc.requests, isEmpty);
  });

  test('loading and empty queue do not fabricate confirmed reviews', () async {
    final pending = Completer<List<SrsStudyItem>>();
    h.queue.loader = () => pending.future;
    final load = h.open();
    expect(h.controller.state.phase, SrsStudyPhase.loading);
    await h.open(); // No concurrent reload.
    expect(h.queue.calls, 1);
    pending.complete([]);
    await load;
    expect(h.controller.state.phase, SrsStudyPhase.empty);
    expect(h.controller.state.confirmed, 0);
    expect(h.controller.state.receipt, isNull);
  });

  test(
    'reveal is required before rating and successful receipt advances once',
    () async {
      h.queue.items = [fixtureItem(), fixtureItem(id: 2)];
      await h.open();
      await h.controller.rate(ReviewRating.good);
      expect(h.rpc.requests, isEmpty);
      expect(h.controller.state.answerVisible, isFalse);
      h.controller.reveal();
      h.ticks += 1234;
      await h.controller.rate(ReviewRating.good);
      expect(h.rpc.requests.single['response_ms'], 1234);
      expect(h.rpc.requests.single['is_correct'], isTrue);
      expect(h.controller.state.confirmed, 1);
      expect(h.controller.state.item!.prompt, '犬');
      expect(h.controller.state.answerVisible, isFalse);
      expect(h.controller.state.receipt, isA<ReviewSuccess>());
      h.controller.reveal();
      await h.controller.rate(ReviewRating.again);
      expect(h.rpc.requests.last['is_correct'], isFalse);
      expect(h.controller.state.phase, SrsStudyPhase.complete);
      expect(h.controller.state.confirmed, 2);
      expect(h.ids, 2);
    },
  );

  test(
    'duplicate rating and reload while saving cannot dispatch another event',
    () async {
      await h.open();
      h.controller.reveal();
      final reply = Completer<Object?>();
      h.rpc.reply = () => reply.future;
      final save = h.controller.rate(ReviewRating.good);
      await h.controller.rate(ReviewRating.easy);
      await h.controller.retry();
      await h.open();
      expect(h.rpc.requests.length, 1);
      expect(h.queue.calls, 1);
      expect(h.ids, 1);
      expect(h.controller.state.confirmed, 0);
      reply.complete(h.rpc.response);
      await save;
      expect(h.controller.state.confirmed, 1);
    },
  );

  test(
    'uncertain network retry retains exact timestamp rating duration and ID',
    () async {
      await h.open();
      h.controller.reveal();
      h.rpc.reply = () => Future.error(
        const ReviewTransportFailure(
          ReviewErrorCode.networkUnavailable,
          retryable: true,
        ),
      );
      await h.controller.rate(ReviewRating.hard);
      expect(h.controller.state.canRetry, isTrue);
      expect(h.controller.state.canReload, isFalse);
      expect(h.controller.state.confirmed, 0);
      final original = Map<String, Object>.from(h.rpc.requests.single);
      h.instant = h.instant.add(const Duration(days: 3));
      h.ticks += 20000;
      await h.controller.rate(ReviewRating.easy);
      await h.open();
      expect(h.ids, 1);
      expect(h.queue.calls, 1);
      h.rpc.reply = null;
      await h.controller.retry();
      expect(h.rpc.requests.last, original);
      expect(h.ids, 1);
      expect(h.controller.state.confirmed, 1);
    },
  );

  test('same-event retry also suppresses duplicate retry taps', () async {
    await h.open();
    h.controller.reveal();
    h.rpc.reply = () => Future.value({
      'code': 'RATE_LIMITED',
      'message_vi': 'TEST ONLY',
      'retryable': true,
    });
    await h.controller.rate(ReviewRating.good);
    final pending = Completer<Object?>();
    h.rpc.reply = () => pending.future;
    final retry = h.controller.retry();
    await h.controller.retry();
    expect(h.rpc.requests.length, 2);
    pending.complete(h.rpc.response);
    await retry;
    expect(h.controller.state.confirmed, 1);
  });

  test(
    'malformed success cannot mark a review saved or discard uncertain event',
    () async {
      await h.open();
      h.controller.reveal();
      h.rpc.reply = () =>
          Future.value({...h.rpc.response, 'private_owner': 'secret'});
      await h.controller.rate(ReviewRating.good);
      expect(h.controller.state.phase, SrsStudyPhase.failed);
      expect(h.controller.state.failure!.code, ReviewErrorCode.internalError);
      expect(h.controller.state.confirmed, 0);
      expect(h.controller.state.hasPendingEvent, isTrue);
      expect(h.controller.state.canReload, isFalse);
    },
  );

  test(
    'definitive conflict permits explicit reload but never changes rating automatically',
    () async {
      await h.open();
      h.controller.reveal();
      h.rpc.reply = () => Future.value({
        'code': 'SYNC_CONFLICT',
        'message_vi': 'PRIVATE SECRET',
        'retryable': false,
      });
      await h.controller.rate(ReviewRating.good);
      expect(h.controller.state.confirmed, 0);
      expect(h.controller.state.canReload, isTrue);
      expect(h.controller.state.canRetry, isFalse);
      await h.controller.retry();
      expect(h.rpc.requests.length, 1);
      h.queue.items = [];
      await h.open();
      expect(h.controller.state.hasPendingEvent, isFalse);
      expect(h.controller.state.phase, SrsStudyPhase.empty);
    },
  );

  test('wrong-level duplicate and excessive queues fail closed', () async {
    for (final items in [
      [fixtureItem(level: PreviewLevel.n4)],
      [fixtureItem(), fixtureItem()],
      List.generate(101, (i) => fixtureItem(id: i + 1)),
    ]) {
      h.queue.items = items;
      await h.open();
      expect(h.controller.state.phase, SrsStudyPhase.failed);
      expect(h.controller.state.item, isNull);
      expect(h.controller.state.confirmed, 0);
    }
  });

  test('queue exceptions are safe and explicitly reloadable', () async {
    h.queue.loader = () => throw StateError('PRIVATE SECRET');
    await h.open();
    expect(
      h.controller.state.failure!.messageVi,
      isNot(contains('PRIVATE SECRET')),
    );
    expect(h.controller.state.canReload, isTrue);
    h.queue.loader = null;
    await h.open();
    expect(h.controller.state.phase, SrsStudyPhase.ready);
  });

  test(
    'session switch immediately clears visible item and rejects late queue data',
    () async {
      final pending = Completer<List<SrsStudyItem>>();
      h.queue.loader = () => pending.future;
      final load = h.open();
      h.auth.currentSession = ReviewSession(
        userId: 'a1000000-0000-4000-8000-000000000002',
      );
      h.controller.sessionChanged();
      pending.complete([fixtureItem()]);
      await load;
      expect(h.controller.state.phase, SrsStudyPhase.signedOut);
      expect(h.controller.state.item, isNull);
      expect(h.controller.state.receipt, isNull);
      h.queue.loader = null;
      await h.open();
      expect(h.queue.lastSession, same(h.auth.currentSession));
    },
  );

  test(
    'late previous-session save and A B A never increment new session UI',
    () async {
      await h.open();
      h.controller.reveal();
      final pending = Completer<Object?>();
      h.rpc.reply = () => pending.future;
      final save = h.controller.rate(ReviewRating.good);
      h.auth.currentSession = ReviewSession(
        userId: 'a1000000-0000-4000-8000-000000000002',
      );
      h.controller.sessionChanged();
      h.auth.currentSession = ReviewSession(
        userId: 'a1000000-0000-4000-8000-000000000001',
      );
      h.controller.sessionChanged();
      pending.complete(h.rpc.response);
      await save;
      expect(h.controller.state.item, isNull);
      expect(h.controller.state.confirmed, 0);
      expect(h.controller.state.receipt, isNull);
      expect(h.controller.state.phase, SrsStudyPhase.signedOut);
    },
  );

  test(
    'session hint mismatch on user action clears stale curriculum',
    () async {
      await h.open();
      h.auth.currentSession = null;
      h.controller.reveal();
      expect(h.controller.state.item, isNull);
      expect(h.rpc.requests, isEmpty);
    },
  );

  test(
    'disposal while loading or saving cannot publish later results',
    () async {
      await h.open();
      h.controller.reveal();
      final pending = Completer<Object?>();
      h.rpc.reply = () => pending.future;
      final save = h.controller.rate(ReviewRating.good);
      h.controller.dispose();
      pending.complete(h.rpc.response);
      await save;
      expect(h.controller.state.phase, SrsStudyPhase.unavailable);
      expect(h.controller.state.item, isNull);
      expect(h.controller.state.receipt, isNull);
    },
  );

  test('queue timeout can be retried without a review event', () async {
    final short = StudyHarness(loadTimeout: const Duration(milliseconds: 1));
    addTearDown(short.dispose);
    final pending = Completer<List<SrsStudyItem>>();
    short.queue.loader = () => pending.future;
    await short.open();
    expect(
      short.controller.state.failure!.code,
      ReviewErrorCode.networkUnavailable,
    );
    expect(short.controller.state.canReload, isTrue);
    expect(short.rpc.requests, isEmpty);
    pending.complete([fixtureItem()]);
  });

  test(
    'controller save deadline is uncertain and preserves same-event retry',
    () async {
      final short = StudyHarness(saveTimeout: const Duration(milliseconds: 1));
      addTearDown(short.dispose);
      await short.open();
      short.controller.reveal();
      final pending = Completer<Object?>();
      short.rpc.reply = () => pending.future;
      await short.controller.rate(ReviewRating.good);
      expect(short.controller.state.canRetry, isTrue);
      expect(short.controller.state.confirmed, 0);
      pending.complete(short.rpc.response);
      short.rpc.reply = null;
      await short.controller.retry();
      expect(short.rpc.requests[0], short.rpc.requests[1]);
      expect(short.controller.state.confirmed, 1);
    },
  );

  test(
    'timing clamps negative or very long monotonic elapsed values',
    () async {
      for (final tick in [-1, 999999999]) {
        await h.open();
        h.controller.reveal();
        h.ticks = tick;
        await h.controller.rate(ReviewRating.good);
        expect(
          h.rpc.requests.last['response_ms'],
          inInclusiveRange(0, 3600000),
        );
      }
    },
  );

  test('curriculum projection rejects blank oversized or malformed fields', () {
    for (final text in ['', ' ', 'a' * 5001]) {
      expect(
        () => SrsStudyItem(
          type: LearningItemType.grammar,
          itemId: fixtureItem().itemId,
          level: PreviewLevel.n5,
          prompt: text,
          reading: 'よみ',
          answerVi: 'nghĩa',
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => SrsStudyItem(
        type: LearningItemType.kanji,
        itemId: 'bad',
        level: PreviewLevel.n5,
        prompt: '日',
        reading: 'ひ',
        answerVi: 'ngày',
      ),
      throwsArgumentError,
    );
  });

  test('random event factory emits distinct lower-case UUID v4 IDs', () {
    final ids = List.generate(100, (_) => newReviewEventId());
    expect(ids.toSet().length, 100);
    for (final id in ids) {
      expect(
        id,
        matches(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      );
    }
  });
}
