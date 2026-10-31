import 'dart:convert';
import 'conversation_receipt_reference.dart';
import 'conversation_requests.dart';

/// Proposed payload format BEFORE a future reviewed secure-storage boundary.
/// Encoding is sensitive plaintext, NOT encryption, persistence or authority.
/// No existing retained-command getter, store, runtime or default uses this type.
final class PendingConversationCommandEnvelope {
  const PendingConversationCommandEnvelope._(
    this.reference, {
    this.start,
    this.turn,
    this.finish,
  });

  factory PendingConversationCommandEnvelope.fromStart({
    required String projectUrl,
    required String ownerId,
    required StartConversationRequest request,
  }) => _parse(
    ConversationReceiptReference.fromStart(
      projectUrl: projectUrl,
      ownerId: ownerId,
      request: request,
    ),
    request.toJson(),
  );

  factory PendingConversationCommandEnvelope.fromTurn({
    required String projectUrl,
    required String ownerId,
    required ConversationTurnRequest request,
  }) => _parse(
    ConversationReceiptReference.fromTurn(
      projectUrl: projectUrl,
      ownerId: ownerId,
      request: request,
    ),
    request.toJson(),
  );

  factory PendingConversationCommandEnvelope.fromFinish({
    required String projectUrl,
    required String ownerId,
    required FinishConversationRequest request,
  }) => _parse(
    ConversationReceiptReference.fromFinish(
      projectUrl: projectUrl,
      ownerId: ownerId,
      request: request,
    ),
    request.toJson(),
  );

  /// Caller supplies the trusted local partition. This is NOT Auth verification.
  /// Only canonical bytes from this format are accepted, including member order.
  factory PendingConversationCommandEnvelope.decode(
    String encoded, {
    required ConversationReceiptScope expectedScope,
  }) {
    try {
      if (encoded.length > maxEncodedBytes ||
          utf8.encode(encoded).length > maxEncodedBytes) {
        throw _invalid;
      }
      final value = jsonDecode(encoded);
      const keys = {'version', 'reference', 'request'};
      if (value is! Map<String, Object?> ||
          value.length != keys.length ||
          !value.keys.every(keys.contains) ||
          value['version'] is! int ||
          value['version'] != version) {
        throw _invalid;
      }
      final reference = ConversationReceiptReference.fromJson(
        value['reference'],
      );
      if (!expectedScope.contains(reference)) throw _invalid;
      final result = _parse(reference, value['request']);
      // Reject duplicate JSON members, whitespace/escape aliases and reordering.
      if (result.encode() != encoded) throw _invalid;
      return result;
    } on Object {
      throw _invalid; // No parser source, payload, credentials or offset.
    }
  }

  static const version = 1;
  static const maxEncodedBytes = 32768;
  final ConversationReceiptReference reference;
  final StartConversationRequest? start;
  final ConversationTurnRequest? turn;
  final FinishConversationRequest? finish;

  Map<String, Object> get _request => switch (reference.operation) {
    ConversationReceiptOperation.start => start!.toJson(),
    ConversationReceiptOperation.turn => turn!.toJson(),
    ConversationReceiptOperation.finish => finish!.toJson(),
  };

  static PendingConversationCommandEnvelope _parse(
    ConversationReceiptReference reference,
    Object? value,
  ) {
    try {
      final result = switch (reference.operation) {
        ConversationReceiptOperation.start =>
          PendingConversationCommandEnvelope._(
            reference,
            start: StartConversationRequest.fromJson(value),
          ),
        ConversationReceiptOperation.turn =>
          PendingConversationCommandEnvelope._(
            reference,
            turn: ConversationTurnRequest.fromJson(value),
          ),
        ConversationReceiptOperation.finish =>
          PendingConversationCommandEnvelope._(
            reference,
            finish: FinishConversationRequest.fromJson(value),
          ),
      };
      // Exact original event spelling is part of immutable request identity.
      if (result._request['client_event_id'] != reference.clientEventId) {
        throw _invalid;
      }
      result
          .encode(); // Validate the full UTF-8 envelope bound before returning.
      return result;
    } on Object {
      throw _invalid;
    }
  }

  /// Sensitive bytes for a future secure port only; never logs or a file fallback.
  String encode() {
    final encoded = jsonEncode({
      'version': version,
      'reference': reference.toJson(),
      'request': _request,
    });
    if (utf8.encode(encoded).length > maxEncodedBytes) throw _invalid;
    return encoded;
  }

  @override
  String toString() => 'PendingConversationCommandEnvelope';
}

const _invalid = FormatException('Invalid pending command envelope');
