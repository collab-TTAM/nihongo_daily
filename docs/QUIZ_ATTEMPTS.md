# Vocabulary quiz attempt snapshots and history — Issue #13

## Delivery boundary

The rules below were recorded and separately reviewed in #13 before coding.
This increment supplies immutable pure-Dart models and a deterministic projection
for future owner-bound history. The public /quiz route still keeps only its
current local round. It does not store a result or publish account history.
An opt-in native library is described in NATIVE_QUIZ_HISTORY.md. The optional
captured-ready-session repository is described in QUIZ_ACCOUNT_HISTORY.md;
UI save/recovery and hosted transport remain pending. The models do not authorize their caller.

## Local format version1

VocabularyQuizAttempt.capture accepts a nonempty fully advanced1..10-question
round from one level, plus one caller-supplied canonical UUID and explicit UTC
completion time. It snapshots the accepted first answers through a copied,
unmodifiable map. Targets, content versions and exact displayed choice IDs remain
original. A selected ID must be one of four distinct displayed IDs and the target
must also be displayed. Score is derived from selected/target equality.

Strict toJson/fromJson fields:

| Object | Exact fields |
| --- | --- |
| Attempt | format_version, event_id, level, completed_at, answers |
| Answer | item_id, content_version, selected_id, choices |
| Stored envelope | Validated ownerId plus immutable attempt; no wire/API shape yet |

Only N5/N4; format_version is integer1, content version1..2147483647,
canonical lowercase UUIDs, canonical UTC ISO text in2000..2100. Reject unknown or
missing keys, incorrect types, invalid/normalized date strings, duplicate target
IDs and round/choice bounds. Deep-copy/freeze collections. Payload includes no
owner, credential, response text, supplied score, timer, SRS or mastery field.
The owner-free local format is separate from frozen contracts/v0.1; no public
endpoint, SQL schema or shared wire contract changes.

## Owner and replay rules

A future session-bound repository must derive owner identity from its captured
ready Auth session and fence logout/replacement around every await. A validated
owner string in a model is not authentication. The projection requires one
explicit owner and rejects any foreign-owner record before filtering by level or
deduplicating. A future storage read returning mixed owners must fail closed.

History is bounded to10000 records. An event ID with exactly the same canonical
payload counts once. A changed time, level, answer or displayed-choice order
under the same event ID throws VocabularyQuizHistoryConflict before producing
any counters. No mutable shared counters or partial aggregation are committed.

## Current-source practice and review

Events sort by UTC completion time then canonical event UUID, independent of
input order. Historical totals count unique selected-level attempts, answers and
canonical correct choices; these remain client reports, not verified attention.

Current-item summaries resolve targets through the existing generated quiz with
matching content version and exact displayed choice order. Unknown, retired,
modified-version or mismatched-choice reports remain in historical totals but
cannot create a current recommendation or practiced-current-item count. The
projection never invents curriculum items or merges N5/N4 summaries.

Latest wrong answer makes that current item a review candidate. Later correct
answer clears the candidate; historical wrong counts remain. Another later wrong
answer restores it. Rank by cumulative wrong count descending, last completion
time descending, then canonical item UUID. Equal-time events use event UUID as a
deterministic tie-break only; it is not a trusted server ordering.

Practice/answers/correct counts are distinct from time studied or mastery.
There is no mastery threshold/count, MASTERED state, SRS scheduling write,
timer/plan/profile update or server study credit. A future authoritative service
must validate the owner, canonical question/choices and idempotency itself.

## Verification

Exact parent cd9e4450 CI39474839847 attempt1 completed allfive jobs/every required
step:605 Flutter/five actual Chrome, format/analyze, retained SQL/SDK/native/process
checks, configured/preview Windows and Web release builds/artifacts. SDK readiness
correction and all19 public-quiz cases passed. This is parent evidence.

New16 tests cover both actual canonical levels/deep immutable snapshots, incomplete/
empty/mixed rounds, unknown/type/date/ID/version/choice/bounds rejection, duplicate
target, owner isolation before dedup/level filter, identical replay, changed-event
conflict, repeated wrong/correct/wrong transitions, stable equal-time order,
recommendation ranking, stale/unknown/source-choice mismatch and empty history.
Read-only answer map snapshots are checked as well.

Execution environment remains unavailable. No local Dart/Flutter/format/analyze,
Python QA/render or build ran for this increment; source/rule/assertion review
and canonical UUID inventory through JavaScript are not executable Dart tests.
Existing new exact-head Actions must verify all relevant gates. No prior Flutter
metadata automatic-review rejection retry/bypass. QA adds a baseline anchor;
all14 hosted groups stay pending. Keep #13 open/#41 draft/default preview.

## Next

After native-store current-head checks pass, add a captured-ready-session
repository and explicit save/history UI, retaining pending failures and fencing
old sessions. The opt-in store protocol/tests and remaining validation are in
NATIVE_QUIZ_HISTORY.md. Server sync
and authoritative validation require their own reviewed contract and ACL tests.
Do not claim route persistence or progress/mastery until its flow is implemented
and verified. No live configuration, merge or deployment in this increment.

### Initial model CI and exact formatter diagnostics

a9c14f22 CI39477153830 attempt1 passed all database/repo/AI/Windows steps.
Flutter stopped at formatting vocabulary_quiz_history_test.dart; new16 tests,
analysis and downstream Flutter checks were skipped.

The existing strict formatter step now prints its pinned-SDK diff on failure
from the disposable runner checkout and still fails. Its exact name, SDK3.35.4,
clean-check behavior and downstream gates stay unchanged; no source auto-push.
Apply the observed test diff before claiming formatting or model test success.
No local execution environment is available. Public route persistence is pending.

### SDK-produced format patch applied

Diagnostic fef1e081 CI39478685828 attempt1 kept the format gate failing and
emitted three exact test-file hunks. They are applied without changing cases,
assertions, string literals or model behavior. The resulting independently
computed Git blob is ebaa415b7a9905d7abcecf11fa249adf9dc76ccc, matching the SDK's
diff target. No other Dart source changes. New exact-head CI still must run
analysis, all16 model tests and downstream platform checks before acceptance.

### Strict empty-fixture element types

At1d963615 CI39479261449 attempt1 the strict formatter passed181 files/zero
changes; database/repo/AI/Windows passed every step. Analyzer found only two
uninferred empty list literals in malformed answers/choices fixtures. Explicit
Object? element types retain those empty rejection inputs, all16 cases and every
assertion. Production model/quiz, strict analysis and CI gates are unchanged.
Full model/test/downstream execution was skipped and needs the new exact head.

### Verified models and opt-in native storage

Exact43094ac2 CI39480610637 latest attempt1 completed all five jobs/every required
step:621 Flutter tests (all16 model cases), five Chrome, Web/Windows builds and
retained native/SQL/process gates. The two fixture annotations are verified.
A separate opt-in native quiz store and real-file/process tests are now authored;
see NATIVE_QUIZ_HISTORY.md. New-source Actions are still required. Public /quiz
is not wired to it; no saved history/session authorization/mastery is claimed.

### Captured-session repository

Parent78fbfae0 CI39484645098 latest attempt1 passed all five jobs/every step,
634 Flutter/five Chrome/Web/Windows, including all13 native store tests. A new
owner-derived save/load repository and optional runtime factory are now authored
with20 lifecycle/SDK/disk tests; see QUIZ_ACCOUNT_HISTORY.md. New exact-head
checks remain required. No startup journal/UI persistence is activated.
