// Decodes supplied SQL/fixture output through the real Dart DTO and RPC queue.
// CI passes actual native SQL fixture-role output. Local hand-authored input is
// TEST ONLY; neither proves SDK/JWT/PostgREST or a persisted learner journey.
import 'dart:convert';
import 'dart:io';

import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/data/rpc_srs_study_queue.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

final class FixtureAuth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(
    userId: 'd1000000-0000-4000-8000-000000000001',
  );
}

final class InputTransport implements ReviewRpcTransport {
  InputTransport(this.response, this.request);
  final Object? response;
  final Map<String, dynamic> request;
  @override
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String function,
    required Map<String, Object> params,
  }) async {
    if (function != 'get_review_queue' ||
        params.keys.single != 'p_request' ||
        jsonEncode(params['p_request']) != jsonEncode(request)) {
      // Compare fields rather than serialized object order from PostgreSQL JSONB.
      final inner = params['p_request'] as Map<String, Object>?;
      if (function != 'get_review_queue' ||
          params.length != 1 ||
          inner == null ||
          inner.length != request.length ||
          !request.keys.every((key) => inner[key] == request[key])) {
        throw StateError('Unexpected queue RPC wrapper');
      }
    }
    return response;
  }
}

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError('Provide input and output JSON paths');
  }
  final bundle =
      jsonDecode(File(args[0]).readAsStringSync()) as Map<String, dynamic>;
  if (bundle['version'] != 'nd-review-queue-1') {
    throw StateError('Wrong version');
  }
  final outputs = <Map<String, Object?>>[];
  for (final raw in bundle['cases'] as List<dynamic>) {
    final c = raw as Map<String, dynamic>;
    final request = c['request'] as Map<String, dynamic>;
    final response = c['response'] as Map<String, dynamic>;
    final level = request['jlpt_level'] == 'N5'
        ? PreviewLevel.n5
        : PreviewLevel.n4;
    final limit = (request['limit'] as num).toInt();
    Map<String, Object> encoded;
    try {
      final snapshot = ReviewQueueSnapshot.decode(
        response,
        level: level,
        limit: limit,
      );
      final auth = FixtureAuth();
      final queue = RpcSrsStudyQueue(
        auth: auth,
        transport: InputTransport(response, request),
        limit: limit,
      );
      final items = await queue.load(auth.currentSession!, level);
      if (items.length != snapshot.items.length ||
          items.asMap().entries.any(
            (entry) =>
                entry.value.itemId != snapshot.items[entry.key].item.itemId,
          )) {
        throw StateError('Application queue lost the wire projection');
      }
      encoded = snapshot.toJson();
    } on ReviewTransportFailure catch (error) {
      if (!response.containsKey('code') ||
          error.code.wireName != response['code']) {
        throw StateError('Unexpected queue decoding failure');
      }
      encoded = ReviewFailure(error.code, retryable: error.retryable).toJson();
    }
    outputs.add({'name': c['name'], 'request': request, 'response': encoded});
  }
  if (outputs.length != 7) throw StateError('Missing queue cases');
  File(args[1]).writeAsStringSync(
    jsonEncode({'version': bundle['version'], 'cases': outputs}),
  );
  stdout.writeln(
    'PASS: decoded ${outputs.length} supplied queue projections through Dart DTO/RPC adapter; no SDK/JWT claim',
  );
}
