# Caller-bound profile bootstrap — nd-own-profile-1 / #20 / #22

This additive RPC makes the existing profile table usable for a verified caller
without giving Flutter INSERT privileges. It does not select a sign-in provider,
change Auth strategy, restore credentials, install a runtime or deploy services.
The eight frozen v0.1 operations and existing tables/RLS/grants are unchanged.

## Contract and privilege review

`public.ensure_profile(p_request jsonb)` accepts only `{}`. No caller ID, profile
settings, email or user/app metadata. Require auth.uid() to parse as a UUID and
match an existing auth.users row; missing/malformed/unknown identity returns the
existing three-field UNAUTHORIZED error. Invalid request returns VALIDATION_FAILURE.
Anon/PUBLIC/service-role execute is explicitly revoked; only authenticated gets
EXECUTE. No direct table INSERT/DELETE grant is added. SECURITY DEFINER uses a
fixed empty search_path and fully qualified Auth/table names. The elevated scope
is solely INSERT of the caller's profile and SELECT of that same row; no learner
state, another profile or provider configuration can be changed by this function.

Insert with existing defaults and ON CONFLICT(id) DO NOTHING. Existing settings
are preserved; new profile timezone is canonicalized by the existing trigger to
Asia/Ho_Chi_Minh (Vietnam alias compatibility). The unique key serializes duplicate
bootstrap; the following SELECT returns the current caller row. Current profile
settings may be concurrently changed via their existing allowlisted RLS path;
bootstrap does not reset them. Any insert/trigger/select failure rolls back this
function body and returns safe INTERNAL_ERROR without SQL detail. Production
deployment and actual signed-token identity validation remain future acceptance.

Success has exactly five fields:

| Field | Rule |
| --- | --- |
| id | Canonical caller UUID, checked against captured Auth by Dart |
| display_name | String, at most 100 Unicode characters; empty allowed |
| preferred_jlpt | N5/N4/N3/N2/N1 existing enum |
| daily_target_minutes | Integer 7..1440 |
| timezone | Existing server-validated IANA timezone, canonical alias handling |

Error has the unchanged code/message_vi/retryable shape. No response owner is
accepted merely because it is syntactically a UUID. RpcOwnProfileRepository
captures the session, sends the empty envelope through the current captured-token
RPC binding, checks the same session after await, rejects unexpected fields/types
or another owner and redacts transport failures. Timeout is uncertain and does
not trigger automatic retries. A/B/A and fresh same-user login reject old outcomes.
The process registry allowlist gains only ensure_profile with an empty request.
Dart checks timezone syntax/bounds; the authoritative IANA catalog check is SQL's
existing table trigger. Profile data and tokens are not persisted by this adapter.

Explicit use: construct RpcOwnProfileRepository with the configured Supabase
binding as auth/transport and await ensure before activating a learner runtime.
A caller still needs a login/profile readiness coordinator and safe lifecycle
handling for activation. Default preview runtime stays null; no auto-call/login
or secure session restoration is introduced by these classes.

## Verification and remaining work

Migration: supabase/migrations/20261014073000_ensure_profile.sql. Append-only,
undeployed. The disposable SQL suite checks scoped function privileges, unchanged
table grants, invalid/forged inputs, default provision, preserved settings, A/B
isolation and rollback after a forced trigger error. A separate native process
test observes the second bootstrap actually waiting on a lock before committing
the first; both must return the same ID and create one row. SQL fixtures emulate
Auth identity and cannot verify hosted JWT signatures/expiry.

Five actual role-fixture responses are exported (new A, changed settings A,
invalid caller fields, new B, missing identity) and downloaded by the same CI
Flutter run. The real typed adapter decodes these; the injected Auth/transport
port is TEST ONLY. Seven pure/unit groups cover malformed data, old session,
signed-out/no dispatch, timeout/no retry, redacted errors and registry envelope
guards. Two SDK/HTTP fixture tests verify captured-token POST/empty body and
wrong-owner response rejection; unsigned test tokens do not establish real Auth.

From an empty disposable TEST_DATABASE_URL after all migrations/tests:

```bash
python3 scripts/export_profiles.py build/profile-bootstrap-sql.json
python3 scripts/test_profile_concurrency.py
```

From apps/flutter_app:

```bash
flutter test test/features/srs/own_profile_repository_test.dart test/features/srs/supabase_review_binding_test.dart
dart run tool/verify_own_profile.dart build/profile-native-input/profile-bootstrap-sql.json
```

Native PostgreSQL and full SDK/Flutter/Windows evidence require exact-head CI;
local pure Dart checks are not SQL/hosted proof. Retain every existing gate.
Keep #37 draft/#20/#22/#15 open and all Personal Alpha integration gates pending.
Next login/profile readiness UI, supported secure token persistence/restoration
and configured non-production A/B/expired JWT/two-device learner acceptance.

Observed source: fb3a691553869fd0f01ec029c008808323e778cd passed all five jobs
in https://github.com/collab-TTAM/nihongo_daily/actions/runs/38528310665 : 251
Flutter tests (nine new profile/SDK), 25 profile SQL assertions/observed lock race,
five actual same-run SQL-to-Dart profile projections, retained Chrome/native
gates and web/Windows release artifacts. Exact-head CI metadata verification
accepted all required steps. This is not hosted login/signature or token-restore
evidence; later commits need their own checks.


## Expired JWT RPC rejection — disposable local evidence

The TEST ONLY local GoTrue/PostgREST integration creates a JWT with a valid
local HMAC signature but an already-expired `exp`. The gateway must reject it
for the profile read, `ensure_profile` RPC and `submit_review` RPC. After the
review attempt, a valid session confirms that no review event or learning item
was created. This verifies expiry enforcement across both write endpoints in
the disposable local stack only; it is not hosted Supabase, production JWT or
learner A/B evidence. The app still accepts no learner-supplied URL/key, and no
Auth strategy/provider or RLS change is made.


## Hosted A/B probe — caller-controlled profile overrides

The manual-only `hosted-supabase-acceptance.yml` probe now sends three adversarial
`ensure_profile` requests for each pre-provisioned test account before the valid
empty bootstrap: a different caller `id`, a forged `display_name`, and a forged
`user_metadata` object. Each must return the exact safe
`VALIDATION_FAILURE` object. The probe then verifies both own-profile reads are
still empty before calling `ensure_profile({})`, after which normal caller-bound
bootstrap and A/B RLS checks continue.

The offline fake-server suite also models each vulnerable acceptance mode and
requires the probe to fail, so a future regression in the probe cannot silently
turn an accepted override into a passing result. This strengthens the pending
hosted acceptance; it is not a hosted run. The protected staging environment,
two pre-provisioned accounts and explicit workflow dispatch are still required.


## Hosted profile update isolation and bootstrap idempotency

The manual non-production A/B probe also exercises the allowlisted
`preferred_jlpt` profile update. User A attempts to change User B's setting
and vice versa; the probe verifies through the target user's own session that
the value remains unchanged. Each user then changes only their own setting to
N4, repeats `ensure_profile({})`, and verifies the RPC returns and preserves
that existing setting. A finally path restores each pre-probe value (the new
test profiles' N5 default) and verifies the restoration.

The offline fake-server regressions deliberately model a cross-owner UPDATE
leak and an `ensure_profile` implementation that resets existing settings.
Both must make the probe fail. These are opt-in staging checks, not deployed
learner evidence; no migration, grants or RLS policy are changed.
