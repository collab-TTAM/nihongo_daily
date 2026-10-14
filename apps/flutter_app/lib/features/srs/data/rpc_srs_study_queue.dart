import 'dart:async';

import '../../../shared/models/preview_level.dart';
import '../application/srs_study_controller.dart';
import '../domain/srs_models.dart';
import 'review_repository.dart';

/// Additive nd-review-queue-1 read model, not derived scheduling authority.
final class ReviewQueueEntry {
  const ReviewQueueEntry._(this.item, this.dueAt, this.dueAtWire);
  final SrsStudyItem item;
  final DateTime dueAt;
  final String dueAtWire;
  Map<String, Object> toJson() => {
    'item_type': item.type.wireName,
    'item_id': item.itemId,
    'prompt_ja': item.prompt,
    'reading_ja': item.reading,
    'answer_vi': item.answerVi,
    'next_review_at': dueAtWire,
  };
}

final class ReviewQueueSnapshot {
  ReviewQueueSnapshot._(
    this.level,
    this.serverTime,
    this.serverTimeWire,
    List<ReviewQueueEntry> items,
  ) : items = List.unmodifiable(items);
  final PreviewLevel level;
  final DateTime serverTime;
  final String serverTimeWire;
  final List<ReviewQueueEntry> items;

  factory ReviewQueueSnapshot.decode(
    Object? raw, {
    required PreviewLevel level,
    required int limit,
  }) {
    try {
      if (limit < 1 || limit > 100 || raw is! Map<String, Object?>) {
        throw const FormatException();
      }
      if (raw.containsKey('code')) {
        final error = decodeReviewOutcome(raw) as ReviewFailure;
        throw ReviewTransportFailure(error.code, retryable: error.retryable);
      }
      _keys(raw, const {'jlpt_level', 'server_time', 'items'});
      if (raw['jlpt_level'] != level.label) throw const FormatException();
      final serverWire = _text(raw['server_time']);
      final server = _queueInstant(serverWire);
      final rows = raw['items'];
      if (rows is! List<Object?> || rows.length > limit)
        throw const FormatException();
      final items = <ReviewQueueEntry>[];
      final keys = <String>{};
      DateTime? previousDue;
      String? previousKey;
      for (final row in rows) {
        if (row is! Map<String, Object?>) throw const FormatException();
        _keys(row, const {
          'item_type',
          'item_id',
          'prompt_ja',
          'reading_ja',
          'answer_vi',
          'next_review_at',
        });
        final type = LearningItemType.values.singleWhere(
          (type) => type.wireName == row['item_type'],
        );
        final item = SrsStudyItem(
          type: type,
          itemId: _text(row['item_id']),
          level: level,
          prompt: _text(row['prompt_ja']),
          reading: _text(row['reading_ja']),
          answerVi: _text(row['answer_vi']),
        );
        final dueWire = _text(row['next_review_at']);
        final due = _queueInstant(dueWire);
        final key = '${type.wireName}/${item.itemId}';
        if (!keys.add(key) ||
            due.isAfter(server) ||
            (previousDue != null &&
                (due.isBefore(previousDue) ||
                    (due == previousDue && key.compareTo(previousKey!) < 0)))) {
          throw const FormatException();
        }
        previousDue = due;
        previousKey = key;
        items.add(ReviewQueueEntry._(item, due, dueWire));
      }
      return ReviewQueueSnapshot._(level, server, serverWire, items);
    } on ReviewTransportFailure {
      rethrow;
    } on Object {
      throw const ReviewTransportFailure(ReviewErrorCode.internalError);
    }
  }

  Map<String, Object> toJson() => {
    'jlpt_level': level.label,
    'server_time': serverTimeWire,
    'items': items.map((entry) => entry.toJson()).toList(),
  };
}

void _keys(Map<String, Object?> value, Set<String> expected) {
  if (value.length != expected.length || !expected.every(value.containsKey)) {
    throw const FormatException();
  }
}

String _text(Object? value) {
  if (value is! String) throw const FormatException();
  return value;
}

DateTime _queueInstant(String value) {
  if (value.length > 27 ||
      !RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$',
      ).hasMatch(value)) {
    throw const FormatException();
  }
  return parseSrsWireInstant(value);
}

/// Concrete RPC projection/decoder over the existing injected transport. A real
/// SDK/Auth transport is still missing; this class alone does not enable runtime.
final class RpcSrsStudyQueue implements SrsStudyQueue {
  RpcSrsStudyQueue({
    required this.auth,
    required this.transport,
    this.limit = 100,
    this.timeout = const Duration(seconds: 15),
  }) {
    if (limit < 1 ||
        limit > 100 ||
        timeout <= Duration.zero ||
        timeout > const Duration(minutes: 2)) {
      throw ArgumentError('Invalid queue limit/deadline');
    }
  }
  final ReviewAuth auth;
  final ReviewRpcTransport transport;
  final int limit;
  final Duration timeout;

  @override
  Future<List<SrsStudyItem>> load(
    ReviewSession session,
    PreviewLevel level,
  ) async {
    if (!identical(auth.currentSession, session)) {
      throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
    }
    try {
      final raw = await transport
          .invoke(
            capturedSession: session,
            function: 'get_review_queue',
            params: Map<String, Object>.unmodifiable({
              'p_request': Map<String, Object>.unmodifiable({
                'jlpt_level': level.label,
                'limit': limit,
              }),
            }),
          )
          .timeout(timeout);
      if (!identical(auth.currentSession, session)) {
        throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
      }
      final snapshot = ReviewQueueSnapshot.decode(
        raw,
        level: level,
        limit: limit,
      );
      return List.unmodifiable(snapshot.items.map((entry) => entry.item));
    } on Object catch (error) {
      if (!identical(auth.currentSession, session)) {
        throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
      }
      if (error is ReviewTransportFailure) rethrow;
      if (error is TimeoutException) {
        throw const ReviewTransportFailure(
          ReviewErrorCode.networkUnavailable,
          retryable: true,
        );
      }
      throw const ReviewTransportFailure(ReviewErrorCode.internalError);
    }
  }
}
