# Quiz report boundary — nd-quiz-report-1 (specified, undeployed)

## Reusable raw-ingress guard primitive — 2026-10-31

backend/ai/src/strict_json.ts now exports parseQuizReportJsonBody(Uint8Array)
for a future quiz ingress adapter. It checks the original byte length (16 KiB
maximum), fatal UTF-8 decoding, BOM rejection, duplicate decoded object keys
at every depth, integer-only numeric lexemes and safe integer representation
before any JSONB conversion. Quiz string values and object keys additionally
reject decoded NUL and unpaired UTF-16 surrogates, including escaped forms;
valid supplementary characters are preserved. This preflight restriction does
not change the general AI decoder's string semantics. The helper returns an object only; it does not
perform the nd-quiz-report-1 schema check, verify Auth, validate active
curriculum/ordered choices, acquire the owner lock, or call the private ledger.

The same module supplies duplicate-aware parseStrictJson to the existing AI
request decoder. The quiz-specific guard is tested with valid, exact-limit,
oversized, invalid UTF-8, duplicate/escaped-key, decimal/exponent, deep and
trailing-body cases. It is a reusable internal primitive, not a public endpoint
or an activated collection path. The private ledger remains inaccessible to
app roles; no RPC, migration, grant, upload or default app behavior changed.

## Typed request decoder — 2026-11-04

`backend/ai/src/quiz_report.ts` exposes `createQuizReportDecoder(schema)`.
The trusted host supplies the unchanged repository nd-quiz-report-1 schema;
learner input must never choose a schema. The returned function consumes raw
bytes through the guard above, validates the request definition without coercion,
defaults or field stripping, rejects repeated targets and nonmember choices,
and checks the real UTC calendar. Asynchronous schemas are rejected at setup.
It preserves original timestamp spelling/microseconds and answer/choice order,
then freezes the report, answer list, each answer and each choice list.
All request failures become the fixed VALIDATION_FAILURE boundary error.

Seven regression groups exercise all three canonical request fixtures, unknown/
missing fields, versions, kind, choice membership/duplicates, calendar overflow,
raw guard composition, nested immutability and asynchronous schema rejection.
These run in the existing Node/Deno test discovery. This is an internal decoder:
no HTTP route, verified identity, canonical-content check, transaction, public
RPC or upload is provided. Future replay lookup must still precede current-content
and future-time checks under the same owner transaction. No stored report or
learner acceptance is implied by successful decoding.

## Captured-request response decoder — 2026-11-04

`createQuizReportResponseDecoder(schema, requestRaw)` validates and captures the
original request before asynchronous I/O. Its returned decoder applies the same
16 KiB raw-byte guard and strict response schema, then requires exact equality of
all five echoed fields (including timestamp spelling). Counts must equal the
captured answer count and the count of selected_id==item_id. It returns a frozen
response with no aliases to either input byte array. Invalid captured requests
remain VALIDATION_FAILURE; invalid responses produce only INTERNAL_ERROR.

Five regression groups cover all canonical pairs, mutation of request bytes after
capture, immutable output, each identity/count mismatch, equivalent timestamps
with different spellings, schema-valid type/kind swaps, missing/extra fields,
invalid counts, raw lexical/encoding/size errors and invalid request binding.
A matching response proves only contract correlation: no authenticated ownership,
persistence, mastery, receipt lookup or permission to retry follows from it.
This internal decoder does not activate an endpoint or change app behavior.

## Internal transaction coordinator — 2026-11-04

`submitQuizReportInTransaction(schema, raw, host)` captures the validated request
before asynchronous work. Inside the caller's verified-owner transaction it
looks up replay first. Only explicit null permits current-content validation and
store; lookup failure/unknown or invalid replay cannot authorize a new write.
Both replay and store responses are validated before the work callback resolves,
so the host must roll back malformed results rather than commit them. Commit
failure propagates as a safe error. Safe Auth/conflict/validation codes are
reconstructed without forwarding SQL details or mutable error messages.

The host MUST bind verified identity and a single connection/transaction, retain
the owner lock after replay miss, validate canonical active content, enforce the
server clock in store, commit only on callback success and roll back on failure.
No default host, public route, identity verifier, PostgreSQL transaction host or
content adapter is supplied. Scripted transaction traces are TEST ONLY, not native DB
rollback, concurrency or hosted learner evidence. Actual wiring remains required.
An authoritative miss inside this transaction is not learner retry permission.

