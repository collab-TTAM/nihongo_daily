# Private conversation reconciliation SQL — Issue #31

Migration `20261022161500_ai_conversation_reconciliation.sql` is an undeployed SQL
component. It provides lookup-only saved correlation/context and atomic completion
of a recovered original result. It does not install a provider lookup verifier,
runtime recovery port, endpoint or default; the existing runtime still fails closed
on pending. Never wire an unverified learner/model/legacy PendingRecovery result
straight to this helper. No provider selection, strategy, paid call or new learner
data category is introduced; the key already exists in ProviderInput.idempotencyKey.

## Lookup only, no new authority

`private.ai_conversation_recovery_lookup(uuid,text,jsonb)` validates the full original
request and looks up only that verified owner's operation/client_event_id. Immutable
request changes conflict. Missing returns only missing; completed returns only the
original response before active profile/scenario/session checks. The future runtime
must still apply the original strict response schema on replay.

For an existing atomic pending reservation, return exactly kind, correlation and
saved context. Correlation contains the original server receipt_id, user_id,
operation, canonical client_event_id and the existing canonical
`user_id/operation/client_event_id` idempotency_key. Original request JSON remains
immutable, including UUID casing; the key uses canonical UUIDs just like AiService.
Saved context is returned unchanged, even if current content has changed. Lookup
never rebuilds the provider's original context from a later source snapshot.

The helper is STABLE/invoker/empty search_path, so all its reads use one statement
snapshot. It does not take a dispatch lock, create a receipt/reservation, renew a
claim, expose a token or release a slot. Concurrent uncommitted completion remains
invisible; after commit, a fresh statement sees the completed original result.
Legacy pending without a saved atomic reservation returns only pending, with no
fabricated context/correlation. Missing/legacy/unknown never permits redispatch.

## Bound atomic reconciliation

`private.ai_conversation_reconcile(uuid,text,jsonb,uuid,text,jsonb,jsonb)` takes the
verified owner, operation, original request, captured receipt UUID/idempotency key,
original saved context and externally verified provider response. It validates
request and correlation bounds (key<=128 characters/context<=64KiB UTF-8), acquires
the same owner transaction advisory lock and locks the exact receipt/reservation.
Require exact immutable request, owned receipt UUID, derived full canonical key and
saved context. Cross-owner/missing receipt is NOT_FOUND; borrowed receipt/key is
FORBIDDEN; changed original request/context is SYNC_CONFLICT. No caller can supply
a new reservation, context, sequence or server identity to replace saved values.

The narrow service-only SECURITY DEFINER/empty-search-path helper reads the original
dispatch token ONLY inside PostgreSQL, then calls the existing
[validated completion transaction](AI_CONVERSATION_COMPLETION.md). The token never
appears in a returned value. Existing completion rechecks active source/profile/
owned session/transcript/IDs/slots, strict response/audio/refs and atomically writes
public state, original receipt and guarded release. Completed identical replay
returns original before active checks; changed result conflicts. Storage failure
rolls back the entire operation, including session closure/scores/summary. Duplicate
reconciliation or original-worker completion races serialize to one original result.
No new/replacement token, claim, receipt, expiry/delete/reset/takeover is introduced.

Clients/PUBLIC cannot execute either helper; table grants and RLS are unchanged.
Service_role already has access to the original claims and completion capability;
this narrow helper keeps that capability internal rather than granting client or
pending-caller token access. Direct reservation UPDATE/DELETE/TRUNCATE/pre-released
INSERT remain denied. Static fully qualified SQL, fixed controlled errors and no
SQL/credential/token/context logs preserve the existing boundary. Future driver
code must redact unknown errors and require confirmed COMMIT before success.

## What SQL does not prove

Stored correlation is a database identity binding, not evidence of a genuine
upstream result. Before invoking reconciliation, a trusted lookup-only provider
adapter must authenticate its upstream, validate stable owner/operation/event/key,
original immutable request/provider context and result association. It must not
create a provider request or reinterpret unknown/not-found as permission to retry.
Do not treat a learner UUID, echoed JSON tuple, SQL role or synthetic result as that
proof. SQL cannot authenticate a provider transport or infer whether dispatch occurred.

After an acquire COMMIT whose delivery was lost, a pending reservation may have no
provider request at all. Absence remains pending; never renew or dispatch it. After
completion COMMIT delivery loss, a fresh lookup returns original completion. Future
recovery must capture/freeze the lookup context/key/request, strictly validate the
retrieved output and revalidate inside this transaction. Original scenario/profile
retirement can make unfinished recovery unavailable; do not swap in new context.

## Verification and next binding

Fresh PGlite0.5.9/PostgreSQL18.6 applied all14 migrations. New72 SQL assertions passed,
retaining250 baseline/28 receipt/59 quota/59 text/68 reservation/99 completion cases.
Covers exact saved correlation/no token/read-only missing/retry, canonical key vs
original casing, allthree operations, wrong owner/receipt/key/context/shape/bounds,
legacy pending, storage faults after public/receipt/release changes, current-source
version revalidation, direct-release/client ACL denials and completed replay after
closure/profile change/retirement with no new tokens or duplicate messages.

The retained required database runner adds eight native PostgreSQL17 races using
independent psql processes and actually observed ungranted advisory locks: same
result, changed result, original normal completion, rollback, next distinct turn,
finish vs turn, wrong context and wrong key. Before first COMMIT, a separate STABLE
lookup must see only coherent old pending state and no partial public messages.
Another owner/scenario acquires independently under the same event UUID; after
commit/fresh retry exactly one receipt/token/original result exists. Tokens never
leave SQL in these probes. Bounded barriers/fixed disposable URL only. Native cases
are authored/syntax-checked, not locally executed; exact-head Actions is required.
SQL-role/model fixtures do not prove upstream authentication or hosted learner use.

Parent014bee0087ac197774efbac89a2ac4ec32898e09 passed allfive latest-attempt jobs and
every step in [CI39805367641](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39805367641),
attempt1, including all10 actual pg runtime cases. This resolves its old pending
Flutter/Windows checkpoint; this increment requires its own exact-head CI.

Next inspect exact-head allfive jobs and eight native reconciliation results. Then
implement trusted lookup-only verifier/runtime recovery and real-driver commit/
abort/restart guards, without a legacy fallback, token leak or provider redispatch.
Keep #31 open/default preview/#41 draft. Hosted TLS/CA/JWT/PostgREST/Edge/Deno/provider/
real network-partition/learner proof and all14 Personal Alpha release groups remain
pending; no deployment, provider strategy or release acceptance is claimed.
