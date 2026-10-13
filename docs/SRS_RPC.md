# Local atomic review transaction — Issue #22

This is an additive **local SQL implementation increment**, not a deployed
Supabase endpoint or an integrated Flutter review feature. Issue #22 remains open
for typed transport/UI and real JWT/PostgREST acceptance. No production migration,
Auth strategy change, new provider, paid request or secret is included.

## Wire and identity boundary

`public.submit_review(p_request jsonb)` accepts the frozen seven-field
`submit_review_request`. A future typed repository wraps `SrsReview.toJson()` in
`{'p_request': ...}` for Supabase RPC transport. The inner request and five-field
success response are unchanged; errors are the three-field frozen error object.

The function derives its owner **only from auth.uid()**, checks that identity
exists in auth.users, and rejects missing/malformed identity. Actual Supabase
JWT signature/issuer/expiry/project checks belong to the verified Auth/PostgREST
boundary; `SET ROLE` and test sub claims do not prove that integration. #20/#22
must still observe it. No user_id, derived card/counter/date or arbitrary learning
item owner is accepted from the request. Active curriculum is shared read content;
item_type determines the actual vocabulary/Kanji/grammar table, not client state.

The RPC is SECURITY DEFINER because clients cannot directly insert review events
or update derived scheduling fields. Its empty search_path, schema-qualified
relations, caller predicates and no dynamic SQL retain that write boundary.
Only authenticated has EXECUTE. PUBLIC/anon/service_role lack the RPC grant, and
all new private validators/scheduler lack client/backend execution grants. Direct
table grants/RLS, append-only triggers and owner FKs remain unchanged. The migration
owner remains trusted; applying/deploying it is separate from this local delivery.

Input checks reject missing/unknown/null fields, wrong JSON scalar types, malformed
UUIDs, non-integer/out-of-range rating/duration, contradictory correctness and
invalid calendar/time/offset syntax. Integer-valued JSON numbers (e.g. 2.0) remain
valid integers; strings are not coerced. Resource limits are 32 KiB of parsed JSONB
text and 4096 timestamp characters. PostgREST must bound network bodies *before*
JSONB conversion and configure request/lock deadlines; this function cannot bound
an already allocated gateway body or verify transport tokens.

## Transaction, chronology and replay

1. Validate/canonicalize request UUIDs and event instant.
2. Acquire an owner-scoped transaction advisory lock. The same event submitted for
   different items is serialized too; a hash collision only serializes another
   owner and cannot grant authority. Current implementation trades per-user
   throughput for simple personal-app correctness.
3. Replay original immutable receipt before stale/skew/active-content checks.
   Changed input under that owner/event conflicts; key order, UUID capitalization,
   equivalent timezone instants and trailing fractional zeros are canonicalized.
   Stored responses are revalidated before returning; corrupt receipt JSON fails
   closed and cannot expose unexpected private fields.
4. Enforce future skew <=300 seconds against server clock; lock active content
   FOR SHARE, bind/create the owner's unique item and lock it FOR UPDATE.
5. Reject stale new events, run the private nd-srs-1 policy port, validate the
   five-field response and atomically update scheduling plus append one event.

The PL/pgSQL exception block rolls back all writes before returning a fixed
Vietnamese error, including a newly created item and counters changed before an
injected event-write failure. No SQL/trigger details are returned. Replay after
later reviews or curriculum retirement returns the original result unchanged.
Read/correct/incorrect counters advance exactly once. stability/retrievability
are preserved, not fabricated. MASTERED remains reserved; invalid/overflowing
trusted card state fails closed. No automated retry or client overwrite is added.

Exact canonical fractional digits are kept in request_json and occurred_epoch
metadata; differing sub-microsecond events do not collapse into identical retries.
Scheduling/card/event timestamps truncate to integer microseconds, matching Dart
DateTime policy, while metadata tracks exact chronology by the accepted review
count. next_review_at is UTC with six fractional digits. Timestamp conversion is
independent of session timezone and handles explicit wire offsets through 23:59.
Algorithm version nd-srs-1 and sequence count are internal metadata, not new wire
fields. Legacy state without this metadata falls back to its stored last instant.

Native tests use ordinary READ COMMITTED transactions. Higher-isolation or other
trusted writers may produce serialization/lock errors; retry immutable events
rather than recomputing/overwriting client state. Do not assume a client timeout
means the server transaction failed: fetch/retry the same event for original replay.
The response validates schema shape; authorization comes from the transaction,
never from model/provider output or the supplied request.

## Reproduce and evidence limits

Use a **new empty disposable PostgreSQL 17** database, never production/hosted:

```bash
python3 -m pip install -r contracts/requirements.txt
bash scripts/test_database.sh
```

The retained bootstrap/RLS/AI suites run first, then review_rpc.sql (62 assertions),
actual private SQL output compared against all 26 frozen Dart policy cases and
five native-session RPC races: identical, changed input, distinct events,
same event/different item and first transaction rollback. Races check original
responses, final event/item counts and scheduling counters. SQL role fixtures are
not expired JWT, gateway, browser or multi-device evidence.

`verify_review_parity.py` compares all state/response fields, exact instants and
finite numbers against hand-authored golden cases. Six Python mutation regressions
protect missing/duplicate cases, microsecond drift, bad counters/state/fields and
valid offset equivalence. Expected fixtures are TEST ONLY, not generated evidence.
A PGlite run can exercise the migration/assertions/parity but cannot establish
native two-session contention. CI supplies native PostgreSQL 17 evidence only
when its actual current-head jobs are observed successful.

Remaining #22 acceptance: typed RPC adapter/error decoding, complete SRS UI flow,
missing/expired real Auth/PostgREST requests, authenticated non-production learner
journey and retry/restart integration with #15/#20. Keep the PR draft/issue open
until its declared acceptance is actually observed; baseline green is not release.

Primary design references checked 2026-10-13:
- https://www.postgresql.org/docs/17/sql-createfunction.html (definer/search_path/grants)
- https://supabase.com/docs/guides/database/functions (caller-bound definer boundary)
- https://supabase.com/docs/guides/database/postgres/row-level-security (auth.uid/RLS)
