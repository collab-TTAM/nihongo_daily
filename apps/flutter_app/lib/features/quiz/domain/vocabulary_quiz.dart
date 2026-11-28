/// Deterministic, local-only vocabulary reading quiz rules.
///
/// This domain never persists attempts, updates SRS/mastery, or grants study
/// minutes. A caller must supply one already selected JLPT level and its
/// original vocabulary rows.
enum VocabularyQuizBuildStatus { ready, empty, insufficientContent }

final class VocabularyQuizEntry {
  const VocabularyQuizEntry({
    required this.id,
    required this.jlptLevel,
    required this.contentVersion,
    required this.expression,
    required this.reading,
    required this.meaningVi,
    required this.isActive,
  });

  final String id;
  final String jlptLevel;
  final int contentVersion;
  final String expression;
  final String reading;
  final String meaningVi;
  final bool isActive;
}

final class VocabularyQuizOption {
  const VocabularyQuizOption({required this.id, required this.label});

  /// The canonical trimmed reading from an original row.
  final String id;
  final String label;
}

final class VocabularyQuizQuestion {
  VocabularyQuizQuestion({
    required this.questionId,
    required this.sourceId,
    required this.contentVersion,
    required this.expression,
    required this.reading,
    required this.meaningVi,
    required this.options,
    required this.correctOptionId,
    required this.correctOptionIndex,
  }) : options = List.unmodifiable(options);

  /// Stable identity includes the level, original row ID and content version.
  final String questionId;
  final String sourceId;
  final int contentVersion;
  final String expression;
  final String reading;
  final String meaningVi;
  final List<VocabularyQuizOption> options;
  final String correctOptionId;
  final int correctOptionIndex;
}

final class VocabularyQuizRound {
  VocabularyQuizRound({
    required this.level,
    required this.batchIndex,
    required this.status,
    required this.eligibleCount,
    required this.questions,
  }) : questions = List.unmodifiable(questions);

  final String level;
  final int batchIndex;
  final VocabularyQuizBuildStatus status;
  final int eligibleCount;
  final List<VocabularyQuizQuestion> questions;

  bool get hasNextBatch =>
      status == VocabularyQuizBuildStatus.ready &&
      (batchIndex + 1) * VocabularyQuizBuilder.maxQuestionsPerRound <
          eligibleCount;
}

final class VocabularyQuizBuilder {
  const VocabularyQuizBuilder();

  static const maxSourceEntries = 5000;
  static const maxQuestionsPerRound = 10;
  static const optionCount = 4;

  static final RegExp _kanjiExpression = RegExp(r'[\u4E00-\u9FFF々]');

  VocabularyQuizRound build({
    required String level,
    required List<VocabularyQuizEntry> entries,
    int batchIndex = 0,
  }) {
    if (level != 'N5' && level != 'N4') {
      throw const FormatException('Unsupported JLPT level');
    }
    if (entries.length > maxSourceEntries) {
      throw const FormatException('Vocabulary source is too large');
    }
    if (batchIndex < 0 ||
        batchIndex > maxSourceEntries ~/ maxQuestionsPerRound) {
      throw const FormatException('Invalid quiz batch');
    }

    final seenIds = <String>{};
    final seenExpressions = <String>{};
    final eligible = <_EligibleVocabulary>[];

    for (final entry in entries) {
      final id = entry.id.trim();
      final expression = entry.expression.trim();
      final reading = entry.reading.trim();

      if (entry.jlptLevel != level) {
        throw const FormatException('Vocabulary level does not match');
      }
      if (id.isEmpty ||
          expression.isEmpty ||
          reading.isEmpty ||
          entry.contentVersion < 1) {
        throw const FormatException('Invalid vocabulary identity');
      }
      if (!seenIds.add(id)) {
        throw const FormatException('Duplicate vocabulary identity');
      }
      if (!entry.isActive || !_kanjiExpression.hasMatch(expression)) {
        continue;
      }
      // Keep the first original heading; later duplicates are not prompts or
      // distractor sources, even if their alternate reading differs.
      if (!seenExpressions.add(expression)) continue;

      eligible.add(
        _EligibleVocabulary(
          id: id,
          contentVersion: entry.contentVersion,
          expression: expression,
          reading: reading,
          meaningVi: entry.meaningVi.trim(),
        ),
      );
    }

    if (eligible.isEmpty) {
      return VocabularyQuizRound(
        level: level,
        batchIndex: batchIndex,
        status: VocabularyQuizBuildStatus.empty,
        eligibleCount: 0,
        questions: const [],
      );
    }

    final readings = <String>[];
    final seenReadings = <String>{};
    for (final entry in eligible) {
      if (seenReadings.add(entry.reading)) readings.add(entry.reading);
    }
    if (readings.length < optionCount) {
      return VocabularyQuizRound(
        level: level,
        batchIndex: batchIndex,
        status: VocabularyQuizBuildStatus.insufficientContent,
        eligibleCount: eligible.length,
        questions: const [],
      );
    }

    final start = batchIndex * maxQuestionsPerRound;
    if (start >= eligible.length) {
      return VocabularyQuizRound(
        level: level,
        batchIndex: batchIndex,
        status: VocabularyQuizBuildStatus.empty,
        eligibleCount: eligible.length,
        questions: const [],
      );
    }
    final end = start + maxQuestionsPerRound < eligible.length
        ? start + maxQuestionsPerRound
        : eligible.length;
    final questions = <VocabularyQuizQuestion>[];

    for (var absoluteIndex = start; absoluteIndex < end; absoluteIndex++) {
      final entry = eligible[absoluteIndex];
      final distractors = <String>[];
      for (var offset = 1;
          offset < readings.length + 1 && distractors.length < optionCount - 1;
          offset++) {
        final candidate =
            readings[(absoluteIndex + offset) % readings.length];
        if (candidate != entry.reading && !distractors.contains(candidate)) {
          distractors.add(candidate);
        }
      }

      // At least four distinct readings were checked above, so three
      // distractors must be available without fabricating any option.
      if (distractors.length != optionCount - 1) {
        throw StateError('Validated reading pool became inconsistent');
      }

      final correctIndex = absoluteIndex % optionCount;
      var distractorIndex = 0;
      final options = <VocabularyQuizOption>[];
      for (var slot = 0; slot < optionCount; slot++) {
        final reading = slot == correctIndex
            ? entry.reading
            : distractors[distractorIndex++];
        options.add(VocabularyQuizOption(id: reading, label: reading));
      }

      final questionId = [
        level,
        entry.id,
        'v' + entry.contentVersion.toString(),
      ].join(':');
      questions.add(
        VocabularyQuizQuestion(
          questionId: questionId,
          sourceId: entry.id,
          contentVersion: entry.contentVersion,
          expression: entry.expression,
          reading: entry.reading,
          meaningVi: entry.meaningVi,
          options: options,
          correctOptionId: entry.reading,
          correctOptionIndex: correctIndex,
        ),
      );
    }

    return VocabularyQuizRound(
      level: level,
      batchIndex: batchIndex,
      status: VocabularyQuizBuildStatus.ready,
      eligibleCount: eligible.length,
      questions: questions,
    );
  }
}

