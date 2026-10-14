# Local atomic review transaction — Issue #22

This is an additive **local SQL and typed Dart repository increment**, not a deployed
Supabase endpoint or an integrated Flutter review feature. Issue #22 remains open
for SDK/Auth/queue binding and real JWT/PostgREST/UI acceptance. No production migration,
Auth strategy change, new provider, paid request or secret is included.

## Wire and identity boundary

`public.submit_review(p_request jsonb)` accepts the frozen seven-field
`submit_review_request`. The typed RpcReviewRepository wraps `SrsReview.toJson()` in
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
responses, final event/item counts and scheduling counters. Each race observes
the second backend waiting on the advisory lock before releasing the first
transaction; a delay alone is not counted as contention. SQL role fixtures are
not expired JWT, gateway, browser or multi-device evidence.

`verify_review_parity.py` compares all state/response fields, exact instants and
finite numbers against hand-authored golden cases. Six Python mutation regressions
protect missing/duplicate cases, microsecond drift, bad counters/state/fields and
valid offset equivalence. Expected fixtures are TEST ONLY, not generated evidence.
A PGlite run can exercise the migration/assertions/parity but cannot establish
native two-session contention. CI supplies native PostgreSQL 17 evidence only
when its actual current-head jobs are observed successful.

Remaining #22 acceptance: concrete SDK/Auth transport binding, complete SRS UI flow,
missing/expired real Auth/PostgREST requests, authenticated non-production learner
journey and retry/restart integration with #15/#20. Keep the PR draft/issue open
until its declared acceptance is actually observed; baseline green is not release.

Primary design references checked 2026-10-13:
- https://www.postgresql.org/docs/17/sql-createfunction.html (definer/search_path/grants)
- https://supabase.com/docs/guides/database/functions (caller-bound definer boundary)
- https://supabase.com/docs/guides/database/postgres/row-level-security (auth.uid/RLS)

## Typed Dart repository increment

`apps/flutter_app/lib/features/srs/data/review_repository.dart` adds ReviewRepository
and RpcReviewRepository with injected ReviewAuth/ReviewRpcTransport ports. It is
connected to the new study controller via injected runtime ports, not a real SDK.
The default runtime is null and does not call it. The transport must use the captured
authenticated session/client and recheck before dispatch; it must never select a
different account's current credentials implicitly. ReviewSession is a local
identity/lifecycle hint, not a JWT validator. #20 retains real token verification,
refresh and secure storage responsibility.

prepare() captures a session and immutable seven-field event. submit() sends only
`submit_review` with `{'p_request': ...}`. Reusing the prepared event keeps its ID,
timestamp, rating and duration. Logout/account changes replace ReviewSession,
including A -> B -> A; stale events do not dispatch, and an in-flight old-session
result cannot become success for the new session. Server authorization still
comes from auth.uid(). Same-user token refresh may retain the object only inside
the same authenticated lifecycle.

Strict decoded-object validation accepts only the five-field server response or
three-field frozen error. Invalid types, calendar/time/offsets, non-finite numbers,
reserved NEW/MASTERED state and extra/missing/mixed fields fail closed. Success
retains the exact wire due timestamp alongside a UTC microsecond display value.
It does not run a local scheduler or construct/update a stored card. Original
replay results must not overwrite newer cached scheduling state; authoritative
state refresh and durable receipts/queue integration remain #15/#22 work.

Errors expose fixed Vietnamese messages by allowlisted code, never arbitrary
backend/SDK messages, tokens, SQL or headers. A concrete SDK binding must translate
recognized failures to ReviewTransportFailure; unknown exceptions are INTERNAL_ERROR.
Only transient network/provider failures and explicit retryable rate limits allow
retry. Timeout means **unknown outcome**: it does not cancel the server transaction,
generate a new event, redispatch or mark a review saved. Late success is ignored;
manual retry uses the same prepared event.

