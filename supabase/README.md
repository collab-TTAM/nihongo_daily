# Supabase storage baseline

This directory contains an additive PostgreSQL migration, not a deployed service.
The Flutter app still uses its labeled preview repository. No live credentials,
production changes, authentication provider changes or AI provider calls are made.

Issue #11 adds a narrowly scoped authenticated Daily Plan snapshot RPC in
`20261019150000_daily_plan.sql`. It preserves existing user/date plans and derived
progress and keeps unavailable services blocked. This is an additive local/CI
migration, not deployment or study-session integration. See
[`docs/DAILY_PLAN.md`](../docs/DAILY_PLAN.md) for the definer boundary, frozen
payload mapping, allocation policy and native role/wire/concurrency checks.

## Reproduce verification

Use an **empty disposable PostgreSQL 17 database**, owned by the migration user:

```bash
export TEST_DATABASE_URL=postgresql://postgres:postgres@localhost:5432/nihongo_test
bash scripts/test_database.sh
```

The URL above is a disposable local/CI example, never a project credential. The
script installs a minimal test-only `auth.users` / `auth.uid()` and API role
fixture, applies every migration in filename order, executes SQL assertions with
real `SET ROLE`, and starts two native PostgreSQL sessions for the duplicate-key
race. `bootstrap.sql` must never run against Supabase or an existing database.
The script is deliberately not repeatable on an already initialized database.
Create a fresh test database for each run.

Daily Plan's actual SQL wire validation also requires the existing pinned
`python3 -m pip install -r contracts/requirements.txt`; the database CI job
installs it before running the retained SQL tests and new plan checks.

CI's `database` job uses a PostgreSQL 17 service and runs this same script. The SQL
baseline was also executed locally with PostgreSQL 18.6 through PGlite 0.5.9;
that local execution cannot verify native-session concurrency or Supabase's JWT,
GoTrue, PostgREST, storage or hosted environment. Those need later integration
checks. No expiration/authentication claim is inferred from a test JWT setting.

For a local Supabase stack, initialize CLI configuration separately, then use the
usual `supabase start` / `supabase db reset` migration workflow. Do not apply
`tests/bootstrap.sql`: the real stack already supplies Auth and API roles.
Hosted migration/deployment remains a separate reviewed operation. No production
connection is requested by the tests.

## Security boundary

- Every public project table enables RLS, including curriculum and relationship
  tables. `anon` and `PUBLIC` have no table grants, even under older broad defaults.
- `authenticated` reads only its own rows, messages whose parent session it owns,
  and active curriculum/examples/relations. Only allowlisted own-profile settings
  can be updated directly. No client insert/delete or derived-state updates.
- Scenario `system_context` stays backend-only via column-level SELECT grants.
  Adapters select safe columns explicitly; `select *` on this table is rejected.
- `service_role` is trusted and bypasses RLS. It gets explicit DML grants, not
  TRUNCATE. Keep it backend-only and verify end-user identity before every write.
- Functions are invoker functions with empty `search_path` and qualified tables;
  private schema/function access is revoked from clients. No security-definer RPC
  is exposed in this baseline. Trigger functions cannot be called as RPCs.
- IDs/owners/parent-message identity are immutable. Review events cannot be edited
  or deleted. Curriculum is retired with `is_active=false`; restrictive FKs retain
  history. Account deletion is not implemented and needs the applicable human gate.
- Profiles are provisioned by a trusted integration using the verified Auth user
  ID. There is no signup trigger or reliance on untrusted auth metadata yet.

## Storage/export mapping

| Wire field | Normalized storage |
| --- | --- |
| vocabulary.examples | vocabulary_examples ordered by sort_order |
| grammar.examples | grammar_examples ordered by sort_order |
| grammar.related_grammar_ids | grammar_relations.related_grammar_id |
| scenario target_grammar / target_vocabulary | scenario_grammar / scenario_vocabulary |
| item_type + item_id | generated typed FK columns on learning items and quizzes |

Export adapters reconstruct arrays and omit generated typed-FK storage columns.
The wire contracts are unchanged. The content importer must validate complete
bounded JSON contracts, examples, array cardinality/order and related IDs before
publishing; baseline database JSON shape checks alone do not validate a full API
response. Source-specific learning_errors references remain backend-validated.

## Idempotency handoff

`review_events` has unique `(user_id, client_event_id)`, same-owner composite FK,
immutable `request_json` and original `result_json`. The internal invoker helper
`private.review_replay(user_id, request)` returns the stored original result,
returns NULL for an unseen ID and raises `SYNC_CONFLICT` for changed input. It is
only callable by trusted SQL/backend code; never accept an arbitrary client user
ID. Canonicalize validated timestamps/fields before storing/comparing request JSON.

**This is storage support, not a working submit_review API.** Issue #22's integration after scheduler #4
must authenticate, reject unknown fields, lock the user's learning item, replay
before stale-time checks, validate rating/time skew/content, schedule on the server,
and atomically append event/update state. Race losers must re-read the committed
receipt and compare the request; they must not turn uniqueness errors into silent
success. API-level rollback/skew/offline retry tests remain required there.

Operation receipts add PENDING/COMPLETED state and immutable completed responses.
Issue #7 must implement provider-call ownership, pending recovery, request/output
validation and fault tests; this table does not itself prevent provider duplicates.
Daily Plan/session/progress endpoints are #11/#13; real auth and sync integration
must separately test provisioned users, tokens, restarts and two clients.

Reference design sources (checked 2026-10-13):
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/database/postgres/column-level-security
- https://supabase.com/docs/guides/database/functions
- https://www.postgresql.org/docs/17/ddl-rowsecurity.html

Timezone compatibility: accept the documented Asia/Saigon alias and normalize it
to canonical Asia/Ho_Chi_Minh before storage. Some native tzdata builds omit the
backward alias; converting stored canonical names keeps the Vietnam UTC+7 plan
semantics available. Invalid zones still fail. Tests cover default/settings alias
normalization and actual timestamp conversion. Use the stored timezone for plans.

Issue #7 adds private AI receipt lookup/dispatch-claim/token-completion helpers and
native claim-race/security tests. No deployed conversation/AI runtime is implied;
see `../docs/AI_BOUNDARY.md` for required validation/transaction/recovery binding.
