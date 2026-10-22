# Atomic conversation completion — Issue #31

Migration `20261022142000_ai_conversation_completion.sql` adds an undeployed private
SQL component for the three original conversation mutations. It builds on the
[reservation component](AI_CONVERSATION_RESERVATIONS.md). It does not itself install a runtime/provider/endpoint or default. The explicit
opt-in adapter is now documented in [AI_CONVERSATION_RUNTIME.md](AI_CONVERSATION_RUNTIME.md);
correlated recovery and hosted evidence remain pending.

`private.ai_conversation_complete(uuid,text,jsonb,uuid,jsonb)` takes the verified
backend owner, original operation/request, private dispatch token and validated
provider result. The backend must still verify Supabase Auth, rate limits, request/
response contracts, deadlines and confirmed reservation COMMIT before dispatch.
A caller-supplied UUID or SQL service role is not hosted learner authentication.

## One transaction, one original result

Validate the original request, acquire the same short per-owner advisory lock,
lock the owner's exact receipt/reservation and compare immutable request and token.
A different owner sees NOT_FOUND; an invalid token is FORBIDDEN. Completed replay
requires both the original completed reservation and exactly the stored response;
it returns before profile, content or session-active checks. Changed response or
request conflicts. A legacy bare receipt completion without the atomic public
writes cannot release or heal a pending reservation through this helper.

For pending work, lock the profile FOR SHARE, owned existing session FOR UPDATE,
old message rows FOR SHARE, scenario FOR UPDATE, linked scenario rows and curriculum
target rows FOR SHARE in deterministic ID order. Scenario/session parent locks
block concurrent FK additions; row locks also block existing source edits/deletes.
Rebuild the bounded context and require exact equality with the saved context,
including source versions, typed refs and transcript. Reject closed sessions,
changed profile/retired content, changed source/text or consumed sequence slots.
These short locks can queue different owners sharing one scenario or target; a
lock/deadlock timeout must fail closed. Locks never span provider I/O. Advisory
locking alone does not constrain unrelated callers bypassing the protocol.

The response validator enforces the original strict shapes and bounds for all three
responses: required/unknown fields, assistant identity/sequence/role, Japanese and
nullable Vietnamese text, correction arrays/text/refs, finite JSON scores [0,100],
strength/focus arrays and recommendations. Serialized JSON is limited to1MiB UTF-8.
Assistant/server IDs and refs must preserve the exact canonical values provided
in context, matching AiService. Model audio_ref must remain null. Every correction
and recommendation ref must be a complete member of the captured typed allowlist;
a model cannot invent authority through an ID or select another item type.

Then, in the SAME transaction:

- Start inserts the reserved session with verified owner/level/scenario and server
  reservation clock, plus reserved assistant message at sequence0.
- Turn inserts the reserved user message with exact immutable request text and null
  translation/audio, followed by the reserved validated assistant at the next slot.
  Live feedback is retained in the exact receipt; it does not alter SRS/error tables.
- Finish sets a finite server ended_at, stores response.scores in score_json and
  the four remaining response fields in summary_json. It adds no message or SRS/
  learning-error write. Recommendations remain suggestions.
- Complete the original token-checked receipt and only then mark the reservation
  completed, releasing the pending-session unique guard. Any failure rolls back
  all session/message/receipt/release changes. The original response is returned.

The caller must use a fresh bounded owned READ COMMITTED transaction and confirm
COMMIT/ReadyForQuery before returning success. This helper cannot prove commit
acknowledgement. After uncertain delivery, inspect the immutable durable receipt;
never renew a dispatch, delete/reset/expire a reservation or automatically call the
provider again. Lookup-only correlated reconciliation still needs implementation.

## Privileges and safe errors

Only service_role can execute the new helpers. Completion is a narrow SECURITY
DEFINER with empty search_path and static fully qualified table/function access;
this supplies only the guarded private release authority. Direct service UPDATE,
DELETE, TRUNCATE and pre-released INSERT remain denied, including the unchanged
reservation suite's existing denial assertion. All client/PUBLIC execution is
revoked. The validator is immutable invoker. Existing client RLS/table grants,
frozen contracts, Auth strategy and legacy receipt helpers are unchanged.

Controlled errors remain VALIDATION_FAILURE/22023, NOT_FOUND/P0002,
FORBIDDEN/42501 and SYNC_CONFLICT/P0001. The future runtime must map only these
exact controlled errors, redact all unknown SQL/transport details and prevent late
or aborted work. Neither SQL helpers nor native probes print tokens/context/text.
No plaintext fallback, new personal-data category or paid dispatch is introduced.

## Verification and remaining work

All13 migrations applied locally in fresh PGlite0.5.9/PostgreSQL18.6. The new99 SQL
assertions cover successful start/turn/finish, strict malformed output/bounds/refs,
owner/token/request fencing, captured version/profile/transcript/retirement changes,
allthree operations' atomic storage-failure rollback, retained denied direct release,
legacy bare-complete safety and exact original replay after closure/retirement.
The250 baseline,28 receipt,59 quota,59 text and68 reservation assertions also pass.
Embedded PostgreSQL is not multi-process/native concurrency evidence.

The retained database runner adds eight native PostgreSQL17 cases with independent
psql processes, bounded barriers and actually observed ungranted transaction locks:
duplicate and changed completion, next distinct turn/slots, rollback, finish vs
next turn, target update, new scenario link and old transcript update. An unrelated
owner/scenario acquires while A is held. Fresh processes check exact public rows,
receipt/release/closure and original replay without a new dispatch capability.
The script refuses any URL except the disposable CI database. All8 native SQL cases and all99 SQL assertions passed on parent e621c9d/latest
attempt1 in CI39795974325, with allfive jobs/every step successful. Future changes
require their own exact-head checks; embedded tests alone are not concurrency proof.

Parent007b2d49587f5e7979a5acee8913521f17efeac2 passed allfive latest-attempt jobs and
every step in [CI39787225163](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39787225163),
attempt1, including all68 native reservation assertions and five native races.
This resolves that source's pending platform handoff; this increment needs its own CI.

An opt-in coherent atomic runtime port/driver is documented in
[AI_CONVERSATION_RUNTIME.md](AI_CONVERSATION_RUNTIME.md). Next add lookup-only
correlated reconciliation and hosted runtime evidence. Current AiService prepare/claim are separate; do not hide reserve
in prepare and return another worker's token from a pending claim. Test real driver
COMMIT ambiguity/cancellation/restart before installing an endpoint. Hosted TLS/CA,
JWT/PostgREST/Edge/Deno/provider/learner and all14 release groups remain unverified;
SQL roles, fixed model fixtures and reconnect probes do not establish those gates.
