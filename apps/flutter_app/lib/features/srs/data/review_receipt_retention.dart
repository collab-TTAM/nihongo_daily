import 'durable_review_repository.dart';
import 'review_repository.dart';

/// Explicit opt-in for a local success-receipt cache, never server history.
/// Requires the server's immutable same-event replay contract. Pending and
/// rejected events cannot be dropped; only this owner's oldest staged successes.
final class ReviewReceiptRetention {
  ReviewReceiptRetention({this.keepCount = 128}) {
    if (keepCount < 1 || keepCount > 256) {
      throw ArgumentError('Expected a receipt-cache limit in [1, 256]');
    }
  }
  final int keepCount;

  List<StoredReview> retain(List<StoredReview> records, String userId) {
    final owner = ReviewSession(userId: userId).userId;
    var excess =
        records.where((r) => r.userId == owner && r.receipt != null).length -
        keepCount;
    final retained = <StoredReview>[];
    for (final record in records) {
      if (record.userId == owner && record.receipt != null && excess > 0) {
        excess--;
      } else {
        retained.add(record);
      }
    }
    return retained;
  }
}
