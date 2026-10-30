# Grammar quiz core — Issue #13

The grammar quiz now has an explicit process-local route at /quiz/grammar,
linked from /quiz. It does not persist grammar attempts.
GrammarQuizQuestion and GrammarQuizRound are distinct types from vocabulary
questions/rounds, preventing accidental input to VocabularyQuizAttempt.capture.
No Auth, storage, study recorder, SRS or progress capability is imported.

## Captured grammar history repository component — 2026-10-30 UTC

Pre-code rules saved PR41+issue13. GrammarQuizHistoryRepository captures a ready
ReviewSession object and its canonical owner; save accepts ONLY the immutable
attempt, not a learner owner field. Separate GrammarQuizOperationDrain and
GrammarQuizHistorySource capability remain uninstalled in current runtime/UI.
Trusted Auth/readiness/owner/directory composition is still required; these local
ports neither verify JWTs nor authorize hosted endpoints.

Reviewed vocabulary repository/drain algorithm is retained in separate grammar
types (comparison normalizes names/import/formatter), plus a final current-session
check AFTER result validation/snapshot copying. Readiness and exact session identity
are checked twice before dispatch, after success/error awaits and before publishing.
Mismatch/ABA/closed drain permanently retires an old repository. Reentrant checks
are rejected without revoking the healthy outer operation. Raw errors are redacted;
late old-session errors cannot override session-changed failure. A callback during
returned-list validation cannot publish old-owner data.

Same-event identical in-flight save returns the same Future; changed content,
including practice kind, conflicts before another dispatch. Result owner/content
must match the captured command. Loads reject foreign owners,more than10000 rows
or conflicting duplicates; exact duplicates collapse into an immutable snapshot
sorted ascending by completion time then event ID. This does not merge correction
scores into primary results. Accepted old-owner disk writes cannot be undone by
session switch; their late results are fenced and records remain with that owner.
Caller must revoke/drain accepted operations BEFORE closing borrowed storage; the
repository never closes caller resources. No implicit retry/auto-save is added.

Eighteen new real-journal/TEST ONLY Auth and held-result tests authored: owner/
primary/correction isolation,duplicate/coalesced/conflicting saves,storage reentry,
late save/load success+private error through A-B-A,pre-dispatch replacement,drain,
readiness/Auth reentry and getter replacement,unready/null/throwing Auth,redacted
storage/wrong owner/content,load sort/dedup/foreign/cap/conflict,final validation
callback replacement. Existing vocabulary/core/native journal tests unchanged.
Official fresh Dart3.9.2 SHA256 verified/strict format2files zerochanges PASS
(unresolved Flutter lint include warning, not analyzer). Assertion-enabled actual
Dart/native-file smoke PASS: coalesced dispatch,own history,late result fence,A-B-A,
fresh-owner isolation and drain barrier. NOT18Flutter or hosted proof. QA55 PASS/
inventory155 valid(not155executed)/diffcheck PASS; new18/fullFlutter/analyze/build
locally UNRUN(noFlutter), require exact-head Actions.

Parent72c6129 CI40971760438/latestattempt1 all5/EVERYstep SUCCESS/no skips; raw
Flutter123790581884 all9 native grammar journal cases and Windows123790052457
required persistent vault/sameSDK/profile/receipt marker observed. TEST ONLY,
not hosted learner/native Windows grammar ownership acceptance. Next exact-head
all5/EVERYstep/new18, then caller-owned runtime/store/drain composition before
explicit save/history UI. No app/default/Authstrategy/API/RLS/retention/content/Pro
activation or policy change; all14 hosted gates pending. PR41 draft/13 open.
Commit/tree/new CI in PR checkpoint; no incomplete merge/deploy/release claim.

## Native grammar test interpolation correction — 2026-10-29 UTC

