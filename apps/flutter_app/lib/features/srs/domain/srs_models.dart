/// Domain types for the versioned SRS core. No UI, storage, clock or auth access.
library;

enum ReviewRating {
  again(0),
  hard(1),
  good(2),
  easy(3);

  const ReviewRating(this.wireValue);
  final int wireValue;
  bool get isCorrect => this != again;
  static ReviewRating fromWire(int value) => values.firstWhere(
    (rating) => rating.wireValue == value,
    orElse: () => throw ArgumentError.value(value, 'rating', 'Expected 0–3'),
  );
}

enum LearningItemType {
  vocabulary('VOCABULARY'),
  kanji('KANJI'),
  grammar('GRAMMAR');

  const LearningItemType(this.wireName);
  final String wireName;
}

enum SrsState {
  newItem('NEW'),
  learning('LEARNING'),
  review('REVIEW'),
  mastered('MASTERED'),
  relearning('RELEARNING');

  const SrsState(this.wireName);
  final String wireName;
}

const maxSrsCounter = 2147483647; // PostgreSQL integer; exact on Dart web.
final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
String _uuidValue(String value, String field) {
  if (value.length != 36 || !_uuid.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'Expected a UUID');
  }
  return value.toLowerCase();
}

DateTime _instant(DateTime value, String field) {
  final utc = value.toUtc();
  if (utc.year < 1 || utc.year > 9999) {
    throw ArgumentError.value(value, field, 'Outside four-digit RFC3339 years');
  }
  return utc;
}

void _unitInterval(double value, String field) {
  if (!value.isFinite || value < 0 || value > 1) {
    throw ArgumentError.value(value, field, 'Expected a finite value in [0,1]');
  }
}

/// Immutable learning-item projection, without ownership credentials.
/// Backend #22 must obtain this state for the verified authenticated owner.
final class SrsCard {
  SrsCard({
    required this.itemType,
    required String itemId,
    this.state = SrsState.newItem,
    this.intervalDays = 0,
    this.difficulty = 0.5,
    this.reviewCount = 0,
    this.correctCount = 0,
    this.incorrectCount = 0,
    DateTime? lastReviewAt,
    DateTime? nextReviewAt,
  }) : itemId = _uuidValue(itemId, 'item_id'),
       lastReviewAt = lastReviewAt == null
           ? null
           : _instant(lastReviewAt, 'last_review_at'),
       nextReviewAt = nextReviewAt == null
           ? null
           : _instant(nextReviewAt, 'next_review_at') {
    _unitInterval(difficulty, 'difficulty');
    if (!intervalDays.isFinite || intervalDays < 0) {
      throw ArgumentError.value(intervalDays, 'interval_days');
    }
    for (final count in [reviewCount, correctCount, incorrectCount]) {
      if (count < 0 || count > maxSrsCounter) {
        throw ArgumentError.value(count, 'review counters');
      }
    }
    if (correctCount + incorrectCount != reviewCount) {
      throw ArgumentError('Correct and incorrect counts must sum to reviews');
    }
    if (state == SrsState.newItem) {
      if (reviewCount != 0 ||
          intervalDays != 0 ||
          this.lastReviewAt != null ||
          this.nextReviewAt != null) {
        throw ArgumentError('NEW state must have no review history');
      }
    } else if (reviewCount == 0 ||
        intervalDays <= 0 ||
        this.lastReviewAt == null ||
        this.nextReviewAt == null ||
        !this.nextReviewAt!.isAfter(this.lastReviewAt!)) {
      throw ArgumentError(
        'Reviewed state requires history and a later due time',
      );
    }
  }
  final LearningItemType itemType;
  final String itemId;
  final SrsState state;
  final double intervalDays;
  final double difficulty;
  final int reviewCount;
  final int correctCount;
  final int incorrectCount;
  final DateTime? lastReviewAt;
  final DateTime? nextReviewAt;

  /// Trusted persistence projection. Never send derived fields from the UI as
  /// submit_review input. V1 does not estimate stability or retrievability.
  Map<String, Object?> toStateJson() => {
    'srs_state': state.wireName,
    'interval_days': intervalDays,
    'difficulty': difficulty,
    'review_count': reviewCount,
    'correct_count': correctCount,
    'incorrect_count': incorrectCount,
    'last_review_at': lastReviewAt?.toIso8601String(),
    'next_review_at': nextReviewAt?.toIso8601String(),
  };

  /// Exact five-field frozen submit_review_response, without internal IDs/counts.
  Map<String, Object> toReviewResponseJson() {
    if (reviewCount == 0 || nextReviewAt == null) {
      throw StateError('An unreviewed item has no submit_review response');
    }
    return {
      'srs_state': state.wireName,
      'next_review_at': nextReviewAt!.toIso8601String(),
      'interval_days': intervalDays,
      'difficulty': difficulty,
      'review_count': reviewCount,
    };
  }
}

/// Typed seven-field request encoder. JSON decoding/auth/full schema validation
/// and durable retry receipts are #22 responsibilities, not a local authority.
final class SrsReview {
  SrsReview({
    required String clientEventId,
    required this.itemType,
    required String itemId,
    required this.rating,
    required bool isCorrect,
    required this.responseMs,
    required DateTime occurredAt,
  }) : clientEventId = _uuidValue(clientEventId, 'client_event_id'),
       itemId = _uuidValue(itemId, 'item_id'),
       occurredAt = _instant(occurredAt, 'occurred_at') {
    if (isCorrect != rating.isCorrect) {
      throw ArgumentError('rating and is_correct are inconsistent');
    }
    if (responseMs < 0 || responseMs > 3600000) {
      throw ArgumentError.value(responseMs, 'response_ms');
    }
  }
  final String clientEventId;
  final LearningItemType itemType;
  final String itemId;
  final ReviewRating rating;
  final int responseMs;
  final DateTime occurredAt;
  Map<String, Object> toJson() => {
    'client_event_id': clientEventId,
    'item_type': itemType.wireName,
    'item_id': itemId,
    'rating': rating.wireValue,
    'is_correct': rating.isCorrect,
    'response_ms': responseMs,
    'occurred_at': occurredAt.toIso8601String(),
  };
}

/// Receipt replay must happen before scheduling on the backend. This pure core
/// stores no receipts; it rejects stale new events without changing input state.
final class StaleSrsReview implements Exception {
  const StaleSrsReview();
  String get code => 'SYNC_CONFLICT';
  @override
  String toString() => 'The review precedes the last accepted review';
}
