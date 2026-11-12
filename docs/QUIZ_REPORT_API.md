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

The adapter's `encodeRawBody()` serializes the immutable request as UTF-8 JSON,
returns a fresh unmodifiable byte list and enforces the same 16,384-byte maximum
as the backend raw-ingress guard. The encoder cannot emit duplicate object keys
and does not normalize timestamps or versions. The test covers vocabulary and
grammar/correction requests, byte-count parity, round-trip fields and immutability.

This remains a pure Dart wire projection/decoder, not a repository or transport.
It does not call Supabase, expose a public route/RPC, persist attempts, activate
default save, or grant mastery/study credit. The existing v1 private ledger/host
is not reused as a v2 endpoint; hosted acceptance and a separately reviewed
transport integration remain required. No N4 content is read or changed by these
tests.


## Private nd-quiz-report-2 ledger foundation — 2026-11-10

The additive migration `20261110100500_quiz_report_v2_ledger.sql` adds private
`quiz_report_request_v2`, `replay_quiz_report_v2` and
`store_quiz_report_v2` helpers. V2 validates exactly four ordered choice IDs
and four positive int32 `choice_content_versions`; the version at the target's
choice position must equal `content_version`.

V1 and V2 intentionally share `private.quiz_report_receipts` and the same
per-owner advisory lock. The complete JSONB request (including all displayed
versions) is the immutable replay identity, so changing a distractor version
under an existing event conflicts. A V1/V2 attempt cannot silently reuse the
same owner/event key with a different contract body. Existing V1 validators and
request/response contract remain unchanged.

The native TEST ONLY ledger suite covers V2 insert/replay, changed distractor
version conflict, target-version mismatch, short arrays, boolean/decimal
versions, cross-version event collision, owner isolation, RLS and revoked
execute grants. The migration is additive and undeployed. It does not provide
the V2 raw HTTP decoder binding, verified-owner V2 host, public RPC/route,
PostgREST grant, client dispatch, default save, mastery, SRS or study credit.
The raw UTF-8/duplicate-key/integer-lexeme guard must still run before JSONB
conversion, and the V2 current-content validator must run after replay miss on
the same verified-owner transaction.


## Strict raw nd-quiz-report-2 ingress decoder — 2026-11-10

`backend/ai/src/quiz_report_v2.ts` provides separate request and response
decoders for the undeployed v2 contract. Both accept raw UTF-8 bytes and call
the existing `parseQuizReportJsonBody` guard before schema validation or any
JSONB conversion. The shared guard enforces the 16 KiB limit, fatal UTF-8,
duplicate-object-key rejection, PostgreSQL-compatible strings, integer-only
number lexemes (so `1.0` and `1e0` are rejected), depth/token bounds and no
trailing JSON.

The request decoder validates the v2 schema, distinct answer targets, offered
target/selection IDs and the captured version at every choice position. The
target's displayed choice version must equal its explicit `content_version`.
Returned requests, answers, choice IDs and choice-version arrays are frozen.
The response decoder repeats the raw guard, validates the seven-field schema
and correlates event/type/kind/level/exact timestamp plus answer/correct counts
against the immutable request.

Tests use all three canonical v2 fixtures and cover duplicate keys, fractional
and exponent number spellings, malformed UTF-8, oversize payloads, duplicate
targets/choices, target-slot mismatch, invalid calendar values, immutable
snapshots and response identity/count mismatch.

This closes only the raw decoder component gap. It is not a verified-owner V2
host, current-content transaction, HTTP route, public RPC/grant, deployed
PostgREST/Auth integration or learner save path. The private v2 ledger and
current-content validator still require a same-connection verified-owner host;
default app save, mastery, SRS and study credit remain disabled.


## nd-quiz-report-2 verified-owner transaction host — internal only

`backend/ai/src/quiz_report_v2_host.ts` now composes the existing strict raw-byte
decoder, trusted Supabase Auth verifier, private v2 SQL ledger and canonical
current-content validator. Raw bytes are copied and schema-validated before
Auth or JSONB conversion. The verified Auth UUID alone supplies the owner claim;
the host opens one fresh owned PostgreSQL connection, checks the private ledger
capabilities, sets the owner claim and awaits replay/content/store on one
transaction. It has bounded lock/statement/idle/overall deadlines, abort-driven
connection close, rollback before commit, ambiguous-commit safe failure and
fixed redacted errors. No request field selects an owner, table, schema or SQL.