Parentb4aed8a CI40964232310/latestattempt1 all5/EVERYstep inspected: database,
AI,repo-sanity,Windows SUCCESS. Flutter format SUCCESS, analyze failed sole
prefer_interpolation_to_compose_strings at native_grammar_quiz_journal_test.dart:204.
Nine new tests/integration/Web skipped, not passed. Build the identical512row
newline-joined string in rows, then interpolate its one trailing newline into
committed. Same row loop/codec/order/contents/terminator/assertions/caps/cleanup;
no production change. Reverse patch must restore entire parent test file.
No duplicate test for syntax-only correction. QA55/inventory155/whitespace and
official fresh Dart3.9.2 SHA256 verified/strict format1file zerochanges PASS
(unresolved Flutter lint include warning, not analyzer). New9/fullFlutter/analyze/
build still need new exact-head
Actions. No local Flutter/Windows execution claim; parent smoke is parent proof.
No content/Pro/Auth/API/RLS/default/storage/retention change. Journal remains
unwired; captured-session repository and explicit save UI still absent. PR41
stays draft/issue13 open/all14 hosted groups pending. Commit/tree/CI in PR handoff;
next all5/EVERYstep/new9 and retained SDK/native markers, fix real diagnostics
without weakening assertions. No incomplete merge/deploy/release acceptance.

## Native grammar journal component — 2026-10-29 UTC

Pre-code rules saved PR41+issue13. Separate GrammarQuizAttemptStore and
OwnedGrammarQuizAttempt carry explicit structural owner keys; these are NOT
Auth or write authorization. NativeGrammarQuizJournal is an opt-in component
for a caller-owned trusted private directory, never installed by current runtime
or quiz UI. No URL/key, token, source text, auto-save or server credit is added.
Later captured-session repository must fence every await before exposing it.

Uses separate grammar-quiz-attempts.lock and grammar-quiz-attempts.ndjson, leaving
vocabulary storage untouched. Existing vocabulary journal algorithm retained
except typed names/filenames and formatter whitespace (normalized-source equality
checked separately): serialized append/list, in-isolate ownership plus OS exclusive
lease, link rejection,1MiB/512events, flush-before-success, immutable snapshots,
owner+event exact replay/no bytes written; any changed payload including primary/
correction kind conflicts. Full canonical complete lines validate before EOF-tail
truncation; invalid committed/cross-type/conflicting rows preserve all bytes and
failed open releases ownership. Uncertain write sticks until close/reopen. Close
drains accepted writes and immediately rejects new work. No delete/compaction or
retention-policy change. Same UUID reused across owners is isolated; correction
requires its own event ID when saving a separate record. Listing is insertion
order, not trusted chronology. Plain local learning records are not a secret vault.

Nine new real-file Flutter unit cases authored: owner+primary/correction reopen,
exact replay+conflicts/healthy continuation, close drain/rejection,exclusive writer,
valid EOF repair,corrupt/noncanonical/vocabulary/conflicting complete-line preserve+
failed-open recovery,file/event caps,invalid owners/safe errors,data+lock symlinks.
Existing tests/vocabulary implementation remain unchanged. Official fresh Dart3.9.2
SHA256 verified/strict format4files zerochanges PASS (unresolved Flutter lint include
warning, not analyzer). Actual native Dart assertion-enabled smoke PASS for real-file
replay/conflict/owner isolation/exclusive writer/reopen/EOF recovery/corrupt bytes/
failed-open lease/closed rejection; NOT9Flutter test execution. QA55 PASS/inventory155
valid(not155executed)/diffcheck PASS. New9/fullFlutter/analyze/Web/Windows UNRUN locally.

Parentea5fa48 CI40955343076/latestattempt1 all5/EVERYstep SUCCESS; raw Flutter
123734800006 all12 grammar model tests and Windows123733971319 retained persistent
vault/sameSDK/profile/receipt marker observed. TEST ONLY component proof; not hosted
learner, new-journal Windows cross-process or hardware power-loss certification.
UI save/history, trusted owner/session repository and runtime/journal disposal
composition remain absent. No default/retention/Authstrategy/API/RLS/content/Pro
change; all14 hosted groups pending. PR41 draft/13 open; commit/tree/new CI in PR
checkpoint. Next exact-head all5/EVERYstep/new9, then guarded repository before UI
activation; no incomplete merge/deploy/release acceptance.

## Grammar attempt test lint correction — 2026-10-29 UTC

