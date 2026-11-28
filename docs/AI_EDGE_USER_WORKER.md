# AI Edge user-worker compatibility probe (#31)

This TEST ONLY component probe builds the original strict Contracts/Ajv, AiService,
correlated recovery module and HTTP adapter into a self-contained ESM user worker.
It adds no Supabase function, app endpoint, real Auth/provider binding or default.
Existing production source, frozen wire/schema, SQL/RLS and npm lock stay unchanged.

## Build and actual isolate boundary

Deno **2.9.6** is the pinned build tool, using npm-ci manual node_modules and the
original package-lock. `deno task check` includes both Edge entrypoints. The new
`bundle:edge` task requires type checking, forbids remote module resolution and
bundles all npm imports plus original static JSON schema/fixtures. Deno bundle is
experimental; this version is pinned and its internal esbuild binary may need a
build-time registry download. This is not a second application dependency lock.
No npm package, filesystem-relative schema or network import is needed by the
resulting user worker. The bundle hash is recorded with observed evidence.

The test supervisor calls **EdgeRuntime.userWorkers.create** with fixed
`/probe/worker`, 150 MiB worker memory, bounded CPU/wall time, no npm/remote module loading, no environment
forwarding and no automatic retry. `worker.fetch` crosses the real main/user
isolate boundary. It is not a standalone main-worker Deno server probe.
Only immutable predefined routes bind operations; query/body cannot select an
arbitrary service path. No production provider URL, JWT or key is accepted.

The Python stdlib runner pulls official **supabase/edge-runtime:v1.77.4**, records
registry digest/local immutable image ID and binary version, then launches that
image ID with explicit per_worker pool policy. One disposable memory/CPU/PID-capped container has no forwarded host
environment, a read-only bundle mount, dropped capabilities and a loopback-only
random host port. Only its captured container ID is removed. Pull, commands,
readiness, HTTP requests and cleanup have finite bounds. No broad Docker prune,
production migration/deployment or paid provider call occurs.

The official tag/API was checked against these primary sources on 2026-10-22:
- https://github.com/supabase/edge-runtime/releases/tag/v1.77.4 (2026-10-01 release)
- https://github.com/supabase/edge-runtime/blob/v1.77.4/examples/main/index.ts
- https://github.com/supabase/edge-runtime/blob/v1.77.4/types/global.d.ts
- https://github.com/supabase/edge-runtime/blob/v1.77.4/DEVELOPERS.md
- https://docs.deno.com/runtime/reference/cli/bundle/

The image tag, CLI crate version and branded JavaScript metadata are different
identifiers. Official v1.77.4 `cli/src/flags.rs` formats `--version` from
`cli/Cargo.toml` (**0.1.0**) plus `deno/Cargo.toml` (**2.1.4**); both CLI lines
remain strictly checked, capturing stdout and stderr. `ext/runtime/js/bootstrap.js`
overwrites `Deno.version.deno` with the full string:

```text
supabase-edge-runtime-1.77.4 (compatible with Deno v2.1.4)
```

The release workflow passes semantic **1.77.4**, without `v`, as `GIT_V_TAG`.
The probe strictly compares the entire reported three-field metadata object:
that branded string, V8 **11.6.189.12** and TypeScript **5.1.6**. The latter two
are hard-coded bootstrap reports, not directly measured engine/compiler versions.
Plain `2.1.4`, a different image/compatible Deno, missing/extra/changed fields or
suffixes fail before any AI operation, with a fixed error that echoes no input.
Four Python regressions reproduce this distinction and exercise wrong-runtime
HTTP rejection before POST/dispatch. They are fixtures, not Edge execution proof.

Primary pinned sources: [flags.rs](https://github.com/supabase/edge-runtime/blob/v1.77.4/cli/src/flags.rs),
[CLI manifest](https://github.com/supabase/edge-runtime/blob/v1.77.4/cli/Cargo.toml),
[Deno manifest](https://github.com/supabase/edge-runtime/blob/v1.77.4/deno/Cargo.toml),
[bootstrap.js](https://github.com/supabase/edge-runtime/blob/v1.77.4/ext/runtime/js/bootstrap.js)
(blob1a98593cee8882faa9206b8a274496b5e8166935), and
[release workflow](https://github.com/supabase/edge-runtime/blob/v1.77.4/.github/workflows/release.yml).
Standalone bundle/fixture testing may explicitly pass a complete expected runtime
metadata object; the Docker entrypoint always uses the pinned Edge fingerprint.
Such standalone execution never becomes actual Edge evidence.

## Cases and CI acceptance

`Verify bundled Supabase Edge user worker` is mandatory in the existing
ai-boundary job, alongside every retained Node/Deno/SQL/native/platform gate.
The evidence artifact publication is also mandatory. QA rejects either step
missing, skipped, failed or pending behind a green job.

The actual HTTP probe checks seven groups:
1. User-worker fixture marker and strict pinned branded Deno/V8/TypeScript reported metadata.
2. All five unchanged original wire fixtures, fixed operation and safe headers.
3. Completed mutation replay without dispatch and separate fixture A/B receipts.
4. Missing/invalid fixture Auth, wrong method and strict unknown owner rejection.
5. Chunked multibyte 32 KiB body rejected before Auth/provider/receipt activity.
6. Strict provider-result schema rejection and redacted safe error/no completion.
7. Deadline propagated to private provider signal, late output fenced and pending
   retry never redispatched.

Evidence prints only versions/image IDs/digests/bundle hash/case labels, never
request headers, provider output, claim tokens or learner data. Successful output
is also `build/edge/evidence.json` and the `ai-edge-user-worker` CI artifact,
with separate source head and actual checkout head. A failing or absent step
is not evidence. On failure, bounded fixture-only startup diagnostics redact
test bearers/claim/output; cleanup still runs if diagnostics fail.

Reproduce from backend/ai with Docker available:

```sh
npm ci --ignore-scripts --no-audit --no-fund
deno task check
deno task bundle:edge
mkdir -p ../../build/edge/main
cp edge/main.ts ../../build/edge/main/index.ts
python3 ../../scripts/verify_edge_user_worker.py
```

## Limits and next evidence

Auth, quota, context, provider and receipt ports are explicit TEST ONLY fixtures.
They do not establish real JWT verification, distributed quota, database
transactions, authenticated upstream result provenance or hosted learner proof.
The worker receipt map deliberately tests service portability, not durable SQL.
SQL/PostgreSQL/Deno transaction and recovery checks remain separately mandatory.
No hosted/runtime-version equivalence, resource-limit stress, cold-start cost,
real disconnect across the hosted proxy, deployment or Personal Alpha claim.

The local cloud environment has no Docker; actual container/user-isolate proof
requires the new exact-head Actions step, observed with all latest-attempt jobs.
All14 hosted release groups and provider decisions/configuration remain gated.

The explicit server composition is documented in [AI_TRUSTED_RUNTIME.md](AI_TRUSTED_RUNTIME.md).
It requires caller configuration/provider and retains verified TLS/atomic transactions;
no default endpoint or live provider is enabled. Parent Edge fixture evidence does
not certify the new full PostgreSQL assembly inside an Edge worker.


The separate TEST ONLY full PostgreSQL/user-isolate stage is specified in
[AI_EDGE_POSTGRES.md](AI_EDGE_POSTGRES.md); retained memory-port and native suites
remain mandatory. Only observed new exact-head execution can establish its scope.
