# Quiz report boundary — nd-quiz-report-1 (specified, undeployed)

## Issue #13 audit and bounded delivery

At source f5308cf66136b79e349c2e1163096daf9b06e910, quiz rounds, immutable
owner-bound local journals, explicit history/progress, current-content weak points
and nd-quiz-recall-1 milestones have component evidence. Hosted attempts, sync,
verified learner identity and a mastered-item projection remain incomplete.
The SQL baseline has per-item quiz_attempts rows and restrictive owner read RLS;
it has no authenticated round-report mutation/receipt. Those rows also require a
duration_ms that current local reports do not measure. Do not fabricate zero
duration, reuse SRS receipts, grant direct writes or call a native journal cloud sync.

This increment supplies a separate wire specification, executable JSON/semantic
validator, fixtures and mutation tests. It does not implement an RPC, migrate a
DB, send reports, activate collection or authorize deployment. Frozen v0.1,
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

No endpoint, server-side parser, ledger, grant, RPC adapter or replay transaction
exists for this proposed operation yet. No hosted/learner acceptance follows from
these fixtures. Issue13 and all14 release gates remain open.

## Prior evidence

[CI41180091136](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41180091136)
passed exactf5308cf/latestattempt1/allfive/every step. Raw Flutter124475881165
confirms the extended owned dual-store dashboard journey; Windows124475602208
confirms grammar/evidence/persistent SDK markers. This is TEST ONLY component
proof; it does not execute the new contract tests. Their exact new-head CI and
publication are recorded in PR41/PROJECT_STATUS.