Parent5d7f414 CI40947859746/latestattempt1 all5/EVERYstep inspected. Database,
repo-sanity,AI,Windows SUCCESS; Flutter format SUCCESS, analyzer failed sole
curly_braces_in_flow_control_structures at grammar_quiz_attempt_test.dart:277.
Twelve new unit tests and downstream Flutter/Web checks skipped, not passed.
Add braces only to that multiline order-mutation if. Assignment, inputs, every
assertion/deadline and production model unchanged; reverse patch restores entire
parent test file byte-for-byte. No new test for this syntax-only fix. QA55/
inventory155 valid(not155executed)/whitespace checked in PR. Local Dart/Flutter/
analyze/build UNRUN; require new exact-head CI. Old pure smoke is parent evidence.
No corpus/Pro/Auth/API/RLS/storage/default/retention change. Grammar storage/UI save
still absent; PR41 draft/13 open/all14 hosted release groups pending. Commit/tree/
new CI in PR checkpoint; next all5/EVERYstep/new12 and retained native markers,
fix actual diagnostics preserving assertions. No merge/deploy/release acceptance.

## Grammar attempt data model — 2026-10-29 UTC

Pre-code scoring/identity/scope rules were recorded in PR41 and issue13 before
implementation. GrammarQuizAttempt is a separate immutable local format1 data
model, not a repository or save action. Capture requires a completed nonempty
GrammarQuizRound of at most10 unique targets, exact accepted first answers,
original question/choice order and content versions. Every answer has four
unique canonical UUID choices including target and selection; versions are
positive signed32bit integers. N5/N4 and canonical UTC time(year2000..2100) only.
Exact keys reject unknown/missing/type-invalid fields. Errors contain fixed text.

quiz_type=grammar_meaning distinguishes this from vocabulary reports. Required
practice_kind=primary/correction keeps their scores in separate records; this
classification is caller-reported, not proof of its source round or server credit.
Score is derived from accepted target IDs, never supplied JSON. No copied source
texts, credentials, owner field, study minutes or mastery. Nested lists are
immutable; input/output JSON copies cannot mutate the snapshot. Exact canonical
content equality includes event/time/kind/order/answers for future idempotency;
it does not implement deduplication or authorize a write. Structural validation
is not curriculum membership or evidence that the learner answered honestly.

Twelve synthetic unit cases authored for capture/first-answer/versions/order,
both levels+practice kinds, incomplete/empty, missing/unknown/derived/owner fields,
vocabulary type separation, versions/count/level, duplicate targets/answer shape,
choice membership, identity/time, detached immutable lists, exact equality, and
10targets/maxversion. Old tests/vocabulary model/grammar UI remain unchanged.
Official fresh Dart3.9.2 archive SHA256 verified/strict format2files zerochanges
PASS(unresolved Flutter lint include warning, not analyzer). An assertion-enabled
pure Dart smoke executes the actual model across four level/kind combinations
and16 rejection/immutability checks; PASS, not Flutter execution. QA55 PASS/
inventory155 valid(not155executed)/diffcheck PASS. New12/full Flutter/analyze/
Web/Windows locally UNRUN(noFlutter); exact-head Actions required.

Parentcf51ab4 CI40944034220/latestattempt1 all5/EVERYstep SUCCESS/no skips;
Flutter123695470637 both accepted-answer review widgets and Windows123694648581
required persistent vault/sameSDK/profile/receipt marker observed. TEST ONLY,
not hosted learner acceptance. This increment has no I/O, storage, Auth, UI save,
mastery, SRS, shared API/schema/RLS, default, retention or Pro/content changes.
Grammar persistence still absent. Next after new exact-head CI: review/wire a
separate owner-captured grammar store and explicit save UI, keeping corrections
separate and vocabulary history untouched. PR41 draft/13 open/all14 hosted gates
pending. Commit/tree/new CI in PR checkpoint; no merge/deploy/release acceptance.

## Accepted-answer review — 2026-10-29 UTC

