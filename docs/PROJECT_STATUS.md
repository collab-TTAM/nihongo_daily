# PROJECT STATUS

Current release target: Personal Alpha
Overall status: IN_PROGRESS — starter baselines #1–#8 merged; real learner flows, N5/N4 expansion and live integrations remain outstanding.

| Milestone | Status | Owner / prerequisite |
| --- | --- | --- |
| Architecture baseline | MERGED via PR #10; #1 completed | Lead |
| Flutter skeleton | MERGED via PR #19; #2 completed | #2 Flutter |
| Supabase schema/auth | MERGED via PR #21; live Auth tracked in #20 | #3 Backend |
| SRS engine | MERGED via PR #24; pure nd-srs-1; live RPC #22 | #4 Learning |
| Kanji writing engine | MERGED via PR #29; capture/synthetic core; real assets #16 | #6 Kanji |
| AI tutor | MERGED via PR #32; runtime bridge #31 / live providers #17 | #7 AI |
| N5/N4 content pipeline | N5 seed MERGED via PR #27; expansion #26 / N4 #14 | #5 completed |
| QA/security baseline | MERGED via PR #35; #8 inventory completed | #18 integrated release still pending |

## Historical handoff — Issue #1, 2026-10-13

- Completed: resolved rating/units/date/retry/ownership ambiguities; 37 named schema definitions, eight endpoint bindings, 20 fixtures, validator and 15 regression tests; dependency and merge order documented.
- Remaining: Flutter #2, database/RLS #3, SRS #4, curriculum #5 and remaining Personal Alpha modules.
- Changed files: contracts/v0.1/*, contracts/validate.py, contracts/test_contracts.py, contracts/requirements.txt, API_CONTRACTS, DATABASE_SCHEMA, ARCHITECTURE, CONTRACT_BASELINE, this status, README, CI workflow.
- API changes: typed definitions for eight already-planned operations; RPC/Edge boundaries, safe errors, bounded outputs and scoped retries.
- Database changes: specification only; user-scoped review uniqueness/original-result receipts, conversation receipts, parent-message ownership, integrity and validated write requirements. No migration applied.
- Known issues: no Flutter app or live service; fixture validation does not test deployed RLS/providers. Audio streaming/upload contract remains later work.
- Tests: local validator passed all 20 fixtures and all 15 regression tests passed. PR/current-head CI is the integration gate; see #1/its PR for evidence.
- Next task: #2 Flutter shell after #1 integration, without external credentials.
- Blockers/decisions: none for #2; live Supabase/AI/voice configuration is addressed when integration is implemented.

Personal Alpha gaps are queued as #11–#18; see CONTRACT_BASELINE for the map. Issue #16 provides real Kanji reference assets, while #6 can start synthetic primitives after #2.

## Latest handoff — Issue #2 / PR #19, 2026-10-13

- Branch: automation/issue-2-flutter-shell; base main 33f31a8 (PR #10).
- Implemented: Vietnamese Material 3 adaptive shell, GoRouter module discovery and
  unavailable pages, Riverpod-injected typed demo repository, session-only N5/N4
  and theme settings, loading/error/retry/empty handling, regression tests.
- Changed files: apps/flutter_app, README, CI workflow, .gitignore, this status.
- API/database changes: none; demo allocation does not implement get_daily_plan.
- Checks: contract validator passed 20 fixtures; 15 contract regression tests passed.
  Flutter format and analyze passed (no issues); 22 Flutter tests passed, including
  200% text on 320/375px layouts after fixing the theme dropdown overflow. Web
  release build succeeded locally again with the final dependency lock, including
  the optional Cupertino icon font. Local source matches the uploaded tree
  2554e82a1b6e5c8f787fba350bbfe8e734022bfa (code head 20e3088 before this status update).
  Exact-head CI and Windows build evidence are tracked in
  https://github.com/collab-TTAM/nihongo_daily/pull/19/checks; repo-sanity, flutter
  (format/analyze/22 tests/web build), and windows (release build) must all pass
  before integration. Artifacts: flutter-web-preview and flutter-windows-preview.
  CI run 38407859810 passed repo-sanity and all Flutter checks, but Windows failed
  because windows-latest supplied VS 2026 and Flutter 3.35 selected the fallback
  VS 2019 CMake generator. The Windows job is now pinned to windows-2022 / VS 2022;
  no checks were removed. Current-head rerun remains the integration gate.
  Direct browser smoke was not observed:
  the local headless Chrome process crashed before the app could load.
- Known limitations: real content, auth, storage, sync, SRS, scoring, progress,
  providers and voice remain unimplemented; preview routes state this explicitly.
- Next: integrate #2 only after separate review and current-head CI; then #3
  Supabase schema/RLS. #4 can use the Dart package after #2 merge.
- Blockers: none requiring user input. Native Windows launch, iOS runner,
  signing and device validation remain later work.

## Integrated handoff — Issue #3 / PR #21, 2026-10-13

- Merged: PR #21 (https://github.com/collab-TTAM/nihongo_daily/pull/21) as
  4dd5e134ec2bfdc93bac97ed796ba882c9e98af6; #3 completed. Shared contracts #1 and
  Flutter preview #2 are also integrated; earlier handoffs above are historical.
- Delivered: additive 22-table migration; owner/parent-message RLS; explicit
  table/column grants; allowlisted own-profile settings; backend-only scenario
  context; immutable review requests/original responses; typed curriculum FKs;
  normalized relationship FKs, indexes and checked receipt state.
- Evidence: separately reviewed head 240ef15190dbaa3ffc191cf212dba7a8c262e686.
  CI https://github.com/collab-TTAM/nihongo_daily/actions/runs/38421789675 succeeded:
  repo-sanity (20 contract fixtures, 15 tests), database (250 SQL assertions plus
  two native concurrent sessions committing exactly one event), flutter
  (format/analyze/22 tests/web release build), windows (release build).
- Local checks: the migration/SQL suite passed on PostgreSQL 18.6 via PGlite 0.5.9;
  contract fixtures/tests, bash syntax, Python compilation and whitespace passed.
  Native PostgreSQL 17 evidence comes from CI, not this local environment.
- Review fixes: canonicalize Asia/Saigon to Asia/Ho_Chi_Minh with UTC+7 conversion
  checks; use FOR SHARE for active-content validation; revoke inherited service-role
  TRUNCATE; verify restrictive FK rejection and unchanged curriculum/history across
  observed native PG17/local PG18 error codes. No security/test gates removed.
- Not delivered: hosted Supabase/PostgREST/Auth, public submit_review, account
  lifecycle, real providers, offline sync or production deployment. Storage replay
  is not a functioning review endpoint, and the UI remains a labeled demo.
- Follow-ups: #20 real Auth/session lifecycle; #22 authenticated atomic review RPC
  after #4 pure scheduler; #7 provider-neutral validated interfaces; #17 live
  AI/voice. Read supabase/README.md for storage/export mapping and safe test setup.
- Next task: #4 deterministic pure Dart SRS on automation/issue-4-srs-core, then
  #5 original N5 content according to dependency order. #4 needs no live secrets.
  Main stays IN_PROGRESS toward Personal Alpha; no release completion claimed.

## Integrated handoff — Issue #4 / PR #24, 2026-10-13

- Merged: https://github.com/collab-TTAM/nihongo_daily/pull/24 as
  d4ed337dc8a5bcce46bc830e0e10528b8bd04e56; #4 completed as a pure scheduler.
- Delivered: immutable Dart card/request projections, nd-srs-1 rating/transition
  rules, bounded learning/relearning/early/overdue intervals, capped review growth,
  validated counters/difficulty and deterministic UTC duration arithmetic.
- Evidence: reviewed head 7e656d445bbca00216f601fc203f14f923068b03; all jobs succeeded at
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38426443750:
  repo-sanity (20 baseline fixtures/17 regression tests), database (retained SQL/RLS
  and native race), Flutter (format/analyze without issues, full unit suite,
  26 policy cases and actual Dart output/schema validation, web release build),
  Windows (release build). Separate source and verifier lint-fix reviews recorded.
- Local evidence: raw pure-Dart execution and actual-output validation of all 26
  cases, domain/tool analysis, formatting, 17 Python tests and whitespace/syntax.
  Full Flutter package resolution was unavailable locally; full unit/build evidence
  comes from CI. No browser/native interactive smoke or hosted integration claim.
- Shared fields/enums are unchanged. docs/SRS_ALGORITHM.md specifies the heuristic,
  rounding and #22 backend parity/auth/locking/replay requirements. Versioned
  golden cases are contracts/srs/v1/golden.json. No calibrated memory prediction.
- Not integrated: SRS UI study flow, public submit_review, stored receipt replay,
  auth or durable offline persistence. #22/#15/#20 retain these responsibilities.
  MASTERED remains reserved; memory stability/retrievability are not estimated.
- Next task: #5 original schema-valid N5 seed content. #22 can now port the pure
  scheduler with authoritative transaction tests; #11's #2/#3/#4 dependencies are
  satisfied. Live configuration does not block original content work.
- Personal Alpha remains IN_PROGRESS with curriculum, study screens, real auth,
  sync, Kanji, AI/voice and integrated release evidence still outstanding.

## Development handoff — Issue #5, 2026-10-13 UTC

- Branch automation/issue-5-n5-seed, base main 73c1dc8. Original editorial N5
  seed: 24 vocabulary, 8 Kanji, 10 grammar and 44 embedded example entries.
  Stable IDs, version/count/scope manifest, Vietnamese explanations and readings.
- Added strict offline export gate and 17 mutation/regression tests; CI runs the
  gate and all existing tests. Wire models, Flutter source and database unchanged.
- Local: content/schema/count/reference validation passed; 20 baseline fixtures
  and all 34 Python tests passed; Python compile/whitespace passed. Eight stroke
  counts cross-checked against pinned KanjiVG metadata; assets not redistributed.
- Flutter SDK/native PostgreSQL are absent locally. Existing full Flutter format,
  analyze/tests/SRS output validation, web/Windows builds and SQL/race checks must
  pass in CI for the PR's exact head before integration; no such result claimed yet.
- Not full N5/N4 curriculum; no audio, reference strokes, importer, hosted service
  or UI integration. Linguistic correspondence manually reviewed by the worker;
  independent teacher review is not observed. Details/provenance in data/README.md.
- Resume this PR first, then #6 Kanji capture/synthetic primitives. #26 tracks N5 expansion; #14 can extend
  the content gate with N4; #12 consumes original exports; #16 provides real assets.
  Personal Alpha remains IN_PROGRESS; no new user action is needed for #6.

- Separate review fix: reject duplicate JSON object members and fullwidth romaji
  readings; two mutation regressions added. No validation/security gate weakened.

## Integrated handoff — Issue #5 / PR #27, 2026-10-13 UTC

- Merged PR #27 as d5afac06f129f1c9ae899bd3827b24dfc89ae8d6; #5 completed.
  Separately reviewed exact head d1756a389895e7910d0fe6ff20b8d684006558fb.
- Original seed: 24 vocabulary, 8 Kanji, 10 grammar and 44 embedded examples with
  kana readings/Vietnamese text; stable IDs and honest scope/count/asset manifest.
  Pinned metadata provenance and linguistic notes are in data/README.md.
- Evidence: https://github.com/collab-TTAM/nihongo_daily/actions/runs/38443120630
  completed successfully; repo-sanity, database, flutter and windows all passed.
  repo-sanity validates the exports, 20 baseline fixtures and 34 Python regressions.
  Flutter retained format/analyze/full tests, 26 SRS policy cases and actual-wire
  schema checks/web release build; Windows release and SQL/RLS/native race passed.
- Local checks: 34 Python tests, content/contracts, Python compile, manifest schema,
  forbidden-file and whitespace checks. Local Flutter/native PostgreSQL unavailable;
  their evidence is CI, not local execution. Remote uploaded tree matched reviewed
  local files. No interactive browser/native or hosted service validation claimed.
- Review fixes: duplicate JSON object members and fullwidth romaji are rejected.
  No frozen wire schema, RLS, migration, Flutter or provider change.
- Limits: small editorial seed, not complete N5/N4 support. No audio/stroke geometry,
  importer or content UI integration; independent teacher review not observed.
  #26 tracks N5 scope/expansion, #14 N4, #12 study and #16 real reference assets.
- Next: #6 Kanji capture/normalization and synthetic scoring primitives, with #2
  and #1 already merged. No external credential blocks this work. Resume any open
  evidence PR first. Personal Alpha remains IN_PROGRESS with live integration,
  broader curriculum, offline/sync and release acceptance still outstanding.


## Development handoff — Issue #6, 2026-10-13 UTC

- Fresh main 8559956 includes merged #5 evidence PR #28; no open PR on claim.
  Branch automation/issue-6-kanji-capture, one sequential worker.
- Added pure immutable normalized models, bounded single-pointer capture, undo/
  clear, square mouse/touch/stylus prototype and synthetic-only geometric scores.
  Real grading is explicitly unavailable; no canonical assets or persisted progress.
- Local SDK exists but Flutter dependency bootstrap cannot complete in this
  environment. Raw Dart capture/scorer verifier passed and emitted two actual
  schema-valid requests; full Flutter analyze/tests/build and database/Windows
  checks require observed exact-head CI before integration.
- Added domain/widget regressions and actual-wire CI gate; no dependencies or
  frozen contracts/auth/RLS changed. docs/KANJI_CAPTURE.md records heuristic/limits.
- Resume this PR and CI first; after integration next worker task is #7 validated
  AI interfaces. #16 still gates real stroke assets/grading. Personal Alpha remains
  IN_PROGRESS; no hosted/backend/recognition/real-grade claim.

- Separate review fix: enforce event-time monotonicity even for coalesced stationary
  samples; added targeted regression. Added spacing for readable canvas guidance.


## Integrated handoff — Issue #6 / PR #29, 2026-10-13 UTC

- Merged PR #29 as 9d66f36123e5a2a958cf4a1c1b2177bbf5a46494; #6 completed.
  Separately reviewed/tested head 2743ed2e0388d2aaa69f2bf4282c6931a00c58f9.
- Delivered immutable finite/bounded square-coordinate models; single-pointer
  capture with relative monotonic time, boundary clamp, cancel/tap/limit handling,
  undo/clear; local Riverpod prototype on /kanji for mouse/touch/stylus.
  Pure nd-kanji-synthetic-1 primitives compare shape/order/direction/balance.
- Evidence: https://github.com/collab-TTAM/nihongo_daily/actions/runs/38446275479
  succeeded with all four jobs. Flutter format/analyze (no issues), 91 tests
  (21 new domain/6 widget tests), 26 SRS wire cases, 2 actual Kanji capture encodings
  validated against frozen schema, web release build; Windows release and retained
  database/RLS/native concurrent uniqueness passed. No required job skipped.
- Local evidence: raw Dart identity/reversal verifier, actual request schema,
  authored content/20 baseline fixtures/34 Python regressions, formatting/Python
  compilation/whitespace. Flutter dependency bootstrap unavailable locally; full
  Flutter/native PostgreSQL evidence comes from CI. All 15 uploaded files matched
  reviewed local hashes. No interactive browser/native device launch observed.
- Review fix: decreasing time after stationary/coalesced input cancels the stroke,
  with regression. Documentation distinguishes pure engines from integrated flows.
  No auth/RLS/dependency/provider/frozen-schema changes or weakened gates.
- Limits: no persisted Kanji attempts, curriculum selection, tracing/animation,
  canonical reference assets or real grade. evaluateReal explicitly reports
  reference absence; synthetic scores never appear as learner grades. #16 retains
  vetted assets/real grading work; docs/KANJI_CAPTURE.md records heuristic limits.
- Next sequential worker task: #7 provider-neutral validated AI interfaces after
  any open evidence PR. No secret/configuration needed for pure adapter tests;
  #17 still owns live services/voice. Personal Alpha remains IN_PROGRESS.


## Development handoff — Issue #7, 2026-10-13 UTC

- Branch automation/issue-7-ai-boundary; fresh main 59506e2, no open PR on claim.
- Added server-only provider-neutral TypeScript contracts/ports, strict original
  JSON Schema validation, immutable bounded requests/context, auth/rate guard,
  safe Vietnamese errors and deadline/abort handling. No live provider configured.
- Added private durable SQL receipt lookup/claim/token-completion, permission tests
  and native two-session claim race. Pending uncertainty never renews dispatch;
  lookup-only recovery must validate/correlate an existing result.
- Local: TypeScript check/format and 38 Node tests passed, original 34 Python tests,
  20 contract fixtures/content checks, Python compile/bash syntax/whitespace passed.
  Native PostgreSQL/full Flutter/web/Windows checks require exact-head CI; no such
  result claimed until observed. Existing CI gates retained; ai-boundary job added.
- Limits: injected test Auth/limiter/context/provider/memory store only; no deployed
  Edge/Deno compatibility, distributed runtime limiter, complete conversation
  transaction adapter, live provider, Flutter AI UI or voice. Follow-up runtime
  binding #31 must prove ownership/sequence/restart/reconciliation; #17 live/voice.
- Resume PR/CI/review first. After #7 merge next sequential task #8 QA matrix.
  Personal Alpha remains IN_PROGRESS; no external configuration needed for #8.

- Local additive migration, retained SQL/RLS suite and new AI receipt/security
  assertions passed on PGlite 0.5.9; native multi-session concurrency still needs CI.

- Separate review fixes: reject empty/oversized dispatch tokens before provider
  calls, freeze validated outputs/recovered context before asynchronous persistence,
  with two targeted regressions. No security/test gate weakened.

- Dependency audit found moderate Ajv advisory GHSA-2g4f-4pwh-qvx6; $data is
  disabled, and Ajv was upgraded from 8.17.1 to pinned 8.20.0 before integration.
  Added production dependency audit gate; current-head CI must rerun.

- UUID compatibility review: prepared-session binding compares logical UUIDs
  case-insensitively, while receipt comparison keeps immutable request fields.
  Added an uppercase client UUID regression; no auth/ownership check weakened.


## Integrated handoff — Issue #7 / PR #32, 2026-10-13 UTC

- Merged PR #32 as edb6465ed07af54ee2495be706afc2712382efb1; #7 completed.
  Separately reviewed/tested head e3200bc60c58e175d3d0414621f06c6d0b887467.
- Delivered provider-neutral server TypeScript interfaces for five frozen AI
  operations, original-schema validation/generated types, bounded immutable
  request/context/result, required verified-auth/rate/context ports, server identity
  and curriculum-ref checks, safe Vietnamese errors and deadline/abort handling.
  Private invoker receipt lookup/claim/token-completion helpers preserve ownership,
  original replay and pending uncertainty; recovery never dispatches a new call.
- Evidence: https://github.com/collab-TTAM/nihongo_daily/actions/runs/38452125458
  succeeded with all five jobs: repo-sanity, ai-boundary, database, flutter, windows.
  AI format/strict TypeScript/generated-type checks and all 38 Node tests passed;
  production dependency audit reported zero findings. Native PostgreSQL passed
  28 added AI SQL/security assertions and two-session dispatch claim race, retaining
  existing SQL/RLS/review uniqueness tests. Flutter retained 91 tests, analyze with
  no issues, SRS/Kanji actual-wire gates and web release; Windows release passed.
- Local: Node checks/tests, 34 Python regressions, 20 baseline fixtures/content,
  PGlite 0.5.9 migrations/SQL/RLS/AI assertions, Python compilation/bash syntax and
  whitespace. Native concurrency/full Flutter build evidence is CI, not local.
  Uploaded initial/patched trees matched 21 reviewed local files; no secrets.
- Review fixes: frozen output/recovery context, invalid dispatch token, equivalent
  UUID capitalization; Ajv moderate GHSA-2g4f-4pwh-qvx6 audited/patched to 8.20.0
  ($data disabled), production audit gate added. No test/security gate weakened.
- Limits: no deployed Edge/Deno proof, real Supabase Auth verification, distributed
  runtime limiter, actual conversation session/message transaction adapter,
  real provider, Flutter AI UI or voice. Test ports are explicit fixtures and do
  not count as integrations. #31 tracks trusted runtime/transaction/reconciliation
  binding; #17 live provider/voice, #20 account lifecycle, #18 integrated evidence.
  docs/AI_BOUNDARY.md details scope and safe pending recovery requirements.
- Next sequential worker task: #8 reproducible QA/security regression matrix after
  any open evidence PR. No external configuration needed for that inventory.
  #31's library dependency is resolved; real hosted/provider evidence remains
  pending configuration. Personal Alpha stays IN_PROGRESS beyond starter tasks.


## Development handoff — Issue #8, 2026-10-13 UTC

- Fresh main 98397e72; no open PR on claim. Single sequential worker on
  automation/issue-8-qa-matrix. #1–#7 implementation/evidence already merged.
- Added 27-case machine-readable QA matrix: 13 executable baseline groups with
  concrete test anchors, reproduction/scope limits; 14 pending integrated release
  cases. Six ranked findings distinguish missing assurance from a proven exploit
  and the remediated Ajv advisory. Created #34 for unassigned Listening/Reading.
- Added standard-library inventory and exact-head Actions evidence verifier:
  explicit repository/workflow/head/run/attempt, all five jobs/critical steps,
  complete pagination, no missing/skipped/pending/mixed results. CLI never executes
  matrix commands or certifies metadata authenticity. Synthetic test data is TEST ONLY.
- Local: 17 QA negative regressions, original 34 Python tests, 20 frozen fixtures
  and content export checks passed. Prior-main CI 38453557158 passed all five jobs;
  this is historical, not the #8 head. Full current-head Node/SQL/Flutter/web/Windows
  CI must be observed before integration. No new runtime/provider/migration change.
- QA_SECURITY_MATRIX documents reproduction, evidence retrieval, ranked findings
  and the unchecked release checklist. Baseline green cannot pass --release while
  live Auth/RPC/plan/study/content/assets/Edge/AI/voice/sync/progress/smoke/journey
  evidence remains pending; no Personal Alpha completion claim.
- Resume #8 PR/CI and separate review first; next priority #22 authenticated atomic
  review transaction, then #31 runtime bridge and #11 plan/session work by dependency.
  Local implementation can proceed without secrets; hosted evidence remains pending.

- Separate review hardening: verify command/step anchors within their actual CI
  job, so moving an audit elsewhere cannot preserve coverage; reject removed
  ranked findings and out-of-repository test anchors. Three regressions added.

## Integrated handoff — Issue #8 / PR #35, 2026-10-13 UTC

- Merged https://github.com/collab-TTAM/nihongo_daily/pull/35 as
  250cc1ff2c21da876ce7a8e9004b77c0bb6145ef; #8 completed as QA inventory/evidence tooling.
  Separately reviewed/tested head 7ee60f0f54297231147e1dd7ac1e1fe4662ea6fd.
- Delivered qa/matrix.json: 27 assurance cases (13 executable baseline groups,
  14 pending integrations), exact file/statement anchors, reproduction commands,
  issue owners and limits; six severity-ranked findings distinguish five missing
  assurance gaps from the already patched dependency advisory. docs/QA_SECURITY_MATRIX.md
  maintains the reproduction/evidence instructions and unchecked release checklist.
- Standard-library verifier rejects stale head/repo/workflow, mixed run/attempt,
  incomplete pagination, missing/duplicate/unreviewed jobs or steps and non-success
  states. It never executes matrix commands or authenticates saved metadata.
  CI now validates inventory and all 17 QA regressions, retaining every prior gate.
- Evidence: https://github.com/collab-TTAM/nihongo_daily/actions/runs/38455196645
  succeeded with all five jobs: repo-sanity (17 QA, 34 existing Python tests,
  20 frozen fixtures/content), ai-boundary (38 Node tests/format/type/generated
  checks, zero production audit findings), database (retained SQL/RLS and both
  native concurrency races), flutter (analyze without issues/tests/SRS/Kanji
  actual-wire checks/web release), windows (release build/artifact).
- Fetched unmodified workflow run and complete latest-attempt jobs via connected
  GitHub; verifier accepted exact-head evidence. Prior-main CI was rejected for
  missing the new QA step. With the real successful CI snapshot, --release
  intentionally returned nonzero because 14 integration cases remain pending.
  No release completion, interactive device/browser or hosted-service claim.
- Local: 17 QA regressions, 34 Python tests, contract/content checks, compilation
  and whitespace passed. Remote uploaded tree c462f344 matched reviewed local
  files. Full Node/native SQL/Flutter/Windows results came from current-head CI.
- Review hardening: scope step anchors to their actual job, reject test paths
  outside the repository and removal of ranked findings. No wire/auth/RLS,
  runtime/provider/migration changes or weakened checks.
- Follow-up #34 covers the previously unassigned Listening/Reading module with
  honest audio availability and valid-session/retry requirements. Existing issues
  retain all auth, RPC, plan/study, N5/N4, real Kanji, AI/voice, sync and progress gaps.
- Next sequential task: #22 authenticated atomic submit_review, whose schema/SRS
  dependencies are merged. Implement local SQL/typed adapter/transaction evidence
  without waiting for live secrets; do not close #22 without its full acceptance.
  Then #31 runtime binding and #11 plan/session work by dependency. #18 remains
  blocked by integrated Personal Alpha evidence; independent development continues.

## Daily Plan server snapshot — core-20261019T1454-daily-plan

- Independent main-based branch automation/issue-11-daily-plan from78a44faf, after reader/search PR #39 57acb70 passed CI39272055003 latest attempt all5 jobs/110 Flutter tests/Web+Windows. #37/#39 source and Pro #14/#38/N4 untouched; single core marker in #37.
- Additive public.get_daily_plan(p_request jsonb) uses existing Supabase auth.uid identity, strict frozen date request, qualified definer boundary/empty search_path, provisioned profile and existing user/date uniqueness. No client owner/target/readiness/progress input or new table/RLS grants. Existing plans are never rewritten. Largest-remainder nd-plan-1 preserves seven positive blocks and exact120-minute default for targets7..1440. Profile-local exclusive midnight determines due candidates; unsupported resources/services stay BLOCKED.
- Native SQL role tests authored for every target/default/min/max, A/B isolation, strict bad requests, private/anon grants, Vietnam/DST/DateStyle/leap dates, preserving started145-minute/changed-settings/content snapshots and row identity/time, malformed storage and rollback/redacted errors. Python validates7 actual SQL successes/1 error against frozen contracts and races two native connections plus a fresh-connection retry. All existing SQL/RLS/AI/Flutter/contract/security gates retained; database job installs existing pinned jsonschema for new actual-wire validation.
- Local Python compilation, bash syntax, git diff --check, QA inventory27 and all17 QA regression tests passed. Production migration/security and test/CI diffs reviewed separately. Runtime lacks native PostgreSQL and importable jsonschema; no SQL/role/wire/concurrency or new-source full CI pass claimed locally. Exact-head native CI is mandatory.
- Policy/security review and reproduction/limits are in docs/DAILY_PLAN.md. No deployment, Auth-provider/strategy, collection/spend change or security reduction. No secrets supplied/requested. Trusted fixture progress is not real session ingestion/aggregation. Main UI stays labeled preview.
- Keep #11 open/draft: validated idempotent session events/aggregation, typed account-scoped app adapter, offline/restart/UI and hosted learner evidence remain. All14 live Personal Alpha groups pending. Next invocation must read actual head/marker/latest-attempt required checks and fix failures preserving assertions; only CI pending means persist/release without duplicate work.

## Daily Plan fixture baseline correction — core-20261019T1506-plan-fixtures

- Fresh GitHub worktree matches #40 source595f2917c39037169e10f7a96e24d2b0f59b70aa/tree924f1d92b2b6d38ac59c20e78ce16657357b4bbe. Prior worker released; one core writer, Pro #14/#38/N4 reserved.
- Exact CI39274376359 attempt1 completed with ai-boundary/repo-sanity/flutter/windows passing. Database applied migrations and actually passed all1434 target allocations/default, RPC/private/anonymous ACLs, missing Auth/profile, twelve invalid requests and denied client progress update. It then failed the first Vietnam/content-count assertion; no subsequent SQL/wire/concurrency pass claimed.
- The existing native review race intentionally commits active N5 vocabulary92000000-0000-4000-8000-000000000001. The new SQL test incorrectly expected only its3 N5 rows. The test now captures preexisting active N5/N4 vocabulary and N5 grammar counts before seeding, and requires exact baseline+3/+1 totals. Own SRS2 and midnight/level/owner/status/progress assertions are retained. No prior fixture removed/retired or production function changed. Failure diagnostics include the fixed test response so any further cause is visible.
- Test progress/identity and rollback probes now explicitly scope to this suite's own user/date, preserving unrelated committed test rows. Changed only supabase/tests/daily_plan.sql, docs/DAILY_PLAN.md and this handoff; no migration/RPC/ACL/RLS/CI/app/content/dependency source change. Separate diff review and git diff --check passed; native PostgreSQL is absent locally, so exact-new-head CI is required and no native result is claimed.
- Next: inspect actual head/latest-attempt required checks first and fix any remaining failure preserving assertions. Keep #40 draft/#11 open; valid session ingestion/aggregation, typed account-scoped app/UI and hosted learner proof remain missing. All14 live Personal Alpha groups pending; no #37/#39/Pro #38 source, merge/deployment/schedule/security/provider/spend change.

## Typed Daily Plan client boundary — core-20261019T1513-plan-client

- Resumed #40 from verified fdd585855ba7d911516fc6ac40e004c8909d82b4 on automation/issue-11-daily-plan. Exact CI39275287778 completed successfully: all five jobs/every required step, native SQL allocations/ACL/date/isolation/snapshot tests, seven actual SQL wire successes/one error, concurrent first-create/retry/new connection, Flutter/analyze and Web/Windows artifacts. Previous fixture failure is resolved. No hosted acceptance inferred.
- Added two pure Dart files: immutable strict frozen Daily Plan date/block/response projections and read-only captured-session repository. Validate real dates, exact fields, seven unique areas/positive allocation totals, statuses/nonnegative exact numbers and returned date. Preserve over-target progress. RPC parameters contain only p_request/date; no user ID/client derived-state writes. No cache/automatic retries. Fence dispatch and late success/failure on revoked session generation; fixed safe Vietnamese errors discard raw server/transport text and constrain retry advice to network/provider/limits.
- Sixteen authored unit cases cover the canonical fixture/strict decoder/calendar/precision/immutability, exact dispatch/fresh reload, revoked session, account switch and late completion/failure, named error variants/redaction and explicit offline retry. Production/test diffs reviewed separately. Local Dart formatter/pure-source analysis, actual-fixture standalone Dart smoke, QA inventory27 and all17 QA regressions passed. Full Flutter analyze/tests/build unrun locally because Flutter startup/dependency setup did not complete; new-head Actions must verify them. Historical fdd5858 CI is not evidence for the increment.
- This supplies an adapter interface, not real Supabase dispatch or installed UI. Gateway must be bound to the owned verified Auth session/generation with bounded transport; #37 composition and all hosted A/B/restart/multi-device proof remain. No default fake success, migration/API/schema/RLS/dependency/CI change or Pro #14/#38/N4/#37/#39 source edit. No deployment/merge/schedule/provider/spend change. #40 remains draft/#11 open; all14 live release gates pending.
- Next: inspect actual new head/latest-attempt CI and fix failures preserving tests. Then implement valid idempotent session events/aggregation and/or compose this boundary with the owned runtime and typed UI; do not claim learner readiness before actual configuration and evidence. Only pending CI means durable handoff/release, not duplicate code or long polling.

## Daily Plan strict test inference correction — core-20261019T1846-plan-analyze

- Fresh clone/head784502e8b04d9636c9091294249a152b44a2fb68; prior core worker released. CI39304221710 completed: database, repo-sanity, ai-boundary and Windows succeeded. Flutter format passed; analyze reported one inference_failure_on_collection_literal at daily_plan_test.dart:151 (untyped empty malformed-input list). Flutter tests and downstream Web/wire steps were skipped, so the16 cases are not yet execution-verified.
- Added explicit Object? element type to that intentionally empty malformed-input fixture. All16 test cases, assertions, production source, lint strictness, CI/security/RLS/contracts and Pro #14/#38/N4 remain unchanged. Reviewed the one-line test diff independently; Dart formatter and git diff --check pass. Full Flutter analyze/test/build require new-head CI; historical Windows/database success does not verify this successor.
- Keep #40 draft/#11 open/all14 hosted release groups pending. No merge/deployment/schedule/provider/security change. Next invocation checks actual head/latest-attempt required steps and fixes any remaining failures; after green prioritize session-event aggregation and integration of the owned Auth/Daily Plan/study path. Persist/release while only CI is pending.

## Trusted completed-session progress — core-20261019T1851-study-sessions

- Started from fresh #40 head911eb781fa85f0c7c707a74e1cf2a7681b97f24c after exact CI39305465372 passed allfive jobs/every required step, all16 Daily Plan cases, format/analyze and Web/Windows. One core writer with marker in #37; Pro #14/#38/N4 and #37/#39 source unchanged.
- Additive private.record_study_session(p_owner,p_request) is a narrow service-only definer/empty search_path and immutable private receipt ledger with RLS/no direct client or service table grants. No public API or frozen schema/endpoint change. Future trusted backend must verify JWT/activity/owner; this helper does not establish learner authentication or active studying and is not installed in Flutter. No hosted migration/deployment.
- Strict five-field event/time/date validation, existing plan/snapshot availability, per-snapshot timezone/level/allocated minutes; derive floor(elapsed seconds/60), reject sub-minute/future/out-of-day/overlapping intervals. Native23/25-hour DST policy max1500 minutes per interval; cross-midnight requires separately validated day events in future runtime. Owner profile lock serializes receipts/plan writes. Exact replay returns original frozen plan response; changed event conflicts. Add uncapped derived progress once, update only area's IN_PROGRESS/DONE and preserve prior DONE/other snapshot fields. Session/ledger/plan changes roll back together on any failure. Unreceipted legacy rows do not inflate totals.
- Authored native role/strict-request/A-B/derived-field/replay/overlap/settings/boundary/DST/IN_PROGRESS-DONE/corruption/late-failure rollback tests. Python validates11 actual SQL success responses/one error against frozen definitions and uses native uncommitted duplicate/distinct-adjacent races, changed replay/overlap, fresh connection/read and exact3-session/receipt checks. Existing database runner adds this suite after all prior gates; no test/security gate removed.
- Local Python compilation, shell syntax, separate production/security and test/runner diff review, git diff --check, QA inventory27/all17 QA regressions passed. Runtime lacks PostgreSQL/jsonschema, so native migration/roles/wire/races and whole new-source CI remain unverified until exact-head Actions. Historical911eb7 pass is not evidence for this increment.
- Boundary/policy and remaining authenticated runtime contract decision are documented in STUDY_SESSIONS.md, DAILY_PLAN.md and supabase/README.md. Client mutation gateway/owner verification/activity validation/typed session transport, durable event queue/recovery, UI integration and hosted learner proof remain. Keep #11/#40 open/draft/all14 live Personal Alpha gates pending. No merge/schedule/provider/spend/Auth-strategy/security reduction.
- Next: inspect new actual head/latest-attempt required CI and fix any failure preserving assertions. Only CI pending means persist/release without duplicate implementation/long polling. After green compose owned Auth/Daily Plan/study with a separately reviewed end-user mutation contract; never expose service credentials or caller-controlled owner to learners.

## Authenticated study-report boundary — core-20261019T1904-study-submit

- Fresh #40 source02e9ee00aa2304731f5eb2436e03a547700a611b verified at CI39307231511 allfive jobs/every required step. Native helper actually passed roles/strict commands/calendar/overlap/replay/settings/DST/late rollback,11 frozen success payloads/one error and uncommitted duplicate/distinct-adjacent races with45 minutes and fresh read/replay. Web/Windows and all16 client tests passed. Single core marker #37; Pro #14/#38/N4/#37/#39 source unchanged.
- Scoped interface/security/compatibility review in STUDY_SESSION_API.md defines a separately versioned contracts/study/v1 addition; no frozen v0.1 file edit. Strict five-string UTC request has no owner or derived minutes. New authenticated-only public.submit_study_session derives owner from existing gateway-verified auth.uid and calls the unchanged atomic private ledger; narrow definer/empty search_path, anonymous/service wrapper denied, private/table grants and all existing RLS retained. Auth strategy/providers and collected fields unchanged. Explicit policy: authenticated self-reported duration, not proof of attention or mastery; no score/SRS outcome writes or paid calls.
- Added immutable canonical UTC CompletedStudySession and optional same-lease DailyPlanStudySessionGateway/typed repository submit. Shared strict request/response/date/error fencing remains on reads and writes. No local completion/cache/automatic retry; missing capability fails explicitly, late revoked-owner success/failure discarded. Ambiguous responses require retaining original event; receipt replay can hold older progress so dashboard must load latest plan separately. Durable queue, owned SDK transport and actual UI remain missing; no fake save is installed.
- Authored five separate Python contract cases, eight Dart submit/model cases and native Auth-role tests for ACL/missing identity/profile/derived A-B owner/override/private denial/UTC/replay/RLS/latest read. Python validates four actual versioned request/response pairs against new request and frozen output definitions. All prior16 read cases and SQL/race/QA/build/security gates retained. Database runner appends wrapper tests after all prior gates; existing contract discovery picks up new suite.
- Local pinned-Dart format/pure-source analyze, actual fixture/exact nested submit/authoritative response/revoked late-write standalone smoke, Python compilation, JSON syntax/UTC-regex fixture spot-check, shell syntax, separate production/security and test diff review, whitespace and all17 QA regressions passed. PostgreSQL/jsonschema/full Flutter dependencies absent locally; native/schema/full tests/new-source build need exact-head Actions. Prior source green CI is historical, not current evidence.
- Keep #11/#40 open/draft/all14 hosted release groups pending. No migration/deployment/merge/schedule/Auth strategy/provider/spend/security reduction. Next: inspect actual new head/latest-attempt CI, fix failures preserving assertions, then bind owned captured Auth RPC transport, durable session queue and learning/plan UI. Do not expose service authority or claim restart/two-device/learner proof without actual evidence.
