# Captured local quiz-history repository — Issue #13

VocabularyQuizHistoryRepository borrows an existing local attempt store under one
captured ready ReviewSession and a trusted runtime-readiness fence. This optional
library does not authenticate a caller or create a hosted endpoint. The existing
PersistentSupabaseRuntime can accept quizStore (default null) and create this
repository only after exact secret persistence and own-profile readiness.
Configured Windows startup now owns a quiz journal in its existing trusted
project directory; default preview still has no account/history source.

## Owner and publication boundary

save(attempt) and load() have no owner argument. The repository derives the owner
from its captured Auth session. Before storage and after every await, including
failed awaits, it requires that identical session object, current readiness and
an open operation drain. Any observed mismatch/getter failure permanently revokes
the wrapper. A fresh same-user login needs a fresh repository.

The concrete runtime factory captures the exact account.readyRuntime and
readySession plus its closing state. A refresh/profile barrier therefore revokes
an old wrapper even when the underlying SDK retains the same user/session object.
It uses the existing secure-persistence/profile gate; no Auth strategy changes.

Already accepted storage can finish after logout/close. The old result is then
rejected with a fixed session-changed error and cannot be published to the new
account. The original immutable event can remain on disk under its original
owner; a fresh same-owner repository can recover/replay it. A future UI must
retain that uncertain event for exact manual retry and must bind the entire quiz
round to one ready lifecycle rather than assigning a guest/old-user round later.

## Save, load and failure semantics

Simultaneous identical same-event saves share one future/dispatch. Registration
precedes dispatch so a reentrant store cannot launch a duplicate. Changed payload
under that active ID conflicts. Native storage handles later exact replay and
conflict after restart. A returned save record must match both the captured owner
and the complete original event before success is exposed.

load validates every record's owner before deduplication or sorting; mixed-owner
responses fail closed. It bounds input to10000 records, deduplicates identical
events, rejects changed-payload replay atomically and returns an immutable copied
list sorted by UTC completion time then event UUID. It computes no counters or
mastery and grants no study time/SRS/plan/server credit.

Known storage and replay errors retain their safe types while the session is
current. Unknown synchronous/asynchronous port errors become a fixed storage
failure without raw path/secret text. After revocation, session-changed failure
takes precedence over a late storage error. No false saved result is invented.

VocabularyQuizOperationDrain revokes new work synchronously and drains accepted
save/load futures before storage release. PersistentSupabaseRuntime.close now
awaits this drain alongside its existing Auth/study shutdown, retaining the prior
Auth policy. The caller still owns and closes the supplied store only after
runtime.close completes. Default null storage changes no existing behavior.

## Verification and next UI increment

Twenty new Flutter cases are authored. Fifteen wrap a real disposable native
journal with explicit TEST ONLY await/failure ports, exercising owner-derived
save/load, immutable ordered replay, mixed-owner and bound rejection, changed
returns, duplicate/reentrant dispatch, redacted failures/exact retry, A/B/A,
same-user replacement, readiness/getter failure and queued/in-flight shutdown.
Five use the actual pinned SDK with simulated HTTP/vault plus real quiz files:
persisted-secret/profile barriers, optional-null default, refresh replacement,
logout/same-user recovery and runtime drain before caller store release. No quiz
RPC, live JWT/RLS or hosted learner acceptance is claimed by those fixtures.

Parent78fbfae0 CI39484645098 latest attempt1 passed all five jobs/every required
step:634 Flutter tests including all13 native store cases, five Chrome, retained
native/process/SQL/wire gates and Web/Windows builds/artifacts. New tests and
source require new exact-head format/analyze/test/build evidence. No local SDK,
Flutter, QA or build ran; source/boundary review is not executable testing.
New native quiz-store Windows execution and injected file-write/flush faults
remain outstanding; the repository fault ports do not establish those results.

Parent0e33052b CI39668904464 latest attempt1 passed all five jobs/every required
step:654 Flutter tests including all20 captured-repository/SDK cases, five Chrome,
Web/Windows builds and retained native/SQL/process checks. This is fixture/disk
evidence, not hosted acceptance. The ownership increment below needs new CI.

## Configured Windows storage ownership

openWindowsStagingOwner acquires the existing review lease, then study and quiz
journals, before constructing the SDK/credential writer. The native quiz journal
uses its separate existing files/format in the same trusted project directory.
Construction failure unwinds acquired quiz/study/review handles through nested
finally blocks; corrupt/locked quiz storage fails startup rather than silently
falling back to guest history. Startup's existing fixed error UI redacts details.

