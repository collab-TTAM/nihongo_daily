// Frozen v0.1 responses only. Model recommendations never authorize a write.
import 'ai_text_models.dart' show AiTextCorrection, AiTextItemRef;

final class ConversationAssistantMessage {
  const ConversationAssistantMessage._(
    this.id,
    this.textJa,
    this.textVi,
    this.audioRef,
    this.sequenceNo,
  );
  factory ConversationAssistantMessage.fromJson(Object? value) {
    final j = _object(value, {
      'id',
      'role',
      'text_ja',
      'text_vi',
      'audio_ref',
      'sequence_no',
    });
    if (j['role'] != 'assistant') {
      throw _invalid;
    }
    final sequence = j['sequence_no'];
    if (sequence is! int || sequence < 0) {
      throw _invalid;
    }
    return ConversationAssistantMessage._(
      _uuid(j['id']),
      _text(j['text_ja'], 5000),
      j['text_vi'] == null ? null : _text(j['text_vi'], 5000),
      j['audio_ref'] == null ? null : _text(j['audio_ref'], 1000),
      sequence,
    );
  }
  final String id;
  final String textJa;
  final String? textVi;
  final String? audioRef;
  final int sequenceNo;
  Map<String, Object?> toJson() => {
    'id': id,
    'role': 'assistant',
    'text_ja': textJa,
    'text_vi': textVi,
    'audio_ref': audioRef,
    'sequence_no': sequenceNo,
  };
}

final class StartConversationResponse {
  const StartConversationResponse._(this.sessionId, this.assistantMessage);
  factory StartConversationResponse.fromJson(Object? value) {
    final j = _object(value, {'session_id', 'assistant_message'});
    return StartConversationResponse._(
      _uuid(j['session_id']),
      ConversationAssistantMessage.fromJson(j['assistant_message']),
    );
  }
  final String sessionId;
  final ConversationAssistantMessage assistantMessage;
  Map<String, Object?> toJson() => {
    'session_id': sessionId,
    'assistant_message': assistantMessage.toJson(),
  };
}

final class ConversationTurnResponse {
  const ConversationTurnResponse._(this.assistantMessage, this.liveFeedback);
  factory ConversationTurnResponse.fromJson(Object? value) {
    final j = _object(
      value,
      {'assistant_message'},
      optional: {'live_feedback'},
    );
    return ConversationTurnResponse._(
      ConversationAssistantMessage.fromJson(j['assistant_message']),
      j.containsKey('live_feedback')
          ? _list(j['live_feedback'], _correction)
          : null,
    );
  }
  final ConversationAssistantMessage assistantMessage;
  // Null means omitted on the wire, distinct from an explicitly empty list.
  final List<AiTextCorrection>? liveFeedback;
  Map<String, Object?> toJson() => {
    'assistant_message': assistantMessage.toJson(),
    if (liveFeedback != null)
      'live_feedback': liveFeedback!.map((e) => e.toJson()).toList(),
  };
}

final class ConversationScores {
  const ConversationScores._(this.grammar, this.vocabulary, this.fluency);
  factory ConversationScores.fromJson(Object? value) {
    final j = _object(value, {'grammar', 'vocabulary', 'fluency'});
    return ConversationScores._(
      _score(j['grammar']),
      _score(j['vocabulary']),
      _score(j['fluency']),
    );
  }
  final num grammar;
  final num vocabulary;
  final num fluency;
  Map<String, Object> toJson() => {
    'grammar': grammar,
    'vocabulary': vocabulary,
    'fluency': fluency,
  };
}

final class FinishConversationResponse {
  const FinishConversationResponse._(
    this.scores,
    this.errors,
    this.strengthsVi,
    this.focusNextVi,
    this.srsRecommendations,
  );
  factory FinishConversationResponse.fromJson(Object? value) {
    final j = _object(value, {
      'scores',
      'errors',
      'strengths_vi',
      'focus_next_vi',
      'srs_recommendations',
    });
    return FinishConversationResponse._(
      ConversationScores.fromJson(j['scores']),
      _list(j['errors'], _correction),
      _list(j['strengths_vi'], (v) => _text(v, 2000)),
      _list(j['focus_next_vi'], (v) => _text(v, 2000)),
      _list(j['srs_recommendations'], _itemRef),
    );
  }
  final ConversationScores scores;
  final List<AiTextCorrection> errors;
  final List<String> strengthsVi;
  final List<String> focusNextVi;
  final List<AiTextItemRef> srsRecommendations;
  Map<String, Object?> toJson() => {
    'scores': scores.toJson(),
    'errors': errors.map((e) => e.toJson()).toList(),
    'strengths_vi': strengthsVi.toList(),
    'focus_next_vi': focusNextVi.toList(),
    'srs_recommendations': srsRecommendations.map((e) => e.toJson()).toList(),
  };
}

const _invalid = FormatException('Invalid conversation response');
Map<String, Object?> _object(
  Object? value,
  Set<String> required, {
  Set<String> optional = const {},
}) {
  if (value is! Map<String, Object?> ||
      !required.every(value.containsKey) ||
      !value.keys.every((k) => required.contains(k) || optional.contains(k))) {
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
  return value;
}

String _text(Object? value, int max) {
  if (value is! String ||
      value.isEmpty ||
      value.length > max * 2 ||
      value.runes.length > max) {
    throw _invalid;
  }
  return value;
}

num _score(Object? value) {
  if (value is! num || !value.isFinite || value < 0 || value > 100) {
    throw _invalid;
  }
  return value;
}

List<T> _list<T>(Object? value, T Function(Object?) decode) {
  if (value is! List<Object?> || value.length > 100) {
    throw _invalid;
  }
  return List<T>.unmodifiable(value.map(decode));
}

AiTextCorrection _correction(Object? value) {
  try {
    return AiTextCorrection.fromJson(value);
  } on FormatException {
    throw _invalid;
  }
}

AiTextItemRef _itemRef(Object? value) {
  try {
    return AiTextItemRef.fromJson(value);
  } on FormatException {
    throw _invalid;
  }
}
