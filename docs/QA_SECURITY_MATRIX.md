# QA/security regression matrix — Issue #8

Personal Alpha is **IN_PROGRESS**. `qa/matrix.json` is the maintained source for
32 assurance cases, their exact test-file anchors, reproduction steps, issue owners,
scope limits and ranked findings. `automated-baseline` means an executable test
exists; it does **not** mean it passed on the current head or proves live integration.
`pending-integration` means the specified scenario has not been observed. No
synthetic evidence or fixture may be promoted to real integration evidence.

## Baseline inventory and reproducible runs

Run from the repository root unless a working directory is stated. Use Python 3.11+
(the verifier uses pathlib containment), Node 24 and Flutter 3.35.4 / Dart 3.9.2.
Create `apps/flutter_app/build` before the two Dart wire verifiers. Never run the
SQL bootstrap on a hosted, production or existing database; use a new empty
**disposable PostgreSQL 17** database as documented in `supabase/README.md`.
The matrix's reproduction strings are instructions; the checker never executes them.

```bash
python3 -m pip install -r contracts/requirements.txt
python3 scripts/verify_qa.py
python3 -m unittest discover -s qa -p 'test_*.py' -v
python3 contracts/validate.py
python3 -m contracts.validate_content
python3 -m unittest discover -s contracts -p 'test_*.py' -v
```

Database: `bash scripts/test_database.sh` with the supported disposable
`TEST_DATABASE_URL`; it applies migrations, real SQL `SET ROLE`/RLS tests and two
native concurrency tests. Setting an auth fixture's user ID does not validate a JWT.

In `backend/ai`: `npm ci --ignore-scripts --no-audit --no-fund`,
`npm audit --omit=dev --audit-level=moderate`, `npm run format:check`,
`npm run check`, `npm test`. From root regenerate `wire.ts`, format in backend/ai,
and inspect `git diff --exit-code -- src/wire.ts` there as CI does. All provider,
Auth, limiter, context and memory-store ports in these tests are fixtures.