The coordinator optionally accepts the caller's AbortSignal and passes the same
signal to the host. It checks before opening, when the transaction callback starts,
after each awaited replay/content/store phase, and after the host returns. An
observed cancellation yields only NETWORK_UNAVAILABLE, never the abort reason.
Cancellation before/during work rejects the callback so a conforming host rolls
back; cancellation during commit may already have committed and remains UNKNOWN
to the caller. It never authorizes retry, deletion or a claim that rollback occurred.
The host must enforce its own bounded DB cancellation/deadlines and check the
signal before commit. The coordinator awaits operation settlement rather than
racing an orphaned DB promise; it does not itself impose a timeout. Scripted
cancellation tests do not prove native PostgreSQL cancellation/rollback.


## Private ledger SQL capability bridge — 2026-11-05

`createQuizReportSqlTransaction(query, validateCurrentContent)` supplies the
coordinator's replay/store capabilities using fixed parameterized SELECT calls to
private.replay_quiz_report and private.store_quiz_report. A single $1::jsonb value
carries the captured request; no owner, SQL identifier or role comes from input.
The SQL result is cast to text so the coordinator applies its existing strict
response decoder before returning from the transaction callback. Exactly one
SELECT row/one response column is required. Only SQL NULL from replay is a miss;
unknown/missing rows, JSON null text, malformed responses and null store fail.
Input/output UTF-8 bytes are bounded to16KiB. Exact P0001 plus UNAUTHORIZED,
VALIDATION_FAILURE or SYNC_CONFLICT maps to safe errors; other SQL details stay
private. Canonical-content validation is mandatory caller input, never a default
success implementation.

This bridge does not open/commit a transaction or establish identity, privileges,
cancellation or a content snapshot. Both capabilities MUST use the same trusted
verified-owner transaction, retain the replay lock, and be revoked at transaction
end. Current app/service grants remain revoked. A reviewed real transaction host,
canonical validator and native PostgreSQL tests are still required; do not wire
this directly to an HTTP route. Scripted SQL envelopes test protocol composition,
not actual SQL/RLS/rollback or hosted learner acceptance.

## Transaction capability lifetime — 2026-11-05

The coordinator now wraps each host callback with
`withQuizReportTransactionScope` (`backend/ai/src/quiz_report_scope.ts`). Only one
replay/content/store call may run at a time. A rejected operation or overlapping
call poisons the callback even if its caller catches the rejection. At callback
settlement all exposed capabilities are revoked; retained references reject
without dispatch. If an operation is still pending, the scope rejects and drains
it before returning to the host, including when the callback throws. Safe errors
are reconstructed; private exceptions are never forwarded.

Dispatch also rechecks revocation inside the queued microtask. A synchronous
callback throw after scheduling a port call now prevents that port from starting;
it does not merely drain a query that should never have been dispatched. A new
regression reproduces the old failure and verifies zero dispatch plus safe rejection
for replay, current-content validation and store. Already-started operations still
drain through the original settlement path; this is not native query cancellation.

The host must await the callback before commit/rollback and provide bounded native
operations. This wrapper does not impose a timeout, cancel a query, revoke the
host's original ports, or guarantee native rollback. SQL/identity/content/grants
remain the host's responsibility. Sequential awaited coordinator behavior and
replay-first ordering are unchanged. Five new scripted regression groups cover
success, escaped calls, failure, overlap, pending drain and swallowed failures;
they are TEST ONLY capability evidence, not native PostgreSQL/hosted acceptance.

## Private ledger foundation — 2026-10-31 UTC

Migration20261031090000_quiz_report_ledger.sql adds only a private, undeployed
self-report receipt ledger. All authenticated/anon/service-role table and helper
privileges are revoked. No public RPC or app upload is enabled. RLS has an owner
SELECT policy but no application read grant; future access needs an explicit
reviewed boundary. Immutable update/delete trigger preserves original history.
No baseline quiz_attempts row, unmeasured duration, progress, SRS or mastery is written.

