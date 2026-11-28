# Concrete SDK review binding — Issue #22

`SupabaseReviewBinding` uses pinned **supabase 2.16.5**, **http 1.6.0** and
**logging 1.3.0**, with the existing typed repository/queue/controller. The owner
supplies an already configured SupabaseClient and trusted project origin/public
key. `createSupabaseStudyRuntime` assembles those ports explicitly. Default app
runtime remains null: no app login, service setup/deployment or new Auth provider
is activated. Profile provisioning, secure credential storage/restoration,
durable pending records and real JWT/learner acceptance remain #20/#15/#22.

## Identity and dispatch

- Observe the public SDK onAuthStateChange stream with error/done handlers;
  initialize from currentSession. Logout/null/error/closure revokes the registry.
- Server `session_id` + user ID distinguish same-lifecycle refresh/refocus from
  another login, including A/B/A or same-user re-login. Same active lifecycle
  keeps prepared immutable reviews; a new lifecycle replaces identity. Access
  and dispatch also compare current SDK state, not only delayed notifications.
- Strict bounded JWT payload/UUID/sub/role/expiry checks are **defensive local
  hints**, never signature/issuer/audience/project authentication. Unsigned test
  tokens do not prove authorization. Supabase Auth/PostgREST verifies real JWTs;
  the server RPC still derives the owner only from auth.uid(). Token claims and
  user metadata never grant new client writes or provision profiles.
- Each RPC creates an isolated PostgrestClient with a captured bearer token and
  public key. Never select shared client.rpc's changing token, use setAuth,
  auto-refresh within dispatch or retry automatically. Same-session refresh
  cannot redirect an in-flight request; next dispatch captures the refreshed
  token. Old lifecycle results are discarded even if HTTP succeeded.
- HTTPS origin only: no embedded credentials/path/query/fragment. Match SDK
  endpoint/public key; reject secret/service-role keys. Configuration must come
  from the owner's supported settings, never a learner-supplied URL or chat.
  Local plain-HTTP Supabase support needs a separately reviewed opt-in; not here.

## HTTP, errors and logs

POST only to allowlisted SRS RPCs with copied ownerless p_request, existing
schemas and no direct feature table access. Disable redirects and retries.
SDK's request deadline is 15 seconds; cancellation/timeout is **unknown server
outcome**, not rollback. Manual retry retains the original event identity/time.
Bound response bytes before SDK JSON decoding to 1 MiB, including chunked data.
Malformed success still fails the existing strict typed decoder.

Translate 400/401/403/404/409/429/408/5xx and transport failures to fixed safe
codes. Do not consume/display/log raw HTTP error bodies, URL credentials, headers,
SQL details or tokens. SDK logging was inspected: pinned Auth finest logs include
Session.toString with tokens; PostgREST debug logs include headers/raw errors.
Binding explicitly disables the `supabase` SDK logger family, with explicit
`supabase.auth` and `supabase.postgrest` overrides too, for logging
app-wide, enabling hierarchical logging for these scoped overrides. It does not
restore unsafe logging on disposal. The owner must never re-enable these sinks or
log SDK AuthState/Session/exception objects; configure redacted application logs
before any earlier SDK Auth operation too. This is a security hardening, not a
claim that every third-party logging sink is safe.

Dispose clears notifications/hints and stops the binding listener, without
signing out/disposal of the caller's borrowed SDK/HTTP clients. Per-RPC HTTP clients
and PostgREST isolates are cleaned up; externally supplied client is caller-owned.
No credential serialization or persistent token/cache storage is implemented.

## Dependency provenance and tests

Local Flutter bootstrap was previously policy-blocked; it was not retried.
An isolated read-only Actions workflow resolved the candidate manifest/lock at
head 5bfa29b41f4f62c88df7d90fbdefa7047ddb4893:
https://github.com/collab-TTAM/nihongo_daily/actions/runs/38504490159 .
The public artifact/log output was inspected and imported intact; existing
resolved versions remained unchanged. Already-resolved logging 1.3.0 becomes a
direct dependency solely to enforce safe SDK log policy. The temporary resolver
workflow was removed after this import (recoverable from git history); original
CI's enforce-lockfile/format/analyze/test/SQL/build gates are unchanged.

From apps/flutter_app:

```bash
flutter pub get --enforce-lockfile
flutter test test/features/srs/supabase_review_binding_test.dart
```

These tests use the **actual SDK** and HTTP serialization but **TEST ONLY unsigned
JWTs/Auth/RPC HTTP fixtures**, not a real GoTrue/PostgREST gateway or signature/RLS
test. Cover POST headers/envelope, refresh/re-login/logout/A-B-A, in-flight token
capture and account rejection, expiry, fixed errors/no retries, body limits,
malformed result, safe logger policy, configuration guards, runtime and disposal.
Full current-head tests/build/native SQL remain required before reporting success.
All 14 Personal Alpha release integration cases stay pending.

Primary sources/pinned published source checked 2026-10-14:
- https://supabase.com/docs/reference/dart/auth-onauthstatechange
- https://supabase.com/docs/reference/dart/rpc
- https://pub.dev/packages/supabase/versions/2.16.5
- https://pub.dev/packages/postgrest/versions/2.9.1
- https://pub.dev/packages/gotrue/versions/2.27.3
