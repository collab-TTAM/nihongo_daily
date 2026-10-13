// Runs the pure domain on shared cases and emits real wire encodings for the
// Python schema validator. It needs only dart: libraries, no Flutter dependency.
import 'dart:convert';
import 'dart:io';
import 'package:nihongo_daily/features/srs/domain/srs_models.dart';
import 'package:nihongo_daily/features/srs/domain/srs_scheduler.dart';

void verifyFields(Map<String, Object?> actual, Map<String, dynamic> expected) {
  if (actual.length != expected.length ||
      !actual.keys.toSet().containsAll(expected.keys)) {
    throw StateError('Output fields differ from the golden projection');
  }
  for (final key in expected.keys) {
    final value = expected[key];
    final got = actual[key];
    if (value is num && got is num) {
      if ((value - got).abs() > 1e-12) throw StateError('Mismatch: $key');
    } else if (got != value) {
      throw StateError('Mismatch: $key ($got != $value)');
    }
  }
}

void main(List<String> arguments) {
  if (arguments.length != 1) throw ArgumentError('Provide an output JSON file');
  final bundle =
      jsonDecode(File('../../contracts/srs/v1/golden.json').readAsStringSync())
          as Map<String, dynamic>;
  if (bundle['algorithm'] != SrsScheduler.version) {
    throw StateError('Version mismatch');
  }
  final outputs = <Map<String, Object?>>[];
  for (final raw in bundle['cases'] as List<dynamic>) {
    final c = raw as Map<String, dynamic>;
    final state = c['before'] as Map<String, dynamic>;
    final request = c['request'] as Map<String, dynamic>;
    final type = LearningItemType.values.singleWhere(
      (t) => t.wireName == c['item_type'],
    );
    final card = SrsCard(
      itemType: type,
      itemId: c['item_id'] as String,
      state: SrsState.values.singleWhere(
        (s) => s.wireName == state['srs_state'],
      ),
      intervalDays: (state['interval_days'] as num).toDouble(),
      difficulty: (state['difficulty'] as num).toDouble(),
      reviewCount: state['review_count'] as int,
      correctCount: state['correct_count'] as int,
      incorrectCount: state['incorrect_count'] as int,
      lastReviewAt: state['last_review_at'] == null
          ? null
          : DateTime.parse(state['last_review_at'] as String),
      nextReviewAt: state['next_review_at'] == null
          ? null
          : DateTime.parse(state['next_review_at'] as String),
    );
    final r = SrsReview(
      clientEventId: request['client_event_id'] as String,
      itemType: type,
      itemId: request['item_id'] as String,
      rating: ReviewRating.fromWire(request['rating'] as int),
      isCorrect: request['is_correct'] as bool,
      responseMs: request['response_ms'] as int,
      occurredAt: DateTime.parse(request['occurred_at'] as String),
    );
    final output = const SrsScheduler().schedule(card, r);
    verifyFields(
      output.toStateJson(),
      c['expected_state'] as Map<String, dynamic>,
    );
    verifyFields(
      output.toReviewResponseJson(),
      c['expected_response'] as Map<String, dynamic>,
    );
    outputs.add({
      'name': c['name'],
      'request': r.toJson(),
      'response': output.toReviewResponseJson(),
    });
  }
  File(arguments.single).writeAsStringSync(
    jsonEncode({'algorithm': SrsScheduler.version, 'cases': outputs}),
  );
  stdout.writeln('Verified ${outputs.length} shared SRS policy cases');
}
