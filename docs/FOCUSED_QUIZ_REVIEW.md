# Focused current-source quiz review — Issue #13

After explicitly loading local account statistics on /progress, the learner can
choose `Luyện lại các từ này`. This creates a new quiz over current needs-review
targets in the existing deterministic priority: repeated-error count, latest
error time and original ID. It includes all matched targets, even when only the
first20 headings fit the statistics list. Existing batches contain at most10
questions, with explicit next batch/restart and first-answer checking.

## Current source and canonical choices

selectVocabularyReviewQuestions uses the full original quiz deck, not a rebuilt
small distractor pool. It retains each exact immutable QuizQuestion/choices
object and the projection's priority order. A target must have the same
level/ID/content version and identical current CurriculumEntry instance as the
loaded progress projection. New source objects, changed versions, missing IDs,
foreign levels and cleared/correct-only history cannot silently retarget it.
Duplicate question keys or a deck above5000 entries fail before selection.
This process-local identity fence is not durable source authentication or
linguistic/version-publication certification.

A single current wrong item can therefore be practiced using its four original
choices, including distractors outside the needs-review set. Only actual original
questions can be selected; no fallback question, invented reading or random
replacement is made. No new recommendation/mastery policy is introduced.

## Explicit practice and save lifecycle

The existing quiz panel is extracted into VocabularyQuizPanel and reused by
/quiz and focused practice. Source comparison/canonical formatting verifies the
whole panel equals the original plus its public names and optional timer gate;
answer, advance, capture, manual-save/retry/late-result, question/result and batch
logic are retained. The dedicated /quiz keeps its timer enabled as before.
Focused practice has no timer/editor or recorder start/interrupt path, so this
statistics flow never grants study minutes. Scores still do not imply mastery.

Practice starts only from an explicit current projection action. Guards require
the same mounted account/history capability, curriculum source, selected view
level and exact progress object, including changes before the next frame. Each
opening has a fresh immutable question-list identity; retained controls cannot
reset an active round or close a later reopened practice. Back discards unsaved
answers. Leaving/reloading/changing source, level or owner clears the practice.
No network service, SDK/store owner, retention or Auth strategy is added.

Completion captures one new immutable local attempt under the existing captured
history capability; saving remains explicit and retries use that same event.
Accepted writes retain their original owner, while replacement/logout fences
late UI publication. Returning to statistics preserves its previous snapshot;
explicitly load statistics again to include the saved correction. A later saved
correct answer clears only its matching current-source candidate through the
existing projection. No automatic read/save/credit, SRS mutation or MASTERED
state is installed. Default unconfigured progress still has no account/results.

## Evidence and limits

Parenteb58c1c CI39951748561/latest attempt1 passed allfive jobs/every required
step:762 full Flutter/five Chrome/Web/Windows/native/SQL/Edge checks, including
all11 quiz-study widgets. That is prior component evidence, not these new cases.

Six new pure cases use TEST ONLY synthetic metadata and the actual builder,
progress/attempt models and selector: both levels' priority/full original choices,
exact objects/immutability, focused correction/dedup, same-version source copies
or new versions, empty/correct/foreign-level and duplicate/oversized input.
Fresh official Dart3.9.2 SHA256 verified; strict analysis and6/6 passed with the
identical seven-file source/test graph in a disposable harness. Only the
flutter_test import is changed to package:test1.26.2. This is not Flutter execution.

Nine authored actual-router/provider widget cases read original N5 unchanged and
use TEST ONLY Auth/memory/clock: empty availability; priority/choices/manual save/
explicit stats reload; stale projection; source replacement before frame; content
version change; logout/other-account held-save completion; level/old answer;
back/reopen/old back;320px/200-percent real controls. Existing tests/assertions
are unchanged. Full new Flutter/analyze/widget/platform proof must be observed
on exact-head CI; no local metadata-bootstrap review rejection workaround.

Format, QA inventory/regressions and final commit/tree/current-head CI are
recorded in PROJECT_STATUS/PR41/Issue13. Keep #13 open/#41 draft and all14 hosted
release groups pending. Hosted identity/sync/learner proof, authoritative mastery,
complete reviewed curriculum and server quiz availability remain separate work.
No Pro/content/manifest/SQL/security/CI/dependency/provider/spend/deployment change.