An authoritative replay hit returns the original correlated response before
current curriculum checks. Only an explicit miss permits the required V2
validator, which reconstructs canonical source order and checks the target plus
all four displayed choice versions. The private store then enforces server time
and the existing shared owner/event receipt. Transaction capabilities are
serialized, drained and revoked after callback settlement.

`createTrustedPostgresQuizReportV2Submitter` accepts trusted server configuration
only. The component does not read environment variables, install an HTTP/Edge
route, add grants, change Auth strategy, deploy, or enable the Flutter default
save action. It stores a self-reported answer receipt only; it does not grant
mastery, SRS state or study minutes. The app adapter remains a separate opt-in
boundary.

Node regressions cover raw rejection before Auth, verified owner binding,
replay-first order, content rejection/rollback, missing privileges, malformed
responses, cancellation, ambiguous commit and error redaction. The native
PostgreSQL 17 regression exercises all three V2 fixtures, concurrent duplicate
submission, source order/version validation, original replay after content
retirement, changed-event conflict and A/B receipt isolation. Its Auth verifier
is synthetic TEST ONLY and is not hosted learner proof. Hosted signed-JWT/
PostgREST, live content import, default learner save, durable attempts,
mastery/weak-points and complete learner acceptance remain separate work.


## Internal nd-quiz-report-2 HTTP ingress adapter — 2026-11-10

The new backend/ai/src/quiz_report_v2_http.ts composes an internal
Request/Response boundary around a caller-supplied trusted
QuizReportV2Submitter. It accepts POST application/json only, requires one
Bearer header and identity content-encoding, enforces the 16 KiB raw-body cap
while reading the stream, verifies a declared Content-Length against actual
bytes, and forwards the exact byte sequence without JSON parsing or
re-encoding. The existing trusted submitter remains responsible for strict
UTF-8/duplicate-key/schema validation, Supabase Auth verification, canonical
content checks and the owner-locked transaction.

The HTTP adapter propagates client cancellation and a bounded deadline to the
submitter, cancels incomplete request streams, returns no-store/nosniff
responses, and maps only fixed Vietnamese error messages/statuses. Rate-limit
and network errors are retryable; validation and conflict errors are not. A
timeout does not prove rollback or absence of a committed receipt; clients must
retain the original client_event_id and inspect history before an explicit
retry.

The internal handler is now wrapped by an undeployed Supabase Edge Function at
`supabase/functions/quiz-report-v2/index.ts`; `supabase/config.toml` explicitly
keeps `verify_jwt = true`. The binding reads fixed server environment variables,
validates an exact-origin CORS allowlist and dynamically loads the trusted
PostgreSQL submitter only after installing the real Node compatibility globals
required by the pinned `pg` dependency. It never accepts a learner-selected
project URL, key, owner or database. The route is not deployed, and no hosted
JWT/PostgREST/Edge-runtime evidence or default app save path is implied. No
mastery, SRS state or study minutes are granted.

Node regressions cover exact raw-byte forwarding (including duplicate JSON
members, left for the strict host decoder), method/media/encoding/bearer
rejection before dispatch, streamed size and Content-Length checks, fixed error
mapping/redaction, deadline and client cancellation. Exact-head AI boundary CI
must pass before this baseline is treated as verified; hosted signed-JWT,
PostgREST/RLS and learner acceptance remain separate.

## Captured-session Flutter HTTP transport — 2026-11-10

The opt-in Flutter boundary now has `QuizReportV2HttpTransport` and a
read-only `SupabaseQuizReportV2Auth` observer. The observer snapshots only the
SDK's current user ID, access token and local generation. It never decodes JWT
claims as proof, signs in/out, refreshes, persists credentials or owns the
Supabase client; the trusted server remains the only JWT verifier. A generation
changes when the user or access token changes, including refresh rotation, so a
request captured under an older token is fenced.

The transport accepts only a caller-owned Supabase project origin and public
publishable/anon key, constructs the fixed
`/functions/v1/quiz-report-v2` path, and never reads URL/key from learner input.
It posts the adapter's original bounded UTF-8 bytes with the captured Bearer
token and public key, disables redirects and automatic retries, aborts on
logout/account/token-generation replacement, bounds the response to 16 KiB,
requires JSON plus `no-store`/`nosniff`, and validates the response against
the immutable request. Server error text is never displayed; status/code pairs
map to fixed Vietnamese messages.

