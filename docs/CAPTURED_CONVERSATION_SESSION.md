# Captured conversation session progression — Issue #17

CapturedConversationSession owns one private ConversationMutationLane for one
conversation and one captured ready-owner generation. Trusted host supplies the
borrowed Auth/port; construction sends nothing. start/turn/finish are explicit
typed calls with caller-owned immutable event IDs. No ID generator, reset,
automatic retry, SDK/HTTP port, provider or UI activation is installed.

An accepted start publishes the server session ID and first assistant message.
Only matching-session turns/finish are allowed afterward (UUID identity is case
insensitive; exact supplied wire spelling remains unchanged). A different start
event, pre-start turn/finish, foreign session or any turn/start after accepted
finish rejects locally with fixed SYNC_CONFLICT, without dispatch. Only the
identical accepted finish may replay after completion. Changed replay wire is
still rejected by the lane. These are local view rules, not authorization.

One immutable snapshot contains notStarted/active/finished/revoked phase, server
session ID, assistant messages and optional finish summary. Each newly accepted
turn must have a strictly greater sequence and a previously unseen assistant
message UUID (case insensitive). Gaps are allowed: frozen v0.1 does not promise
consecutive assistant numbers, and user messages also consume server slots.
No invented +1/+2 rule or changed wire schema. The turn response has no session
ID; its association is the captured request/port, not independent response proof.
Server must validate owner, scenario, receipts, message IDs and sequence context.

Accepted start/turn replay reuses the lane result without resetting or appending
the projection; older replay after later turns cannot roll back progress. Operation
scopes remain separate even if their event UUIDs match. Summary/reference/error
lists retain the strict response models; empty lists stay empty and no score,
recommendation, elapsed minute, SRS/mastery/progress write is derived.

Failure/timeout keeps the existing snapshot and lane's unresolved same-event
reservation, including after the injected future drains. Local busy and unresolved
are separate. Explicit identical retry alone may advance on accepted success;
new-event substitution, older cache replay or finish cannot bypass uncertainty.
A duplicate/backward new sequence or repeated message UUID permanently revokes
the entire session and clears its projection. The lane may already have accepted
that response, so retry cannot repair it and a fresh event must not bypass it.
Recovery/reconciliation with server authority remains a later integration step.

Readiness/Auth checks protect each operation, publication, replay and snapshot
read. Observed readiness loss, getter failure, different ReviewSession identity
(even same user) or unauthorized failure permanently revokes the session.
The host must also revoke synchronously on every lifecycle barrier, including
transient refresh/A-B-A barriers that later look ready again. Revocation clears
retained projection/keys; actual held work stays observable as busy until its
injected future settles. It does not close borrowed resources/cancel remote work.
Previously returned immutable snapshots cannot be erased from callers; hosts
must remove old views/callbacks and not render retained copies after revocation.

Singleflight reserves before external getter/port reentry. A nested availability
read while readiness is still being checked returns a redacted revoked snapshot
without revoking the outer healthy session. Nested mutation is pending; it cannot
dispatch. The private bounded lane (default100, trusted1..1000 slots) limits all
retained messages/events without eviction. Capacity failure never silently
finishes or forgets history. A long conversation can exhaust this local bound;
no automatic replacement session is authorized. Separate instances/devices/
processes are not serialized or reconciled by this in-memory component.

Twenty pure injected-port cases cover progression/exact wire/session identity,
invalid lifecycle calls, replay without rollback, changed wire, operation-scoped
IDs, duplicate/backward sequence and message UUID rejection, every operation's
uncertain late success/error and explicit retry, provider/malformed failures,
port/readiness reentry, A-B-A late responses/drain, readiness/getter/same-user/401
revocation and capacity. Observed execution is recorded in PROJECT_STATUS/PR.
Pure tests are not SDK/HTTP/receipt/durable restart/hosted learner/voice evidence.

Parent c222d53 CI40081353423 exact latest attempt1 passed allfive jobs/every
required step,965 Flutter (all13 lane cases) and five Chrome tests. New full CI
must verify this increment. Next add owned fixed-endpoint SDK/HTTP and actual
session lifecycle/recovery tests before conversation UI. Main/staging AI stay
off; all14 hosted release groups and provider/voice/collection/spend/human gates
remain pending. No Auth strategy/provider/release permission follows.