`private.quiz_report_request(jsonb)` checks decoded shape, UUIDs, kind/level,
UTC/calendar/version, unique targets/ordered choices and membership. The existing
review_instant helper supplies calendar parsing. `private.replay_quiz_report`
derives owner exclusively from auth.uid(), validates structure, acquires a
transaction-scoped per-owner advisory lock, and returns the original response or
null on a miss. The lock survives a miss until transaction end: the future public
wrapper must look up replay BEFORE active-content checks, validate a new report,
and then call private.store_quiz_report in the same transaction.

The private store repeats lookup under that lock, rejects new future reports
beyond five minutes, derives counts from reported choices, and atomically inserts
one complete round/request/original response. Identical retry returns the original;
changed payload under the same owner/event conflicts across quiz types and grammar
kinds. Another owner can use that event independently. Helpers are closed-path
SECURITY INVOKER and inaccessible to app roles. They are internal capabilities for
a future trusted wrapper, not a standalone authenticated user-facing service.

**Important ingress gap:** conversion to JSONB loses duplicate object keys and can
normalize exponent number spelling (e.g.1e0). Original UTF-8 byte size is also lost.
These helpers cannot establish all raw-wire rules in nd-quiz-report-1. The future
verified ingress must apply strict raw JSON validation BEFORE JSONB conversion,
or explicitly review a transport contract change. Do not open the proposed
jsonb RPC and claim the Python raw-parser guarantees were preserved. Canonical
active target/choice validation is also deliberately absent from this ledger.
Fixture rows are self-reports, not validated linguistic grades or learner proof.

Native SQL tests cover three correlated fixture responses, missing identity,
revoked role calls/grants, RLS(A/B) under transaction-local TEST ONLY read grants,
exact retry, type/kind conflicts, malformed reports, immutability, outer rollback,
new-future rejection and replay-before-future checking. A synthetic privileged
prior-future receipt models clock rollback; it is not a real learner report.
All temporary grants/data are rolled back and grant absence is asserted afterward.

The mandatory database runner additionally invokes four real-session race cases
(identical/changed/distinct/rollback). Each must observe the second session's
actual pg_stat_activity advisory wait before releasing the first transaction;
response/row counts are checked after commit/rollback. These are privileged
TEST ONLY Auth-claim fixtures, not hosted JWT/RPC tests. Existing checks are retained.
Fresh PGlite0.5.9 executed all migrations plus the complete new SQL suite locally,
then verified zero retained fixture rows and no leaked read grant. This single
WASM engine does not execute the native concurrency script. Actual PostgreSQL17
SQL/race results still require the new exact-head Actions run in PR41.

The next step remains a public verified/raw-ingress/current-content boundary and
Dart parity. Production deployment, collection and Auth human gates remain intact.

## Issue #13 audit and bounded delivery

At source f5308cf66136b79e349c2e1163096daf9b06e910, quiz rounds, immutable
owner-bound local journals, explicit history/progress, current-content weak points
and nd-quiz-recall-1 milestones have component evidence. Hosted attempts, sync,
verified learner identity and a mastered-item projection remain incomplete.
The SQL baseline has per-item quiz_attempts rows and restrictive owner read RLS;
it has no authenticated round-report mutation/receipt. Those rows also require a
duration_ms that current local reports do not measure. Do not fabricate zero
duration, reuse SRS receipts, grant direct writes or call a native journal cloud sync.

The earlier contract increment supplied a separate wire specification, executable
JSON/semantic validator, fixtures and mutation tests. The private ledger increment
above adds an undeployed migration; neither increment opens an RPC, sends reports,
activates collection or authorizes deployment. Frozen v0.1,
existing local journal formats, RLS/grants, default app and Pro content are intact.
The pre-code design/review is saved under core-20261031-quiz-report-contract in
PR41/Issue13. Live collection/deployment and other human gates remain unchanged.

## Proposed operation and ownership

`submit_quiz_report(p_request jsonb)` is specified in `contracts/quiz/v1/contract.json`.
The version is nd-quiz-report-1; request/response are `$defs` in schema.json.
Use the existing frozen error object. The eight v0.1 operations are unchanged.
Only future gateway-verified Auth/auth.uid may supply the owner. Never accept an
owner, derived score, mastery, duration, metadata or arbitrary question text.
Client report time/answers are self-reports, not proof of attention or memory.

| Field | Rule |
| --- | --- |
| client_event_id | Lowercase UUID, copied unchanged from the locally captured event_id |
| quiz_type | vocabulary_reading or grammar_meaning |
| practice_kind | null for vocabulary; primary or correction for grammar |
| jlpt_level | N5 or N4, mapped from local level |
| completed_at | Real UTC instant, 2000–2100, uppercase T/Z, at most six fractional digits |
| answers | 1–10 unique target answers, preserving original order |

