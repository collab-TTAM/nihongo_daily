// Frozen v0.1 text DTOs only. No provider, identity, storage or UI activation.

enum AiTextLevel {
  n5('N5'),
  n4('N4'),
  n3('N3'),
  n2('N2'),
  n1('N1');

  const AiTextLevel(this.wireName);
  final String wireName;
}

enum AiTextItemType {
  vocabulary('VOCABULARY'),
  kanji('KANJI'),
  grammar('GRAMMAR');

  const AiTextItemType(this.wireName);
  final String wireName;
}

final class TutorExplainRequest {
  TutorExplainRequest({
    required this.level,
    required String questionVi,
    List<String> recentGrammarIds = const [],
    List<String> recentVocabularyIds = const [],
  }) : questionVi = _text(questionVi, 5000),
       recentGrammarIds = _ids(recentGrammarIds),
       recentVocabularyIds = _ids(recentVocabularyIds);

  final AiTextLevel level;
  final String questionVi;
  final List<String> recentGrammarIds;
  final List<String> recentVocabularyIds;

  Map<String, Object> toJson() => {
    'jlpt_level': level.wireName,
    'question_vi': questionVi,
    'context': {
      'recent_grammar_ids': recentGrammarIds.toList(),
      'recent_vocabulary_ids': recentVocabularyIds.toList(),
    },
  };
}

final class CorrectSentenceRequest {
  CorrectSentenceRequest({required this.level, required String sentenceJa})
    : sentenceJa = _text(sentenceJa, 5000);

  final AiTextLevel level;
  final String sentenceJa;

  Map<String, Object> toJson() => {
    'jlpt_level': level.wireName,
    'sentence_ja': sentenceJa,
  };
}

final class AiTextExample {
  const AiTextExample._(this.sentenceJa, this.readingJa, this.translationVi);

  factory AiTextExample.fromJson(Object? value) {
    final json = _object(value, {
      'sentence_ja',
      'reading_ja',
      'translation_vi',
    });
    return AiTextExample._(
      _text(json['sentence_ja'], 2000),
      _text(json['reading_ja'], 2000),
      _text(json['translation_vi'], 2000),
    );
  }

  final String sentenceJa;
  final String readingJa;
  final String translationVi;

  Map<String, Object> toJson() => {
    'sentence_ja': sentenceJa,
    'reading_ja': readingJa,
    'translation_vi': translationVi,
  };
}

final class AiTextPractice {
  const AiTextPractice._(this.questionJa, this.answerJa, this.explanationVi);

  factory AiTextPractice.fromJson(Object? value) {
    final json = _object(value, {'question_ja', 'answer_ja', 'explanation_vi'});
    return AiTextPractice._(
      _text(json['question_ja'], 2000),
      _text(json['answer_ja'], 2000),
      _text(json['explanation_vi'], 2000),
    );
  }

  final String questionJa;
  final String answerJa;
  final String explanationVi;

  Map<String, Object> toJson() => {
    'question_ja': questionJa,
    'answer_ja': answerJa,
    'explanation_vi': explanationVi,
  };
}

final class TutorExplanation {
  const TutorExplanation._(this.answerVi, this.examples, this.practice);

  factory TutorExplanation.fromJson(Object? value) {
    final json = _object(value, {'answer_vi', 'examples', 'practice'});
    return TutorExplanation._(
      _text(json['answer_vi'], 10000),
      _list(json['examples'], AiTextExample.fromJson),
      _list(json['practice'], AiTextPractice.fromJson),
    );
  }

  final String answerVi;
  final List<AiTextExample> examples;
  final List<AiTextPractice> practice;

  Map<String, Object> toJson() => {
    'answer_vi': answerVi,
    'examples': examples.map((e) => e.toJson()).toList(),
    'practice': practice.map((p) => p.toJson()).toList(),
  };
}

/// A structurally valid reference, not proof of current published curriculum.
final class AiTextItemRef {
  const AiTextItemRef._(this.type, this.id);