In `apps/flutter_app`: enforce the lock with `flutter pub get --enforce-lockfile`,
run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`,
`flutter test`, both `tool/verify_srs.dart` and `tool/verify_kanji.dart`; validate
actual output using `contracts.validate_srs_wire` / `contracts.validate_kanji_wire`
from root. Build web release; build Windows release on VS 2022/Windows-compatible
runner. Build artifacts do not prove an interactive app launch or live learner flow.

| Baseline case | CI job | Scope and limit |
| --- | --- | --- |
| `wire-validation` | repo-sanity | Unknown owner/fields, rating correctness, finite numbers, dates and bounded outputs. Schema tests do not verify JWT or RLS. |
| `content-integrity` | repo-sanity | Counts, unique IDs/text, references, Japanese readings and absent assets. Small original N5 seed only; no N4/audio/reference stroke corpus or independent teacher review. |
| `rls-isolation` | database | Actual SQL roles A/B, parent message reads, forbidden writes, private functions. Native SQL fixture auth.uid() is not verified GoTrue/JWT/PostgREST integration. |
| `review-storage` | database | Immutable original result replay, changed-input conflict and native two-session uniqueness. Storage helper race is not an atomic submit_review endpoint or updated scheduler counters. |
| `review-transaction` | database | Authenticated SQL RPC validation/replay/rollback, 26 SQL/Dart cases and five native races. SQL auth fixtures do not establish JWT/PostgREST/Flutter/UI integration. |
| `ai-sql-receipts` | database | Private token ownership, scoped claim/completion, privileges and rollback. Helpers do not persist conversation messages/session in a real adapter transaction. |
| `ai-claim-race` | database | Two native sessions grant exactly one dispatch owner. SQL claims do not prove upstream delivery, recovery or two distinct session events. |
| `srs-policy` | flutter | Versioned 26 policy pairs, offsets, stale events and actual Dart wire output. Pure scheduler; no authenticated persistence, queue or integrated review UI. |
| `kanji-capture` | flutter | Bounded capture/time/multiple pointers, undo/clear and synthetic scoring. Synthetic fixtures never establish canonical stroke order, recognition or learner grades. |
| `preview-ui` | flutter | Navigation, recovery, loading/error/retry/empty and large text layouts. Widget tests exercise a labeled demo; no interactive web/Windows or account/study flow evidence. |
| `ai-boundary-faults` | ai-boundary | Missing/expired/forged identity, limits, provider malformed output/timeout and safe errors. Auth/limiter/provider ports are test fixtures, not JWT verification or distributed rate limiting. |
| `ai-retry-recovery` | ai-boundary | Duplicate concurrent requests, changed input, pending recovery, commit failure and immutable results. Memory test store and lookup fixture are not durable process restart or provider reconciliation. |
| `dependency-audit` | ai-boundary | Pinned patched Ajv, production audit and unchanged generated schema projections. Production npm audit snapshot alone does not establish security of Flutter/native/dev dependencies or application. |
| `qa-evidence` | repo-sanity | Reject missing/skipped/pending/stale-head/mixed-attempt CI evidence. Checks saved Actions metadata, not test execution/authenticity or integration completion. |

## Observed evidence and current-head merge check

Prior main `98397e72bee41924840ed87f998d40f1b8e2c7fe` has observed successful
[CI run 38453557158](https://github.com/collab-TTAM/nihongo_daily/actions/runs/38453557158)
with all five jobs. PR #32's separately reviewed head `e3200bc6` passed 38 Node
and 91 Flutter tests, original 34 Python tests, 28 added SQL assertions and native
claim/review races; see PROJECT_STATUS for exact links/limits. These historical
results do not certify the new #8 head. Current-head PR CI is still required.

`verify_qa.py --evidence evidence.json --head FULL_40_CHARACTER_SHA` verifies a
saved GitHub workflow-run object and the complete latest-attempt jobs response.
It requires the repository/workflow/trigger, explicit head, run ID/attempt, all five
jobs and critical steps to match and finish successfully. Missing/paginated,
duplicate, skipped, cancelled, failed, queued or mixed-attempt data fails closed.
Unreviewed additional jobs also require updating the inventory. It verifies
correlation/completeness, **not authenticity**, elapsed testing or semantic test
coverage. Retrieve the evidence freshly from the connected GitHub tools or GitHub
API, inspect the source URLs, and review diff/acceptance separately before merging.
Do not synthesize or rewrite metadata to pass. Unit-test fixtures are TEST ONLY.

Example using an already authenticated GitHub CLI, without requesting secrets:

```bash
gh api repos/collab-TTAM/nihongo_daily/actions/runs/RUN_ID > /tmp/qa-run.json
gh api 'repos/collab-TTAM/nihongo_daily/actions/runs/RUN_ID/jobs?filter=latest&per_page=100' > /tmp/qa-jobs.json
python3 - <<'PYDATA'
import json
from pathlib import Path
Path('/tmp/qa-evidence.json').write_text(json.dumps({
    'run': json.loads(Path('/tmp/qa-run.json').read_text()),
    'jobs': json.loads(Path('/tmp/qa-jobs.json').read_text()),
}))
PYDATA
python3 scripts/verify_qa.py --evidence /tmp/qa-evidence.json --head FULL_40_CHARACTER_SHA
```

Inspect pagination: an incomplete jobs response is rejected. Do not concatenate
old attempts. No logs, tokens or transcript contents are needed. A rerun changes
run_attempt, so fetch the run and latest jobs again rather than mixing snapshots.
CI runs the inventory/test regressions; the external evidence check is performed
**after** all jobs complete, avoiding a job trying to certify its own success.

## Ranked findings

Severity ranks impact **if the missing boundary were activated without evidence**;
coverage gaps are not claims of an observed exploit. No unremediated vulnerability
is asserted solely from a missing test. A clean production npm audit is not a full
application security review. No runtime activation or security weakening is included.

| ID | Severity / kind | Finding and action |
| --- | --- | --- |
| SEC-01 | high / coverage-gap | Real identity verification, session lifecycle and cross-account cache isolation remain unverified. This is missing release assurance, not a proven exploit. Complete #20/#15; run actual A/B, expiry/restart/sign-out cases before enabling personal data flows. |
| SEC-02 | high / coverage-gap | Distributed limits, trusted message/session transactions and upstream reconciliation are not bound in the runtime. Fixture success cannot authorize real provider calls. Complete #31/#17 with durable commit-before-dispatch and correlated lookup-only recovery; retain safe pending state. |
| SEC-03 | high / coverage-gap | Local atomic SQL RPC is tested, but real identity/transport, integrated review UI and durable retry queue remain unverified. SQL fixture success alone does not establish an end-to-end review flow. Complete #22 then #15; test two native clients, rollback/counters/parity/conflicts. |
| SEC-04 | medium / coverage-gap | Audio contract, permissions and retention assurance is missing. No audio collection should be inferred from text schemas. Review #17 audio design and applicable user gates before activation; test denial/disconnect/retention. |
| SEC-05 | medium / coverage-gap | No observed interactive browser/native launch evidence; CI builds and widget tests do not cover artifact launch failures. Run exact artifact smoke on supported browser/Windows in #18 and preserve redacted environment/assertions. |
| DEP-01 | medium / remediated-dependency | PR #32 remediated Ajv GHSA-2g4f-4pwh-qvx6 with 8.20.0 and disabled $data; production audit passed at reviewed head e3200bc6. Retain moderate production audit and monitor new findings; do not disable tests or generalize this snapshot to overall security. |

## Personal Alpha release gate checklist

Every row below is unchecked; all require observed integrated evidence. Run
`python3 scripts/verify_qa.py --evidence ... --head ... --release` to obtain a
nonzero result while these cases are pending, even if baseline CI is green.
The v1 inventory intentionally does not accept a free-form `passed` status for
live cases. When implementation/evidence arrives, review a versioned extension
with commit/environment/command/source evidence rather than silently changing a
status label. #18 owns that integrated release decision; #8 closes only inventory.

| Gate | Owner issues | Required evidence |
| --- | --- | --- |
| [ ] `auth-live` | [#20](https://github.com/collab-TTAM/nihongo_daily/issues/20), [#18](https://github.com/collab-TTAM/nihongo_daily/issues/18) | Non-production Supabase: login A/B, verify issuer/signature/expiry, provision profiles from trusted identity, restart/restore, sign out/switch and inspect caches. Record exact commit/environment and redacted assertions. |
| [ ] `review-rpc` | [#22](https://github.com/collab-TTAM/nihongo_daily/issues/22), [#18](https://github.com/collab-TTAM/nihongo_daily/issues/18) | Execute real submit_review under A/B: duplicate/changed/concurrent payloads, stale new event, future skew, inactive/wrong-type curriculum, forced rollback and Dart/SQL parity; observe counters/original responses. |
| [ ] `daily-plan` | [#11](https://github.com/collab-TTAM/nihongo_daily/issues/11), [#18](https://github.com/collab-TTAM/nihongo_daily/issues/18) | At local midnight and timezone changes: generate/retry existing plan, record duplicate sessions, exceed target, restart; verify progress preserved and unavailable AI BLOCKED. |
| [ ] `study-flows` | [#12](https://github.com/collab-TTAM/nihongo_daily/issues/12), [#34](https://github.com/collab-TTAM/nihongo_daily/issues/34), [#18](https://github.com/collab-TTAM/nihongo_daily/issues/18) | Select actual N5/N4 items, display readings/examples/meaning, load/error/empty/offline, complete validated study session; verify no simulated audio/completion. |
| [ ] `n5-coverage` | [#26](https://github.com/collab-TTAM/nihongo_daily/issues/26), [#18](https://github.com/collab-TTAM/nihongo_daily/issues/18) | Check reviewed count/topic/grammar-skill target against versioned exports and real study/quiz/listening flows; record linguistic review and asset gaps. |
| [ ] `n4-coverage` | [#14](https://github.com/collab-TTAM/nihongo_daily/issues/14), [#18](https://github.com/collab-TTAM/nihongo_daily/issues/18) | Validate N4 exports/references/version/counts, review Japanese/Vietnamese examples and exercise actual N4 study screens. |
| [ ] `kanji-real` | [#16](https://github.com/collab-TTAM/nihongo_daily/issues/16), [#18](https://github.com/collab-TTAM/nihongo_daily/issues/18) | Reproduce pinned licensed import, validate counts/lookup/order/coordinates; draw correct/wrong/missing references, verify honest feedback, record persisted attempt through trusted service. |
| [ ] `ai-runtime` | [#31](https://github.com/collab-TTAM/nihongo_daily/issues/31), [#18](https://github.com/collab-TTAM/nihongo_daily/issues/18) | On verified runtime with A/B: two distinct and same session events, sequence/ownership, crash before/after dispatch/commit, pending reconciliation; verify JWT and global limiter. |
| [ ] `ai-live` | [#17](https://github.com/collab-TTAM/nihongo_daily/issues/17), [#31](https://github.com/collab-TTAM/nihongo_daily/issues/31), [#18](https://github.com/collab-TTAM/nihongo_daily/issues/18) | Call approved backend provider through verified user session; validate outputs, rate/size/deadline failures, original retry result and provider correlation without duplicate billing. |
| [ ] `voice-live` | [#17](https://github.com/collab-TTAM/nihongo_daily/issues/17), [#18](https://github.com/collab-TTAM/nihongo_daily/issues/18) | Review audio contract/retention/permissions; record/upload or stream and play a real conversation on supported devices; test denial/disconnect and approved retention. |
| [ ] `offline-sync` | [#15](https://github.com/collab-TTAM/nihongo_daily/issues/15), [#20](https://github.com/collab-TTAM/nihongo_daily/issues/20), [#22](https://github.com/collab-TTAM/nihongo_daily/issues/22), [#18](https://github.com/collab-TTAM/nihongo_daily/issues/18) | Run two clients A/B, go offline, queue immutable event IDs/times, restart, reconnect/resend, provoke stale/two-device conflict and account switch; inspect retained authoritative state. |
| [ ] `quiz-progress` | [#13](https://github.com/collab-TTAM/nihongo_daily/issues/13), [#18](https://github.com/collab-TTAM/nihongo_daily/issues/18) | Submit correct/wrong/repeated/duplicate attempts; verify owner history/counters, empty state and recommendations referencing curriculum; inspect dashboard. |
| [ ] `browser-windows-smoke` | [#18](https://github.com/collab-TTAM/nihongo_daily/issues/18) | Serve exact web artifact; launch exe with DLL/data directory on Windows 2022-compatible toolchain; inspect 320/375/desktop/200% text, navigation, refresh/deep-link and console; record OS/browser/build SHA. |
| [ ] `learner-journey` | [#18](https://github.com/collab-TTAM/nihongo_daily/issues/18) | Exact tested commit: login -> plan -> study -> review -> quiz -> Kanji -> conversation/voice -> progress; restart/two-device sync, no critical defects; preserve rollback/recovery and evidence. |

For #18, store exact code SHA, OS/runtime/browser, commands/scenarios, observed
assertions, CI/artifact URLs, redacted integration results, unresolved findings
and recovery/rollback instructions. Do not infer evidence from issue closure,
static mocks, SQL bootstrap identities or a successful executable build.

QA identified the unassigned Listening/Reading module and created #34; preserve
its audio availability/valid-session acceptance. No secrets are requested in chat.
Human gates in AUTOMATION.md remain unchanged: destructive migrations, production
or App Store release, auth strategy, expanded collection, material AI spend,
production deletion and security reduction. No deployment/release is performed.
Next sequential implementation priority: #22 atomic authoritative review path;
#31 runtime binding and #11 plan/session integration remain queued independently.
