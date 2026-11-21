// Frozen v0.1 conversation mutations only. No transport, retry or ownership grant.
import 'ai_text_models.dart' show AiTextLevel;

final class StartConversationRequest {
  StartConversationRequest({
    required String scenarioId,
    required this.level,
    required String clientEventId,
  }) : scenarioId = _uuid(scenarioId),
       clientEventId = _uuid(clientEventId);
  factory StartConversationRequest.fromJson(Object? value) {
    final json = _object(value, {
      'scenario_id',
      'jlpt_level',
      'client_event_id',
    });
    return StartConversationRequest(
      scenarioId: _uuid(json['scenario_id']),
      level: _level(json['jlpt_level']),
      clientEventId: _uuid(json['client_event_id']),
    );
  }
  final String scenarioId;
  final AiTextLevel level;
  final String clientEventId;
  Map<String, Object> toJson() => {
    'scenario_id': scenarioId,
    'jlpt_level': level.wireName,
    'client_event_id': clientEventId,
  };
}

final class ConversationTurnRequest {
  ConversationTurnRequest({
    required String sessionId,
    required String clientEventId,
    required String textJa,
  }) : sessionId = _uuid(sessionId),
       clientEventId = _uuid(clientEventId),
       textJa = _text(textJa);
  factory ConversationTurnRequest.fromJson(Object? value) {
    final json = _object(value, {'session_id', 'client_event_id', 'text_ja'});
    return ConversationTurnRequest(
      sessionId: _uuid(json['session_id']),
      clientEventId: _uuid(json['client_event_id']),
      textJa: _text(json['text_ja']),
    );
  }
  final String sessionId;
  final String clientEventId;
  final String textJa;
  Map<String, Object> toJson() => {
    'session_id': sessionId,
    'client_event_id': clientEventId,
    'text_ja': textJa,
  };
}

final class FinishConversationRequest {
  FinishConversationRequest({
    required String sessionId,
    required String clientEventId,
  }) : sessionId = _uuid(sessionId),
       clientEventId = _uuid(clientEventId);
  factory FinishConversationRequest.fromJson(Object? value) {
    final json = _object(value, {'session_id', 'client_event_id'});
    return FinishConversationRequest(
      sessionId: _uuid(json['session_id']),
      clientEventId: _uuid(json['client_event_id']),
    );
  }
  final String sessionId;
  final String clientEventId;
  Map<String, Object> toJson() => {
    'session_id': sessionId,
    'client_event_id': clientEventId,
  };
}

const _invalid = FormatException('Invalid conversation request');
Map<String, Object?> _object(Object? value, Set<String> keys) {
  if (value is! Map<String, Object?> ||
      value.length != keys.length ||
      !value.keys.every(keys.contains)) {
    throw _invalid;
  }
  return value;
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
String _uuid(Object? value) {
  if (value is! String || value.length != 36 || !_uuidPattern.hasMatch(value)) {
    throw _invalid;
  }
  return value; // Preserve nil/uppercase and caller event identity, never regenerate.
}

AiTextLevel _level(Object? value) {
  for (final level in AiTextLevel.values) {
    if (level.wireName == value) return level;
  }
  throw _invalid;
}

String _text(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 10000 ||
      value.runes.length > 5000) {
    throw _invalid;
  }
  return value; // Exact code points/whitespace, no transcript normalization.
}