  factory AiTextItemRef.fromJson(Object? value) {
    final json = _object(value, {'item_type', 'item_id'});
    final matches = AiTextItemType.values.where(
      (type) => type.wireName == json['item_type'],
    );
    if (matches.length != 1) throw _invalid;
    return AiTextItemRef._(matches.single, _uuid(json['item_id']));
  }

  final AiTextItemType type;
  final String id;

  Map<String, Object> toJson() => {'item_type': type.wireName, 'item_id': id};
}

final class AiTextCorrection {
  const AiTextCorrection._(
    this.originalText,
    this.correctedText,
    this.explanationVi,
    this.itemRefs,
  );

  factory AiTextCorrection.fromJson(Object? value) {
    final json = _object(value, {
      'original_text',
      'corrected_text',
      'explanation_vi',
      'item_refs',
    });
    return AiTextCorrection._(
      _text(json['original_text'], 2000),
      _text(json['corrected_text'], 2000),
      _text(json['explanation_vi'], 2000),
      _list(json['item_refs'], AiTextItemRef.fromJson),
    );
  }

  final String originalText;
  final String correctedText;
  final String explanationVi;
  final List<AiTextItemRef> itemRefs;

  Map<String, Object> toJson() => {
    'original_text': originalText,
    'corrected_text': correctedText,
    'explanation_vi': explanationVi,
    'item_refs': itemRefs.map((ref) => ref.toJson()).toList(),
  };
}

final class SentenceCorrection {
  const SentenceCorrection._(
    this.correctedSentence,
    this.naturalSentence,
    this.grammarErrors,
    this.vocabularyErrors,
  );

  factory SentenceCorrection.fromJson(Object? value) {
    final json = _object(value, {
      'corrected_sentence',
      'natural_sentence',
      'grammar_errors',
      'vocabulary_errors',
    });
    return SentenceCorrection._(
      _text(json['corrected_sentence'], 5000),
      _text(json['natural_sentence'], 5000),
      _list(json['grammar_errors'], AiTextCorrection.fromJson),
      _list(json['vocabulary_errors'], AiTextCorrection.fromJson),
    );
  }

  final String correctedSentence;
  final String naturalSentence;
  final List<AiTextCorrection> grammarErrors;
  final List<AiTextCorrection> vocabularyErrors;

  Map<String, Object> toJson() => {
    'corrected_sentence': correctedSentence,
    'natural_sentence': naturalSentence,
    'grammar_errors': grammarErrors.map((e) => e.toJson()).toList(),
    'vocabulary_errors': vocabularyErrors.map((e) => e.toJson()).toList(),
  };
}

const _invalid = FormatException('Invalid AI text payload');

Map<String, Object?> _object(Object? value, Set<String> keys) {
  if (value is! Map<String, Object?> ||
      value.length != keys.length ||
      !value.keys.every(keys.contains)) {
    throw _invalid;
  }
  return value;
}

String _text(Object? value, int max) {
  // Schema lengths count Unicode code points, not UTF-16 units. Bound the
  // scan first; preserve the original text without trimming or normalization.
  if (value is! String ||
      value.isEmpty ||
      value.length > max * 2 ||
      value.runes.length > max) {
    throw _invalid;
  }
  return value;
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

String _uuid(Object? value) {
  // Frozen UUID format permits uppercase and nil; retain exact wire spelling.
  if (value is! String || value.length != 36 || !_uuidPattern.hasMatch(value)) {
    throw _invalid;
  }
  return value;
}

List<T> _list<T>(Object? value, T Function(Object?) decode) {
  if (value is! List<Object?> || value.length > 100) throw _invalid;
  return List<T>.unmodifiable(value.map(decode));
}

List<String> _ids(List<String> value) {
  if (value.length > 100) throw _invalid;
  final copy = value.map(_uuid).toList();
  if (copy.toSet().length != copy.length) throw _invalid;
  return List.unmodifiable(copy);
}
