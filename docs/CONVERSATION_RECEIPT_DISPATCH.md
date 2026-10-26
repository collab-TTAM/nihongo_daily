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
