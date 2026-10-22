# Atomic conversation reservation — Issue #31

Migration `20261022131000_ai_conversation_reservations.sql` is an undeployed SQL
component for start_conversation, conversation_turn and finish_conversation.
It commits a private server context/identity reservation together with the original
receipt/dispatch claim. It does not install a runtime conversation adapter, provider,
endpoint, public session/message write, completion/release API or application default
by itself. A separate validated
[completion component](AI_CONVERSATION_COMPLETION.md) now supplies guarded atomic
public persistence and release; neither component is bound to a runtime.
Do not enable conversation dispatch from this component alone.

## Authorization and source context

Only service_role can execute the three private invoker helpers; all have empty
search_path. The trusted backend must verify Supabase Auth and derive p_user_id.
An SQL UUID argument or SQL-role fixture is not an end-user authentication proof.
The request validator preserves strict original wire shapes, accepts no user/role/
server-ID/sequence overrides, checks standard UUIDs/level,32KiB serialized UTF-8
and1–5000-character turn text. No dynamic SQL or model text chooses authority.

For a new event, require a provisioned profile and matching active scenario/level.
Existing sessions must belong to that user, remain open and match the profile's
level. Other-owner/missing sessions both return NOT_FOUND. Every linked grammar/
vocabulary target must be active at the same level; no silent dropping of invalid
targets. A STABLE read helper constructs one statement snapshot with canonical
typed refs/versioned minimal curriculum and scenario data. Instruction data is
bounded to10000 UTF-8 bytes, scenario source and target projection each8000 bytes,
refs<=1000; complete context<=64KiB. It never reads another account's transcript,
credentials, audio, profile metadata or unrelated learner history. Existing scenario
and message data are captured only for this already scoped conversation operation;
no telemetry or new personal-data category is collected.

Existing transcripts must start with assistant sequence0, remain contiguous and
alternate assistant/user, ending on assistant. Reject malformed legacy sequences/
roles, individual text over5000 chars or oversized context. Keep at most99 stored
messages; a new turn requires at most97, leaving room for its user+assistant pair.
Finish remains available at99 messages. The transcript contains prior role/text_ja
only; the current turn stays in the immutable request, not an invented stored row.

## Atomic claim, serialization and safe uncertainty

`private.ai_conversation_reserve(uuid,text,jsonb)` validates the complete request,
takes a transaction advisory lock in the verified owner's namespace and checks the
existing receipt before source-active checks. Same request returns pending without
token/context, or original completed response even after closure/retirement/profile
change. Changed input under the same event conflicts. Legacy pending receipts also
remain pending; they never acquire a replacement dispatch token or reservation. A
committed legacy pending turn/finish for the same session blocks distinct new events
even without a private reservation; all runtime writers must follow the protocol.

For missing receipts, lock the profile/scenario FOR SHARE and existing owned
session FOR UPDATE. Generate start session/assistant UUIDs on the server, with
sequence0. Turn reserves separate user/assistant UUIDs and next consecutive slots;
only the assistant identity/sequence enters PreparedContext. Finish has no
fabricated message. Claim through the existing private receipt helper, then insert
the reservation in the SAME transaction. A competing legacy bare-claim caller may
win the unique receipt first; return its pending/completed result without issuing
another capability. Any failure rolls back receipt, token and reservation together.

Short owner-level transaction serialization is intentionally coarser than per-session
locking; different sessions for one owner may briefly queue. Locks end at COMMIT/
rollback, never span provider I/O. A unique partial index allows only one unreleased
reservation per session across different events/operations after commit. Thus a
finish cannot overtake a pending turn. A rare advisory hash collision could queue
otherwise unrelated owners; ownership checks and the unique index remain separate
correctness boundaries. Unrelated callers that bypass these helpers do not inherit
an application protocol merely from advisory locking.

The RLS-enabled private reservation references the private dispatch claim; it stores
the bounded original context and reserved IDs/sequences. Service receives SELECT
and INSERT of only reservation fields, excluding is_completed/created_at. It has
no UPDATE/DELETE/TRUNCATE or pre-released insert privilege. No client/public grant,
RLS policy, frozen wire or existing table shape is changed. Public sessions/messages
are not created before a validated provider result.

**Reservation alone never releases a slot.** Only the separately validated atomic
completion can release after public writes and receipt completion. A reservation
stays pending after timeouts, lost commit delivery, restart, malformed output or even bare legacy
receipt completion. Never expire, delete, reset or mark it completed to permit a
retry. Availability stays conservative when validated completion or recovery is absent.

The future runtime must use bounded owned READ COMMITTED transactions and verify
COMMIT/ReadyForQuery before dispatching acquired exactly once. Ambiguous COMMIT must
return no success and consult the durable receipt; never automatically retry a
provider call or renew a claim. SQL itself cannot certify commit delivery or Auth.
Controlled helper errors are VALIDATION_FAILURE/22023,NOT_FOUND/P0002,
FORBIDDEN/42501,SYNC_CONFLICT/P0001; the runtime must redact all other SQL/transport
errors and apply abort/late-result guards. No keys/tokens/text are logged here.

## Verification and next binding

The retained required database runner now executes the new SQL suite and native
five-case concurrency script. PGlite0.5.9/PostgreSQL18.6 locally applied all12
migrations and passed68 new assertions plus250 baseline/28 receipt/59 quota/59 text
context assertions. Cases cover all three operations, server identity/sequence,
typed active curriculum/profile/owner checks, malformed input/transcripts/bounds,
pending/completed/legacy replay, no public writes, privilege denials, rollback and
TEST ONLY trigger storage failure after claim without orphan state. Test-only
legacy fixture completion is not a valid learner/provider completion proof.

The native script uses independent psql processes, bounded barriers and observed
pg_stat_activity lock waits before commit/rollback. Cases: same event, changed same
event, distinct event, finish overtaking turn and rolled-back owner. User B must
acquire while A is held; fresh connections verify exactly one receipt/token/
reservation, reserved slots, no new public messages and pending/no leaked capability
on restart/lost-delivery retry. It refuses URLs other than the fixed disposable CI
database and never prints tokens/context. Allfive native cases passed on
exact007b2d4/latest attempt1 in
[CI39787225163](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39787225163),
with allfive jobs/every step successful. Embedded single-connection PGlite is not
concurrency evidence; future heads require their own checks. SQL roles, fixtures
and reconnect checks do not establish hosted JWT/Edge/provider/power-loss/learner proof.

Parent c8d66f43273aa5c7f5cc8202cc64e12628f0a27e passed allfive jobs/every step
in [CI39778434269](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39778434269),
attempt1. Allnine native text driver cases passed there. That source's full CI
pending checkpoint is resolved; this increment requires its own exact-head run.

Validated public persistence/token receipt completion/release is now specified in
[AI_CONVERSATION_COMPLETION.md](AI_CONVERSATION_COMPLETION.md). Next introduce
lookup-only correlated recovery and a coherent runtime acquisition port:
the current AiService prepare/claim calls are separate. Do not call this helper
inside prepare and then return a pending token from claim to work around that
ordering. Never expose another dispatch owner's token. Bind only after atomic
completion and lookup-only correlated reconciliation are ready. All14 hosted
release groups remain pending; no paid call/deployment/Auth/provider change.

Primary PostgreSQL17 locking/index references reviewed2026-10-22:
- https://www.postgresql.org/docs/17/explicit-locking.html
- https://www.postgresql.org/docs/17/indexes-partial.html
