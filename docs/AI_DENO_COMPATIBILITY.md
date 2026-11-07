# Standalone Deno compatibility — Issue #31

`backend/ai/deno.json` adds a pinned Deno2.9.6 verification path alongside the existing
Node24 path. This is observed standalone runtime compatibility, not a configured
Supabase Edge Function, matching hosted runtime version, bundle or production server.
No provider, deployment, Auth strategy, app default, public wire contract, production
source/SQL/RLS/TLS policy or application dependency is changed by this increment.

## Reproducible scope and permissions

Run `npm ci --ignore-scripts --no-audit --no-fund` first, then use the pinned CLI.
Deno uses manual node_modules and the same exact package-lock.json. Its separate
lock generation is disabled because npm's lock is the sole dependency authority;
all check/test tasks use cached-only module resolution and cannot select/download
new dependency versions. A cold DENO_DIR check was observed with only npm-ci's local
modules; no prior Deno dependency cache is required. No alternate npm specifiers,
import-map version overrides, lifecycle scripts or unpinned production deps added.

- `deno task check`: strict TypeScript/noUncheckedIndexedAccess/noUnused checks on
  every source, all unit/native tests and Deno-specific tests. No no-check bypass.
- `deno task test`: runs the same168 original Node:test unit/protocol cases on Deno.
  Network/write/subprocess/FFI/system denied; reads limited to node_modules/contracts,
  environment limited to the optional Node coverage variable. No assertion removed.
- `deno task test:web`: six native Deno tests; network only127.0.0.1, bounded reads/env
  as above, no write/run/FFI/system. Starts actual Deno.serve on ephemeral loopback
  ports, uses native fetch and closes/awaits each server. No external network call.
- `deno task test:postgres`: runs all retained native quota5/text9/conversation28
  cases (42 total) using actual pg on Deno against only the fixed disposable CI
  database. Network onlylocalhost:5432; narrowly enumerated test/pg env variables,
  node_modules/contracts reads; no write/run/FFI/system. Tests themselves refuse any
  other database URL. Auth/provider/generated lookup/plaintext/lost-delivery are
  TEST ONLY. This permission set is not production deployment configuration.

CI keeps every original Node/audit/projection/SQL/native/platform command and adds
four required named gates in ai-boundary/database. Both jobs install exact Deno2.9.6;
version is printed and the native Deno permission test asserts it. New files use
Deno's formatter; original source/tests retain their existing Prettier gate. QA CI
validation requires all new named steps and rejects missing/skipped/failed/pending
evidence even under a green job. Allfive latest-attempt jobs still required; no new
optional/skipped/continue-on-error gate or security reduction introduced.

## Native HTTP and observed behavior

Six Deno-specific cases verify exact version and denied external network/secrets/
arbitrary files/write/run/FFI/system; allfive original frozen operations over real
loopback HTTP with fixed operation binding/no-store/safe headers; unauthenticated,
wrong-method and forged-owner rejection before provider; actual chunked multibyte
32KiB enforcement before Auth; deadline rejection of late output and no redispatch;
actual client TCP disconnect aborting the captured provider signal/no late commit.
Fixtures remain confined to tests and never appear in the default application.

Deno2.9.6's default server prints a one-time legacy request.signal warning: it may
also abort on successful response delivery. Existing HTTP cleanup removes its
listener on return, and success/disconnect/deadline cases passed without unstable
flags. The deadline case correctly expects the unchanged HTTP504/PROVIDER_UNAVAILABLE
contract; a later pending retry is503 and does not generate again. No production
status mapping, timer, cleanup or cancellation assertion was weakened to get green.

Local actual Deno2.9.6/V815.0.245.2-rusty/TypeScript6.0.3: strict check (including all
native test code), original168 cases and all six native HTTP/permission cases passed,
zero failures/ignores. Node24 format/typecheck/original168/audit0 and Python QA30
passed; inventory65/all14 learner release groups remain pending. No local PostgreSQL
binary; new42 Deno native pg execution needs this source's exact-head CI. Node's
parent pg evidence cannot substitute for those Deno results.

Parent691a797f9bdc333fe6d30c9476476474dd9e8328 passed allfive jobs/every step in
[CI39831337442](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39831337442),
latest attempt1, with all28 Node pg conversation cases already verified in the
completed database log. This resolves its old Flutter/Windows pending checkpoint;
this new source needs its own complete jobs and all four added Deno gates.

## Remaining release assurance

Standalone Deno/Linux/manual npm resolution/loopback is not observed Supabase Edge
bundling/isolate/resource limits, deployed runtime version, hosted JWT/TLS/CA/
PostgREST, actual approved upstream lookup provenance, real partition or learner
proof. No published endpoint or live credentials configured. #31/#17/#18 remain
open, #41 stays draft and all14 Personal Alpha release groups remain pending.
Next inspect exact-head full CI and42 Deno pg results, fix observed failures with
all assertions/security intact, then verify actual Edge packaging/runtime separately.
Real provider strategy/configuration remains behind the applicable existing gate;
never invent metadata/echo a learner/model result as authenticated upstream proof.

Official sources checked2026-10-22 UTC: [Deno releases](https://github.com/denoland/deno/releases),
[testing](https://docs.deno.com/runtime/test/),
[manual node_modules/config](https://docs.deno.com/runtime/reference/deno_json/),
[permissions](https://docs.deno.com/runtime/reference/permissions/),
[CI](https://docs.deno.com/runtime/reference/continuous_integration/) and
[Supabase Edge overview](https://supabase.com/docs/guides/functions).
Supabase's overview identifies a Deno-compatible Edge runtime; it does not establish
that our selected standalone CLI equals the version deployed for a learner project.

See [AI_EDGE_USER_WORKER.md](AI_EDGE_USER_WORKER.md) for the separate TEST ONLY
Supabase Edge bundle/main-to-user-isolate probe and its exact-head CI requirement.
Standalone Deno evidence does not substitute for that execution or hosted proof.
