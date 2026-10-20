import '../../curriculum/domain/curriculum.dart';
import '../../../shared/models/preview_level.dart';

final class QuizQuestion {
  QuizQuestion._(this.target, List<CurriculumEntry> choices)
    : choices = List.unmodifiable(choices);
  final CurriculumEntry target;
  final List<CurriculumEntry> choices;
  String get id {
    return '${target.level.name}/${target.id}/${target.contentVersion}';
  }
}

/// Original-source reading choices only; no learning write or mastery inference.
List<QuizQuestion> buildVocabularyQuiz(
  List<CurriculumEntry> source,
  PreviewLevel level,
) {
  if (source.length > 5000) {
    throw const FormatException('Quiz source too large');
  }
  final ids = <String>{};
  final headings = <String, int>{};
  for (final entry in source) {
    final reading = entry.reading;
    if (entry.kind != CurriculumKind.vocabulary ||
        entry.level != level ||
        entry.id.isEmpty ||
        entry.id.length > 128 ||
        !ids.add(entry.id) ||
        entry.contentVersion < 1 ||
        entry.heading.trim().isEmpty ||
        entry.heading.length > 128 ||
        reading == null ||
        reading.trim().isEmpty ||
        reading.length > 128) {
      throw const FormatException('Invalid quiz source');
    }
    headings.update(entry.heading.trim(), (n) => n + 1, ifAbsent: () => 1);
  }
  final kanji = RegExp(r'[\u3400-\u9fff]');
  final eligible = <CurriculumEntry>[];
  for (final entry in source) {
    if (headings[entry.heading.trim()] == 1 && kanji.hasMatch(entry.heading)) {
      eligible.add(entry);
    }
  }
  final readings = <String, CurriculumEntry>{};
  for (final entry in eligible) {
    readings.putIfAbsent(entry.reading!.trim(), () => entry);
  }
  if (readings.length < 4) return const [];
  final pool = readings.values.toList();
  final questions = <QuizQuestion>[];
  for (var i = 0; i < eligible.length; i++) {
    final entry = eligible[i];
    final choices = <CurriculumEntry>[];
    for (var step = 0; step < pool.length; step++) {
      final candidate = pool[(i + step) % pool.length];
      if (candidate.reading!.trim() != entry.reading!.trim()) {
        choices.add(candidate);
      }
      if (choices.length == 3) break;
    }
    choices.insert(i % 4, entry);
    questions.add(QuizQuestion._(entry, choices));
  }
  return List.unmodifiable(questions);
}

/// One accepted answer per current question. All results are process-local.
final class QuizRound {
  QuizRound(List<QuizQuestion> questions)
    : questions = List.unmodifiable(questions) {
    final ids = questions.map((q) => q.id).toSet();
    if (questions.length > 10 || ids.length != questions.length) {
      throw const FormatException('Invalid quiz round');
    }
  }

  final List<QuizQuestion> questions;
  final _answers = <String, String>{};
  int _index = 0;
  QuizQuestion? get current =>
      _index < questions.length ? questions[_index] : null;
  bool get isComplete => current == null;
  bool get answered => current != null && _answers.containsKey(current!.id);
  String? get selectedChoice => current == null ? null : _answers[current!.id];
  int get answeredCount => _answers.length;
  int get score {
    return questions.where((q) => _answers[q.id] == q.target.id).length;
  }

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
