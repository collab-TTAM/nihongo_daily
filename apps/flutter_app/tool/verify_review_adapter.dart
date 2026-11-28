// TEST ONLY transport/Auth fixtures. Exercises real repository encoding/decoding,
// not a deployed RPC, real JWT, persisted review or learner journey.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/domain/srs_models.dart';

final class FixtureAuth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(
    userId: 'a1000000-0000-4000-8000-000000000001',
  );
}

final class FixtureTransport implements ReviewRpcTransport {
  FixtureTransport(this.raw);
  Object? raw;
  Completer<Object?>? pending;
  int calls = 0;
  final requests = <Map<String, Object>>[];
  @override
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String function,
    required Map<String, Object> params,
  }) async {
    check(
      function == 'submit_review' &&
          params.length == 1 &&
          params.containsKey('p_request'),
      'wrong RPC envelope',
    );
    calls++;
    requests.add(params);
    return pending == null ? raw : await pending!.future;
  }
}

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void failure(ReviewOutcome result, ReviewErrorCode code, {bool retry = false}) {
  check(
    result is ReviewFailure && result.code == code && result.retryable == retry,
    'unsafe outcome',
  );
}

Future<void> main(List<String> args) async {
  if (args.length != 1) throw ArgumentError('Provide output JSON path');
  final bundle =
      jsonDecode(File('../../contracts/srs/v1/golden.json').readAsStringSync())
          as Map<String, dynamic>;
  final outputs = <Map<String, Object?>>[];
  for (final raw in bundle['cases'] as List<dynamic>) {
    final c = raw as Map<String, dynamic>;
    final request = c['request'] as Map<String, dynamic>;
    final expected = c['expected_response'] as Map<String, dynamic>;
    final review = SrsReview(
      clientEventId: request['client_event_id'] as String,
      itemType: LearningItemType.values.singleWhere(
        (type) => type.wireName == request['item_type'],
      ),
      itemId: request['item_id'] as String,
      rating: ReviewRating.fromWire(request['rating'] as int),
      isCorrect: request['is_correct'] as bool,
      responseMs: request['response_ms'] as int,
      occurredAt: DateTime.parse(request['occurred_at'] as String),
    );
    final auth = FixtureAuth();
    final transport = FixtureTransport(expected);
    final repository = RpcReviewRepository(auth: auth, transport: transport);
    final prepared = repository.prepare(review)!;
    final result = await repository.submit(prepared);
    check(result is ReviewSuccess, 'valid fixture failed decoding');
    final response = (result as ReviewSuccess).toJson();
    for (final key in expected.keys) {
      check(response[key] == expected[key], 'fixture output differs: $key');
    }
    outputs.add({
      'name': c['name'],
      'request': prepared.request,
      'response': response,
    });
    for (final date in [
      '2026-02-30T00:00:00Z',
      '2026-01-01T24:00:00Z',
      '2026-01-01T00:00:60Z',
      '2026-01-01T00:00:00',
      '2026-01-01T00:00:00+24:00',
    ]) {
      failure(
        decodeReviewOutcome({...expected, 'next_review_at': date}),
        ReviewErrorCode.internalError,
      );
    }
    failure(
      decodeReviewOutcome({...expected, 'private_owner': 'PRIVATE SECRET'}),
      ReviewErrorCode.internalError,
    );
    failure(
      decodeReviewOutcome({...expected, 'review_count': true}),
      ReviewErrorCode.internalError,
    );
    failure(
      decodeReviewOutcome({...expected, 'difficulty': double.nan}),
      ReviewErrorCode.internalError,
    );
    final timed = RpcReviewRepository(
      auth: auth,
      transport: transport,
      timeout: const Duration(milliseconds: 1),
    );
    transport.pending = Completer<Object?>();
    failure(
      await timed.submit(prepared),
      ReviewErrorCode.networkUnavailable,
      retry: true,
    );
    transport.pending!.complete(expected);
    transport.pending = null;
    check(
      await repository.submit(prepared) is ReviewSuccess,
      'immutable retry failed',
    );
    check(
      jsonEncode(transport.requests.first) ==
          jsonEncode(transport.requests.last),
      'retry changed event identity or payload',
    );
    final pending = Completer<Object?>();
    transport.pending = pending;
    final inFlight = repository.submit(prepared);
    auth.currentSession = ReviewSession(userId: prepared.session.userId);
    pending.complete(expected);
    failure(await inFlight, ReviewErrorCode.unauthorized);
    final calls = transport.calls;
    failure(await repository.submit(prepared), ReviewErrorCode.unauthorized);
    check(transport.calls == calls, 'stale session dispatched');
  }
  for (final code in ReviewErrorCode.values) {
    final result = decodeReviewOutcome({
      'code': code.wireName,
      'message_vi': 'PRIVATE SECRET',
      'retryable': false,
    });
    failure(result, code);
    check(
      !(result as ReviewFailure).messageVi.contains('PRIVATE SECRET'),
      'raw details escaped',
    );
  }
  File(args.single).writeAsStringSync(
    jsonEncode({'algorithm': bundle['algorithm'], 'cases': outputs}),
  );
  stdout.writeln(
    'PASS: ${outputs.length} fixture adapter pairs, strict decoding, '
    'immutable timeout/retry and session-change isolation (TEST ONLY ports)',
  );
}
