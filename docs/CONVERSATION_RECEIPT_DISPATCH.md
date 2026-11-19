# First-attempt receipt dispatch barrier — Issue #17

ConversationReceiptDispatch is a caller-owned, optional single-command component.
It borrows an existing secure receipt store, immutable metadata reference, exact
ReviewSession/Auth hint, host vault/profile/runtime-generation readiness getter
and typed dispatch closure bound to the ORIGINAL immutable command/captured
credentials. The closure/actual transport must still validate identity immediately
before HTTP and decode its response. Local hints are not hosted JWT authorization.
No default/route/session factory constructs this gate yet.

submit claims its gate AND the borrowed store identity before any external getter
or I/O. A weak isolate-local store claim is terminal unless the explicit verified
application release below succeeds; failure/close alone never releases it. Two
gates sharing one store cannot race two empty reads into two dispatches.
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


## Explicit applied-completion release primitive — 2026-11-19

A gate may opt into later release by capturing an immutable `originalCommand`
at construction, with the exact same metadata reference. Legacy gates without
that full original remain terminal. `releaseAppliedCompletion` requires an opaque
single-use `CapturedConversationApplication` from the captured session's confirmed
clear AND atomic transcript publication. Receipt reads, preview, direct metadata
clear, missing/UNKNOWN and apply-success booleans cannot construct that proof.

Release checks the exact active gate/store claim, actual storage/dispatch drain,
non-retired gate and fresh readiness. The proof checks exact Auth/store identity,
fresh reader/session currentness, unchanged applied snapshot, idle/resolved lane,
open store and final local reader/session retirement flags after callbacks. The
gate compares the entire encoded original, including exact request text/session/
scenario/event/project/owner, before synchronously retiring itself and clearing
only its own weak claim. There is no storage effect, await or external callback
between the final proof/identity checks and release. Nested release is excluded;
consumed/stale/foreign proofs cannot free another claim. The old gate never sends
again; a new explicit gate still reads/reserves storage before one dispatch.

The transport binding landed at 2026-11-19 12:52 UTC. The owner application
path is now also wired: `AiTextRuntimeOwner.applyRetainedConversationCompletion`
selects the exact lease's existing conversation, receipt reader and release-capable
transport. It either reuses the same still-unconsumed application proof or applies
the exact completion through the retained session, then consumes that proof through
the same `ReceiptGuardedAiTransport`. Epoch, reader, session and transport identity
are checked before and after; the creation/drain reservation spans storage I/O and
proof consumption. `ReceiptAiRuntimeOwner` and `AccountReceiptAiRuntime` expose
the explicit host action. If release is not yet possible, the method returns false
without inventing success or retry authority; the same owner may explicitly retry
while the proof remains current.

The owner-level TEST ONLY regression verifies a failed first dispatch, rejects a
completion from a foreign reader, applies the same-reader completed receipt, clears
the exact pending metadata, consumes the proof and permits exactly one next turn.
This is component/owner wiring only: no default route or learner UI activation,
successful-HTTP acknowledgement, hosted Auth/JWT/RLS/provider proof, native SDK
learner journey or cross-process store ownership. All14 hosted release groups
remain pending; default learner AI stays off.


Update 2026-11-19 12:52 UTC: ReceiptGuardedAiTransport now passes the full original
and exposes explicit proof consumption through its exact retained gate, with
release reentry fencing and a final transport lifecycle check before resetting
its attempt flag. The owner/SDK application action remains unwired and defaults
unchanged; configured owner next mutation is still blocked. See the same-transport
section in AI_CONVERSATION_RUNTIME.md for observed tests and remaining boundaries.
