import '../../../shared/models/preview_level.dart';
import '../../curriculum/domain/curriculum.dart';
import '../data/quiz_report_v2_adapter.dart';
import '../domain/grammar_quiz.dart';
import '../domain/vocabulary_quiz.dart';

/// A current-content suggestion from one explicitly loaded server page.
/// This is not mastery, SRS state, study credit or an all-time model.
final class QuizReportV2WeakPoint {
  const QuizReportV2WeakPoint({
    required this.entry,
    required this.quizType,
    required this.jlptLevel,
    required this.practiceKind,
    required this.incorrectCount,
    required this.lastCompletedAt,
  });

  final CurriculumEntry entry;
  final String quizType;
  final String jlptLevel;
  final String? practiceKind;
  final int incorrectCount;
  final DateTime lastCompletedAt;
}

String quizReportV2ContentKey(String quizType, String jlptLevel) =>
    '$quizType:$jlptLevel';

final class _CurrentQuestion {
  const _CurrentQuestion(this.target, this.choices);
  final CurriculumEntry target;
  final List<CurriculumEntry> choices;
}

final class _WeakPointState {
  _WeakPointState({
    required this.entry,
    required this.quizType,
    required this.jlptLevel,
    required this.practiceKind,
    required this.incorrectCount,
    required this.lastAnswerCorrect,
    required this.lastCompletedAt,
  });

  final CurriculumEntry entry;
  final String quizType;
  final String jlptLevel;
  final String? practiceKind;
  int incorrectCount;
  bool lastAnswerCorrect;
  bool ambiguousAtLatestTime = false;
  DateTime lastCompletedAt;
}

bool _sameDisplayedChoices(
  List<CurriculumEntry> current,
  QuizReportV2Answer reported,
) {
  if (current.length != 4 ||
      reported.choices.length != 4 ||
      reported.choiceContentVersions.length != 4)
    return false;
  for (var index = 0; index < 4; index++) {
    if (current[index].id != reported.choices[index] ||
        current[index].contentVersion !=
            reported.choiceContentVersions[index]) {
      return false;
    }
  }
  return true;
}

/// Rebuilds current questions and requires exact target/choice provenance.
/// Only a latest unambiguous wrong answer is suggested; grammar kinds stay
/// separate. The input page is strict-decoded and caller-owned.
List<QuizReportV2WeakPoint> deriveQuizReportV2WeakPoints({
  required QuizReportV2HistoryPage page,
  required Map<String, List<CurriculumEntry>> currentContent,
}) {
  if (page.items.length > 100) {
    throw const FormatException('Invalid quiz report history page');
  }
  final keys = <String>{
    for (final item in page.items)
      quizReportV2ContentKey(item.request.quizType, item.request.jlptLevel),
  };
  final questionSets = <String, Map<String, _CurrentQuestion>>{};
  for (final key in keys) {
    final source = currentContent[key];
    if (source == null)
      throw const FormatException('Current quiz content unavailable');
    final split = key.split(':');
    if (split.length != 2)
      throw const FormatException('Invalid quiz report content scope');
    final level = switch (split[1]) {
      'N5' => PreviewLevel.n5,
      'N4' => PreviewLevel.n4,
      _ => throw const FormatException('Invalid quiz report content level'),
    };
    final questions = <String, _CurrentQuestion>{};
    switch (split[0]) {
      case 'vocabulary_reading':
        for (final question in buildVocabularyQuiz(source, level)) {
          questions[question.target.id] = _CurrentQuestion(
            question.target,
            question.choices,
          );
        }
        break;
      case 'grammar_meaning':
        for (final question in buildGrammarQuiz(source, level)) {
          questions[question.target.id] = _CurrentQuestion(
            question.target,
            question.choices,
          );
        }
        break;
      default:
        throw const FormatException('Invalid quiz report content type');
    }
    questionSets[key] = questions;
  }

  final ordered = List<QuizReportV2HistoryEntry>.of(page.items)
    ..sort((left, right) {
      final time = DateTime.parse(
        left.request.completedAt,
      ).compareTo(DateTime.parse(right.request.completedAt));
      return time == 0
          ? left.request.clientEventId.compareTo(right.request.clientEventId)
          : time;
    });

  final states = <String, _WeakPointState>{};
  for (final receipt in ordered) {
    final request = receipt.request;
    final key = quizReportV2ContentKey(request.quizType, request.jlptLevel);
    final questions = questionSets[key]!;
    final completedAt = DateTime.parse(request.completedAt).toUtc();
    for (final answer in request.answers) {
      final question = questions[answer.itemId];
      if (question == null ||
          question.target.contentVersion != answer.contentVersion ||
          !_sameDisplayedChoices(question.choices, answer))
        continue;
      final stateKey = '$key|${request.practiceKind ?? ''}|${answer.itemId}';
      final previous = states[stateKey];
      if (previous == null) {
        states[stateKey] = _WeakPointState(
          entry: question.target,
          quizType: request.quizType,
          jlptLevel: request.jlptLevel,
          practiceKind: request.practiceKind,
          incorrectCount: answer.isCorrect ? 0 : 1,
          lastAnswerCorrect: answer.isCorrect,
          lastCompletedAt: completedAt,
        );
        continue;
      }
      if (!answer.isCorrect) previous.incorrectCount++;
      if (completedAt.isAfter(previous.lastCompletedAt)) {
        previous.lastAnswerCorrect = answer.isCorrect;
        previous.lastCompletedAt = completedAt;
        previous.ambiguousAtLatestTime = false;
      } else if (completedAt.isAtSameMomentAs(previous.lastCompletedAt) &&
          previous.lastAnswerCorrect != answer.isCorrect) {
        previous.ambiguousAtLatestTime = true;
      }
    }
  }

  final result = states.values
      .where(
        (state) =>
            state.incorrectCount > 0 &&
            !state.lastAnswerCorrect &&
            !state.ambiguousAtLatestTime,
      )
      .map(
        (state) => QuizReportV2WeakPoint(
          entry: state.entry,
          quizType: state.quizType,
          jlptLevel: state.jlptLevel,
          practiceKind: state.practiceKind,
          incorrectCount: state.incorrectCount,
          lastCompletedAt: state.lastCompletedAt,
        ),
      )
      .toList();
  result.sort((left, right) {
    final count = right.incorrectCount.compareTo(left.incorrectCount);
    if (count != 0) return count;
    final time = right.lastCompletedAt.compareTo(left.lastCompletedAt);
    if (time != 0) return time;
    final level = left.jlptLevel.compareTo(right.jlptLevel);
    if (level != 0) return level;
    final type = left.quizType.compareTo(right.quizType);
    if (type != 0) return type;
    final kind = (left.practiceKind ?? '').compareTo(right.practiceKind ?? '');
    if (kind != 0) return kind;
    return left.entry.id.compareTo(right.entry.id);
  });
  return List.unmodifiable(result);
}