A timeout or connection loss is uncertain: the server may already have committed.
The transport returns a retryable network error but never retries itself; the
caller must keep the original `client_event_id`, inspect history and only then
make an explicit same-event reconciliation attempt. A late response from a
replaced account is rejected locally even if the original owner transaction
committed.

This is an opt-in client component only. The Supabase Edge route is not yet
registered or deployed, the default quiz save action remains disabled, and no
hosted signed-JWT/PostgREST/RLS, learner A/B, durable multi-device attempt,
mastery, SRS or study-credit acceptance is claimed. SDK/Auth fixtures and Mock
HTTP tests are not hosted learner proof.


## Undeployed Supabase Edge binding — 2026-11-11

The fixed function path is `/functions/v1/quiz-report-v2`. Its source entrypoint
is `supabase/functions/quiz-report-v2/index.ts`, with explicit gateway
`verify_jwt = true` in `supabase/config.toml`. The gateway JWT check is retained;
the handler additionally calls the configured project's Auth `/user` endpoint
through `SupabaseAuthVerifier` before opening PostgreSQL. The verified Auth UUID
alone supplies the owner claim for the existing replay-first private transaction.

Required server-only environment names are:

- `ND_QUIZ_REPORT_SUPABASE_URL`: fixed HTTPS project origin.
- `ND_QUIZ_REPORT_SUPABASE_PUBLIC_KEY`: the project's anon/publishable key,
  never a service-role API key.
- `ND_QUIZ_REPORT_DATABASE_URL`: backend-only PostgreSQL URL accepted by the
  existing verified-TLS factory; query strings and fragments are rejected.
- `ND_QUIZ_REPORT_ALLOWED_ORIGINS`: comma-separated exact origins. Wildcards,
  credentials, paths, query strings, fragments and public HTTP origins fail
  closed; HTTP is allowed only for explicitly listed loopback development.

The function never reads a URL/key from request data, does not enable credentialed
CORS, and reflects only an exact allowlisted Origin. Preflight permits POST and
the bounded Supabase transport headers only. Native requests without Origin are
not given CORS headers. Unexpected errors remain fixed/redacted and responses
remain no-store/nosniff.

This is source registration and Deno bundle/test coverage only. No Supabase
project environment has been configured, no function has been deployed, and no
hosted signed-JWT A/B, PostgREST/RLS, real Edge-runtime TLS/CA or learner save
acceptance is claimed. The Flutter transport remains opt-in; default quiz save,
mastery, SRS mutation and study credit remain disabled.

## Caller-owned runtime transport gate — 2026-11-11

The opt-in PersistentSupabaseRuntime can now expose the existing
QuizReportV2HttpTransport through QuizReportV2TransportSource. The trusted
staging build flag is ND_QUIZ_REPORT_TRANSPORT; it defaults to false and is
validated before any disk/SDK resource is opened. The default preview has no
source/provider override. AccountStartupController and the Windows staging
owner forward the borrowed capability, while the Riverpod provider additionally
requires AccountPhase.ready, an own profile and a live study runtime.

The runtime owns the transport and its read-only SupabaseQuizReportV2Auth
observer. The observer now also listens to account/profile readiness changes;
a transition away from the ready owner invalidates its generation, so a held
request cannot survive profile revocation even if the SDK access token itself
has not changed. The existing transport continues to capture the exact token,
abort on generation change, validate the correlated response and never retry
automatically. Runtime shutdown aborts the transport and disposes the observer
before the Supabase SDK client.

This is transport availability only. No quiz screen invokes it, no local
history is marked saved by it, and no default/preview save action is enabled.
The caller must explicitly submit an immutable v2 report and reconcile an
uncertain event ID against authoritative history before any retry. The Edge
Function remains undeployed/unconfigured; no hosted JWT/PostgREST/RLS, learner
A/B, server history read, mastery, SRS or study-credit acceptance is claimed.

## Edge request-body lifetime

