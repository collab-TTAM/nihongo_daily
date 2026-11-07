// TEST ONLY Auth, curriculum queue and RPC responses. No hosted evidence.
import 'dart:async';

import 'package:nihongo_daily/features/srs/application/srs_study_controller.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/domain/srs_models.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

final class FixtureStudyAuth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(
    userId: 'a1000000-0000-4000-8000-000000000001',
  );
}

SrsStudyItem fixtureItem({int id = 1, PreviewLevel level = PreviewLevel.n5}) =>
    SrsStudyItem(
      type: LearningItemType.vocabulary,
      itemId: 'b3000000-0000-4000-8000-${id.toString().padLeft(12, '0')}',
      level: level,
      prompt: id == 1 ? '猫' : '犬',
      reading: id == 1 ? 'ねこ' : 'いぬ',
      answerVi: id == 1 ? 'con mèo' : 'con chó',
    );

final class FixtureStudyQueue implements SrsStudyQueue {
  List<SrsStudyItem> items = [fixtureItem()];
  Future<List<SrsStudyItem>> Function()? loader;
  int calls = 0;
  ReviewSession? lastSession;
  PreviewLevel? lastLevel;
  @override
  Future<List<SrsStudyItem>> load(ReviewSession session, PreviewLevel level) {
    calls++;
    lastSession = session;
    lastLevel = level;
    return loader?.call() ?? Future.value(items);
  }
}

final class FixtureStudyRpc implements ReviewRpcTransport {
  final requests = <Map<String, Object>>[];
  Future<Object?> Function()? reply;
  Map<String, Object> get response => {
    'srs_state': 'LEARNING',
    'next_review_at': '2026-10-14T01:10:00.000Z',
    'interval_days': 10 / 1440,
    'difficulty': 0.5,
    'review_count': 1,
  };
  @override
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String function,
    required Map<String, Object> params,
  }) {
    if (function != 'submit_review' || params.keys.single != 'p_request') {
      throw StateError('Wrong RPC envelope');
    }
    requests.add(params['p_request']! as Map<String, Object>);
    return reply?.call() ?? Future.value(response);
  }
}

final class StudyHarness {
  StudyHarness({
    Duration saveTimeout = const Duration(seconds: 20),
    Duration loadTimeout = const Duration(seconds: 15),
  }) {
    repository = RpcReviewRepository(auth: auth, transport: rpc);
    controller = SrsStudyController(
      auth: auth,
      reviews: repository,
      queue: queue,
      now: () => instant,
      elapsedMs: () => ticks,
      eventId: () =>
          'b2000000-0000-4000-8000-${(++ids).toString().padLeft(12, '0')}',
      saveTimeout: saveTimeout,
      loadTimeout: loadTimeout,
    );
  }
  final auth = FixtureStudyAuth();
  final queue = FixtureStudyQueue();
  final rpc = FixtureStudyRpc();
  late final RpcReviewRepository repository;
  late final SrsStudyController controller;
  final changes = StreamController<void>.broadcast(sync: true);
  int ticks = 1000;
  int ids = 0;
  DateTime instant = DateTime.utc(2026, 10, 14, 1);
  Future<void> open() => controller.load(PreviewLevel.n5);
  void dispose() {
    controller.dispose();
    unawaited(changes.close());
  }
}