Each answer contains item_id, positive integer content_version up to2147483647,
selected_id and exactly four unique ordered choice UUIDs. Both item_id and
selected_id must belong to choices. Repeated targets are rejected even when the
selected answer differs. JSON has no unknown/missing fields. Vocabulary focused
practice has no stored kind in its existing format, so maps to null; do not
invent a primary/correction split during upload. Grammar kind stays explicit.

The response echoes those five identity/type/kind/level/time fields and returns
answer_count and correct_count. Counts are strict JSON integers within1–10 and
0–10, with correct<=answer. With a correlated request, validate both identity
and the exact count of selected_id==item_id. This equality is reported canonical
choice correctness, not a trusted grade. It grants no MASTERED/SRS/study credit.

## Executable validation

`python3 -m contracts.validate_quiz_report` validates three committed synthetic
request/response pairs. `python3 -m unittest contracts.test_quiz_report_contracts -v`
executes ten test groups, automatically included in the existing CI contracts
discovery. No workflow or test gate changes are needed.

`parse_request(bytes)` bounds the UTF-8 body to16384bytes before parsing, rejects
invalid encoding, malformed/deep JSON, duplicate keys at every object depth and
non-finite numbers, then enforces schema and cross-field rules. It returns generic
errors without raw payloads. Direct validate_request/validate_response handle
already-decoded offline values; they are not HTTP adapters or Auth verifiers.
The validator additionally rejects float/bool versions/counts that ordinary JSON
Schema integer semantics could accept. Formatted JSON fixtures and Python syntax
are checked locally. Schema validation cannot prove ownership or curriculum truth.

## Required server increment (not delivered)

1. Review an additive round receipt/answer ledger compatible with current reports;
   retain baseline quiz_attempts constraints and immutable history. Do not invent
   duration or silently collect new fields. Auth derives owner; per-owner event
   identity spans both quiz types and grammar kinds so changed input conflicts.
2. Replay identity compares validated field values, including exact timestamp text
   and array order; object key order/JSON whitespace are irrelevant. Keep the
   original spelling on retry; changing an equivalent UTC spelling still changes
   the request. Under one transaction/owner lock, check replay before current-content or
   future-time rejection. Identical retry returns the stored original response,
   including after content changes; changed body under that event ID conflicts.
3. For NEW reports validate each active target and ordered choice in the matching
   type/level/current version; verify the canonical choice-building policy, not
   just selected==target. Bound resource use and reject future instants more than
   five minutes ahead of server time. Original historical completion times remain
   unchanged; no artificial re-dating to earn recall milestones.
4. Derive counts server-side, atomically persist complete round/answers/original
   response, and roll back everything on failure. No orphan partial report or
   client write to progress/mastery/SRS. Map safe frozen errors without SQL details.
5. Native role/RLS and concurrent same/different-body tests, plus typed Dart wire
   parity/owned-runtime integration, precede hosted A/B/JWT/PostgREST/two-device
   evidence. Distinguish received self-report from scientifically validated mastery.

The strict raw-byte guard and typed decoder now exist, but no public endpoint,
canonical-content validator or Dart RPC adapter exists yet. The private decoded
ledger and verified-owner transaction host are foundations only; the host requires
a trusted canonical-content validator and is not wired to a route. No hosted or
learner acceptance follows from these fixtures. Issue #13 and all 14 release gates
remain open.

## Prior evidence

[CI41180091136](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41180091136)
passed exactf5308cf/latestattempt1/allfive/every step. Raw Flutter124475881165
confirms the extended owned dual-store dashboard journey; Windows124475602208
confirms grammar/evidence/persistent SDK markers. This is TEST ONLY component
proof; it does not execute the new contract tests. Their exact new-head CI and
publication are recorded in PR41/PROJECT_STATUS.


## Native PostgreSQL coordinator and SQL-bridge execution — 2026-11-06

The database CI job now runs `npm run test:postgres-quiz` on its fixed disposable
PostgreSQL 17 database. The Node 24 test composes
`submitQuizReportInTransaction` with `createQuizReportSqlTransaction` on one
`pg.Client` connection. It records the native transaction ID across replay,
current-content validation and store, and refuses any other SQL statement from
the bridge.