The CORS wrapper initiates cancellation of any remaining request body after
its response path settles, including denied origins, all preflight replies and
unexpected handler failures. Cancellation is best effort and is never awaited:
an untrusted stream's rejected or stalled cancel callback cannot replace or
hold the safe response. A locked reader remains its owner's responsibility;
the inner HTTP boundary retains its bounded read/reader-cancel/release logic.
Accepted requests reach that boundary unchanged and are not cancelled before
it finishes consuming the raw bytes. This is in-process Node/Deno regression
evidence, not a deployed Edge or hosted learner acceptance claim.

## Internal v2 receipt lookup after an uncertain submission

The trusted backend now exposes an internal
`lookupVerifiedQuizReportV2Receipt` helper and a fixed-configuration factory.
The caller must retain and supply the original immutable v2 request bytes,
not only a client event ID. The helper applies the same strict raw decoder,
verifies the Bearer token through the configured Supabase Auth verifier before
opening PostgreSQL, binds only that verified UUID to `auth.uid()` inside one
bounded owner transaction, and invokes only
`private.replay_quiz_report_v2`. Lookup mode checks only private-schema usage,
replay-function execution and receipt SELECT capability; its transaction
surface rejects content validation and store calls.

A found receipt is decoded against the captured original request before
COMMIT, including the event ID, level, quiz type, practice kind, completion
instant and answer counts. A changed request under the same owner/event returns
the existing safe `SYNC_CONFLICT`; another owner sees no receipt. A successful
miss returns `status: unresolved` with the captured event ID. It is not a
negative acknowledgement and never authorizes resubmission. The caller must
retain the original event ID/request and reconcile again later; no automatic
retry is introduced. Auth failure opens no database connection, while
cancellation, timeout or malformed receipt remains a safe failure rather than
an unresolved miss.

This is a replay-only internal server capability using the existing private
ledger and owner advisory lock. It adds no migration, grant, public RPC, HTTP
route, Edge registration, default quiz save, mastery, SRS mutation or study
credit. Unit tests cover invalid input/Auth, read-capability denial, cancellation,
miss/found, response correlation and absence of content/store dispatch. Native
disposable PostgreSQL covers synthetic TEST ONLY Auth A/B ownership and changed
payload conflict; it is not hosted JWT/PostgREST/RLS or learner evidence.

## Internal receipt lookup HTTP adapter

`createQuizReportV2ReceiptLookupHttpHandler` accepts only a trusted
`QuizReportV2ReceiptLookup` assembled by the server. It shares the existing
submit HTTP boundary's POST-only JSON/Bearer checks, 16 KiB raw-byte limit,
content-length/encoding checks, bounded deadline, disconnect cancellation,
no-store response headers and safe error mapping. It forwards the original
bytes without parsing or normalizing them; strict decoding, verified Auth and
request-correlated receipt validation remain the trusted lookup's responsibility.

Successful lookup returns HTTP 200 with the existing internal discriminated
result: `{status: "found", response: ...}` or
`{status: "unresolved", client_event_id: ...}`. Unresolved is not absence proof
or retry authority. A conflict, cancellation or internal failure remains an
error and is never converted to unresolved. The adapter invokes the lookup
once, has no submit fallback and suppresses late results after cancellation.
The submit wrapper retains its original response shape and behavior.

This helper registers no public route or Edge Function and changes no frozen
endpoint contract. CORS/Edge assembly, a reviewed public lookup contract,
caller-owned client transport/reconciliation and hosted learner verification
remain outstanding; default quiz save stays disabled.


## Request-correlated nd-quiz-report-2 lookup response — 2026-11-12

The separate v2 schema now defines `lookup_response` as a strict discriminated
union: `found` carries the original `response`; `unresolved` carries only the
captured `client_event_id`. The new
`createQuizReportV2LookupResponseDecoder(schema, originalRequestBytes)`
captures and validates the original immutable request before decoding lookup
bytes. A found receipt must match every request identity field and the expected
answer/correct counts; an unresolved result must echo the same event ID. Both
branches reject extra/missing fields, use the bounded duplicate-aware raw JSON
guard, and return frozen objects. A malformed lookup result is a safe
`INTERNAL_ERROR`; an invalid captured request remains `VALIDATION_FAILURE`.

An unresolved lookup is deliberately not a negative acknowledgement and never
authorizes resubmission. The caller must retain the original event ID and exact
request bytes and reconcile again later. This is a contract/decoder increment
only: no lookup HTTP route, Edge binding, grant, default app save, mastery, SRS
mutation or study credit is activated. V1 request/response and the existing v2
submit request/response definitions remain unchanged.