Reproduce from apps/flutter_app:
`flutter test test/features/srs/review_repository_test.dart` and
`dart run tool/verify_review_adapter.dart build/review-adapter-output.json`.
Then run `python3 -m contracts.validate_srs_wire
apps/flutter_app/build/review-adapter-output.json` at repo root. The tool passes
26 original response fixtures through the real repository/encoder/decoder, tests
strict invalid data, timeout/retry and session replacement, then emits actual
wire encodings. Ports/server responses are TEST ONLY fixtures: this is not a
SQL-to-Flutter, expired JWT, hosted transaction, durable restart or UI test.
Full Flutter regressions also cover all error codes, immutability/account changes.
QA's review-rpc, auth-live and offline-sync release gates remain pending.

Primary Dart references checked 2026-10-13:
- https://api.dart.dev/dart-core/DateTime/parse.html (normalizes invalid components;
  explicit calendar validation is required before parsing)
- https://api.flutter.dev/flutter/dart-async/Future/timeout.html (source may finish
  after timeout; timeout does not prove server rollback)

## SRS study controller/screen increment

The `/srs` route now uses SrsStudyScreen, a Riverpod notifier and the pure Dart
SrsStudyController. `srsStudyRuntimeProvider` is **null by default**: the default
app displays missing Supabase configuration and has no queue/rating/fake success.
Tests alone inject fixture Auth, due queue and RPC replies. This is UI readiness,
not a hosted/persisted learner flow or a Supabase SDK/Auth implementation.

SrsStudyItem is an application-only projection of due curriculum content, not a
new server endpoint or learning state. Future SrsStudyQueue must read an
authenticated owner's due queue/content for the captured session/selected level.
The controller rejects wrong-level, duplicate and >100-item results. #12/#20/#22
still need real content/query and Auth bindings; no new wire contract is claimed.

Load is bounded and generation/session-checked. Prompt is shown before answer;
only after revealing can the user select AGAIN/HARD/GOOD/EASY. Event ID is random
UUID v4, occurred_at is captured once at the first rating, and response_ms uses
bounded monotonic elapsed time. Clock/ID/ticks are injectable only for tests.
Save locks controls immediately: repeated taps or reload cannot send another
event. Only a validated ReviewSuccess increments the local acknowledged count
and advances the snapshot. This is not Daily Plan time, mastery or persisted
progress; no derived schedule/card update or local scheduler is invoked.

Unknown network/timeout outcomes retain the same prepared event and original
rating/time/ID; manual retry cannot regenerate them. Unknown/malformed/internal
responses never become success or permit discarding an uncertain event. Only
explicit definitive rejection (validation/not-found/forbidden/conflict) permits
an explicit rejected-event reload. Late post-timeout results are ignored. Real
receipt reconciliation for nonretryable uncertainty remains #15/#22 work.

Notifier is not autoDispose, so pending retries survive navigation within the
same process. No disk persistence, restart recovery or multi-device evidence is
claimed. Session changes must be emitted synchronously by the future Auth binding:
visible old-user item/answer/receipt and pending references are cleared, and a
generation guard rejects old in-flight load/save results even on A/B/A. A closed
lifecycle stream disables the runtime. Actual token/storage isolation and durable
per-account pending records remain #20/#15; client hints never authorize writes.

Widget tests cover the unconfigured default, reveal/rating/acknowledgment, loading/
empty/safe failures, conflict, route-retained retry, session clearing and 320/375px
at 200% text. Controller tests cover deadline, duplicates, exact retry payloads,
late session/disposal replies, malformed data and UUID/timing bounds. The raw-Dart
tool `verify_srs_study.dart` passes 26 original server-response fixtures through
actual controller/repository encoding with reveal-before-rating, uncertain retry
and old-session suppression, then schema-validates emitted wire pairs in CI.
These fixture responses are **TEST ONLY**, not SQL-to-UI or hosted evidence.

Next: concrete Supabase SDK/Auth/due queue integration, durable event recovery and
real missing/expired JWT/PostgREST and non-production SRS learner evidence. Keep
PR #37 draft and #22/#20/#15 open; Personal Alpha release gates remain pending.

Riverpod 2 lifecycle references checked 2026-10-14:
- https://docs-v2.riverpod.dev/docs/concepts/provider_lifecycles
- https://docs-v2.riverpod.dev/docs/concepts/modifiers/auto_dispose