PersistentAccountStartup and WindowsStagingOwner forward the optional
VocabularyQuizHistorySource capability. The runtime still captures the exact
ready session/runtime and owns no journal itself. Once owner.close starts it
offers no new history repository; it awaits runtime Auth/study/quiz drain before
closing quiz, study and review journals. A failed runtime drain retains all
journals, preserving the existing shutdown policy. Nested finally blocks attempt
remaining storage closes even if a storage close fails. No history is deleted.
Optional constructor storage remains backward compatible with existing owners.

Three additional actual-SDK/simulated-HTTP/vault/real-file tests cover owner
capability readiness/logout/same-owner replacement, duplicate close and a held
quiz write retaining all three leases until drain, successful reopen/recovery,
and an absent quiz capability with an unrelated caller-owned store left open.
These tests run on the existing Flutter job; they are not live Windows learner
or injected native close/open-failure evidence. Native startup failure cleanup
also has source review; no new fault-injection proof is claimed.

## Read-only history view

The optional source is forwarded by AccountStartupController only while active
and not closed. AccountStartupApp installs that borrowed capability alongside
the existing account runtime; the preview provider defaults null. The repository
provider requires a ready account/profile/runtime and rebuilds at every account
barrier. It never creates a store, SDK or simulated history by itself.

/quiz/history is linked from the quiz page. Reading is explicit through
Tải lịch sử; it shows loading, empty and fixed safe error states with manual
reload only. Each row displays the saved level, integer score/total and original
completion instant explicitly labeled UTC. No owner/event UUID, path, raw error,
mastery or server progress is displayed. List order is newest first according
to the existing repository ordering. Reload clears previous rows before dispatch.

The stateful panel is keyed by the captured repository identity. Account/profile
replacement or startup shutdown removes the old panel and its rows; late success
or failure cannot set state on a disposed panel. The existing repository also
fences the captured lifecycle after storage awaits. Route return starts empty and
requires another explicit read; no cross-account UI cache or background retry.

Eight widget cases are authored for preview/profile gates, explicit empty read,
held read/disabled duplicate dispatch/score, redaction and manual retry, late
success/same-owner replacement, late error/other-owner replacement, actual
startup source publication/exit revocation and320px/200-percent layout. Test ports
are explicitly simulated; existing disk/SDK ownership tests remain unchanged.
New format/analyze/widget/build evidence is pending exact-head Actions.

Parent09344fc5 CI39684530931 attempt1 passed allfive jobs/every required step,
657 Flutter tests, five Chrome and Web/Windows builds. This is component/fixture
evidence, not hosted learner acceptance. Local29 QA tests and whitespace passed;
new Flutter UI tests did not run locally because the SDK is absent.

## Explicit completed-round save

The quiz panel captures the optional ready repository when a round starts.
Login after a guest round never assigns that round to the new owner. Any
replacement of a previously captured ready repository hides that round's
answers/result/save status, fences stale actions and requires an explicit new
round. Same-user refresh/profile replacement is also a new lifecycle.

On advancing the final accepted answer, the configured round captures one
immutable local-v1 report with secure UUIDv4 and UTC completion time. Capture
failure is fixed-text, dispatches nothing and claims no save. Only the explicit
save button calls the captured repository. While waiting, save/restart/next-batch
actions cannot dispatch duplicates or replace that event. A transient/uncertain
failure exposes manual retry of the exact same immutable object, UUID, time and
answers; unknown errors are redacted. Success appears only after the existing
validated repository returns. No automatic retry or reconstructed new event.

Account barriers clear visible status. A late old-round operation may remain
durable under its original owner, but cannot publish to a different round,
session or disposed view. History can resolve that uncertainty after login.
Explicit restart or route exit discards only unsaved local view state; any
accepted original disk report is retained. No pending event is reassigned to a
fresh owner. Results are self-reported local quiz history, not study-time,
mastery, SRS, plan or server credit. No new hosted operation is introduced.

Nine tests are authored: one real UUID/UTC capture case and eight widget cases
using explicit Auth/profile/memory-storage/fixed-clock ports and an original N5
question. They cover save-to-history, disabled/stale duplicate actions, uncertain
commit and exact replay, guest-login fencing, late same/other-owner save results,
unfinished same-user replacement, capture failure and320px/200-percent text.
These UI ports do not prove real filesystem faults or hosted learner behavior;
the existing native store/repository/SDK tests remain unchanged.

Parent66d32e97 CI39698216596 attempt1 passed allfive jobs/every required step,
665 Flutter including all eight history-view widget cases, five Chrome and
Web/Windows builds. New save source/tests require their own exact-head CI.
Keep #13 open/#41 draft,
default preview and all14 hosted acceptance groups pending. No dependency,
workflow, wire/schema/RLS, live activation, deployment, merge or schedule change.

