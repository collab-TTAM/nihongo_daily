# Quiz report boundary — nd-quiz-report-1 (specified, undeployed)

## Reusable raw-ingress guard primitive — 2026-10-31

backend/ai/src/strict_json.ts now exports parseQuizReportJsonBody(Uint8Array)
for a future quiz ingress adapter. It checks the original byte length (16 KiB
maximum), fatal UTF-8 decoding, BOM rejection, duplicate decoded object keys
at every depth, integer-only numeric lexemes and safe integer representation
before any JSONB conversion. The helper returns an object only; it does not
perform the nd-quiz-report-1 schema check, verify Auth, validate active
curriculum/ordered choices, acquire the owner lock, or call the private ledger.

The same module supplies duplicate-aware parseStrictJson to the existing AI
request decoder. The quiz-specific guard is tested with valid, exact-limit,
oversized, invalid UTF-8, duplicate/escaped-key, decimal/exponent, deep and
trailing-body cases. It is a reusable internal primitive, not a public endpoint
or an activated collection path. The private ledger remains inaccessible to
app roles; no RPC, migration, grant, upload or default app behavior changed.

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

No public endpoint, strict raw-ingress adapter, canonical-content validation or
Dart RPC adapter exists yet. The private decoded ledger above is a foundation only. No hosted/learner acceptance follows from
these fixtures. Issue13 and all14 release gates remain open.

## Prior evidence

[CI41180091136](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41180091136)
passed exactf5308cf/latestattempt1/allfive/every step. Raw Flutter124475881165
confirms the extended owned dual-store dashboard journey; Windows124475602208
confirms grammar/evidence/persistent SDK markers. This is TEST ONLY component
proof; it does not execute the new contract tests. Their exact new-head CI and
publication are recorded in PR41/PROJECT_STATUS.
