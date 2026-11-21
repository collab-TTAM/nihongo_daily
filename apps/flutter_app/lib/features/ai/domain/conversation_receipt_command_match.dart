import 'dart:convert';
import 'conversation_receipt_reference.dart';
import 'conversation_receipt_snapshot.dart';
import 'conversation_requests.dart';

/// Pure stored-command association, never authenticated lookup or release.
/// The host must retain the FULL original DTO; metadata cannot reconstruct it.
/// No request, raw row, retry closure or storage capability is retained here.
abstract final class ConversationReceiptCommandMatch {
  static ConversationReceiptSnapshot forStart(
    ConversationReceiptReference reference,
    StartConversationRequest original,
    Object? rows,
  ) => _decode(
    reference,
    ConversationReceiptOperation.start,
    original.toJson(),
    rows,
  );

  static ConversationReceiptSnapshot forTurn(
    ConversationReceiptReference reference,
    ConversationTurnRequest original,
    Object? rows,
  ) => _decode(
    reference,
    ConversationReceiptOperation.turn,
    original.toJson(),
    rows,
  );

  static ConversationReceiptSnapshot forFinish(
    ConversationReceiptReference reference,
    FinishConversationRequest original,
    Object? rows,
  ) => _decode(
    reference,
    ConversationReceiptOperation.finish,
    original.toJson(),
    rows,
  );

  static ConversationReceiptSnapshot _decode(
    ConversationReceiptReference reference,
    ConversationReceiptOperation operation,
    Map<String, Object> original,
    Object? rows,
  ) {
    try {
      if (reference.operation != operation ||
          reference.clientEventId.toLowerCase() !=
              (original['client_event_id']! as String).toLowerCase() ||
          rows is! List<Object?> ||
          rows.length > 1 ||
          utf8.encode(jsonEncode(rows)).length > 1024 * 1024) {
        throw const FormatException();
      }
      // Absent/invisible is still unknown, NOT a successful command match.
      if (rows.isEmpty) {
        return ConversationReceiptSnapshot.fromRows(reference, rows);
      }
      final row = rows.single;
      const keys = {
        'user_id',
        'operation',
        'client_event_id',
        'request_json',
        'status',
        'response_json',
      };
      if (row is! Map<String, Object?> ||
          row.length != keys.length ||
          !row.keys.every(keys.contains)) {
        throw const FormatException();
      }
      final saved = row['request_json'];
      // Original DTO values are bounded scalars. Ignore JSON member order only;
      // preserve every code point, whitespace and original UUID spelling.
      if (saved is! Map<String, Object?> ||
          saved.length != original.length ||
          !original.entries.every((entry) => saved[entry.key] == entry.value)) {
        throw const FormatException();
      }
      // Reuse all existing owner/operation/event/status/strict response checks.
      return ConversationReceiptSnapshot.fromRows(reference, [
        Map<String, Object?>.from(row)..remove('request_json'),
      ]);
    } on Object {
      throw const FormatException('Invalid receipt command projection');
    }
  }
}
