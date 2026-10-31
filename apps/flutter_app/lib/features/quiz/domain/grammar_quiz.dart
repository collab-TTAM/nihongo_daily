import '../../curriculum/domain/curriculum.dart';
import '../../../shared/models/preview_level.dart';

/// Meaning according to the original source, not a semantic equivalence claim.
/// Separate from vocabulary questions so grammar cannot enter their save path.
final class GrammarQuizQuestion {
  GrammarQuizQuestion._(this.target, List<CurriculumEntry> choices)
    : choices = List.unmodifiable(choices);

  final CurriculumEntry target;
  final List<CurriculumEntry> choices;
  String get id =>
      'grammar/${target.level.name}/${target.id}/${target.contentVersion}';
}

List<GrammarQuizQuestion> buildGrammarQuiz(
  List<CurriculumEntry> source,
  PreviewLevel level,
) {
  if (source.length > 5000) {
    throw const FormatException('Grammar quiz source too large');
  }
  final ids = <String>{};
  final headings = <String, int>{};
  for (final entry in source) {
    if (entry.kind != CurriculumKind.grammar ||
        entry.level != level ||
        entry.id.trim().isEmpty ||
        entry.id.length > 128 ||
        !ids.add(entry.id) ||
        entry.contentVersion < 1 ||
        entry.heading.trim().isEmpty ||
        entry.heading.length > 256 ||
        entry.meaningVi.trim().isEmpty ||
        entry.meaningVi.length > 2048) {
      throw const FormatException('Invalid grammar quiz source');
    }
    headings.update(entry.heading.trim(), (n) => n + 1, ifAbsent: () => 1);
  }
  final eligible = source
      .where((entry) => headings[entry.heading.trim()] == 1)
      .toList(growable: false);
  final meanings = <String, CurriculumEntry>{};
  for (final entry in eligible) {
    meanings.putIfAbsent(entry.meaningVi.trim(), () => entry);
  }
  if (meanings.length < 4) return const [];
  final pool = meanings.values.toList(growable: false);
  final questions = <GrammarQuizQuestion>[];
  for (var index = 0; index < eligible.length; index++) {
    final target = eligible[index];
    final choices = <CurriculumEntry>[];
    for (var step = 0; step < pool.length; step++) {
      final candidate = pool[(index + step) % pool.length];
      if (candidate.meaningVi.trim() != target.meaningVi.trim()) {
        choices.add(candidate);
      }
      if (choices.length == 3) break;
    }
    choices.insert(index % 4, target);
    questions.add(GrammarQuizQuestion._(target, choices));
  }
  return List.unmodifiable(questions);
}

/// Process-local answers only. No attempt persistence, study time or mastery.
final class GrammarQuizRound {
  GrammarQuizRound(List<GrammarQuizQuestion> source)
    : questions = List.unmodifiable(source) {
    if (source.length > 10 ||
        source.map((q) => q.target.id).toSet().length != source.length ||
        source.any((q) => q.target.level != source.first.target.level)) {
      throw const FormatException('Invalid grammar quiz round');
    }
  }

  final List<GrammarQuizQuestion> questions;
  final _answers = <String, String>{};
  int _index = 0;
  GrammarQuizQuestion? get current =>
      _index < questions.length ? questions[_index] : null;
  bool get isComplete => current == null;
  bool get answered => current != null && _answers.containsKey(current!.id);
  String? get selectedChoice => current == null ? null : _answers[current!.id];
  int get answeredCount => _answers.length;
  Map<String, String> get acceptedAnswers => Map.unmodifiable(_answers);
  int get score => questions.where((q) => _answers[q.id] == q.target.id).length;
  List<CurriculumEntry> get incorrect => List.unmodifiable([
    for (final q in questions)
      if (_answers.containsKey(q.id) && _answers[q.id] != q.target.id) q.target,
  ]);

  bool answer(String questionId, String choiceId) {
    final question = current;
    if (question == null ||
        question.id != questionId ||
        answered ||
        !question.choices.any((choice) => choice.id == choiceId)) {
      return false;
    }
    _answers[questionId] = choiceId;
    return true;
  }

  bool advance(String questionId) {
    if (current?.id != questionId || !answered) return false;
    _index++;
    return true;
  }
}
