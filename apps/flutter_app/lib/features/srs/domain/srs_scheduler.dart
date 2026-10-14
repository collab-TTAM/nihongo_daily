import 'dart:math' as math;
import 'srs_models.dart';

/// Explicit conservative interval heuristic, not FSRS or a calibrated memory
/// model. See docs/SRS_ALGORITHM.md and versioned parity cases. Backend is #22.
final class SrsScheduler {
  const SrsScheduler();
  static const version = 'nd-srs-1';
  static const maxIntervalDays = 365.0;
  static const _microsecondsPerDay = 86400000000;

  SrsCard schedule(SrsCard card, SrsReview review) {
    if (card.itemType != review.itemType || card.itemId != review.itemId) {
      throw ArgumentError(
        'Review does not identify the supplied learning item',
      );
    }
    if (card.state == SrsState.mastered) {
      throw ArgumentError('MASTERED is reserved, not a v1 scheduling state');
    }
    if (card.reviewCount == maxSrsCounter) {
      throw RangeError('PostgreSQL review counter limit reached');
    }
    final eventTime = review.occurredAt;
    if (card.lastReviewAt != null && eventTime.isBefore(card.lastReviewAt!)) {
      throw const StaleSrsReview();
    }
    final delta = switch (review.rating) {
      ReviewRating.again => 0.15,
      ReviewRating.hard => 0.05,
      ReviewRating.good => -0.02,
      ReviewRating.easy => -0.05,
    };
    // Fixed six-place difficulty limits accumulated binary drift for backend ports.
    final difficulty =
        ((card.difficulty + delta).clamp(0.0, 1.0) * 1000000).round() / 1000000;
    final double days;
    final SrsState state;
    if (review.rating == ReviewRating.again) {
      days = 1 / 1440;
      state = card.state == SrsState.review || card.state == SrsState.relearning
          ? SrsState.relearning
          : SrsState.learning;
    } else if (card.state != SrsState.review) {
      (state, days) = switch (review.rating) {
        ReviewRating.hard => (
          card.state == SrsState.relearning
              ? SrsState.relearning
              : SrsState.learning,
          5 / 1440,
        ),
        ReviewRating.good =>
          card.state == SrsState.newItem
              ? (SrsState.learning, 10 / 1440)
              : (SrsState.review, 1.0),
        ReviewRating.easy => (SrsState.review, 4.0),
        ReviewRating.again => throw StateError('Handled above'),
      };
    } else {
      state = SrsState.review;
      final elapsed =
          eventTime.difference(card.lastReviewAt!).inMicroseconds /
          _microsecondsPerDay;
      // Early reviews receive elapsed-time credit rather than multiplying a long
      // future interval on every tap. Both early and overdue credit are bounded.
      final base = math.min(
        maxIntervalDays,
        math.min(card.intervalDays, math.max(1.0, elapsed)),
      );
      final overdue = math.max(
        0.0,
        eventTime.difference(card.nextReviewAt!).inMicroseconds /
            _microsecondsPerDay,
      );
      final raw = switch (review.rating) {
        ReviewRating.hard => math.max(1.0, base * 1.2),
        ReviewRating.good => math.max(
          1.0,
          (base + math.min(overdue / 2, base)) * (2.5 - difficulty),
        ),
        ReviewRating.easy => math.max(
          4.0,
          (base + math.min(overdue, base)) * (3.0 - difficulty),
        ),
        ReviewRating.again => throw StateError('Handled above'),
      };
      days = raw.clamp(1.0, maxIntervalDays).toDouble();
    }
    // Round once to integer microseconds. Reconstruct days from that exact
    // duration so the persisted interval and UTC due timestamp stay consistent.
    final interval = Duration(
      microseconds: (days * _microsecondsPerDay).round(),
    );
    return SrsCard(
      itemType: card.itemType,
      itemId: card.itemId,
      state: state,
      intervalDays: interval.inMicroseconds / _microsecondsPerDay,
      difficulty: difficulty,
      reviewCount: card.reviewCount + 1,
      correctCount: card.correctCount + (review.rating.isCorrect ? 1 : 0),
      incorrectCount: card.incorrectCount + (review.rating.isCorrect ? 0 : 1),
      lastReviewAt: eventTime,
      nextReviewAt: eventTime.add(interval),
    );
  }
}
