import 'dart:convert';
import 'conversation_receipt_reference.dart';
import 'conversation_responses.dart';

enum ConversationReceiptStatus { unknown, pending, completed }

/// A read-only server projection, never permission to clear, retry or dispatch.
/// Unknown includes an absent/invisible row; it does not prove non-dispatch.
final class ConversationReceiptSnapshot {
  const ConversationReceiptSnapshot._(
    this._reference,
    this.status, {
    this.start,
    this.turn,
    this.finish,
  });
  final ConversationReceiptReference _reference;
  final ConversationReceiptStatus status;

  /// Local result association only, never authentication or release authority.
  bool matchesReference(ConversationReceiptReference reference) =>
      _reference.projectOrigin == reference.projectOrigin &&
      _reference.ownerId.toLowerCase() == reference.ownerId.toLowerCase() &&
      _reference.operation == reference.operation &&
      _reference.clientEventId.toLowerCase() ==
          reference.clientEventId.toLowerCase();

  final StartConversationResponse? start;
  final ConversationTurnResponse? turn;
  final FinishConversationResponse? finish;

  factory ConversationReceiptSnapshot.fromRows(
    ConversationReceiptReference reference,
    Object? value,
  ) {
    try {
      if (value is! List<Object?> ||
          value.length > 1 ||
          utf8.encode(jsonEncode(value)).length > 1024 * 1024) {
        throw const FormatException();
      }
      if (value.isEmpty) {
        return ConversationReceiptSnapshot._(
          reference,
          ConversationReceiptStatus.unknown,
        );
      }
      final row = value.single;
      const keys = {
        'user_id',
        'operation',
        'client_event_id',
        'status',
        'response_json',
      };
      if (row is! Map<String, Object?> ||
          row.length != keys.length ||
          !row.keys.every(keys.contains) ||
          row['user_id'] is! String ||
          (row['user_id']! as String).toLowerCase() !=
              reference.ownerId.toLowerCase() ||
          row['operation'] != reference.operation.wireName ||
          row['client_event_id'] is! String ||
          (row['client_event_id']! as String).toLowerCase() !=
              reference.clientEventId.toLowerCase()) {
        throw const FormatException();
      }
      if (row['status'] == 'PENDING' && row['response_json'] == null) {
        return ConversationReceiptSnapshot._(
          reference,
          ConversationReceiptStatus.pending,
        );
      }
      if (row['status'] != 'COMPLETED' || row['response_json'] == null) {
        throw const FormatException();
      }
      final result = row['response_json'];
      return switch (reference.operation) {
        ConversationReceiptOperation.start => ConversationReceiptSnapshot._(
          reference,
          ConversationReceiptStatus.completed,
          start: StartConversationResponse.fromJson(result),
        ),
        ConversationReceiptOperation.turn => ConversationReceiptSnapshot._(
          reference,
          ConversationReceiptStatus.completed,
          turn: ConversationTurnResponse.fromJson(result),
        ),
        ConversationReceiptOperation.finish => ConversationReceiptSnapshot._(
          reference,
          ConversationReceiptStatus.completed,
          finish: FinishConversationResponse.fromJson(result),
        ),
      };
    } on Object {
      throw const FormatException('Invalid receipt projection');
    }
  }
  @override
  String toString() => 'ConversationReceiptSnapshot(${status.name})';
}
