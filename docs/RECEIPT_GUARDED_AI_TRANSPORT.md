# Receipt-guarded owned transport — Issue #17

ReceiptGuardedAiTransport composes the existing first-attempt receipt barrier with
an owned text/conversation/scenario transport. It implements the same runtime
owner interfaces, so an explicitly supplied AiTextRuntimeOwner transport factory
can return it. No app/default factory now does so. Ownership of inner transport
transfers on successful construction; the secure receipt store remains borrowed.
The factory must supply the exact verified session, canonical trusted store scope
and vault/profile/runtime-generation readiness. The host must bind the SAME trusted
project to store and inner transport; the generic inner interface exposes no URL
for this decorator to authenticate. No learner endpoint/key input.

Every mutation is strictly decoded through its existing frozen request type.
The new immutable scalar body preserves exact UUID spelling/text/code points and
cannot change while a receipt write is pending. The matching typed reference
contains only project/owner/operation/event, never original text/token/response.
Unknown operations/invalid bodies fail before storage or HTTP. The adapter makes
ONE mutation attempt in its lifetime, registered before supplied code can reenter.
Preexisting metadata, repeated calls or another gate using the same store are
blocked; no new event, automatic retry, pending eviction or receipt clear.

Only a confirmed secure-store reserve precedes underlying invoke. Both the barrier
and decorator check exact captured Auth identity and host readiness; the underlying
SDK transport must independently recheck credentials immediately before HTTP.
Revocation retires the barrier synchronously and revokes/aborts inner transport.
close waits actual barrier storage/callback settlement BEFORE closing inner,
including late errors; repeated close shares completion. Cleanup failure becomes a
fixed internal error, never permission for a fresh runtime lease. Metadata is
preserved and borrowed store is neither closed nor erased by this decorator.

The existing runtime owner requires no changed code: invalidation calls revoke,
then tracks decorator close as its retirement drain. New generation acquisition is
blocked while that actual drain is pending. Tests use the real runtime owner and
conversation session around TEST ONLY storage/transport ports; they do not prove
SDK cancellation, Windows-backed runtime composition or hosted learner recovery.
Scenario reads/tutor/correction delegate without receipt writes and retain their
original own captured-transport guards. The adapter grants no server authorization.

Twelve cases cover all three exact typed wires and held-write body mutation,
storage failure, preexisting identical receipt, actual owner invalidation with
late HTTP success/error, held-storage retirement before HTTP, unchanged text/read
forwarding, cleanup error and invalid request/operation. The original18 barrier
and11 store cases are retained. Observed execution is in PROJECT_STATUS/PR41.

Parent26f5cfe CI40253359051 latest attempt1 passed all5 jobs/every required step;
the preceding first-attempt component is now verified by full CI. New exact-head
CI remains required. No default AI/provider/Auth strategy/SQL/RLS/contract/CI/
dependency/content/Pro change. All14 hosted release groups remain pending.

Limitations: one pending mutation blocks all later mutations until authenticated
receipt lookup/verified conditional release exists. Existing memory-only session
retry policy is not broadened; this decorator does not permit uncertain replay.
Host must exclude external writers/same-user competing processes; no cross-process
CAS, secure multi-process ownership or metadata-derived dispatch grant is claimed.
Next explicitly compose store creation/close/sign-out clear with Windows lifecycle,
exercise actual SDK/runtime storage failure/refresh/account transitions, and add
authenticated receipt reconciliation before enabling this in learner composition.