final class _EligibleVocabulary {
  const _EligibleVocabulary({
    required this.id,
    required this.contentVersion,
    required this.expression,
    required this.reading,
    required this.meaningVi,
  });

  final String id;
  final int contentVersion;
  final String expression;
  final String reading;
  final String meaningVi;
}

final class VocabularyQuizAnswer {
  const VocabularyQuizAnswer({
    required this.questionId,
    required this.optionId,
    required this.isCorrect,
  });

  final String questionId;
  final String optionId;
  final bool isCorrect;
}

/// Immutable in-memory round state. It deliberately has no storage or service
/// dependency; leaving/reloading the route discards this local result.
final class VocabularyQuizSession {
  VocabularyQuizSession(VocabularyQuizRound round)
    : this._(round, 0, const {});

  VocabularyQuizSession._(
    this.round,
    this.currentIndex,
    Map<String, VocabularyQuizAnswer> answers,
  ) : answers = Map.unmodifiable(answers);

  final VocabularyQuizRound round;
  final int currentIndex;
  final Map<String, VocabularyQuizAnswer> answers;

  VocabularyQuizQuestion? get currentQuestion =>
      currentIndex >= 0 && currentIndex < round.questions.length
      ? round.questions[currentIndex]
      : null;

  bool get isComplete =>
      round.questions.isNotEmpty && currentIndex >= round.questions.length;

  int get correctCount =>
      answers.values.where((answer) => answer.isCorrect).length;

  /// An integer-only local result. Empty rounds remain 0/0, never a percentage.
  String get scoreLabel =>
      correctCount.toString() + '/' + round.questions.length.toString();

  List<VocabularyQuizQuestion> get incorrectQuestions => List.unmodifiable(
    round.questions.where(
      (question) => answers[question.questionId]?.isCorrect == false,
    ),
  );

  /// Accepts only a valid option for the current unanswered question.
  /// Stale question IDs, unknown options and repeated taps are no-ops.
  VocabularyQuizSession answer({
    required String questionId,
    required String optionId,
  }) {
    final question = currentQuestion;
    if (question == null ||
        question.questionId != questionId ||
        answers.containsKey(questionId) ||
        !question.options.any((option) => option.id == optionId)) {
      return this;
    }

    final nextAnswers = Map<String, VocabularyQuizAnswer>.of(answers)
      ..[questionId] = VocabularyQuizAnswer(
        questionId: questionId,
        optionId: optionId,
        isCorrect: optionId == question.correctOptionId,
      );
    return VocabularyQuizSession._(round, currentIndex, nextAnswers);
  }

  /// Advances only the currently displayed question after it was answered.
  /// A queued next action from an older question cannot skip a new one.
  VocabularyQuizSession next(String questionId) {
    final question = currentQuestion;
    if (question == null ||
        question.questionId != questionId ||
        !answers.containsKey(questionId)) {
      return this;
    }
    return VocabularyQuizSession._(round, currentIndex + 1, answers);
  }

  /// Restarts this local round only; it does not touch SRS or saved progress.
  VocabularyQuizSession restart() => VocabularyQuizSession(round);
}
