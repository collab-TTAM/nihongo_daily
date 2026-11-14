// Synthetic core entries only. No authored curriculum or hosted learner proof.
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/curriculum/domain/curriculum.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

CurriculumEntry sample(
  int number, {
  String? id,
  CurriculumKind kind = CurriculumKind.grammar,
  PreviewLevel level = PreviewLevel.n5,
  int version = 1,
  String? heading,
  String? meaning,
}) => CurriculumEntry(
  id: id ?? 'grammar-$number',
  kind: kind,
  level: level,
  contentVersion: version,
  heading: heading ?? 'TEST ONLY pattern $number',
  caption: 'TEST ONLY',
  reading: null,
  meaningVi: meaning ?? 'TEST ONLY meaning $number',
  explanationVi: 'TEST ONLY explanation',
  hasAudioReference: false,
  notes: const [],
  mistakes: const [],
  examples: const [],
);

List<CurriculumEntry> samples([int count = 6]) => [
  for (var i = 0; i < count; i++) sample(i),
];

void main() {
  test('grammar choices are stable original entries with rotating slots', () {
    final source = samples();
    final first = buildGrammarQuiz(source, PreviewLevel.n5);
    final second = buildGrammarQuiz(source, PreviewLevel.n5);
    expect(first, hasLength(6));
    for (var i = 0; i < first.length; i++) {
      final question = first[i];
      expect(question.target, same(source[i]));
      expect(question.id, 'grammar/n5/grammar-$i/1');
      expect(question.choices, hasLength(4));
      expect(question.choices[i % 4], same(source[i]));
      expect(
        question.choices.map((c) => c.meaningVi.trim()).toSet(),
        hasLength(4),
      );
      expect(question.choices.every(source.contains), isTrue);
      expect(question.choices, second[i].choices);
    }
  });

  test('grammar source requires four distinct eligible meanings', () {
    expect(buildGrammarQuiz([], PreviewLevel.n5), isEmpty);
    expect(buildGrammarQuiz(samples(3), PreviewLevel.n5), isEmpty);
    final source = [
      sample(0),
      sample(1),
      sample(2),
      sample(3, meaning: ' TEST ONLY meaning 0 '),
    ];
    expect(buildGrammarQuiz(source, PreviewLevel.n5), isEmpty);
  });

  test('duplicate grammar prompts are excluded before the choice pool', () {
    final source = samples();
    source.add(sample(6, heading: ' TEST ONLY pattern 0 '));
    final questions = buildGrammarQuiz(source, PreviewLevel.n5);
    expect(questions, hasLength(5));
    expect(questions.any((q) => q.target.id == 'grammar-0'), isFalse);
    expect(questions.any((q) => q.target.id == 'grammar-6'), isFalse);
    expect(
      questions.expand((q) => q.choices).any((c) => c.id == 'grammar-0'),
      isFalse,
    );
  });

  test('all grammar source entries validate before any exclusion', () {
    for (final invalid in [
      sample(6, id: 'grammar-0'),
      sample(6, id: ' '),
      sample(6, id: 'x' * 129),
      sample(6, kind: CurriculumKind.vocabulary),
      sample(6, level: PreviewLevel.n4),
      sample(6, version: 0),
      sample(6, heading: ' '),
      sample(6, heading: 'x' * 257),
      sample(6, meaning: ' '),
      sample(6, heading: 'TEST ONLY pattern 0', meaning: ' '),
      sample(6, meaning: 'x' * 2049),
    ]) {
      expect(
        () => buildGrammarQuiz([...samples(), invalid], PreviewLevel.n5),
        throwsFormatException,
      );
    }
    expect(
      () => buildGrammarQuiz(samples(5001), PreviewLevel.n5),
      throwsFormatException,
    );
  });

  test('equal meaning targets still have distinct labelled choices', () {
    final questions = buildGrammarQuiz([
      ...samples(4),
      sample(4, meaning: ' TEST ONLY meaning 0 '),
    ], PreviewLevel.n5);
    expect(questions, hasLength(5));
    final last = questions.last;
    expect(last.target.id, 'grammar-4');
    expect(last.choices.map((c) => c.meaningVi.trim()).toSet(), hasLength(4));
    expect(last.choices.where((c) => c.id == last.target.id), hasLength(1));
  });

  test('grammar questions and rounds retain immutable list snapshots', () {
    final source = samples();
    final questions = buildGrammarQuiz(source, PreviewLevel.n5);
    final selected = questions.take(3).toList();
    final round = GrammarQuizRound(selected);
    source.clear();
    selected.clear();
    expect(questions, hasLength(6));
    expect(round.questions, hasLength(3));
    expect(() => questions.clear(), throwsUnsupportedError);
    expect(() => questions.first.choices.clear(), throwsUnsupportedError);
    expect(() => round.questions.clear(), throwsUnsupportedError);
    expect(() => round.acceptedAnswers.clear(), throwsUnsupportedError);
  });

  test('grammar first answer and current question govern advancement', () {
    final questions = buildGrammarQuiz(samples(), PreviewLevel.n5);
    final round = GrammarQuizRound(questions.take(2).toList());
    final first = round.current!;
    final wrong = first.choices.firstWhere((c) => c.id != first.target.id);
    expect(round.advance(first.id), isFalse);
    expect(round.answer('foreign', first.target.id), isFalse);
    expect(round.answer(first.id, 'foreign'), isFalse);
    expect(round.answer(first.id, wrong.id), isTrue);
    expect(round.selectedChoice, wrong.id);
    expect(round.answer(first.id, first.target.id), isFalse);
    expect(round.score, 0);
    expect(round.incorrect, [first.target]);
    expect(round.advance(first.id), isTrue);
    expect(round.advance(first.id), isFalse);
    expect(round.answer(first.id, first.target.id), isFalse);
    final last = round.current!;
    expect(round.answer(last.id, last.target.id), isTrue);
    expect(round.advance(last.id), isTrue);
    expect(round.isComplete, isTrue);
    expect(round.score, 1);
    expect(round.answeredCount, 2);
    expect(() => round.incorrect.clear(), throwsUnsupportedError);
    expect(round.answer(last.id, last.target.id), isFalse);
    expect(GrammarQuizRound(questions.take(2).toList()).answeredCount, 0);
  });

  test('grammar identity fences another level and content version', () {
    final question = buildGrammarQuiz(samples(), PreviewLevel.n5).first;
    final round = GrammarQuizRound([question]);
    final revised = buildGrammarQuiz([
      sample(0, version: 2),
      ...samples().skip(1),
    ], PreviewLevel.n5).first;
    final otherLevel = buildGrammarQuiz([
      for (var i = 0; i < 6; i++) sample(i, level: PreviewLevel.n4),
    ], PreviewLevel.n4).first;
    expect(round.answer(revised.id, question.target.id), isFalse);
    expect(round.answer(otherLevel.id, question.target.id), isFalse);
    expect(round.answeredCount, 0);
  });

  test('grammar round bounds unique targets and a single level', () {
    final questions = buildGrammarQuiz(samples(11), PreviewLevel.n5);
    expect(() => GrammarQuizRound(questions), throwsFormatException);
    expect(
      () => GrammarQuizRound([questions.first, questions.first]),
      throwsFormatException,
    );
    final other = buildGrammarQuiz([
      for (var i = 20; i < 24; i++) sample(i, level: PreviewLevel.n4),
    ], PreviewLevel.n4).first;
    expect(
      () => GrammarQuizRound([questions.first, other]),
      throwsFormatException,
    );
    final empty = GrammarQuizRound([]);
    expect(empty.isComplete, isTrue);
    expect(empty.score, 0);
    expect(empty.advance('foreign'), isFalse);
  });

  test('ten grammar answers score once and exported maps stay frozen', () {
    final questions = buildGrammarQuiz(samples(10), PreviewLevel.n5);
    final round = GrammarQuizRound(questions);
    final before = round.acceptedAnswers;
    for (final question in questions) {
      expect(round.answer(question.id, question.target.id), isTrue);
      expect(round.answer(question.id, question.target.id), isFalse);
      expect(round.advance(question.id), isTrue);
    }
    expect(round.isComplete, isTrue);
    expect(round.score, 10);
    expect(round.answeredCount, 10);
    expect(round.incorrect, isEmpty);
    expect(before, isEmpty);
    expect(round.acceptedAnswers, hasLength(10));
    expect(() => round.acceptedAnswers.clear(), throwsUnsupportedError);
  });
}
