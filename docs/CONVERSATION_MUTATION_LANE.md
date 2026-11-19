# Captured owner conversation mutation lane — Issue #17

ConversationMutationLane serializes start/turn/finish within one caller-owned ready
generation using the actual CapturedConversationMutation primitive and strict DTOs.
Host must keep one lane for all its conversation mutations; separate lane objects,
processes or devices are not coordinated by this in-memory component. Construction
sends nothing. It owns/closes no SDK/HTTP/vault/journal and activates no provider/UI.

Before supplied Auth/readiness getters, factories or port code can reenter, a
singleflight reservation is installed. The operation+lowercase event UUID key is
bound to the exact serialized scalar wire. A reconstructed identical request
reuses its original mutation/cached accepted result. Changed text, scenario,
level, session or wire UUID spelling under that key returns fixed SYNC_CONFLICT
without dispatch. UUID keys fold case solely to prevent a case-only bypass;
conservative wire equality is not a server canonicalization/receipt proof.
Same UUID in different operations remains separately scoped per frozen contract.

After any accepted operation failure or timeout, its key stays reserved, including
after the injected accepted future drains. No new event ID, different operation
or older cached replay can bypass unresolved work. Only explicit same-event,
same-wire retry may resolve it successfully. There is no automatic retry, fresh
ID substitution, optimistic discard or reset/abandon action. isBusy distinguishes
executing/held injected work from hasUnresolvedMutation. A response timeout is not
remote rollback; eventual HTTP port must also fence ignored-abort actual I/O.

Retain at most100 mutation slots by default; trusted host may choose1..1000.
At capacity a new event gets nonretryable local RATE_LIMITED, without eviction;
existing replay still works. This is a local memory bound, not backend quota.
Request text/results live only in the retained lane/borrowed port; no transcript
or receipt file, logging, UUID generator or restart reconstruction is introduced.

Every dispatch/publication/replay checks exact captured ReviewSession identity and
owner readiness. Observed loss/getter error/unauthorized permanently revokes all
retained mutations and clears publication/registry. A late held future remains
observable as busy until it settles; it cannot publish or revive after A-B-A.
Caller must revoke synchronously on every lifecycle barrier, including a barrier
that later looks ready again. Clearing this lane on logout is not a guarantee of
server cancellation/deletion, nor permission to recreate uncertain work elsewhere.

Thirteen pure injected-port test cases cover typed operation/cache replay;
cross-operation held work; changed body/scenario/level/session/UUID case; scoped
keys; timeout late success/error and uncertainty after drain; provider failure/
old-cache bypass; capacity/no eviction; port+getter reentry; revoked A-B-A late
success/error; safe readiness/unauthorized invalidation; same-user replacement/
explicit revoke/invalid limits. Execution evidence is in PROJECT_STATUS/PR.

This lane does not enforce conversation start/turn/finish progression, message
sequence correlation, scenario ownership, signature/JWT verification, durable
server receipts/restart/multi-device recovery or approved hosted provider behavior.
Next integrate session progression/correlation and an owned fixed-endpoint HTTP
port, then UI/recovery evidence. Server remains auth/receipt authority. Parent
15f0eb1 CI40077403342 allfive/every step passed,952 Flutter/5 Chrome; new exact-head
full CI is required. Main/staging AI stay off and all14 hosted release gates remain
pending. No Auth strategy/provider/voice/collection/spend/release approval follows.


## Read-only accepted-completion comparison — 2026-11-19

inspectAcceptedCompletion(completion, store: ownedStore) is a bounded prerequisite
for a future normal-success acknowledgement path. It accepts only an opaque
original-bound completion on the identical Auth port/current generation. The lane
must be idle with no unresolved event/actual held I/O; the existing store must be
open and contain the command's project/owner scope. The complete operation/event/
request fingerprint and the entire typed response encoding must match the lane's
already accepted result. Changes to response text, IDs, session, scores/arrays,
request text/scenario/session or wire UUID spelling remain conservative mismatches.

A private slot retains only a reference to its existing typed accepted result;
no duplicate payload, additional file, logs, new cache owner or collection. This
reference is installed only after successful mutation/currentness checks and cleared
on revoke. Receipt-reconciled synthetic cache slots are explicitly excluded, even
after exact cached replay, so they cannot masquerade as observed HTTP success.
The existing bounded slot count/lifetimes and mutation/retry/cache results remain.

Inspection reserves the lane before supplied callbacks, redacts nested reads and
fences nested submits, then rechecks completion/lane currentness followed by only
local terminal/slot/result/store guards. Valid reads do not alter pending/result
state, dispatch, read/clear metadata or perform storage I/O. Observed lifecycle loss
can still revoke the lane under its existing policy. Returning a snapshot is NOT
transcript applicability, hosted provenance, confirmed clear, application proof or
permission to replay/send. No session/owner/default caller is wired yet.

Twenty-four TEST ONLY regressions cover all3operations exact match/cache/no-I/O,
changed full originals sharing metadata, changed typed results, foreign Auth/store,
refresh/account/revoke/reader/store retirement, missing/unresolved slots, timeout/
late success-error drain, final callback reentry/reader/store/refresh, and exclusion
of receipt-reconciled cached replay. Exact local evidence is in PROJECT_STATUS.