Completed rounds now show the accepted choice meaning, original target meaning
and original target explanation for each incorrect answer, in question order.
The display reads the completed round's immutable accepted-answer snapshot and
exact question choices. No invented explanation or additional curriculum request.
Correct answers are omitted. Focused correction summaries use only that subset's
answers while the original score remains frozen; restart removes the old summary.
Existing first-answer, round/source/level lifecycle guards remain unchanged.

Two synthetic widget cases exercise normal and320px/200% layouts, selected vs
correct meanings, distinct target explanations, omission of correct questions,
subset isolation, frozen original score, full restart and a single source read.
Existing tests/assertions remain untouched. Local format/QA and exact-head CI are
recorded in PR41; Flutter/analyze/native builds locally unavailable. This remains
process-local feedback, not grammar persistence/mastery or hosted learner proof.


## Focused correction round — 2026-10-29

After a completed original round containing errors, Luyện riêng câu sai starts a
separate round from exactly its incorrect original question objects, in original
order. Choices, source versions, explanations and examples are reused unchanged;
no new curriculum read or generated material. It retains first-answer scoring and
source/level/provider/generation guards. The original integer score stays visible
as Bộ gốc and cannot be raised by correction answers. This is practice feedback,
not repeated-error persistence, mastery or server study credit.

Làm lại câu sai resets only the correction subset. Làm lại bộ gốc explicitly
starts the entire original batch with empty answers and removes the frozen score.
Bộ câu hỏi tiếp theo always advances by the original batch length, even after
reviewing only one or two mistakes; no original questions repeat or disappear.
Perfect primary rounds and correction rounds offer no nested review action.
Every transition constructs a fresh round identity, so captured original/focused
answer/advance/review/restart/batch callbacks cannot revive through an ABA cycle.
Reload, level/source change and route exit discard both scopes as before.

Four synthetic widget cases cover8/10 original +2/2 correction, preserved score,
exact subset order/one source read, duplicate/stale actions, subset restart,
original restart/perfect round, original10-row next-batch offset, reload/level/
disposal and320px200% actual controls. All original fixture bytes/assertions/
timeouts/cleanup are retained. Parent504e157 CI40880006535/latestattempt1 all5/
EVERYstep SUCCESS and native persistent SDK marker observed; TEST ONLY component,
not hosted learner proof. Fresh Dart3.9.2 archive SHA256 verified/strict format
clean (unresolved Flutter lint include warning); QA55/inventory154/whitespace
checked separately. New4/full Flutter/analyze/build locally UNRUN(noFlutter),
require new exact-head Actions. No storage/Auth/SRS/vocabulary history/content/
Pro/default/retention policy change; all14 hosted release groups remain pending.


## Local screen and source integration — 2026-10-29

The fixed curriculum repository grammar/selected-level read feeds an autoDispose
provider and the existing bounded core. Vietnamese loading, safe redacted error,
manual reload and insufficient-content states do not invent data. Each visible
round has at most10 questions; next batch and restart are explicit. Feedback and
incorrect review retain original meaning/explanation; score is integer correct/
round total. No grammar data enters vocabulary history or progress/save paths.

Every action checks the exact provider snapshot, repository, level and screen
generation. Manual listeners retire level/source callbacks before the next frame,
including ABA. Provider invalidation immediately retires old actions; a keyed new
panel discards answers on reload/source/level replacement. Round identity fences
old answer/advance/restart/batch closures even for identical question IDs. Route
exit disposes the panel; no stale callback may trigger a read or answer.

Eight synthetic widget cases cover real route/link/provider/core, wrong/correct/
duplicate answers, ten-question scoring/review/restart/next batch with one source
read, safe errors/retry/empty, pending old-level success/error, level ABA/reload/
disposal, repository replacement before a frame and320px/200% actual buttons.
No corpus files/tests or Pro scope modified. Parent465b17a CI40872072420/latest
attempt1 all5/EVERYstep succeeded; all10 core cases and native persistent SDK
marker observed. New widgets/analyze/platform builds locally UNRUN(no Flutter);
Dart3.9.2 archive SHA256 verified/format clean, with unresolved Flutter lint include
warning. QA55/inventory154/whitespace checked separately; new exact-head Actions
required. Default AI off/all14 hosted groups pending; not hosted learner proof.


