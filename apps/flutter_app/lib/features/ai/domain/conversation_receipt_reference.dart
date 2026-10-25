// Local metadata format only. Neither a credential nor mutation/retry authority.
import 'dart:convert';
import 'conversation_requests.dart';

enum ConversationReceiptOperation {
  start('start_conversation'),
  turn('conversation_turn'),
  finish('finish_conversation');

  const ConversationReceiptOperation(this.wireName);
  final String wireName;
}

/// Identifies an existing receipt for future authenticated lookup only.
/// Contains no original mutation, text, response, token or dispatch claim.
final class ConversationReceiptReference {
  const ConversationReceiptReference._(
    this.projectOrigin,
    this.ownerId,
    this.operation,
    this.clientEventId,
  );

  factory ConversationReceiptReference.fromStart({
    required String projectUrl,
    required String ownerId,
    required StartConversationRequest request,
  }) => _create(
    projectUrl,
    ownerId,
    ConversationReceiptOperation.start,
    request.clientEventId,
  );

  factory ConversationReceiptReference.fromTurn({
    required String projectUrl,
    required String ownerId,
    required ConversationTurnRequest request,
  }) => _create(
    projectUrl,
    ownerId,
    ConversationReceiptOperation.turn,
    request.clientEventId,
  );

  factory ConversationReceiptReference.fromFinish({
    required String projectUrl,
    required String ownerId,
    required FinishConversationRequest request,
  }) => _create(
    projectUrl,
    ownerId,
    ConversationReceiptOperation.finish,
    request.clientEventId,
  );

  factory ConversationReceiptReference.fromJson(Object? value) {
    if (value is! Map<String, Object?> ||
        value.length != _keys.length ||
        !value.keys.every(_keys.contains) ||
        value['version'] is! int ||
        value['version'] != version) {
      throw _invalid;
    }
    final project = value['project_origin'];
    if (project is! String || _origin(project) != project) throw _invalid;
    final operation = ConversationReceiptOperation.values.where(
      (item) => item.wireName == value['operation'],
    );
    if (operation.length != 1) throw _invalid;
    return ConversationReceiptReference._(
      project,
      _uuid(value['owner_id']),
      operation.single,
      _uuid(value['client_event_id']),
    );
  }

  /// Only this local format's canonical encoding is accepted, including key
  /// order. Duplicate members, alternate escapes and parser aliases fail closed.
  factory ConversationReceiptReference.decode(String encoded) {
    try {
      if (encoded.length > maxEncodedBytes ||
          utf8.encode(encoded).length > maxEncodedBytes) {
        throw _invalid;
      }
      final reference = ConversationReceiptReference.fromJson(
        jsonDecode(encoded),
      );
      if (reference.encode() != encoded) throw _invalid;
      return reference;
    } on FormatException {
      throw _invalid; // Never expose raw input, parser offset or source.
    }
  }

  static const version = 1;
  static const maxEncodedBytes = 1024;
  static const _keys = {
    'version',
    'project_origin',
    'owner_id',
    'operation',
    'client_event_id',
  };
  final String projectOrigin;
  final String ownerId;
  final ConversationReceiptOperation operation;
  final String clientEventId;

  static ConversationReceiptReference _create(
    String projectUrl,
    String ownerId,
    ConversationReceiptOperation operation,
    String clientEventId,
  ) => ConversationReceiptReference._(
    _origin(projectUrl),
    _uuid(ownerId),
    operation,
    _uuid(clientEventId),
  );

  /// A local partition check, never proof of login, ownership or server receipt.
  /// The host must supply trusted configuration and freshly verified identity.
  bool matchesScope({required String projectUrl, required String ownerId}) {
    try {
      return projectOrigin == _origin(projectUrl) &&
          this.ownerId.toLowerCase() == _uuid(ownerId).toLowerCase();
    } on FormatException {
      return false;
    }
  }

  Map<String, Object> toJson() => {
    'version': version,
    'project_origin': projectOrigin,
    'owner_id': ownerId,
    'operation': operation.wireName,
    'client_event_id': clientEventId,
  };

  String encode() => jsonEncode(toJson());

  @override
  String toString() => 'ConversationReceiptReference';
}

const _invalid = FormatException('Invalid conversation receipt reference');
final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
String _uuid(Object? value) {
  if (value is! String || value.length != 36 || !_uuidPattern.hasMatch(value)) {
    throw _invalid;
  }
  return value; // Preserve caller spelling; this reference cannot replay a DTO.
}

String _origin(String value) {
  try {
    if (value.isEmpty ||
        value.length > 480 ||
        value.codeUnits.any((unit) => unit < 0x21 || unit > 0x7e)) {
      throw _invalid;
    }
    final uri = Uri.parse(value);
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !const {'', '/'}.contains(uri.path) ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.port < 1 ||
        uri.port > 65535) {
      throw _invalid;
    }
    final origin = uri.origin.toLowerCase();
    if (!RegExp(r'^https://[a-z0-9.\-:\[\]]+$').hasMatch(origin)) {
      throw _invalid;
    }
    return origin;
  } on FormatException {
    throw _invalid;
  }
}