For each canonical vocabulary/grammar fixture it seeds isolated TEST ONLY
curriculum rows and Auth user IDs. A retired choice causes current-content
validation to reject after replay miss; the test host rolls back to a savepoint
and commits the empty outer harness transaction, then confirms no receipt row
exists. After reactivating the content, the same event succeeds. The test then
retires the target and proves exact replay returns the original response without
calling current-content validation; changed payload returns only
`SYNC_CONFLICT`. A second synthetic owner can store the same event ID without
reading the first owner's receipt.

This is native PostgreSQL execution of the TypeScript coordinator/SQL bridge,
not merely a mocked query trace. The test-only host sets
`request.jwt.claim.sub` on a privileged disposable connection; it does not
verify a signed JWT, exercise PostgREST grants/RLS, or provide a production
transaction host. The current-content callback is a test fixture, not a trusted
deployed content service. No public RPC, app binding, migration, grant, default
activation, hosted learner evidence, mastery or study credit is added.

## Verified-owner PostgreSQL transaction host — 2026-11-07

`backend/ai/src/quiz_report_host.ts` now supplies an opt-in server-side host.
`submitVerifiedQuizReport` verifies the bearer through the injected AuthVerifier
before creating a database connection. Invalid identity never opens PostgreSQL.
A fresh trusted connection must already have the private schema/function/table
privileges; the host checks those privileges and never creates or widens grants.
It begins one bounded transaction, binds `request.jwt.claim.sub` only from the
verified Auth result, and runs the private replay/content/store capabilities on
that same connection. Replay remains first. The mandatory current-content
validator runs only on an authoritative miss; there is no default-success
validator. A valid response is decoded before COMMIT. Failure rolls back;
cancellation closes the owned connection; an ambiguous COMMIT is never retried
or presented as a saved result. Raw SQL/driver errors are redacted.

`createTrustedPostgresQuizReportSubmitter` wires only trusted server configuration
to `SupabaseAuthVerifier` and the TLS-enforcing owned PostgreSQL factory. It does
not read environment variables, install an HTTP route, expose a public RPC,
change the default Flutter runtime, add migration/grants, or collect additional
learner fields. The current-content callback is still a required trusted input;
canonical ordered-choice reconstruction and a typed Dart adapter remain open.

The Node tests cover invalid identity/body, verified-owner claim binding,
replay-first behavior, mandatory content validation, rollback, closed-role
refusal, redacted errors, cancellation and ambiguous commit. The PostgreSQL 17
native test composes the host with a synthetic TEST ONLY AuthVerifier and real
disposable database connection, then checks `auth.uid()`, owner A/B receipts,
retired-content replay and rollback. This is not signed-JWT/PostgREST, deployed
RLS, hosted Auth, canonical linguistic validation or learner acceptance.
## Current active-content eligibility callback — 2026-11-07

backend/ai/src/quiz_report_content.ts exports validateCurrentQuizReportContent, a concrete callback matching the verified-owner host's required validateCurrentContent port. It runs only after the host's replay miss and receives the host's same-connection query function and abort signal.

The callback reads a bounded projection from exactly one table selected by the trusted decoded quiz type: active public.vocabulary or active public.grammar, filtered by the fixed jlpt_level. It requires an exact projection shape, canonical lowercase UUIDs, valid content versions and nonblank bounded text. The target must still be active at the captured content version and eligible under the current quiz builder's unique-heading rules. Vocabulary choices must be current active Kanji-bearing vocabulary prompts with distinct readings; grammar choices must be active unique-title items with distinct meanings. All four displayed IDs must be present in that same level's active eligible set. Query/driver details are redacted; abort is preserved as NETWORK_UNAVAILABLE.

This is deliberately a membership and eligibility check, not exact deterministic reconstruction. The curriculum tables do not store the original source ordinal used by the client quiz builder, so the server cannot yet prove the exact distractor order or target slot. The report also carries only the target content version, not each distractor's displayed version. To avoid guessing, ambiguous reading/meaning labels are rejected. Adding source-order/version provenance requires a separately reviewed content-contract/schema increment; this change does not invent it.

