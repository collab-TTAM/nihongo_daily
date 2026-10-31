// Synthetic local reports, not hosted identity or learner mastery evidence.
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz_attempt.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz_progress.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';
import 'grammar_quiz_progress_test.dart'
    show owner, other, source, report, variant, derive;

final start = DateTime.utc(2026, 10, 1);
GrammarQuizAttempt event(
  int id,
  int hours, {
  bool correct = true,
  PreviewLevel level = PreviewLevel.n5,
  GrammarQuizAttemptKind kind = GrammarQuizAttemptKind.primary,
}) => variant(
  report(event: id, correct: correct, level: level, kind: kind),
  (json) => json['completed_at'] = start
      .add(Duration(hours: hours))
      .toIso8601String(),
);

void main() {
  for (final level in PreviewLevel.values) {
    for (final kind in GrammarQuizAttemptKind.values) {
      test(
        '${level.name} ${kind.name} recall is spaced deduplicated and kind isolated',
        () {
          final otherKind = kind == GrammarQuizAttemptKind.primary
              ? GrammarQuizAttemptKind.correction
              : GrammarQuizAttemptKind.primary;
          final a = event(1, 0, level: level, kind: kind);
          final b = event(2, 24, level: level, kind: kind);
          final c = event(3, 48, level: level, kind: kind);
          final rapid = event(4, 1, level: level, kind: kind);
          final foreignWrong = event(
            5,
            49,
            level: level,
            kind: otherKind,
            correct: false,
          );
          final reports = [c, rapid, a, b, a, c, foreignWrong];
          final p = derive(reports, level: level, kind: kind);
          expect(p.attemptCount, 4);
          expect(p.answerCount, 16);
          expect(p.correctCount, 16);
          expect(p.practicedCurrentItemCount, 4);
          expect(p.recallMilestoneCurrentItemCount, 4);
          expect(
            p.items.every((i) => i.recallEvidence.countedCorrect == 3),
            isTrue,
          );
          expect(p.needsReview, isEmpty);
          expect(
            derive(
              [a, rapid, a],
              level: level,
              kind: kind,
            ).recallMilestoneCurrentItemCount,
            0,
          );
          final separate = derive(reports, level: level, kind: otherKind);
          expect(separate.attemptCount, 1);
          expect(separate.recallMilestoneCurrentItemCount, 0);
          expect(separate.needsReview, hasLength(4));
          final wrong = event(6, 48, level: level, kind: kind, correct: false);
          final reset = derive([...reports, wrong], level: level, kind: kind);
          expect(reset.recallMilestoneCurrentItemCount, 0);
          expect(reset.needsReview, hasLength(4));
          expect(
            p.recallMilestoneCurrentItemCount,
            4,
          ); // Prior snapshot unchanged.
          final foreignCorrect = [
            for (var i = 0; i < 3; i++)
              event(20 + i, 72 + i * 24, level: level, kind: otherKind),
          ];
          expect(
            derive(
              [wrong, ...foreignCorrect],
              level: level,
              kind: kind,
            ).recallMilestoneCurrentItemCount,
            0,
          );
          expect(
            derive(
              [wrong, ...foreignCorrect],
              level: level,
              kind: otherKind,
            ).recallMilestoneCurrentItemCount,
            4,
          );
        },
      );
    }
  }
  test(
    'grammar recall empty old version changed choices and other level stay historical',
    () {
      expect(derive([]).recallMilestoneCurrentItemCount, 0);
      final reports = [for (var i = 0; i < 3; i++) event(i + 1, i * 24)];
      final current = derive(reports);
      expect(current.recallMilestoneCurrentItemCount, 4);
      final oldVersion = derive(reports, content: source(version: 2));
      expect(oldVersion.practicedCurrentItemCount, 0);
      expect(oldVersion.recallMilestoneCurrentItemCount, 0);
      expect(oldVersion.correctCount, 12);
      final changedChoices = [
        for (final e in reports)
          variant(e, (json) {
            for (final raw in json['answers'] as List) {
              final row = raw as Map<String, Object?>;
              row['choices'] = (row['choices'] as List).reversed.toList();
            }
          }),
      ];
      expect(derive(changedChoices).recallMilestoneCurrentItemCount, 0);
      expect(derive(changedChoices).correctCount, 12);
      expect(
        derive(reports, level: PreviewLevel.n4).recallMilestoneCurrentItemCount,
        0,
      );
      // A mismatched wrong is history, not a reset of current evidence.
      final staleWrong = variant(event(8, 72, correct: false), (json) {
        for (final raw in json['answers'] as List) {
          (raw as Map<String, Object?>)['content_version'] = 2;
        }
      });
      expect(
        derive([...reports, staleWrong]).recallMilestoneCurrentItemCount,
        4,
      );
    },
  );
  test(
    'grammar recall rejects foreign owners and conflicts before filtering kind',
    () {
      final a = event(1, 0);
      expect(
        () => deriveGrammarQuizProgress(
          ownerId: owner,
          level: PreviewLevel.n5,
          kind: GrammarQuizAttemptKind.correction,
          source: source(),
          history: [OwnedGrammarQuizAttempt(other, a)],
        ),
        throwsFormatException,
      );
      final changed = variant(
        a,
        (json) => json['practice_kind'] = 'correction',
      );
      expect(
        () => derive([a, changed], kind: GrammarQuizAttemptKind.correction),
        throwsA(isA<GrammarQuizProgressConflict>()),
      );
    },
  );
  test(
    'grammar recall tied instant uses existing UUID order not input order',
    () {
      final correct = event(1, 0);
      final wrong = event(2, 0, correct: false);
      final a = derive([wrong, correct]);
      final b = derive([correct, wrong]);
      expect(a.items.first.recallEvidence.countedCorrect, 0);
      expect(b.items.first.recallEvidence.countedCorrect, 0);
      final next = event(3, 24);
      expect(
        derive([
          next,
          wrong,
          correct,
        ]).items.first.recallEvidence.countedCorrect,
        1,
      );
    },
  );
}
