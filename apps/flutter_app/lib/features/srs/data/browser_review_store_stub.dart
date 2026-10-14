import 'durable_review_repository.dart';
import 'transactional_review_store.dart';

/// Native callers use NativeReviewJournal. No in-memory persistence fallback.
Future<TransactionalReviewStore> openBrowserReviewStore({
  String databaseName = 'nihongo-daily-review-v1',
}) => Future.error(const ReviewStorageFailure());
