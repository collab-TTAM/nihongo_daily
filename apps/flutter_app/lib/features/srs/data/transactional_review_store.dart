import 'dart:convert';

import 'durable_review_repository.dart';
import 'review_repository.dart';
import 'review_receipt_retention.dart';

/// The callback is synchronous inside one transaction. A replacement commits
/// atomically before the future resolves; a thrown callback must roll back.
/// Implementations serialize read/write transactions across all connections.
abstract interface class ReviewLedgerTransactions {
  Future<T> transact<T>(
    bool write,
    T Function(String? current, void Function(String) replace) operation,
  );
  Future<void> close();
}

/// Bounded canonical ledger, independent of browser APIs. Local owner keys are
/// isolation only; the existing captured Auth/RPC ports authorize server work.
/// No tokens/content, automatic dispatch, eviction or derived-state mutation.
final class TransactionalReviewStore implements DurableReviewStore {
  TransactionalReviewStore(this.transactions, {this.receiptRetention});
  final ReviewLedgerTransactions transactions;
  final ReviewReceiptRetention? receiptRetention;
  static const maxBytes = 1024 * 1024;
  static const maxEvents = 512;
  static const reservedOutcomeBytes = 8192;

  Future<T> _transaction<T>(
    bool write,
    T Function(List<StoredReview> records, void Function() save) operation,
  ) async {
    try {
      return await transactions.transact(write, (raw, replace) {
        final records = _decode(raw);
        void save() {
          if (!write) throw const ReviewStorageFailure();
          replace(_encode(records));
        }

        return operation(records, save);
      });
    } on ReviewTransportFailure {
      rethrow;
    } on Object {
      throw const ReviewStorageFailure();
    }
  }

  static List<StoredReview> _decode(String? encoded) {
    if (encoded == null) return [];
    if (encoded.length > maxBytes || utf8.encode(encoded).length > maxBytes) {
      throw const ReviewStorageFailure();
    }
    final raw = jsonDecode(encoded);
    if (raw is! Map<String, Object?> ||
        jsonEncode(raw) != encoded ||
        raw.length != 2 ||
        raw['version'] is! int ||
        raw['version'] != 1 ||
        raw['records'] is! List<Object?>) {
      throw const ReviewStorageFailure();
    }
    final entries = raw['records']! as List<Object?>;
    if (entries.length > maxEvents) throw const ReviewStorageFailure();
    final seen = <String>{};
    final records = <StoredReview>[];
    for (final entry in entries) {
      if (entry is! Map<String, Object?> ||
          entry.length != 4 ||
          !const {
            'user_id',
            'request',
            'receipt',
            'rejection',
          }.every(entry.containsKey) ||
          entry['user_id'] is! String) {
        throw const ReviewStorageFailure();
      }
      final owner = entry['user_id']! as String;
      if (ReviewSession(userId: owner).userId != owner) {
        throw const ReviewStorageFailure();
      }
      ReviewSuccess? receipt;
      ReviewFailure? rejection;
      if (entry['receipt'] != null) {
        final outcome = decodeReviewOutcome(entry['receipt']);
        if (outcome is! ReviewSuccess) throw const ReviewStorageFailure();
        receipt = outcome;
      }
      if (entry['rejection'] != null) {
        final outcome = decodeReviewOutcome(entry['rejection']);
        if (outcome is! ReviewFailure ||
            !isDefinitiveReviewRejection(outcome)) {
          throw const ReviewStorageFailure();
        }
        rejection = outcome;
      }
      final record = StoredReview(
        userId: owner,
        request: entry['request'],
        receipt: receipt,
        rejection: rejection,
      );
      if (!seen.add('${record.userId}/${record.eventId}')) {
        throw const ReviewStorageFailure();
      }
      records.add(record);
    }
    // Restore must honor the same reservation/bounds as newly staged data.
    _encode(records);
    return records;
  }

  static String _encode(List<StoredReview> records) {
    final result = jsonEncode({
      'version': 1,
      'records': [
        for (final record in records)
          {
            'user_id': record.userId,
            'request': record.request,
            'receipt': record.receipt?.toJson(),
            'rejection': record.rejection?.toJson(),
          },
      ],
    });
    final reserved =
        records.where((r) => r.isPending).length * reservedOutcomeBytes;
    if (records.length > maxEvents ||
        utf8.encode(result).length + reserved > maxBytes) {
      throw const ReviewStorageFailure();
    }
    return result;
  }

  @override
  Future<List<StoredReview>> list(String userId) =>
      _transaction(false, (records, _) {
        final owner = ReviewSession(userId: userId).userId;
        return List<StoredReview>.unmodifiable(
          records.where((r) => r.userId == owner),
        );
      });

  @override
  Future<StoredReview> stage(String userId, Map<String, Object> request) =>
      _transaction(true, (records, save) {
        final candidate = StoredReview(userId: userId, request: request);
        final index = records.indexWhere(
          (r) => r.userId == candidate.userId && r.eventId == candidate.eventId,
        );
        if (index >= 0) {
          final previous = records[index];
          if (!sameReviewRequest(previous.request, candidate.request)) {
            throw const ReviewTransportFailure(ReviewErrorCode.syncConflict);
          }
          return previous;
        }
        _retain(records, candidate.userId);
        records.add(candidate);
        save();
        return candidate;
      });

  int _retain(List<StoredReview> records, String userId) {
    final retained = receiptRetention?.retain(records, userId);
    if (retained == null) return 0;
    final removed = records.length - retained.length;
    records
      ..clear()
      ..addAll(retained);
    return removed;
  }

  /// Explicit maintenance, serialized with stage/settle across browser tabs.
  /// No policy means no deletion. Only local confirmed successes are eligible.
  Future<int> pruneReceipts(String userId) =>
      _transaction(true, (records, save) {
        final owner = ReviewSession(userId: userId).userId;
        final removed = _retain(records, owner);
        if (removed > 0) save();
        return removed;
      });

  Future<void> _settle(
    String userId,
    String eventId, {
    ReviewSuccess? receipt,
    ReviewFailure? rejection,
  }) => _transaction(true, (records, save) {
    final owner = ReviewSession(userId: userId).userId;
    final index = records.indexWhere(
      (r) => r.userId == owner && r.eventId == eventId,
    );
    if (index < 0) throw const ReviewStorageFailure();
    final previous = records[index];
    final next = StoredReview(
      userId: owner,
      request: previous.request,
      receipt: receipt,
      rejection: rejection,
    );
    if (!previous.isPending) {
      if (jsonEncode(previous.receipt?.toJson()) !=
              jsonEncode(next.receipt?.toJson()) ||
          jsonEncode(previous.rejection?.toJson()) !=
              jsonEncode(next.rejection?.toJson())) {
        throw const ReviewStorageFailure();
      }
      return;
    }
    records[index] = next;
    save();
  });

  @override
  Future<void> acknowledge(
    String userId,
    String eventId,
    ReviewSuccess receipt,
  ) => _settle(userId, eventId, receipt: receipt);

  @override
  Future<void> reject(String userId, String eventId, ReviewFailure rejection) {
    if (!isDefinitiveReviewRejection(rejection)) {
      return Future.error(const ReviewStorageFailure());
    }
    return _settle(userId, eventId, rejection: rejection);
  }

  Future<void> close() => transactions.close();
}
