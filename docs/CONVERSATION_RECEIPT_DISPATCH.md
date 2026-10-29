# First-attempt receipt dispatch barrier — Issue #17

ConversationReceiptDispatch is a caller-owned, optional single-command component.
It borrows an existing secure receipt store, immutable metadata reference, exact
ReviewSession/Auth hint, host vault/profile/runtime-generation readiness getter
and typed dispatch closure bound to the ORIGINAL immutable command/captured
credentials. The closure/actual transport must still validate identity immediately
before HTTP and decode its response. Local hints are not hosted JWT authorization.
No default/route/session factory constructs this gate yet.

submit claims its gate AND the borrowed store identity before any external getter
or I/O. A weak isolate-local store claim is terminal, including after failure or
close; two gates sharing one store cannot race two empty reads into two dispatches.
This is not cross-process ownership/CAS. A new store/process must read storage and
reject ANY preexisting metadata, even the same event/reference. A reference is
neither the original command nor proof that a provider was never called.

Fresh captured identity and readiness checks surround read/reserve/dispatch.
Only initially empty storage and a confirmed reserve can precede one explicit
callback. Storage/readiness/identity failure prevents sending. The same gate never
retries, even after success or preflight failure. There is no timeout that releases
actual work, new ID generation, metadata deletion or implicit provider replay.
Existing session retry policy is unchanged; this component does not authorize
using it after restart or uncertainty.

revoke retires immediately. close revokes synchronously then waits for actual
storage/callback completion, including errors. The drain promise is installed
before external readiness code, so reentrant close cannot return early. Late
success/error is consumed and cannot publish after retirement. Raw errors become
fixed typed errors with no input/secret details. Borrowed store remains open and
pending metadata preserved: the lifecycle owner must order its eventual close or
sign-out clear after actual drain. Failed storage writes can be ambiguous and are
never turned into success/retry authority.

18 new TEST ONLY cases cover persistence-before-dispatch, terminal second call,
identical/different old metadata, read/write failure, late write under revoke/
readiness/same-account hint/other-account/A-B-A, actual wire drain late success/error,
reentrant readiness-close/submit, private getter/HTTP errors, foreign captured owner
and two gates borrowing the same store. Existing 11 store cases are retained.
Pure harness results and new-head CI are recorded in PROJECT_STATUS/PR41. These
ports are not actual Windows/Auth/provider/restart learner proof.

Parent69af2f1 CI40248729565 latest attempt1 all five jobs/every required step passed;
Windows121335801623 log confirms the actual receipt Dart/native process
metadata isolation/reopen/conflict/clear marker. That verifies the earlier bridge,
not this new gate or learner restoration. All14 hosted release groups remain open.

Next compose the barrier with captured runtime/real I/O drain and validate app
storage-failure/logout/refresh cases; add authenticated receipt lookup and verified
conditional release before permitting later commands. The single pending slot
currently blocks the next command until reconciliation exists. Current learner
route remains memory-only, AI off/default unavailable. No frozen API/SQL/RLS/Auth
strategy/provider/collection/spend/content/Pro/default/CI/dependency change.

## Final readiness identity at persistence boundaries — 2026-10-29 UTC

ConversationReceiptDispatch now rechecks exact captured Auth session identity
AFTER the final supplied readiness callback, before accepting each lifecycle
check. The callback could previously return true while replacing even the same
user's session after the last identity read. That could allow an old gate to
start storage, reserve metadata, invoke dispatch or publish an old response.
The existing terminal revoke/error behavior now catches that replacement at the
same check. The store/gate claims still precede callbacks; no new owner/slot,
I/O, retry, cleanup or cancellation policy is introduced.

Four TEST ONLY cases replace the session at the final callback before read,
before reserve, before dispatch and after response (readiness calls2/4/6/8).
They require fixed unauthorized, exact0/1 wires and exact backend call sequences.
Before reservation, no metadata is added; after reservation, exact original
metadata survives close. Returning the old session cannot retry through either
the same gate or a fresh gate on that store. No clear occurs and the borrowed
store remains open. All original cases/assertions/deadlines remain byte-identical.
This is injected Auth/storage/dispatch evidence, not hosted or native-file proof.

Parent8393149 CI40816845575/latestattempt1 passed all5 jobs/EVERYstep/no skips;
Windows123259855433 required persistent vault/same SDK/profile/receipt marker
observed. New4/formatter/analyzer/Flutter/builds locally UNRUN (no SDK); require
new exact-head Actions. QA46/inventory152/whitespace and separate boundary/count/
metadata/terminal/preservation review are recorded in PR41. Parent success is not
new-head validation or hosted learner acceptance. Learner AI stays off/memory-only,
single pending mutation blocking; trustedroot/backend/captured storage lifecycle/
durable uncertainty/authenticated conditional application-release/retentionapproval
and all14 hosted release groups remain outstanding. No default, Pro/content,
Auth strategy/provider/API/RLS/collection/retention/security-policy change.