The callback does not expose an HTTP route or public RPC, read environment secrets, activate the Flutter save path, grade linguistic correctness, infer mastery, or grant study/SRS credit. Its eleven Node tests are automated component checks; the new exact-head CI must execute them before this increment is accepted. Hosted signed-JWT/PostgREST/A-B and learner proof remain separate gates.


## Deterministic source-order report v2 — 2026-11-09

The separate `nd-quiz-report-2` contract lives under
`contracts/quiz/v2`; `nd-quiz-report-1` remains unchanged. Each answer adds
`choice_content_versions`, exactly four positive int32 values aligned with the
four ordered choice IDs. The target's `content_version` remains for explicit
target identity and must match the value at its displayed slot.

The additive `20261109030000_quiz_source_order.sql` migration adds
`source_ordinal` to vocabulary and grammar. It is the zero-based order from the
canonical source export within a JLPT level, not UUID order or a learner-supplied
value. Partial unique indexes enforce non-null ordinal uniqueness per level.
New active rows require an ordinal; old inactive/unimported rows may remain null.
The v2 content validator fails closed if an active projection contains a missing,
duplicate, malformed or non-monotonic ordinal.

`validateCurrentQuizReportContentV2` reconstructs the same eligible target
sequence, first-occurrence reading/meaning pool, cyclic distractor selection and
`targetIndex % 4` insertion slot as the Dart builders. It compares the exact
four ordered IDs and every captured choice version. Duplicate labels retain the
same first-in-source-order behavior as the client; no UUID-based guess is used.
This closes the prior membership-only gap for a current-content projection.

The v2 schema, Python fixtures, TypeScript validator and additive SQL constraints
are component foundations only. Existing v1 private-ledger SQL/host is not
silently reinterpreted as v2. No v2 ledger function, HTTP route, public RPC,
grant, Dart upload adapter, default save path, hosted JWT/PostgREST learner flow,
mastery or study credit is enabled. The trusted content importer must populate
canonical ordinals before active rows can be accepted by v2 validation.


## Canonical source-order projection — 2026-11-09 UTC

`scripts/export_quiz_source_order.py` builds a read-only projection for the
future trusted curriculum importer. It reads `data/manifest.json` and each
selected level's original `vocabulary.json` / `grammar.json` arrays. For each
table and level it emits the original zero-based array index as
`source_ordinal`, including inactive rows, plus ID, level, content version and
active flag. It records SHA-256 for the exact manifest and each exact source
file, so an import review can bind the ordinal map to the source snapshot.

The projection fails closed on duplicate JSON keys/IDs, missing or mismatched
manifest counts, unsupported/duplicated levels, wrong-level rows, invalid
active/version metadata, oversized sources or a pre-existing ordinal field.
It never edits canonical JSON, contacts Supabase, produces SQL or accepts
credentials. `--level N5` is the repo-sanity CI path. The same generic code
supports N4 after coordinator review/integration, but this core CI increment
does not read or modify Pro-owned N4 content.

The output is only an import input contract, not an importer or deployment.
Existing active database rows remain unpopulated until a separately reviewed
trusted transaction consumes the projection. The v2 validator remains fail
closed; no public route/RPC/grant, typed Dart upload, default save, mastery or
study credit is enabled by this step.


## Typed Dart nd-quiz-report-2 projection — 2026-11-10

\`QuizReportV2Request.fromVocabularyAttempt\` and
\`QuizReportV2Request.fromGrammarAttempt\` project immutable local attempt snapshots
into the separate v2 request shape. They require local \`format_version: 2\`; legacy
v1 snapshots are rejected because they never captured all four displayed choice
versions. The adapter preserves event ID, exact canonical UTC completion text,
level, grammar primary/correction kind, answer order, four choice IDs and their
parallel content versions. Vocabulary \`practice_kind\` remains null.

The request and answer snapshots are immutable and serialize only the six v2
request fields. They do not serialize owner identity, local format version, score,
duration, SRS state, mastery, credentials or timer data. The strict response
decoder requires exactly the seven v2 response fields and correlates all five
identity fields plus answer/correct counts against the captured request.

This is a pure Dart wire projection/decoder, not a repository or transport. It
does not call Supabase, expose a public route/RPC, persist attempts, activate
default save, or grant mastery/study credit. The existing v1 private ledger/host
is not reused as a v2 endpoint; v2 still needs its own reviewed transaction host,
raw-ingress boundary and deployment/hosted acceptance. No N4 content is read or
changed by these tests.
