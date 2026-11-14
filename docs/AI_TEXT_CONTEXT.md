# Private text context projection — Issue #31

Migration `20261022111500_ai_text_context.sql` supplies two undeployed, read-only
SQL components for `tutor_explain` and `correct_sentence`. They do not bind an
endpoint, runtime ContextRepository, provider, Auth strategy or application default.
Conversation ownership/reservations/sequence allocation and atomic message/receipt
completion remain separate #31 work. The existing conversation helper must not be
replaced with this read-only projection or a fabricated successful context.

## Trust and selection

Only service_role can execute the invoker functions in the private schema; both
use an empty search_path. No client grants, RLS policies, table shapes or frozen
v0.1 wire definitions change. The trusted backend must first verify Supabase Auth
and pass that identity as p_user_id. This argument is not an authentication proof
and must never come from a learner field, decoded JWT or model output. SQL-role
fixtures do not verify hosted signatures, expiry, issuer or two-user learner flows.

`private.ai_text_context(uuid,text,jsonb)` requires a provisioned profile and exact
request/profile preferred_jlpt agreement. It validates only the two original text
request shapes, rejecting unknown/owner/role fields, missing/null/wrong types,
invalid levels, non-UUID references, canonical duplicate IDs, more than100 IDs per
recent array and over5000-character learner text. The parsed JSONB request is
bounded to32KiB UTF-8 on serialization. The existing Contracts and streamed HTTP
validation remain mandatory; pass their frozen parsed request, never reparse raw
learner text under different rules. Canonical duplicate UUIDs are rejected even
when their original string casing differs.

Tutor recent IDs must resolve to active grammar/vocabulary in the profile's level.
Inactive, missing, wrong-level or wrong-table IDs all fail NOT_FOUND. Empty arrays
are valid. UUIDs are normalized and sorted, grammar before vocabulary; the learner
does not choose SQL, roles or an unbounded catalog query. The helper returns a
minimal versioned curriculum projection: grammar title/pattern/meaning or vocabulary
expression/reading/meaning, with type/id/content_version. It deliberately does not
load examples, private scenario system_context, audio, user history, sessions,
learning errors, credentials or another account's data. It does not create learning
items, counters, errors, sessions or receipts.

Correction requests have no reference selector in frozen v0.1. The server considers
the first32 active grammar and32 active vocabulary IDs in canonical order. Whole
entries are admitted deterministically while the curriculum JSON remains within
8000 UTF-8 bytes; no field is silently cut. The resulting allowlist covers exactly
the admitted entries, not the entire curriculum. This bounded selection is a
component policy, not semantic search, coverage or evidence that every possible
correction can be linked. Oversized mandatory tutor selections fail validation
instead of dropping requested IDs. Grammar-first budget allocation can admit fewer
vocabulary entries when grammar consumes the budget; empty allowlists remain valid.

The result has the existing PreparedContext fields `instruction`, `transcript`
(empty), and `allowedRefs`. Instruction is serialized curriculum DATA, separate
from AiService's fixed system instruction and the learner request. It must not be
installed as replacement model authority. The helper checks instruction <=10000
characters and complete JSON <=64KiB UTF-8; at most200 tutor or64 correction refs
are possible. AiService still verifies its own context bounds and rejects response
references outside the captured allowlist. Provider outputs never authorize IDs.

## Revalidation and errors

Both functions are STABLE: their SELECTs share the calling statement's snapshot.
`private.ai_validate_text_context(uuid,text,jsonb,jsonb)` recomputes the same
projection and requires exact equality with the captured context. Changed content
or selection gives SYNC_CONFLICT; retirement/missing references and a changed
profile are rejected by the original checks. This is a fresh read check, not a lock
on future edits or an atomic conversation completion transaction.

The future runtime must use short, bounded READ COMMITTED/autocommit reads before
dispatch and again after provider output passes original schema/allowlist checks.
Do not keep a transaction/snapshot open over provider I/O or reuse a REPEATABLE READ
snapshot for revalidation. No result may be returned as success after cancellation,
failed revalidation or ambiguous SQL/transport results. The adapter must map fixed
SQLSTATE/message codes into existing safe BoundaryErrors and redact raw driver
errors; SQL helpers do not supply that transport/error/cancellation boundary.

Controlled exceptions use VALIDATION_FAILURE/22023, FORBIDDEN/42501,
NOT_FOUND/P0002 and SYNC_CONFLICT/P0001. They include no text, UUID, credentials or
database details. A/B profile-level fixture tests exercise trusted SQL arguments;
service_role is privileged and those tests do not prove end-user authentication.

## Verification and remaining work

`bash scripts/test_database.sh` retains every prior gate and now executes
`supabase/tests/ai_text_context.sql` in the required database job. It checks invoker/
STABLE/ACLs, A/B level selection, null/forged/malformed requests, both reference
types, multibyte budgets, deterministic whole entries/canonical ordering, unchanged
learning/receipt state and stale/forged contexts after content/profile changes.
The suite temporarily retires earlier catalog fixtures inside its rollback-only
transaction, retaining their rows/FKs; it tolerates earlier committed receipt rows.

Local PGlite0.5.9/PostgreSQL18.6 applied all11 migrations and passed the new59
assertions plus retained baseline250, AI receipt28 and quota59 assertions. Existing
Node24 formatter/strict types/98 tests and29 QA regressions passed. PGlite is not a
native PostgreSQL17/multi-session/hosted test; new exact-head native CI is pending.

Separately, source cdae78b54d14c7aadff5e4a849adafa3452c47c5 passed allfive jobs
and every step in [CI39763102669](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39763102669),
attempt1. Its completed database log confirms allfive real-driver quota probes
passed. Test-only plaintext container transport and Auth/context/provider/receipt
ports do not establish hosted TLS/CA/JWT/Deno/Edge or learner acceptance.

Next: bind this projection/revalidation to a bounded real SQL ContextRepository
for the two text operations with real-driver safe-error/abort/late-response tests;
keep conversation operations explicitly unavailable until reservation/claim and
completion can share coherent transactions. Then implement conversation session
serialization and lookup-only receipt reconciliation. All14 hosted release groups
remain pending; no migration was deployed or paid provider called.

Primary PostgreSQL17 snapshot rules reviewed2026-10-22:
https://www.postgresql.org/docs/17/xfunc-volatility.html

## Opt-in runtime binding

The text-only `PostgresTextContextRepository` now binds these two helpers with
fresh owned read-only transactions, original schema/ref validation, confirmed
COMMIT and bounded cancellation/safe errors. See AI_TEXT_CONTEXT_RUNTIME.md for
tests and remaining native/hosted gates. The SQL components above do not themselves
install that host binding or a deployed endpoint. Parent a16bdb4a03b16f1d01dabfcf89961a2d5cde18d9
passed allfive jobs/every step in CI39770572353 attempt1, including all59 SQL text
assertions; that source's pending native/full-CI checkpoint is resolved.
