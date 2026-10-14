# Additive due-queue read contract — nd-review-queue-1

Decision/impact review, 2026-10-14, refs #22/#20/#15: the /srs controller previously
had only an abstract queue port. Add `get_review_queue(p_request jsonb)` and the
versioned schema in `contracts/review_queue/v1/schema.json`. This is a bounded
read bridge, not an Auth strategy change, SDK installation, hosted deployment or
Personal Alpha release. The eight frozen v0.1 operations/models are unchanged.

Request: exactly `jlpt_level` (N5–N1) and integer `limit` (1–100). Dart's current
Personal Alpha UI supports N5/N4 only. RPC transport wraps them in `p_request`;
owner/user ID, client clock, arbitrary table/filter/order and scheduling fields
are forbidden. Limits must be explicitly provided; no implicit enrollment.

Success: exactly `jlpt_level`, `server_time`, `items`. Each item has exactly
`item_type`, `item_id`, `prompt_ja`, `reading_ja`, `answer_vi`, `next_review_at`.
Instants are UTC Z with at most six fractional digits; native SQL emits six.
Text is bounded to 5000 Unicode code points, nonblank prompt/answer. Reading is
explicitly empty when a canonical reading is absent. Errors use the unchanged
three-field v0.1 error object and safe retry semantics, never SQL details.

## Read/security semantics

- `SECURITY INVOKER`, STABLE, empty search_path, qualified tables, no dynamic SQL.
  Caller RLS remains active and explicit `user_id=auth.uid()` further narrows reads.
  Only authenticated has EXECUTE. No new table grants, policies, private-schema
  access, elevated read function or scheduling write is introduced.
- A valid caller identity and owned provisioned profile are required. Profiles
  are not provisioned by this read; #20 must implement trusted provisioning from
  verified Auth identity. SQL role/sub-claim fixtures do not verify JWTs.
- Use statement_timestamp(), not a client date or a transaction-start date that
  can remain stale in a long transaction. Read the active curriculum at the SQL
  statement snapshot; include only the caller's reviewed LEARNING/REVIEW/RELEARNING
  items with next_review_at <= captured server time and the requested level.
- Exclude NEW, null due dates, reserved MASTERED, future/retired/wrong-level items.
  A fresh account has an empty queue, not fake progress. New curriculum enrollment
  and initial study remain #12/#22 integration work.
- Order by due time, item_type in C collation, UUID; apply limit **after** active
  content filtering. This is a snapshot, not a reservation or a total due count.
  Refresh after authoritative review writes to obtain the next bounded page.
- Vocabulary maps expression/reading/meaning; Kanji maps character/published
  onyomi+kunyomi/meaning. Grammar maps pattern/meaning with empty reading because
  no canonical pattern-reading field exists. Do not mislabel an example reading.
- Parsed request is bounded to 32 KiB. Gateway must bound bytes before allocation
  and enforce deadlines. Corrupt/oversized trusted content or BC/out-of-range due
  timestamps fail closed. A read never creates items, increments counters, updates
  cards or appends events. Existing derived-state write restrictions remain.

## Dart bridge and evidence

`RpcSrsStudyQueue` invokes the read RPC over the same captured-session transport
port as review writes. `ReviewQueueSnapshot` strictly checks envelope/row fields,
level/limit, UTC microsecond instants, due <= server_time, normalized duplicate
keys, ordering and bounded typed content. Errors are converted to safe codes;
timeouts are not fake empty success. Account replacement before/during read
rejects the old result. Empty reading renders explicit absence on /srs.

The real Supabase SDK/Auth transport and runtime binding are **still missing**.
Default srsStudyRuntimeProvider remains null; no secret, token cache, login,
network connection, enrollment or persistent learner flow is activated here.
Same-process UI state is not a durable offline queue; #15 retains that work.

Reproduce with a new empty disposable PostgreSQL 17, never hosted/production:
`bash scripts/test_database.sh` runs retained suites/races and the queue suite,
then exports actual SQL role-fixture responses to `build/review-queue-sql.json`.
Seven cases cover A/B owner/history, N5/N4, bounded limit, empty, missing identity
and forged-owner errors. Assertions also cover future/retired/NEW filters, all
levels, malformed requests, unknown profile, invoker/grants, oversized trusted
reading, BC timestamps and unchanged rows/events.

CI publishes this actual SQL output artifact. Flutter depends on that successful
database job and downloads the artifact from the **same run**, passes it through
the real Dart decoder/RPC queue projection, then validates emitted JSON with
`python3 -m contracts.validate_review_queue`. Prior-run metadata/artifacts are not
used. This is observed SQL-to-Dart fixture data flow, not a PostgREST SDK request,
real Auth/JWT/expired token, signed-in UI journey or multi-device evidence.

`contracts/review_queue/v1/fixtures.json` and unit tests are hand-authored **TEST
ONLY** inputs, not generated SQL evidence. Schema validation alone never proves
their origin; local verifier success must be reported as fixture-only. Full #22
and Personal Alpha remain pending concrete SDK/Auth/runtime/durable integration.

Primary references checked 2026-10-14:
- https://www.postgresql.org/docs/17/sql-createfunction.html
- https://www.postgresql.org/docs/17/ddl-rowsecurity.html
- https://www.postgresql.org/docs/17/functions-datetime.html
- https://supabase.com/docs/guides/database/functions
