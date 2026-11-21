// TEST ONLY queue/Auth/server-response fixtures. Actual controller/repository
// encodings, not a real database transaction, authenticated service or UI test.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nihongo_daily/features/srs/application/srs_study_controller.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/domain/srs_models.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

final class FixtureAuth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(
    userId: 'a1000000-0000-4000-8000-000000000001',
  );
}

final class FixtureQueue implements SrsStudyQueue {
  FixtureQueue(this.item);
  final SrsStudyItem item;
  @override
  Future<List<SrsStudyItem>> load(
    ReviewSession session,
    PreviewLevel level,
  ) async => [item];
}

final class FixtureTransport implements ReviewRpcTransport {
  FixtureTransport(this.response);
  final Map<String, Object?> response;
  bool fail = true;
  Completer<Object?>? pending;
  final requests = <Map<String, Object>>[];
  @override
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String function,
    required Map<String, Object> params,
  }) async {
    check(
      function == 'submit_review' && params.keys.single == 'p_request',
      'wrong envelope',
    );
    requests.add(params['p_request']! as Map<String, Object>);
    if (fail) {
      throw const ReviewTransportFailure(
        ReviewErrorCode.networkUnavailable,
        retryable: true,
      );
    }
    return pending == null ? response : await pending!.future;
  }
}

void check(bool value, String reason) {
  if (!value) throw StateError(reason);
}

Future<void> main(List<String> args) async {
  if (args.length != 1) throw ArgumentError('Provide output JSON path');
  final bundle =
      jsonDecode(File('../../contracts/srs/v1/golden.json').readAsStringSync())
          as Map<String, dynamic>;
  final outputs = <Map<String, Object?>>[];
  for (final entry in bundle['cases'] as List<dynamic>) {
    final c = entry as Map<String, dynamic>;
    final request = c['request'] as Map<String, dynamic>;
    final auth = FixtureAuth();
    final type = LearningItemType.values.singleWhere(
      (type) => type.wireName == request['item_type'],
    );
    final queue = FixtureQueue(
      SrsStudyItem(
        type: type,
        itemId: request['item_id'] as String,
        level: PreviewLevel.n5,
        prompt: '猫',
        reading: 'ねこ',
        answerVi: 'con mèo',
      ),
    );
    final transport = FixtureTransport(
      c['expected_response'] as Map<String, dynamic>,
    );
    final repository = RpcReviewRepository(auth: auth, transport: transport);
    var ticks = 0;
    var generated = 0;
    final controller = SrsStudyController(
      auth: auth,
      reviews: repository,
      queue: queue,
      now: () => DateTime.parse(request['occurred_at'] as String),
      eventId: () {
        generated++;
        return request['client_event_id'] as String;
      },
      elapsedMs: () => ticks,
    );
    try {
      await controller.load(PreviewLevel.n5);
      final rating = ReviewRating.fromWire(request['rating'] as int);
      await controller.rate(rating);
      check(transport.requests.isEmpty, 'rating before reveal dispatched');
      controller.reveal();
      ticks = request['response_ms'] as int;
      await controller.rate(rating);
      check(
        controller.state.canRetry &&
            !controller.state.canReload &&
            controller.state.confirmed == 0,
        'uncertain result was not retained',
      );
      await controller.load(PreviewLevel.n4);
      await controller.rate(ReviewRating.easy);
      transport.fail = false;
      ticks += 5000;
      await controller.retry();
      check(
        generated == 1 &&
            transport.requests.length == 2 &&
            jsonEncode(transport.requests[0]) ==
                jsonEncode(transport.requests[1]),
        'retry changed immutable event',
      );
      check(
        controller.state.phase == SrsStudyPhase.complete &&
            controller.state.confirmed == 1,
        'confirmed fixture did not advance',
      );
      outputs.add({
        'name': c['name'],
        'request': transport.requests.last,
        'response': controller.state.receipt!.toJson(),
      });
      await controller.load(PreviewLevel.n5);
      controller.reveal();
      transport.pending = Completer<Object?>();
      final save = controller.rate(rating);
      auth.currentSession = null;
      controller.sessionChanged();
      transport.pending!.complete(transport.response);
      await save;
      check(
        controller.state.item == null &&
            controller.state.receipt == null &&
            controller.state.confirmed == 0,
        'old-session reply leaked into UI',
      );
    } finally {
      controller.dispose();
    }
  }
  File(args.single).writeAsStringSync(
    jsonEncode({'algorithm': bundle['algorithm'], 'cases': outputs}),
  );
  stdout.writeln(
    'PASS: ${outputs.length} TEST ONLY controller/repository pairs; '
    'reveal/rating, uncertain same-event retry and old-session suppression',
  );
}
