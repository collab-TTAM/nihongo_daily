import 'durable_review_repository.dart';
import 'transactional_review_store.dart';
import 'review_receipt_retention.dart';

/// Native callers use NativeReviewJournal. No in-memory persistence fallback.
Future<TransactionalReviewStore> openBrowserReviewStore({
  String databaseName = 'nihongo-daily-review-v1',
  ReviewReceiptRetention? receiptRetention,
}) => Future.error(const ReviewStorageFailure());
