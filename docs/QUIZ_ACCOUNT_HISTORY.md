# Captured local quiz-history repository — Issue #13

VocabularyQuizHistoryRepository borrows an existing local attempt store under one
captured ready ReviewSession and a trusted runtime-readiness fence. This optional
library does not authenticate a caller or create a hosted endpoint. The existing
PersistentSupabaseRuntime can accept quizStore (default null) and create this
repository only after exact secret persistence and own-profile readiness.
No startup code opens a quiz journal yet; /quiz remains process-local.

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

After this repository passes CI, add owned store opening/close forwarding,
providers and explicit save/history UI with loading/safe errors/manual retry,
same-round identity and old-owner clearing. Do not publish the native store as
available merely because this optional factory exists. Keep #13 open/#41 draft,
default preview and all14 hosted acceptance groups pending. No dependency,
workflow, wire/schema/RLS, live activation, deployment, merge or schedule change.
