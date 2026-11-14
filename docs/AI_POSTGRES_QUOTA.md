# Private PostgreSQL AI request quota

`20261022091000_ai_rate_limits.sql` adds one private row per verified Auth user
and `private.consume_ai_quota(uuid,text)`. This is an undeployed database component
for #31. The opt-in Node driver/RateLimiter binding is in AI_POSTGRES_RUNTIME.md.
It does not assemble an Edge endpoint, select a provider, enable paid calls, change
Auth strategy or alter the
ordinary app preview. Live production configuration/deployment remains separate.

## Policy and ownership

All five existing AI operations share the same user bucket; changing operation,
HTTP worker or connection cannot create more capacity. No device, IP, transcript,
credential or new learner attribute is collected. The row contains only the
existing Auth UUID, numeric tokens, server refill timestamp, UTC budget date and
successful-reservation count. The Auth FK is restrictive; no deletion/pruning or
refund endpoint is introduced.

The initial, undeployed policy is a burst of10, refill of one token per6 seconds,
capped at10, and at most100 successful request reservations per UTC calendar day.
Day rollover resets only the daily counter, preserving the shared burst budget.
This is a rate guard, not a provider billing/token-cost ceiling or production SLA.
UTC is independent of learner timezone/device dates. Policy changes require an
explicit reviewed migration; clients cannot supply time, capacity, rate, day,
counter, operation namespace or a replacement identity.

Only the trusted backend may invoke the helper. It must derive the UUID from the
existing verified Auth port, validate the request and preserve user JWT/RLS
checks elsewhere. The private table has RLS enabled and no client policies or
PUBLIC/anon/authenticated grants. The function is SECURITY INVOKER with an empty
search_path and qualified relation names. Only service_role receives execution
and necessary SELECT/INSERT/UPDATE; DELETE/TRUNCATE/TRIGGER/REFERENCES are not
granted. As with the existing receipt helpers, service_role is a trusted bypass-
RLS backend capability, not a learner credential or sandbox against compromised
server code. No public PostgREST RPC or arbitrary-owner client operation is added.

## Atomicity, clocks and dispatch

Validate the owner/operation, insert the one user row with ON CONFLICT DO NOTHING,
then SELECT FOR UPDATE it. Concurrent first creators wait on the unique key;
subsequent workers serialize on the row. Sample clock_timestamp only after the
row lock is acquired to avoid stale transaction/statement-start time after waits.
If either server time or UTC day moved backward relative to stored state, deny
without resetting counters or minting tokens. Denial does not update refill/debit
state. Successful refill and the burst/daily debit happen in one transaction.
Fractional refill is retained in numeric arithmetic; long idle refill caps at10.

The trusted SQL adapter (see AI_POSTGRES_RUNTIME.md) must execute a short READ COMMITTED transaction,
apply bounded database lock/statement/network deadlines and return true only
AFTER a confirmed COMMIT. Return false on denial; map SQL, cancellation, transport,
serialization and commit uncertainty to existing fixed safe errors. Never
return allowed on an exception, retry consumption automatically, refund after
provider dispatch, or fall back to process-memory limits. An uncertain commit
may have consumed capacity; no provider call is authorized by that uncertainty.
Do not hold this quota row lock during a provider call or conversation transaction.

AiService currently applies its mandatory limiter before receipt lookup. The
same policy counts valid retries/replays as requests, not unique client events
or billed provider calls. A confirmed reservation does not authorize session/
content access, create a receipt dispatch owner or permit a duplicate upstream
call. Existing durable pending/claim/reconciliation requirements still apply.
Quota rollback is safe only before dispatch; a later failure does not imply a
refund or a fresh dispatch claim. None of the receipt tables/helpers change.

## Verification and outstanding runtime binding

On an empty disposable PostgreSQL17 database with TEST_DATABASE_URL configured:

```sh
bash scripts/test_database.sh
```

The retained database CI step runs the new SQL suite and native concurrency
script in addition to every existing SQL/RLS/receipt/review/plan/study gate.
`supabase/tests/ai_rate_limits.sql` checks all five operation names share one row,
A/B independence, ten burst grants/eleventh denial, fractional/capped refill,
last daily slot and cross-operation cap, UTC day change without burst reset,
clock rollback, null/unknown/nonexistent inputs, fixed invoker path, RLS/ACLs,
invalid stored values, denied DELETE/TRUNCATE and rolled-back first/existing rows.
Fixture-only direct state edits simulate elapsed/day boundaries; the production
helper has no fake clock or quota override parameters.

`test_ai_quota_concurrency.py` uses independent native psql processes and a
bounded binary readiness barrier. It observes the second connection actually
waiting on a lock via pg_stat_activity before releasing the first. Cases cover
first creation, last daily slot and a rolled-back contender across different
operations; another owner proceeds while the first remains locked. Fresh
connections verify exactly one row, committed debit counts and retained denial.
Allowed waiters must persist a refill timestamp after the release-time floor,
which rejects sampling transaction/statement time before the wait. Rollback and
same-database reconnect are not a database crash/physical power-loss certificate.

Local PGlite0.5.9 executed all migrations, the retained baseline/AI receipt suites
and new quota assertions. Python compilation/bash syntax/QA checks also ran.
PGlite is single-connection embedded PostgreSQL and does not prove native
multi-session locking. No local psql/PostgreSQL17 or Dart/Flutter/Windows SDK was
available. Exact-head native CI and complete platform gates must be observed.
Hosted Auth/PostgREST, actual runtime limiter binding, Deno/Edge, conversation
transactions and provider/learner evidence remain open in #31/#17/#18. The
14 pending hosted release groups are unchanged.

Primary PostgreSQL17 references checked2026-10-22:
- https://www.postgresql.org/docs/17/explicit-locking.html
- https://www.postgresql.org/docs/17/functions-datetime.html

## Observed native component evidence

Source b65f5cc681b4d70ccbe9229933ba2dd823998168 passed allfive jobs/every step
in CI39754447718 attempt1. Completed database logs explicitly show allthree native
quota first_create/last_daily_slot/rollback observed-lock/isolation/fresh-connection
checks passed. This verifies the SQL component; the subsequently added driver
composition still requires its own exact-head checks and hosted gates.