## Original usage and examples after answering — 2026-10-29

After a valid current answer, a collapsed Cách dùng và ví dụ theo bài gốc panel
shows the target's original usage notes, common mistakes and every Japanese /
reading / Vietnamese example. Wrong answers still show the correct target's
material, not the selected distractor. Empty note/mistake sections are omitted;
missing examples explicitly say Bài gốc chưa có ví dụ. No examples are generated.
The existing explanation remains visible without opening the panel.

The panel is keyed to the exact question identity and exists only after answering.
Advancing/reloading removes it; the next answered question starts collapsed.
Existing source/level/generation/round guards remain unchanged. Expanding/collapsing
uses the loaded immutable entry and performs no extra repository read or write.
It does not change scoring, vocabulary persistence, study time or mastery.

Three synthetic widget cases cover hidden-before-answer/collapsed state, wrong/
correct target material including two complete example triples, next-question
reset, empty sections/reload and actual title/next taps at320px/200% text. Every
original test fixture byte is retained after removing the new helper/cases.
Parentfa5da1a CI40876848905/latestattempt1 all5/EVERYstep succeeded, including
all8 prior grammar widgets and Windows persistent SDK/profile/receipt rotation.
New3 widgets/format/analyze/build locally UNRUN(no SDK); QA55/inventory154/diffcheck
are separate checks. No content/Pro/Auth/API/RLS/retention/default policy change;
all14 hosted learner release groups remain pending and PR41 stays draft.

## Reviewed selection and scoring rules

The UI asks: Chọn nghĩa tiếng Việt theo bài gốc for target.heading (the
existing grammar pattern). Choice labels are original meaningVi values. This is
source association, not proof that other grammar patterns are semantically wrong
or that original explanations are complete. Linguistic review remains required.
No new text, examples or distractors are generated or added to content exports.

Validate the entire selected-level grammar source before filtering: at most5000
entries, unique nonblank IDs up to128 code units, positive content versions,
nonblank patterns up to256 and nonblank meanings up to2048. Fixed format errors
contain no source text. Bounds are local quiz limits, not shared wire changes.
Skip all repeated trimmed patterns; distinct trimmed meanings form the option
pool. Fewer than four eligible meanings returns an empty list. Original order,
first representative per meaning and a rotating correct slot give deterministic
four-choice questions without mutating source entries. Target/options remain
original immutable entries; outer/option lists are immutable snapshots.

Question identity includes grammar, level, original ID and version. A round has
at most10 unique targets from one level. Accept only the first valid answer for
the exact current question and one of its choices. Cannot advance unanswered or
with an earlier question ID. Each accepted matching target ID scores1, other
valid choices0. Incorrect entries and exported answer maps are immutable snapshots.
An empty round is complete with score0, not a percentage or mastered state.
A new round starts empty. Callers must still replace rounds on source/route change.

No grammar results are passed to vocabulary history/progress. No minutes, server
credit, mastery threshold, account cache or saved-success behavior is introduced.
Reviewed language coverage, grammar-specific persistence and learner acceptance
remain later work.
This increment does not complete issue13 or any Personal Alpha release gate.

## Verification

From apps/flutter_app:

```bash
flutter test test/features/quiz/grammar_quiz_test.dart
```

Ten synthetic core cases cover deterministic original choices/slots, insufficient
meaning diversity, duplicate patterns, invalid hidden inputs/limits, repeated
meaning targets, immutable lists/maps, first-answer/stale-advance behavior,
level/version identity, round bounds/empty state and ten-question scoring.
These tests do not modify or validate Pro's N4 content or certify language quality.
Local Dart/Flutter SDK unavailable: new tests/format/analyze/build UNRUN; require
new exact-head Actions. QA55/inventory153/diffcheck are separate checks. Parent
CI40868376520 exacte9f6adc/latestattempt1 all5/EVERYstep succeeded, including actual
restored-history journey and Windows persistent SDK/protected original-mismatch
markers; parent success is not new grammar or hosted learner proof.