## Lookup CORS/HTTP composition

`createQuizReportV2ReceiptLookupEdgeHandler` composes the existing exact-origin
CORS gate with the bounded lookup HTTP handler. The caller supplies a trusted
verified-owner lookup and fixed allowed origins; this factory reads no
request-selected project/key and registers no route. Accepted preflight and
rejected origins never invoke lookup. Allowed-origin authentication/errors
remain CORS-readable with no-store headers; CORS grants no ownership authority.
Raw POST bytes, cancellation and deadline flow through the existing HTTP
boundary. There is no submit fallback or retry, and unresolved stays unknown.

Composition tests use TEST ONLY callbacks, not live Auth/SQL. They cover ingress
gates, exact bytes/unresolved, redacted failures and disconnect propagation.
Trusted deployment assembly, public lookup registration, caller-owned client
transport/conditional reconciliation and hosted learner proof remain pending.

## Supabase receipt lookup entrypoint

The fixed lookup path is `/functions/v1/quiz-report-v2-lookup`. Its source
entrypoint uses the same four server-only environment settings as submit and
explicit gateway `verify_jwt = true`. It initializes the Node compatibility
globals before loading PostgreSQL. The trusted lookup verifies the bearer with
Supabase Auth, derives the owner from the verified UUID and uses only the
existing private replay transaction. The handler accepts the original v2
request bytes and returns a correlated `found` or `unresolved` result.
An unresolved result provides no permission to resend the report.

CI type-checks and bundles both entrypoints and checks both JWT registrations.
The lookup source is registered for future deployment. Hosted JWT, TLS/RLS,
learner A/B and app reconciliation remain to be verified before activation.

## Caller-owned Flutter v2 receipt lookup — 2026-11-12

The existing opt-in `QuizReportV2HttpTransport` now exposes
`lookupReceipt(originalReport)` against the fixed
`/functions/v1/quiz-report-v2-lookup` path. It sends the exact same bounded
original request bytes and uses the same caller-owned Supabase Auth snapshot,
generation checks, abort-on-account/token/profile replacement, timeout,
response-size and safe-header/error rules as submit. No learner-supplied URL,
key or endpoint is accepted.

The adapter strictly decodes the `found` / `unresolved` union against that
original request. A found response must match its event/type/kind/level/exact
completion instant and derived answer counts. An unresolved result must echo
the original event ID and carries no response. Extra/missing fields, changed
event IDs or mismatched nested responses fail closed.

Lookup is read-only and makes exactly one lookup request. It never calls submit,
retries, marks local history saved, mutates progress/mastery/SRS or grants study
credit. Unresolved is not a negative acknowledgement and never authorizes
resubmission; retain the exact original attempt/event ID and reconcile again
later. The existing caller-owned runtime/provider readiness gate remains
opt-in; default preview and quiz save UI stay disabled.

Flutter Mock HTTP/SDK tests cover exact original bytes, fixed endpoint,
found/unresolved correlation, no submit fallback and late account replacement.
This does not prove a deployed Edge Function, hosted signed-JWT/PostgREST/RLS,
learner A/B, durable multi-device attempt sync or Personal Alpha acceptance.


## Caller-owned receipt lookup shutdown — 2026-11-12

The opt-in Dart transport now tracks each active submit/lookup operation. Its
awaitable `close()` revokes new dispatch immediately, aborts active HTTP requests,
waits for every accepted operation to settle, and only then closes an HTTP client
that the transport itself created. A supplied client remains borrowed and is not
closed by the transport. `dispose()` remains a fire-and-forget compatibility
wrapper; owners of dependent resources must await `close()`.

`PersistentSupabaseRuntime.close()` first revokes the transport getter and
starts transport close, then invalidates account readiness. It awaits transport
drain before disposing the borrowed Supabase Auth observer, closing the SDK port
or disposing the Supabase client. This preserves the request's cancellation and
safe-error boundary while preventing an active lookup from outliving its owner.

This is lifecycle/fixture evidence only. Lookup remains read-only; unresolved
never authorizes submit, retry or local-history release. Default preview/save
remains disabled. No hosted receipt, learner A/B, PostgREST/RLS or Personal Alpha
acceptance is inferred.
