# Captured local quiz-history repository — Issue #13

VocabularyQuizHistoryRepository borrows an existing local attempt store under one
captured ready ReviewSession and a trusted runtime-readiness fence. This optional
library does not authenticate a caller or create a hosted endpoint. The existing
PersistentSupabaseRuntime can accept quizStore (default null) and create this
repository only after exact secret persistence and own-profile readiness.
Configured Windows startup now owns a quiz journal in its existing trusted
project directory; default preview and public /quiz remain process-local.

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

Next add providers and explicit save/history UI with safe loading/error/manual
retry, same-round identity and old-owner clearing. Keep #13 open/#41 draft,
default preview and all14 hosted acceptance groups pending. No dependency,
workflow, wire/schema/RLS, live activation, deployment, merge or schedule change.