## History view captured read fence — 2026-10-28 UTC

History load now checks mounted state and the exact currently supplied repository
before any view mutation/storage call, after its await, and before error/finally
publication. Repository replacement invalidates an old retained load callback even
before the widget replacement frame; disposal makes it inert before setState or
provider access. Existing repository Auth/storage/drain guards remain authoritative
and accepted borrowed I/O is not cancelled or reassigned. No data write/credit,
mastery, retention, new SDK owner or default activation is introduced.

Two regression widgets retire the supplied repository before a frame or invoke
the callback after route disposal. Both require zero old storage reads/no widget
exception and a working fresh explicit load afterward. Original fixture bodies,
assertions and cleanup are unchanged. Parent fddf56f CI40752649494 attempt1 passed
all5/every step and retained Windows markers. New2 widgets/format/analyze/build
locally UNRUN: no Dart/Flutter SDK; QA46/inventory151/diffcheck pass separately.
Require own exact-head CI; TEST ONLY ports are not hosted learner evidence.


## Exact formatter correction — 2026-10-28

CI40757797643, exact93f62b8/latestattempt1, passed repo/AI/database/Windows
with every step successful. Flutter123062214330 stopped at strict formatting;
analyzer, two new history widgets/full tests and later Flutter checks were skipped,
not passed. The pinned formatter emits only a line-wrap change to the isCurrent
closure supplied to _HistoryPanel. Apply that exact diff; the resulting source
blob is debcacc647906c5b1077c5837a08f9ee455eaaf5, matching the logged prefix.
Reverse replacement reproduces the entire original source byte-for-byte.

Captured repository/mounted checks, all test bodies/assertions/deadlines/cleanup
and CI/security gates remain unchanged. Local QA46/inventory151/whitespace pass;
there is no local Dart/Flutter SDK, so new-head format/analyzer/history widgets/
build evidence must come from exact-head Actions. No new test is invented for a
layout-only fix. #13 stays open/#41 draft and all14 hosted release groups pending.

## Loaded local-history totals — 2026-10-28 UTC

History shows the number of saved rounds and original correct answers / all
answered questions only after an explicit successful load. Totals use exactly the
validated owner-bound repository snapshot, including its existing event dedup;
repeated practice rounds each contribute their original score. They are not
unique vocabulary counts, current-content correctness, study time or mastery.
No extra source/store/network read, write or persistent derived counter is added.
Empty history shows0 rounds/0of0; loading, failure and owner replacement remove
the prior summary through the same existing captured-repository view lifecycle.
Two separate text rows wrap naturally with the existing narrow/large-text layout.

One added widget checks duplicate events become2 rounds/1of2, no summary before
load, failure redaction/removal, empty reload0of0 and logout removal with exact
read counts. All original widget bodies/assertions/cleanup remain. Parent78cab24
CI40778521899 attempt1 passed all5/every step, including narrow context fix and
retained Windows markers. New widget/format/analyze/build locally UNRUN(no SDK);
QA46/inventory151/diffcheck pass separately. Require own exact-head CI. TEST ONLY
Auth/read ports do not establish hosted learner acceptance or full sync.


## View-only history level filter — 2026-10-28

The history panel offers All/N5/N4, initially All. Both displayed round rows and
correct/answer totals use the same selected subset of the already validated,
owner-bound, deduplicated loaded snapshot. Empty selected-level history shows0
rounds/0of0 with an explicit message; it is not a storage error or invented result.
Duplicate events still deduplicate before any view filtering. Original attempts,
UTC ordering, score semantics and all-level default totals remain unchanged.

Selection may precede explicit load and never triggers storage/network/content
reads or writes. Explicit reload preserves this view selection and filters the
fresh snapshot. Owner/repository/route replacement creates a fresh panel with All
and no loaded totals. Selection checks mounted/current repository before setState;
no account/profile/preview level is changed. Existing load guards/drain/error
redaction and no mastery/time/SRS credit rules remain intact.

Two new widgets use TEST ONLY structurally valid N5/N4 reports to verify mixed-
level duplicate totals/rows and roundtrip filters with exactly one read; pre-load
selection/empty selected level, explicit fresh reload and logout/new-owner All
reset with exact read counts. Store append remains an unconditional test failure.
All previous widget bodies/assertions/cleanup remain. Local QA46/inventory151/
whitespace pass; new Flutter/format/analyze/build locally UNRUN(noSDK), require
exact-head CI. Parent83f26c6 CI40782950867/latestattempt1 all5/EVERYstep SUCCESS.
Hosted ownership/sync/mastery/learner proof remains pending; #13open/#41draft.
