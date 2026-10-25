# PROJECT STATUS

Current release target: Personal Alpha
Overall status: IN_PROGRESS — starter baselines #1–#8 merged; real learner flows, N5/N4 expansion and live integrations remain outstanding.

| Milestone | Status | Owner / prerequisite |
| --- | --- | --- |
| Architecture baseline | MERGED via PR #10; #1 completed | Lead |
| Flutter skeleton | MERGED via PR #19; #2 completed | #2 Flutter |
| Supabase schema/auth | MERGED via PR #21; live Auth tracked in #20 | #3 Backend |
| SRS engine | Pure nd-srs-1 MERGED via PR #24; PR #37 draft includes atomic SQL/SDK/UI/durable recovery/profile readiness; live integration pending | #4 / #22 / #20 / #15 |
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


## Development handoff — Issue #22 server transaction increment, 2026-10-13 UTC

- Fresh main 78a44faf; no open PR on claim. Single sequential worker on
  automation/issue-22-atomic-review; #3/#4 schema/policy dependencies are merged.
- Added strict seven-field request/canonical instant/response helpers, private
  nd-srs-1 SQL port and narrow authenticated caller-bound submit_review(jsonb).
  No direct table grants/RLS weakening or auth strategy/provider/deployment change.
- Owner mutex + content share lock/item row lock provide replay-before-stale,
  active-content/five-minute skew validation and atomic event/state/counter writes.
  Exact raw fractional identity/chronology survives microsecond scheduling;
  reserved memory fields remain unchanged. Corrupt stored responses fail closed.
- Local observed: migration/retained baseline/AI and 62 new RPC SQL assertions
  passed on PostgreSQL via PGlite 0.5.9; actual private SQL outputs matched all
  26 frozen Dart policy cases. 40 Python regressions, 17 QA tests and inventory
  passed. Six Python parity-validator regressions are TEST ONLY fixtures.
- Five native race scenarios authored; native PostgreSQL and full Node/Flutter/
  web/Windows CI remain current-head acceptance checks until observed. Local
  PGlite cannot certify two-session/native concurrency or real JWT/PostgREST.
- docs/SRS_RPC.md records transport wrapper, normalization/resource limits,
  permissions, serialization/rollback policy and evidence limits. QA matrix now
  has 28 groups; review-rpc remains a pending integration release case.
- This is a complete SQL increment within an incomplete #22. Keep issue/PR open:
  typed Flutter adapter, integrated SRS UI and real Auth/PostgREST acceptance
  remain. Resume this draft/review/CI first, then implement typed transport/UI
  without presenting fixtures as live integration. No secrets requested in chat.
  Personal Alpha remains IN_PROGRESS; do not close #22 from SQL fixture success.

- Separate review: native race harness now observes the second backend actually
  waiting on the advisory lock before releasing the first transaction; no timing
  guess/sequential replay can count as concurrency. Clarified private invoker vs
  narrow public definer documentation. Keep draft for remaining full #22 gates.


## Sequential resume — Issue #22 typed repository, 2026-10-13 23:04 UTC

- Resumed existing draft PR #37 / automation/issue-22-atomic-review after its
  unchanged head 7018a339 and no newer worker activity for three hours. Fresh
  main remains 78a44faf; no other open PR. No parallel worker/agent.
- Observed all five jobs successful for SQL head 7018a339 at
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38459542474, including
  native PostgreSQL/RLS/62 RPC assertions, 26 SQL/Dart cases and five lock-observed
  concurrency scenarios, retained Flutter/web/Windows and AI gates. That run is
  historical SQL-head evidence, not evidence for this new Dart increment.
- Added typed ReviewRepository/RpcReviewRepository using injected Auth/RPC ports,
  immutable session-bound events, strict five-field success/three-field errors,
  safe fixed Vietnamese messages, timeout uncertainty and old-session isolation.
  No scheduler/client-derived writes, automatic retry or direct table calls.
- Added 21 Flutter regressions plus a raw-Dart verifier: actual encoder/decoder
  outputs for 26 original server-response fixtures, invalid data, timeout/immutable
  retry and session replacement. Fixture ports/responses are TEST ONLY and cannot
  count as SQL-to-Flutter, live Auth, actual retry-after-later-reviews or UI evidence.
- Local raw-Dart verifier and 26 encoded schema pairs passed; 40 Python tests,
  17 QA tests and inventory passed before final docs/CI changes. SDK dependency
  bootstrap cannot complete here, so full Flutter analyze/tests/web/Windows and
  all final-head gates require observed GitHub Actions before any success claim.
- QA now tracks 29 cases; new fixture adapter group and CI steps are explicit.
  All 14 integration release cases stay pending. No frozen contract/dependency,
  Auth strategy/RLS, data collection/provider, production or release change.
- Keep #22 open and PR #37 draft. Next worker resumes final-head CI/review, then
  concrete SDK/Auth binding and SRS UI/queue acceptance with #20/#15; independent
  implementation still needs no secrets in chat. Personal Alpha IN_PROGRESS.

- CI 38482842040 passed repo-sanity/AI/database at head 74a8d110, but Flutter
  analyze found one missing if block and one untyped empty test list. Both were
  fixed without relaxing lint/tests; all final-head checks must rerun. Flutter
  tests/builds skipped after failed analysis are not counted as success.

## Sequential resume — Issue #22 SRS screen readiness, 2026-10-13 23:55 UTC

- Fresh main 78a44faf; only open PR is existing draft #37 at b0375f67. Prior worker
  released. All five jobs at CI 38483096635 succeeded for the typed repository,
  including 112 Flutter tests/web/Windows and native SQL/RLS/parity/races. This is
  prior-head evidence, not evidence for this new UI increment.
- SDK/Auth/real due queue are not configured. Continue independent application/UI
  work on the same branch, not a new issue/PR: pure SRS controller, typed queue
  projection, Riverpod lifecycle binding and /srs load/reveal/rate/save/retry flow.
  Default runtime is null; no fake due content, account, confirmation or progress.
- One immutable prepared event; controls lock during save; uncertain retry keeps
  original rating/ID/time/duration. No reload discards an uncertain event; explicit
  definitive conflict/rejection permits reload. Only validated receipt advances
  local acknowledged count. No Daily Plan/mastery/server-state overwrite.
- Session callbacks clear old visible curriculum/receipt and invalidate asynchronous
  replies by generation; route navigation retains in-memory pending state, not
  app restart. Closed lifecycle stream disables runtime. No credentials or disk
  storage added. Real SDK/Auth/cache/queue/reconciliation are #20/#15/#22 work.
- Local raw-Dart controller/repository verifier passed 26 TEST ONLY fixture pairs,
  reveal-before-rating, uncertain immutable retry and session-change suppression;
  emitted request/response schema check passed. Pure source/tool analysis passed;
  40 Python and 17 QA tests passed before final CI/documentation changes.
- Flutter dependency bootstrap is unavailable locally; full format/analyze/unit/
  widget/web/Windows and retained database/AI gates must be observed in current-head
  CI. New tests include accessible 320/375px UI at 200% text and controller failure/
  duplicate/disposal/deadline bounds. 30 QA groups, all 14 integration gates pending.
- No dependency/schema/Auth strategy/RLS/deployment/cost/data collection change.
  Review diff separately; resume PR #37 CI first. Keep #22 open/PR draft; next
  increment is concrete SDK/Auth/queue binding and durable event integration with
  non-production evidence. Independent work continues; no secrets requested.

- First UI CI 38488298013 passed repo/AI/database but found one router format
  difference after full Flutter package resolution. Reproduced with the correct
  local package language version and formatted that route; no format/analyze/test
  gate changed. Skipped later checks are not counted as passes; rerun final head.

- Follow-up CI 38488570435 passed formatting, but analyze found a missing direct
  ReviewRating domain import and three multiline if blocks without braces. Fixed
  import/blocks without changing behavior or weakening lint; full test/build
  evidence still requires the next exact-head run.

## Sequential resume — Issue #22 due-queue bridge, 2026-10-14 00:57 UTC

- Fresh main 78a44faf; resume only open draft #37 at 104dcdd8 after previous worker
  released. All five prior-head jobs at CI 38488768979 passed, with 139 Flutter
  tests/web/Windows and retained SQL/RLS/races. That is not new-head evidence.
- Actual due data read was missing behind the SRS UI's abstract queue. Added
  separately versioned nd-review-queue-1 contract and local get_review_queue RPC:
  stable invoker, empty search_path, existing RLS plus explicit auth.uid owner,
  provisioned profile, reviewed/due/active/level/order/bounded-limit read snapshot.
  No v0.1 operation/field, table/RLS grant, enrollment or derived-state write changed.
- Added strict RpcSrsStudyQueue/ReviewQueueSnapshot: ownerless captured-session
  envelope, limits/fields/UTC precision/due/order/duplicates, safe errors/deadline,
  old-session rejection. Canonical grammar reading is explicitly absent, not an
  example pronunciation; UI shows that absence instead of fabricated content.
- Added native SQL read/security/filter/assertions and actual seven-case response
  export. Flutter now depends on database and consumes the same-run artifact for
  actual SQL fixture output -> Dart DTO/RPC projection -> schema checks. Original
  full tests/builds/races retained; missing/skipped/past-head artifacts cannot pass.
- Local pure Dart DTO/RPC verifier and schema passed seven HAND-AUTHORED TEST ONLY
  cases; source/tool analysis/formatting and 49 Python tests passed. No native SQL,
  full Flutter/widget/web/Windows or real JWT/PostgREST success claimed locally.
  Final-head CI must establish new SQL/SQL-to-Dart/build evidence. QA: 32 groups;
  all 14 release integrations remain pending. docs/REVIEW_QUEUE records review/impact.
- Default app runtime stays null. No SDK/Auth binding, credentials, deployment,
  token persistence, paid call or data collection change. Keep PR draft/#22 open.
  Next: concrete SDK/Auth/profile/runtime binding with #20, durable pending/receipt
  reconciliation/restart with #15, and real non-production A/B/expired JWT/SRS UI
  evidence. This read bridge is independent implementation, not release completion.

- First queue CI 38495122637 correctly rejected fixture enrollment into already
  inactive curriculum. Fixed fixture ordering: enroll while active, then retire;
  no validation/RLS trigger weakened. Exporter now prints disposable-fixture SQL
  diagnostics and exits safely without an artifact on failure; no connection URL
  is included in its failure message. Final-head native/Flutter checks must rerun.

- CI 38495371143 observed all 36 native queue assertions and seven actual SQL
  response exports passing, plus repo/AI gates. Flutter analyze found three
  multiline if blocks without braces; fixed without relaxing lint. Its skipped
  test/SQL-to-Dart/build steps are not yet counted; wait for final-head rerun.

## Verified prior due-queue handoff — PR #37, 2026-10-14 UTC

- Head 7273e62d4c13d04e5a8566d9b6932090de72a70b passed all five jobs at
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38495696580:
  Flutter analyze/no issues, 149 tests/web, Windows release/artifact, 36 native
  queue assertions/seven actual same-run SQL -> Dart projections, retained
  SQL/RLS/parity/races/AI/repo gates. Exact-head metadata verifier accepted all
  critical steps. Separate diff reviews and worker release are saved on GitHub.
  This is historical evidence, not proof for the next source increment.

## Sequential resume — Issue #22 lifecycle readiness, 2026-10-14 02:05 UTC

- Fresh main remains 78a44faf; only open draft #37 unchanged at verified prior
  head 7273e62d after worker release. Resume the same branch with one worker.
- Flutter dependency bootstrap was blocked by runtime policy after attempted
  access to unrelated cloud metadata; no retry/workaround. Continue independent
  dependency-free lifecycle source and fixture tests; concrete SDK resolution,
  Auth event listener/profile/storage and real HTTP remain unimplemented.
- Added ReviewConnectionRegistry: fresh lifecycle vs same-user refresh, expiry
  timer/access guard, synchronous clearing, closure snapshot/old-result rejection,
  bounded immutable ownerless request, redacted failure and explicit disposal.
  Added explicit runtime factory wiring the existing typed queue/repository to
  that same registry. Default app runtime remains null; no network is activated.
- Tests/tool use TEST ONLY captured connection closures; closure credentials/JWT
  cannot be authenticated by this registry. Source/format/raw verifier can run
  locally; full Flutter tests/analyze/native SQL/web/Windows require observed
  current-head CI. No full build/SDK/learner success is claimed locally.
- QA inventory adds a lifecycle group (33 total); all 14 integration release
  cases remain pending. No dependencies, frozen API/SQL/RLS, Auth strategy,
  production/data collection/provider/cost changes. Keep PR draft/#22 open.
- Next: approved SDK dependency resolution and concrete captured-token/Auth
  events with #20/profile provisioning, then #15 durable recovery/reconciliation
  and real non-production A/B/expired JWT/learner evidence. No secrets in chat.

- CI 38500368761 passed database/repo-sanity/AI but Flutter analyze found three
  verifier CLI lint issues (relative lib imports and print). Replaced with package
  imports and stdout; no lint gate weakened. Skipped Flutter tests/builds are not
  successes. Full corrected-head CI remains required.

- CI 38500591480 passed analysis and 165 tests; one runtime assembly test exposed
  nonidentical stream wrappers from repeated controller.stream access. Cache the
  registry lifecycle stream so assembled runtime has a stable handle; retain the
  assertion and add a raw-Dart regression. No test expectation weakened. Native
  database/repo/AI passed; full final-head Flutter/build evidence must rerun.

## SDK binding resume — Issue #22, 2026-10-14 03:02 UTC

- Fresh main 78a44faf; resume draft #37 at unchanged 3ff15977 after released
  worker. CI 38500891063 observed all five jobs successful with 166 Flutter tests,
  web/Windows and retained native SQL/AI gates. This is prior-head evidence only.
- Resolve SDK candidate lock in isolated read-only Actions at 5bfa29b4, run
  38504490159 observed successful. Import its public manifest/lock; already-locked
  logging becomes direct for security log controls. Remove temporary bootstrap
  workflow, recoverable in git history. No local blocked dependency retry and no
  change to original app enforce-lockfile/format/analyze/test/RLS/build gates.
- Add concrete Supabase Auth event/current-session and captured-token PostgREST
  bridge with explicit runtime factory. Same server session_id refresh retains
  identity; new login/A-B-A/expiry/disposal rejects old results. Bounded HTTPS
  config/public-key guards, no direct table write/automatic RPC refresh/retry,
  1 MiB HTTP response cap, safe errors and disabled unsafe SDK Auth/RPC logs.
- SDK/HTTP fixture tests authored; unsigned test tokens cannot authenticate real
  users or certify hosted JWT/RLS. Local formatting and Python/QA checks only;
  full SDK/Flutter/build/native SQL must be observed for the current head in CI.
  QA: 34 groups; all 14 integrated release cases remain pending.
- Default runtime remains null. No login UI, profile provisioning, secure token
  storage/restoration, durable pending queue, deployment or live learner evidence.
  No Auth provider/strategy, RLS, frozen API/SQL, production, data collection or
  paid provider/cost change. Keep PR draft/#22 open. Next #20 profile/login/storage,
  #15 durable recovery and actual non-production A/B/expired JWT/SRS journey.

- Separate follow-up review: add explicit whitespace/config bounds, block braces
  for multiline verifier-facing guards, and chunked-body/malformed-session-ID
  regressions. Preserve expectations and all checks; final-head CI must rerun.

- CI 38505690541 passed database/repo/AI but SDK Flutter analysis rejected three
  multiline if blocks and a closure-variable declaration. Use blocks/local
  function, not disabled lint. Its skipped tests/builds do not prove success.

- CI 38506024037 observed all five jobs successful at 7c27af43, including new
  SDK HTTP tests/builds. Follow-up security review extends OFF logging to the
  whole supabase logger family and strengthens the root-ALL sink test. This
  prior-head success does not certify that final log-policy change; rerun gates.

## Verified concrete SDK binding handoff — 2026-10-14 UTC

- Source head d7df49b472b3e74ce8bc85546d50e598ee3e0aea passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38506398102 .
  Observed Flutter format/analyze (no issues), **184 tests including 18 SDK/HTTP
  cases**, enforce-lockfile, web release/artifact, Windows release/artifact and
  retained SQL/RLS/parity/observed-lock races/AI/repo gates. The unmodified run
  and all five latest-attempt jobs passed scripts/verify_qa.py for that exact
  source head and every critical step. This evidence is historical for later
  commits; documentation-only successors require their own CI before merging.
- Concrete pinned Supabase SDK Auth events and captured-token PostgREST binding
  now have build/test evidence. HTTP/Auth fixtures still use TEST ONLY unsigned
  JWTs; they do not verify hosted signatures, real Auth/RLS or a learner journey.
  Unsafe SDK loggers are OFF including the parent family; all assertions remain.
- Default runtime is null. No login screen, own-profile provisioning, secure
  token persistence/restoration, durable pending event/restart reconciliation,
  deployment or hosted JWT evidence is claimed. QA inventory: 34 groups,
  all 14 Personal Alpha integration cases remain pending. Keep PR #37 draft
  and #22 open; do not merge this incomplete integration.
- Bounded sequential SDK worker released after evidence persistence. Next worker
  must inspect the current PR head first, then implement #20's login/profile and
  secure session lifecycle using the approved Auth strategy, followed by #15's
  durable owner-scoped pending/receipt recovery. Actual non-production missing/
  expired JWT, account A/B isolation and signed-in SRS acceptance still require
  supported service configuration; never request secrets in chat. Independent
  source/tests can continue without configuration. No RLS, provider, production,
  data collection or paid-cost changes.

## Native durable-review resume — 2026-10-14 UTC

- Resume unchanged draft #37 at 3f9fc78a with one worker after the released SDK
  handoff. Add opt-in native bounded append journal and DurableReviewRepository:
  flush pending before dispatch, immutable original-receipt persistence/replay,
  strict exact timestamp restore, explicit manual pending recovery under fresh
  same-owner Auth and late lifecycle rejection. Default runtime remains null.
- Actual raw-Dart subprocess/disk verifier passed locally: exit without close,
  reopen/exact pending recovery, reject second-process writer, original manual
  replay/durable receipt and interrupted tail versus complete corrupt record.
  Auth/RPC responses are TEST ONLY; no hosted/two-device learner proof.
  Pure source/tool analyzer and formatting passed. Local QA inventory/17 QA
  regressions passed; full Flutter lint/test/web and Windows require current-head
  CI. Twenty Flutter cases authored, not yet claimed passed locally.
- Add required real-disk subprocess verifier to Linux Flutter and Windows CI,
  retaining all existing gates. QA 35 groups, all 14 integration releases remain
  pending. No dependencies, frozen RPC, RLS, Auth strategy or deployment change.
- Limits/risks: native-only, single owner isolate, 1 MiB/512 retained events,
  fail-closed capacity/corruption, no compaction/encryption or hardware power-loss
  certification. This is an opt-in storage/repository library; no automatic send,
  token storage, runtime installation or UI restart flow is implemented.
  Separate architecture/security impact is recorded in DURABLE_REVIEW_JOURNAL.
- Keep #37 draft/#22/#15 open. Next: controller reconciliation/storage-error UI
  that recovers pending before allowing new events, browser transactional store,
  #20 configured login/profile/secure session restoration, bounded retention
  and real non-production missing/expired JWT/two-client SRS acceptance.

- Separate follow-up review reserves worst-case receipt bytes before dispatch,
  preventing disk-capacity exhaustion caused by staging too many unresolved
  events. Add reservation-exhaustion/freeing regression; retain the global
  event cap test with acknowledged history plus a final pending event.

## Opt-in study recovery resume — 2026-10-14 UTC

- Resume released draft #37 at unchanged e64133fa; prior CI 38512449413 passed
  all five jobs/204 Flutter tests/native disk verifiers on Linux and Windows.
  This is historical evidence, not proof for this new source increment.
- Controller/notifier/screen now recover all owner-scoped pending before due
  cards, show immutable original rating/time and explicit replay, reject late
  sessions/disposal and reload authoritative queue after durable reconciliation.
  Both explicit runtime factories accept caller-owned storage; default is null.
- Journal writes v2 terminal rejections with v1 pending/receipt read compatibility.
  Strict nonretryable definitive codes only, immutable result history, reserved
  result space and failed-write uncertainty retained. Local storage failure marker
  permits safe manual retry without altering frozen RPC error JSON or rating.
- Local actual disk/controller close/reopen verifier, retained native subprocess
  verifier, pure source/tool analyzer and formatter, QA36 inventory/17 regressions
  passed. Twenty-one controller/widget cases authored; full Flutter/widget/web and
  Windows results require current-head CI. Add required disk/controller verifier
  to Linux/Windows without removing any previous gate.
- Separate impact/compatibility and reproduction in STUDY_RECOVERY.md. No new
  dependencies, Auth provider/strategy, tokens, RLS, frozen RPC, deployment or
  paid calls. Keep #37 draft/#22/#15 open; no hosted learner acceptance is claimed.
- Next: browser transactional store/retention, configured #20 login/profile/secure
  session restoration and actual hosted A/B/expired JWT/two-device validation.
  All 14 Personal Alpha integration release cases remain pending.

- Windows build and both real-disk verifiers passed at b0d5de6a; Flutter
  format/analyze passed but widget tests were still running unusually long.
  Follow-up test review uses runAsync with a bounded controller-terminal-state
  future to await native file I/O, then pumps the UI. All UI assertions remain;
  no timeout/expectation/security gate relaxed. Full corrected-head CI required.

- Prior canceled Flutter logs exposed synchronous revocation emitting a nested
  state notification. Preserve the failing assertion; drain queued notifications
  synchronously after the current listener returns, while state/session clearing
  remains immediate. Defer stream close during notification and add synchronous
  disposal regression. No old-data/new-dispatch protection weakened.


## Lossless native compaction resume — 2026-10-14 UTC

- Resume released draft #37 from verified source dccd9b70, one worker. Add
  explicit serialized lossless compact(): flushed sibling/rename/reopen under
  stable lease, v3 settled snapshots with v1/v2 read compatibility. Preserve
  every owner, exact pending event and original outcome; no automatic deletion
  or increase to 512-event capacity. Default runtime remains null.
- Local actual-file/subprocess verifier passed six scenarios plus child compact/
  exit/parent reopen, temporary-write failure and full history retention. Six
  Flutter cases authored; full lint/test/web/Windows require current-head CI.
- Retain all gates; add mandatory CLI verifier to Linux and Windows, QA37 groups
  with all 14 Personal Alpha releases pending. Separate compatibility/impact/
  reproduction in JOURNAL_COMPACTION.md. No API/RLS/Auth/provider/dependency/
  production changes. Keep #37 draft/#15/#20/#22 open. Verified handoff below.
- Next: browser transactional store and reviewed terminal retention; configured
  login/profile/secure sessions and actual hosted two-client learner validation.

## Verified lossless native compaction handoff — 2026-10-14 UTC

- Source head 580954f8539f790cc27a5f3fe6addea4e687ce64 passed all five jobs
  at https://github.com/collab-TTAM/nihongo_daily/actions/runs/38520798851 .
  Flutter format/analyze (no issues), 231 tests including six compaction cases,
  all native disk/controller/wire gates and web release/artifact passed. Windows
  release/artifact and all three real-file process verifiers passed. Native SQL/
  RLS/parity/observed-lock races, repo/49 Python/17 QA and AI/audit gates retained.
- Unmodified run/all latest-attempt jobs passed scripts/verify_qa.py for exact
  source head and all critical steps. QA37 groups, all 14 release gates pending.
  Source CI is historical for later documentation commits; no merge attempted.
- Separate review added interrupted-sibling bootstrap and second-process writer
  rejection after replacement. All original assertions/gates retained. Local
  six actual-file cases and child compact/exit/parent reopen, retained disk and
  controller verifiers, pure analysis/format/49 Python/17 QA passed. Full Flutter,
  Windows/web/native database results are CI, not local execution.
- Explicit lossless compact retains every event/outcome and reserved pending
  receipt capacity; v3 reads v1/v2 history, old-binary downgrade needs migration.
  No automatic retention/history deletion or higher 512-event cap. Default
  runtime null; no web store, live login/profile/secure token persistence,
  power-loss or hosted/two-device learner evidence. #37 draft/#15/#20/#22 open.
- Sequential bounded worker released after evidence persistence. Resume current
  PR head first, then browser transactional store and reviewed terminal retention,
  configured Auth/profile/secure sessions and hosted learner acceptance. No API/
  RLS/Auth/provider/dependency/production changes or secrets requested.

## Browser transactional store resume — 2026-10-14 UTC

- Resume released draft #37 at dc7994a0 after all five prior documentation-head
  jobs succeeded in CI38521325597. Verified every tracked local blob against
  current remote head; one sequential worker, same branch.
- Add opt-in canonical TransactionalReviewStore with actual IndexedDB transaction
  transport using dart:js_interop. Commit before success; synchronous mutation
  under readwrite scope, exact event/outcome and owner projections, corruption/
  bounded 1MiB/512 events with pending-outcome reservations and safe failures.
  Native unsupported stub never supplies false in-memory persistence.
- Seven pure-ledger fixtures passed locally; JS reload verifier compiles locally.
  Seven Flutter unit/four real Chrome tests plus actual page-refresh/second-tab
  verifier authored; full lint/Chrome/build success requires current-head CI.
  Chrome is absent locally, so no local browser runtime claim.
- Add two mandatory browser gates in Linux Flutter; retain every prior gate.
  QA38 groups, all 14 release integrations pending. Separate protocol/impact/
  migration/persistence/security limits in BROWSER_REVIEW_STORE.md.
- Default runtime null. No secure token/login/profile, automatic retention or
  eviction/power-loss/hosted two-device acceptance. No dependencies/frozen API/
  RLS/Auth/provider/production changes. Keep #37 draft/#15/#20/#22 open. Worker
  released after verified evidence below. Next reviewed terminal retention and configured
  Auth/profile/secure sessions, followed by hosted learner acceptance.

- First CI38522933955 passed format/analyze and 238 Flutter tests; Chrome
  frontend-server could not load a direct tool/ test entrypoint. Move the same
  browser cases into test/features/srs (non-default *_test name) and share pure
  fixtures under test/. Retain every assertion and both mandatory browser gates;
  skipped Chrome/reload/web steps do not count as passing evidence.

## Verified opt-in IndexedDB handoff — 2026-10-14 UTC

- Source a1c54ffd3a767302a6623cac77c6b1336bb88f90 passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38523331817 .
  Flutter format/analyze (no issues), 238 unit/widget tests including seven
  ledger scenarios, four real Chrome IndexedDB tests, actual compiled-Dart page
  refresh twice/second-tab persistence, all existing verifiers and web build/
  artifact passed. Windows build/nihongo_daily.exe/artifact plus all three native
  disk/process verifiers passed. SQL/RLS/parity/races/repo/49 Python/17 QA/AI
  audit gates retained and passed. Unmodified run/all latest-attempt jobs passed
  scripts/verify_qa.py for exact source head and every required step.
- Source and follow-up separately reviewed: complete-before-success, synchronous
  mutation/rollback, cross-connection serialization, exact immutable outcomes,
  owner/canonical/reservation/capacity validation, no fallback data reset. First
  Chrome entrypoint path failed; relocated unchanged tests/shared pure fixtures
  to test/ without weakening assertions or browser gates. Corrected source passed.
- Local seven pure ledger fixtures/source-tool analysis/format/JS compilation/
  49 Python/17 QA passed. Actual Chrome/reloads/full Flutter/web/Windows/native
  SQL are CI evidence, not local execution. Quota/commit failure is modeled by
  the injected atomic port; no real quota/eviction or hardware-power-loss proof.
- Browser store is opt-in and accepted by existing runtime/recovery factories.
  Default runtime remains null; no hosted JWT/login/profile/secure sessions,
  other-browser or two-device learner acceptance. 512 history cap remains; no
  automatic eviction/terminal retention. QA38 groups, all 14 releases pending.
- Sequential worker released after evidence persistence; resume latest draft
  head first. Keep #37 draft/#15/#20/#22 open, no merge/deployment. Next reviewed
  terminal retention and configured Auth/profile/secure session restoration,
  followed by actual hosted A/B/expired JWT/two-client SRS evidence. Source-head
  CI is historical for later documentation/source commits; inspect their checks.
  No dependencies/API/RLS/Auth/provider/production changes or secrets requested.

## Opt-in receipt-cache retention resume — 2026-10-14 UTC

- Resume released ff76a2cd after all five CI38523872062 jobs succeeded. Verified
  every local tracked blob against GitHub; one worker on the same draft branch.
- Add explicit ReviewReceiptRetention (default disabled, limit1..256) to native/
  browser stores. Before new stage, remove only current-owner oldest staged
  successful receipt cache entries. Preserve pending/rejected/other-owner history;
  explicit prune applies strict limit. Keep+1 possible after a fresh receipt.
- Server event history untouched; pruned replay stages original immutable event
  then revalidates RPC, never synthesizes local success/progress. Shared policy,
  native flushed replacement/lease and browser atomic transaction preserve all
  existing formats/security bounds. See RECEIPT_CACHE_RETENTION.md for review.
- Local four pure scenarios plus actual native 600-review/process-restart/temp
  failure verifier passed. Four new Flutter cases and one actual Chrome retention
  case authored; current-head full lint/browser/web/Windows CI still required.
  Add mandatory CLI on Linux/Windows, retain all previous gates. QA39 groups;
  all 14 Personal Alpha integration cases pending. Default app runtime null.
- Keep #37 draft/#15/#20/#22 open. Worker released after verified evidence below; next configured
  login/profile/secure token persistence and actual hosted A/B/expired JWT/
  two-client learner acceptance. No production history deletion, dependencies,
  frozen API, RLS, Auth strategy/provider changes or secrets requested.

## Verified receipt-cache retention handoff — 2026-10-14 UTC

- Source 1a857891c068a9c96a170743e7ff7b2062c8488b passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38525221671 .
  Flutter format/analyze (no issues), 242 unit/widget tests including four new
  retention cases, five actual Chrome tests including concurrent retention/reopen,
  real page reload/second-tab, all wire/native checks and web release/artifact
  passed. Windows build/nihongo_daily.exe/artifact plus four native file/process
  verifiers passed, including 600-review retention/child prune-exit-parent reopen/
  pending preservation/blocked temporary write. SQL/RLS/parity/races/repo/49
  Python/17 QA/AI audit retained and passed. Unmodified run/all latest-attempt
  jobs accepted by scripts/verify_qa.py at exact head/every required step. QA39
  groups; all 14 Personal Alpha integration release cases still pending.
- Separate source review checked default-disabled/own successful receipts only,
  no pending/rejection/other-owner deletion, immutable existing replay/conflict
  before maintenance, atomic browser rollback and native replacement-memory
  ordering. Native formats v1/v2/v3 and browser schema1 unchanged. Server replay
  remains authoritative; injected retention server is TEST ONLY. No live receipt
  retention policy/JWT/login/profile/secure tokens/two-device learner proof.
- Local four pure scenarios/native 600-review/process/temp-write verifier, retained
  compaction CLI/source analysis/format/JS compilation/49 Python/17 QA passed.
  Full Flutter/Chrome/web/Windows/native SQL results are CI, not local execution.
- Bounded worker released after evidence persistence; resume latest draft head
  first and inspect its CI. Keep #37 draft/#15/#20/#22 open, no merge/deployment.
  Source-head success is historical for subsequent documentation/source changes.
  Default retention disabled/runtime null; pending/rejected/shared-owner/quota
  limits may still exhaust storage. Next configured Auth/profile/login/secure
  session restoration and actual hosted A/B/expired JWT/two-client acceptance.
  No server/production history deletion, API/RLS/Auth/provider/dependency change.

## Caller-bound profile bootstrap resume — 2026-10-14 UTC

- Resume released draft #37 at 3471b92c after all five CI38525874034 jobs passed.
  Verified all local tracked blobs against remote head; one sequential worker.
- Add additive nd-own-profile-1/ensure_profile accepting empty request only,
  auth.uid plus existing auth.users identity, idempotent own default insert and
  settings-preserving read. No direct INSERT/DELETE grants or changed RLS/table
  schema; narrow authenticated definer with fixed empty search_path. Exceptions
  roll back and return existing safe errors. No Auth provider/strategy change.
- Typed Dart bootstrap uses captured Auth/RPC, strict own response projection,
  timeout/no automatic retry and old-session rejection. Registry allowlist only
  adds empty ensure_profile envelope. Default runtime null; no login/token store.
- Seven pure scenarios/source-tool analysis/format passed locally. Nine Flutter
  cases (seven unit/two SDK HTTP) and native SQL/rollback/observed-lock race/five
  actual SQL response projection tests authored; success requires exact-head CI.
  Native PostgreSQL is absent locally; no local SQL/full SDK/build claim.
- Add database export/concurrency/artifact and same-run Flutter decoder gates;
  retain every prior gate. QA40 groups/all 14 releases pending. Separate contract/
  scope/privilege/impact review in OWN_PROFILE_BOOTSTRAP.md. Worker active pending
  CI; keep #37 draft/#20/#22/#15 open. Next login/profile readiness coordination,
  secure session persistence and actual configured hosted learner evidence.

## Verified own-profile source handoff — 2026-10-14 UTC

- Source fb3a691553869fd0f01ec029c008808323e778cd passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38528310665 .
  Flutter format/analyze (no issues), 251 tests including seven profile unit/two
  SDK HTTP cases, five Chrome tests, five actual same-run SQL profile responses
  decoded through the Dart adapter and web release/artifact passed. Windows
  release/artifact/all native file verifiers passed. Database includes 25 new
  profile assertions and observed-lock concurrent creation; existing SQL/RLS/
  SRS parity/races/repo/49 Python/17 QA/AI gates retained and passed. Unmodified
  run/all latest-attempt jobs accepted by scripts/verify_qa.py at exact head/
  every critical step. QA40 groups/all 14 releases still pending.
- Separate scope/privilege review: authenticated-only caller-ID provisioning,
  empty request/no metadata, settings-preserving duplicate handling, unchanged
  direct grants/RLS, fixed-path definer and rollback/redacted errors. Typed
  adapter rejects malformed/other-owner/old-session results and has no auto
  retry. No default runtime/login/token persistence/provider change/deployment.
- Local pure/profile/source-tool/format/Python/QA checks passed; native SQL/full
  SDK/Flutter/web/Windows evidence is CI, not local execution or hosted JWT proof.
  Source success is historical for later documentation/source commits.
- User requested continuing; same sequential worker now proceeds to login/profile
  readiness UI and runtime coordination. Keep #37 draft/#20/#22/#15 open. Secure
  token restoration and actual configured hosted learner acceptance still missing.

## Account readiness implementation — 2026-10-14 UTC

- Resume the same sequential worker at restored b5b15c9c. A documentation tree
  created without its base briefly omitted source at a11492a; fast-forward repair
  restored every source blob from verified fb3a6915. Full recursive comparison
  confirmed only the two intended documentation files differed (203 blobs).
  Nothing merged or deployed. Subsequent trees require explicit nonempty base
  and full-tree comparison before advancing the ref.
- Add configured account UI/runtime assembly: transient cleared credential fields,
  existing SDK email/password/local sign-out, own-profile readiness barrier,
  owner/session/generation checks and immediate study invalidation on logout,
  expiry/account changes, stream closure or disposal. SDK logout dispatch waits
  until an active callback returns; gate is already closed. Late sign-in cleanup
  remains fenced; safe explicit retry, no credential/token state or automatic
  controller retry. Default runtime null; no provider/backend setup or deployment.
- Ten raw-Dart scenarios and pure analysis/format passed locally. Five widget/two
  actual SDK HTTP cases authored; full tests/builds require source-head CI.
  Separate scope/lifecycle/credential review and reproduction in
  ACCOUNT_READINESS.md. New mandatory readiness step retains all prior gates.
  QA41 groups/all 14 live integration releases pending. Worker active pending CI.
- Keep #37 draft/#20/#22/#15 open. Next secure session storage/restore and actual
  configured hosted A/B/expired JWT/restart/two-client learner acceptance.

## Verified account/profile readiness handoff — 2026-10-14 UTC

- Source 6a04a2cfb3dc30802da2b9169801475a72b1e63e passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38547379359 .
  Flutter format/analyze (no issues), 267 tests including ten account-controller,
  five widget and two SDK HTTP cases (generic auth placeholder replaced by richer
  dedicated route coverage), five actual Chrome tests, new mandatory readiness
  verifier and retained native/wire/same-run SQL-to-Dart checks passed. Web and
  Windows releases/artifacts plus all four Windows native file/process verifiers
  passed. SQL/RLS/profile observed-lock races, repo/49 Python/17 QA and AI/audit
  gates retained and successful. Unmodified workflow/all latest-attempt jobs
  accepted by scripts/verify_qa.py at this exact head/every critical step. QA41
  groups/all 14 integration release cases pending.
- Separate source/follow-up review checked profile barrier and caller ownership,
  immediate study invalidation before awaited logout, late sign-in cleanup,
  reentrant notification/disposal, transient cleared credential fields and safe
  errors. Initial extracted queue import/lint failure fixed with original tests
  and gates preserved. Every one of 213 local blobs matches uploaded source.
  The earlier documentation-only tree omission was fully restored before this
  source increment; corrected complete source now has all five CI jobs passing.
- Local ten pure scenarios/source analysis/format/49 Python/17 QA passed. Full
  widgets/SDK/Chrome/builds/native SQL evidence is CI, not local or hosted Auth.
  Existing SDK email/password is caller configured, no server provider change.
  App default runtime null; no registration/secure token store or restore/live
  learner acceptance. Login credentials never enter account state or journal.
- Bounded sequential worker released after evidence persistence. Resume latest
  draft head first, inspect its CI and do not overlap workers. Source-head success
  is historical for the following documentation-only handoff commit. Keep #37
  draft/#20/#22/#15 open; no merge/deployment. Next configured secure session
  lifecycle/storage/restore, then actual hosted A/B/expired JWT/restart/two-client
  learner acceptance. Missing credentials do not block independent work.

## Windows refresh-secret vault resume — 2026-10-14 UTC

- Resume eae3c63d after all five CI38548119120 jobs passed. All 213 local blobs
  match remote baseline. One core worker; Pro content lane remains reserved for
  Issue #14. No data/content/schema/migration/Auth provider changes.
- Add explicit Windows Credential Manager refresh-secret component, trusted
  HTTPS-origin namespace, 2048 printable-ASCII byte bound, strict native method
  envelope, idempotent exact-target clear and safe errors. Serialize same-target
  operations across facade instances in this Dart isolate; never fall back to
  files/browser storage. Existing app/account runtime remains unconfigured.
- Twelve pure scenarios/source analysis/format pass locally. Four platform-channel
  tests and real native Windows credential/child exit/read/project isolation/
  corrupt-input/clear probe authored. Native C++ helper is shared by app/probe;
  Windows runner lifetime registers/unregisters the bridge. Current-head CI
  required for full Flutter/native API/build claims. All prior gates retained;
  add pure verifier and mandatory actual Windows probe. QA42/all 14 releases
  pending; worker active pending CI.
- Separate source/scope/secret-memory/OS boundary review in WINDOWS_SESSION_VAULT.
  No dependencies/API/RLS/production/paid-provider changes. This component is not
  yet connected to SDK token rotation or login/logout/restart restoration. Next
  bind the vault to an explicitly owned Supabase session lifecycle with profile
  readiness and late-result guards, then actual configured hosted acceptance.
  Keep #37 draft/#20/#22/#15 open; no merge/deployment.

## Verified Windows session-vault handoff — 2026-10-14 UTC

- Source 1dd109470369884f7f776888cfab91859f9efc1c passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38558520796 .
  Flutter format/analyze (no issues), 283 tests including twelve vault cases/four
  platform-channel cases, five Chrome tests, new pure vault verifier and retained
  account/native/wire/same-run SQL-to-Dart checks passed. Web release/artifact,
  Windows app/bridge release build/artifact and all four prior native file/process
  verifiers passed. New native /W4 /WX probe used actual Credential Manager for
  write/read/replacement, child write/exit/parent read, project isolation, invalid
  write preservation, 2048-byte bounds, foreign target rejection, raw corrupt blob
  injection/recovery and idempotent deletion. PID-qualified .invalid TEST ONLY
  credentials cleared before success. SQL/RLS/races/repo/49 Python/17 QA/AI/audit
  retained and successful. Unmodified run/latest-attempt job payloads passed
  exact-head/every-critical-step scripts/verify_qa.py. QA42/all 14 releases pending.
- Initial CLI print lint was fixed with stdout. Native probe wchar narrowing
  warning was fixed with checked ASCII conversion and stricter CI-only child
  target scope; /W4 /WX, assertions and every gate remain. Separate follow-up
  review checked changed paths/no credential output, bounds, OS buffer cleanup,
  method envelope, channel lifetime and no secret fallback. Before final probe
  correction all 226 local blobs matched upload; correction preserves every
  other blob. No data/content/schema/lock/dependency/RLS/Auth/provider changes.
- Twelve pure cases/format/source analysis/49 Python/17 QA passed locally. Actual
  Windows credentials, full Flutter/channel mocks/Chrome/builds/native SQL are
  observed CI, not local execution, interactive Dart-to-OS or hosted Auth proof.
  Vault remains an explicit component; current account runtime null. No SDK token
  rotation/login/logout persistence/startup restore/browser/mobile store enabled.
  Same OS user process access remains outside application isolation; same-isolate
  queue is not interprocess CAS, and full memory zeroization is not claimed.
- Bounded core worker released after evidence persistence; Pro #14 remains
  reserved and untouched. Resume latest draft head/its CI first. Source success
  is historical for the documentation handoff successor. Keep #37 draft and
  #20/#22/#15 open; no merge/deployment. Next explicitly owned SDK/vault lifecycle:
  captured/generation-guarded token rotation, clear/logout ordering, startup refresh
  before own-profile readiness, storage/revocation/late-response tests. Then actual
  configured hosted A/B/expired JWT/restart/two-client learner acceptance.


## Owned persistent session lifecycle resume — 2026-10-14 UTC

- Resume d3fc8ad7 after latest CI38559195851 succeeded. All 226 baseline blobs
  matched GitHub; one isolated core checkout/writer. Pro N4 PR #38 stays separate.
- Add explicit exclusively owned Supabase runtime with disabled SDK auto-refresh,
  no Session JSON storage, Windows vault scope validation, single-isolate owner
  lease, server refresh-only startup and persist-before-own-profile readiness.
  App default runtime remains null; browser assembly rejected before SDK creation.
- Generation/captured-secret guards discard stale events, fence logout before awaits,
  serialize writes/clear and clean up late Auth success. Storage errors fail closed;
  explicit login cleans failed state before retry. Close preserves saved credentials
  but waits for interrupted Auth cleanup; caller must await close. Explicit refresh
  only, no automatic refresh scheduler. Auth HTTP is same-origin/no redirects,
  bounded to one 15-second attempt and 1MiB; no raw errors or secrets in state/logs.
- Twenty-two pure fixture cases pass locally. Seven actual SDK/mock-HTTP cases authored;
  full Flutter, SDK, browser, native/build evidence requires current-source CI.
  New mandatory lifecycle verifier retains every prior gate. QA43/all 14 live
  release integrations pending. Separate review: PERSISTENT_SESSION_LIFECYCLE.md.
- No dependencies, schema/RLS/API, Auth provider/strategy, N4 data or deployment
  changes. Keep #37 draft/#20/#22/#15 open. Worker active until verified handoff.
  Next actual Windows Dart-to-OS/runtime restart and configured hosted learner
  A/B/expired JWT/two-client evidence; then opt-in startup UI/configuration and
  refresh scheduling. Source implementation is not real login acceptance.

- First CI38573420584 passed repo/database/AI but Flutter lint required the
  inherited stream's @override annotation. Kept lint gate; correction also holds
  the Auth operation through late cleanup and cancels failed-state login recovery
  on logout, with two added regression cases (22 pure). Source CI rerun required.

- Source review requires an explicitly supplied DurableReviewStore in the new
  persistent factory: rotation removes the old study runtime, so a process-only
  review repository could lose an uncertain event. Added actual disposable-disk
  pending-event preservation across rotation/logout/relogin (seventh SDK test).
  Existing nonpersistent factories retain their optional store. Fixed Japanese
  HTTP fixture JSON content type; assertions and lint/build gates retained.


## Verified owned session lifecycle handoff — 2026-10-14 UTC

- Source 021c36bf7a5572dcc0111161d093a0fc7b3377f8 passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38575156585 .
  Format/analyze without issues, 312 Flutter tests (22 pure lifecycle/seven
  pinned-SDK HTTP cases), five actual Chrome tests, mandatory lifecycle verifier,
  all retained wire/native/same-run SQL-to-Dart checks and web release passed.
  Windows release/artifact, actual Credential Manager/process probe and all four
  file/process verifiers passed. Native SQL/RLS/profile races, repo/49 Python/
  17 QA/AI audit retained. Unmodified run/latest-attempt metadata passed exact-head
  and every required step in scripts/verify_qa.py. QA43/all 14 live groups pending.
- All 233 local source blobs matched GitHub. Separate review retained persist-
  before-profile, exclusive private SDK mutation port, logout/clear ordering,
  late cleanup ownership, failed-state retry cancellation and default-null scope.
  Required caller review store prevents losing uncertain events when rotation
  replaces a runtime; actual native-disk test retains the exact original event
  across rotation/logout/relogin and never auto-dispatches it. Pro #38 untouched.
- First lint annotation and Japanese HTTP fixture content-type errors fixed
  without removing checks/assertions. Local 22 pure lifecycle/ten retained account
  cases, pure source analysis/format/49 contracts/17 QA passed. Full Flutter/SDK/
  browser/build/native SQL/Windows results are observed CI, not local/hosted proof.
- Bounded HTTP timeout is per attempt. Pinned gotrue 2.27.3 internally retries
  refresh transport/5xx failures even with SDK auto-refresh disabled; observed
  timeout fixture takes about 12 seconds. Whole Auth operation can exceed the
  15-second attempt bound. Controller/persistence adds no retry loop or timer.
  Updated scope docs rather than claiming absent SDK retries or changing policy.
- Explicit SDK/vault assembly only, matching vault + caller-owned review store
  required, no default startup configuration or automatic refresh scheduler.
  Web is rejected before SDK construction; Windows store is the implemented
  native backend. No hosted login/JWT, actual Dart-to-Windows restart or two-
  device learner proof. Single-isolate owner lease is not interprocess CAS.
- Core worker RELEASED after verified source and durable handoff; resume latest
  draft head and its checks. Following documentation commit preserves source and
  has separate CI; source success is historical for later heads. Keep #37 draft
  and #20/#22/#15 open. Next actual Dart-to-Windows bridge/runtime restart, caller
  startup/error/explicit-refresh scheduling, then configured hosted learner A/B/
  expiry/restart/two-client acceptance. Missing service configuration does not
  block independent testable work. No dependencies/schema/RLS/API/Auth-provider,
  production deployment/deletion or N4 changes; schedule remains requested.

## Windows Dart/native bridge increment — 2026-10-14 UTC

- Resumed actual #37 head 0a2aad71; baseline local blobs matched prior source tree
  except the two known handoff docs. Pro #38/N4 lane remains untouched.
- Added TEST ONLY Flutter runner entrypoint and bounded PowerShell orchestration
  to exercise real Dart facade/codec/channel/Credential Manager in five sequential
  processes, including observing replaced data and absence after deletion.
  GUID `.invalid` scope; fixed synthetic values only; finally cleanup required.
- CI requires probe build/execution and then normal preview rebuild. All prior
  gates retained. Local formatting and 17 QA tests passed; initial contracts run
  lacked jsonschema in default Python (environment, not test success). Use existing
  contract-venv. Windows execution/new-head full CI are pending at upload.
- Separate review: no arbitrary target/token CLI input, bounded processes, fixed
  safe logs, per-run target cleanup, separate probe target and normal artifact.
  This increment verifies vault bridge only; persistent SDK runtime restart,
  refresh scheduling/startup UI and all 14 live integrations remain pending.
  Keep #37 draft; no deployment, migration, dependency/Auth-provider or N4 change.

### Observed bridge evidence and released handoff

- Source 92250a67629c5fd2d73090c249075478847a59dd passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38584671877 .
  Actual Flutter runner bridge build/execution passed; logs confirmed the fixed
  cross-process success marker. Normal learner entrypoint rebuilt afterward;
  Windows/web artifact uploads and all retained test/SQL/browser/native/security
  steps succeeded. Raw run/latest-attempt metadata passed exact-source-head and
  every-required-step QA. Existing 49 Python contracts and 17 QA passed locally
  using saved jsonschema packages; no dependency installed or gate weakened.
- All 235 uploaded source blobs matched local files; base tree preserved in full.
  Review kept fixed fixture values, bounded process calls, GUID-only test scope,
  fail-visible finally cleanup and normal artifact rebuild. No live learner or
  Supabase-to-OS restore claim. QA43/all 14 live integration groups remain pending.
- Core worker RELEASED. Resume actual head; following evidence-only docs commit
  has its own CI and does not inherit current-head success. Next: persistent SDK
  runtime using actual Windows bridge across processes, caller startup/error UI,
  explicit refresh scheduling, then hosted configured learner A/B/expiry/two-client
  acceptance. Keep #37 draft and #20/#22/#15 open; Pro #38/N4 untouched.

## Windows persistent runtime restart increment — 2026-10-14 UTC

- Resumed actual head 53de3784; its CI passed. Core worker ACTIVE for this
  sequential increment; Pro #38/N4 lane remains untouched.
- Added five runtime phases to the already executed real Flutter Windows bridge
  probe, using pinned SDK/mock HTTP plus actual OS vault and native review disk.
  Checks refresh-only restore, exact rotation before profile, preserved pending
  event, close persistence, immediate logout fencing, signed-out restart and
  rejected stored token with explicit recovery. No submit_review permitted.
- Local format/49 contracts/17 QA pass. New-head full analysis/Flutter/Windows
  execution are pending. No historical test result counted for new code.
- Separate review: fixed .invalid GUID scope/synthetic values; no external HTTP;
  bounded phases/cleanup of test OS entry and temp journal; production runtime
  owns SDK; normal entrypoint rebuilt before artifact upload. Fixture Auth/JWT
  remains simulated, so all 14 hosted Personal Alpha groups remain pending.
  Keep #37 draft and #20/#22/#15 open. Next caller startup/error UI and refresh
  scheduling, then configured hosted learner/restart/two-client acceptance.

- First source e31fd57e CI 38589704536 passed repo/SQL/AI but Flutter analysis
  found one missing block in fixture `_check`. Added braces without changing
  assertions or suppressing lint. Skipped test/build steps are not passes;
  corrected source requires a fresh full CI run.

- Corrected source 1475f19 CI 38590154982 passed analysis and actual Windows
  runtime probe, but one retained SDK recovery test checked readiness after only
  eight event turns and observed profile still pending (311 passed/one failed).
  Replace that timing heuristic in this test with bounded account completion
  observation; ready/profile-error/sign-in-error/unavailable are terminal, and
  ready plus original nonnull runtime assertions remain mandatory. Production
  logic and timeout/assertion/security/CI gates are unchanged. New source needs CI.

### Verified Windows runtime process handoff

- Source e39d6fee1ac554f8e9802294b09ef54d5ed17b63 passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38590916038 .
  Observed 312 Flutter tests/five Chrome tests, no analyze/format issues, actual
  Flutter vault and runtime cross-process markers, native credential/process
  probe and retained native/SQL/wire/security/build gates. Normal web/Windows
  artifacts uploaded; TEST ONLY entrypoint rebuilt to learner entrypoint first.
  Raw run/latest-attempt metadata passed exact-source/every-required-step QA.
- Ten process phases use real Windows credential vault and journal. Runtime
  phases retain the original pending event, server-refresh the saved secret,
  save rotation before profile, preserve confirmed secret on close, fence logout,
  remain signed-out after restart and recover explicitly from rejected secret.
  Pinned SDK uses mock HTTP/unsigned JWTs: no hosted identity or two-client proof.
- Full source tree preserved; 236 blobs matched after upload. Separate review
  kept original ready/non-null SDK assertion while replacing fixed event turns
  with bounded terminal-state observation. No assertion/lint/security/CI weakening
  or production auth logic change. All 14 live release gates remain pending.
- Core worker RELEASED after evidence saved. Resume actual head/checks; evidence
  successor only updates handoff/QA documentation and has separate CI. Next
  caller startup/error UI and explicit refresh scheduling, then configured hosted
  A/B/restart/expiry/two-client acceptance. Keep #37 draft; #20/#22/#15 open.
  Pro #38/N4 unaffected; no dependency/provider/schema/deployment changes.

## Opt-in account startup/error host — 2026-10-14 UTC

- Resumed actual #37 head 57cd3043 with sequential core ownership; Pro #38/N4
  lane untouched. Added pure owned startup controller, persistent runtime adapter
  and configured Flutter host. Default main/provider still unconfigured.
- Loading withholds account/router publication. Fixed errors allow explicit
  fenced login or retry, with old-owner close before replacement. Close drains
  late factory/start and never publishes late results. Cleanup failure blocks
  replacement; caller awaits close, disposal reports fixed callback. No auto retry.
- Added eight lifecycle/four widget fixture tests, including 320px/200% text,
  real account route/form wiring and disposal races. Local formatting done;
  new-source full Flutter/Windows/web/retained gates pending CI. All 14 live
  integration groups pending; no hosted Auth/refresh scheduler claim.
- Separate review retained profile/persistence gating, safe errors, project
  ownership and mandatory close-before-replacement. Factory owns partial failure
  cleanup; supplied journal remains caller-owned. No dependencies/provider/API/
  schema/N4/deployment changes. Scope/reproduction: docs/ACCOUNT_STARTUP.md.

### Verified startup host handoff

- Source 9388b5813d3c3eacf727f8fae7eec5cd388f070a passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38593010698 .
  Observed 324 Flutter tests (eight lifecycle/four startup widgets added), five
  Chrome tests, format/analyze, retained actual Windows vault/runtime process
  success markers, native/SQL/wire/security gates and normal web/Windows artifacts.
  Raw run/latest-attempt metadata passed exact-source/every-required-step QA.
- All 242 uploaded source blobs matched. Review kept one captured owner, no
  account publication before start, explicit fenced-login action, cleanup before
  replacement, immediate closed publication and drained late factory/start.
  Pro #38/N4 unchanged. Multiline retry guard enclosed without logic changes.
- Startup UI evidence is explicit owner/Auth/profile fixtures, not hosted login,
  full UI-to-OS integration or release readiness. Default main/provider stays
  unconfigured; no refresh scheduler added. All 14 live release groups pending.
- Core worker RELEASED after persisted evidence. Resume actual latest head/checks;
  following documentation/QA evidence commit has separate CI. Next tested refresh
  scheduling with lifecycle/expiry/resume/logout guards, then configured hosted
  learner A/B/restart/expiry/two-client acceptance. Keep #37 draft/#20/#22/#15 open.
  No dependency/provider/schema/API/deployment change or production data cleanup.

## Opt-in owned refresh scheduling — 2026-10-14 UTC

- Resumed actual #37 head ba506b08 with one core writer, Pro #38/N4 untouched.
  Added private runtime scheduler selected by automaticRefresh=true; default false
  and main unconfigured. SDK automatic refresh remains disabled.
- Accepted identity/expiry only, 60-second lead, 24-hour bounded rearm, 30-second
  spacing and one attempt per lease. Current gate rechecked before dispatch;
  logout/close cancel timers, late callbacks cannot dispatch old identities,
  expired resume never restores; no scheduler failure retry loop.
- Existing save-before-profile barrier used for every rotation. Startup host
  forwards foreground resume only for active owned adapters. Twelve timer/clock
  cases, two pinned-SDK/mock-HTTP cases and one widget forwarding test added.
  Local format/49 contracts/17 QA passed; new-source CI pending.
- Separate review retains SDK internal retry policy and per-attempt HTTP bounds,
  no public credentials, null default activation and caller journal ownership.
  No dependency/provider/Auth strategy/schema/API/N4/deployment changes.
  Scope/limits: docs/SESSION_REFRESH.md. Hosted JWT/device/background/OS suspend
  proof and all 14 live release groups remain pending; keep #37/#20/#22/#15 open.

- First source a60539e CI38595472805 passed repo/SQL/AI, but analysis found
  nullable receiver at generic resume forwarding. Add explicit nonnull guard
  before the resumable-owner check. No lifecycle/expiry/ownership/assertion or
  lint gate changed; skipped downstream tests/build are not passing evidence.
  Corrected source requires fresh full CI.

### Verified refresh scheduler handoff

- Source c65528fbea77313f386666c37ab10a1f58efbae0 passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38596070841 .
  Observed 339 Flutter tests (12 scheduler/two pinned-SDK/one widget added),
  five Chrome tests, format/analyze, retained actual Windows vault/runtime
  cross-process markers, native/SQL/wire/security gates and normal artifacts.
  Raw run/latest-attempt metadata passed exact-head/every-required-step QA.
- All 245 uploaded source blobs matched. Pure local controller/scheduler analysis,
  format/49 contracts/17 QA passed. Generic foreground forwarding required both
  nonnull guard and checked interface cast; kept active-owner/lifecycle/expiry
  guards and every assertion/lint/CI/security gate. No SDK retry policy change.
- Opt-in automaticRefresh=false by default; main unconfigured, SDK automatic
  refresh disabled. New scheduler attempts once per lease, keeps save-before-
  profile, rejects expired resumes and cancels on logout/close. Short TTLs cannot
  loop. Failure test fences study with no added resume retry. Fixture Auth/clock/
  timers are not hosted rotation/background/OS suspension proof. Pro #38/N4 intact.
- Core worker RELEASED after evidence saved. Resume actual head/checks; following
  evidence/QA docs commit has separate CI. Next configured non-production hosted
  learner A/B/expiry/restart/two-client acceptance and startup/refresh error
  presentation; all 14 live integrations still pending. Keep #37 draft and
  #20/#22/#15 open. No dependency/provider/schema/API/production changes.

## Safe account session notice UI — 2026-10-14 UTC

- Resumed actual #37 head 8486f440, one core writer; Pro #38/N4 unaffected.
  Added display-only three-state port from owned persistent runtime, source
  provider/notifier and active-startup wiring. Account checking hides/clears
  credentials; fixed failure text offers explicit login. Ordinary logout clears
  notices; existing profile/account errors keep their messages.
- No notice can grant/revoke authorization; existing session/profile/persistence
  gate remains authoritative. Source replacement cancels stale events; fixed
  enum state only, no raw SDK/error/token/path exposed. Runtime close cancels
  scheduler first and does not await paused display subscribers before cleanup.
- Seven notice/provider/widget tests plus one pinned-SDK/mock-HTTP case added;
  retained automatic-refresh tests now assert saved/failure/checking display.
  Local format/analysis/contract/QA checks pending below; new-source full CI pending.
- Separate review retained null default source/main, no retry/autologin, caller
  journal ownership and no production/schema/API/provider/dependency changes.
  Hosted Auth/learner/two-client/OS suspension and all 14 live groups pending.
  Scope: docs/ACCOUNT_SESSION_NOTICE.md; keep #37/#20/#22/#15 open.

- Source d7816608 CI38598860539 passed analysis and seven notice/SDK direct cases,
  but configured-host test still found form after a single frame. Preserve the
  no-fields assertion, add explicit owned-source/scoped-notice assertions and
  render after stream state propagation. This distinguishes wiring from frame
  timing; no production/auth/assertion/lint changes. New-source CI required.

### Verified session notice handoff

- Source bb6be63deefa307e130c1a840c5aedaa1054a0d2 passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38599504856 .
  Observed 347 Flutter tests (seven notice/provider/widgets + one pinned-SDK),
  five Chrome tests, format/analyze, retained actual Windows vault/runtime
  process markers, native/SQL/wire/security gates and normal web/Windows uploads.
  Raw run/latest-attempt metadata passed exact-head/every-required-step QA.
- All 249 source blobs matched local upload. Pure port/controller analysis,
  format/49 contracts/17 QA passed locally. Added owned-source/propagated-state
  assertions before next-frame no-fields check in host test; original expectation
  retained, no production/Auth/lint/security/CI relaxation.
- Display-only notices never grant study; checking clears/hides credentials,
  fixed failures request explicit login, success/ordinary logout clear notice.
  Startup installs only the owned source; replacement cancels old events.
  SDK failure and login recovery are mock HTTP/unsigned JWT fixtures, not hosted
  learner/UI-to-OS expiry/rotation proof. All 14 live release groups remain pending.
- Core worker RELEASED after persisted evidence. Resume actual head/checks;
  following documentation/QA successor has separate CI. Next configured staging
  learner A/B/expiry/restart/two-client acceptance and evidence-linked remaining
  product flows. Keep #37 draft/#20/#22/#15 open. Default main/provider unchanged;
  Pro #38/N4 untouched; no dependencies/schema/API/Auth provider/deployment changes.

## Explicit Windows staging bootstrap — 2026-10-14 UTC

- Resumed actual #37 head cfa60116, one core writer; Pro #38/N4 not changed.
  #20 still requires configured non-production Supabase/actual A/B evidence,
  and neither issue/repo supplied those values. Continue independent assembly.
- Ordinary main now selects preview by default or explicit validated staging
  build configuration. Configured Windows opens a project-scoped LocalAppData
  journal/process lease before the SDK/token writer, owns runtime + journal and
  installs existing startup/notice/refresh/account/profile/study paths.
  Invalid/missing/unsupported selected staging fails before resources/without
  silent preview or other-project fallback. Public key/URL only; no secrets/logs.
- Added read-only native known-folder/SHA256 path channel, shared unchanged target
  validation and strict Dart path/platform checks. Native root failures have fixed
  errors; no cwd/temp/network fallback. Nine Dart tests/three process phases plus
  configured TEST ONLY Windows main build added; normal preview rebuilt before
  upload. Local format/49 contracts/17 QA passed; full new-source CI pending.
- Separate review: COM already initialized by runner, known-folder memory/provider
  handles released, Unicode conversion checked; no filesystem create/delete in
  native resolver. GUID-scoped disposable probes, caller journal ownership
  transferred explicitly, no user-history deletion. No dependency/provider/
  Auth strategy/RLS/schema/API/production deployment or N4 changes.
- Scope: docs/STAGING_BOOTSTRAP.md. Hosted login/expiry/two-client/GUI acceptance
  and all 14 live release groups remain pending. Keep #37/#20/#22/#15 open.

- First bootstrap source ca859a0f CI38603915706 passed analysis/354 Flutter
  cases, but two widget platform fixtures left debugDefaultTargetPlatformOverride
  set at Flutter's invariant check. Use framework TargetPlatformVariant rather
  than late addTearDown reset. Original selection/ownership/no-resource assertions
  retained; no production behavior, lint/security/CI gate changed. Full corrected
  source CI required; skipped downstream steps are not successes.

### Verified explicit staging bootstrap handoff

- Source 5be34663e2c28e182d12c66f0dea894853e05cd9 passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38605205617 .
  Observed 356 Flutter tests (six config/selection + three directory), five
  Chrome tests, format/analyze, actual OS project app-data + empty-vault owned
  factory/start/close/reopened journal marker and retained Windows vault/runtime
  process markers/native/SQL/wire/security gates. Configured staging main compiled
  with TEST ONLY settings, then normal preview rebuilt and artifacts uploaded.
  Raw run/latest-attempt metadata passed exact-source/every-required-step QA,
  including the newly mandatory configured main build.
- All 256 source blobs matched. Local format/49 contracts/17 QA passed. Initial
  widget debug-platform invariant corrected with framework variants; redundant
  imports removed without any production behavior, expectation or gate weakening.
  Native API buffers/providers freed, scope is canonical target SHA256 and probe
  only deletes its GUID `.invalid` journal scope. No user history is deleted.
- Main now supports trusted explicit Windows staging build assembly; default
  remains preview. Journal/process lease precedes token writer; invalid/unsupported
  selected configuration fails before resources. Bootstrap now owns journal +
  runtime, preserves history and drains runtime before journal release. No secrets
  supplied through build settings, no hosted project/provider/schema deployment.
- Core worker RELEASED after persisted evidence. Resume actual head/checks;
  following handoff/QA successor has separate CI. Next supported non-production
  service configuration and actual learner A/B/expiry/restart/two-client acceptance,
  or independent remaining product flows while service configuration is absent.
  All 14 live release groups remain pending. Keep #37 draft/#20/#22/#15 open;
  Pro #38/N4 intact. No dependencies/Auth strategy/API/RLS/production changes.

## Awaited cancelable Windows window close — 2026-10-14 UTC

- Resumed #37 head 84bd5c16; sequential core worker ACTIVE, Pro #38/N4 untouched.
  Pinned engine source confirms final-window WM_CLOSE asks the framework before
  closing; owned host previously had no awaited exit observer.
- Added awaited owned controller close, immediate account-route fencing, fixed
  closing/failure UI, concurrent request coalescing and cancellation on failure.
  Explicit later native close retries retained cleanup; no automatic reopening,
  timeout pretending drain complete, raw exception or learner-history deletion.
- Four framework/widget cases and two actual Windows OS-close fixture phases
  added. Real empty-vault staging owner closes and journal lease reopens before
  natural process exit; external GUID test markers keep fixture drain observable.
  Cancellation fixture fails before delegating owner close, then explicitly retries.
- Format/local contracts/QA and new-source full CI pending. Hosted Auth/learner
  A/B/restart/rotation/logoff/power-loss and all 14 release groups remain pending.
  Scope: docs/ACCOUNT_STARTUP.md. No dependency/provider/schema/RLS/API/default
  preview/N4/production changes. Keep #37 draft and #20/#22/#15 open.

- Early source ea1c7079 CI38608189714 failed analysis on missing explicit
  dart:ui AppExitResponse import. Source 001cb178 CI38608551307 passed analysis/
  359 cases but the new pending-drain UI assertion needed a rendered frame after
  async observer dispatch. Original no-fields/owned-drain assertions retained.
- With that frame rendered, f07ffb2f CI38609111254 exposed a lifecycle defect:
  replacing the active router disposes AppLifecycleListener while the binding's
  copied observer list is awaiting our drain. Preserve the router subtree, revoke
  the account provider override and cover routes offstage with focus/tickers
  blocked until exit. Test additionally asserts same router identity, null
  account publication and focus exclusion. No swallowed framework assertion or
  test/security/build gate relaxation; corrected source needs full fresh CI.

- Source 6878b47e CI38610083054 kept router identity/null override assertions
  but still exposed EditableText lifecycle listeners disposed when account
  revocation removed form children. Keep keyed form subtree mounted but offstage,
  disabled/unfocusable and cleared on the existing state/notice transitions.
  Test now retains password-widget identity and checks disabled/empty controller.
  Windows build/native vault/runtime phases passed, but CloseMainWindow was
  requested before .NET found a main HWND; wait for the real native main window
  after Dart ready marker. Required no-early-exit/cleanup-marker assertions kept.
  No failing/skipped source run counts as verification; fresh full CI required.

### Verified cancelable window close handoff

- Source 2aa94639e99dc38c9af9f5734eba7b47c52a3469 passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38611061291 . Observed 360 Flutter tests (four new
  framework/widget exit cases), five actual Chrome tests, format/analyze, retained
  native/SQL/wire/security/AI checks and web/Windows preview artifacts.
- Actual Windows CloseMainWindow tests passed: pending owned drain keeps process
  alive until externally released; synthetic one-shot close failure cancels the
  first native request, and a later explicit close finishes the same owner. Real
  empty-vault staging runtime closes, real app-data journal lease reopens and
  completion marker precedes natural process exit. Logs contain all four vault/
  runtime/app-data/window-close success markers. Configured staging main compiled,
  then normal preview rebuilt. Raw evidence passed exact-head/every-required-step.
- Retain router + keyed form listeners during the framework observer snapshot;
  null account override revokes publication, offstage/disabled/focus/ticker guards
  block input and existing listeners clear fields. Stronger fixture checks verify
  same router/password-widget identity, empty disabled password and no framework
  exception. First .NET close needed the native main HWND after Dart frame ready.
  All assertions/gates retained; no native exit bypass or forced-exit timeout.
- All 257 source blobs preserved/verified; local format/49 contracts/17 QA passed.
  Prepared QA48 metadata adds this scoped baseline and preserves all 14 pending
  integrations. Hosted Auth, logged-in learner expiry/restart/rotation/two-client,
  uncancelable logoff/kill/power-loss and full acceptance remain unproven.
- Core worker RELEASED after saving evidence. Following four-file docs/QA
  successor has separate CI; resume actual head/checks. Next supported staging
  service configuration + actual learner acceptance, or independent remaining
  product flows while absent. Pro #38/N4 untouched; keep #37 draft/#20/#22/#15 open.
  No dependency/provider/Auth strategy/schema/RLS/API/production changes.

## Explicit owned account refresh action — 2026-10-14 UTC

- Run core-20261014T1952-manual-refresh started/claimed at 2026-10-14T20:00:09Z;
  base/head 5492475f02cfd59d2f4b64f26161660bb46ff3b2 on #37/core branch.
  Latest main 78a44faf; prior exact-head CI38612153007 completed successfully
  with all five latest-attempt jobs. Pro #38/N4 scope remains reserved/untouched.
- Clone proxy had no credential; fetched all 257 blobs freshly through GitHub
  at the actual immutable head, decoded binary/text and checked Git blob SHA1.
  No previous-run source/worktree/SDK was used. Current cloud has no Dart/Flutter
  and lacks jsonschema; retain all CI gates instead of weakening them.
- Added credential-free refresh capability/active-owner provider wiring and
  explicit account “Làm mới phiên” action. Forward to the existing exclusively
  owned SDK/persistence runtime; no learner URL/key or SDK mutation exposed.
  Existing exact-secret save-before-profile gate is unchanged/authoritative.
- Pending UI clears/hides credentials and study/profile, blocks repeated clicks
  and allows explicit logout. Fixed unexpected-error text is scoped to the same
  action/controller/session; logout/switch/replacement/unmount discard old errors.
  No Auth/default activation, automatic retry/timer, secret/log/plaintext fallback.
- Nine controller/widget fixtures added and two existing actual pinned-SDK
  rotation/durable-pending cases use the new command interface without changing
  original assertions. New-source format/analyze/Flutter/Chrome/native/build
  checks must run on GitHub Actions; none is claimed locally. Stdlib QA pending
  verification below. All 14 live release groups and #20/#22/#15 remain open.
- Scope: docs/SESSION_REFRESH.md. Source implementation complete; fresh diff
  review/checkpoint/CI handoff below. Core marker remains ACTIVE until persisted
  and released in PR body. Keep #37 draft; no merge/deployment/provider/RLS/API/
  dependency/N4 changes. Next exact-head CI review/fix, then configured hosted
  learner acceptance or independent remaining product work while unavailable.

### Manual refresh source checkpoint / CI handoff

- Fresh full-tree diff reviewed independently after writing: 13 scoped paths,
  nine new tests plus two retained pinned-SDK cases routed through the action.
  Matched 257 base blobs from GitHub before edits; preserve binary assets and all
  unrelated files. No protected content/N4/content tests, API, schema, dependency
  or CI definition changes. Additive code/test files only expand the tree.
- Stdlib QA inventory passed with 49 cases; all 17 QA regression tests passed.
  Local Flutter/Dart/format/analyze/build/native and 49 contract tests were not
  executed because this fresh cloud runtime lacks SDK/jsonschema. New source
  remains unverified until its exact-head Actions run/latest-attempt gates pass.
  Parent CI38612153007 success is historical, never substituted for new source.
- Core run core-20261014T1952-manual-refresh RELEASED at persisted checkpoint;
  source SHA, current heartbeat and CI URL/status are recorded in #37 body.
  Only waiting on CI after persistence: next run checks the actual head/complete
  latest attempt and fixes any format/analysis/test/native/build failure before
  new implementation. No duplicate worker/code, long keepalive polling, merge,
  deployment or schedule pause. Hosted config and all 14 acceptance groups still
  pending; do not request secrets or report Personal Alpha complete.


## Verified same-session refresh timeout fix — 2026-10-15 UTC

- Resumed PR #37 / `automation/issue-22-atomic-review` at source head `b7198e2`; Pro PR #38 and all N4 paths remained untouched. The diagnostic CI #228 reproduced the original 10-minute timeout after the restored-session event, before the test's readiness assertion; temporary markers were removed before the final change.
- Final source commit `7b8c184ac590d7f07658deccae99a7e3f04fe7b3` changes only `apps/flutter_app/test/features/srs/manual_session_refresh_test.dart`. It replaces the unbounded zero-duration fixture drain in this widget test with bounded Flutter frame pumps, retaining the same-session identity, no-error, ready-runtime and no-exception assertions and the existing 10-minute test timeout.
- Exact-head CI run 38667034793 passed on its latest attempt: ai-boundary, repo-sanity, database, flutter (format, analyze, full test suite and all downstream verification/build steps) and windows. The first Windows attempt failed at an exit-marker fixture check; rerunning only the failed job passed without changing code or gates.
- This proves the regression test and cloud CI path; it is not hosted Auth/learner or Personal Alpha acceptance evidence. Live Auth, multi-device/session rotation, provider integrations and remaining release groups remain open. Next: keep PR #37 draft for review, then continue the documented Auth/vault/session acceptance work without touching Pro N4 scope.


## Verified duplicate same-session Auth event guard — 2026-10-15 UTC

- Resumed PR #37 at source head `437255fa159fd112c361df7f11f495daf9ef7704` after the prior RELEASED marker; Pro PR #38/N4 remained untouched. Added one TEST ONLY lifecycle scenario in `apps/flutter_app/test/features/srs/session_lifecycle_fixtures.dart` for a repeated Auth event with the identical session object and refresh secret.
- The scenario asserts that readiness remains available and the credential vault write count does not increase. It covers the existing `PersistentAccountAccess` same-session/same-secret short-circuit without changing production code, Auth strategy, storage schema, or CI gates.
- Source commit `555dd9a6d09f56e2d84c740aea0829c7b6a7a3c8`; exact-head CI 38678938196 passed all five required jobs, including Flutter format/analyze/full tests and downstream Chrome/native/web/Windows checks. No required job was skipped.
- This is fixture evidence only; hosted Auth signatures, real learner A/B, multi-device rotation and remaining Personal Alpha gates still require supported staging configuration. Keep PR #37 draft and continue only with independently scoped work until that human gate is available.


## Verified pending same-session Auth event coalescing — 2026-10-15 UTC

- Resumed PR #37 at source head `54c010c4bca7197fd4a9ee878192dda6bd6d02aa`; Pro PR #38/N4 remained untouched. Added one TEST ONLY lifecycle scenario in `apps/flutter_app/test/features/srs/session_lifecycle_fixtures.dart` for a duplicate same-session/same-refresh event while the first vault write is still pending.
- The scenario asserts that the duplicate event does not queue a second vault write and that readiness is published only after the original write completes. Production Auth/vault behavior, assertions, API/schema, CI, and security gates are unchanged.
- Source commit `c399870d51f612e5cb76006da3b5133da9e43af8`; exact-head CI run [38681835045](https://github.com/collab-TTAM/nihongo_daily/actions/runs/38681835045) passed on its latest attempt: ai-boundary, repo-sanity, database, flutter (format/analyze/full tests and downstream checks) and windows. The first Flutter attempt exposed one transient existing test failure (370 passed, one null readyRuntime assertion); rerunning only the failed job passed all checks. No required job was skipped.
- This is fixture evidence only; hosted Auth signatures, real learner A/B, expiry/restart/two-client behavior and remaining Personal Alpha gates still require supported staging configuration. Keep PR #37 draft and continue without touching Pro N4 scope.


## Verified same-session secret rotation drain — 2026-10-15 UTC

- Resumed PR #37 at source head `02735fc2bcf31a43d92766604ac423b8f980411e`; Pro PR #38/N4 remained untouched. Added a TEST ONLY lifecycle scenario for a same-session refresh-secret rotation while the first vault write is pending.
- Fixed the owned persistence barrier in `apps/flutter_app/lib/features/auth/data/persistent_account_access.dart`: `_settle()` now drains until the queued write tail is stable, so a newer same-session rotation queued during the first write is persisted before readiness is evaluated. No retry loop, token logging, Auth strategy, schema or CI gate changed.
- Source commit `312327ec1de5e73d87dc8df7c2ef4acf5489c856`; exact-head CI run [38684718287](https://github.com/collab-TTAM/nihongo_daily/actions/runs/38684718287) passed on its latest attempt: ai-boundary, repo-sanity, database, flutter (format/analyze/full tests and downstream checks) and windows. Flutter observed 371 tests with the new scenario; the first Windows attempt hit the known exit-marker fixture flake and rerunning only that failed job passed all Windows checks. No required job was skipped.
- This is fixture and local persistence evidence only; hosted Auth signatures, learner A/B, expiry/restart/two-client behavior and remaining Personal Alpha gates still require supported staging configuration. Keep PR #37 draft and continue without touching Pro N4 scope.

## Guarded SRS due-queue level selection — 2026-10-19 UTC

- Run core-20261019T1332-srs-level-selection resumed released PR #37 at
  92744739be619d78c2df809bc30b051f69033bf3; main 78a44faf unchanged. All five
  latest-attempt exact-head jobs in CI38685894607 passed. Fresh cloud clone
  matches GitHub; no prior temporary source/SDK was used. Pro #14/#38/N4 untouched.
- Added explicit N5/N4 due-queue selection on configured SRS, guarded controller/
  notifier commands and retained level on navigation/empty/error reload. Session
  revocation clears selection. No preview preference/curriculum state is written.
- Controller/UI prevent level changes while loading/recovering/saving or any
  immutable pending/rejected event remains. Explicit rejected-event reload stays.
  Changing level hides revealed content and loads a fresh captured-session queue.
- Five controller and four widget cases added; native recovery test strengthened
  to preserve original request/selected level before exact retry. Existing mobile
  320/375px at 200% cases retained. No N4/content tests/data, dependencies,
  workflow/security/Auth strategy/schema/API/default activation changes.
- Local 17 stdlib QA tests passed; git diff --check passed. Contract tests could
  not import because jsonschema is unavailable. Flutter/Dart SDK is absent, so
  format/analyze/Flutter/Chrome/native/web/Windows checks require exact-head CI.
  Source diff/full-tree preservation reviewed before checkpoint.
- Keep #37 draft and #20/#22/#15 open. All 14 live acceptance groups remain
  pending; no hosted config, learner A/B/restart/two-client or Alpha claim.
  Next: exact-source CI/fix failures, then supported hosted acceptance or the
  next independent increment. Run ACTIVE until source/CI handoff is persisted
  and the PR marker is RELEASED.

### Formatting correction / automatic continuation — 2026-10-19 UTC

- CI39262147940 at fab49332074367204a08303a310f5ac74323fc5c stopped Flutter
  at dart format: one controller-test file changed. Other required checks and
  Flutter downstream steps are not counted as passing on that source.
- Shortened one test description to fit the formatter line width; all assertions,
  nine new cases, behavior and CI/security gates remain unchanged. Corrected
  source still needs exact-head format/analyze/test/native/web/Windows CI.
- User explicitly requested automatic continuation. Existing hourly cloud task
  6ace2a9c236c819189637e49f38182d7 was resumed, enabled=true, in Asia/Saigon;
  no duplicate schedule or cadence/guard changes. Read actual PR/head/CI first.
- Core run core-20261019T1343-srs-format uses fresh GitHub source, expected-head
  update and full-tree verification. Pro #14/#38/N4 unchanged. Keep #37 draft;
  all 14 live release groups remain pending. Final release/CI checkpoint is in
  PR #37 body; next scheduled run fixes any remaining CI failure before new work.

### Analyzer correction — 2026-10-19 UTC

- Exact-head CI39262893248 at c303af4493998a2c33c5167fa2d70333d9848285 passed
  format and four complete jobs (repo-sanity/database/ai-boundary/windows), but
  Flutter analyze stopped on unnecessary_import in srs_study_widget_test.dart.
- Removed the direct PreviewLevel import already exported by preview_preferences.
  No lint suppression, assertion/test removal, production behavior or CI change.
  All nine new level-selection cases still require execution on corrected source.
- Core run core-20261019T1351-srs-analyze resumed released source with a fresh
  GitHub clone, full-tree/expected-head checks and separate diff review. Pro N4
  scope unchanged. Hourly continuation remains enabled; keep PR #37 draft and
  all hosted learner/release gates pending. Exact-source CI and final RELEASED
  checkpoint are recorded in PR #37; next run checks CI before new development.

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

## Owned Daily Plan SDK composition — core-20261019T1918-plan-sdk

- New isolated automation/issue-11-plan-sdk-integration combines source #37 afa572a27f050048990ad4feb07fd6f01758e7e2 and #40 b03bf105f74caf7032ec136c13eddb752d103dab. Parent CI39263961507 and CI39309235348 passed allfive required jobs; new combination is not yet tested. Original PR branches/main/Pro #14/#38/N4/reader #39 remain unchanged. Global one-core marker remains in #37.
- Manually reviewed four merge conflicts: retain core CI validator's exact name/same pinned package and all core Windows/Chrome/native/security steps; retain review parity/atomic races/queue export then all three plan/session/submit runners; preserve both complete status histories and Supabase README sections. All other merged paths reviewed. Frozen v0.1/dependencies/lockfile, Auth save-before-profile/startup/close/refresh implementation and canonical content unchanged.
- Add CapturedDailyPlanGateway borrowing existing captured Supabase transport, fixed get_daily_plan/submit_study_session envelopes only, bounded <=15-second operation, safe typed failures and irreversible readiness/session revocation. Registry retains envelope/scalar/byte limits and rejects owner/derived/unknown function input; only two explicit allowed operations added. No token/callback-to-current-client fallback or second SDK/store/resource owner.
- Add explicit nullable PersistentSupabaseRuntime.createDailyPlanRepository factory behind persisted-secret/profile readiness and exact ready-runtime/session identity; refresh barrier, expiry/logout/replacement/close fence old leases. Native/owned Auth lifecycle implementation remains unchanged. Factory is not installed into app providers/routes; no save UI or durable completed-session journal is claimed.
- Authored six registry/gateway and four actual pinned-SDK/mock-HTTP/vault cases covering persistence/profile/factory order, exact RPC HTTP body/headers, stale/late calls, same-user relogin, refresh vault fence, safe HTTP failure/timeout/expiry/close. TEST ONLY unsigned JWT/memory OS fixtures are not hosted identity, real OS vault or learner proof. Old SQL/race/Dart/Chrome/Windows/security tests retained.
- Local Dart format, pure gateway/registry analysis, actual registry/envelope/typed read-write/revocation standalone smoke, shell syntax, whitespace and QA49 inventory/all17 regressions passed. Full local Flutter/SDK/jsonschema/PostgreSQL unavailable: combined current-head tests/native/wire/build must run through Actions. No new-source full pass claimed; parent evidence is historical only.
- Docs/DAILY_PLAN_SDK.md records integration review/policy/limits. Keep all14 hosted release gates and #11 open; new integration PR stays draft. No source PR merge, deployment, paid/provider/Auth strategy/security reduction or schedule change. Next inspect exact new head/latest-attempt CI and fix failures preserving assertions; after green bind the factory to owned startup/providers, durable study-event queue and actual plan/study/save UI. Receipt replay remains older snapshot; load latest plan after acknowledgment.


## Owned Daily Plan read UI — core-20261019T1942-plan-ui

Continue integration #41 from4461fd9 / tree99a50317. Verified CI39311989226
allfive jobs/every required step successful; completed Flutter logs confirm six
captured gateway and four actual-SDK cases passed. Both source drafts unchanged.

Publish the borrowed plan source only through active owned startup, with current
profile/runtime gated Riverpod composition and explicit /plan account action.
Read-only UI requires an explicit valid date under displayed profile timezone;
server-only seven blocks/statuses/over-target progress, loading/redacted failure/
offline explicit reload, account replacement/late result fences. A keyed mounted
but cleared/disabled/hidden date form preserves the existing awaited-exit observer
invariant. No activity/save/durable queue success is manufactured. Ten widget
cases authored incl startup publication, owner changes, layout and real binding
exit request; full current-head execution requires independent exact-head CI.

Separate composition/lifecycle/test review and local checks precede persistence;
see DAILY_PLAN_UI.md for scope and limitations. No core source draft/main/Pro N4/
reader, API/schema/dependencies/security/provider/release/schedule changes. Keep
#11 open/#41 draft/all14 live acceptance groups pending. After new-head CI,
continue durable completed-study event recovery and actual timer/save composition.


## Windows plan-source forwarding — core-20261019T1950-plan-windows-source

Resume #41 at a12d95d, treee8c3e2f. CI39313830624 observed repo-sanity/database/
ai-boundary/Flutter successful (format/analyze/full tests/all downstream/Web);
Windows native checks still running at inspection. Actual source review found
the production Windows owner did not forward the new source interface, unlike
the inner session/test owner. Forward the borrowed source through that exact
outer owner, returning null once close starts; preserve existing resource/drain
order. Public constructor permits the same production assembly to be tested
with actual SDK/mock HTTP/native journal and startup controller. One additional
regression covers ready/read/refresh/close/lease/reopen and unchanged interrupted
refresh cleanup; prior ten widget/ten SDK-gateway cases remain. No timer/queue/
save completion claim. Separate composition/lifecycle/test review and local
format/QA/whitespace precede persistence; exact new-head checks still mandatory.
Keep #41 draft/#11 open/all14 live gates pending, source drafts/main/Pro/reader/
API/schema/dependencies/Auth strategy/security/deployment/schedule unchanged.


## Opt-in completed-study durability — core-20261019T1956-durable-study

Resume #41 from21de4608/tree daf2221d. CI39314626994 now verified allfive
jobs/every required step successful, including the production Windows wrapper
SDK/vault/journal-close regression and all10 prior UI cases. Source drafts/main
and Pro/reader lanes remain unchanged.

Added strict canonical stored-report decoding; owner/session/delegate-ready
scoped durable submission/recovery; flushed immutable staging before RPC;
uncertain commit retention, definitive-code rejection, durable acknowledgment
then fresh-plan read with distinct confirmed/reload-failed result. Old same-owner
wrappers cannot revive after readiness/identity loss. No cached derived progress.
Separate bounded native append log keeps pending/terminal history, protects its
lease, reserves terminal capacity, repairs only partial EOF and fails closed on
complete corruption; close shares/drains ownership. It does not touch SRS files.

Six reusable real-disk scenarios and an actual abrupt child-process exit/exclusive
lease/reopen verifier passed locally with pinned Dart, along with pure-source
analysis/format. Six Flutter cases authored; the verifier is appended to both
Linux and Windows CI jobs, keeping every earlier gate. Full Flutter/current-head
SDK/browser/native/Web/Windows checks remain unverified until new exact-head CI.
See DURABLE_STUDY_SESSIONS.md for protocol, hard limits and evidence boundaries.

The library is not installed into owned startup/service/UI yet. Next after green:
open/close the separate store under the owned project lifetime, publish the
captured durable service, expose explicit recovery then real timer/save UI. Keep
#11 open/#41 draft/all14 hosted gates pending. No API/schema/RLS/dependency/Auth
strategy/security/release/deployment/source-PR merge/Pro content/schedule change.

## Owned completed-study recovery — core-20261019T2016-owned-study-recovery

Resumed 2026-10-20 on integration #41 at ac8cbd9, source #37/#40 and main
unchanged. Parent CI39316750394 was freshly inspected: all five jobs/every
required step succeeded, including native completed-study Linux/Windows gates.
This historical result does not establish new-source success.

Configured Windows now acquires its separate study journal before SDK creation,
publishes a captured durable service through the actual startup owner only after
account/profile readiness, and exposes manual /study-recovery from account/plan.
Check lists only own pending reports without RPC; explicit send retains exact
reports on uncertainty, durably acknowledges before confirmation, then reads
fresh progress. Failed progress reload remains confirmed with an explicit notice.
Account changes clear visible state and fence late results; errors are redacted.
Runtime-scoped unfinished-operation drain runs concurrently with immediate
existing Auth close and precedes SDK disposal and release of both journal leases.

Seven real-disk scenarios plus abrupt child exit/restart/process lease/reopen
passed locally with pinned Dart3.9.2. Pure-source analysis found no issues;
format0changes after normalization, QA inventory49/17 regressions and diff
whitespace checks passed. Nine new widget cases and two actual-SDK/mock-HTTP/
native-journal cases authored; every prior assertion/gate retained. Full Flutter
packages are unavailable locally. A local Flutter dependency attempt was blocked
by automatic approval review because it contacted instance metadata; no bypass
or local full-Flutter success is claimed. Exact-head Actions is required for
new widget/SDK/browser/native/platform tests, analysis and Web/Windows builds.
The workflow, frozen contracts, schema/RLS, dependencies, Pro/N4 and reader
content are unchanged. See OWNED_STUDY_RECOVERY.md for flow and ownership review.

Next inspect #41 current head/latest-attempt CI and fix actual failures before
new implementation. Only pending CI means save/release, not duplicate work or
long polling. After green, implement actual activity timer/new completed-report
creation and correct profile-local day selection; browser storage and all14
hosted JWT/A-B/restart/two-device acceptance groups remain pending. Keep #11 open,
#41 draft/default preview. No merge/deployment/Auth strategy/provider/spend or
schedule change.


## Recovery widget clock correction — core-20261020T0318-study-widget

Resume #41 dd9d926; CI39363253639 latest attempt: repo-sanity/database/ai-boundary/
Windows succeeded. Flutter format and analysis passed, then437 tests passed/7
failed. All seven actual-SDK cases (both new study lifetime cases included),
all seven real-disk Flutter scenarios and all ten original plan widgets passed.
Seven recovery widget failures occur before dispatch: six missing check actions,
one startup/profile loading timeout. Downstream Flutter gates were skipped,
not passing. Keep #41 draft and all14 hosted gates pending.

Root cause: shared setUp constructs the account Harness and its Auth stream
listener outside testWidgets fake-clock zone. Immediate profile Future.value
completion escapes pump's microtask queue; the delayed completer case created
inside that zone passes. A pinned Dart diagnostic with actual account controller/
Auth fixture proves the outside-pending/inside-ready behavior. Move fixture
construction into each of all nine widget bodies, retain cleanup/held-write
release and every original assertion, add ready/service/publication checks.
No production behavior, test count, assertion, lint/security gate or workflow
was weakened. No new timer/report UI is included in this bounded correction.

Local targeted Dart analysis reports no issues; pinned format0changes, standalone
zone diagnostic, all17 QA regressions and whitespace passed. Packages are present,
but Flutter test --no-pub itself was blocked by automatic review because it
accessed instance metadata. No bypass/retry through indirect execution, no full
local widget result claimed. Corrected source needs new exact-head Actions.

Next inspect actual #41 head/latest-attempt complete CI, fix actual failures and
only after green continue real activity timer/new-report creation/profile-local
day. Only pending CI means save/release rather than duplicate changes/long poll.
Main/source drafts #37/#40, Pro #14/#38/N4, reader #39, contracts/schema/RLS/
dependencies/production Auth policy unchanged. No merge/deployment/provider/spend
or schedule change. See docs/OWNED_STUDY_RECOVERY.md.


## Foreground SRS session recorder — core-20261020T0326-srs-study-timer

#41 parent b28684c CI39363924790 was freshly verified allfive jobs/every required
step success, including444 Flutter/five Chrome/all9 recovery widgets/all7 SDK
cases/native process gates/Web/Windows. The prior fixture correction is verified;
this historical evidence does not verify the new recorder source.

Configured /srs now exposes an explicit profile-date elapsed recorder only with
a current ready real card at the profile level. Local pending-report preflight
blocks before server reads; an available server SRS plan is required before a
monotonic foreground interval starts. Finish freezes one UUID/date/SRS/UTC report,
flushes through the existing durable service then awaits validated confirmation
and fresh progress. Failed staging/ambiguous commit keeps the same frozen report
for explicit retry across navigation; no replacement event or automatic replay.
Reload failure remains confirmed. Definitive rejection stays durably terminal.
Route/background/queue/account interruption cancels unfinished timing with no
credit; no pause/background accrual. Existing runtime drains accepted saves.
Keyed date field remains mounted, cleared/hidden/disabled/unfocusable on revocation
for awaited exit. Duration60..90000s, wall-clock discrepancy>5s fails without
credit; server still owns date/overlap/availability/minutes and derived progress.
Authenticated self-reported duration does not prove mastery or attention.

Eight new recorder scenarios with real disk and explicit Auth/RPC/clock passed
locally, along with all7 prior recovery cases and abrupt child restart/process
lease/reopen. They are included in Flutter discovery and the retained native
verifier in both existing Linux/Windows jobs; workflow unchanged. Nine widget
cases authored for actual card/profile/date/start/finish/retry/recovery/lifecycle/
owner/field/large-text behavior. Existing assertions and gates retained.
Pinned Dart formatter, targeted production/test analysis, QA inventory49/all17
regressions and whitespace passed. Full new-source Flutter/SDK/browser/native/
Web/Windows results pending exact-head Actions. Local Flutter CLI execution is
blocked by metadata-endpoint approval review; no bypass/indirect retry attempted.

After current-head CI/fixes, continue automatic correct profile-local day,
additional real activity flows and hosted learner validation. Other timers,
browser study persistence, unfinished-interval crash recovery and all14 hosted
JWT/A-B/restart/two-device acceptance groups remain pending. Keep #11 open/#41
draft/default preview. No source draft/main/Pro/reader content/contract/schema/
RLS/dependency/Auth strategy/provider/spend/deployment/merge/schedule change.
Details and limitations: docs/SRS_STUDY_TIMER.md.


## Timer retry hit-target correction — core-20261020T0437-timer-hit-test

Resume #41 at575716dd after reading actual source/global RELEASED marker.
CI39365344329 latest attempt completed: repo-sanity/AI/database/Windows pass,
including15 native recorder/recovery scenarios and actual process leases.
Flutter format/analyze pass,460 tests pass/1 fail. All8 pure recorder scenarios,
8 other timer widgets and prior SDK/recovery cases passed. The retry-navigation
widget tapped an offscreen/covered button (y556 hit bottom navigation), then
list.single found no staged event. This is an observed hit-target fixture fault;
full Flutter downstream browser/Web checks were skipped, never counted as pass.

Both retry actions now use a helper that scrolls to the button, settles layout,
asserts a hit-testable target and taps normally. Added exact1/2 RPC dispatch
assertions. Preserve all9 widget cases/original assertions, exact frozen report,
single committed receipt and one event ID. No warning suppression or direct
callback shortcut; no production behavior/viewport/CI gate change.

Local pinned format, all17 QA/inventory49, whitespace and separate diff/assertion
review passed. Full corrected-source Flutter/SDK/native/browser/Web/Windows
requires exact-head Actions. Previous local Flutter CLI metadata-endpoint
approval rejection remains; no retry/workaround/indirect execution attempted.
Next inspect new exact-head/latest-attempt complete CI, fix actual failures,
then profile-local today/additional real activity flows. Only pending CI means
save/release, no duplicate work/long polling. Keep #11 open/#41 draft/default
preview/all14 hosted gates pending. Source drafts/main/Pro/reader/contracts/
schema/RLS/dependencies/Auth policy unchanged; no merge/deployment/provider/spend/
security/schedule change. See docs/SRS_STUDY_TIMER.md.


## Server profile-local today — core-20261020T0441-profile-study-day

Resumed after #41 ebf09bc CI39370830597 verified allfive jobs/every required step
success,461 Flutter/five Chrome and retained SDK/native/Web/Windows gates. The
retry hit-target correction is verified; parent evidence is historical only for
this new source. Read-only continuation review in #41 selected a server-owned
calendar projection instead of device-date guesses or a client timezone database.

Additive contracts/calendar/v1 and get_study_day now accept only an empty request,
derive auth.uid owner, read the current validated profile timezone and one server
statement instant, and return exact date/timezone. No profile/bootstrap/learning
write. Definer path/ACL/private converter and role/calendar/no-write review/test
boundaries preserve frozen v0.1/study payloads/RLS/table grants/Auth policy.
Captured SDK/registry adds one fixed empty envelope and reuses existing transport/
readiness/late-result fences. Typed decoding rejects malformed days/zones and
profile timezone mismatch; safe UI tells the learner to refresh their account.

Configured /plan and /srs offer explicit today buttons that only fill existing
date fields. Manual entry, load/start/finish remain separate. Duplicate lookup
is disabled; newer manual edits, disabled action, logout/profile/source change
and disposal reject old results. Frozen uncertain reports cannot be retargeted.
No auto-fetch/write/retry or midnight subscription. Existing retained keyed
fields preserve account revocation/awaited exit ownership. See PROFILE_STUDY_DAY.md.

Six pure captured-day scenarios passed locally, together with all15 existing
real-disk recorder/recovery cases and actual abrupt child/process-lease/reopen.
Six Flutter day cases/six widgets/one actual-SDK case/three contract cases plus
native role/calendar/actual-four-wire tests authored. Database runner/native tool
append coverage; workflow and all prior steps/assertions retained. Pinned Dart
format/pure-source analysis, Python compilation, JSON parse, shell syntax, QA17/
inventory49 and whitespace passed. Full jsonschema/PostgreSQL/Flutter widget/
SDK/browser/Web/Windows requires exact-head CI; dependencies are absent locally.
No retry/bypass of prior Flutter CLI metadata-endpoint approval rejection.

Next inspect actual #41 exact head/latest attempt/every required step, fix actual
failures preserving assertions, then continue remaining real activity/hosted
learner acceptance. Only pending CI means save/release without duplicate work or
long polling. Keep #11 open/#41 draft/default preview/all14 hosted groups pending.
No source drafts/main/Pro/reader/dependencies/Auth strategy/provider/spend/security
reduction/hosted deployment/merge/schedule change. Existing immutable report dates,
server overlap/day/minute validation and pending recovery remain authoritative.


## Public N5 reader in owned integration — core-20261020T0503-reader-integration

Resumed #41 ad299b12 after CI39372174900 latest attempt completed successfully:
allfive jobs/every required step,474 Flutter/five Chrome, native day/calendar/ACL/
no-write/four-wire checks, owned process/SDK/lifecycle/Web/Windows gates. Separately
reviewed #39 reader57acb709 and CI39272055003 allfive jobs/every step success.
These source passes are historical evidence, not combined-head verification.

The integration now opens actual /vocabulary and /grammar from the existing study
cards rather than placeholders. Imports unchanged five production reader/search
files, two canonical N5 asset copies (24 words/10 patterns), two reader test files,
updated real home CTA test and optional PageBody controller. Routes combine with
all prior account/plan/recovery/SRS/Kanji/other placeholders; pubspec adds only the
two asset declarations. Study cards explain current reading/SRS/Kanji capability.
No #39 source/content, Pro N4 assets, dependency/lockfile/workflow/Auth/schema/RLS
or existing owned-runtime behavior changed. Public reader has no learning-write
capability and its process-local preview level never retargets the own profile.

Two additional owned-host widget cases authored, one for each actual bundled
reader: read the existing plan first, navigate/search original content without
extra plan/queue calls, preserve authenticated N4 profile during public N5 reading,
then await close with the search EditableText still mounted and focus excluded
behind the existing closing screen. TEST ONLY Auth/plan fixtures are not hosted
learner/actual OS shutdown proof. All existing reader and owned checks retained;
the home test replaces its placeholder assertion with original reading/detail.

Local pinned Dart formatter and pure curriculum-domain/search analysis passed;
11 imported reader/asset/test/layout files exactly equal reviewed #39, and both
packaged asset texts equal the canonical data. Original route-set equality and
all five owned paths verified. QA inventory49/all17 regressions and whitespace
passed. Full combined Flutter/widget/SDK/native/Web/Windows execution requires
exact-head Actions; local Flutter package execution remains unavailable after
prior metadata-endpoint approval rejection, with no retry/workaround attempted.
Separate production/test/composition diff review completed before persistence.

Next inspect actual combined #41 head/latest-attempt complete CI and fix failures
preserving assertions. Only pending CI means save/release without duplicate work
or long polling. After green, add validated vocabulary/grammar elapsed sessions
through the existing durable service, not credit from reading/navigation. Keep
#11/#12 open/#41 draft/default preview/all14 hosted gates pending. Main and source
drafts #37/#39/#40 remain unchanged; no Pro content/dependency/security/provider/
Auth policy/spend/merge/deployment or schedule change. CURRICULUM_BROWSER.md records
composition, limitations and verification scope.


## Reviewed N4 seed in reader — core-20261020T0515-n4-reader

Resumed #41 dbbb92e1 after exact CI39373165397 latest attempt passed allfive
jobs/every required step,495 Flutter/five Chrome/SDK/native/Web/Windows. Completed
logs explicitly verify both owned curriculum/plan/retained-search exit cases.
The preceding reader integration is verified. Separately reviewed Pro #38 source
28c20cb0, exact CI38696918878 allfive jobs/every required step success. Source
branch unchanged. These passes are historical for this new combined source.

The N4 reader prerequisite is prioritized before new activity reports: an N4
profile previously had only public N5 content available, which must not be used
to credit an N4 plan. Import seven reviewed Pro content/manifest/docs/test paths
byte-for-byte, retaining all N5 bytes/IDs and N4 first-version records. Package
exact N4 vocabulary/grammar copies; fixed typed level paths now load N5 or N4,
never fallback. Reader/search/detail/adjacent navigation supports366 N4 words and
139 patterns/1010 original Japanese/kana/Vietnamese examples.95 Kanji metadata
records are canonical data only, not new writing/trace/grading UI. No content is
provisioned to a hosted database. Public level still never changes the account
profile/SRS/plan. These are incomplete editorial seeds pending teacher/native
review, not certified full JLPT. Audio/stroke assets/grading remain unavailable.

Two N4 asset/codec cases authored: full asset-text equality, every ordered ID/
version/meaning and every Japanese/kana/Vietnamese example. Replace the obsolete
unbundled-level expectation with both-kind missing-asset failure/no-N5-fallback.
All other reader cases/assertions retained, including explicit injected missing
N4 fixtures. Two additional original N4 widget cases cover switching from N5,
search/detail/examples/clear/next/back to N5 at320px/200-percent text, with actual
hit-testable taps. Existing account/plan/SRS/owned exit tests unchanged.

Local pinned Dart format4/0changes, QA inventory49/all17 regressions, Python
compilation, source/asset/N5 byte parity, content-test AST review and whitespace
passed. All prior Python content tests remain; only aggregate expectations change,
with one added localized-meaning test from Pro. Copied Pro docs/test retain CRLF
bytes; standard whitespace rules were checked with CR-at-EOL recognized locally,
without repository/CI configuration changes. Full jsonschema/Flutter/widget/
SDK/native/Web/Windows execution unavailable locally and requires exact-head
Actions. No retry/workaround of the prior Flutter metadata-endpoint rejection.
Separate source/test/compatibility/composition review completed before saving.

Next inspect actual #41 new head/latest-attempt every required job/step, fixing
failures without weakening tests. Only pending CI means save/release without
duplicate changes/long polling. After green continue one shared account-scoped
foreground/frozen-report coordinator for SRS/vocabulary/grammar: a report whose
stage failed exists only in memory and must block cross-area replacement until
explicit exact retry. Require real same-profile-level content and available
same-area server plan; preserve existing drains/retained fields/immutable events.
Keep #11/#12/#14 open/#41 draft/default preview/all14 hosted groups pending. Main,
Pro #38 and source #37/#39/#40 branches remain unchanged; no authored-record edits,
dependency/Auth policy/schema/RLS/security/provider/spend/merge/deployment or
schedule change. CURRICULUM_BROWSER.md records the composition and limits.


## Shared foreground/frozen slot — core-20261020T0525-shared-study-recorder

Resumed #41 at621e515 after exact CI39374191185 allfive jobs/every required latest
step success,499 Flutter/five Chrome/SDK/native/Web/Windows. Completed logs show
both N4 assets and both320px/200-percent N4 reader flows passed. N4 source verified;
that success is historical for this common-recorder refactor.

Extract StudySessionRecorder supporting SRS/vocabulary/grammar with one captured
owner/slot and area-aware state/readiness/server-block selection. Preserve all
existing pending-before-read, duration/clock, immutable freeze, stage/submit/ack/
fresh-plan, explicit retry, definitive rejection and resource-drain behavior.
Checking/running/saving/uncertain prevent cross-area replacement, including stage
failure before a journal entry exists. Scoped interruption and generation fencing
prevent an old route/preflight canceling a newer area's timing; accepted saves
remain uncanceled. Revocation clears the area and suppresses old-owner results.

Legacy SrsSessionRecorder constructor/clock/state exports remain through a wrapper.
The old SRS provider aliases exactly one shared provider/notifier. Configured
readiness remains SRS-only; reader UI/profile-content guards are deliberately not
installed by this prerequisite. Existing SRS panel/keys/retained field/level/clock
behavior stays intact. No new fake learning credit, runtime/token/storage owner,
retry, RPC, content/API/schema/RLS/dependency/CI/provider/schedule change.

Six cross-area scenarios with actual native files passed: all three areas,
unstaged frozen exclusion, uncertain commit/exact retry, correct-area availability/
readiness recheck, scoped interruption/late preflight and held-save replacement
owner. Retained all7 recovery/all8 original SRS/all6 captured-day scenarios; the
expanded native tool passed27 scenarios plus abrupt child/process lease/reopen.
These comprise21 real-disk plus6 captured-RPC cases. Six Flutter wrappers and one
actual Riverpod/native legacy/shared-consumer regression authored. Full provider/
widgets/SDK/platform checks require exact-head CI, not the local pure verifier.

Local pinned formatting/core+fixture analysis, native verifier, QA17/inventory49
and whitespace passed; source/provider/test compatibility diff separately reviewed.
Initial new-fixture enum/import diagnostics were corrected before successful
analysis/execution; no case/assertion removed. Local full Flutter remains unavailable
after prior metadata-endpoint approval rejection; no retry/bypass attempted.

Next inspect actual new #41 head/latest-attempt every required CI job/step and fix
failures preserving assertions. Only pending CI means release/handoff without
duplicate work/long polling. After green wire vocabulary/grammar UI to this same
provider with actual loaded same-profile-level content, same-area server plan,
visible immutable report area, explicit start/finish/retry and area-scoped route/
background/level/account interruption. Keep date fields mounted/cleared/hidden/
unfocusable for awaited exit. No independent activity recorder or silent credit.
Keep #11/#12 open/#41 draft/default preview/all14 hosted groups pending; main/Pro/
source drafts and content unchanged. No merge/deployment/Auth policy/security/
provider/spend/schedule changes. See docs/SHARED_STUDY_RECORDER.md.


## Shared recorder fixture cleanup lint — core-20261020T0540-shared-recorder-lint

Resumed #41 bea659ae; actual CI39375345330 latest attempt completed with four jobs
success: database/repo-sanity/AI/Windows. Windows logs explicitly confirm all six
new shared-recorder scenarios and actual abrupt child/process lease/reopen passed.
Flutter format succeeded, analyze failed solely on shared_study_recorder_fixtures
line267: multiline if without braces. Full Flutter/provider/widget/browser/Web
steps skipped, not passing. No source change justified outside this correction.

Wrap both existing fixture cleanup if bodies in explicit blocks; completion calls,
every case/checkStudy assertion and all production/provider/widget sources remain
unchanged. No lint suppression, test removal, timeout/CI/security/config change.
Exact diff/count review, pinned format0changes/pure targeted analyze no issues,
retained27-scenario native verifier plus actual abrupt child/lease/reopen, QA17/
inventory49 and whitespace passed after correction. Full new-head Flutter/provider/
browser/Web/Windows require exact-head CI. Prior local Flutter metadata-endpoint
approval rejection remains; no retry/workaround/full local Flutter claim.

Next read actual corrected #41 head/latest-attempt complete required jobs/steps,
fix any actual failure preserving assertions, then wire reader start/finish/retry
and real profile-level content guards into the same shared provider. Only pending
CI means save/release without duplicate code/long polling. Keep #11/#12 open/#41
draft/default preview/all14 hosted groups pending. Main/source/Pro/content/deps/
Auth/schema/RLS/CI/security/provider/spend/merge/deployment/schedule unchanged.
See docs/SHARED_STUDY_RECORDER.md and current #41 handoff.


## Configured reader elapsed sessions — core-20261020T0800-reader-study-ui

Resumed #41 e674e60b3bf388b3ccd8d9899fe1e993588807c3. CI39376257044 latest attempt
verified allfive jobs/every required step success:506 Flutter/five Chrome plus
SDK/native/process/SQL/Web/Windows, explicitly including shared-provider frozen
failed-stage regression. Main/source drafts/Pro canonical content unchanged.

Configured vocabulary/grammar now share the existing one recorder and common
area-aware panel with SRS. Real settled nonempty original content and matching
profile level gate starts before/after pending-before-plan preflight; matching
server blocks must be available. Retained AsyncData during refresh is rejected.
Explicit date/today-fill/start/finish/retry, original frozen area/date/UTC interval,
scoped source/search/level/route/background cancellation and retained hidden/
cleared/unfocusable date fields preserve owned exit/drain and exact uncertain
retry. Public browsing never records time. SRS keys/readiness/last-card behavior
remain; immutable pendingEvent is display-only. No extra recorder/Auth/SDK/store
owner, API/schema/RLS/content/dependency/CI/security/provider/spend change.

Seventeen reader widget cases authored, including failed-stage grammar retry from
vocabulary after SRS navigation, ambiguous commit, retained-data refresh, late
preflight/logout,320px/200-percent confirmed reload failure and actual owned-host
exit retention. Original fixture exports are used; hosted Auth/RPC/clock/storage
are TEST ONLY. Prior SRS/reader/owned assertions retained. Strengthened native
frozen-slot projection assertions; pinned direct Dart format/pure targeted analyze,
all27 native scenarios plus actual abrupt child/lease/reopen,QA17/inventory49 and
whitespace passed. New full Flutter/widget/provider/SDK/platform execution needs
exact-head CI. Prior local Flutter metadata review rejection is not bypassed.

Next inspect the published exact #41 head/latest-attempt complete required jobs/
steps; fix actual failures without weakening assertions. Only pending CI means
persist/release and handoff, no duplicate work or long polling. After green,
continue remaining actual activity flows and outstanding hosted/browser gates.
Keep #41 draft/#11/#12 open/default preview/all14 hosted groups pending; no
main/source draft change, merge, deployment, release or schedule action.
See CURRICULUM_STUDY_TIMER.md and current #41 handoff.


## Reader timer test correction — core-20261020T0825-reader-test-fix

Resumed #41 e1915c04d8b9fdd19d9d049ff370661577578d1d. Actual CI39392930477
Flutter format/analyze passed; full suite520 passed/3 failed. All14 other new
reader cases passed, including exact frozen cross-route retry, lifecycle/late
preflight/logout,320px/200-percent reload failure and actual bundled owned exit.
Repo-sanity/database/AI completed successfully; Windows still running at review.
Downstream Flutter/browser/Web skipped, never counted as success.

Two configured save tests incorrectly compared DailyPlanDate object identity;
assert exact event.date.value instead. All original ack/area/61-second interval/
ID/dispatch/plan-read/no-queue checks retained. Refresh already observed loading,
readiness false and canceled notifier, but panel's async-state frame had not
rendered. Pump one frame with reload still held, retain disabled-start check
and additionally assert its presence/no elapsed/no frozen report. All17 cases/
prior assertions remain; no product/model/provider/runtime/data/Auth/security/
CI/lint/timeout/dependency/schema/RLS/Pro/main/source branch change.

Separate bounded diff/assertion review, pinned Dart format1/0changes,QA17/
inventory49 and whitespace passed locally. No full local Flutter run; prior
metadata-endpoint automatic-review rejection remains, no retry/bypass. Native
production unchanged, so no redundant native rerun or new native pass claimed.
Full corrected-head Flutter/widgets/builds require Actions.

Next inspect published exact #41 head/latest-attempt complete required jobs/
steps and fix any actual remaining failure preserving assertions. Pending-only
means persist/release/handoff without duplicate changes/long polling. After
green continue remaining activity and hosted/browser gates. Keep #11/#12 open/
#41 draft/default preview/all14 hosted groups pending; no merge/deployment/
release/Auth strategy/security/provider/spend/schedule change. Details in
docs/CURRICULUM_STUDY_TIMER.md and the current PR handoff.


## Original Kanji catalog and selected capture — core-20261020T1024-kanji-reader

Resumed #41 613024bf08027ebb2d178dc4f731df1f69516f94. Actual CI39393662381 latest
attempt verified allfive jobs/every required step success. Completed Flutter logs
confirm523 tests/five Chrome and all17 reader timer cases; Web/Windows/native/
SDK/SQL/process gates passed. Prior reader test corrections now verified, hosted
learner evidence still absent. Main/source drafts/Pro canonical exports unchanged.

Bounded #16 integration prerequisite: public typed Kanji catalog now packages
exact original8 N5/95 N4 metadata, preserving IDs/versions/readings/meaning/count.
Free /kanji capture retained; new catalog/search/level and explicit original-ID/
level practice routes reuse the same canvas implementation in an isolated local
controller per character/version. Unsupported/wrong-level/unknown IDs never
fallback. Search/filter/retry/empty/redacted errors and held reload/late-level
results are safe. Drawing or metadata counts never grade/credit/save; no vetted
reference geometry, synthetic real score, timer/learning endpoint or new resource
owner. Same-level catalog return and correct navigation remain; owned exit keeps
search EditableText mounted beneath its blocker.

Eighteen repository/codec and12 widget cases authored using original exports and
TEST ONLY ports, including direct identity/source reset,320px/200-percent capture
and actual bundled owned-host search/exit retention. All prior tests/assertions
unchanged. Local pinned format/pure-domain analyze, exact103-record/asset smoke,
malformed/bounds/duplicate/local Japanese+Vietnamese search/immutability smoke,
QA17/inventory49, whitespace and separate source/composition review passed. Full
new Flutter/widget/platform verification requires exact-head Actions; prior
metadata-endpoint automatic-review rejection not retried/bypassed. No new full
local Flutter/native/hosted grading pass claimed.

Next inspect published exact #41 head/latest-attempt every required job/step and
fix actual failures preserving assertions. Pending-only means persist/release
without duplicate changes or long polling. After green continue vetted Kanji
reference import/evaluation or remaining actual activity/hosted/browser work.
Keep #41 draft/#16 open/default preview/all14 hosted gates pending; no canonical
content/Pro/source/main/API/Auth strategy/SDK/storage/schema/RLS/dependency/CI/
security/provider/spend/merge/deployment/release/schedule change. Two asset-only
pubspec declarations added. Details: docs/KANJI_CATALOG.md and current handoff.


## Kanji malformed-fixture typing — core-20261020T1039-kanji-test-type

Resumed #41 ba7b06f158a1c15af244b41693e083f829cb98a6. Actual CI39408920908
repo-sanity/database/AI success; Flutter format passed, analyze failed only on
Kanji repository test line123 uninferred empty Map. Full tests/Chrome/downstream
Web skipped, not passing. Windows still running after configured staging success.

Change only the malformed empty-map fixture to explicit Map<String,Object?>; its
JSON remains [{}]. All18 repository/12 widget cases and original assertions,
production, canonical/Pro content, routes/ownership and CI/lint/security untouched.
Local pinned format, pure-domain analyze,QA17/inventory49,whitespace and separate
exact diff/encoded-fixture parity review passed. Full corrected Flutter/widget/
platform execution needs exact-head Actions. No prior metadata automatic-review
rejection retry/bypass or local full Flutter pass claimed.

Next inspect published actual head/latest-attempt every required job/step and fix
actual failures retaining assertions. Only CI pending means persist/release and
handoff without duplicate implementation/documentation-only source commit or
long polling. Keep #41 draft/#16 open/default preview/all14 hosted gates pending;
no production/main/source/Pro/API/Auth strategy/schema/RLS/dependency/CI/security/
provider/spend/merge/deployment/release/schedule change. See KANJI_CATALOG.md.


## Kanji search finder scope — core-20261020T1044-kanji-search-finder

Resumed #41 a041fc9a68a697561887accf45e6ca656346f8e1. Actual CI39409601599
format/analyze passed;552 tests passed/one failed. All18 Kanji repository/11 other
new Kanji widgets passed, including real original both levels, local capture
isolation/refresh,320px/200-percent and actual bundled owned exit. Database/
repo/AI succeeded, Windows running at review; downstream Flutter/browser/Web
skipped, never passed.

The global text finder for 日 matched both the search input's EditableText and
result Text. Scope the glyph expectation to the canonical-ID ListTile; assert
exactly one such result and the unchanged query, retain count/query/clear/level
checks and all30 cases. Only test+two docs change, all production/content/source/
Pro/Auth/SDK/ownership/security/lint/CI/dependency/schema/RLS unchanged.

Pinned local format,QA17/inventory49,whitespace and separate bounded diff/assertion
review passed. Corrected full Flutter/widget/build needs exact-head Actions; no
local metadata automatic-review retry/bypass or full local Flutter claim. Next
inspect complete actual head/latest-attempt all required jobs/steps and fix actual
failures preserving assertions before new work. Pending-only means persist/
release/handoff without duplicate source or long polling. Keep #41 draft/#16 open/
default preview/all14 hosted gates pending; no merge/deployment/release/provider/
spend/schedule change. See KANJI_CATALOG.md and current PR handoff.


## Eight-seed N5 stroke guide — core-20261020T1052-n5-stroke-guide

Resumed #41 cf00d0817721a5147fd28aba765ac780021fcbed; CI39410222982 verified
allfive jobs/every required step. Completed logs553 Flutter/five Chrome, all30
Kanji catalog cases and retained SQL/SDK/native/process/Web/Windows. Prior scoped
search finder now verified. Main/source/Pro canonical records unchanged.

Bounded #16 reference increment imports eight unchanged pinned KanjiVG N5 SVGs
with original notices/COPYING, source/metadata SHA locks, versioned manifest and
CC BY-SA attribution/modification notices in repo/generated asset/UI. Reproducible
stdlib importer validates109 canvas/glyph/ordered IDs/count/no transforms, accepts
only observed M/C/c/S/s commands, adaptively flattens bounded curves, preserves
placement/order/direction and normalizes without fitting/clamping. Optional
explicit Xem nét mẫu offers step prefixes/highlight/start dots/end arrows/full
view in selected practice. Free drawing unchanged; N4 references absent. Unknown
or mismatched ID/glyph/version/count cannot fallback; safe error/retry/late-route/
hide behavior. No synthetic/real grade, attempt storage, timer or study credit;
canonical stroke_data_ref and server availability unchanged.

Eight Python importer tests passed (25 total QA), deterministic --check, actual
Dart eight-guide projection smoke, pure-domain analysis, pinned format/whitespace
and visual actual-glyph contact sheet review passed. Ten codec/repository/six
widget cases authored, including actual bundle, N4 zero reads, mismatch rejection,
explicit step/attribution/no grade, safe missing/retry/late result,320px/200-
percent controls and retained expanded attribution EditableText through owned exit. All prior tests/assertions unchanged. Full new Flutter/widgets/
SDK/platform needs exact-head Actions; prior metadata automatic-review rejection
not retried/bypassed. No independent pedagogical quality or real grading claim.

Next inspect published exact #41 head/latest-attempt every required job/step and
fix actual failures preserving assertions. Pending-only means persist/release/
handoff without duplicate source/docs-only commit or long polling. After green,
continue reference coverage and reviewed real evaluation/remaining activities.
Keep #41 draft/#16 open/default preview/all14 hosted groups pending. No canonical
content/Pro/source/main/API/Auth/SDK/storage/dependency/schema/RLS/CI/security/
provider/spend/merge/deployment/release/schedule change; one asset-only pubspec
declaration. See N5_STROKE_GUIDE.md and current PR handoff.

Reference source/metadata/output checkout bytes are preserved for cross-platform
digest checks; importer text I/O uses explicit UTF-8 and LF.

The upstream COPYING file is preserved byte-for-byte, including its blank EOF
line. Full whitespace review reports that one upstream-only notice; authored-file
whitespace check passes. Its exact license digest is also locked by the importer.


## Windows fixture publication — core-20261020T1111-exit-marker-publication

Resumed #41 `72e984a8b24cde8e11ccff1babb927561dcf2296`. Exact CI39412500938,
latest attempt, completed repo-sanity/ai-boundary/database/Flutter with every step
successful. Completed Flutter logs show569 tests including all16 new N5 guide
cases, five actual Chrome tests, retained SDK/native/process/SQL and Web artifact.
Windows bridge build and app-data/Dart-native/persistent-runtime probes passed;
actual exit fixture then failed `Windows exit marker invalid`. Later Windows
configured/normal builds and artifacts were skipped, never passed.

Inspection identifies final-name visibility before asynchronous write completion
as a publication race, consistent with the historical intermittent marker failure;
the failed log itself does not capture a partial payload. TEST ONLY Dart markers
now stage, flush, close and validate before same-directory rename. PowerShell
release likewise stages before move, and Dart verifies its exact payload. Existing
strict reader/deadlines/process-alive/real close/cancel/explicit retry/owned drain/
lease reopen/natural exit checks remain. No weakening or corrupt-data retry.

Four real disposable-file regressions passed direct pinned Dart execution: held
empty stage remains unpublished, repeated partial stage preserves prior final,
invalid payload rejected/cleaned and failed write propagated/cleaned. Pure helper/
fixture analysis and pinned format passed. All four are included in ordinary
Flutter discovery. QA inventory49 and25 Python regressions, whitespace and a
separate bounded diff/assertion review passed. PowerShell is unavailable locally;
full updated Flutter and actual Windows runner checks require exact-head Actions.
No local Flutter metadata rejection retry/bypass or full local Flutter claim.

Next inspect published exact head/latest-attempt all required jobs/steps, fix
actual failures retaining assertions. Pending-only means persist/release/handoff,
no duplicate source/docs-only commit or long polling. Only after complete green,
continue the previously checked95-character N4 reference increment. No N4 guide
asset installed in this fix. Keep #41 draft/#16/#20/#22 open/default preview/all14
hosted groups pending. No app/Auth/SDK/vault/journal/content/Pro/main/source/API/
provider/dependency/schema/RLS/CI/security/timeout/spend/merge/deployment/release/
schedule change. See ACCOUNT_STARTUP.md and current PR handoff.


## Original95 N4 stroke guides — core-20261020T1124-n4-stroke-guides

Resumed #41 060187ee9aa2e78c3640d0faf69a001e2978f1b3 after CI39413895560,
latest attempt, verified allfive jobs/every required step successful. Completed
logs573 Flutter/five actual Chrome, all four marker regressions, actual Windows
cancelable close/owned drain and configured/normal builds/artifacts; retained
SDK/native/process/SQL/Web gates. The Windows publication fix is now verified.

Bounded #16 increment adds95 unchanged original nonvariant KanjiVG N4 sources,
separate hash-locked manifest/version and deterministic generated asset from the
same pinned70a0b7ae source. Closed per-level importer configuration fixes paths/
coverage8/95/version/provenance and preserves all original N5 output/manifest,
upstream license and both canonical metadata files byte-for-byte. N4 has977
ordered strokes/7782 normalized points; no unsupported parser commands added.

Expected-level Flutter decoder rejects foreign version/coverage/provenance;
repository uses fixed separate assets and model/panel require exact level/ID/
glyph/content-version/count. Selected N4 now offers explicit Xem nét mẫu with
existing step/start/end/attribution controls and independent drawing. N5 behavior,
missing/redacted retry/late selection/owned exit retained. No real evaluation,
attempt save, score, recorder, timer credit or canonical stroke_data_ref change.

Four new Python N4 cases passed (29 total QA), both-level deterministic --check,
actual103-guide direct pinned Dart smoke, pure-domain analysis/format/inventory49/
whitespace and separate bounded diff/source review passed. Four intermediate
sheets of all95 normalized glyphs were visually reviewed; not independent teacher
quality or calibrated scoring. Expanded24 Flutter guide cases authored, including
all95 N4 mappings/fixed path/cross-level rejection, explicit N4 steps/drawing,
foreign result/late cross-level route and both-level missing/retry/narrow/actual
bundled expanded-attribution owned exit. Original N5 assertions retained; obsolete
N4 unavailable cases replaced with strict level-specific loading/identity checks.
Full new Flutter/widget/platform execution needs exact-head Actions; no local
Flutter metadata automatic-review rejection retry/bypass/full local Flutter claim.

Next inspect published exact head/latest-attempt all required jobs/steps and fix
actual failures preserving assertions. Pending-only means persist/release/handoff,
no duplicate source/docs-only commit or long polling. After complete green,
continue reviewed real evaluation/remaining learning activities and hosted gates.
Keep #41 draft/#16 open/default preview/all14 hosted groups pending. No main/
source/Pro/canonical content/Auth strategy/SDK/storage/schema/RLS/dependency/CI/
security/provider/spend/merge/deployment/release/schedule change. One asset-only
pubspec declaration. See N5_STROKE_GUIDE.md and current PR handoff.


## Optional Kanji tracing underlay — core-20261020T1213-kanji-tracing

Resumed exact #41 4497cba23d86caba9739197ca400cf58be31dc65. CI39415591962,
latest attempt, completed allfive jobs/every step successfully; completed logs581
Flutter/five actual Chrome plus retained SQL/SDK/native/process/Web/Windows
builds/artifacts. All24 N5/N4 guide cases passed. N4 coverage increment verified.

Bounded #16 UI increment adds explicit Hiện nét mẫu trong ô viết after a guide
is shown. Validated immutable original prefix paints faintly under the unchanged
learner capture painter; current stroke/start emphasized and guide step/full
controls stay aligned. No reference point becomes learner ink. Toggling/hiding
preserves ink; undo/clear preserves reference selection. Local trace is removed
on selected identity/level/version/source replacement, guide refresh/loading/
error/foreign result; same-instance refresh still requires explicit re-enable.
No implicit load/free-canvas trace. Existing attribution/owned host retained.

Local pure-domain analyze, pinned format,29 Python QA/inventory49, deterministic
both-level import, whitespace and separate bounded diff/lifecycle review passed.
Direct pinned Dart smoke checked all103 actual guides/1005 ordered prefix bounds,
immutable identical source strokes/invalid indices and untouched learner capture.
Six new guide cases authored (30 total), covering both-level trace/capture/controls,
identical-instance refresh and route/level/free isolation; retained narrow/actual
bundled owned-exit tests additionally trace while preserving all previous checks.
Full new Flutter/widgets/render/platform needs exact-head Actions. No retry/
bypass of prior local Flutter metadata automatic-review rejection or local full
Flutter claim. No independent pedagogical/calibrated handwriting-grade claim.

Next inspect published exact head/latest-attempt every required job/step and fix
actual failures retaining assertions. Pending-only means persist/release/handoff,
no duplicate source/docs-only commit or long polling. After complete green,
continue reviewed real feedback/evaluation or next unblocked learning activity.
Keep #41 draft/#16 open/default preview/all14 hosted groups pending. No geometry/
source/manifest/license/canonical content/Pro/main/source branch/API/Auth strategy/
SDK/storage/recorder/progress/credit/dependency/schema/RLS/CI/security/provider/
spend/merge/deployment/release/schedule change. See N5_STROKE_GUIDE.md.


## Trace refresh fixture and narrow toggle — core-20261020T1225-trace-refresh-layout

Resumed #41 ecac51d2a136a50a47f338e8ad0935490f8dda3f. CI39421796252 latest
attempt repo/database/AI passed, Flutter format/analyze passed;583 tests passed/
four failed. Both N5/N4 tracing/capture controls, cross-level/free isolation and
actual bundled expanded tracing/attribution owned exit passed. Both first-frame
refresh cases and320px/200-percent trace-toggle hit tests failed. Downstream
Flutter/Chrome/Web skipped, never passed. Windows bridge/actual close passed;
configured staging build in progress at diagnosis, later checks not yet claimed.

Refresh fixture now explicitly refreshes provider and asserts observed loading/
exact second loader call before checking the painted frame. Riverpod2.6.1's
invalidate schedules recomputation and does not guarantee that first-pump state;
see versioned API references in N5_STROKE_GUIDE.md. All original no-trace/retained-
ink/same-instance-disabled/manual-re-enable assertions retained and strengthened.
This is an inferred fixture scheduling cause; production trace lifecycle unchanged.

Replace tall adaptive switch tile with full-width outlined toggle button and
separate explanatory text, retaining explicit on/off semantics and visible labels.
Strict hitTestable assertions,320px/200-percent configuration/square/step checks,
all30 guide cases and original assertions retained. No ignored tap/finder warning,
font-scale reduction, removed scenario or semantic weakening.

Local pinned format2/0changes,29 Python QA/inventory49, whitespace and separate
bounded source/assertion review passed. Corrected full Flutter/render/platform
needs exact-head Actions; no local full Flutter claim or retry/bypass of prior
metadata automatic-review rejection. No next-feature source work while this
correction is unverified. Read-only queue check found #13 owns quiz/mastery and
requires reviewed scoring rules before coding; /quiz remains a placeholder.

Next inspect published exact head/latest-attempt every required job/step and fix
actual failures preserving assertions. Pending-only means persist/release/handoff,
no duplicate source/docs-only commit or long polling. After complete green, review
#13 scoring/answer/dedup rules for a bounded real curriculum quiz before replacing
its placeholder; no inferred mastery or server credit. Keep #41 draft/#16 open/
all14 hosted groups pending. No source/geometry/manifest/canonical/Pro/main/source
branch/capture/Auth/SDK/storage/dependency/schema/RLS/CI/security/provider/spend/
merge/deployment/release/schedule change. See N5_STROKE_GUIDE.md and PR handoff.


## Public reading-choice quiz — core-20261020T1755-vocabulary-quiz

Resumed exact #41 0c7644ebe9432626b4aa085852af55e662510200. CI39422900350,
latest attempt, completed allfive/every required step; completed Flutter logs587
tests/five actual Chrome. Both trace refresh/320px200-percent fixes passed; all
retained SQL/SDK/native/process/Web/Windows builds/artifacts passed.

Reviewed bounded #13 scoring/identity/mastery boundary recorded before code.
Replace only /quiz placeholder with deterministic original-vocabulary reading
choices at selected N5/N4. Same-level canonical objects/versions, unique prompt/
reading rules, rotating answer slots, max10 question round, first-answer wins,
stale next/answer/batch no-op, explicit result/wrong-word review/restart/next batch.
No attempt storage, mastery, progress dashboard, recorder/timer/server credit.
Source refresh/level/route discards local panel; late old callbacks fenced.
Loading/redacted manual retry/insufficient/narrow states and owned host retained.

Original source inventory via JavaScript:24 N5 eligible prompts/24 rows;364 N4
Kanji prompts/366 rows,362 distinct N4 readings. This is not Dart test execution
or independent linguistic approval; no content or Pro changes.

Authored domain/widget regressions cover actual canonical both levels, immutable/
deterministic choices, duplicate prompt/reading/answer, source/kind/level/version/
bounds rejection, empty/short pools, wrong answers/local reset and stale next.
UI includes correct/incorrect/result/restart/next batch dedup, level/late source/
refresh/disposed action/route isolation, safe error/retry/insufficient, both-level
320px/200-percent strict interaction and actual bundled awaited owned exit.
QA inventory adds baseline case50, existing14 hosted groups remain pending.
No original test/assertion removed; /quiz no longer iterates the unavailable
placeholder loop and now has dedicated functional route tests.

Execution environment unavailable. No new local format/analyze/Dart/Flutter/
Python QA/Chrome/render/build executed. Pinned-source/full-base-tree review and
separate rule/callback/bounds review completed through GitHub; existing Actions
must verify published exact head. No retry/bypass of prior metadata rejection.
Next inspect exact-head/latest-attempt all required jobs/steps, fix actual failures
preserving assertions. Pending-only means save/release/handoff, no duplicate
source/docs-only commit or long polling. After green, continue reviewed owned quiz
events/mastery/progress boundaries or next unblocked learning activity.
Keep #41 draft/#13 open/default preview/all14 hosted groups pending; no main/
source/Pro/canonical/Auth/API/storage/dependency/schema/RLS/CI/security/provider/
spend/merge/deployment/release/schedule change. See VOCABULARY_QUIZ.md.


## Quiz formatting correction — core-20261020T1816-quiz-format

Resumed exact #41 1a3d0ae8ea7b370565d7d8996e507e8a1dd4488d. CI39472889990,
latest attempt1, completed repo-sanity/database/ai-boundary/windows with every
required step successful. Windows configured staging and preview release builds,
native process/close checks and artifact upload passed. Flutter job118801709143
failed dart format: vocabulary_quiz.dart, vocabulary_quiz_screen.dart and
vocabulary_quiz_widget_test.dart changed. Analyze/full tests/Chrome/Web and other
downstream Flutter checks were skipped; no quiz test success is claimed.

Correct member spacing and collapse fitting Text/function invocations; remove
the extra trailing blank line in the widget test. Only whitespace and optional
trailing commas change in these three Dart files. Separate pinned-source review
confirmed every string literal and non-whitespace/non-comma character sequence
unchanged, including test assertions. No quiz behavior, scoring, source data,
test case, assertion, formatter setting, dependency or workflow change.

Execution environment remains unavailable. These edits were reviewed manually
against the formatter's member-spacing fixture, not executed by a local formatter.
Existing exact-head Actions must verify formatting, analysis, full tests and
platform builds. No retry/bypass of prior Flutter metadata review rejection.
Persist a complete base tree, verify original paths/modes/SHAs and read back each
changed blob before advancing the branch. Next inspect exact-head/latest-attempt
required jobs and steps; fix actual failures. Pending-only means release/handoff
without duplicate source/docs-only commits or long polling.
Keep #41 draft/#13 open/default preview/all14 hosted groups pending; no main/
source/Pro/canonical/Auth/API/storage/schema/RLS/security/provider/spend/merge/
deployment/release/schedule change. See VOCABULARY_QUIZ.md and PR handoff.


## SDK profile readiness fixture — core-20261020T1825-sdk-readiness-fixture

Resumed exact #41 ccd006e3a5295570bad39c56a007407027da027d.
CI39474040443 attempt1 passed Flutter formatting and analysis. Completed Flutter
logs show604 passed/one failed; all19 new vocabulary quiz tests passed (8 domain,
11 widget, including both levels,320px/200-percent interaction and owned exit).
The one failure is the existing pinned-SDK login/explicit-rotation/logout
readiness test at line185: saved secret matched, readyRuntime was still null.
Downstream native/Chrome/Web checks were skipped, never passed. Repo/database/AI
completed all required steps; Windows still in progress at initial observation.

Source review: PersistentSupabaseRuntime.refresh delegates to persistence.refresh,
whose completion drains credential writes. AccountController separately launches
unawaited profile loading after the session change; only a ready profile publishes
the study runtime. A fixed eight zero-delay fixture flushes do not represent that
profile completion. The observed scheduling cause is inferred from source and the
failing assertion, not a captured production trace.

In this single existing test, replace fixed post-login/post-rotation flushing
with the existing waitForReady helper. It observes actual account state, has a
five-second bound, fails on error/unavailable phases and requires nonnull runtime.
Assert the rotated vault secret immediately after rotation completion, before
waiting for profile readiness. Every original assertion is retained in order,
including immediate revocation, readiness withheld while vault write is held,
exact saved secret, eventual ready runtime and logout clear/signed-out state.
No increased timeout, retry, added sleep, production change or weakened assertion.
Other fixtures/tests and all CI/security/lint gates are unchanged.

No local Dart/Flutter/format/analyze/Python/render/build execution is available.
Do not retry/bypass prior Flutter metadata review rejection. Full-tree/pinned
source review is not executable testing; existing exact-head Actions must verify
this correction. Next inspect latest-attempt allfive jobs/every required step,
fix actual failures preserving assertions. Pending-only means release/handoff
without duplicate source/docs-only commits or long polling. Keep #41 draft,
#13 open/default preview/all14 hosted acceptance groups pending.


## Quiz attempt snapshots and error history — core-20261020T1834-quiz-history-model

Resumed exact #41 cd9e4450035051e439884badb6918a6d2746ff93, complete479-file
treeba377dd82e73ac49e99816bc3357706a7aecf392. CI39474839847 attempt1 allfive/
every required step passed. Completed logs605 Flutter/five Chrome; all19 quiz
cases and SDK readiness correction passed, plus retained SQL/native/process/
Web/Windows builds/artifacts. Previous pending/failure observations are historical.

#13 bounded attempt/owner/replay/error rules recorded/reviewed before coding.
Add immutable completed-round attempt snapshots, strict separate local-v1 JSON,
owner envelope and pure deterministic history projection. One read-only copied
answer-map getter is the only existing production change; current /quiz behavior
and original tests unchanged. No route save/history success or mastery claim.

Only fully advanced nonempty one-level rounds are captured. Canonical IDs/versions/
four displayed choice IDs/first selection are copied; derive score, never accept a
caller-supplied score or correctness. Exact schema/types/bounds/UTC round-trip
reject unknown/normalized input. Separate owner envelope is data, not Auth:
future repository must capture its owner from a ready session.

Reject foreign owner before dedup/level filter; identical event replay counts
once and changed payload conflicts before counters. Bound history10000. Stable
UTC/event-ID order; historical totals retain old source reports, while current
practice/review must resolve original generated questions with matching version
and exact choice order. Latest wrong proposes that item for review; later correct
clears it while preserving error counts; rank by errors/time/canonical ID.
No MASTERED, mastery threshold, study timer, plan/SRS/profile or server credit.

Sixteen new tests authored against both actual canonical levels and malformed/
owner/replay/conflict/time/ranking/wrong-correct/stale-source/immutable edge cases.
QA51 adds one baseline; all14 hosted groups and existing gates/findings unchanged.
Pure JavaScript canonical inventory confirms all24/366 source IDs match UUID
requirements; not Dart execution or linguistic acceptance.

Execution environment unavailable. No new local Dart/Flutter/format/analyze/
Python QA/browser/render/build; no previous Flutter metadata-review bypass.
Separate source/test/rule/scope review and full-tree/blob checks accompany the
published head; existing exact-head Actions must verify implementation.
Next inspect exact-head/latest-attempt allfive jobs/every required step and fix
actual failures preserving assertions. Pending-only means release/handoff without
duplicate source/docs-only commits or long polling. After full green implement
owner-scoped durable append/restart/corruption/replay behavior, then captured-ready-
session repository and explicit save/history UI; no fabricated default success.
Keep #41 draft/#13 open/default preview/all14 hosted groups pending; no main/source/
Pro/canonical/Auth strategy/API/storage activation/schema/RLS/dependency/CI/security/
provider/spend/merge/deployment/release/schedule change. See QUIZ_ATTEMPTS.md.


## Pinned formatter diagnostics — core-20261021-history-test-format

Actual a9c14f22 CI39477153830 attempt1 passed database/repo-sanity/AI/Windows,
every required step. Flutter formatter reports only vocabulary_quiz_history_test;
analysis/new16 tests/Chrome/Web skipped. No model test pass is claimed.

The execution environment is unavailable and formatter --output=none names files
without a diff. Add diagnostics to the existing pinned-SDK format gate, retaining
its exact step name, SDK3.35.4, original strict check and failure outcome. A clean
check exits0; after failure, the disposable runner formats and prints git diff,
then returns nonzero even if later commands would succeed. There is no auto-push,
continue-on-error, artifact/secret change or relaxed formatter/analyzer/test gate.
All other workflow bytes and original test/model source remain unchanged.

This is a scoped observability change reviewed in #13 before the workflow edit;
the earlier no-CI-change handoff applied to that model increment. No local
execution or prior Flutter metadata review rejection retry/bypass. New CI is
expected to expose the exact formatter-produced test diff while still failing.
Read that diff, apply it without changing cases/assertions, then verify a new head.
Do not begin durable-store implementation until the models are verified.
Keep #41 draft/#13 open/default preview/all14 hosted groups pending.


## Exact SDK history-test format correction — core-20261021-history-test-format

The diagnostic increment fef1e081 CI39478685828 attempt1 reached the unchanged
strict formatter gate and failed as required. Its log supplied exactly three
hunks for vocabulary_quiz_history_test.dart: two multiline map/list displays and
one collection argument layout. No other Dart file changed.

Apply those three observed hunks exactly, without a hand-invented formatting
change. Independent UTF-8 Git blob SHA1 (self-checked against SHA1("abc") and the
original GitHub blob) yields ebaa415b7a9905d7abcecf11fa249adf9dc76ccc, matching
the formatter diff's target prefix ebaa415. Every string literal and all
non-whitespace/non-comma text remain identical; all16 test cases/assertions and
production model/quiz behavior are retained. The successful diagnostic failure
proves the added logging did not silently accept unformatted code.

At observation diagnostic CI repo/database/AI passed, Windows bridge build in
progress, Flutter format failed; analysis/tests/Chrome/Web skipped. Exact a9c14f22
first model CI separately passed Windows/all other four jobs. Previous cd9e4450
allfive/605 Flutter/five Chrome remains historical source evidence, not history-
model execution. Local execution environment unavailable; no local SDK/format/
test/analysis/QA/render/build or prior metadata-review bypass.

Persist this source correction on the complete483-file base, read back each
changed blob and verify all paths/modes/SHAs before fast-forwarding. Existing
strict diagnostic gate remains installed; new exact-head CI must verify its
clean-success branch and full model/test/platform checks. Next inspect actual
latest-attempt allfive required jobs/every step and fix real failures retaining
assertions. Pending-only means release/handoff without duplicate commits or long
polling. Native quiz store/session repository/save-history UI remain pending
until these models are verified. Keep #41 draft/#13 open/default preview/all14
hosted groups pending. No native store activation/mastery/credit/main/source/
Pro/canonical/Auth strategy/API/schema/RLS/dependency/security/provider/spend/
merge/deployment/release/schedule change.

## Ready-state test barrier — core-20261021T2209-ready-test-barrier

Resume #41 at d6052eb6babc18970b6622974f1d15c6fd523ac1. Exact
CI39676720583 latest attempt1 completed repo/database/AI/Windows every required
step, including Windows configured/preview builds and retained native checks.
Flutter format and analyze passed; all three new owned-quiz SDK/disk tests passed.
Full Flutter result was656 passed/one failed, not a passing suite. Chrome and
downstream Flutter/Web steps were skipped.

The sole failure was the existing SDK rotation/logout real-disk recovery test:
readyRuntime was still null at line332 after a fixed fixture.flush. Auth refresh
completion does not prove asynchronous own-profile/runtime readiness. Replace
exactly three fixed flush waits in that one test (login/refresh/relogin) with its
existing waitForReady helper. The helper requires AccountPhase.ready within five
seconds, fails on terminal account errors, and asserts a nonnull runtime. All
original pending-request identity/disk/no-submit-RPC assertions remain unchanged;
no production logic, retry, sleeps, timeout increase, test skip or weakened gate.

Separate diagnostic/source/diff/assertion review and git diff --check verify the
bounded change. No local Dart/Flutter SDK; new executable checks require new
exact-head CI. Keep #41 draft/#13 open/default preview/all14 hosted gates pending.
Next inspect allfive latest-attempt jobs/every required step; after full green
continue captured-round save/history providers/UI. Pro/N4/main/source drafts,
API/schema/RLS/Auth strategy/dependencies/workflow/security/providers/spend/
merge/deployment/release/schedule unchanged.


## Strict history-fixture type annotations — core-20261021-history-analyzer

Resumed #41 exact1d963615f6459976e8e8de8cae6f4518b2fbd8b1, complete483-file
tree53e64964282dc99e1a6a9dbca3f9df6076ed7a11. CI39479261449 attempt1 completed
database/repo/AI/Windows with every required step successful. Flutter strict
formatter passed181 files/zero changes, verifying the exact formatter patch and
the clean-success branch of the diagnostic gate.

Analyzer emitted exactly two inference_failure_on_collection_literal warnings
in vocabulary_quiz_history_test.dart210:28 and236:30: the deliberately empty
answers/choices lists inside malformed-JSON fixtures need explicit element types.
Add Object? list annotations in only those two inputs. Their values remain empty;
every original case/assertion and rejection expectation is unchanged. Separate
diff review confirmed only those annotations, no production model/quiz behavior,
lint settings, exclusions, dependencies, workflow or security change.

The16 history tests/full Flutter/Chrome/Web and downstream checks were skipped
after analyzer failure, not passed. Existing cd9e4450 allfive/605 Flutter/five
Chrome evidence remains historical. New exact-head Actions must verify the
annotations, all16 cases and every retained required job/step. No local usable
execution environment or local format/analyze/test/Python QA/render/build claim;
no prior Flutter metadata review rejection retry/bypass.

User requested continued automatic work after the hourly-resume offer. Re-enabled
the existing cloud task6ace2a9c236c819189637e49f38182d7; tool confirmed enabled=true.
Only enabled state changed: existing hourly Asia/Saigon schedule/prompt preserved.
A current single-core ACTIVE marker was published before resumption. Follow the
existing overlap guard; do not promise continuous or quota-independent execution.

Next inspect actual new-head/latest-attempt allfive required jobs/every step,
fix real failures preserving assertions. Pending-only means release/handoff
without duplicate source/docs-only commits or long polling. After model full
green implement owner-scoped durable append/restart/corruption/replay handling,
then captured-ready-session save/history UI. Current route still saves no history.
Keep #41 draft/#13 open/default preview/QA51/all14 hosted groups pending. No main/
source/Pro/canonical/Auth strategy/API/storage activation/schema/RLS/dependency/
CI/security/provider/spend/merge/deployment/release change.


## Opt-in native quiz journal — core-20261021-quiz-native-store

Exact parent43094ac2 CI39480610637 attempt1 completed all five jobs/every required
step, with621 Flutter tests (all16 history cases), five Chrome, retained native/
process/SQL checks and Web/Windows builds/artifacts. No pending/skipped steps were
counted. The previous model fixture warnings are resolved and verified.

The separately reviewed #13 protocol is implemented as a new opt-in native store
interface/journal: canonical version1 owner/immutable-attempt envelopes, composite
owner/event replay, typed changed-payload conflict, serialized flushed append,
safe failure poisoning, lease/local guard, strict complete restore and incomplete
EOF repair,1 MiB/512-event bounds and shared close/drain. No existing production
file, app startup, public quiz route, credential or other journal is changed.

Thirteen new real-file Flutter cases cover immutable reopen, mixed owners/equal
IDs, concurrent duplicate/conflict, accepted-work drain, partial tail, complete
schema/canonical/duplicate-key corruption, capacity/no eviction, failed bootstrap/
ownership cleanup and actual child-process flush/restart/lease/replay. Synthetic
reports are not Auth proof. Injected write/flush fault coverage remains open;
its poisoning path is source-reviewed. Unchanged Flutter CI runs these on Linux;
new native-store Windows execution is not yet verified.

Execution environment unavailable: no local Dart/Flutter/format/analyze/test/
Python QA/build ran, and no prior metadata-review bypass. Separate source/test/
boundary review completed; new exact-head CI must verify formatting, analysis,
all new and retained tests and builds. See NATIVE_QUIZ_HISTORY.md/QUIZ_ATTEMPTS.md.

Next inspect actual new-head/latest-attempt all five jobs/every required step and
fix real failures retaining assertions; pending-only handoff without duplicate
commits/long polling. After store green, add captured-ready-session repository
and explicit save/history UI with old-session fences and safe manual retry.
Public /quiz still saves no history; no mastery/credit or issue completion.
Keep #13 open/#41 draft/default preview/QA51/all14 hosted groups pending.
No main/source/Pro/content/Auth strategy/API/schema/RLS/dependency/CI/security/
provider/spend/merge/deployment/release/schedule change.


## Exact native-quiz SDK formatting — core-20261021-quiz-store-format

Parent6a966917 CI39482718818 attempt1 passed repo-sanity/database/AI every required
step. Flutter stopped at the unchanged strict formatter:185 files/two changed,
native_vocabulary_quiz_journal.dart and its test. Analysis/new13 tests/Chrome/Web
were skipped and never passed. Windows configured build succeeded; standard
release/native checks were still running at the initial observation.

The existing pinned Dart diagnostic emitted exactly four hunks, applied with
checked original context/counts. Independent UTF-8 Git SHA1 verification matches
both SDK target blobs:26d53e667cc172c77dbe716031ea7892bfa8c828 and
694b727b3d65b90da747acf4079aaad62f1f6ccd. SHA routine self-tested on abc and both
original GitHub blobs. All non-whitespace/non-comma text, all13 test scenarios
and64 expect/expectLater calls are retained; no production behavior or gate
change. This is patch/source verification, not executable Dart testing.

No usable local execution environment, local format/analyze/test/QA/build or
prior automatic-review bypass. New exact-head CI must verify format/analyze,
all new and retained tests and Web/Windows builds. Existing43094ac2 all five/
621 Flutter/five Chrome evidence remains parent-model evidence only.

Next inspect actual new-head/latest-attempt all five jobs/every required step,
fix real failures preserving assertions; pending-only release without duplicate
commits/long polling. Then captured-ready-session save/history UI, after the store
is verified. Public /quiz still stores no history; no mastery or credit.
Keep #41 draft/#13 open/default preview/QA51/all14 hosted groups pending.
No CI/dependency/security/Auth/schema/API/main/source/Pro/content/merge/deployment/
release/schedule change.


## Native quiz test import correction — core-20261021-quiz-store-import

Exact13bb2821 CI39483670336 latest attempt1 passed repo-sanity/database/AI/Windows
every required step. Flutter strict formatter passed185 files/zero changes;
analysis reported only unnecessary_import for dart:async at native quiz journal
test1:8. flutter_test already exports all the async elements used by this test.
All new13 store tests/full Flutter/Chrome/Web downstream steps were skipped.

Remove exactly that first import line. Remaining test bytes, all13 scenarios
and64 expect/expectLater calls are identical; production store/model/UI and all
strict analysis/format/test/security gates unchanged. Separate source/diagnostic/
assertion review is not executable testing. Execution environment remains
unavailable; no local SDK/format/analyze/test/QA/build or prior review bypass.

New exact-head Actions must verify the corrected test and all retained gates.
Historical43094ac2 all five/621 Flutter/five Chrome remains model-parent evidence.
Next inspect actual latest-attempt all five required jobs/every step and fix real
failures preserving assertions; pending-only release without duplicate commits/
long polling. After store green implement captured-ready-session repository and
explicit save/history UI. Public /quiz still saves no history; no mastery/credit.
Keep #41 draft/#13 open/default preview/QA51/all14 hosted groups pending.
No production/API/schema/Auth/RLS/dependency/CI/security/main/source/Pro/content/
provider/spend/merge/deployment/release/schedule change.


## Captured quiz-history repository — core-20261021-quiz-session-repository

Exact parent78fbfae0 CI39484645098 attempt1 completed all five jobs/every required
step:634 Flutter/five Chrome, Web/Windows and retained SQL/native/process gates.
All13 real-file/process native quiz store tests passed on Linux. Native quiz
Windows execution and injected file-write/flush fault coverage remain open.

New bounded #13 library provides owner-derived save/load under an exact captured
ready session/runtime fence. It validates returned owner/full payload, coalesces
identical/reentrant saves, rejects conflicting replay/mixed-owner/oversized
history, returns copied immutable ordered records and redacts unknown errors.
Readiness/identity loss permanently revokes the wrapper before storage/after
every await, including failed results. Late old-owner writes can remain durable
but never publish to a new session. Revoke/drain waits for accepted operations.

PersistentSupabaseRuntime accepts optional quizStore (default null) and creates
the wrapper only after own profile/secure-secret readiness. It captures exact
ready-runtime/ready-session identity and drains quiz operations alongside existing
Auth/study close before caller storage release. No startup/host opens a new store;
no public /quiz save/history UI or server transport is installed.

Twenty new tests authored:15 repository/real-disk port-fault cases and five
actual pinned-SDK/simulated HTTP/vault/real-disk cases, covering duplicate/
reentrant dispatch, owner isolation, validation, redaction/retry, A/B/A, same-user/
readiness replacement, optional-null default, profile/rotation barriers and
queued/held shutdown. Existing source/test assertions and CI/security retained.
No usable local execution environment or local SDK/format/analyze/test/QA/build
claim; source/protocol/test review is not execution. No prior review bypass.

New exact-head Actions must verify formatting/analysis/new20 plus all existing
tests and required builds/checks. Next inspect actual latest-attempt all five
jobs/every step and fix failures without removing assertions; pending-only release
without duplicate commits/long polling. After green, add explicitly owned journal
opening/close forwarding and save/history providers/UI with same-round lifecycle
binding and manual immutable retry. Public route still loses results on exit.
Keep #13 open/#41 draft/default preview/QA51/all14 hosted groups pending.
No main/source/Pro/content/Auth strategy/API/schema/RLS/dependency/CI/security/
provider/spend/merge/deployment/release/schedule change.

## Quiz-session formatter correction — 2026-10-21 UTC

Run core-20261021T1909-quiz-session-format resumed draft #41 on
0a01b0f8915adf4c02969dcf6994a343e88aed96 after its stale ACTIVE marker exceeded 90 minutes.
CI39487075159 completed repo-sanity/database/ai-boundary/windows with every
required step successful. Flutter failed strict formatting in exactly the two
new history test files; analyze/new20 tests/Chrome/Web were skipped, not passed.

Applied only the two pinned-SDK diagnostic hunks in
apps/flutter_app/test/features/quiz/owned_quiz_history_sdk_test.dart and
apps/flutter_app/test/features/quiz/vocabulary_quiz_history_repository_test.dart.
All twenty scenarios, assertions and production logic remain unchanged. Separate
source review verifies equality after whitespace/comma removal; this is not local
Dart execution. New exact-head Actions must verify format/analyze/full tests and
retained builds/gates. Public quiz persistence/UI remains unconnected; keep #13
open/#41 draft/default preview/all14 hosted acceptance groups pending.

Next inspect all five latest-attempt jobs for the corrected head and fix actual
failures without weakening checks. When green, continue explicitly owned journal
opening and captured-round save/history UI. Pro/N4, API/schema/RLS, dependencies,
workflow, Auth strategy, deployment and schedule unchanged.

## Quiz-session async imports — 2026-10-21 UTC

Run core-20261021T2015-quiz-async-imports resumes #41 at bc5a11f1e5d08763656105ae528be7b357ef7825.
Exact CI39659479265 latest attempt1 passed strict Dart format and all required
repo-sanity/database/ai-boundary/windows steps. Analyzer reported sixteen
undefined Completer class/function errors in the two new quiz-history tests.
Full tests/new20, Chrome and downstream Flutter/Web steps were skipped.

Add explicit dart:async imports in owned_quiz_history_sdk_test.dart and
vocabulary_quiz_history_repository_test.dart; keep every remaining test byte,
all20 scenarios/101 expect or expectLater calls and production code unchanged.
Separate diff/import/assertion review and git diff --check verify this bounded
correction; no local Dart/Flutter SDK, executable test or build claim.
Fresh cloud clone matched current head/tree. New exact-head Actions is required
for analyze/full tests/builds. Keep #41 draft/#13 open/default preview/all14
hosted acceptance groups pending. Public quiz save/history UI is not connected.

Next inspect all five latest-attempt jobs/every required step, fix actual
failures while preserving assertions, then continue owned journal opening and
captured-round save/history UI after green. Pending-only handoff without duplicate
source/docs-only commits or long polling. Pro/N4, main/source drafts, API/schema/
RLS/Auth strategy, dependencies/workflow/security, deployment and schedule unchanged.

## Owned quiz journal — core-20261021T2107-owned-quiz-store

Resumed #41 at0e33052b9035533468205e1210600b6b87888bf9 after exact
CI39668904464 latest attempt1 passed all five jobs/every required step.
Logs prove654 Flutter tests including the new20 repository/SDK cases, five
Chrome, Web/Windows builds and retained checks. No hosted learner proof.

Configured Windows startup now opens the separate native quiz journal before
SDK/vault construction and transfers it to the existing Windows owner. It
unwinds acquired quiz/study/review handles on construction failure. Shutdown
awaits runtime operation drain before closing quiz/study/review journals;
failed runtime drain keeps stores leased. The startup/Windows wrappers forward
the optional captured-ready-history source and revoke access while closing.
Default preview and public quiz UI remain unchanged/unconnected.

Three added actual-SDK/simulated-HTTP/vault/real-file cases exercise source
forwarding and account readiness, close coalescing/held-write/all-three-lease
retention/reopen/recovery, and optional absent store/caller ownership. Source
review covers acquisition/failure/close ordering; injected native open/close
failures and hosted/native learner proof remain unverified. All existing tests,
contracts, gates and Pro/N4 content retained. No SDK locally; network attempt to
obtain Dart timed out, so new format/analyze/test/build evidence requires CI.

Next inspect new exact-head/latest-attempt allfive jobs/every required step,
fix failures retaining assertions, then implement captured-round save/history
providers/UI. Keep #41 draft/#13 open/default preview/all14 hosted gates pending.
No API/schema/RLS/Auth strategy/dependency/workflow/security/provider/spend/
merge/deployment/release/schedule change.

## Read-only quiz history — core-20261021T2309-quiz-history-view

Resumed #41 at09344fc5083ae50c362ae7262a93b970ef50275e. Exact
CI39684530931 attempt1 passed allfive jobs/every required step:657 Flutter,
five Chrome, Web/Windows and retained native/process/wire/SQL/security gates.

Added optional startup/source/provider forwarding under existing account/profile
readiness, /quiz/history and quiz navigation. Explicit read/reload shows saved
level/score/total/UTC completion only; safe loading/empty/redacted error states.
Keyed repository lifecycle removes old rows on account barriers; disposed loads
cannot publish late results. No new save, automatic retry, owner reassignment,
mastery/study/server credit or hosted transport. Default preview has no source.

Eight new widget scenarios authored for profile/preview gates, explicit empty
reads, held dispatch, safe errors/manual retry, late same/other-owner results,
actual startup source/exit revocation and narrow large-text layout. All existing
assertions retained. Separate source/lifecycle/diff review, whitespace and29
local Python QA tests passed. Dart/Flutter absent locally; new format/analyze/
widget/Chrome/build checks require exact-head Actions. Source/fixture checks are
not hosted learner evidence. Source files and full tree persisted on GitHub.

Next inspect allfive latest-attempt jobs/every required step, fix real failures
preserving assertions; after green implement explicit save bound to the entire
round's same ready lifecycle with immutable manual retry. Keep #41 draft/#13
open/default preview/all14 hosted gates pending. Pro/N4/main/source drafts,
API/schema/RLS/Auth strategy/dependencies/CI/security/providers/spend/merge/
deployment/release/schedule unchanged.

## History-view build correction — core-20261022T0011-history-build-fix

Resume #41 atc8fcf059066e74b730bb96c20bd408ac3725ae61. Exact
CI39691899499 latest attempt1 passed repo/database/AI every required step.
Flutter strict format reported two production-file hunks (provider wrapping and
history subtitle wrapping); analyze/eight new widget cases/downstream Web skipped.
Windows first compile failed on PreviewLevel.label missing extension scope, so
no current UI Windows build/native/artifact success is claimed.

Apply exactly the pinned-SDK formatter diff and add explicit
shared/models/preview_level.dart import to quiz_history_screen.dart, bringing
PreviewLevelLabel into scope without changing labels/level mapping. No behavior,
validation, source/session guard, test/assertion, UI content or CI/lint changes.
All eight new widget scenarios and all other tests remain byte-identical.
Separate diagnostic/import/source/diff review plus git diff --check passed.
Local Dart/Flutter SDK remains absent; new executable checks require new CI.

Next inspect allfive exact-head/latest-attempt jobs/every required step and fix
real failures preserving assertions. Pending-only handoff without duplicate
commits/long polling. After history view full green, implement explicit immutable
same-round/session save. Keep #41 draft/#13 open/default preview/all14 hosted
gates pending; Pro/N4/API/schema/RLS/Auth strategy/dependencies/workflow/security/
providers/spend/merge/deployment/release/schedule unchanged.

## Explicit quiz save — core-20261022T0112-quiz-save-ui

Resume #41 at66d32e97e617f3b726ad115dd09c4d29ea89b5fb. Exact
CI39698216596 attempt1 passed allfive jobs/every required step,665 Flutter,
five Chrome and Web/Windows. All eight history-view widget cases now passed.

Quiz rounds capture an optional ready repository at start; guest/old-session
rounds are never assigned to a later login. Captured-repository replacement
hides old answers/status and fences stale actions until an explicit new round.
Completed configured rounds capture one immutable UUIDv4/UTC local report.
Explicit save is single-flight, succeeds only after validated storage return,
and retries the exact original event on manual request after uncertain failure.
No raw errors/owner IDs, fabricated save, automatic retry, mastery/time/SRS/plan
or server credit. Default preview still has no Auth/history source.

Nine tests authored: secure UUID/UTC capture plus eight widget cases with
explicit Auth/profile/memory-storage/fixed-clock ports and original N5 content.
They cover save-to-history, stale/disabled duplicate, uncertain replay identity,
guest boundary, same/other-owner late results, mid-round same-user replacement,
capture failure and narrow large-text UI. Existing tests/assertions retained.
Separate lifecycle/replay/source/diff review and29 local Python QA tests passed;
Dart/Flutter SDK absent locally, new format/analyze/tests/builds require CI.
UI port evidence is not hosted learner or native fault proof.

Next inspect new exact-head/latest-attempt allfive jobs/every step and fix real
failures retaining assertions. Pending-only handoff without duplicate commits/
long polling. After save integration green, continue remaining #13 owned-event
progress/weak-point rules and acceptance; do not close #13 or merge draft until
its full criteria and hosted/release gates are satisfied. Pro/N4/main/source
drafts/API/schema/RLS/Auth strategy/dependencies/workflow/security/providers/
spend/merge/deployment/release/schedule unchanged.

## Quiz-save formatter correction — core-20261022T0214-save-test-format

Resume #41 at2343d755834e86662663666b04138ff60a4f78ba. Exact
CI39704833968 attempt1 completed repo/database/AI/Windows every required step,
including configured/preview Windows builds/native checks/artifacts. Flutter
strict format reported exactly one hunk in quiz_save_widget_test.dart around
its FutureProvider family override. Analyze/nine new tests/Chrome/Web/downstream
were skipped, not passed.

Apply the exact pinned-SDK diagnostic hunk only. Corrected test Git blob matches
diagnostic d8923b0 prefix; allnine scenarios/assertions and non-whitespace/comma
text retained, production behavior and CI/lint/security gates unchanged.
Separate diagnostic/source/assertion/diff review and git diff --check passed.
Dart/Flutter SDK absent locally; no new executable format/test/build claim.

Next inspect allfive corrected-head/latest-attempt jobs/every required step,
fix real failures retaining assertions; pending-only release without duplicate
commits/long polling. After save full green continue remaining #13 progress/
weak-point reviewed rules/acceptance. Keep #41 draft/#13 open/default preview/
all14 hosted gates pending. Pro/N4/main/source drafts/API/schema/RLS/Auth strategy/
dependencies/workflow/security/providers/spend/merge/deployment/release/schedule
unchanged.

## Quiz-save boundary diagnostics — core-20261022T0318

Resume #41 at64256e83a4c66124963be1c40694a7dc1eb1eac3. Exact
CI39710333451 attempt1 completed all five jobs: repo/database/AI/Windows passed
every required step, Flutter strict format/analyze passed but its full suite
reported666 passed/eight failures, all in the new save widget scenarios. Secure
factory unit case passed; Chrome/runtime/Web downstream were skipped, not passed.

All failing UI cases either never called the injected capture or could not find
the save button. Added explicit fixture preconditions for ready runtime/history
capability, exactly one rendered question, accepted correct answer and completed
result. Existing nine cases/45 assertions remain; no production/CI/security or
content changes. The extra provider read also initializes the capability before
navigation. This is a diagnostic checkpoint, not a proven root-cause fix.

Separate source/lifecycle/diff review and git diff --check passed. No local SDK;
new Flutter execution requires exact-head CI. Inspect the first new boundary
failure or all-five success before selecting a functional fix. Do not equate
fixture/component checks to hosted learner proof. Keep draft #41/#13 open and
all14 hosted gates pending; Pro/N4 and Auth/API/schema/RLS policies unchanged.

### Widget Auth fixture zone correction

Diagnostic checkpoint9ac29bf428b63fe2d8fb874fd55700036eb0fe89 preserves the
original assertions and adds readiness/round-result preconditions. Follow-up
source review found Harness (AccountController and Auth stream subscription)
created by setUp, outside testWidgets' FakeAsync zone. Existing passing account/
history fixtures construct it inside the widget body instead. Stream listeners
run callbacks in their registration zone, so later pumps cannot deterministically
flush profile work registered outside their fake clock.

Move Harness/source construction into mount inside each widget body; retain
in-memory synchronous store/reset in setUp and explicitly construct/close the
unit test's Harness in its own body. Preserve all nine cases and every original
assertion; add five helper assertions for actual readiness and rendered one-
question completion. No delays, polling, timeout increase, skips or production
behavior changes. Source/zone/lifecycle teardown/diff review passed. No local
Dart/Flutter SDK; exact-head CI must confirm the correction.

Next inspect latest-attempt allfive jobs/every step, especially all eight save
widget cases and retained full Flutter/Chrome/Web/Windows checks. Keep draft/
release gates pending until observed; fixture clocks are not hosted Auth proof.

## Own-device quiz progress view — core-20261022T0407

Resume #41 atc1f0b9b33ffa8040a565cc1c33efa755def3ad02. CI39716360716
latest attempt2 now completed allfive jobs/every required step successfully.
674 Flutter tests include allnine save cases; five actual Chrome, Web/Windows
configured/preview builds/native credential/process/wire/SQL/artifact gates pass.
Attempt1's only remaining failure was npm registry security-advisory HTTP503,
resolved by one failed-jobs rerun without source/dependency/workflow changes.
This confirms the save fixture zone correction; hosted learner proof is absent.

Replace /progress placeholder with explicit read-only own-device quiz practice
and current-source needs-review projection, using already-reviewed #13 rules.
Selected-level unique rounds/canonical correct answers/current practiced items
and latest-wrong recommendations remain client reports, not mastery/time/server
credit. Display at most20 original words/readings/Vietnamese meanings/error
counts. New view-local level does not modify profile/preview/study selection.

Exact repository/source/owner/level keys revoke old panels. Public vocabulary
loads before captured history so readiness is checked after the content await.
Single-flight explicit load clears prior data; safe failure/retry and late
account/source/level/route fences prevent partial or old-owner publication.
Default preview still offers unavailable/configured-account state, no mock data.
No new API/schema/RLS/Auth/storage/dependency/workflow/security/provider/spend.

Ten widget scenarios authored with original N5 source and TEST ONLY Auth/profile/
local reads; controller construction stays inside widget FakeAsync. Existing
scoring/projection/owner/SDK/native tests retained. Separate source/lifecycle/
route/projection/diff review plus local QA51/29 regressions/whitespace passed.
No local Flutter/Dart SDK: new format/analyze/widgets/builds require exact-head
Actions. See QUIZ_PROGRESS_VIEW.md. Keep #13 open/#41 draft/all14 hosted gates
pending. Next inspect complete latest-attempt CI and fix real diagnostics; only
pending CI means released handoff without duplicate code or long polling.
Pro/N4/main/source branches, merge/deployment/release/schedule unchanged.

## Progress widget pinned-format correction — core-20261022T0510

Resume #41 at935b7286618e6ebd5269d7340e2de1e6ad17d1bd. Exact
CI39721489739 latest attempt1 completed repo/database/AI/Windows every required
step successfully, including configured/preview builds/native checks/artifacts.
Flutter stopped at strict format: exactly two hunks in the new progress widget
test, wrapping two long testWidgets calls and one cascade. Production progress
source and all other Dart files were accepted by the formatter. Analyze, new
ten widgets/full Flutter/Chrome/Web/downstream were skipped, not passed.

Applied exactly the pinned-SDK diff from the completed Flutter job. Complete
corrected test Git hash04081f48 matches diagnostic target04081f4; all ten expanded
cases, all original assertions and string literals retained. All non-whitespace/
non-comma text is identical. No production/model/owner guards, CI/lint/security,
workflow/dependency or Pro/content changes. Separate diagnostic/source/assertion/
blob/diff review and git diff --check passed. Local Dart/Flutter SDK absent; no
new executable format/analyze/widget/build pass claim.

Next inspect corrected-head latest-attempt allfive jobs/every required step,
including all ten progress widgets, before further implementation. Fix actual
diagnostics retaining assertions; pending-only release without duplicate source/
docs-only commits or long polling. Keep #13 open/#41 draft/default preview/all14
hosted groups pending. Historical674 Flutter/five Chrome validates only the
previous save increment. Main/source/Pro/API/schema/RLS/Auth strategy/providers/
spend/merge/deployment/release/schedule unchanged.

## Native quiz save/history/progress journey — core-20261022T0614

Resume #41 at03cda71f75354b1fc9941502f6493c42537724fe. Exact CI39726504614
latest attempt1 completed allfive jobs/every required step. Completed logs prove
683 Flutter tests, allten progress cases/five actual Chrome/Web release, retained
SDK/native/process/wire/SQL and configured/preview Windows/native/artifact gates.
Progress formatting and all57 widget assertions are verified as components;
all14 hosted learner groups remain pending.

Add a composed real-file widget journey: actual pinned SDK/persistent runtime/
owned startup, original bundled N5 and production UUID/UTC capture through ten
real answers, explicit save, history and current-source needs-review statistics.
A forwarding observation port still awaits actual native append/flush/read and
returns unchanged rows; it supplies no success/result fixtures. Stale duplicate
save must append once. History/progress must agree with disk9/10/one candidate.

Await owned close before unmount; reopen real journals under a fresh SDK/runtime
and retained TEST ONLY vault, require refresh/profile barrier without manual
login or seeded attempt, then recover the exact event and visible projection.
A/B/A logout/login must clear old UI, return empty B data, recover A only after
explicit read, leave file bytes unchanged and append nothing. Only fixture Auth/
profile endpoints may be called; no quiz RPC or owner/token text in the view.

SDK/storage/callbacks/awaited close use the real event loop with bounded native
completion/readiness, then normal frame checks. New composed test is authored,
not yet executed. HTTP/unsigned JWT/vault are simulated; graceful same-process
reopen is not forced-process/power-loss, physical Windows vault, hosted Auth/RLS
or multi-device evidence. Default/prod behavior and all prior tests unchanged.
See QUIZ_DISK_JOURNEY.md. QA adds a baseline anchor, retains all14 pending gates.

Next inspect new exact-head latest-attempt allfive jobs/every step, fix real
diagnostics retaining assertions. New format/analyze/native-widget/platform
execution requires Actions because local Dart/Flutter SDK is absent. Keep #13
open/#41 draft; no main/source/Pro/N4/API/schema/RLS/Auth strategy/dependency/CI/
security/provider/spend/merge/deployment/release/schedule changes.

## Bounded AI HTTP resource adapter — core-20261022T0716

Resume #41 at49ee8fb93631eefed974ffc59ed4299ea552f4bf. Exact CI39733485647
latest attempt1 allfive jobs/every required step passed;684 Flutter tests include
the composed real native-disk quiz save/history/progress/reopen/A-B-A journey,
five Chrome/Web/Windows and retained checks. That new journey is verified as
local SDK/disk/UI composition with TEST ONLY HTTP/vault, not hosted learner proof.

#13 hosted ownership/sync/mastery/learner gates remain open. Proceed with #31's
ready independent HTTP resource increment after its merged #7 dependency: trusted
fixed-operation handler, strict POST/JSON/Bearer/identity encoding, actual streamed
32768-byte fatal UTF-8 bound and length validation before concatenation. Bound
empty chunks/read iterations; reject malformed/truncated/BOM JSON safely.

Combined client/overall deadline starts before body read; monotonic checks fence
starved timers. Per-read abort listener cleanup, non-blocking source cancellation
and reader release bound stalled/uncooperative reads. Optional parent signal in
AiService preserves existing callers and Auth/limiter/receipt/output rules; late
identity/provider results cannot dispatch/complete after guards. Uncertain claims
remain pending, no automatic retries/takeover. Fixed safe HTTP/error mapping,
no-store/no token/raw reason logs, frozen JSON shapes unchanged. No endpoint or
Auth strategy/provider/dependency/deployment change. See AI_HTTP_BOUNDARY.md.

Local Node24.19.0 pinned npm ci, Prettier check, strict TypeScript and58 tests
passed:20 new HTTP/cancellation cases and38 original unchanged. Native Request/
ReadableStream are actual; Auth/limiter/context/provider/receipts are TEST ONLY.
Local Flutter/Dart SDK absent; full new-source platform CI remains required.
QA adds one baseline to53 and retains all14 pending integration groups.

Next inspect exact-head latest-attempt allfive jobs/every step; fix diagnostics
retaining assertions. After green continue #31 concrete verified Auth, distributed
limits and conversation/receipt transaction binding with Deno/Edge evidence. No
paid provider/live config, production/Pro/N4 changes. Keep #31/#13 open/#41 draft;
no main/source branch/merge/release/schedule changes.

## Fixed-project server AI Auth adapter — core-20261022T0810

Resume #41 at18642c650d84d7683ffb2bc4096495bc03937cf5. Exact CI39740748424
latest attempt1 completed allfive jobs/every step successfully, including AI58
Node tests/format/strict types/audit, retained Flutter/Web/Windows/native/SQL gates.
This verifies the prior HTTP increment as a component, not hosted learner gates.

Continue ready #31 with an opt-in implementation of its existing AuthVerifier
port: fixed trusted HTTPS project origin/public key, GET /auth/v1/user with only
caller access token and public apikey; no redirects/cache/session/refresh/retry.
Supabase Auth owns token verification; no decoded learner JWT/metadata/owner
fallback. Only validated server UUID/aud authenticated may reach existing limiter,
context and receipt ownership.401/403 reject,429 rate-limits, all remaining network/
malformed/resource faults fail closed with fixed errors/no raw body or token logs.

Independent bounded deadline/caller abort, monotonic checks, actual64KiB fatal
UTF-8 streaming bound/empty-read cap and nonblocking cancellation fence ignored/
late fetch/read responses; timers/listeners/reader locks cleaned. Public legacy
key decoding only classifies trusted deployment configuration, never authorizes
learner identity. No learner-editable URL/key or Auth strategy/provider change.
See AI_SUPABASE_AUTH.md for supported settings, semantics and evidence limits.

Local Node24.19.0 pinned npm install/Prettier/strict TypeScript/all79 tests passed:
21 new adapter/composition cases plus58 original unchanged; audit0 findings.
QA inventory adds one baseline to54; all14 hosted groups remain pending. Full new
head CI still required; no local Flutter/Dart/Windows execution claimed. Separate
source/security/resource/owner/error/diff review completed before publication.

Next inspect exact published-head latest-attempt allfive jobs/every required step.
Fix actual failures retaining assertions. Then #31 still needs atomic distributed
limits, conversation/receipt transaction and lookup-only reconciliation adapters,
Deno/Edge execution and actual hosted signature/issuer/expiry/A-B acceptance.
No deployment, live provider, paid spend, main/Pro/N4/content/schema/RLS/CI/
dependency/contract changes. Keep #31/#13 open/#41 draft/default preview; Personal
Alpha not accepted and release evidence remains pending.

## Private AI PostgreSQL quota — core-20261022T0910

Resume #41 branch automation/issue-11-plan-sdk-integration at parent
2fb7c934fd9099a88aa9b06e5a64a9ccd8556151. Its exact CI39747039359 latestattempt1
completed allfive jobs/every step successfully, including the prior Auth adapter
and retained full platform/SQL gates. Hosted JWT/learner proof remains pending.

Continue #31's merged #7 dependency with additive private ai_rate_buckets and
consume_ai_quota. One Auth-user row shares burst10, refill1/6s and100 successful
reservations/UTCday across allfive operations/workers. Invoker/empty search_path,
RLS enabled/no client policies or grants; trusted service_role gets only required
SELECT/INSERT/UPDATE and function execution, no delete/truncate. No public RPC,
new learner fields, rate/time/identity override or Auth/provider strategy change.

Unique first-create and row locks serialize debits; clock sampled after lock,
fractional/capped refill and daily rollover preserve burst; backward clocks deny.
Malformed inputs, invalid stored limits and rolled-back new/existing reservations
are tested. Existing receipt/learning/security tables and helpers remain unchanged.
Confirmed COMMIT must precede dispatch; SQL/transport/cancellation/commit ambiguity
fails closed, never retries/refunds/uses memory fallback. Actual TypeScript driver/
Edge binding is still outstanding; no endpoint or paid provider activated.

New SQL quota/security assertions and native first-create/last-daily-slot/rollback
observed-lock races are wired into retained scripts/test_database.sh; no existing
gate removed. A different account proceeds while an owner is locked; new database
connections check exact debit persistence and post-wait server timestamps.
Local PGlite0.5.9 executed every migration and baseline/AI receipt/quota SQL suites;
Python compilation/bash syntax/whitespace passed. PGlite is not native multi-
session proof. New native tests/full platform checks require exact-head Actions.
See AI_POSTGRES_QUOTA.md. Local pinned npm format/strict TypeScript/all79 Node
tests passed unchanged; production audit0 findings. QA inventory55 groups and29
Python QA tests passed; all14 hosted groups remain pending.

Paths: new quota migration/SQL test/native Python race/doc; scripts/test_database.sh,
supabase/README.md, docs/AI_BOUNDARY.md, this status and qa/matrix.json. No Pro/N4/
content/Flutter/frozen-wire/dependency/workflow edits. No hosted migration,
production deletion, security reduction, live Auth/provider/spend/release change.
Next inspect exact published-head/latest-attempt allfive jobs/every step before
new work. Fix real failures retaining assertions. After green bind the mandatory
limiter to a trusted committed SQL transport; conversation/receipt transaction,
lookup-only reconciliation and Deno/hosted acceptance still remain. Keep #31/#13/
#20/#22/#15 open/#41 draft/default preview; Personal Alpha not accepted.

## Committed PostgreSQL AI limiter — core-20261022T1015

Resume #41 automation/issue-11-plan-sdk-integration at
b65f5cc681b4d70ccbe9229933ba2dd823998168. Exact CI39754447718 attempt1 allfive
jobs/every step succeeded. Completed database logs prove allthree quota native
first-create/last-daily-slot/rollback lock/isolation/reconnect cases passed.

Add opt-in Node PostgresQuotaLimiter implementing existing RateLimiter, with real
pinned pg8.23.1/@types8.23.1 driver. Deployment helper captures trusted URL only,
verified TLS/no URL SSL overrides/Unix socket hosts, fresh owned client/no pipeline,
fixed role/READ COMMITTED and bounded connect/query/lock/statement/idle/overall
deadlines. Parameterized UUID/operation only; validate exactly one boolean; allow
only after COMMIT command/protocol acknowledgement. Errors/cancellation/late replies
or unknown COMMIT fail closed with fixed safe error/no raw logs, automatic retry,
refund or memory fallback. No endpoint/Auth strategy/provider/paid spend activated.

Add19 protocol-fault/composition tests: all98 Node tests/formatter/strict types
and audit0 passed locally, including no provider on unconfirmed/failed COMMIT.
Five additional real-driver/native PostgreSQL service cases are authored and
added as a required database CI step, retaining every old gate. They exercise
shared operations/A-B-A, real COMMIT barrier/observed row wait/last-slot isolation,
locked-query abort/no late debit, actual commit with injected lost delivery/no
provider, and production factory rejecting the fixture server's missing TLS.
These five are NOT executed locally; no PostgreSQL17/Dart/Flutter/Windows SDK.
Native plaintext transport and Auth/context/provider/receipts are TEST ONLY.

Paths: new backend/ai/src/postgres_quota.ts, test/postgres_quota.test.ts and
postgres_quota.native.ts; package/lock; .github/workflows/ci.yml; new
AI_POSTGRES_RUNTIME.md; AI_POSTGRES_QUOTA.md/AI_BOUNDARY.md/this status; qa/matrix.json.
QA inventory56 and all29 Python QA tests passed; new critical native step added,
all14 hosted release groups remain pending. Separate source/driver/SSL/transaction/
cancellation/owner/diff review completed before publication. No original source/test assertions, SQL/RLS,
Pro/N4/content/Flutter/frozen wire changes or weaker checks.

Next inspect published exact-head/latest-attempt allfive jobs/every step and all
five new native driver cases. Fix real failures retaining assertions; pending-only
handoff without duplicate work. Then #31 conversation/context/receipt transactions,
lookup-only reconciliation and Deno/hosted Auth/TLS/learner evidence remain open.
See AI_POSTGRES_RUNTIME.md. Keep #31/#13/#20/#22/#15 open/#41 draft/default preview;
no deployment, production deletion, security reduction, release or schedule change.

## Core checkpoint — #31 text context, 2026-10-22 11:23 UTC

- Resume draft PR #41, `automation/issue-11-plan-sdk-integration`, expected parent
  `cdae78b54d14c7aadff5e4a849adafa3452c47c5`, base tree
  `aa6190c05152fac08e217410e94c02d184ea8720`. Main observed unchanged at
  `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`; PR #37 redirects here. One core
  writer; #14/Pro N4 scope, content/manifests/tests/branch left untouched.
- Observed parent CI39763102669, latest attempt1, exact cdae78b54: allfive jobs
  and every step succeeded. Actual completed database log confirms allfive native
  pg-driver cases passed (shared operations/A-B-A, held COMMIT/no early provider,
  locked abort/no late debit, actual commit with injected lost delivery/no retry,
  production TLS factory rejects plaintext/no fallback). These are component
  fixtures, not hosted TLS/CA/JWT/Edge/Deno/provider/learner proof.
- Implemented a complete independent SQL increment for two text operations:
  private STABLE invoker profile/level and active grammar/vocabulary projection,
  strict original request shapes, canonical bounded IDs, deterministic whole-entry
  8000-byte curriculum budget/allowlist and fresh post-provider snapshot validation.
  Unknown/forged/malformed/overbudget input and changed content/profile fail closed.
  No learning/receipt/session writes, public RPC, client privileges, RLS reduction,
  live deployment, provider/Auth strategy, paid calls or application default change.
- Nine paths: new migration `20261022111500_ai_text_context.sql`,
  `supabase/tests/ai_text_context.sql`, `scripts/test_database.sh`,
  `docs/AI_TEXT_CONTEXT.md`, `docs/AI_BOUNDARY.md`, `docs/AI_POSTGRES_RUNTIME.md`,
  `supabase/README.md`, `qa/matrix.json`, this status. Existing checks/tests and
  all public frozen wire contracts remain intact. Native required database runner
  adds the new SQL suite after retained quota/claim suites.
- Local: clean pinned Node install; formatter/strict TypeScript and98 existing Node
  tests passed (0 failure/skip/cancel); PGlite0.5.9/PostgreSQL18.6 applied all11
  migrations and passed59 new text-context assertions plus250 retained baseline,
  28 AI receipt and59 quota assertions. All29 QA regressions, QA inventory57/14
  hosted pending, shell syntax and whitespace checks passed. Separate source/diff review
  completed for ACLs, bounded selection and fresh snapshot limits; it caught and
  fixed catalog-test isolation against earlier committed review fixtures. A local
  probe confirms those rows/FKs/receipts survive the suite rollback. New native PostgreSQL17 and complete exact-head Actions remain
  pending; no local PostgreSQL17/Dart/Flutter/Windows SDK was used or claimed.
- Limits/next: SQL components are not a bound ContextRepository. Add bounded real
  driver prepare/revalidation for tutor/correction with cancellation/safe errors
  and late results; never hold/reuse a transaction snapshot across provider I/O.
  Conversation prepare/reservation/claim and validated message/session+receipt
  completion need coherent transactions and distinct-event serialization before
  wiring. Lookup-only recovery, hosted Auth/Edge/provider and all14 release groups
  remain open. Do not merge this draft, close #31 or claim Personal Alpha.
- Durable publication commit/tree/exact-head CI and released marker are recorded
  in the re-read PR #41/#37 and #31 handoff; only pending CI remains after publish.

## Core checkpoint — #31 text context runtime, 2026-10-22 12:24 UTC

- Resume draft #41, `automation/issue-11-plan-sdk-integration`, expected parent
  `a16bdb4a03b16f1d01dabfcf89961a2d5cde18d9`, exact base tree
  `1c6f9c4a4b53bc6b954ecaf33362588c4b284974`. Fresh main unchanged at
  `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`; #37 redirects here. One core writer,
  Pro retains #14/N4/content/manifests/tests/docs/branch scope without edits.
- Exact parent CI39770572353 latest attempt1 completed/success; allfive jobs and
  every step passed, including Flutter/Windows. This resolves that source's full
  CI pending handoff; no hosted learner/Alpha acceptance follows from it.
- Delivered opt-in PostgresTextContextRepository for tutor/correction: captured
  original requests, detached frozen bounded contexts, fresh owned READ COMMITTED
  READ ONLY prepare and validation phases, confirmed COMMIT before dispatch/final
  success, exact safe SQL error pairs, deadline/abort/late-result fences and no
  automatic retry. Real SQL profile/active-content revalidation is bound through
  the original ContextRepository port. Conversation operations remain explicitly
  unsupported. Host still supplies mandatory verified Auth/limiter/provider/receipts.
- Extracted the existing owned pg URL/TLS factory into postgres_connection.ts;
  unchanged verified TLS/no overrides/no pipeline/timeouts/close/error suppression.
  Quota's original API/type aliases/config error and entire transaction body are
  preserved; all original quota unit/native tests remain text-identical. No new
  dependency, lock, SQL migration, public wire/RLS/Flutter/default/provider/Auth
  strategy/deployment/spend change, token/raw SQL logs or plaintext fallback.
- Thirteen paths: backend/ai src postgres_connection.ts, postgres_text_context.ts,
  postgres_quota.ts; new test/postgres_text_context.test.ts and .native.ts;
  package.json; .github/workflows/ci.yml; docs/AI_TEXT_CONTEXT_RUNTIME.md,
  AI_TEXT_CONTEXT.md, AI_BOUNDARY.md, AI_POSTGRES_RUNTIME.md, this status;
  qa/matrix.json. New required database native step retains every existing gate.
- Local clean pinned Node24 install; formatter/strict TypeScript and117 tests
  passed (98 retained +19 new;0 fail/skip/cancel); production audit0 findings.
  All29 QA regressions passed; inventory58/all14 hosted groups pending. A new
  redundant workflow-file QA anchor initially conflicted with an existing fixture's
  directory setup; replaced it with the new cancellation test anchor, retaining
  the explicit required CI step and every existing QA assertion unchanged.
  Whitespace/source checks and separate quota-body/original-tests equality passed.
- Nine real-driver/native PostgreSQL17 cases added: actual quota+context/service
  both text operations/no open provider transaction, A/B/A levels/refs, actual
  content retirement/version and profile changes after dispatch, actual COMMIT
  barriers before provider/final success, observed table-lock abort/no late work,
  actual commit with injected lost delivery both phases/no retry, absent profile/
  inactive requested content, production TLS factory rejects plaintext. These are
  authored/compiled but not locally executed; exact-head CI remains required.
  Disposable URL restricted; Auth/provider/receipt/plaintext/lost-delivery probes
  TEST ONLY. No native/hosted TLS/CA/JWT/Deno/Edge/network-partition/learner claim.
- Separate source/diff review covers connection/transaction closure, immutable
  parameters, safe-error mapping, bounds, fresh snapshots and retained CI/security.
  Publication commit/tree/readback/non-force expected-head evidence and released
  marker are stored in PR #41/#37 and issue #31 after re-reading their bodies.
- Next: inspect exact-head latest-attempt CI/allfive jobs before new work; if green,
  implement coherent conversation reserve+claim serialization and validated
  message/session+token receipt completion, then lookup-only reconciliation.
  Keep #31/#13/#20/#22/#15 open/#41 draft. Hosted configuration/evidence and all14
  release groups remain pending; default preview is unchanged, no Alpha release.

## Core checkpoint — #31 atomic conversation reservation, 2026-10-22 13:24 UTC

- Resume #41 `automation/issue-11-plan-sdk-integration`, expected parent
  `c8d66f43273aa5c7f5cc8202cc64e12628f0a27e`, exact base tree
  `c36d546325b4c279e910398cd4e88012776c951e`; fresh main unchanged at
  `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. #37 redirects here; one core writer.
  Pro/#14 N4/content/manifests/content tests/docs/branch unchanged.
- Parent CI39778434269, raw exact c8d66f4 latest attempt1: allfive jobs/every step
  completed/success, including allnine native text cases and Flutter/Windows.
  Resolves that source's full CI pending handoff; hosted release proof remains open.
- Added private strict request/context/reserve SQL for allthree conversation ops:
  verified backend owner/profile/level, active scenario/typed curriculum, owned open
  contiguous alternating transcript, bounded data and generated server IDs/slots.
  Same-transaction receipt/token+private context reservation, short per-owner
  advisory/profile/session/scenario locks and unique pending session guard prevent
  distinct events/finish from overtaking an unresolved turn. Replay returns original
  completed or capability-free pending before active checks; legacy pending never
  acquires a replacement token. No public session/message/success write is made.
- New private table has RLS and SELECT/column-INSERT only; cannot insert completed
  flags or clocks, update/release/delete/truncate. Deliberately no completion/release
  endpoint yet; even bare legacy receipt completion leaves the guard held. No token
  logs, reset/expiry/takeover, default/runtime/endpoint/provider/Auth strategy,
  dependency/frozen wire/client grants/RLS reduction/deployment/spend change.
- Ten paths: new supabase/migrations/20261022131000_ai_conversation_reservations.sql,
  supabase/tests/ai_conversation_reservations.sql,
  scripts/test_ai_conversation_concurrency.py, scripts/test_database.sh,
  docs/AI_CONVERSATION_RESERVATIONS.md, docs/AI_BOUNDARY.md,
  docs/AI_TEXT_CONTEXT_RUNTIME.md, supabase/README.md, qa/matrix.json, this status.
  Existing retained required database step adds SQL suite and five native races;
  every original gate/test/Node/Flutter source remains intact.
- Local PGlite0.5.9/PostgreSQL18.6 applied all12 migrations and passed68 new SQL
  assertions plus250 baseline/28 receipt/59 quota/59 text-context assertions.
  Includes malformed/owner/level/curriculum/transcript/capacity cases, pending and
  completed replay, no public writes, denied releases, rollback and TEST ONLY
  trigger storage failure after claim with no orphan receipt/token/reservation.
  Python compilation/bash syntax/whitespace and all29 QA regressions passed;
  inventory59, all14 hosted release groups pending. Existing Node117/native text9
  checks are observed parent CI evidence, not a new local execution claim.
- Five authored native PostgreSQL17 races use independent psql processes, bounded
  barriers, observed ungranted advisory locks, A/B independence and fresh-process
  receipt/token/reservation/slot/public-message verification: identical event,
  changed same event, distinct event, finish overtaking turn and rolled-back owner.
  Fresh pending retries expose no token/context and never renew dispatch. Fixed
  disposable CI URL only; no local PostgreSQL17/native execution claimed yet.
- Separate source/diff review covers strict shapes, owner locks, NULL-safe identity
  constraints, ACLs, atomic rollback, source bounds and safe pending availability.
  Exact commit/tree/non-force expected-parent/full-tree/blob readback and latest CI
  are recorded in re-read PR #41/#37 and #31 released checkpoints after publication.
- Next: inspect exact-head latest-attempt CI/allfive jobs, fix any failure first.
  Then implement validated session/user+assistant message and token-checked receipt
  completion with reservation release in ONE transaction, source/owner/sequence
  rechecks and correlated lookup-only recovery. Introduce coherent runtime atomic
  acquisition; do not hide a claim in current separate prepare/claim calls or return
  another dispatch owner's token. #41 remains draft; #31/#20/#22/#15/#13 open.
  SQL-role/PGlite/reconnect fixtures are not hosted JWT/Edge/provider/learner/Alpha
  proof. No production deployment/release or schedule change; all14 gates pending.

## Core checkpoint — #31 atomic conversation completion, 2026-10-22 14:27 UTC

- Resume draft #41 `automation/issue-11-plan-sdk-integration`, expected parent
  `007b2d49587f5e7979a5acee8913521f17efeac2`, exact base tree
  `bdf7d3a2e76a99cf891e60bdfa0f4182639f9670`. Fresh main remains
  `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`; #37 redirects here. One core writer;
  Pro/#14 content/manifests/content tests/N4 docs/branch untouched.
- Parent CI39787225163 exact007b2d4/latest attempt1: allfive jobs/every step
  completed/success verified. Includes68 native reservation assertions and allfive
  native races; resolves that source's pending Flutter/Windows handoff.
- Added strict original bounded response validator and service-only atomic completion
  for allthree conversation mutations. Exact owner/request/private token/receipt,
  captured profile/active scenario/typed curriculum/transcript/version/slots rechecked
  under short locks. Completed original replay precedes active source checks; changed
  response/request conflicts. Model IDs/roles/sequence/audio/refs cannot choose writes.
- Start saves reserved session/server clock+assistant0; turn saves exact immutable
  user text plus reserved validated assistant; finish saves server close clock and
  exact scores/summary without SRS/learning-error writes. All public changes,
  token-checked receipt completion and reservation release share ONE transaction.
  Any message/receipt/release error rolls back the entire operation. Legacy bare
  receipt completion never heals/releases missing public writes or renews dispatch.
- Narrow SECURITY DEFINER/empty search_path/static qualified SQL supplies guarded
  release; direct service UPDATE/DELETE/TRUNCATE/pre-released INSERT stay denied.
  Existing reservation denial assertions, client grants/RLS/frozen wire/Auth strategy,
  legacy helpers and every prior runner gate unchanged. No reset/expiry/takeover,
  provider/endpoint/runtime/default/deployment/collection/spend change or token log.
- Ten paths: new supabase/migrations/20261022142000_ai_conversation_completion.sql,
  supabase/tests/ai_conversation_completion.sql,
  scripts/test_ai_completion_concurrency.py, docs/AI_CONVERSATION_COMPLETION.md;
  scripts/test_database.sh, docs/AI_CONVERSATION_RESERVATIONS.md,
  docs/AI_BOUNDARY.md, supabase/README.md, qa/matrix.json, this status.
- Fresh local PGlite0.5.9/PostgreSQL18.6 applied all13 migrations. New99 SQL assertions
  passed, retaining250 baseline/28 receipt/59 quota/59 text/68 reservation assertions.
  Includes malformed original shapes/arrays/text/bounds/typed refs, owner/token/
  request fencing, captured source drift and retirement, actual storage fault
  injection after start/session, turn/user+assistant, finish/closure, receipt and
  release writes; every failure leaves pending/no partial writes. Exact replay of
  allthree operations after closure/retirement/profile changes passed. Fixture roles/
  model results do not establish real Auth/provider or learner success.
- Eight native PostgreSQL17 cases authored using independent psql processes and
  observed ungranted locks/bounded barriers: duplicate/changed completion, next turn/
  consecutive slots, transaction rollback, finish vs next turn, target update,
  new scenario link and old transcript update. Unrelated owner/scenario remains
  independent; fresh connections verify exact messages/receipt/guard/closure/replay.
  Fixed disposable CI URL/no capability output. Not locally executed; exact-head CI
  required. Reconnect/ignored delivery is not a real network-partition/commit-ACK proof.
- All29 QA regressions, inventory60/all14 hosted groups pending, Python compilation,
  bash syntax, SQL parsing/embedded execution and whitespace checks passed. Separate
  diff review covers NULL/shape/identity checks, definer ACLs, static SQL, row/FK locks,
  rollback, bounded native barriers and preserved old tests/gates. Early embedded
  execution caught JSON operator precedence/local-variable qualification errors;
  corrected before publication and all suites rerun successfully.
- Exact commit/tree/expected-parent nonforce/full-tree/changed-blob readback and
  latest CI are recorded after publication in re-read #41/#37/#31 RELEASED handoffs.
- Next inspect exact-head latest-attempt allfive jobs/steps, fix actual failures.
  Then introduce coherent atomic runtime acquisition/completion and lookup-only
  correlated reconciliation with real-driver COMMIT/cancellation/restart guards.
  Current separate prepare/claim methods cannot hide reserve in prepare and expose
  another worker's pending token. Do not install a default/endpoint before this
  binding and uncertainty behavior are verified. #31/#13/#20/#22/#15 remain open,
  #41 draft; all14 hosted release groups/Personal Alpha proof still pending.

## Core checkpoint — #31 coherent conversation runtime, 2026-10-22 15:29 UTC

- Resume draft #41 `automation/issue-11-plan-sdk-integration`, expected parent
  `e621c9d074bdcbc8f8c551433e7e7f67dfb5183b`, exact base tree
  `35b05a534630a49e3a63b543dfe4edda094a438a`. Fresh main remains
  `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`; #37 source redirects here. One core
  writer; Pro/#14/N4/content/manifests/content tests/docs/branch unchanged.
- Parent CI39795974325 raw exact e621c9d/latest attempt1: allfive jobs/every step
  completed/success. Actual database log confirms99 new completion SQL assertions
  and all8 native SQL races. Resolves its old queued/unverified platform handoff.
- Added explicit ConversationStore lookup/acquire/complete port and owned actual pg
  adapter; optional AiDependencies.conversations selects this lane for allthree
  mutations only. Atomic context/server IDs/dispatch claim COMMIT must be confirmed
  before provider; validated public/session/message + token receipt + guarded release
  COMMIT must be confirmed before success. Shared original provider/schema/ID/ref/
  audio checks remain. No transaction spans provider I/O. No split prepare/claim,
  text context validation or legacy receipt/recovery fallback occurs in this lane.
- Completed original replay precedes active-source checks; pending or unknown
  delivery remains unavailable with no capability exposure, provider retry, expiry,
  reset/takeover/delete. Capture/freeze request/normalized owner-event key/token and
  cloned bounded strict context/result before asynchronous work. All parameters
  fixed/bound, exact row/shape/operation/UUID/sequence/typed-ref checks, semantic
  returned-original equality before COMMIT. Authoritative source/owner/token checks
  remain inside the already reviewed SQL transaction.
- Fresh owned READ COMMITTED phases (lookup READ ONLY), fixed service role and
  lock1s/statement2s/idle3s/independent5s limits, monotonic alive checks, abort/late
  result guards and exactly-once immediate close. Only exact controlled SQLSTATE/
  message pairs cross safe errors; unknown driver/storage/COMMIT errors redact to
  NETWORK_UNAVAILABLE, without SQL/credential/token/context logs. Existing strict
  TLS factory body unchanged, only one fixed application-name type added. No learner
  URL/key, plaintext fallback, endpoint/default/provider/Auth strategy/deploy change.
- Fifteen paths: new backend/ai/src/postgres_conversation.ts,
  backend/ai/test/postgres_conversation.test.ts,
  backend/ai/test/postgres_conversation.native.ts, docs/AI_CONVERSATION_RUNTIME.md;
  backend/ai/src/ports.ts, service.ts, postgres_connection.ts, package.json;
  .github/workflows/ci.yml, docs/AI_BOUNDARY.md, AI_CONVERSATION_COMPLETION.md,
  AI_CONVERSATION_RESERVATIONS.md, this status, qa/matrix.json, supabase/README.md.
  New required database native step retains every old SQL/race/quota/text/profile/
  export gate. Original tests/support/SQL/runner/lockfile/frozen contracts unchanged.
- Local pinned Node24 clean install, formatter/check, strict TypeScript and138 tests
  passed (117 retained +21 new,0 fail/skip/cancel); production audit0 findings.
  Covers allthree operations/parameter order/owned phases, malformed context/capability/
  replies/output, original pending/completed/no legacy fallback, COMMIT provider and
  success barriers, unknown delivery, deadline/abort/late I/O, snapshots and A/B/A
  connections. Source review captured the token before provider awaits. The generic
  frozen turn fixture allows sequence0; new TEST ONLY atomic projection uses2 after
  assistant0/user1, preserving original fixture and strict production slot checks.
- Ten compiled native PostgreSQL17 cases authored: actual quota and start→turn→finish,
  restart/original replay after closure/retirement/profile change; same pending event
  and distinct turn/finish during held provider; actual acquire/completion COMMIT with
  TEST ONLY lost delivery and fresh retry; retired-source rollback/pending; observed
  blocked-lock cancellation/no late provider; A/B/A/foreign parent; production TLS
  factory rejects plaintext; actual COMMIT delivery gates provider/final success.
  Barriers bounded; fixed disposable URL only. Not locally executed; exact-head CI
  required. Fixture Auth/provider/plaintext/injected delivery is not hosted TLS/CA/
  JWT/PostgREST/Edge/Deno/provider/real network-partition/learner proof.
- All29 QA regressions/inventory61/all14 hosted groups pending, whitespace and
  separate diff/source review passed. Existing tests/SQL/runner/quota/text adapters/
  lockfile and strict TLS factory body confirmed byte-identical. No dependency/
  migration/client grant/RLS/security reduction/paid call/content/merge change.
- Exact commit/tree/nonforce expected-head/full-tree/changed-blob readback evidence
  and current CI are recorded after publication in re-read #41/#37/#31 RELEASED
  handoffs. New native/runtime CI must not be inferred from parent or fixture tests.
- Next inspect exact-head latest-attempt allfive jobs/every required step and all10
  native logs; fix actual failures preserving assertions. Then add lookup-only
  correlated reconciliation without another worker's token or dispatch renewal,
  observed Edge/Deno compatibility and hosted configuration/evidence. Default and
  live endpoint stay unconfigured; #31/#13/#20/#22/#15 open/#41 draft/all14 hosted
  learner release groups/Personal Alpha still pending. No schedule change.

## Core checkpoint — #31 private reconciliation SQL, 2026-10-22 16:18 UTC

- Resume draft #41 `automation/issue-11-plan-sdk-integration`, expected parent
  `014bee0087ac197774efbac89a2ac4ec32898e09`, exact base tree
  `073697c6e0b0a732d98b7eb0bc3494ec81bc3463`. Fresh main remains
  `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`; #37 redirects here; one core writer.
  Pro/#14/N4/content/manifests/content tests/docs/branch untouched.
- Parent CI39805367641 raw exact014bee0/latest attempt1 allfive jobs/every step
  completed/success verified, including all10 actual pg conversation runtime cases.
  Resolves that source's previously pending Flutter/Windows handoff.
- Added private service-only STABLE/invoker/empty-search-path saved recovery lookup:
  exact original owner/operation/event/request, original receipt UUID, canonical
  existing ProviderInput idempotency key and saved context. One statement snapshot
  returns coherent missing/pending/completed; no current-source context rebuilding,
  receipt/claim/token write, dispatch lock, release or capability exposure. Legacy
  pending without a saved atomic reservation remains capability/context-free pending.
- Added narrow service-only empty-search-path definer reconciliation bound to exact
  original receipt/request/key/context. Owner advisory + receipt/reservation locks,
  original token read ONLY inside SQL, then reuse all validated completion guards/
  source rechecks/public writes/token receipt/release in one transaction. No token
  returned/renewed/replaced; no new claim/reset/expiry/delete/takeover. Duplicate or
  original-worker completion races yield one original result; wrong key/owner/
  request/context/result conflicts. Completed original replay precedes active checks.
- SQL identity binding does NOT authenticate a provider result. Trusted authenticated
  lookup-only upstream verifier/runtime recovery remains absent and mandatory before
  invoking this component from runtime. Never accept a learner/model/legacy recovery
  proof or interpret missing upstream output as permission to redispatch. Existing
  AiService pending behavior still fails closed; no new endpoint/default/provider,
  strategy/Auth/wire/dependency/collection/spend/deployment change. Existing service
  can already read claims/complete; no new client authority or reduced RLS/grants.
- Eleven paths: new supabase/migrations/20261022161500_ai_conversation_reconciliation.sql,
  supabase/tests/ai_conversation_reconciliation.sql,
  scripts/test_ai_reconciliation_concurrency.py, docs/AI_CONVERSATION_RECONCILIATION.md;
  scripts/test_database.sh, docs/AI_BOUNDARY.md, AI_CONVERSATION_RUNTIME.md,
  AI_CONVERSATION_COMPLETION.md, this status, qa/matrix.json, supabase/README.md.
  Existing runner adds one SQL suite/eight native cases and retains all prior steps.
  Original migrations/SQL tests/Node runtime/workflow/contracts/Pro content untouched.
- Local fresh PGlite0.5.9/PostgreSQL18.6 applied all14 migrations:72 new SQL assertions
  passed, retaining250 baseline/28 receipt/59 quota/59 text/68 reservation/99 completion.
  Covers missing/no writes, saved context/no tokens, canonical UUID key vs original
  request casing, owner/receipt/key/context/shape/bounds, legacy pending, source drift,
  every mutation/replay, actual release-storage fault after public/session/message/
  receipt writes with full rollback (including finish timestamps/scores/summary),
  denied direct release/client helpers, no new tokens and no duplicate writes.
- Eight native PostgreSQL17 cases authored/syntax checked, not locally executed:
  same result, changed result, original normal completion, rollback, next distinct
  turn, finish vs turn, wrong context and wrong key. Independent psql processes/
  bounded barriers and actual ungranted advisory waits. During held first transaction,
  separate STABLE lookup sees only original pending metadata/no partial public rows;
  B/separate scenario with same event UUID acquires independently. Fresh connections
  verify exactly one receipt/token/original result, release/closure and consecutive
  next slots. No dispatch token leaves SQL. Fixed disposable CI URL only; real
  upstream/Auth/hosted/partition/learner proof is not established by these fixtures.
- All29 QA regressions/inventory62/all14 hosted groups pending, Python compile,
  bash syntax/whitespace and separate diff/security/source review passed. Existing
  migration/test/runtime/workflow and every old runner step byte-identical. Node138/
  native runtime10/platform are observed parent CI evidence, not new local execution.
- Exact commit/tree/full-tree/changed-blob readback/expected-parent nonforce evidence
  and latest CI are recorded after publication in re-read #41/#37/#31 RELEASED
  handoffs. Current-head native/platform checks cannot be inferred from embedded SQL
  or parent success. No merge/issue close/release/deployment/schedule change.
- Next inspect exact-head latest-attempt allfive jobs/steps and eight native results;
  fix actual failures preserving assertions. Then implement trusted upstream lookup-
  only correlation verifier/driver/runtime recovery with captured immutable result/
  request/key/context, safe COMMIT/cancel/restart behavior and no borrowed token,
  legacy fallback or redispatch. Hosted TLS/CA/JWT/PostgREST/Edge/Deno/provider and
  all14 learner release groups remain pending; #31/#20/#22/#15/#13 open/#41 draft.

## Core checkpoint — #31 PostgreSQL recovery driver, 2026-10-22 17:22 UTC

- One core writer resumes draft #41 `automation/issue-11-plan-sdk-integration`,
  expected parent `9b9283f1c8ae0f2bcd59a0f5633b52d238efe62b`, base tree
  `af9f4988d4a9cd2d49be41ee47bcc45d63c3ae65`. Fresh main remains
  `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`; #37 redirects/source unchanged;
  Pro #14/N4/content/manifests/content tests/docs/branch untouched.
- Exact parent CI39813007245/latest attempt1 now allfive jobs/every step success,
  including SQL72/eight native reconciliation races/runtime10. This resolves its
  old Windows/Flutter pending checkpoint, not this new head's validation.
- Explicit separate host-only ConversationRecoveryStore plus actual owned pg
  lookupRecovery/reconcile methods. Canonical original owner/op/event/full key and
  receipt UUID, strict saved context/output/IDs/sequence/audio/refs/byte limits;
  frozen lookup outputs and all parameters captured before I/O. Fixed SQL/roles/
  limits/fresh TLS connections; no dispatch token returned, borrowed or renewed.
  Missing/legacy never fabricates context. Shared completion validator preserves
  normal token-bound completion behavior. Semantic returned response match before
  confirmed COMMIT; no success/result on uncertain delivery. Existing monotonic
  deadline/parent abort/late response/close-once/listener cleanup apply both methods.
- Paths: backend/ai/src/ports.ts, src/postgres_conversation.ts,
  test/postgres_conversation.test.ts and .native.ts; new
  docs/AI_CONVERSATION_RECOVERY_DRIVER.md; docs/AI_BOUNDARY.md,
  AI_CONVERSATION_RUNTIME.md, AI_CONVERSATION_RECONCILIATION.md, this status and
  qa/matrix.json. No migration/workflow/dependency/provider/Auth/public wire/default/
  endpoint/RLS/collection/spend/deployment changes. AiService still fails closed
  on pending; legacy recovery is never substituted. Stored database correlation
  is NOT authenticated upstream proof; trusted lookup-only verifier remains absent.
- Local pinned Node24 format/check/152 tests passed (138 retained/14 new, no failed/
  skipped/cancelled); production audit0 findings. New unit cases cover allthree
  mutations/strict replies/borrowed correlation/context/output bounds/IDs/refs,
  missing/legacy/completed, canonical key/original casing, captured immutable args,
  semantic response order, commit gates/ambiguity/abort/deadline/late cleanup/A-B-A.
- Eight additional actual-driver native tests authored/typechecked in retained
  required database command (18 total): allthree mutations/fresh replay after
  closure/retirement/profile change, lookup/reconcile actual COMMIT lost-delivery
  and delivery gates, observed blocked reconciliation abort, post-write rollback
  and fresh once-only retry, A/B/A same event/borrowed receipt/context/request/source
  denial. No local PostgreSQL binary; native execution pending exact-head CI.
  Fixtures/SQL role/plaintext/generated result/delivery injections are not hosted
  identity/provider/real partition/learner proof.
- Next inspect exact-head allfive latest-attempt jobs/every step/native18 and fix
  failures preserving assertions. Then trusted authenticated lookup-only result
  verifier and bounded captured runtime recovery; no legacy fallback/redispatch.
  Hosted TLS/CA/JWT/PostgREST/Edge/Deno/provider proof and all14 learner release
  groups remain pending. Keep #31/#20/#22/#15/#13 open/#41 draft. No merge/release/
  deployment or schedule change.

## Core checkpoint — #31 opt-in correlated recovery runtime, 2026-10-22 18:24 UTC

- One core writer resumes draft #41 `automation/issue-11-plan-sdk-integration`,
  expected parent `d8eeebc6a616a7f347e9c0358f3baaeece356bb5`, base tree
  `be7749af81d599fa2b60c468f8a3a24715cb75da`. Main78a44fa unchanged/#37 redirects/
  source unchanged; Pro #14/N4/content/manifests/content tests/docs/branch untouched.
- Parent CI39822068710/latest attempt1 raw exactd8eeebc allfive jobs/every step
  completed/success. Actual completed database log verifies18 native pg cases passed
  (eight driver +ten earlier runtime, zero fail/skip/cancel); old pending resolved.
- Added explicit ConversationRecoveryBinding/AuthenticatedConversationLookup port
  and bounded CorrelatedConversationRecovery coordinator. AiService captures SAME
  coherent store/lookup before async I/O; pending/losing acquire can recover only
  with that opt-in. Default remains unavailable; ordinary missing/acquire/generate
  and legacy fixture lane unchanged. No real provider lookup adapter configured;
  trusted adapter MUST authenticate upstream provenance, never echo arbitrary
  learner/model JSON. Metadata/types/SQL fixtures are NOT genuine upstream proof.
- Capture canonical owner/op/event/full key/original request/saved receipt/context;
  missing/legacy never fabricates context or dispatch capability. Require <=2MiB
  exact seven-field original lookup JSON, full semantic request/context equality,
  unchanged schema/1MiB response/IDs/slots/null audio/typed refs. Shared original
  pure validators extracted unchanged from pg driver; retained tests unchanged.
  Frozen captured values pass to guarded SQL reconcile, confirmed COMMIT before
  success; no renew/acquire/borrowed token/legacy fallback/generate/automatic retry.
- Independent monotonic10s recovery deadline plus service overall/parent abort;
  wait races prevent ignored/late store/upstream/reconcile replies from advancing.
  Cleanup private signal/timer/parent listener; driver owns/closes DB connection.
  Unknown upstream failures safe PROVIDER_UNAVAILABLE; controlled DB errors kept.
- Paths: backend/ai/src/ports.ts, service.ts, postgres_conversation.ts; new
  src/conversation_validation.ts, src/conversation_recovery.ts and
  test/conversation_recovery.test.ts; appended test/postgres_conversation.native.ts;
  new docs/AI_CONVERSATION_RECOVERY_RUNTIME.md; docs/AI_BOUNDARY.md,
  AI_CONVERSATION_RUNTIME.md, AI_CONVERSATION_RECOVERY_DRIVER.md, this status and
  qa/matrix.json. No endpoint/default/provider strategy/Auth/public wire/migration/
  RLS/grant/dependency/workflow/spend/collection/deployment change.
- Local Node24 formatter/strict TypeScript/168 tests (152 retained/16 new, no failed/
  skipped/cancelled), production audit0 passed. New unit cases cover allthree ops,
  malformed/misassociated/unknown/oversized result/DB context, same-store/late host
  binding capture, immutable request casing/semantic object order/output refs/IDs,
  COMMIT gates/ambiguity/cancel/deadline/late settle/timer starvation/A-B-A.
- Ten new native pg runtime cases authored/typechecked (28 total) in existing
  required database command: full lifecycle/replay with actual quota and no open
  upstream transaction, actual completion delivery loss/restart, lost acquisition
  with absent original staying pending, late upstream cancellation, observed SQL
  lock cancellation/no late writes, same/changed original-worker completion races,
  A/B/A borrowed-result denial, source-retirement rollback and actual COMMIT delivery
  before success. No local PostgreSQL binary; new exact-head CI execution pending.
  Synthetic Auth/upstream/plaintext/delivery injection are not live provenance,
  TLS/CA/JWT/Edge/Deno/real partition or learner evidence.
- Next inspect exact-head allfive latest-attempt jobs/every step and native28 logs,
  fixing actual failures without weakening assertions. Real approved authenticated
  upstream adapter and hosted/Edge/Deno integration remain missing. Keep default
  unconfigured/#31/#20/#22/#15/#13 open/#41 draft/all14 learner release groups pending.
  No merge/release/deployment/schedule change.

## Core checkpoint — #31 standalone Deno compatibility, 2026-10-22 19:26 UTC

- One core writer resumes draft #41 `automation/issue-11-plan-sdk-integration`,
  expected parent `691a797f9bdc333fe6d30c9476476474dd9e8328`, base tree
  `c1dbdd1f0ffc533f5bcadc502ba41aa02bcf9ef5`; main78a44fa/#37 redirect/source afa572a
  unchanged. Pro #14/N4/content/manifests/content tests/docs/branch untouched.
- Exact parent CI39831337442/latest attempt1 raw allfive jobs/every step success;
  all28 Node pg conversation cases verified in prior completed database log. Old
  Flutter/Windows pending resolved; no hosted/provenance/Personal Alpha claim.
- Added backend/ai/deno.json and deno/runtime_test.ts, pinned standalone Deno2.9.6
  with manual npm-ci node_modules and cached-only checks/tests. Exact package-lock
  remains sole dependency authority; no independent Deno lock/re-resolve/download,
  no production import/provider/Auth/source/SQL/RLS/TLS/default/endpoint change.
- Strict Deno check covers every source and unit/native/Deno test without no-check;
  unchanged original168 unit cases run on both Node24 and Deno. Six real native
  Deno HTTP/permission cases: pinned version/denied external network/secrets/files/
  write/run/FFI/system, allfive original operations/fixed binding, Auth/method/owner
  rejection, chunked multibyte32KiB bound, deadline/late output/no redispatch, actual
  client disconnect/abort/no late commit. Servers close/finish; fixture ports only.
- Unit permissions deny network; web allows only127.0.0.1. Native pg task runs
  retained quota5/text9/conversation28 (42 total) under Deno against fixed disposable
  URL/localhost5432 with enumerated pg/test env/node_modules/contracts read only,
  no write/run/FFI/system. No local PostgreSQL binary; Deno native42 need new-head CI.
- Four mandatory Deno CI gates added in existing ai-boundary/database jobs with
  exact2.9.6 setup/version output, keeping every original command/step/job. QA now
  rejects each new step omitted/skipped/failed/pending behind green jobs (16 negative
  variants); no gate/old assertion removed. Inventory65/all14 release groups pending.
- Local actual Deno2.9.6/V815.0.245.2-rusty/TS6.0.3: strict check including cold
  dependency cache, all168 original cases and six native cases passed/no ignored.
  Node24 format/strict TypeScript/168 tests/audit0, Python QA30 and whitespace pass.
  Initial newly authored timeout assertion corrected to existing HTTP504 contract;
  production behavior unchanged. Deno default legacy request.signal warning after
  response delivery is observed; success/disconnect/cleanup pass without unstable
  flags, not suppressed by changing server semantics.
- Paths: .github/workflows/ci.yml; new backend/ai/deno.json, deno/runtime_test.ts,
  docs/AI_DENO_COMPATIBILITY.md; docs/AI_BOUNDARY.md, AI_CONVERSATION_RUNTIME.md,
  AI_CONVERSATION_RECOVERY_RUNTIME.md, PROJECT_STATUS.md; qa/matrix.json and
  qa/test_verify_qa.py. No production source/dependency/SQL/content edited.
- Separate source/permission/CI/diff review and complete GitHub tree/blob expected-
  head publication are recorded in released #41/#37/#31 handoffs. New-head allfive
  jobs/four added Deno gates/actual Deno pg42 required; parent evidence insufficient.
  Native PostgreSQL/full Flutter/Windows are CI checks, not local runtime results.
- Standalone Deno/Linux/npm/loopback fixtures are NOT deployed Supabase Edge runtime
  version/bundle/isolate/resource limits, hosted JWT/TLS/CA/PostgREST/approved real
  provider lookup provenance/network partition or learner proof. Next inspect exact
  head CI/native42, fix actual failures retaining guards; then actual Edge packaging/
  runtime evidence independently. Real provider decisions/configuration remain gated.
  Keep #31/#20/#22/#15/#13 open/#41 draft/all14 release groups/Personal Alpha pending.
  No deployment/provider strategy/Auth/wire/security reduction/spend/release/schedule
  change; no automatic default AI success or unverified lookup binding.


## Core checkpoint — #31 Supabase Edge user-worker probe, 2026-10-22 20:28 UTC

- Resume draft #41 / automation/issue-11-plan-sdk-integration from exact
  ef2200885b0748b3ebc2581953c881de76041b88, tree
  a3ae6384e11599b745f21189e05854b7021bf8d3 (549 blobs); main78a44fa unchanged.
  Marker core-20261022T2018-edge-worker; single core writer; #37 redirects here.
  Parent CI39840365647 latest attempt1 now allfive jobs/every step success,
  including allfour Deno gates. This resolves its prior platform-pending handoff;
  original Deno168+six native HTTP and real Deno pg42 remain component evidence.
- Add TEST ONLY edge/main.ts and edge/worker.ts. Original Contracts/Ajv/service/
  HTTP/recovery modules and static frozen schema/fixtures bundle into one ESM
  worker; no production source/test/SQL/RLS/Auth/provider/default/endpoint change.
  Pinned Deno2.9.6 bundle --check/--no-remote/--packages=bundle with unchanged
  npm-ci lock/manual node_modules; strict check covers both entrypoints. Official
  Supabase Edge Runtime v1.77.4 API/tag verified against pinned example/types/docs.
- Main calls real EdgeRuntime.userWorkers.create then worker.fetch: fixed path,
  no npm/remote module loading or forwarded env; bounded CPU/memory/wall time,
  no retry/fallback. Fixture memory receipt/Auth/quota/context/provider are test
  bindings only. No model/provider URL, real token/key, deployment or paid call.
- Bounded stdlib Docker runner resolves fixed official tag to local image ID,
  records registry digest/binary/user Deno versions/bundle hash/source+checkout
  head. Loopback random port/read-only mount/capability-drop/no-new-privileges/
  CPU-memory-PID caps; finite pull/HTTP/readiness/cleanup. Only captured container
  removed; redacted bounded fixture startup diagnostics cannot skip cleanup.
- Seven HTTP assertion groups: actual user-worker/version; allfive original wire
  operations/fixed operation/safe headers; completed replay/no dispatch and A/B
  fixture receipt isolation; missing/invalid Auth/method/unknown owner rejection;
  chunked multibyte32KiB before Auth; malformed provider strict safe failure/no
  completion; deadline/private abort/late result/no completion or redispatch.
- Mandatory CI Verify bundled Supabase Edge user worker plus Publish Edge
  user-worker compatibility evidence in existing ai-boundary job. Every prior
  workflow line/Node/Deno/native/SQL/platform check retained; artifact contains
  fixture-only metadata, never learner/header/provider/claim output. QA rejects
  either new step missing/skipped/failed/pending even behind green jobs (eight
  negative variants); original cases/findings/gates/assertions retained.
- Local observed: Node24 format/typecheck/168 tests/audit0; Deno2.9.6 format/strict
  check/168 original tests/six retained native HTTP+permission tests all passed.
  Deno bundle initially could not directly reach registry for internal esbuild;
  official v2.9.6 source pins0.25.5 and documents manual cache installation.
  Exact @esbuild/linux-x64@0.25.5 fetched through npm, then Deno built102 modules /
  363.83KB with zero residual imports. Actual self-contained standalone Deno
  execution with denied env/read/write/run/FFI/sys and only listener net passed
  allseven new protocol groups. This is bundle/fixture proof, NOT Edge isolate.
  QA31/inventory66/all14 hosted pending, Python syntax/whitespace checks passed.
- Paths: .github/workflows/ci.yml; backend/ai/deno.json; new backend/ai/edge/main.ts,
  edge/worker.ts and scripts/verify_edge_user_worker.py; new docs/AI_EDGE_USER_WORKER.md;
  docs/AI_DENO_COMPATIBILITY.md, AI_BOUNDARY.md, PROJECT_STATUS.md; qa/matrix.json,
  qa/test_verify_qa.py. Separate diff review checks old production/native/Pro bytes,
  workflow subsequence, old QA objects/assertions, permissions and cleanup.
- Local Docker/PostgreSQL/Flutter/Windows absent. New exact-head/latest-attempt
  full jobs/two added Edge gates and actual container logs/artifact still required;
  no container/isolate/native-platform pass inferred from local or parent proof.
  Keep #31/#20/#22/#15/#13 open/#41 draft/defaults unconfigured/Pro scope intact.
- Next inspect exact-head Actions, fix genuine failures without weakening tests.
  Then real authenticated upstream result-provenance adapter/configured hosted
  JWT/TLS/CA/PostgREST/A-B integration and learner/release evidence remain. The
  official local image is not proof of deployed hosted runtime equivalence,
  stress limits, real proxy disconnect, distributed fixture receipts or Personal
  Alpha. All14 release groups pending; no release/schedule change.


### Edge probe CI correction — 2026-10-22 20:32 UTC

- Exact65ecbbc / CI39849089985 latest attempt1 actual completed AI logs prove
  Node168/Deno168+six/native permission gates and typed102-module bundle passed.
  Edge gate failed before user-worker launch: the probe incorrectly assumed
  image tag1.77.4 equals CLI package version; artifact/final schema steps skipped.
  This is not Edge/isolate proof. Earlier pending observation superseded.
- Verified primary pinned v1.77.4 cli/src/flags.rs formats CLI0.1.0 (cli/Cargo.toml)
  and embedded Deno2.1.4 (deno/Cargo.toml). Corrected strict CLI two-line regex,
  stdout+stderr capture and actual worker Deno2.1.4 check. Image tag/digest/ID
  still recorded; no bypass/removal of runtime identity verification. Local
  standalone test passes explicit expected2.9.6 and cannot become Edge evidence.
- Only scripts/verify_edge_user_worker.py, docs/AI_EDGE_USER_WORKER.md and this
  status changed in follow-up. All seven original HTTP assertion groups and
  production/old tests/CI gates/Pro files unchanged. New exact-head Docker/full
  platform results remain required; #41 draft/all14 hosted groups still pending.


## Core checkpoint — #31 branded Edge runtime identity, 2026-10-22 UTC

- Fresh main78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c unchanged. Resume draft #41,
  branch automation/issue-11-plan-sdk-integration, parentb1908d8eda9206b89ab22db93ad970818fdfc497,
  tree028230cf61b39cc920c82bd2bc49444db3b990ed /553 blobs. Marker
  core-20261022T2119-edge-identity; one core writer; #37 redirects unchanged.
  Pro #14/N4/data/manifests/content tests/docs/branch reserved and untouched.
- Fresh exactb1908d8 CI39849667906/latest attempt1 is completed/failure, complete
  latest jobs5/all matching head+attempt. Repo-sanity/database/windows/flutter
  completed/success/every step, retaining vault/native lifecycle/SQL/Deno/native/
  web/Windows builds. AI earlier format/typecheck/Node168/Deno168+six/typed102-module
  bundle passed, Edge gate failed on user-worker metadata assertion; artifact and
  final schema projection skipped. This supersedes the previous pending handoff.
- Actual completed AI log reached user-worker fixture metadata, then rejected its
  Deno label because old probe expected plain2.1.4. Read primary pinned v1.77.4
  ext/runtime/js/bootstrap.js blob1a98593cee8882faa9206b8a274496b5e8166935 and
  release.yml: bootstrap emits supabase-edge-runtime-1.77.4 (compatible with Deno
  v2.1.4); release passes semantic GIT_V_TAG without v. CLI crate0.1.0 and Deno
  crate2.1.4 are separate identifiers. V8/TS are bootstrap-reported constants,
  not direct measurement of engine/compiler internals.
- scripts/verify_edge_user_worker.py now strictly checks entire three-field
  pinned reported fingerprint (branded Deno string/V811.6.189.12/TS5.1.6), with
  fixed failure that echoes no input. Plain compatibility version, wrong image,
  compatible Deno mismatch, missing/extra/changed fields and suffixes rejected
  before AI HTTP operations. CLI two-line regex and official image/digest pinning
  remain; Docker entrypoint supplies no override. Explicit standalone expected
  complete metadata remains test-only and cannot become Edge execution evidence.
- Four new qa/test_edge_runtime_identity.py regressions: official branded tuple
  and reordered JSON object; nine wrong/plain/mixed/suffixed Deno identifiers;
  missing/extra/malformed/mixed reported fields without echo; actual probe with
  TEST ONLY HTTP metadata rejects wrong identity after one GET and before POST
  or any Docker operation. All35 QA cases passed; inventory66/all14 release
  groups pending. Original31 QA assertions/cases/findings/gates retained; existing
  Edge case only gains an executable anchor. CI workflow unchanged.
- Five paths: scripts/verify_edge_user_worker.py; new qa/test_edge_runtime_identity.py;
  qa/matrix.json; docs/AI_EDGE_USER_WORKER.md and PROJECT_STATUS.md. Separate diff
  review confirms all original seven HTTP assertion groups byte-identical after
  identity guard, every original workflow/production/native/SQL/dependency/Pro
  byte unchanged. No provider/Auth/default/endpoint/RLS/TLS/deployment/spend change.
- Local Node24 format/typecheck/all168 passed; Deno2.9.6 strict check covers all
  source/unit/native/Edge entrypoints. Fresh source typed bundle102 modules/
  363.83KB built with pinned Deno/internal esbuild0.25.5; direct helper-registry
  network failed, exact npm helper/manual SDK cache fallback used as documented.
  Actual standalone bundled Deno with denied env/files/write/run/FFI/sys and
  listener-only net passed allseven unchanged HTTP groups with explicit full
  Deno2.9.6 metadata. Python syntax/QA35/inventory/whitespace passed. These fixture
  results do NOT establish Supabase Edge execution; local Docker/native SDKs absent.
- Next inspect new exact-head/latest-attempt allfive jobs/both Edge gates/actual
  complete AI log and evidence artifact; fix observed errors retaining assertions.
  Real authenticated upstream adapter/provenance and hosted JWT/TLS/CA/PostgREST/
  A-B/learner proof remain, not certified by a runtime metadata string. Keep #41
  draft/#31/#20/#22/#15/#13 open/defaults unconfigured/all14 release groups pending;
  no merge/issue closure/production release/schedule change.


## Core checkpoint — #31 explicit trusted server assembly, 2026-10-22 UTC

- Fresh main78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c unchanged. Resume draft#41 /
  automation/issue-11-plan-sdk-integration, parent15896c53573e205c016c790c42aa0e4427c74262,
  base0c5ed53c0a948cfbb1d5de15442d11ea14feddb3/554 blobs. Single core writer marker
  core-20261022T2218-trusted-assembly; #37 redirects unchanged. Pro #14/N4/data/
  manifests/content tests/docs/branch reserved and untouched.
- Exact-parent CI39856656219/latest attempt1 now allfive jobs/every step completed/
  success (no skips), superseding old pending handoff. Actual completed AI log
  proves allseven Supabase v1.77.4 main-to-user-worker HTTP groups passed. Artifact
  ai-edge-user-worker ID12459851532/zip digest3a9d7bb1736db5ebd029770e5ce5b5368980d6967c251dc4f120f2f0d10c174a,
  source15896c5; registry image digestad45164b7548bf5820ed7be714789c17ac2865edce79a09cfb4c3756c3d365a8,
  bundle749ba4a178e2d0d9a3dfeecbfe3536fa2db2fe6281559f29f6b6e17933c57759.
  Reported V8/TS literals are not direct engine measurement. This proves parent
  Edge fixture portability, not hosted Auth/provider/SQL inside Edge or release.
- New trusted_runtime.ts composes SupabaseAuthVerifier, verified-TLS owned pg quota,
  text context and atomic conversation drivers with fixed five HTTP handlers.
  Explicit createTrustedPostgresAiHandlers requires trusted server HTTPS origin/
  public key/database URL and mandatory caller provider; construction performs no
  I/O, selects no provider, reads no environment and installs no listener/default.
  Existing URL/key/SSL-override validation and fixed application names retained.
- Lower assemblePostgresAiHandlers is an explicit host-only seam with exclusively
  owned factories. Captures Auth/provider/lookup functions and receivers plus
  three connection factory functions/receiver before async work, freezes dependency
  container/wrappers/returned exact-five handler table. Caller still owns mutable
  factory/provider/lookup internals and resources; no cloning/freezing/automatic
  close or SDK session ownership. Request query/body cannot select operation.
- Real existing drivers retain short transaction/COMMIT-before-provider/no-open-
  transaction-during-provider/COMMIT-before-success and abort/late-response guards.
  Immutable fail-closed legacy receipt sentinel prohibits memory/split fallback;
  optional lookup-only recovery binds exact same internally owned conversation
  store and captured method. Missing recovery keeps pending unavailable without
  reset/acquisition/redispatch. No RLS/TLS/SQL/default/Auth strategy/provider/wire/
  spend/collection/endpoint/deployment/production deletion change.
- Twelve new tests use actual Supabase verifier with TEST ONLY HTTP, actual drivers
  with TEST ONLY SQL protocol replies and TEST ONLY provider: allfive operations/
  exact owner-op parameters/COMMIT and close counts, immutable handlers/no initial
  I/O, trusted config rejection/missing provider, Auth/quota/uncertain COMMIT failure,
  captured methods/receivers/factories, A/B/A without identity cache, same-store
  recovered success without acquire/provider, no-recovery pending and cancel during
  quota COMMIT with ignored late delivery/close once. Turn reserves assistant2
  under existing coherent-driver rules; frozen wire models unchanged.
- Local observed Node24 format/strict check/all180 (168 original+12 new), production
  audit0; pinned Deno2.9.6 strict check/all180 passed/no skips. Python QA35 and
  inventory67/all14 hosted pending/whitespace passed. Existing Node/Deno test glob
  includes new file; workflow/old source/tests/native assertions/dependencies/SQL/
  Edge probe/Pro bytes unchanged. Separate review confirms no dropped old QA
  cases/findings/gates/assertions or old runtime logic; all three owned factories
  still use certificate verification, fresh connection/short transactions.
- Seven paths: new backend/ai/src/trusted_runtime.ts, test/trusted_runtime.test.ts,
  docs/AI_TRUSTED_RUNTIME.md; docs/AI_BOUNDARY.md, AI_EDGE_USER_WORKER.md,
  PROJECT_STATUS.md and qa/matrix.json. New exact-head latest-attempt full CI remains
  required; parent platform/Edge/native results cannot substitute. Local native
  PostgreSQL/Docker/Flutter/Windows absent; new assembly lacks native hosted/Edge
  transport proof. Existing Edge bundle uses fixture ports and is not this assembly.
- Next inspect new exact-head allfive jobs/every step/Node+Deno180/retained Edge7/
  pg42, fix genuine failures retaining assertions/security. Then add native full
  assembled transport/Edge/PostgreSQL proof independently of live provider choices;
  real authenticated upstream adapter/provenance, hosted JWT/TLS/CA/PostgREST/A-B/
  learner gates remain. #31/#20/#22/#15/#13 open/#41 draft/defaults unconfigured/
  all14 release groups/Personal Alpha pending. No merge/issue closure/release or
  schedule change.


## Native full-handler PostgreSQL assembly checkpoint (2026-10-22 23:18 UTC)

- Continue draft #41 / automation/issue-11-plan-sdk-integration from exact source
  dee799f5e741a8594a4f89c95a46a5ffb627bead (base tree
  3d9de71f1c36f42c89d8dc1a3119712810e990b1 /557 blobs), main78a44fa unchanged.
  Marker core-20261022T2314-assembly-native, one core writer; #37 redirects here.
  #14 Pro/N4/data/manifests/content tests/docs/branch remain reserved and untouched.
- Resolve prior waiting checkpoint: source dee799f has observed
  [CI39864435084](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39864435084),
  latest attempt1 completed/success/allfive jobs/every step/no skipped steps.
  Retained Node/Deno180, native PostgreSQL42 and Edge7 passed at that parent.
  Parent evidence does not execute the new suite below.
- Add eight native cases through the actual assembled fixed Request/Response
  handlers, Supabase verifier (TEST ONLY Auth HTTP), actual pg/PostgreSQL17 SQL
  and TEST ONLY provider/plaintext/lost-delivery injection. Allfive operations,
  durable ended session/ordered slots/completed receipt+reservation, fresh closure
  replay after source/profile changes, two independent instances/same-event and
  reserved-session races, real acquire/complete COMMIT followed by lost delivery,
  A/B foreign-session NOT_FOUND (same existing SQL policy), forged owner/bad Auth,
  malformed result durable pending/no public writes/redispatch, text retirement
  and final quota denial. Provider entry requires every connection closed and
  no matching real pg transaction; COMMIT must reach idle before injection.
- Add mandatory Node native assembly database gate; append file to retained
  permission-bounded Deno pg task (42+8=50). Retain every original workflow step,
  native/SQL/unit/Edge/platform check. QA adds this gate to exact-head assurance
  and rejects missing/skipped/failed/pending evidence; all14 release groups pending.
- Eight paths: new backend/ai/test/trusted_runtime.native.ts; backend/ai/package.json,
  deno.json; .github/workflows/ci.yml; qa/matrix.json, test_verify_qa.py;
  docs/AI_TRUSTED_RUNTIME.md and this status. Production source/SQL/TLS/locks/
  dependencies/RLS/default app/approved provider strategy untouched. No live call,
  hosted migration/deployment or production data access.
- Local observed: npm format:check + strict TypeScript passed; strict Deno2.9.6
  checks include new native file; Node180/180 and Deno180/180 passed, no skips;
  QA36/36 passed; inventory68 valid with all14 integrations pending. No local
  PostgreSQL/Docker or Flutter SDK: native8/combined Deno50 and platform builds
  require NEW exact-head Actions; authored assertions are not observed proof.
- Separate review: native expectations align with unchanged SQL/error mappings;
  all prior source/tests/SQL/dependency locks/Pro files preserved. Persist via
  correct base tree, full tree/blob readback and expected-head non-force CAS;
  final commit/CI/RELEASED marker recorded in #41/#37/#31 handoff.
- Next: inspect new exact-head full/latest-attempt jobs and actual native results;
  if green, independently stage full PostgreSQL assembly inside actual Edge user
  isolate. Native handlers do not prove that isolate/network listener, real TLS/CA,
  hosted Auth JWT/signature/expiry/A-B/PostgREST, approved live provider/lookup
  provenance or learner acceptance. #31 stays open/#41 draft; no Alpha sign-off.


## Full PostgreSQL Edge user-isolate probe checkpoint (2026-10-23 00:22 UTC)

- Resume draft #41 / automation/issue-11-plan-sdk-integration from exact source
  c7ec35bb546752e9c883864d58207ed1b6a89aad, base tree
  7911ac4b706a062649c5ca5311870006feff2c19/558 blobs; main78a44fa unchanged.
  Marker core-20261023T0016-edge-postgres; one core writer; #37 redirects here.
  #14 Pro/N4/data/manifests/content tests/docs/branch remain reserved/untouched.
- Resolve prior waiting checkpoint: observed parent
  [CI39870924303](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39870924303)
  latest attempt1 completed/success/allfive jobs/every step/no skips. Actual completed
  database120144866077 log confirms all eight new assembled handler cases passed
  on Node24 and combined native50/50 on Deno2.9.6. No fixture-to-hosted equivalence.
- Add separate TEST ONLY edge/postgres_main.ts + postgres_worker.ts. Actual trusted
  assembly/Supabase verifier/pg quota/text/atomic conversation/service/five handlers
  are bundled with original contracts/schema; fixed disposable localhost PostgreSQL
  and Auth HTTP/provider/lost-delivery fixtures. Fixed operations only; no environment,
  learner URL/key, default endpoint/provider decision or production TLS-off option.
- New Python runner checks exact disposable DB before any command/container,
  seeds seven fixture users/two scenarios/one grammar (no canonical content edits),
  strictly validates response UUIDs before SQL, launches two capped official Edge
  v1.77.4 containers, then replaces one with a fresh container over the same DB.
  Actual main-to-user crossing/no npm/remote modules/host env; immutable imageID,
  read-only mount/cap-drop/no-new-privileges,512MiB/2CPU/128PID each. Linux CI host
  network reaches fixed loopback pg only; explicit --ip127.0.0.1 HTTP ephemeral
  listener flags verified in pinned official flags.rs. Cleanup only captured IDs;
  finite readiness/Docker/HTTP/SQL/provider-hold bounds; no mutation retry.
- Seven planned groups: pinned actual-isolate runtime; allfive HTTP operations and
  durable ended session/slots0,1,2/completed receipts+reservations; A/B denial and
  independent-instance replay after source/profile retirement; real acquire/complete
  COMMIT before lost delivery; malformed result durable pending/no session write;
  concurrent instance one-dispatch and host-observed no SQL transaction held across
  provider; fresh-container original replay/pending no redispatch/all connections
  closed. Scenario-specific owners remain below unchanged burst10 quota; no reset.
- Mandatory database CI execution and artifact publication added after retained
  native Node8/Deno50. Existing memory-port Edge7 and all prior workflow lines/
  SQL/native/Node/Deno/platform assertions remain. New task bundle:edge-postgres;
  QA inventory69, all14 pending groups unchanged; QA negative missing/skipped/
  failed/pending execution or publication cannot count as success. Six fixture
  guard regressions reject wrong DB before subprocess/container, wrong runtime
  before SQL/POST, invalid/untrusted UUID SQL interpolation; both captured
  containers still get cleanup attempts after first diagnostics/removal failure.
- Local observed: strict TS + Deno2.9.6 checks include both new entrypoints;
  Node180/180 and Deno180/180 passed/no skips; format:check and deno fmt edge/JSON
  passed; QA43/43 passed; inventory69 valid; Python compile/whitespace passed.
  Checked bundle148 modules/581994 bytes/SHA256
  afd0290c6945909cced1d1abb98477de6cce874042d796979e390a80a647ff79.
  Direct registry for SDK helper unavailable: exact npm esbuild0.25.5 installed in
  SDK cache then bundle passed, no application dependency/lock/CI override.
- Twelve paths: new backend/ai/edge/postgres_main.ts, postgres_worker.ts,
  scripts/verify_edge_postgres.py, qa/test_edge_postgres.py, docs/AI_EDGE_POSTGRES.md;
  backend/ai/deno.json; .github/workflows/ci.yml; qa/matrix.json, test_verify_qa.py;
  docs/AI_EDGE_USER_WORKER.md, AI_TRUSTED_RUNTIME.md and this status. Production
  source/SQL/RLS/TLS/old tests/npm locks/Pro bytes unchanged. Separate diff review
  precedes full tree/blob readback and expected-head non-force CAS publication;
  actual commit/CI/RELEASED handoff maintained in #41/#37/#31.
- Local Docker/PostgreSQL/Flutter absent; new seven Edge/SQL groups and platform
  builds require NEW exact-head Actions, not inferred from local bundle or parent CI.
  Next fetch full latest-attempt jobs/every required step/exact head and actual logs;
  fix real compatibility failures without weakening assertions. Even success does
  not prove hosted TLS/CA, real JWT issuer/signature/expiry/PostgREST, approved live
  provider/authenticated lookup/cost/voice or learner acceptance. #31 open/#41 draft,
  all14 release groups/default app bindings unconfigured; no Alpha sign-off/pause.


## Edge PostgreSQL cold CommonJS bootstrap correction (2026-10-23 01:14 UTC)

- Resume draft #41 / automation/issue-11-plan-sdk-integration from exact source
  8ef704f7dc8eadfb9915698391a3095f650af6e5, base tree
  b1a316b25fe26b5540d2bba0b409dfdd692bf75d/563 blobs. Main78a44fa and #37 afa572a
  unchanged. Marker core-20261023T0112-edge-node-bootstrap; one core writer;
  Pro #14/N4/data/manifests/content tests/docs/branch reserved and untouched.
- Actual [CI39877892790](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39877892790)
  latest attempt1 completed/failure. AI/repo-sanity/windows all steps success;
  database120167880018 failed new Edge PostgreSQL startup. Evidence artifact and
  profile projections skipped; Flutter job skipped. Full workflow did NOT pass.
  Completed DB log explicitly shows Node native assembly8 and Deno native50 passed.
- Actual user-isolate boot raises ReferenceError Buffer is not defined while
  evaluating pinned postgres-bytea, GET/__probe502, before fixture seeding or any
  new seven-group SQL/HTTP assertions. Bundled CommonJS pg graph bypasses npm global
  initialization. Read fresh pinned pg/pgpass source: process also used unbound.
- Add TEST ONLY postgres_node_globals.ts using actual node:buffer Buffer and
  node:process, defining only absent globals/preserving existing runtime bindings.
  No host env copy, stub/simulated process/SQL success or permission addition.
  New postgres_bootstrap.ts initializes first, then dynamic-imports unchanged
  postgres_worker.ts. Checked bundler inlines that graph without runtime npm or
  remote loading. Only pg bundle entry changes; no production source/default,
  SQL/RLS/TLS/dependency lock/Auth/provider strategy or existing Edge probe edits.
- One new cold CommonJS test runs in retained Node/Deno unit globs and unchanged
  permissions: synchronously remove globals, reproduce actual postgres-bytea import
  failure, install actual builtins, load actual pg and decode bytea UTF8/binary
  bytes; re-entry preserves supplied runtime identities/descriptors. Finally restores
  original globals before yielding. All prior180 unit assertions retained.
- Local observed: format:check +strict TypeScript; strict Deno2.9.6 checks and
  edge/JSON formatting; Node181/181 and Deno181/181 passed/no skips; QA43/43;
  inventory70/all14 integration groups pending; whitespace passed. Checked bundle
  150 modules/594983 bytes/SHA256
  df6ba27afc49b40be3589b2186514faf1b2f80158e5c04056ee86a544ce40de5.
  Direct registry SDK helper unavailable; exact npm esbuild0.25.5 atomically restored
  into SDK cache, build passed with no application dependency/lock/CI override.
- Separate bundle inspection confirms initializer executes before inlined worker
  initialization. Local standalone Deno cold bundle import with globals absent,
  intercepted Deno.serve and denied net/write/run/ffi/sys returned metadata200,
  zero connections/provider. This is module-order proof only, NOT actual Edge
  user-isolate/SQL or hosted evidence. Local Docker/PostgreSQL/Flutter absent.
- Seven paths: new backend/ai/edge/postgres_node_globals.ts, postgres_bootstrap.ts,
  test/postgres_node_globals.test.ts; backend/ai/deno.json; qa/matrix.json;
  docs/AI_EDGE_POSTGRES.md and this status. Separate review preserves original
  source/worker/scripts/SQL/old tests/dependencies/Pro bytes; every old CI gate,
  seven actual Edge/SQL groups, quota/COMMIT/ownership/replay assertions and runtime
  limits/permissions unchanged. Correct base tree/full tree+blob readback/one-parent
  expected-head non-force CAS before publication; commit/CI/release in #41/#37/#31.
- Next inspect NEW exact-head latest-attempt allfive jobs/every required step,
  actual new Edge PostgreSQL groups and evidence. Fix genuine compatibility failures
  without weakening tests/security; fixture/default success not a substitute.
  Actual hosted TLS/CA/JWT issuer/signature/expiry/PostgREST, approved live provider/
  authenticated lookup/cost/voice and learner acceptance remain missing. #31 open,
  #41 draft/all14 release groups/default bindings unconfigured; no Alpha or pause.


## Edge PostgreSQL transport preflight / safe diagnostic checkpoint (2026-10-23 02:22 UTC)

- Resume draft #41 / automation/issue-11-plan-sdk-integration from exact source
  d875fd335f3bd9ae843c705a7ed474220c591525, base tree
  cf5450e3997deeae65efdb2167e0247e483ec6f8/566 blobs; main78a44fa/#37 afa572a unchanged.
  Marker core-20261023T0216-edge-transport-probe; one core writer;
  Pro #14/N4/data/manifests/content tests/docs/branch reserved/untouched.
- Actual [CI39882989584](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39882989584)
  latest attempt1 completed/failure: database120184498914 fails first tutor_explain
  request503 after BOTH actual user-isolate pinned metadata checks +fixture seeding.
  This confirms Buffer boot correction in that scope; empty safe container logs
  leave transport phase/root cause unknown. Completed DB log retains native Node8
  and Deno50 passed. AI/repo-sanity/windows pass; Edge artifact/profile projections
  and Flutter skipped. No full-CI or new full Edge/SQL acceptance claim.
- Add TEST ONLY postgres_probe.ts: extract same fixed disposable pg factory,
  preserve timeout/pipeline/owned connection/COMMIT idle/injected lost-delivery
  semantics; add fixed phases and bounded distinct failure categories, max8 pairs
  per fixture lane. No raw exception code/message/stack/SQL/URL/token/learner data
  enters metrics. Unknown/hostile getters map to unknown; original errors rethrown
  to unchanged production drivers, not simulated SQL or unconditional success.
- Add fixed GET/__probe/transport read before fixture seeding and on fresh restart.
  Same owned factory must actually connect, SELECT1 return exact SELECT/one row/
  numeric1 and pg ReadyForQuery idle; finally closes. No caller SQL/config/Auth,
  quota/provider work or application writes. Adds one actual transport group
  before original seven full-handler groups; all old assertions/gates retained.
  Transport success can never stand in for the five handlers or hosted proof.
- Fixture runner failure snapshot strictly validates exact lanes/fields, integer
  counters0..1000 (no booleans), fixed phase/category enums and max8 failures before
  printing. Unknown/private fields rejected; snapshot failure prints a fixed line
  only. Cleanup remains in outer finally even if snapshot reporting fails; existing
  both-container cleanup regressions unchanged. No new runtime permission/logging
  in production/default app; no secrets or live config asked/used.
- Three new Node/Deno cases prove bounded redaction/deduplication/hostile getters,
  exact preflight result and one close, no query after connect failure/query failure
  close/constructor failure. Added QA case rejects raw fields/categories, excessive
  counters/arrays, bool-as-int and snapshot exception leaks. Existing executable
  getTransactionStatus anchor moves from worker to extracted helper; assertion is
  preserved, not replaced by a comment. Original70 cases otherwise retained +1=71;
  all findings/gates/all14 pending release groups unchanged.
- Local observed: strict TS +Deno2.9.6 checks/edge formatting +npm format:check;
  Node184/184 and Deno184/184 passed/no skips; QA44/44; inventory71 valid;
  Python compile/whitespace. Checked bundle151 modules/599249 bytes/SHA256
  ae2eb4c157dc98d2a704a758ad619f48071cc01598b9d6ba456332973382a383.
  Direct registry SDK helper unavailable; exact npm esbuild0.25.5 cached atomically
  after verifying version, build passed; no app dependency/lock/CI override.
- Eight paths: new backend/ai/edge/postgres_probe.ts and test/postgres_probe.test.ts;
  backend/ai/edge/postgres_worker.ts; scripts/verify_edge_postgres.py;
  qa/test_edge_postgres.py, qa/matrix.json; docs/AI_EDGE_POSTGRES.md and this status.
  Separate review preserves production source/SQL/TLS/Auth/provider/default/npm locks/
  all old tests/Pro bytes, original seven full-handler probes and runtime permissions.
  Correct base tree/full tree+blob/one-parent readback before expected-head non-force
  CAS; commit/CI/RELEASED handoff recorded in #41/#37/#31.
- Local Docker/PostgreSQL/Flutter absent: new SELECT1 and actual eight-group
  Edge/SQL execution require NEW exact-head CI; this increment does not claim the
  original503 root cause is found/fixed. Next inspect safe phase/category snapshot
  if preflight or handlers fail, retain every check while implementing a real fix.
  Hosted TLS/CA/JWT issuer/signature/expiry/PostgREST, approved live provider/lookup/
  cost/voice and learner acceptance still missing. #31 open/#41 draft/defaults
  unconfigured/all14 release gates pending; no Personal Alpha acceptance or pause.


## Client constructor global alias correction (2026-10-23 03:14 UTC)

- Fresh #41 head464360edea1bca0e2e2869ced0f9716183e86918, correct base tree
  1c229837adddad6b07cc2bfd8f481bb84abc694e/568 blobs; main78a44fa/#37 afa572a
  unchanged. Single writer marker core-20261023T0314-pg-global-alias; Pro #14/#38
  N4/data/manifests/content tests/docs/branch reserved and untouched.
- Actual [CI39889372926](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39889372926),
  exact parent/latest attempt1 completed/failure. Allfive jobs/each step inspected:
  repo-sanity/ai-boundary/windows successful; database120205166163 fails actual
  user-isolate SELECT1 preflight503 BEFORE seed. Strict safe snapshot reports
  transport construct/missing-global, opened0, no handler/provider calls. Edge
  artifact/profile projections and Flutter skipped. Native Node8/Deno50 retained
  successful in completed DB log; no full-CI/Edge PostgreSQL pass.
- Pinned actual pg8.23.1 client.js constructor selects c.Promise || global.Promise;
  bootstrap initialized only Buffer/process. Add TEST ONLY absent global alias to
  actual globalThis before bundled graph initialization. Preserve existing binding
  identity/descriptors and let forbidden definitions fail. No Promise override,
  environment copy, fake SQL/provider success or runtime permission change.
- Added synchronous actual pinned Client constructor regression: delete global,
  reproduce ReferenceError, initialize actual alias, construct Client and verify
  intrinsic Promise plus not connecting/connected, destroy unconnected real socket,
  restore original global descriptor in finally. Explicit truthy environment-backed
  fixture parameters avoid reading env under unchanged denied permissions; no
  connect/query/replication/options sent to a server. Original cold bytea parser
  assertions retained; existing-binding fixture now includes global sentinel.
- Local format:check/strict TypeScript +Deno2.9.6 check/edge fmt passed; Node185/185
  and Deno185/185 passed/no skips; QA44/44; inventory71/all14 release cases pending.
  Local Docker/PostgreSQL/Flutter absent; actual new Edge transport/eight fullgroups
  must execute in NEW exact-head CI. Bundle evidence/checkpoint follows in PR bodies.
- Four paths: backend/ai/edge/postgres_node_globals.ts, test/postgres_node_globals.test.ts,
  docs/AI_EDGE_POSTGRES.md and this status. Separate review retains production src,
  Auth/TLS/SQL/RLS/quota/receipts/timeout/owned factory, fixed SELECT1/idle guards,
  all original full-handler cases/scripts/CI/runtime limits, dependencies/locks,
  QA release gates and Pro files. Correct full tree/blob/parent readback before
  expected-head non-force CAS; final actual commit/run/RELEASED in #41/#37/#31.
- Next inspect exact new head/latest attempt/allfive jobs/every required step and
  actual transport/eight-group Edge SQL artifact. Constructor fixture success does
  not prove native Edge connectivity; if actual probe fails use safe phase snapshot
  and fix real cause without bypassing assertions. Hosted TLS/CA/Supabase JWT issuer/
  signature/expiry/PostgREST, approved provider/authenticated lookup/cost/voice and
  learner acceptance remain missing. #31 open/#41 draft/default bindings/all14
  release groups pending. No merge/issue closure/Alpha acceptance/pause.

Local corrected checked bundle:151 modules/599374 bytes, SHA256
`bf62a857b3554b815c5fcd5fd52939eaaa2c59e0937ac143d8389d1da4423b81`.
SDK internal helper registry refused connection; exact npm esbuild0.25.5 verified
and atomically cached, then build passed. No application dependency/lock/CI change.
Separate diff review preserves the entire original bootstrap test except adding
the runtime-global preservation sentinel; production/SQL/old probe/CI/Pro files
byte-identical. Bundle order inspected: initializer before inlined worker graph.


## Edge PostgreSQL distinct-event serialization checkpoint (2026-10-23 04:18 UTC)

- Fresh main78a44fa; #37 redirects to draft #41 branch
  automation/issue-11-plan-sdk-integration, exact parent
  2cc9987fbd5869b42d92999da39c3bc30e85a509/base tree
  20ca8fcd683588855d61aaf97b30a0eeafff78a9/568 blobs. One core writer marker
  core-20261023T0417-edge-distinct-events; Pro #14/#38/N4/data/manifests/content
  tests/docs/branch reserved/untouched. #31 acceptance/dependencies re-read.
- Observed [CI39894048642](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39894048642)
  exact parent/latest attempt1 completed/success. Full allfive jobs/every required
  step successful/no skips: repo-sanity120220214827, ai-boundary120220214738,
  database120220214584, windows120220289711, flutter120220697680. Actual completed
  DB log proves native Node8/Deno50 and original eight actual Edge PostgreSQL groups;
  mandatory evidence uploaded, exact-head nonexpired artifact12476550226/archive
  sha256:1e8bf982c971b0fdd30a67ed8fdcf4267ad1889ac431ee8b949ecf460df65b26.
  Source2cc9987/Actions merge checkoutdf52fc7/bundlebf62a857... recorded in log.
  Prior global constructor correction now confirmed in that actual Edge/SQL scope.
- Complete new #31 assurance increment: ninth actual group holds real reserved turn
  in one user isolate and sends distinct turn/finish from another. Require409
  SYNC_CONFLICT/no provider, zero rejected receipts/public writes, slots[0], one
  pending reservation/unended session and no SQL transaction across provider wait.
  Always release held provider in finally. Explicit retry of same rejected IDs after
  original COMMIT must yield assistant sequences2/4, exact slots0..4/ordered user
  texts, ended/four completed joined reservations/zero pending and exact dispatch
  counts. Fresh-container replay returns both original turns/finish, no dispatch or
  connection leak. Adds fixed TEST ONLY held_turn route using existing binding and
  eighth disposable owner; previous owner IDs/metrics/limits preserved. Nine quota
  attempts including replay; no reset/refill timing/bypass/automatic mutation retry.
- Two new negative QA regressions reject orphan rejected receipt, missing/reordered
  slots/texts, remaining pending/missing completion/unended session and verify held
  provider release. These are mock oracle regressions, not native concurrency proof.
  Adds one QA case with executable anchors; original71 cases/findings/gates and all14
  pending release cases retained. Original eight actual groups/assertions mandatory.
- Local observed format:check/strict TS +Deno2.9.6 check/edge fmt; Node185/185 and
  Deno185/185 passed/no skips; QA46/46; inventory72 valid; Python compile/whitespace.
  Local Docker/PostgreSQL/Flutter absent; NEW actual ninth group/SQL assertions need
  new exact-head CI. Bundle result/commit/run/released checkpoint follows in bodies.
- Six paths: backend/ai/edge/postgres_worker.ts; scripts/verify_edge_postgres.py;
  qa/test_edge_postgres.py +matrix.json; docs/AI_EDGE_POSTGRES.md +this status.
  Separate diff preserves production src/SQL/RLS/Auth/TLS/quotas/receipts/defaults,
  dependencies/locks/workflow/runtime limits/permissions and Pro bytes. Publication
  requires correct base/full untruncated tree +all exact changed blobs/one-parent
  verification and expected-head non-force CAS; actual heads/CI in #41/#37/#31.
- Next inspect new exact-head latest-attempt complete allfive jobs/every required
  step +DB log/artifact before more code. Fix genuine failures preserving assertions;
  pending-only means handoff, no duplicate implementation. Hosted TLS/CA/JWT issuer/
  signature/expiry/PostgREST/approved provider/authenticated lookup/cost/voice and
  learner acceptance missing; #31 open/#41 draft/all14 release groups/default
  bindings pending. No merge/issue closure/deployment/Personal Alpha signoff/pause.

Local checked extension bundle:151 modules/599497 bytes/SHA256
`17360c95acfbd46e947cf60488d8f688351c26d824fc5d4934d1db2b3536cd77`.
SDK helper registry refused connection; verified exact npm esbuild0.25.5 atomically
cached before successful checked build, no application dependency/lock/CI override.
Separate preservation review compares AST: all21 old probe check calls and all old
helper function bodies retained; all71 old QA case objects/gates/findings unchanged.
Only six intended files differ; new actual ninth-group pass awaits exact-head CI.


## Reading domain / independent Issue #34 checkpoint (2026-10-23 05:17 UTC)

- Fresh main78a44fa; #37 redirects to draft #41 branch
  automation/issue-11-plan-sdk-integration, exact parent
  3c47ceb20194c5b21edf4e1e230b2723b7922222/base tree
  9a8f7ce24e356019d6d502b4593c0bd7aa490ed6/568 blobs. One core writer marker
  core-20261023T0513-reading-domain; Pro #14/#38/N4/data/manifests/content tests/
  documents/branch reserved/untouched. No parallel agent or default activation.
- Exact parent [CI39899724078](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39899724078)
  latest attempt1 completed/success: full allfive jobs/every step success/no skips.
  Database120238265739 completed log proves all9 actual Edge/PostgreSQL groups,
  including distinct-event pending fence/rollback/ordered retry and fresh replay;
  Deno native50 passed, mandatory artifact upload succeeded. Printed source3c47ceb/
  Actions checkout5fd3a27/bundle17360c95... observed. #31 remains open for hosted
  TLS/CA/JWT issuer/signature/expiry/PostgREST and approved live provider/authenticated
  lookup/voice/learner evidence; no provider or Auth strategy chosen/activated.
- Select independent #34 acceptance explicitly permitting original parser/model
  work before reviewed material/audio. #11/#12 typed libraries and valid-session
  foundations present; reviewed reading assets/audio and integrated learner proof
  remain missing. Read AUTO_LEARNING/spec/API/database/security and actual issue.
- Complete pure reading domain: separately documented local import v1 bounded at
  256KiB UTF8/50 passages/10 questions/2-4 choices, strict exact keys/types/N5-N4/
  positive version, required Japanese/readings/Vietnamese/attribution metadata,
  duplicate IDs/labels and missing answer rejection. Validate whole catalog before
  filtering, fixed safe errors with no raw JSON. Private constructors/unmodifiable
  nested lists, stable level/id/version snapshot, first valid answer per question,
  all-answers completion and deterministic correctCount with immutable answers.
  Captured key rejects another passage/level/version; new round starts empty.
- No source/license authenticity or linguistic review inferred from metadata.
  Local answer keys/score are practice only and authorize no minutes/mastery/SRS/
  persistence/sync. Text-only importer accepts no audio_ref/default fake audio or
  success; no player/capture/retention/spend, UI/content asset or endpoint change.
  Original frozen contracts/SQL/Auth/security/seven plan blocks unchanged.
- Eleven new TEST ONLY parser/scoring cases cover exact level/readings/translation/
  order/empty/max collections/immutable copies, UTF8 limits/safe decoder errors,
  malformed hidden-level entries/duplicates/invalid IDs/version/field/choice/answer,
  first-answer, stale snapshot/reset/mixed score. These are new reading-domain
  fixtures, not reviewed N5/N4 curriculum or changes to Pro content tests.
- Local observed: official Dart3.9.2 archive SHA256 verified; both repository files
  formatted. Identical model/PreviewLevel and all11 test bodies copied to disposable
  pure-Dart harness, only flutter_test import replaced by package:test1.26.2.
  Strict casts/inference/raw-types +recommended lints analyzed with no issues;
  11/11 pure-Dart tests pass/no skips. No repo SDK/dependency/lock modification.
  Formatter warned unresolved Flutter lint include locally; actual Flutter format/
  analyzer/tests/web/Windows remain NEW exact-head CI work, not locally passed.
  QA46/46/inventory73/Python checks/whitespace passed; all14 release cases pending.
- Five paths: new apps/flutter_app/lib/features/reading/domain/reading_material.dart,
  test/features/reading/reading_material_test.dart, docs/READING_MATERIAL.md;
  qa/matrix.json +this status. Old72 QA cases/gates/findings/assertions and all
  prior Dart/backend/SQL/CI/defaults/assets/Pro bytes retained. Separate review +
  correct base/full tree/all exact changed blobs/one-parent readback required before
  expected-head non-force CAS. Final commit/run/RELEASED in #41/#37/#34; #31 gets
  observed nine-group handoff, no completed-issue claim.
- Next inspect new exact-head latest-attempt complete allfive jobs/every step;
  fix genuine Flutter failures without weakening gates. Pending-only handoff/no
  duplicate implementation. Then trusted bounded reading repository/version mapping,
  explicit loading/error/empty/offline reading UI and captured-session/durable valid
  study reports; reviewed material/audio remain separate and coordinated. #34/#31
  open/#41 draft/all14 release groups/default lessons pending; no merge/issue close/
  deployment/Personal Alpha acceptance/pause.


## Reading repository / independent Issue #34 checkpoint (2026-10-23 05:37 UTC)

- Parent83276f435cf98662bbb76f1a66761ead4392a162, full clone; latest parent
  CI39905018821/attempt1 completed success. All five jobs/every listed required
  step succeeded, including Flutter format/analyze/full tests/Chrome, Web release,
  Windows builds/native credential/storage restart and retained database/AI gates.
  This is component evidence, not hosted learner acceptance.
- Added read-only ReadingRepository and opt-in LocalReadingRepository with one
  trusted host-supplied source callback, no default lesson/route/asset/network.
  Full256KiB catalog validation precedes level filtering. Concurrent reads/lookup
  share a pending read registered before source invocation; five-second default
  deadline (positive/up to15s), fixed typed safe errors, explicit retry only.
  Timed-out late successes/errors never publish data/fences; loader side effects
  are not cancelled. Host must provide read-only bounded source/provenance review.
- IDs retain level/monotone version. Fixed semantic serialization preserves all
  text/order/answer/attribution; same ID/version cannot change content and reuses
  the original immutable passage. Higher versions create new snapshots; old rounds
  retain old content. Exact lookup never substitutes another version. Validate the
  entire prospective mapping before publishing any fence; hidden-level conflicts
  cannot advance earlier entries. Removal returns no stale fallback; retired IDs
  retain fences. Bound50 lifetime IDs/latest snapshots, fail closed on churn,
  never silently evict. Fences are process-local, not authenticity/durable rollback
  protection; resetting repository requires a separately reviewed trusted source.
- Sixteen new TEST ONLY repository cases +retained11 domain cases:27 pure Dart
  tests passed, strict casts/inference/raw-types/recommended lints analysis clean.
  Official Dart3.9.2 archive SHA256 verified. Disposable harness copies production
  model/repository/level and all test bodies exactly; only flutter_test import
  replaced by package:test1.26.2. This is not actual Flutter widget/platform proof.
  Dart formatter passed; unresolved Flutter lint include warned during local
  repository formatting. Flutter3.35.4 bootstrap was blocked by automatic approval
  review for cloud metadata access; no workaround attempted. Actual new-head
  Flutter/analyze/full tests/Web/Windows verification remains with GitHub CI.
- Local QA46 tests passed; inventory74 valid/all14 release groups still pending.
  Separate preservation review:73 old QA case objects/findings/gates unchanged;
  original Dart/domain tests and canonical Pro/N4 content/assets/contracts/SQL/
  Auth/security/defaults/dependencies/workflow unchanged. No new learner write,
  mastery, timer, sync, audio/capture/retention/spend/deployment or release claim.
- Six paths: new domain/reading_repository.dart, data/local_reading_repository.dart
  and test/features/reading/local_reading_repository_test.dart; READING_MATERIAL.md,
  PROJECT_STATUS.md and qa/matrix.json. Full tree/content/parent verification and
  expected-head non-force publication required; final commit/run in PR41/issue34.
- Next inspect new exact-head latest-attempt five jobs/every required step, fix
  actual failures preserving assertions. After verified repository, implement
  explicit reading loading/error/empty/offline UI with injected trusted source,
  then captured-session study reports/durable retry. Reviewed lessons/audio need
  separate coordination; absence never counts as listening completion. Keep #34
  open/#41 draft/all14 release groups pending. Main/Pro/other branches unchanged.


## Reading UI / independent Issue #34 checkpoint (2026-10-23T06:19:26.841001+00:00)

- Fresh source clone at parent1ad9590c6548e54292ce35d34fb7718b17d57b94,
  treefb797a0fd6d0661962fbe0e0034899ed0f7f6162; main78a44faf observed unchanged.
  PR37 sourceafa572a remains a redirect to draft41/current core branch. One core
  writer marker recorded active before implementation; Pro14/38 scope preserved.
- Verified parent CI39906926247 latest attempt1 completed/success: allfive jobs
  and every required step succeeded/no skips. Actual new repository Flutter/
  Chrome/Web/Windows/native/database/AI component gates passed. No hosted learner
  acceptance inferred; Auth/provider/live configuration gaps remain separate.
- Added nullable default reading repository provider and auto-disposed level loads.
  Existing /listening now hosts read-only list/passage/first-answer feedback/result
  with Japanese selectable text, optional kana/Vietnamese, source attribution,
  restart/back, disabled missing-audio control and unavailable/loading/error/empty
  states. Only trusted host source injection; no bundled demo lesson, learner
  URL/key/path input or direct database/account capability.
- Both refresh/reload paths remove prior content; panel identity includes source,
  level, explicit reload revision and collection. Even immediate identical-list
  reload resets the round. Answer/restart/back/toggle callbacks capture exact
  round identity; old/disposed callbacks cannot affect new rounds. Source/level
  replacement/null and route exit discard selection/answers. Explicit retry only;
  no stale offline fallback or raw source exceptions. Mounted scroll guard resets
  explicit navigation. Scores grant no minutes/mastery/progress/SRS/sync.
- Fifteen new widget cases authored using actual router/providers/parser/local
  repository and TEST ONLY source/read ports, including wrong/correct completion,
  duplicate callbacks/restart/back, null/default/audio, error/retry/empty, level
  dropdown and pending old-level success/error, same-level source replacement/
  null and late data, pending reload/version upgrade/immediate identical list,
  version conflict, route disposal/late error, N5/N4 320px/200% controls.
  Original app_test.dart/all existing test bodies unchanged; the dynamic listening
  placeholder iteration is replaced by dedicated real-route cases.
- Local observed: fresh official Dart3.9.2 SDK archive SHA256 verified, allfour
  changed/new Dart files formatted and final format check passed. Formatter warned
  unresolved Flutter lint include. QA46/46/inventory75 valid; all74 original QA
  case objects/findings/gates retained byte-equivalent after JSON decoding.
  No local Flutter analyzer/widget/platform build claimed; prior cloud metadata
  bootstrap rejection respected with no retry/bypass. New exact-head CI required.
- Eight paths: app/router.dart; new reading/application/reading_provider.dart,
  reading/presentation/reading_screen.dart, reading/reading_widget_test.dart;
  new docs/READING_SCREEN.md; READING_MATERIAL.md, PROJECT_STATUS.md, qa/matrix.json.
  All canonical curriculum/Pro/N4 assets, frozen wire/API/SQL/Auth/security/seven
  plan blocks, runtime/storage ownership, dependencies/locks and CI preserved.
  No new player/capture/retention/spend/provider, production write/deployment,
  merge/issue closure, Personal Alpha acceptance or schedule change.
- Separate diff review and full tree/all changed blobs/one-parent verification
  required before expected-head non-force publication; final commit/run/release
  in PR41/issue34. Next inspect exact-head latest-attempt allfive jobs/every step,
  fix actual failures without weakening assertions, pending-only handoff if needed.
  Then trusted reviewed material and captured-session/durable reading study reports;
  vetted playable audio remains a separate adapter. Keep #34 open/#41 draft/all14
  hosted release groups pending. No fabricated lesson/audio/saved success.


## Reading translation-toggle lint correction (2026-10-23T07:11:10.253649+00:00)

- Fresh parent877469aa72956c9322a2f96e332d6064a217c981/tree
  875176f105a2c9d0b2321ea3443fdde6544ab7b6; main78a44fa unchanged; draft41
  resumes the core lane, source37/Pro38 branches untouched. Active marker recorded
  before code: core-20261023T071023-reading-lint.
- Exact parent CI39911022005/latest attempt1 completed failure. repo-sanity,
  ai-boundary/database/windows and every listed step succeeded. Flutter strict
  formatter passed; analyzer found only curly_braces_in_flow_control_structures
  at reading_screen.dart:228. Full/widget/Chrome/Web downstream steps were skipped,
  not passed;15 new reading widget cases still require actual execution.
- Added explicit braces around the existing translation-toggle if/setState only.
  Exact replacement comparison proves condition/assignment/all other source bytes
  retained. All15 widget cases/assertions, model/repository, lint settings, workflow,
  QA inventory, dependencies, content and defaults unchanged; no suppression/new
  test/behavior change. Separate diff/whitespace review and QA75 inventory passed;
  all14 release groups remain pending. Fresh official Dart3.9.2 archive SHA256 verified; pinned formatter passed
  without changes (unresolved Flutter lint include warning only).
- Two paths: reading/presentation/reading_screen.dart and this status. Local full
  Flutter/analyzer/widget/build not executed; prior metadata-bootstrap rejection
  remains respected. No new feature/persistence/audio/Auth/production integration,
  Pro/content/contract/security change, merge/closure/deployment/release or schedule
  action. Final verified commit/tree/run and released heartbeat in PR41/issue34.
- Next inspect new exact-head latest-attempt allfive jobs/every required step;
  fix actual diagnostics preserving assertions. Pending-only handoff, no duplicate
  code/docs-only commits/long polling. Only after verified UI continue reviewed
  material and captured-session/durable reading reports; #34 open/#41 draft.


## Reading elapsed-session composition (2026-10-23T08:22:58.547468+00:00)

- Fresh parentd1787cae7ec58cc34f0cacd8756df4cb88d51681/tree
  39d7cb942881e4d788b1fa206f743fd21ae020c3, main78a44fa/source37afa572a/
  Pro38 preserved. Single core writer marker core-20261023T081123-reading-timer
  recorded active before implementation; repeated continuation stayed in this lane.
- Exact parent CI39916233287/latest attempt1 completed success: allfive jobs/every
  required step passed, including actual15 reading widgets/full Flutter/Chrome/
  Web/Windows/native/database/AI checks. Component evidence, not hosted acceptance.
- Composed reading into the existing one captured-owner study recorder, adding
  only LISTENING_READING to supported client areas; unchanged preflight requires
  same-owner pending recovery, local readiness recheck and matching nonblocked/
  nonempty authoritative area. IMPORTANT current SQL still grants zero reading
  resources/BLOCKED. Local text cannot unblock server plans or authorize credit;
  tests explicitly use permissive TEST ONLY plans. No SQL/RLS/availability change.
- Source/level/catalog-generation-bound selected passage provider resets on refresh,
  including identical immediate lists. Own-profile level, settled valid catalog and
  exact selected object membership gate readiness. Root-mounted shared panel retains
  date editor on logout/awaited exit; no second recorder/SDK/journal owner. Opening/
  restarting/back/reload clears selection and interrupts only unfinished reading.
  Source/level/route/background loss cancels; frozen reports/retry/accepted-save
  drain remain unchanged. Reading finish callback captures running-state identity
  to reject a retained callback after restart. Audio disabled; time is reading
  self-report, not saved answers/comprehension/mastery or listening completion.
- Five new real-file core cases: local/blocked/nonempty gates; failed stage/frozen
  cross-area exclusion/exact retry; uncertain commit +journal close/reopen/manual
  replay; held canceled preflight/new-area isolation; late save/owner replacement.
  Actual fresh Dart3.9.2 SHA256 verified. Strict targeted analysis clean and5/5
  passed in disposable harness with identical production/core/dependency fixtures/
  all test bodies, only flutter_test import changed to package:test1.26.2. Native
  reopen is one process, not new Windows crash/hosted Auth proof. No app lock change.
- Twelve new widget cases authored for public/no dispatch, selected-profile staged
  interval, blocked plan, level mismatch, held reload, back/restart, late preflight,
  cross-route reading retry via SRS, old finish/new interval,320px/200% and logout/
  held-save/date-editor retention. Actual router/providers/shared core/service with
  TEST ONLY Auth/RPC/memory store/material/clock. All15 prior reader tests and every
  old study/Auth/SQL/CI assertion retained. NEW widget/provider/full Flutter/platform
  execution pending exact-head CI; no local Flutter bootstrap retry/workaround.
- Pinned Dart formatting passed; unresolved Flutter lint include warned. Local QA
  46/46/inventory76 passed; all75 prior QA cases/findings/gates unchanged; all14
  hosted release groups pending. Separate lifecycle/source/diff review, harness
  equality and full-tree/blob/parent guards required before expected-head non-force
  publication; final commit/run/released marker in PR41/issue34.
- Twelve paths: five existing study/reading provider/core/panel/screen files; new
  reading_study_recorder_test.dart +reading_study_widget_test.dart; new
  docs/READING_STUDY_TIMER.md; READING_SCREEN.md, SHARED_STUDY_RECORDER.md,
  PROJECT_STATUS.md and qa/matrix.json. Canonical content/Pro/frozen contracts/SQL/
  Auth/transport/storage/CI/dependencies/default source unchanged. No default fake
  success/provider/spend/deployment/merge/closure/release/schedule change.
- Next inspect exact new-head latest-attempt allfive jobs/every required step and
  fix real failures preserving assertions. Pending-only handoff; no duplicate code
  or long polling. Then reviewed original/licensed material and trusted server
  reading availability/version mapping before activation; audio remains separate.
  #34/#11 open/#41 draft/all14 hosted Personal Alpha groups pending.


## Reading timer input-focus regression (2026-10-23 UTC)

- Fresh main78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c, current draft41
  parenta00d17b4d558a9e891aeff5e30d296a79ae2ff49/tree
  7a9fe4542fb4c8bae1bf91bbcc65f74d9d19ee82; old draft37 redirects here.
  Single core marker core-20261023T0913-reading-timer-hit-test active before edits;
  independent Pro14/38 scope/content/manifests/tests/branch untouched.
- Observed exact-head CI39924427623/latest attempt1 completed failure. All steps
  in repo-sanity, ai-boundary, database and windows succeeded. Flutter formatting
  and analysis passed; full test step reported732 passed/10 failed. All10 failed
  reading_study_widget_test.dart cases stopped at begin -> tapReading line122:
  no hit-testable listening_reading-timer-start after date input/ensureVisible/
  pump. Remaining Flutter owned-SDK/Chrome/Web steps skipped, not passed.
- In reading-study begin helper, send the real keyboard Done action and settle
  date-edit focus/caret-reveal work before ensureVisible and the real start tap.
  Deferred EditableText reveal can otherwise override that scroll during the
  helper pump. Input completion happens before any possibly held preflight starts;
  no settling loop is added around a held operation/running timer. Existing
  hitTestable expectation, real tap, all12 test bodies/assertions remain unchanged.
  No direct onPressed start, tap warning suppression, removed case or weaker gate.
- Local fresh official Dart3.9.2 archive SHA256 verified; strict target formatting
  passed unchanged (unresolved Flutter lint include warning). QA inventory76
  valid; all14 hosted groups still pending. Separate exact insertion/diff review
  confirms original test source preserved byte-for-byte aside from5 added lines.
  No local Flutter analyze/test/build or bootstrap metadata-rejection workaround.
  New real Flutter/widget outcome must be observed on exact new-head CI.
- Two intended paths only: reading_study_widget_test.dart and this status.
  App/core/store/Auth/source/SQL/API/security/content/defaults/dependency/workflow/
  QA matrix unchanged. Current server reading area remains BLOCKED; no live
  learner/audio/Personal Alpha acceptance, deployment, merge or issue closure.
- Publish against correct base tree; verify complete remote tree/changed contents/
  parent and expected-head non-force ref. Final SHA/tree/CI/released heartbeat in
  PR41/issue34. Next inspect allfive latest-attempt jobs/every required step and
  fix actual diagnostics while preserving assertions. Keep draft41/issues34/11
  open; no duplicate work while CI alone is pending.


## Captured reading start/finish actions (2026-10-23 UTC)

- Fresh main78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c and draft41
  parent3a55cf4c3519839a37fee36a8395ac7dba377d61/tree
  fb78e66a9f293e5d4fb41b8e6e310aeb3e0cc862. Source37afa572a redirects to41;
  Pro14/38 unchanged/reserved. Marker core-20261023T1019-reading-action-generation
  recorded active in41 and issue34 before implementation; one core writer.
- Exact parent CI39930585722/latest attempt1 completed success. Allfive jobs and
  every required step succeeded/no skips. Flutter log confirms all12 original
  reading-study widgets and742 full cases, plus5 Chrome cases; Web/Windows/native/
  owned-SDK/SQL/Edge retained checks passed. Prior date-input focus/scroll fix is
  verified. Component evidence only, not hosted learner or reading availability.
- Separate source review found start was a State method tearoff reading the
  current owner/selection on invocation. Retaining it across same-passage restart
  or A B A account replacement could begin a successor's interval. Start now
  captures owner/exact recorder state/area and requires mounted current identity
  before reading date/ref or dispatching through that captured owner. Existing
  content/profile readiness and asynchronous/server preflight checks remain.
- Reading host rotates an opaque generation at every clear/open/restart/reload.
  Captured host guard checks actual current generation at invocation, including
  before the next rebuild and when passage identity/idle state are unchanged.
  No round-key/editor remount. Reading finish also uses captured owner/state/round;
  disposed start/finish return before widget-ref access. Other hosts retain their
  area/default content behavior; shared start owner/state checks apply throughout.
- Five new TEST ONLY widget cases: retained start after same-object restart and
  reload; replacement repository returning the same immutable passage objects;
  A B A account swap with cleared editor/new owner; disposed start and finish
  after a61-second canceled route exit. Stale starts must produce no plan read,
  write, event ID or journal event, while current controls still start via real
  hit-tested taps. Original12 test bodies/assertions/date-input helper preserved
  byte-for-byte; actual parser/router/providers/shared recorder/service in use.
- Fresh official Dart3.9.2 SHA256 verified. Local pinned formatting,46 QA tests,
  inventory76 and whitespace passed; all14 hosted groups remain pending. Full
  new Flutter analyze/widget/browser/platform execution not run locally; prior
  bootstrap metadata-review rejection remains respected without retry/bypass.
  New guards/cases need exact-head CI before claiming runtime verification.
- Five intended paths: shared timer panel, reading screen, reading-study widget
  tests, docs/READING_STUDY_TIMER.md and this status. No canonical content/Pro,
  data/manifest/content tests, default fake source/success, Auth strategy/provider,
  SQL/RLS/API/wire/availability, storage/core, CI/dependencies or paid operation
  change. Actual server LISTENING_READING remains BLOCKED; audio unavailable.
- Separate diff/lifecycle/source-preservation review completed before publication.
  Use correct base/full-tree/UTF8/blob/one-parent verification and expected-head
  non-force ref. Final SHA/tree/run and released heartbeat in41/34/37 redirect.
  Next inspect allfive latest-attempt new-head jobs/every required step; fix actual
  diagnostics with assertions intact. Draft41/issues34/11 remain open, reviewed
  material/server mapping/audio/hosted learner acceptance still required. No
  merge/deployment/release or schedule change; pending-only CI means handoff.


## Gated Quiz/Review elapsed-session composition (2026-10-23 UTC)

- Fresh main78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c; draft41
  parent77e9cf445ca9eade2aeed2cc26f37a8e84954c8c/tree
  3d16dd155dc238b6990183406a374dc0aaa9e0f2. Source37afa572a redirects here;
  Pro14/38 reserved/untouched. Single core marker
  core-20261023T1113-quiz-study-composition active in41/11 before code.
- Exact parent CI39938761913/latest attempt1 completed success: allfive jobs,
  every required step/no skips,747 Flutter/five Chrome/Web/Windows/native/SQL/
  Edge. Allfive new reading action-identity regressions explicitly passed.
  Component evidence only; no hosted learner/availability/release acceptance.
- Scoped #11/#13 policy reviewed before code: explicit self-reported elapsed
  quiz/review time, separate from score, local attempt capture/save and mastery.
  Partial or completed current rounds can retain an explicitly started interval;
  answering/finishing/saving never starts/credits time. Guest-to-ready may start
  new time explicitly, never retarget earlier answers as an owned quiz attempt.
- Added only QUIZ_REVIEW to client recorder allowlist. Current SQL still counts
  quiz resources as0/BLOCKED; local questions/readiness cannot enable that area.
  Unchanged same-owner pending recovery, exact nonblocked/nonempty plan block,
  async readiness recheck/calendar/overlap/derived-credit/server replay rules
  remain authoritative. No SQL, snapshot reset, grant/RLS or wire change.
- Quiz start requires settled nonempty questions whose vocabulary targets/choices
  match preview/own-profile level and positive versions, plus mounted current
  round/history-owner eligibility. Shared owner/state/round guards reject stale
  start/finish. Restart/next batch interrupts only unfinished quiz preflight/time;
  source/level/loading/route/background/account loss cancels. Date editor remains
  mounted/cleared/offstage through history-owner loss/logout/awaited app exit;
  source/level/route still replace hosts normally. No second recorder/store/SDK.
- One frozen report blocks all activities even before stage success. Existing
  stage-before-RPC/ack/fresh-plan/manual retry/drain keeps exact ID/date/area/UTC
  times across routes, including retry from SRS. Accepted saves retain owner
  isolation; late old-account publication is suppressed. No score/answer fields
  are added to study reports, no fake save/Auth success or default live service.
- Four new actual-file core cases passed in fresh Dart3.9.2 disposable harness:
  readiness/exact blocked/nonempty area +ack; unstaged cross-area exclusion and
  exact retry; uncertain commit +journal close/reopen/manual replay; late save/
  owner replacement. Official archive SHA256 verified; strict targeted analysis
  clean. Exact production/dependency fixtures/test bodies matched, only runner
  import changed to package:test1.26.2. Reopen is one process, not new Windows
  crash/hosted Auth proof. No local full Flutter/bootstrap-rejection bypass.
- Eleven new actual-router/provider/widget cases authored with unchanged decoded
  original N5/N4 and TEST ONLY Auth/RPC/memory/clock/permissive plans: public no
  credit, explicit partial-quiz interval, blocked area, profile mismatch,
  restart/next-batch/stale finish, held refresh, late preflight/route exit,
  cross-route frozen retry,320px/200%, logout/held save/date retention. Actual
  NEW Flutter/provider/widgets/platform outcomes require exact-head CI.
- Local strict format six files passed,46 QA tests/inventory77/whitespace passed.
  All76 old QA case objects/findings/gates retained; all14 hosted groups pending.
  Separate diff/lifecycle review proves old quiz answer/advance/attempt/save logic
  and question/result rendering exact; every old test remains unchanged.
- Eleven intended paths: four existing recorder/provider/panel/quiz-screen files;
  two new quiz-study test files; new docs/QUIZ_STUDY_TIMER.md, existing shared
  recorder/vocabulary-quiz docs, PROJECT_STATUS.md and qa/matrix.json. Protected
  canonical content/Pro/manifests/content tests/contracts/Auth/store/SQL/security/
  dependencies/CI/provider/spend unchanged. Keep #11/#13 open/#41 draft.
- Publish only after correct-base/full-tree/unchanged-blob/content/single-parent
  and expected-head non-force guards. Final SHA/tree/new run/released heartbeat
  in41/11 and37 redirect. Next inspect every required latest-attempt exact-head
  job/step and fix actual diagnostics without weakening assertions. Pending-only
  means durable handoff, no duplicate code/long polling. Trusted quiz availability
  mapping, reading/audio, hosted attempts/sync/learner/release gates remain open;
  no deployment/merge/closure/release/schedule action.


## Quiz widget unused-import correction (2026-10-23 UTC)

- Fresh main78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c, draft41
  parent14fb8bc3e163721055776626e1030fb7f2abc371/tree
  b9188566d891e98db011a54f2c4a703f20244574; source37afa572a redirects here.
  Marker core-20261023T1212-quiz-unused-import active in41/11 before editing;
  single core writer, Pro14/38 content/manifests/tests/branch untouched.
- Observed exact parent CI39945699267/latest attempt1 completed failure.
  Repo-sanity, database, ai-boundary and windows all jobs/every step succeeded.
  Flutter strict format passed; analyze reported exactly one warning:
  test/features/quiz/quiz_study_widget_test.dart:21 unused_import of
  package:nihongo_daily/features/quiz/domain/vocabulary_quiz.dart. Full/new
  widget/native/owned-SDK/Chrome/Web downstream steps skipped, not passed.
- Removed only that unused test import. Exact comparison against fresh parent
  proves all other bytes, all11 test cases/helpers/assertions and real taps
  unchanged. All app/core/store/default/content/SQL/Auth/CI/lint/dependency rules
  remain unchanged; no suppression, removed case or weaker required check.
- Fresh official Dart3.9.2 archive SHA256 verified; strict target format passed
  with0 changes (unresolved Flutter lint include warning). QA inventory77 valid,
  all14 hosted groups still pending; separate import-removal/diff/whitespace
  review passed. No new executable-test success claimed for this import-only
  correction; actual Flutter analyze/tests/widgets/platforms need new-head CI.
  Prior metadata-bootstrap review rejection respected, no retry or bypass.
- Two paths only: quiz_study_widget_test.dart and this status. Publish with correct
  base/full-tree/unchanged blobs/exact UTF8/parent checks and expected-head non-force
  ref. Final commit/tree/new CI/released heartbeat in41/11/37 redirect.
- Next inspect exact new run/latest-attempt allfive jobs/every required step and
  fix real diagnostics with assertions intact. Pending-only means handoff without
  duplicate code or long polling. Keep41 draft/issues11/13 open; server quiz and
  reading areas remain BLOCKED, original-content/audio/hosted learner/sync/release
  gates remain open. No merge/closure/availability/deployment/release/pause.


## Focused current-source quiz practice (2026-10-23 UTC)

- Fresh main78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c, draft41
  parenteb58c1c53c0d6ef0e0aac7d23f05828f6a70cd85/tree
  ebe9d4ab2467fa69431792988a588181a9607710; source37afa572a redirects here,
  Pro14/38 reserved/unchanged. Single core marker
  core-20261023T1321-focused-quiz-review active in41/13 before implementation.
- Exact parent CI39951748561/latest attempt1 completed success: allfive jobs,
  every required step/no skips,762 full Flutter/five Chrome/Web/Windows/native/
  SQL/Edge, all11 quiz-study widgets passed. Component evidence only, not hosted
  learner/availability/release acceptance. Prior unused-import correction verified.
- Implemented explicit focused practice from current needs-review projection.
  Select original questions in existing error/time/ID priority, retain full-deck
  canonical choice order/objects rather than inventing a smaller distractor pool.
  Require exact level/ID/version and current entry identity; removed/new-version/
  foreign/copied sources cannot retarget old progress. Immutable result; duplicate
  question keys and deck>5000 rejected. Single target still has its four choices.
- Extracted reusable VocabularyQuizPanel. Separate generated/canonical-format
  comparison proves entire old panel preserved plus names/optional timer gate;
  answer/advance/capture/save/retry/question/result/batch semantics unchanged.
  /quiz retains its timer. Focused progress practice has no timer/editor or start/
  interrupt path. No scoring/mastery/SRS/server-minute/implicit-save change.
- New progress action captures mounted current owner/history/source/level and
  exact projection, including replacement before next frame. Each practice gets
  fresh question-list identity; old controls cannot reset active practice or close
  a reopened round. Existing first answer/max10/explicit batch/restart/manual local
  save/immutable retry and accepted-owner-drain rules reused. Back/source/level/
  owner/reload exits clear practice; explicit reload after saved correction updates
  recommendations through existing latest-answer projection. Defaults unchanged.
- Six pure selection cases passed: both levels' priority and canonical choices,
  immutable objects, focused correct event/dedup clears matching targets,
  same-version copied/new-version source, empty/correct/foreign and duplicate/
  oversized decks. Fresh official Dart3.9.2 SHA256 verified; strict analysis clean.
  Actual seven-file production/test graph copied identically to fresh disposable
  harness, only flutter_test import changed to package:test1.26.2. Not Flutter UI.
- Nine widget cases authored against actual router/providers/model/panel/history
  and original N5 with TEST ONLY Auth/memory/clock: empty, prioritized practice/
  explicit save/reload, stale projection, source replacement before frame,
  changed version, logout/B held-save, level/old answer, back/reopen/old back,
  320px/200-percent controls. Test capture uses actual completed round, never
  reconstructs answers. Existing tests/Pro content tests/assertions unchanged.
- Local pinned format six files,46 QA regressions/inventory78/whitespace passed;
  all77 old QA objects/findings/gates preserved/all14 hosted groups still pending.
  New full Flutter/analyze/widgets/platform execution requires exact-head CI;
  prior metadata-bootstrap review rejection respected without retry/bypass.
- Ten intended paths: two existing quiz/progress screens; new shared quiz panel
  and pure review selector; two new test files; new FOCUSED_QUIZ_REVIEW.md plus
  QUIZ_PROGRESS_VIEW.md/PROJECT_STATUS.md/qa matrix. No canonical content/Pro,
  contracts/SQL/RLS/Auth/store/recorder/CI/dependency/provider/spend changes.
- Publish with correct base/full-tree/unchanged blobs/UTF8/one-parent verification
  and expected-head non-force ref. Final SHA/tree/new run/released heartbeat in
  41/13/37 redirect. Next inspect allfive latest-attempt exact-head jobs/every
  required step and fix actual diagnostics preserving assertions. Pending-only
  means handoff, no duplicate implementation/long polling. Keep41 draft/13 open,
  hosted learner/sync/mastery/curriculum/availability/release gates pending; no
  merge/closure/deployment/release/schedule action.


## Focused quiz widget fixture correction — Issue #13, 2026-10-23 UTC

- Fresh main78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c, draft41 parent
  9a7359044d3b09bea2a454dcb35edc13779b6928/tree
  7dfefafec4d0d773c6328e4dfb4673c99f4e36e8. Prior core released;
  core-20261023T1414-focused-review-fixture active in41/13 before edits.
  Fresh cloud clone/source/docs/issues/PRs/CI; Pro14/38 remains reserved.
- Exact parent CI39962254749/latest attempt1 completed failure. All steps in
  repo-sanity/AI/database/Windows passed. Flutter strict format/analyze passed;
  full test recorded776 passed/one10-minute timeout. The sole failure was changed
  content version excludes old mistakes from focused practice, awaiting real
  File.readAsString inside testWidgets FakeAsync. Eight other new focused-review
  widgets and six selector cases passed. Later Flutter SDK/native/Chrome/Web
  steps were skipped, not passed. No full-CI/hosted learner acceptance claim.
- Read unchanged original N5 JSON once in real-loop setUpAll and reuse the same
  string for initial source and in-memory version2 publication. No real file IO
  remains inside widget bodies. All nine cases/all assertion statements, version
  mutation, original content/choices and production behavior remain intact.
  No timeout increase, fixture-success substitution or test/CI weakening.
- Three intended files: focused_quiz_review_widget_test.dart,
  docs/FOCUSED_QUIZ_REVIEW.md and docs/PROJECT_STATUS.md. Separate diff/assertion/
  lifecycle review passed. Fresh official Dart3.9.2 SHA256 verified; pinned
  format checked one file/zero changes. Formatter reports missing flutter_lints
  include because this cloud checkout has no Flutter package resolution; no
  full local Flutter analysis/test/build claim or bootstrap rejection bypass.
  QA inventory78 and whitespace passed; QA/production/old tests unchanged.
- Correct-base/full-tree/path/mode/unchanged blobs/UTF8/one-parent and fresh
  head/marker verification precede expected-head non-force publication. Final
  commit/tree/new exact-head Actions/status/released heartbeat in41/13/37.
- Next inspect exact new run/latest-attempt allfive jobs/every required step,
  including corrected version case and previously skipped Flutter downstream.
  Pending-only handoff, no duplicate implementation or long polling. Keep41
  draft/13 open/all14 hosted release groups pending. No protected Pro/content/
  manifest/SQL/RLS/Auth/default/provider/dependency/CI/spend changes, merge,
  closure, deployment, release or schedule action.


## Focused correction native/UI restart journey — Issues #13/#18, 2026-10-23 UTC

- Fresh main78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c; draft41 parent
  a396b146fccc862574121e7613ca68d2f167d979/tree
  7dfd8148faaae9c9b4b5e1ae5bac517bdfa1dbe1. Source37afa572a redirects
  here, Pro14/38 reserved/unchanged. Prior marker released; single core marker
  core-20261023T1511-focused-disk-journey active in41/13 before edits.
- Exact parent CI39968283133/latest attempt1 completed success, allfive jobs/
  every required step/no skips. Raw complete latest-attempt snapshot accepted
  by evidence verifier before QA changes. Logs prove777 full Flutter/five Chrome
  including allnine focused widgets/all six selector cases and old native-file
  quiz journey. Previous version-fixture FakeAsync timeout correction verified;
  Web/Windows/native/SQL/Edge gates all passed. Component evidence, not hosted
  identity/learner/availability/release acceptance.
- Extended the actual SDK/native-file/UI quiz journey through focused correction
  and a second owned restart. Select current original needs-review question via
  real progress control, verify all canonical choices, answer correctly. Completed
  round alone must leave append count/file unchanged. Explicit save and retained
  save callback produce one new actual UUIDv4/UTC event, not a synthetic row.
- Require original9/10 immutable event plus exact new1/1 target/version/choices,
  two records, preserved original journal prefix. Back retains prior stats until
  explicit reload produces2 rounds/10-of11 correct/10 current practiced/no review
  candidate. These local actions dispatch no HTTP; scores remain separate from
  mastery/time/SRS/plan credit. No production/default/storage/contract change.
- Await second owned close; third fresh SDK/runtime/controller refreshes retained
  TEST ONLY vault, passes own-profile gate without manual login and explicitly
  recovers both byte-equivalent events/history/progress. B loads empty data;
  returning A explicitly recovers corrected counts/no candidate. Restore/A-B-A
  writes nothing and preserves complete corrected bytes; no owner/token text.
  Actual file IO/SDK/close stay inside existing bounded real-loop runAsync path.
- Original fixture/helpers/journey/assertions preserved byte-for-byte before
  appended continuation;58 assertion statements added. Separate source/ownership/
  real-loop/cleanup/immutable event/diff review passed. Existing test name and
  every original QA case/finding/gate retained. Inventory79/46 QA regressions/
  whitespace passed. Fresh official Dart3.9.2 SHA256 verified/pinned formatting;
  unresolved flutter_lints include reflects absent Flutter package resolution.
  New Flutter/analyze/full-platform execution unrun locally; no prior metadata-
  bootstrap rejection retry/bypass or source-review-as-runtime claim.
- Five paths only: quiz_disk_journey_widget_test.dart,
  docs/QUIZ_DISK_JOURNEY.md, docs/FOCUSED_QUIZ_REVIEW.md,
  docs/PROJECT_STATUS.md, qa/matrix.json. New QA group documents component scope
  and exact test anchors. No protected Pro/content/manifests/content tests, SQL/
  RLS/Auth strategy/API/store/provider/dependency/workflow/spend changes.
- Correct-base/full-tree/unchanged blobs/UTF8/single-parent checks and fresh
  expected-head non-force publication; final commit/tree/new CI/release in41/13/37.
  Next inspect exact-head latest-attempt allfive jobs/every required step and
  actual extended journey diagnostics, retaining assertions. Pending-only handoff
  rather than duplicate implementation/long polling. Keep41 draft/13 open/all14
  hosted release groups pending. Same-process graceful reopen/TEST ONLY HTTP,
  unsigned JWT and vault are not hosted learner/sync, physical Windows launch/
  vault or forced-process/power-loss proof. No merge/closure/deployment/release/
  schedule action; continue independent reviewed integration gaps after green.


## Pure Dart AI text contract models — Issue #17, 2026-10-23 UTC

- Fresh main78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c; draft41 parent
  f4f822a03a14e949271c9bb4a1c0622ed5bbb0d8/tree
  4128007a70cbad61736bedc58f8b4d1217385459. Source37afa572a redirects
  here, Pro14/38 remains reserved. Prior worker released; core marker
  core-20261023T1611-ai-text-models active in41/17 before implementation.
- Exact parent CI39976858658/latest attempt1 completed success, allfive jobs/
  every required step/no skips. Complete raw snapshot accepted by QA evidence
  verifier before inventory changes. Logs prove777 full Flutter/five Chrome,
  extended actual-file focused correction/second owned restart/A-B-A journey
  passed; Web/Windows/native/SQL/Edge retained. Prior58-assertion continuation
  verified. Component evidence only; all14 hosted release groups remain pending.
- Independent #17 prerequisite: typed pure-Dart tutor_explain/correct_sentence
  request encoders and strict response decoders from unchanged frozen v0.1.
  Read schema/fixtures/API/architecture/security and Issue17 acceptance first.
  No endpoint/provider/Auth strategy/key/URL/operation/owner or default activation.
  Allfive wire levels represented without expanding N5/N4 UI/content scope.
- Preserve exact keys/text/whitespace/combining characters/case. Count Unicode
  code points at schema limits1..5000/10000/2000, first bounding UTF16 scan.
  Arrays0..100, independent unique context UUID lists, exact upper/nil UUID
  spelling. Nested correction references preserve schema-permitted duplicates;
  structural validity never claims current curriculum existence/authorization.
- Require every response/nested field and reject unknown/missing/mixed error,
  wrong scalars/lists/maps/null/enum/ID/oversize before returning models. Empty
  correction arrays stay empty. Copy/freeze all collections; nested final models
  and fresh wire exports prevent input/output mutation from rewriting state.
  Constant FormatException has no payload source/echo; no logging/persistence,
  model-instruction execution, counters/mastery/SRS/study-credit mutation.
- Seventeen cases read original frozen fixtures unchanged: exact two request
  encodings/two response round trips/allfive levels, immutable contexts, UUID
  case/nil/unique behavior, Unicode/bounds, every nested key/type/text/list limit,
  all reference types/duplicates/empty, deep copy/fresh exports and safe failures.
  Initial new-test analysis found one uninferred empty Map and three unnecessary
  interpolation braces; typed/wrote equivalent literals, retaining assertions.
- Fresh official Dart3.9.2 archive/SHA256 matched. Fresh disposable two-file
  production/test graph +original fixture bytes copied identically, only
  flutter_test import adapted to package:test1.26.2. Strict casts/inference/raw
  types with lints6.0.0 analysis found no issues;17/17 pure tests passed on final
  source. Pinned format two files/zero changes; QA inventory80/46 regressions and
  whitespace passed; all79 prior QA objects/findings/gates unchanged. Full new
  Flutter/analyze/platform checks require exact-head CI; no prior metadata-
  bootstrap rejection retry/bypass. No local JSON Schema validator available;
  no new Python schema or hosted/SDK/UI execution claim.
- Five intended paths: new lib/features/ai/domain/ai_text_models.dart,
  test/features/ai/ai_text_models_test.dart, docs/AI_TEXT_MODELS.md;
  docs/PROJECT_STATUS.md and qa/matrix.json. Separate schema-to-model fields/
  limits/ownership/immutability/diff review completed. No prior source/tests,
  frozen contracts/content/Pro/manifests/SQL/RLS/Auth/CI/dependencies modified.
- Correct-base/full-tree/unchanged blobs/UTF8/single-parent checks and fresh
  expected-head non-force publication precede final commit/tree/new CI/released
  checkpoint41/17/37. Next inspect exact run/latest attempt/allfive jobs/every
  required step, fixing actual diagnostics with assertions intact. Pending-only
  handoff, no duplicate code/long polling. After green add reviewed caller-owned
  captured-ready-session text gateway/repository and safe errors/late-response/
  timeout tests, then actual tutor/correction UI. No global current-user client,
  learner endpoint/key or automatic text retries: v0.1 text calls have no event
  receipt and may invoke a provider again. Live identity/provider choice/spend/
  voice/learner gates remain; keep41 draft/17 open. No deployment/merge/closure/
  release/schedule action or Personal Alpha claim.


## Captured AI text repository — Issue #17, 2026-10-23 UTC

- Fresh main78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c; draft41 parent
  1fb3611563b752e0b44acdba48025a017aa6ab47/tree
  0aef0c9b6a1131d6c95de28133c39de8293d6161. Source37afa572a redirects
  here, Pro14/38 reserved. Previous worker released; single core marker
  core-20261023T1712-ai-text-repository active in41/17 before implementation.
- Exact parent CI39986349215/latest attempt1 completed success, allfive jobs/
  every required step/no skips. Fresh complete raw run/jobs correlated to exact
  head/run/attempt and all required matrix steps through JS checks. Logs prove
  794 full Flutter/five Chrome, all17 new text-model cases; Web/Windows/native/
  SQL/Edge retained. Prior models verified as components, not hosted AI/learner
  acceptance. Existing 14 release groups remain pending.
- Added borrowed CapturedAiTextRepository over ReviewAuth/one exact ReviewSession
  hint, caller's captured vault/profile/runtime generation readiness fence and
  two fixed AiTextTransport methods. Construction/dispatch/success/error/timeout/
  decoded-result publication guard original capability. Observed identity/
  readiness/getter/revoke/server-UNAUTHORIZED permanently fences it; no ABA reuse.
  No SDK/client/token/storage owner, sign-out, provider or runtime/default activation.
- Deeply freeze exact request body; strict frozen models decode successful text.
  Exact safe error shape/code/bounded-message/boolean validation discards raw
  server text; permanent retry flags clamped off, unknown failures fixed internal.
  Local pending state distinguished from server quota; no logs/cache/derived write.
- One request spans both operations, registered before reentrant transport calls.
  Release only after result handling and original I/O both settle. Trusted
  timeout in(0,15s] bounds asynchronous result wait/revocation takes precedence;
  timeout returns non-retryable network failure and retains busy lock. Late
  success/error only settles/release, never publishes or redispatches/unhandled
  error. Not cancellation/rollback/hard CPU deadline or proof of zero provider cost.
  Text v0.1 has no event key, so no automatic retry/idempotency promise.
- Twenty-two cases authored with original frozen fixtures and TEST ONLY Auth/
  readiness/transport: fixed bodies/identity, deep immutable dispatch, construction/
  timeout bounds, same/other-account/logout/revoke/readiness/getter/generation
  guards, late result/error, safe server/transport/malformed failure normalization,
  duplicate/cross-method/reentrant dispatch, timeout held success/error and
  revocation precedence. Old model/app/tests/contracts/content unchanged.
- Runtime unavailable: one exec probe returned no usable execution environment.
  Read full recursive701-entry/592-blob fresh GitHub head tree plus complete
  relevant blobs; no previous scratch/source/SDK dependency. No local clone/
  Dart/Flutter/format/analyze/test/Python QA/build execution claim. Source review,
  delimiter/whitespace/new-anchor/old-inventory checks are static only; CI required.
- Independent JS Git-object hashing checked known SHA1/blob vectors and rebuilt
  exact original tree SHA. New full expected tree/blob hashes will be compared
  with GitHub and all UTF8 files read back before single-parent, fresh head/marker,
  expected-head non-force publication. All80 prior QA cases/findings/gates exact;
  new inventory81 and14 pending groups structurally checked, not Python QA execution.
- Six paths: new lib/features/ai/data/captured_ai_text_repository.dart,
  test/features/ai/captured_ai_text_repository_test.dart,
  docs/AI_TEXT_REPOSITORY.md; docs/AI_TEXT_MODELS.md, PROJECT_STATUS.md,
  qa/matrix.json. Separate ownership/async/error/immutability/timeout/diff review.
  Final commit/tree/new CI/latest-attempt status/released checkpoint in41/17/37.
- Next inspect exact-head latest attempt/allfive jobs/every required step, format
  diagnostics and22 new cases, retaining assertions. Pending-only handoff/no
  duplicate code/long polling. After green add actual caller-owned fixed-project
  text HTTP/SDK credential capture/raw body/JSON/redirect/cancellation/deadline
  controls and tests before runtime/UI integration; injected ports alone do not
  prove them. Keep41 draft/17 open/all14 hosted groups pending. Pro/content/
  manifests/content tests/SQL/RLS/Auth strategy/CI/dependencies/provider/spend
  untouched; no merge/closure/deployment/release/schedule/Personal Alpha claim.


## AI text repository format/analyzer verification — Issue #17, 2026-10-23 UTC

- Sole core marker core-20261023T1819-ai-text-ci-fix; resumed PR41 branch
  automation/issue-11-plan-sdk-integration at9014ee7dbaf0f07e8209f30e73845052762a0801,
  parent tree6ec2967f919e429089dec6c5770d0709dfdc9f68. Fresh main78a44fa,
  source37afa572a/Pro38 unchanged; previous worker released17:25:43 UTC.
- Observed CI39994699895 exact9014ee7/latest attempt1 completed failure:
  AI/database/repo-sanity/Windows all steps success; Flutter pinned formatter
  failed on the two new Dart files. Flutter analyze/test/native/Chrome/Web
  downstream steps skipped, not passed. Read actual job120555870767 logs.
- Fresh official Dart3.9.2 archive and freshly fetched SHA256 matched
  ec22e81271582def81d3e10e2a555ae5d3d81c6951465a3d16cfc47938e9f92a.
  Formatter diff exactly matched CI. Independent non-layout token/string/comment
  comparison retained all22 cases/assertions and source behavior. Strict analysis
  then found an unnecessary double-underscore StackTrace parameter; replaced it
  with wildcard, preserving error consumption and lock-release behavior.
- Fresh identical four-library/one-test source graph, original frozen fixture
  bytes and only flutter_test -> package:test1.26.2 import adaptation:
  strict casts/inference/raw types+lints6.0.0 analysis clean;22/22 cases passed.
  Initial analyze started before package resolution finished and failed URI
  resolution; after successful pub get the real lint above was fixed and clean
  analysis observed. These are pure Dart checks, not full Flutter/SDK/hosted proof.
  Final pinned format two files/zero changes, QA inventory81/14 pending and
  git diff --check passed. No previous scratch source or Flutter bootstrap retry.
- Four paths: lib/features/ai/data/captured_ai_text_repository.dart,
  test/features/ai/captured_ai_text_repository_test.dart,
  docs/AI_TEXT_REPOSITORY.md and this status. Separate diff review preserved
  every test assertion, fixed request/response boundaries, session/generation
  fencing, safe errors and timeout/single-flight behavior. No fixtures/contracts/
  QA matrix/Pro/content/manifests/SQL/RLS/Auth strategy/CI/dependency edits.
- Publish using exact parent base_tree and verify complete recursive tree,
  unchanged blob SHAs/type/mode/path inventory, allfour UTF8/blob readbacks,
  single-parent tree and fresh marker/head before expected-head non-force ref.
  Final commit/tree/new workflow latest-attempt/jobs evidence in PR41/Issue17/37.
- Next inspect new exact-head allfive jobs/every step; fix real diagnostics with
  assertions intact. Pending-only handoff/no duplicate code/long polling. After
  green continue reviewed concrete caller-owned fixed-project HTTP/SDK captured
  credentials/raw-body/JSON/redirect/cancellation/deadline tests before owned UI
  integration. Keep17 open/41 draft/all14 hosted release groups pending. No merge,
  closure, provider/default activation, deployment, release or schedule change.


## Captured Supabase AI HTTP component — Issue #17, 2026-10-23 UTC

- Sole marker core-20261023T1911-ai-http, PR41 branch
  automation/issue-11-plan-sdk-integration, exact parent
  2ebe41ac34b42839fc21c417ff22f95a9ad8494f/tree88dccb7ba84b57c70a67c48fbabf03114bf70001.
  Fresh main78a44fa/source37afa572a/Pro38 unchanged; prior worker released18:25:30 UTC.
- Parent CI40002993953 raw exact head/latest attempt1 completed success, complete
  allfive jobs/every required step/no skips. Unmodified metadata accepted by QA
  evidence verifier; Flutter log120584531944 shows816 Flutter/five Chrome/all22
  captured-repository cases. Windows/native/SQL/Edge retained; no hosted claim.
- New SupabaseAiTextTransport captures exact SDK Session/bearer/ReviewSession and
  owner's ready generation, validates fixed trusted HTTPS project/public key and
  dispatches only two fixed function paths. No current-token selection, refresh,
  token persistence/logging/provider/default activation. SDK replacement/expiry/
  readiness/getter/revoke/401 permanently fences; owner readiness loss must revoke.
- Strict DTO request reconstruction/32KiB UTF8, redirects off/max0, JSON/identity
  encoding, declared/actual lengths,1MiB/4096-read bound, fatal UTF8/BOM rejection,
  depth16/duplicate escaped/nested-key preflight and strict success/error decoding.
  JWT claims are local hints only; actual server Auth still mandatory. No RLS/
  contract/provider/auth-strategy change or hosted endpoint deployment.
- One registered attempt across methods, captured bearer even across SDK refresh,
  monotonic overall <=15s wait/AbortableRequest/per-read stop listener cleanup.
  Hold busy across ignored abort/late headers/cancellation; late bodies/errors only
  cancel/settle. Cooperative cleanup settles before returning, normal EOF drained;
  cancellation failure revokes. Local pending propagated by existing repository.
  close removes owned subscription/closes only owned HTTP/drains; borrowed clients
  stay caller-owned. Timeout/cancel is not remote rollback/zero-cost/hard CPU proof.
- Fresh official Dart3.9.2 archive/fresh checksum matched. Same-run execution
  disconnected once then reconnected; original files verified intact. Fresh exact
  seven-library/two-test graph +original fixture bytes copied again after final
  changes; only flutter_test -> package:test1.26.2. Focused strict casts/inference/
  raw types+lints6.0.0 analysis clean;50/50 passed (28 new HTTP/SDK +22 retained).
  Initial diagnostics fixed typed future inference/curly braces/fixture helper,
  decoded nullable JSON collection types, normal cleanup timing and unused fixture
  stream closure. Assertions retained. Later cancel-error/JWT depth guards included
  in final rerun. Full Flutter/build/SDK-native-network checks require new CI.
- Six paths: new lib/features/ai/data/supabase_ai_text_transport.dart and
  test/features/ai/supabase_ai_text_transport_test.dart; existing captured text
  repository, AI_TEXT_REPOSITORY.md, PROJECT_STATUS.md, qa/matrix.json. Separate
  diff/ownership/limits/late-result/security review; all81 prior QA cases/findings/
  gates retained exactly, add82nd component group/all14 hosted groups pending.
- Publish correct actual-parent base_tree, local/remote tree match/full recursive
  inventory/untouched blob/type/mode checks, six UTF8/SHA readbacks/single parent,
  fresh marker/head and expected-head non-force update. Final commit/tree/new
  exact workflow/latest-attempt/jobs and released checkpoint in41/17/37.
- Next inspect exact-head allfive jobs/every step, fix real diagnostics retaining
  assertions; pending-only handoff/no duplicate work/long polling. After green add
  owned runtime AI factory capturing ready generation/revoke/drain before closure,
  then unavailable/loading/error UI. Existing Auth-only HTTP wrapper disallows
  function routes: use separately scoped owned AI transport, not an endpoint bypass.
  No Pro/content/manifests/fixtures/SQL/RLS/Auth strategy/CI/dependency changes.
  Keep41 draft/17 open/all14 hosted gates pending; no merge/close/deploy/release/
  provider/default activation/schedule action or Personal Alpha claim.


## Owned AI text ready-generation integration — Issue #17, 2026-10-23 UTC

- Sole marker core-20261023T2017-ai-owner; resumed PR41 branch
  automation/issue-11-plan-sdk-integration at exact parent
  e2b403df57ecd6cb0dfcae1da4743c15a51f6237/tree78dcf1bddf49ab08481ccf20cedc05b40cc00185.
  Fresh main78a44fa/source37afa572a/Pro38 unchanged; prior worker released19:30:41 UTC.
- Parent CI40011788906 raw exact head/latest attempt1 completed success, complete
  allfive jobs/every required step/no skips. Unmodified metadata accepted by QA
  verifier; Flutter log120614663554 shows844 Flutter/five Chrome. All28 HTTP
  component cases now have actual Flutter evidence; hosted gates stay pending.
- AiTextRuntimeOwner owns one repository/transport pair per fresh AiTextGeneration,
  with weak retired-token marking, cached acquisition/no implicit dispatch,
  synchronous revoke and asynchronous drain before replacement. Constructor
  reentry/orphans fenced, failed revoke/close permanently disables, safe errors.
  Idempotent close includes construction drain; paused notification listeners
  cannot block resource shutdown. No SDK/token/store/provider ownership added
  to the pure coordinator; concrete transport gains the explicit lifecycle port.
- PersistentSupabaseRuntime factory is explicitly gated by aiTextEnabled=false
  default, exact persisted/own-profile ready runtime/session and fresh generation.
  Both explicit and scheduled refresh revoke before persistence barrier; account
  readiness/logout transitions revoke synchronously. New-generation allocation
  waits for old HTTP drain. HTTP401 cannot recreate under the same generation.
  close revokes before first await/drains before SDK/binding/resource disposal.
  Separate transport-owned/optional borrowed AI HTTP; Auth/REST allowlist untouched.
  Main/staging never enable flag; no provider/default/UI/network activation.
- Fresh official Dart3.9.2 archive/fresh checksum matched; fresh exact eight-library/
  three-test graph +original fixture bytes, only flutter_test -> package:test1.26.2.
  Focused strict casts/inference/raw types+lints6.0.0 analysis clean;69/69 passed
  (19 new owner +50 retained). Initial analyze ran before package resolution and
  returned import failures; after successful pub get, clean analysis observed.
  No source/assertion weakening or full local Flutter/SDK-assembly/build claim.
- Eight actual owned SDK/runtime/vault/profile/AI HTTP tests authored: default-off,
  startup persist/profile gate/cache, refresh held-header drain/exact bearer,
  logout/new account, shutdown/borrowed resource drain, vault failure, profile
  retry and HTTP401/fresh generation. These require new exact-head full Flutter CI.
  Fixture HTTP/OS/unsigned JWT/component success is not hosted learner proof.
- Eight paths: new lib/features/ai/application/ai_text_runtime_owner.dart,
  test/features/ai/ai_text_runtime_owner_test.dart,
  test/features/ai/persistent_ai_text_runtime_test.dart; concrete text transport,
  persistent_supabase_runtime.dart, docs/AI_TEXT_REPOSITORY.md, this status,
  qa/matrix.json. Separate diff/ownership/readiness/reentry/close/security review;
  all82 prior QA cases/findings/gates exact, add83rd component group/14 pending.
- Publish using correct actual parent base_tree/full recursive inventory/local
  tree match/untouched blob-type-mode proof, eight exact UTF8/SHA readbacks,
  single parent/tree and fresh marker/head expected-head non-force update.
  Final commit/tree/new exact workflow/latest-attempt jobs/release in41/17/37.
- Next inspect new exact-head allfive jobs/every step, retaining assertions when
  fixing real diagnostics. Pending-only handoff/no duplicate implementation or
  long polling. After green build tutor UI with unavailable/loading/error/success
  and captured owner lease through the explicit factory, no mock success or live
  provider activation. All14 hosted gates pending; keep41 draft/17 open. No Pro/
  content/manifests/fixtures/SQL/RLS/Auth strategy/CI/dependency changes or merge/
  closure/deployment/release/schedule action/Personal Alpha claim.


## Owned AI fixture analyzer fix — Issue #17, 2026-10-23 UTC

- Sole marker core-20261023T2111-ai-owner-analyze; resumed draft PR41 branch
  automation/issue-11-plan-sdk-integration from exact
  b6ab534f1b9d6dfae0d0e4c0d00507978c099ce9/tree279ad1c82a82c6735520dac4fe97d1983824b8c6.
  Fresh main78a44fa/source37afa572a unchanged; previous worker released20:30:36 UTC.
  Protected Pro14/38/N4/content scope remains untouched.
- CI40019599368, exact parent/latest attempt1, completed failure. Full latest jobs
  page has all five: repo-sanity/ai-boundary/database/windows every step success,
  including both Windows builds and native credential/process checks. Flutter
  pinned format222 files/zero changes passed; analyzer failed with exactly two
  curly_braces_in_flow_control_structures diagnostics at test/features/ai/
  persistent_ai_text_runtime_test.dart129:9 and154:9. Flutter tests, Chrome, Web
  and all downstream Flutter verifiers were skipped, never passed.
- Add blocks only around the multiline TEST ONLY token and ensure_profile fixture
  branches. Keep all eight cases, assertions, helper expressions and response
  behavior intact. Separate diff review verifies exactly four brace tokens added;
  removing those additions recovers the parent file byte-for-byte. No production
  runtime/Auth/vault/HTTP/default/CI/lint/dependency/QA matrix or gate changes.
- Fresh official Dart3.9.2 archive/checksum matched; pinned single-file format
  zero changes (formatter warned Flutter lint include unresolved; not analysis).
  Inventory83 and all46 QA regression tests passed; whitespace clean.
  Local Flutter/full analyzer/eight integrated runtime tests/build were not run.
  New exact-head CI must execute them; the previous69 focused pure Dart passes
  are parent evidence and do not establish these eight integrated cases.
- Two paths only: the fixture above and docs/PROJECT_STATUS.md. Publish using
  actual parent base_tree, full recursive tree/unchanged blob/mode/type proof,
  exact UTF8/SHA readbacks/single parent and fresh marker/head expected-head
  non-force update. Final commit/tree/CI and RELEASED checkpoint in41/17/37.
- Next inspect exact new-head/latest-attempt all five jobs and every required step;
  fix observed diagnostics without weakening tests. Pending-only handoff/no
  duplicate implementation or long polling. After full green, implement explicit
  unavailable/loading/error/success tutor UI through the owned ready-generation
  factory. Keep41 draft/17 open/all14 hosted release groups pending; no merge,
  deployment/provider/default activation/security reduction or Personal Alpha claim.


## Captured AI text view controller — Issue #17, 2026-10-23 UTC

- Sole marker core-20261023T2207-ai-controller; resumed draft41 branch
  automation/issue-11-plan-sdk-integration at actual parent
  5c3e58ab20be8731924c070467d74106bba2ab3b/tree4ad64da90a564d153545054fcc4c8ed236f3266f.
  Fresh main78a44fa/source37afa572a unchanged; prior worker released21:16:05 UTC.
- Parent CI40025398321 raw exact head/latest attempt1 completed success: full
  allfive jobs/every required step/no skips. Actual Flutter analyzer clean,
  871 Flutter/five Chrome including all eight owned SDK/runtime/vault/profile/
  AI HTTP cases and19 owner tests. Windows/native/SQL/Edge retained. The two
  previous missing fixture blocks are verified fixed; no hosted learner claim.
- Add pure borrowed-capability AiTextController, prerequisite to mounted tutor UI.
  Explicit N5/N4 explain/correct; unavailable/idle/loading/success/error/pending;
  strict existing DTOs/exact accepted text/level/operation/typed result, no save or
  invented correction/mastery/plan credit. Register before supplied callbacks,
  duplicate/reentrant/external/timeout-held wire guards, fixed safe errors,
  no automatic resend, stored retry request, timers or fallback success.
- State reads/completions check captured lease. Owner must synchronously invalidate
  on readiness loss; fresh controller/capability required after replacement.
  Revocation/disposal permanently clears accepted text/results and fences late
  success/error/A-B-A. Void async hints never carry old text snapshots; consumers
  read current state. Error/closed availability stream fails closed. Disposal owns
  only its subscription/notifications, does not revoke or close borrowed runtime;
  paused UI listeners cannot hold shutdown. Actual screen/draft clearing follows.
- Fresh official Dart3.9.2/checksum matched; identical six-library/four-test graph
  plus original frozen fixtures, only flutter_test -> package:test1.26.2, passed
  78/78 tests (20 new controller +58 retained models/repository/owner).
  Focused strict casts/inference/raw types+lints6.0.0 analysis no issues; two-file
  pinned format zero changes (app Flutter lint include unresolved warning, not
  full analyzer proof). Inventory84/46 QA regressions/whitespace passed. No new
  local full Flutter/widgets/build/SDK graph or hosted identity/provider proof.
- Five paths: new lib/features/ai/application/ai_text_controller.dart,
  test/features/ai/ai_text_controller_test.dart, docs/AI_TEXT_CONTROLLER.md;
  this status, qa/matrix.json. Separate source/diff/lease/reentry/error/lifetime
  review; all83 old QA objects/findings/gates exact/add84th/all14 hosted pending.
  Existing runtime, routes/providers/defaults, fixtures/contracts/SQL/RLS/Auth/
  dependencies/CI and protected Pro14/38/content/manifests untouched.
- Publish correct actual base_tree/full recursive tree/local tree match/unchanged
  blob-type-mode checks, allfive UTF8/SHA readbacks/single parent and fresh own
  marker/head expected-head non-force update. Final commit/tree/new exact CI/
  latest attempt and released checkpoint in41/17/37.
- Next inspect exact new-head allfive jobs/every required step; pending-only
  handoff/no duplicate implementation/long polling. After green implement
  Riverpod/route/tutor screen through explicit owned factory, safe plain text,
  request-bound drafts/results and mobile/large-text/session-clearing widgets.
  Do not enable aiTextEnabled in default/staging or bypass hosted/provider/
  collection/spend gates. Keep41 draft/17 open/all14 hosted pending; no merge,
  close/deploy/release/schedule action/Personal Alpha claim.


## Injectable AI tutor/correction screen — Issue #17, 2026-10-23 UTC

- Sole marker core-20261023T2313-ai-screen; resumed draft41 branch
  automation/issue-11-plan-sdk-integration at exact parent
  fcd0861b2cbca43ba064392b4536d32dedf6c4dc/tree73b41665d98aabe5dd735a2eb4e37c7c1a11b57e.
  Fresh main78a44fa/source37afa572a unchanged; prior released22:18:30 UTC.
- Parent CI40032646839 raw exact head/latest attempt1 completed success, complete
  allfive jobs/every required step/no skips. Flutter log120685085809 shows clean
  analyze/891 Flutter/five Chrome including20 controller cases; retained owned
  SDK/runtime/Windows/native/SQL/Edge proof. No hosted learner acceptance.
- /ai consumes null-default immutable AiTextViewBinding through Riverpod and
  preserves exact prior unavailable preview/route/mobile assertions when absent.
  An explicitly injected captured repository enables N5/N4 explain/correct input,
  bounded5000 code points/exact whitespace, explicit send/loading/safe error/
  pending/recheck/typed plain-text answer/examples/practice/corrections. Empty
  errors stay empty; voice unavailable/reference results not saved progress.
- Mounted binding identity owns ephemeral controller/editor/focus/subscription,
  never SDK/HTTP/repository. Revocation clears editor/results; removal/replacement
  disposes private state. Request-bound revision/level/mode/text callbacks cannot
  retarget new edits/selections/accounts; held work disables changes and duplicate
  send. External wire-busy offers explicit status check/no polling/auto retry.
  Host still must synchronously revoke/remove binding on readiness loss; actual
  owned startup/factory-to-provider bridge remains next work, not claimed done.
- Fifteen widgets authored/unrun locally: null preview/exact explicit explanation,
  N4 correction/empty errors/held controls, safe failure/recheck/malformed literal
  model text, edit/selection/stale-send fences, revoke/editor clearing, A/B binding
  replacement with late success/error, source removal/borrowed resources, Unicode
  paste limit, external busy and320/375px at200% text success/error. New exact-head
  Flutter analyzer/full suite/platform/build evidence required, not passed locally.
- Fresh official Dart3.9.2/fresh checksum matched; four changed Dart files pinned
  format clean (unresolved app Flutter lint include warning, not full analysis).
  Inventory85/46 QA regressions/whitespace passed. Separate source/diff/callback/
  lifecycle/plain-text/limits review; all84 old QA cases/findings/gates exact +85th,
  all14 hosted release groups pending. No original tests weakened or edited.
- Seven paths: new ai/application/ai_text_view_binding.dart,
  ai/presentation/ai_tutor_screen.dart, test/features/ai/ai_tutor_screen_test.dart,
  docs/AI_TUTOR_SCREEN.md; app/router.dart, this status, qa/matrix.json.
  Existing runtime/controller/Auth/SDK/vault/main/staging/AI flag/providers/keys/
  contracts/fixtures/SQL/RLS/dependencies/CI and Pro14/38/content/manifests unchanged.
  No fake Auth/save/default/live provider or additional collection activation.
- Publish correct actual parent base_tree/full recursive inventory/local tree
  equality/unchanged blob-type-mode proof, allseven UTF8/SHA readbacks/single parent
  and fresh own marker/head expected-head non-force update. Final commit/tree/new
  exact workflow/latest attempt/release in41/17/37.
- Next inspect exact new-head allfive jobs/every required step, fix real diagnostics
  retaining assertions; pending-only handoff/no duplicate code/long polling. Then
  explicit owned ready-generation startup/provider bridge and SDK/vault/profile/
  UI refresh/logout/A-B-A/drain fixtures. Keep defaults off/41 draft/17 open/all14
  hosted groups pending; no merge/close/deploy/release/provider/spend/collection/
  security/schedule action or Personal Alpha claim.


## Tutor SDK compile/analyzer correction — Issue #17, 2026-10-24 UTC

- Sole marker core-20261024T0010-ai-screen-fix; resumed draft41 branch
  automation/issue-11-plan-sdk-integration at exact parent
  9bb5e4c6c0af53440c792c399b3ef58f189e85ed/treef887f8ffee5dd71a31d57f206b8103e9cf6cbe3f.
  Fresh main78a44fa/source37afa572a unchanged; prior released23:24:43 UTC.
- CI40039427005 raw exact parent/latest attempt1 completed failure, complete all
  five latest jobs observed. AI/database/repo-sanity every step success. Flutter
  pinned format passed, then analyzer reported const_with_non_const at screen243
  and library_private_types_in_public_api at test70. Windows first TEST ONLY bridge
  build failed for the same invalid const Semantics. Remaining Flutter tests/15 new
  widgets/Chrome/Web/native/Windows builds and verifiers skipped, never passed.
- Remove const only from the non-const Semantics constructor; keep its Text child
  const, unchanged loading text/liveRegion. Rename fixture mount helper to _mount
  and all13 call sites, keeping its private Harness parameter. Separate exact
  diff/inverse-transform review recovers both parent files byte-for-byte after
  reversing only those changes: all13 test declarations/15 expanded widget cases,
  assertion bodies, fixtures and UI behavior retained. No suppression or lint/
  test/SDK/CI/dependency/security reduction. Original app tests unchanged.
- Fresh official Dart3.9.2 archive/fresh checksum matched; two-file pinned format
  zero changes (unresolved app Flutter lint include warning, not analyzer proof).
  Inventory85/46 QA regressions/whitespace passed. Full local Flutter/analyzer/
  widgets/platform/build unrun; new exact-head CI must confirm this correction.
- Three paths only: lib/features/ai/presentation/ai_tutor_screen.dart,
  test/features/ai/ai_tutor_screen_test.dart, docs/PROJECT_STATUS.md. Runtime/
  controller/route/binding/main/staging/AI flag/Auth/vault/SQL/RLS/fixtures/QA
  matrix/contracts/CI/dependencies and Pro14/38/content/manifests unchanged.
- Publish correct actual parent base_tree/full recursive tree/local tree match/
  unchanged blob-type-mode proof, three UTF8/SHA readbacks/single parent and fresh
  own marker/head expected-head non-force update. Final commit/tree/new exact
  workflow/latest attempt and released checkpoint in41/17/37.
- Next inspect exact new-head allfive jobs/every required step, especially the15
  widgets; fix actual diagnostics retaining assertions. Pending-only handoff/no
  duplicate code/long polling. After full green continue actual owned-startup/
  ready-generation factory-to-provider bridge and SDK/vault/profile/UI lifecycle
  fixtures. Keep defaults off/41 draft/17 open/all14 hosted groups pending. No
  merge/close/deploy/release/Auth strategy/provider/spend/collection/security/
  schedule action or Personal Alpha claim.


## AI dependency audit remediation — Issue #17/#18, 2026-10-24 UTC

- Sole marker core-20261024T0109-fast-uri; resumed draft41 branch
  automation/issue-11-plan-sdk-integration from exact
  75e7bc808d6f20888cb9a07bd319c40270088b2b/treeb4e1eaca123ac51ab91d4f639c077652349880e8.
  Fresh main78a44fa/source37afa572a unchanged; prior released00:14:24 UTC.
- Parent CI40043896926 raw exact head/latest attempt1 completed failure. Complete
  five jobs observed: Flutter/windows/database/repo-sanity every required step
  success; Flutter log120721489794 clean analyze/906 tests/five Chrome, including
  all15 tutor widgets. Both previous compile/analyzer fixes verified. AI job stopped
  at mandatory production npm audit; subsequent AI/TypeScript/Node/Deno/Edge steps
  skipped, not passed. Native/Windows component evidence is not hosted proof.
- Audit flagged Ajv's fast-uri3.1.8 for four moderate advisories:
  GHSA-w74x-v6f9-j3xg, GHSA-xhq7-xmqj-769h, GHSA-wjr9-j795-jxcr and
  GHSA-333x-w4r6-6crp. GitHub-reviewed primary advisory updated2026-10-23 confirms
  patched3.1.9 within Ajv's existing ^3.0.1 range:
  https://github.com/advisories/GHSA-w74x-v6f9-j3xg .
- npm update fast-uri --package-lock-only --ignore-scripts --no-audit --no-fund
  changes only fast-uri3.1.8 ->3.1.9 version/resolved URL/integrity. Separate parsed
  lock comparison: every other package/root object exact, all other fast-uri fields
  exact; package.json/source/tests/CI/security threshold unchanged. No override,
  major upgrade, audit exclusion or reduced validation. Strict URI normalization
  is the upstream security fix, not evidence of an exploitable app path.
- Clean npm ci --ignore-scripts --no-audit --no-fund succeeded; unchanged npm audit
  --omit=dev --audit-level=moderate reports0 vulnerabilities. Prettier format:check,
  tsc --noEmit and185/185 existing Node tests passed, zero skipped/cancelled/fail.
  Local Node24.19.0/npm11.9.0 differs from CI24.21.0/npm11.19.0; new exact-head
  full CI/Deno/native checks remain required. Inventory85/46 QA regressions/
  whitespace passed. No full local Flutter/Windows/Deno/PostgreSQL/hosted claim.
- Two paths only: backend/ai/package-lock.json and docs/PROJECT_STATUS.md.
  Protected Pro14/38/content/manifests, app/UI/Auth/SDK/vault/default AI flag,
  schemas/RLS/contracts/fixtures/QA matrix/dependency manifest/workflows untouched.
- Publish correct actual parent base_tree/full recursive tree/local tree equality/
  unaffected blob/mode/type proof, both UTF8/SHA readbacks/single parent and fresh
  own marker/head expected-head non-force update. Final commit/tree/exact workflow/
  latest attempt/released checkpoint in41/17/37.
- Next inspect exact new-head allfive jobs/every required step; pending-only handoff/
  no duplicate code/long polling. Once full green continue owned ready-generation
  startup/factory-to-provider bridge with SDK/vault/profile/UI lifecycle fixtures.
  Keep41 draft/issues open/defaults off/all14 hosted pending. No merge/deploy/
  release/provider/Auth strategy/collection/spend/security reduction/schedule change
  or Personal Alpha claim.


## Owned AI source/startup/provider bridge — Issue #17, 2026-10-24 UTC

- Sole marker core-20261024T0211-ai-source; resumed draft41 branch
  automation/issue-11-plan-sdk-integration at1f18fa1c20755f7c347eea92c4afeb3b1b060421
  /treeb6aa1d4f5b64d39a5175a1af10b3a34bd5729d1a. Fresh main78a44fa/source37afa572a
  unchanged; prior released01:13:15 UTC. Pro14/38/content remains reserved.
- Parent CI40048725761 raw exact head/latest attempt1 completed success: complete
  allfive jobs/every required step/no skips. Prior dependency audit fix is verified;
  existing906 Flutter/five Chrome/15 tutor widget and owned SDK/native/Windows/
  SQL/Edge component evidence retained, not hosted acceptance.
- Add pure AiTextRepositorySource: captured no-request factory +credential-free
  availability. Existing PersistentSupabaseRuntime implements; owned startup
  forwards; startup controller exposes only active/not-closing source. Startup
  ProviderScope overrides null-default source provider. No SDK/token/HTTP exposed,
  no change to aiTextEnabled=false/main/staging/provider/Auth strategy.
- Public view-binding Provider override API retained. Internal notifier watches
  account state and borrowed source availability, preserving binding for identical
  current repo; clears/replaces on missing/revoked/new generation. Account changes
  trigger acquisition even before any AI lease exists. Factory retains actual
  persisted/profile readiness/drain guards. Getter/stream error/done fail closed;
  factory exceptions return null, no raw detail. Reentry guarded; disposal cancels
  only owned subscription, never borrowed source/repository/resources. No text
  dispatch/retry or timer introduced. Runtime synchronous revoke remains required.
- Nine source/notifier/startup cases authored UNRUN locally: null/default, cached
  identity/no request, null/new-account transitions, revoked/failing factory,
  broken stream getter, stream error/done, disposal/borrowed lifetime and source
  hidden before held startup/after close. Full new-head Flutter/analyze/build
  required; actual SDK-to-mounted-tutor lifecycle journey remains next validation.
- Fresh official Dart3.9.2 archive/checksum matched; changed Dart pinned format
  clean (unresolved Flutter lint include warning, not full analyzer proof).
  Inventory85/46 QA regressions/whitespace passed. Separate interface/forwarding/
  identity/ownership/reentry/failure diff review; original app/widget/SDK tests,
  security/QA gates/CI/dependencies/content/manifests/Pro branch untouched.
- Nine paths: new ai/data/ai_text_repository_source.dart and ai_text_source_test.dart;
  ai_text_view_binding.dart, persistent_supabase_runtime.dart,
  persistent_account_startup.dart, account_startup_controller.dart,
  account_startup_app.dart, docs/AI_TUTOR_SCREEN.md, docs/PROJECT_STATUS.md.
- Publish actual parent base_tree/full recursive tree/local equality/unchanged
  blob-type-mode proof, nine UTF8/SHA readbacks/single parent and fresh own marker/
  head expected-head non-force update. Final commit/tree/new exact CI/latest
  attempt/released checkpoint in41/17/37. Keep41 draft/issues open/defaults off/
  all14 hosted pending; no merge/deploy/release/provider/collection/spend/security/
  schedule action or Personal Alpha claim. Next exact CI then actual owned SDK/
  vault/profile/startup/mounted UI refresh/logout/A-B-A/drain journey fixtures.


## Windows AI source completion and mounted SDK journey — #17, 2026-10-24 UTC

- Sole marker core-20261024T0316-ai-journey; resumed draft41 branch
  automation/issue-11-plan-sdk-integration at exact
  093baab8e257374676c9330ded5bf2c479d63b8f/tree3a0add924ba2ca611a86f2c1de91e8d94d359242.
  Fresh main78a44fa/source37afa572a unchanged; prior marker released02:17:26 UTC.
  Pro14/38/content/manifests remain reserved and untouched.
- Parent CI40053492651 raw exact093baab/latest attempt1 completed success:
  complete allfive jobs/every required step/no skips. Flutter log120751535130
  confirms915 tests including allnine new source cases and five Chrome cases;
  retained15 tutor widgets/native/Windows/SQL/Edge steps passed. Component evidence
  only, not hosted learner acceptance.
- Source review found the outer WindowsStagingOwner did not implement the new
  AiTextRepositorySource. Startup's active controller therefore saw no source
  through the actual production wrapper. Add only interface/captured factory
  forwarding while not closing and borrowed stream forwarding. Runtime ready/
  generation/persistence/profile/drain guards remain authoritative. No build
  switch/aiTextEnabled=false/main/staging/provider/Auth strategy/resource change.
- Eight expanded new widget cases exercise actual pinned SDK/native review file/
  Windows owner/startup/controller/app/default Riverpod source+binding/router/tutor,
  with TEST ONLY Auth/REST/AI HTTP/vault ports, no binding/account overrides.
  Startup holds rotated-secret write then profile independently/no early dispatch;
  exact explain/context/whitespace/bearer; disabled host; refresh old success/error
  after ignored abort/no allocation before old drain/fresh explicit N4 correction;
  A-B-A old result/editor/callback isolation; vault/profile failure and explicit
  recovery/no implicit send; owned close publication/revocation/drain/borrowed HTTP/
  retained saved secret. Real-loop filesystem/runtime barriers, bounded waits.
- New eight cases UNRUN locally; full new-head Flutter/analyzer/platform/build
  awaits CI. Fresh official Dart3.9.2 archive checksum matched; both changed Dart
  files format clean (unresolved Flutter lint include warning, not analyzer proof).
  Inventory86/46 QA regressions/whitespace checks and separate diff/lifetime/wire/
  fixture review recorded before publication. No prior denied Flutter bootstrap
  retry/bypass. Existing test bodies/assertions/CI/gates/dependencies unchanged.
- Five paths: lib/app/staging_bootstrap.dart; new test/features/ai/
  ai_owned_startup_journey_test.dart; docs/AI_TUTOR_SCREEN.md, PROJECT_STATUS.md,
  qa/matrix.json. All85 previous QA cases/findings/gates retained exactly; one
  additional component group, all14 hosted release groups still pending.
- Publish with correct actual parent base_tree/full recursive tree/unaffected
  blob-type-mode proof/local Git tree equality, allfive UTF8/blob SHA readbacks,
  single parent/tree, fresh own marker/head and expected-head non-force update.
  Final commit/tree/exact new workflow/latest attempt/released checkpoint in41/17/37.
- Next inspect exact new-head latest-attempt allfive jobs/every required step;
  correct real failures retaining assertions. Pending-only handoff/no duplicate
  implementation/long polling. Keep41 draft/issues open/default AI off. Hosted
  Auth/provider/voice/learner/physical launch and applicable release/security/
  collection/spend gates remain; no merge/close/deploy/release/schedule action or
  Personal Alpha claim.


## Owned AI widget fixture cleanup — #17, 2026-10-24 UTC

- Sole marker core-20261024T0416-ai-fixture; resume draft41 branch
  automation/issue-11-plan-sdk-integration at exact
  12e8de5e93c1a7ed3584494ecec48a03ec42fccc/treee6710e13140e057e1c0f35d4c4197fa84e866d59.
  Main78a44fa/source37afa572a/Pro14/38 unchanged; previous marker released03:25:48 UTC.
- Parent CI40058196322 raw exact12e8de5/latest attempt1 completed failure.
  Complete allfive jobs observed: database/repo-sanity/ai-boundary/Windows every
  required step success/no skips; Flutter format/analyze pass, full tests fail.
  Log120766098664:916 passed/seven failed. First new actual SDK/Windows owner/
  startup/rotation/profile/mounted-explain case passed; seven later journeys
  failed constructing runtime with SessionVaultFailure(unavailable) at exclusive
  target check. Flutter's downstream SDK/Chrome/native/Web steps skipped, not pass.
- Fix fixture cleanup ordering: all cases run inside widget-body try/finally;
  await tester.runAsync owned close/journal cleanup before body return/automatic
  widget disposal. New assertion checks actual target no longer owned after close.
  Remove deferred addTearDown callback that left target held between cases.
  Six original declarations/two boolean loops still expand to eight cases;
  complete original main bodies/assertions preserved except wrapper name.
  No production lock reset/unique project bypass/timeout extension/test skip or
  weakened assertion. Existing source forwarding/default flags/SDK/vault/RLS/
  provider/content/Pro/QA cases/gates/dependencies/workflows unchanged.
- Fresh official Dart3.9.2 archive checksum verified, changed fixture formatted
  (unresolved Flutter lint include warning, not full analyzer proof). Inventory86,
  46 QA regressions and whitespace passed. Separate lifecycle/diff/byte comparison
  confirms all original test bodies and assertions retained. No new local Flutter/
  analyzer/build run or previously denied bootstrap retry/bypass.
- Three paths only: ai_owned_startup_journey_test.dart, docs/AI_TUTOR_SCREEN.md and
  PROJECT_STATUS.md. Publish correct parent base_tree/full recursive tree/local
  tree equality/unchanged blob/type/mode proof, three exact UTF8/blobSHA readbacks,
  single parent/tree and fresh own marker/head expected-head non-force update.
  Final commit/new exact workflow/latest attempt/released checkpoint in41/17/37.
- Next inspect complete exact new-head/latest-attempt allfive jobs/every required
  step and actual eight journey logs; fix remaining real diagnostics retaining
  assertions. Pending-only handoff/no duplicate code/long polling. Keep41 draft,
  issues open/default AI off/all14 hosted release groups pending. Hosted identity/
  provider/voice/learner/physical launch and human gates remain; no merge/closure/
  deployment/release/provider/Auth strategy/collection/spend/security/schedule
  change or Personal Alpha claim.


## Mounted AI HTTP401 lifecycle regression — #17, 2026-10-24 UTC

- Sole marker core-20261024T0508-ai-unauthorized; resume draft41 branch
  automation/issue-11-plan-sdk-integration at03ca4e308c6a684fb8b313268606c4c85df248e3
  /treebaf7dd870969dff5a993e33d1c2bdba80ad25911. Main78a44fa/source37afa572a/
  Pro14/38 unchanged; previous marker released04:19:53 UTC.
- Parent CI40061875705 raw exact03ca4e3/latest attempt1 completed success:
  allfive jobs/every required step/no skips. Flutter log120777261349 confirms923
  tests/all8 actual owned-startup/tutor journeys including per-case ownership
  release assertion and five Chrome cases; native/Windows/SQL/Edge/builds passed.
  Previous fixture cleanup verified. Component evidence, not hosted acceptance.
- Add one meaningful integration case, actual owned startup/default providers/
  router/mounted tutor/SDK-bound HTTP401 after a displayed strict answer. Check
  previous answer/rejected editor removal, raw private body redaction, permanent
  old repo revocation despite account-ready state, no auto AI/Auth dispatch,
  retained callback/factory/navigation cannot resurrect capability. Explicit
  owner refresh/persisted rotation/profile readiness grants different capability
  and empty editor; old callback still fenced; fresh explicit request uses new
  captured bearer. Existing owned finally/actual target release assertion reused.
- Ninth case authored UNRUN locally; all original8 bodies/helpers/assertions kept
  byte-for-byte before appended case. No production source/lock/default flag/
  SDK/vault/schema/RLS/provider/Auth strategy/Pro/content/QA matrix/gate/workflow/
  dependency change. Main and staging AI remain disabled/all14 hosted groups pending.
- Fresh official Dart3.9.2 checksum verified; fixture pinned format clean with
  unresolved Flutter lint include warning (not full analysis). Inventory86,
  46 QA regressions/whitespace passed. Separate actual source/wire/lifecycle/diff
  review; no local new Flutter/analyzer/build execution or denied bootstrap retry.
- Three paths: ai_owned_startup_journey_test.dart, docs/AI_TUTOR_SCREEN.md and
  PROJECT_STATUS.md. Publish correct actual parent base_tree/full recursive tree/
  local equality/unaffected blob-type-mode proof; allthree exact UTF8/blobSHA/
  single parent/tree readbacks then fresh own marker/head expected-head nonforce.
  Final commit/tree/exact workflow/latest attempt/released handoff in41/17/37.
- Next exact new-head latest-attempt allfive jobs/every required step/ninth case
  logs; fix real diagnostics retaining assertions. Pending-only handoff/no duplicate
  implementation/long polling. After green review remaining #17 text-conversation
  integration and independent ready work. Keep41 draft/issues open/defaults off;
  hosted identity/provider/voice/learner/physical launch/human gates remain. No
  merge/close/deploy/release/provider/collection/spend/security/schedule action or
  Personal Alpha claim.


## Frozen conversation mutation request models — #17, 2026-10-24 UTC

- Sole marker core-20261024T0608-conversation-requests; resume draft41 branch
  automation/issue-11-plan-sdk-integration at5376cd43ef953d2842d3664ef31257ca04fa2dda
  /tree38cecdd1af5f3d58e3c57830069705f2885ee81a. Main78a44fa/source37afa572a/
  Pro14/38 unchanged; previous marker released05:11:46 UTC.
- Parent CI40065258364 raw exact5376cd4/latest attempt1 completed success:
  allfive jobs/every required step/no skips. Flutter log120787422501 confirms924
  tests/ninth mounted HTTP401 journey and five Chrome cases; native/Windows/SQL/
  Edge/builds passed. Component evidence, not hosted learner/provider acceptance.
- Independent #17 prerequisite: immutable StartConversationRequest,
  ConversationTurnRequest and FinishConversationRequest. Match frozen v0.1 field
  sets/fixture wire exactly; strict fromJson rejects extra/missing/null/wrong types.
  Preserve caller scenario/session/event ID spelling including nil/uppercase;
  no UUID generation or retry. Fresh scalar maps do not mutate accepted request.
  Reuse allfive wire levels without expanding N5/N4 product scope. Preserve exact
  turn whitespace/combining characters;1..5000 code points/early10000 UTF16 bound.
  Fixed FormatException without source/raw input. Structural validation does not
  establish owner/scenario existence/server receipt or authorize dispatch.
- Seven pure-Dart groups passed: three frozen fixture round trips; five levels/
  uppercase/nil; mutated input/export/captured identity; Unicode bounds; every
  constructor identifier; malformed shapes/fields/authority injection; redacted
  failure. Fresh official Dart3.9.2 checksum matched; identical three-file graph/
  fixtures/original test bodies in disposable harness, only Flutter test import
  replaced by package:test1.26.2. Strict casts/inference/raw-types +lints6 analysis
  no issues after explicit empty collection types; all assertions retained.
  This is not actual Flutter/SDK/network/hosted proof.
- Both new Dart files formatted; inventory87/46 QA regressions/whitespace passed.
  Separate schema/wire/immutability/bounds/diff review; all86 prior QA cases,
  findings and gates exact; all14 hosted groups pending. No full local Flutter/
  analyzer/build run or denied bootstrap retry/bypass. No old app/source/test,
  Auth strategy/provider/default/schema/RLS/dependency/workflow/Pro/content edits.
- Five paths: new lib/features/ai/domain/conversation_requests.dart and
  test/features/ai/conversation_requests_test.dart; new docs/CONVERSATION_REQUESTS.md;
  docs/PROJECT_STATUS.md and qa/matrix.json. Publish actual parent base_tree/full
  recursive tree/local tree equality/unaffected mode-type-blob proof, five exact
  UTF8/blobSHA/single parent/tree readbacks then fresh own marker/head and
  expected-head non-force update. Final commit/tree/new exact workflow/latest
  attempt/released checkpoint in41/17/37.
- Next inspect exact new-head/latest-attempt allfive jobs/every required step;
  pending-only handoff/no duplicate code/long polling. After green add strict
  conversation response DTOs then captured-session idempotent gateway/recovery/UI.
  Request models alone are not receipt/durable retry/ownership/voice proof.
  Keep41 draft/issues open/AI defaults off/all14 hosted pending; no merge/close/
  deploy/release/provider/Auth strategy/collection/spend/security/schedule action
  or Personal Alpha claim.


## Frozen conversation response models — #17, 2026-10-24 UTC

- Sole marker core-20261024T0706-conversation-responses; resume draft41 branch
  automation/issue-11-plan-sdk-integration at061643f9577966cefbce961b65c6116e73304929
  /tree4324615da18442aad5aa5f7f52ab45bbb8880d75. Main78a44fa/source37afa572a/
  Pro14/38 unchanged; prior marker released06:14:11 UTC.
- Parent CI40069345322 raw exact061643f/latest attempt1 completed success:
  allfive jobs/every required step/no skips. Flutter log120799571266 confirms931
  tests/all7 request-model cases and five Chrome cases; native/Windows/SQL/Edge/
  builds passed. Component evidence, not hosted learner/provider acceptance.
- Independent #17 prerequisite: strict immutable start/turn/finish response DTOs,
  assistant message and scores; private constructors/validated factories. Require
  exact object shapes/assistant role/UUID/nonnegative Dart integer sequence,
  required explicitly nullable translation/audio, exact bounded Unicode strings.
  Optional live_feedback omitted vs empty preserved; present null rejected.
  Scores allthree finite numeric0..100 preserve integer/fractional values.
  Lists0..100 and nested correction/ref limits; reuse existing immutable strict
  AiTextCorrection/AiTextItemRef, normalize failures to fixed response error with
  no raw input/source. Snapshots/unmodifiable collections/fresh deep exports;
  empty and schema-permitted duplicate refs retained. Audio is opaque, never
  opened/played; recommendations authorize no SRS/progress/learning write.
- 8/8 pure Dart groups passed: three original frozen response round trips;
  optional feedback/nullables; message keys/role/IDs/sequence; Unicode/audio bounds;
  finite numeric limits; every list0/100/101; nested alias/export mutation and
  immutable views; malformed nested corrections/refs/mixed errors/safe failure.
  Fresh official Dart3.9.2 checksum matched; exact three-file production/test graph
  +unchanged fixture in disposable harness, only Flutter test import adapted to
  package:test1.26.2. Strict casts/inference/raw types+lints6 analyzer no issues.
  Pure evidence is not actual Flutter/network/SDK/hosted proof.
- Both new Dart files pinned format clean; inventory88/46 QA regressions/whitespace
  passed. Separate schema/optional/role/score/bounds/immutability/diff review;
  all87 old QA cases/findings/gates exact/all14 hosted pending. No old source/test,
  default flag/Auth strategy/provider/SDK/vault/RLS/contract/CI/dependency/Pro/content
  changes. No full local Flutter/analyzer/build or denied bootstrap retry/bypass.
- Five paths: new lib/features/ai/domain/conversation_responses.dart and
  test/features/ai/conversation_responses_test.dart; new docs/CONVERSATION_RESPONSES.md;
  docs/PROJECT_STATUS.md and qa/matrix.json. Publish actual parent base_tree/full
  recursive tree/local equality/unaffected blob-mode-type proof; five exact UTF8/
  blobSHA/single parent/tree readbacks then fresh own marker/head expected-head
  non-force update. Final commit/tree/exact new CI/latest attempt/released handoff
  in41/17/37.
- Next exact new-head/latest-attempt complete allfive jobs/every required step;
  fix real diagnostics retaining assertions. Pending-only handoff/no duplicate
  source/long polling. After green bind request/response DTOs to captured-session
  idempotent conversation gateway/recovery/UI; server owns auth/receipts. No
  owner/message correlation/transport/retry/voice acceptance follows from DTOs.
  Keep41 draft/issues open/AI defaults off/all14 hosted pending; no merge/close/
  deploy/release/provider/Auth strategy/collection/spend/security/schedule action
  or Personal Alpha claim.


## One captured immutable conversation mutation — #17, 2026-10-24 UTC

- Sole marker core-20261024T0808-conversation-mutation; resume draft41 branch
  automation/issue-11-plan-sdk-integration at81bd0f70102cc711d3c99fff2d936b3ff4c5753c
  /tree703041be8a7e92017b6260ebf6f2521f44fdaf60. Main78a44fa/source37afa572a/
  Pro14/38 unchanged; previous marker released07:12:55 UTC.
- Parent CI40073204935 raw exact81bd0f7/latest attempt1 completed success:
  allfive jobs/every required step/no skips. Flutter log120811279750 confirms939
  tests/all8 response-model cases and five Chrome cases; native/Windows/SQL/Edge/
  builds passed. Component evidence, not hosted learner/provider acceptance.
- Add per-event CapturedConversationMutation<T> with typed start/turn/finish
  factories and borrowed unconfigured ConversationMutationTransport. One fixed
  immutable scalar request/operation/client_event_id and exact captured session/
  ready-generation fence. Construction sends nothing; explicit submit only.
  Accepted typed success cached locally/no second dispatch while current; cache
  is not durable receipt proof. Manual retry after uncertainty reuses same object/
  wire/event identity; no generated IDs or auto retry. Register singleflight before
  supplied port can reenter; positive<=15s timeout remains uncertain, busy until
  accepted injected future settles. Consume late errors/success without caching.
  Check identity/readiness before dispatch/publication/cache; permanent observed
  loss/getter/unauthorized fence, explicit revoke drops cached publication. Safe
  frozen error parser discards raw messages/unknown errors and restricts retryable.
- 13/13 injected-port pure Dart tests passed: exact three frozen wires/typed
  decoders/cache, same-wire manual retry, reentry/duplicates, timeout late success/
  error, A-B-A late success/error, ready-loss/revoke/cache, unauthorized/redaction,
  malformed/errors/unknown exceptions, nontransient flags/getter failures,
  unavailable construction/deadlines and same-user fresh identity. Fresh official
  Dart3.9.2 checksum verified; exact eight-file production/test graph+unchanged
  fixture in disposable harness, only test runner import adapted to test1.26.2.
  Strict casts/inference/raw types+lints6 analyzer clean after one explicit empty
  test-map type; all assertions retained. Not actual SDK/HTTP or hosted proof.
- SDK HTTP, global cross-instance serialization/event uniqueness, message/session
  correlation, durable receipts/restart recovery/UI remain next work. Port must
  bind actual captured bearer/generation, limit trusted fixed HTTP/JSON and block
  fresh dispatch while ignored-abort network work drains; injected future settle
  alone is not remote drain/rollback proof. Caller must revoke every owner barrier.
  No borrowed SDK/HTTP/vault/journal ownership/cleanup, transcript persistence,
  provider/default/voice/Auth strategy activation or learning/progress/SRS write.
- Both new Dart files pinned format clean; inventory89/46 QA regressions/whitespace
  passed. Separate reentry/drain/lifecycle/wire/immutability/error/scope/diff review;
  all88 old QA cases/findings/gates exact/all14 hosted pending. No old source/test,
  default flag/SQL/RLS/contract/CI/dependency/Pro/content edits or full local Flutter/
  analyzer/build/denied bootstrap retry/bypass.
- Five paths: new lib/features/ai/data/captured_conversation_mutation.dart and
  test/features/ai/captured_conversation_mutation_test.dart; new
  docs/CAPTURED_CONVERSATION_MUTATION.md; docs/PROJECT_STATUS.md and qa/matrix.json.
  Publish actual parent base_tree/full recursive tree/local equality/unaffected
  blob-type-mode proof, five exact UTF8/blobSHA/single parent/tree readbacks then
  fresh own marker/head expected-head non-force update. Final commit/tree/new
  exact workflow/latest attempt/released handoff in41/17/37.
- Next exact new-head/latest-attempt complete allfive jobs/every required step;
  fix real diagnostics retaining assertions. Pending-only handoff/no duplicate
  source/long polling. After green add one captured-session conversation operation
  coordinator/global serialization/receipt identity before SDK transport/UI.
  Keep41 draft/issues open/AI defaults off/all14 hosted pending; hosted Auth/
  provider/voice/learner/physical launch and human gates remain. No merge/close/
  deploy/release/provider/Auth strategy/collection/spend/security/schedule action
  or Personal Alpha claim.


## Captured owner conversation mutation lane — #17, 2026-10-24 UTC

- Sole marker core-20261024T0909-conversation-lane; resume draft41 branch
  automation/issue-11-plan-sdk-integration at15f0eb14d6ebd020853a8a314fe6ef868d3daf25
  /treee58bef36fbd31dd6ad1d47c7eb65dd98f8c69488. Main78a44fa/source37afa572a/
  Pro14/38 unchanged; prior marker released08:17:47 UTC.
- Parent CI40077403342 raw exact15f0eb1/latest attempt1 completed success:
  allfive jobs/every required step/no skips. Log120824005867 confirms952 Flutter/
  all13 captured mutation cases and five Chrome; native/Windows/SQL/Edge/builds
  passed. Component evidence, not hosted identity/provider/learner acceptance.
- New ConversationMutationLane captures one ready-owner identity and serializes
  typed start/turn/finish using actual CapturedConversationMutation and strict
  DTOs. Reserve before supplied getters/factory/port reentry. Bounded immutable
  operation+lowercase-event-ID registry binds exact wire fingerprint; identical
  reconstructed requests reuse mutation/cache, changed text/scenario/level/session/
  UUID wire spelling rejects SYNC_CONFLICT/no dispatch. Distinct operations keep
  separate event scope. No generated IDs or automatic dispatch/retry.
- Failure/timeout retains unresolved original key even after injected-future
  drain. Different operation/fresh event/older cached replay cannot bypass it;
  explicit same-event same-wire retry resolves only on accepted typed success.
  isBusy differs from hasUnresolvedMutation. Default100 slots/trusted1..1000 bound;
  full registry rejects new events/nonretryable local RATE_LIMITED without eviction,
  existing replay remains valid. Permanent readiness/getter/identity/unauthorized
  revoke clears registry/publication, retains observable late held drain; A-B-A
  cannot revive. Borrowed resources untouched; host must reuse one lane and revoke
  every lifecycle barrier. Separate lanes/devices/processes not coordinated.
- 13/13 pure injected-port tests passed: typed serial/cache operations; held start/
  other operation; changed replay fields/UUID case; operation-scoped IDs; timeout
  late success/error and reservation after drain; provider failure/old-cache bypass;
  capacity/no eviction; port/getter reentry; revoked A-B-A late success/error;
  getter/unauthorized invalidation; same-user/explicit revoke/limits. Fresh official
  Dart3.9.2 checksum verified; exact nine-file production/test graph and unchanged
  fixture in disposable harness, only Flutter runner import adapted to test1.26.2.
  Strict casts/inference/raw types+lints6 analyze no issues. Pure evidence is not
  SDK/HTTP/server receipt/remote drain proof.
- Pinned format/inventory90/46 QA regressions/whitespace passed; separate exact
  wire/scope/uncertainty/cache/reentry/drain/lifecycle/capacity/diff review. All89
  old QA cases/findings/gates retained/all14 hosted pending. No old source/test,
  default flag/Auth strategy/provider/SDK/vault/RLS/contract/CI/dependency/Pro/content
  edits, new local full Flutter/analyzer/build or denied bootstrap retry/bypass.
- Five paths: new lib/features/ai/data/conversation_mutation_lane.dart,
  test/features/ai/conversation_mutation_lane_test.dart and
  docs/CONVERSATION_MUTATION_LANE.md; docs/PROJECT_STATUS.md and qa/matrix.json.
  Publish actual parent base_tree/full recursive tree/local equality/unaffected
  mode-type-blob proof, five exact UTF8/blobSHA/single parent/tree readbacks then
  fresh own marker/head expected-head non-force update. Final commit/tree/new
  exact workflow/latest attempt/released handoff in41/17/37.
- Next exact new-head/latest-attempt allfive jobs/every required step; fix real
  diagnostics retaining assertions. Pending-only handoff/no duplicate code/long
  polling. Then actual conversation progression/message correlation and owned
  fixed-endpoint SDK/HTTP/recovery/UI. Lane is not server ownership/receipt quota,
  cross-device/restart persistence, real I/O drain/rollback or voice proof. Keep41
  draft/issues open/AI defaults off/all14 hosted pending; hosted identity/provider/
  voice/learner/physical launch/human gates remain. No merge/close/deploy/release/
  Auth strategy/provider/collection/spend/security/schedule action or Alpha claim.


## Captured conversation session progression — #17, 2026-10-24 UTC

- Sole marker core-20261024T1017-conversation-flow; resume draft41 branch
  automation/issue-11-plan-sdk-integration atc222d53d910922683af2f561bd0ee79c9a36f21d
  /tree9b565faf4df6c6af6018fddcd09bc44f8e342a85. Main78a44fa/source37afa572a/
  Pro14/38 unchanged; prior core marker released09:18:12 UTC.
- Parent CI40081353423 raw exactc222d53/latest attempt1 completed success:
  complete allfive jobs/every required step/no skips. Log120835724184 confirms
  965 Flutter/all13 lane cases/five Chrome; full analyzer/Web/Windows/native/SQL/
  Edge/build steps passed. Component evidence, not hosted learner/provider proof.
- New CapturedConversationSession owns a private actual ConversationMutationLane
  for one captured ready-owner conversation. Explicit start captures server ID;
  typed turn/finish require active matching UUID identity; no pre-start/foreign
  session/second start or post-finish turn/start dispatch. Identical finish replay
  remains valid; operation-scoped same UUIDs retained. Supplied exact wire/text/
  whitespace/case unchanged. No ID generator/reset/automatic retry/activation.
- Immutable notStarted/active/finished/revoked snapshot retains assistant messages
  and optional typed summary. New turn requires strictly increasing sequence and
  previously unseen case-insensitive message UUID. Gaps accepted, no invented
  consecutive/+2 protocol. Accepted replay does not append twice or roll back
  later progress. Bad correlation permanently revokes/clears projection because
  underlying accepted receipt cannot be repaired by a new event. Turn has no
  response session ID; captured request/port association is not server ownership
  or scenario/context/receipt proof. No model-driven SRS/mastery/progress write.
- Failure/timeout preserves projection and unresolved original key after injected
  drain; only explicit identical retry advances on success. New event/older cache/
  finish cannot bypass uncertainty. Reserve before getter/port reentry; nested
  readiness read is redacted, nested send pending. Snapshot/dispatch/publication/
  replay check current identity/readiness; getter loss/401/same-user replacement
  or explicit lifecycle revoke permanently clears keys/messages/summary. A-B-A
  and late success/error cannot revive; held busy drains without closing borrowed
  SDK/HTTP/Auth. Previously returned snapshots cannot be erased from callers;
  host must invalidate views and synchronously revoke every lifecycle barrier.
  Private lane bounds retained messages/events without eviction; distinct flow
  instances/processes/devices are not coordinated; do not recreate to bypass work.
- 20/20 pure injected-port cases passed: explicit progression/exact wire, wrong
  lifecycle/session, replay without rollback/changed wire/scoped IDs, three invalid
  sequence/message cases, allthree operations with late success/error and exact
  manual retry, provider/malformed failures, port/readiness reentry, A-B-A late
  drain, readiness/getter/same-user/401 summary cleanup and capacity. Fresh official
  Dart3.9.2 checksum matched; exact ten-file production/test graph and unchanged
  fixture in disposable harness, only Flutter runner import adapted to test1.26.2.
  Strict casts/inference/raw types+lints6 analyzer no issues; new test-only braces
  lint fixed retaining assertions. No full local Flutter/SDK/HTTP/native/build
  execution or prior denied Flutter bootstrap retry/bypass.
- Pinned two-file format/zero changes, inventory91/46 QA regressions/whitespace
  passed; all90 old cases/gates/findings exact/all14 hosted pending. Separate
  progression/schema/UUID/sequence/cache/reentry/uncertainty/drain/lifecycle/diff
  review completed. No old source/test/Auth strategy/provider/default/SDK/vault/
  RLS/contract/CI/dependency/Pro/content edits.
- Five paths: new lib/features/ai/data/captured_conversation_session.dart,
  test/features/ai/captured_conversation_session_test.dart and
  docs/CAPTURED_CONVERSATION_SESSION.md; PROJECT_STATUS.md and qa/matrix.json.
  Publish actual parent base_tree/full recursive tree/local equality/unaffected
  mode-type-blob proof, five exact UTF8/blobSHA/single parent/tree readbacks then
  fresh own marker/head expected-head non-force update. Final commit/tree/new
  exact workflow/latest attempt/released handoff in41/17/37.
- Next inspect new exact-head/latest-attempt allfive jobs/every required step;
  fix actual diagnostics retaining assertions. Pending-only handoff/no duplicate
  source/long polling. Then owned fixed-endpoint SDK/HTTP conversation transport,
  actual lifecycle/late HTTP drain/recovery and UI. No durable transcript/receipt,
  hosted identity/provider/voice/learner/physical launch proof. Keep41 draft/issues
  open/AI defaults off/all14 hosted pending; human gates remain. No merge/close/
  deploy/release/Auth strategy/provider/collection/spend/security/schedule action
  or Personal Alpha claim.


## Captured SDK conversation HTTP port — #17, 2026-10-24 UTC

- Marker core-20261024T1110-conversation-http; branch
  automation/issue-11-plan-sdk-integration, parent3ad29d3d727a947d657a1e71360587f3e3306dda
  /tree2ae15ef4cb48210e79da3aa6757ba8441c704249. Main78a44fa/source37afa572a/
  Pro14/38 unchanged. Prior worker released10:28:49 UTC.
- Parent CI40085997614 raw exact3ad29d3/latest attempt1 completed success:
  complete allfive jobs/every required step/no skips. Log120849285801 confirms
  985 Flutter and five Chrome tests; full analyzer/Web/Windows/native/SQL/Edge
  builds passed. Component evidence only; not hosted learner/identity proof.
- SupabaseAiTextTransport also implements closed ConversationMutationTransport:
  only start_conversation/conversation_turn/finish_conversation, fixed trusted
  endpoint/public key and exact captured SDK bearer/ReviewSession/ready generation.
  Strict request/response DTOs preserve exact scalar event/session/text wire.
  Arbitrary URL/path, text operation and malformed/owner fields reject before HTTP.
  Text and conversation share the same actual HTTP singleflight/drain engine,
  unchanged byte/read/depth/UTF8/duplicate-key/media/redirect/timeout/401 guards.
  No wider Auth/REST privileges, credential writer, global retarget or auto retry.
- Ten new actual-SDK/HTTP cases plus all28 original unchanged cases passed (38/38):
  fixed endpoints/bearer/exact wire; allowlist/body/session rejection; allthree
  wrong-shape/duplicate JSON responses; shared text/conversation busy both ways;
  actual captured session progression/local cache replay without HTTP redispatch;
  timeout ignored-abort/exact-event retry after actual drain; 401 and same-user
  SDK replacement fencing. Original full test/helper prefix retained exactly
  except two added imports. TEST ONLY Auth/unsigned JWT/streamed HTTP, not hosted.
- Fresh official Dart3.9.2 checksum matched; disposable complete14-file actual
  production/test import graph+unchanged fixture, only Flutter runner import
  adapted to test1.26.2. Supabase2.16.5/http1.6.0/logging1.3.0 and all8 SDK/HTTP
  core package lock records exact. Changed transport/test strict analyzer clean.
  Whole graph with newer lints6 reports one pre-existing unnecessary_underscores
  info in unchanged supabase_review_binding.dart:47; no broad clean claim or
  unrelated edit/suppression. No local full Flutter/platform/build execution or
  retry/bypass of prior denied Flutter bootstrap. Pinned two-file format clean.
- Inventory92/46 QA regressions/whitespace passed; all91 previous cases/gates/
  findings exact/all14 hosted pending. Separate fixed-path/schema/dispatch/
  credential/decoder/shared lease/cleanup/late response/diff review completed.
- Five paths: existing supabase_ai_text_transport.dart and its test extended;
  new docs/CONVERSATION_SDK_HTTP.md; PROJECT_STATUS.md/qa matrix. Correct actual
  parent base_tree/full tree/local equality and unaffected path/type/mode/blob
  proof plus allfive UTF8/blobSHA/single parent/tree readbacks required before
  fresh own marker/head expected-head non-force update. Commit/tree/new exact
  workflow/latest attempt/released checkpoint will be recorded in41/17/37.
- Next observe new exact-head/latest-attempt complete allfive jobs/every required
  step; pending-only handoff/no duplicate implementation. Then runtime-owned
  conversation capability factory/startup/refresh/logout/late-I/O drain tests,
  recovery/reconciliation and UI. Default runtime still exposes text only; no
  conversation/provider activation. Port alone owns no receipts/progression;
  retain captured session/lane/event and do not rebuild to bypass uncertainty.
  No durable restart/transcript/server JWT/provider/voice/learner proof. Keep41
  draft/issues open/AI off/all14 hosted pending/human gates intact. No merge/
  close/deploy/release/Auth strategy/provider/collection/spend/security/schedule
  action or Personal Alpha claim.


## Retained conversation runtime owner — #17, 2026-10-24 UTC

- Marker core-20261024T1213-conversation-owner; resume draft41 branch
  automation/issue-11-plan-sdk-integration, parentdec021c002e915be75b63f5377b99b359c7f5793
  /treec1f54c1e815c5abc77a3d31c0d245da20772c092. Main78a44fa/source37afa572a/
  Pro14/38 unchanged; previous marker released11:16:57 UTC.
- Parent CI40089202113 raw exactdec021c/latest attempt1 completed success:
  complete allfive jobs/every required step/no skips. Log120858622078 confirms995
  Flutter/five Chrome; analyzer/Web/Windows/native/SQL/Edge/builds passed. Component
  evidence, not hosted identity/provider/learner acceptance.
- AiTextRuntimeOwner retains one CapturedConversationSession per existing lease
  and exact shared owned transport. Factory reuses guarded text acquisition and
  then reserves construction before supplied getters can reenter; unsupported
  text-only transport returns unavailable. Identical factory calls return same
  finished/unresolved session, not fresh event/progression/HTTP capability.
- Invalidate revokes conversation synchronously before repository/transport and
  existing actual close/drain; retired generations cannot revive and a new one
  waits for old I/O. check includes conversation availability; failed cleanup
  blocks replacement. Existing reentrant close waits for construction/orphans.
  No second SDK/network engine/credential writer or raw failure disclosure.
- PersistentSupabaseRuntime adds separate aiConversationEnabled=false flag and
  createAiConversationSession gated by persisted rotation/own-profile and exact
  runtime/session/generation. Uses same AI owner as text; existing refresh revokes
  before persistence barrier, logout/readiness invalidates, close drains before
  SDK disposal. No default/staging flag or source-interface/UI/provider activation.
  One retained session per ready generation has no automatic reset/new-round;
  refresh is not permission to bypass uncertain old events. Server reconciliation,
  durable restart/transcript and explicit new-round policy remain open.
- 25/25 pure owner cases passed:19 original unchanged plus6 new retained finished
  session/shared transport, synchronous revoke/generation drain, same-user loss,
  readiness reentry/reentrant close, failed cleanup and unresolved factory/event
  retention. Fresh official Dart3.9.2 checksum matched; complete12-file actual
  production/test graph+unchanged fixture, only Flutter runner import adapted to
  test1.26.2; strict casts/inference/raw types+lints6 analyze no issues. Initial
  new interface intersection compile error fixed with checked port cast and new
  guard braces; no weakening/suppression. No full local Flutter/platform/build
  execution or retry/bypass of prior denied Flutter bootstrap.
- Four new actual runtime cases AUTHORED, NOT run locally: separately disabled
  conversation while text enabled; vault-write/profile barriers and retained
  conversation-only opt-in; refresh/rotated bearer/ignored-abort drain/replacement/
  logout; owned close with held HTTP/preserved vault/borrowed clients. All8 old
  runtime test bodies/assertions unchanged except optional build helper default
  remains false/two imports. Actual SDK/vault/HTTP here remain TEST ONLY fixtures;
  exact new-head CI must confirm these four cases and full analyzer/builds.
- Pinned four-file format clean/inventory93/46 QA regressions/whitespace passed;
  all92 previous cases/gates/findings exact/all14 hosted pending. Separate lease/
  flags/factory/reentry/epoch/orphan/uncertainty/cleanup/lifecycle/diff review done.
- Seven paths: existing ai/application/ai_text_runtime_owner.dart,
  auth/application/persistent_supabase_runtime.dart and persistent_ai_text_runtime_test.dart;
  new ai_conversation_runtime_owner_test.dart and docs/CONVERSATION_RUNTIME_OWNER.md;
  PROJECT_STATUS.md/qa matrix. Publish with actual parent base_tree/full recursive
  tree/local equality/unaffected mode-type-blob proof; seven exact UTF8/blobSHA/
  single parent/tree readbacks and fresh own marker/head expected-head non-force
  update. Final commit/tree/new CI/latest attempt/released handoff in41/17/37.
- Next inspect exact new-head/latest-attempt complete allfive jobs/every step,
  including allfour new actual runtime cases. Fix real diagnostics, keep assertions;
  pending-only handoff/no duplicate code/long polling. Then startup/source/UI
  conversation flow and explicit recovery/reconciliation/new-round policy. Keep41
  draft/issues open/AI flags off/all14 hosted pending/human gates intact. No hosted
  JWT/provider/receipt/voice/learner/physical launch proof; no merge/close/deploy/
  release/Auth strategy/provider/collection/spend/security/schedule/Alpha claim.


## Conversation runtime fixture lint correction — #17, 2026-10-24 UTC

- Marker core-20261024T1309-runtime-lint; draft41 branch
  automation/issue-11-plan-sdk-integration, parent0d00728b0136b20225a15a9147f81a3b73778a38
  /treef31108e82a743cfa6aa6dfc2510c98031236cd70. Main78a44fa/source37afa572a/
  Pro14/38 unchanged; previous marker released12:20:58 UTC.
- Exact parent CI40093496842/latest attempt1 completed failure. Full five-job
  snapshot observed: repo-sanity/AI/database/Windows completed success with every
  step passing. Flutter format succeeded, then analyzer failed exactly two
  curly_braces_in_flow_control_structures diagnostics in new runtime fixture
  cleanup at lines513/566 (log120871209718). Flutter tests, later native/browser/
  wire checks and Web build/upload skipped; no passing integration claim.
- Added blocks around those two existing if(!held.isCompleted) cleanup statements.
  No assertion, timeout, helper behavior, test case or production source changed.
  Separate exact-diff reconstruction proves all other bytes retained. All8 old
  runtime tests and four new conversation cases remain, with their assertions;
  no lint ignore/check weakening/new empty tests. Full QA matrix unchanged,
  inventory93/46 QA regressions/whitespace passed; all14 hosted groups pending.
- Fresh official Dart3.9.2 checksum verified; target format zero changes. No full
  local Flutter/analyzer/integration/platform/build run or retry/bypass of prior
  denied Flutter bootstrap. Parent pure25-owner checks remain historical,
  not evidence that the four actual runtime cases executed. Corrected full
  Flutter/analyzer/runtime tests must be confirmed by new exact-head CI.
- Two paths only: apps/flutter_app/test/features/ai/persistent_ai_text_runtime_test.dart
  and docs/PROJECT_STATUS.md. Publish with actual parent base_tree/full recursive
  tree/local equality/unaffected mode-type-blob proof; two exact UTF8/blobSHA/
  single parent/tree readbacks before fresh own active marker/head expected-head
  non-force ref update. Commit/tree/new workflow/latest attempt/released handoff
  persisted in41/17/37. No Pro/content/Auth strategy/provider/default/dependency/
  production/RLS/contract/CI edit or merge/issue closure/deploy/release/schedule action.
- NEXT inspect exact new-head/latest-attempt allfive jobs/every required step and
  allfour new actual-runtime cases; fix real diagnostics retaining assertions.
  Pending-only handoff/no duplicate implementation/long polling. Then startup/
  source/UI conversation and explicit recovery/reconciliation/new-round policy.
  Keep41 draft/issues open/AI flags off/all14 hosted pending/human gates intact;
  TEST ONLY Auth/vault/HTTP and builds are not hosted provider/JWT/voice/learner/
  physical launch or Personal Alpha proof.


## Borrowed conversation source through owned startup — #17, 2026-10-24 UTC

- Marker core-20261024T1411-conversation-source; draft41 branch
  automation/issue-11-plan-sdk-integration, parentf0d43bf1b9e80de7efab85a7f81941a046d5c719
  /treeaf57c26640b8a1e932b9e86ac2eb83603707ba2e. Main78a44fa/source37afa572a/
  Pro14/38 unchanged; previous marker released13:11:19 UTC.
- Parent CI40097022865 raw exactf0d43bf/latest attempt1 completed success:
  complete allfive jobs/every required step/no skips observed. Flutter log
  120881644764 confirms1005 Flutter/five Chrome and allfour actual runtime cases:
  separate default-off flag, vault/profile barrier/conversation-only cache,
  refresh/rotated bearer/ignored-abort HTTP drain/replacement/logout, close with
  held HTTP/preserved vault/borrowed clients. Prior lint correction now verified;
  analyzer/Web/Windows/native/SQL/Edge builds passed. Component, not hosted proof.
- New AiConversationSource exposes borrowed captured-session factory and void
  availability hints only; construction/forwarding sends nothing. Runtime uses
  existing default-off factory and same AI owner stream; PersistentAccountStartup
  and WindowsStagingOwner forward exact same capability/stream, Windows factory
  unavailable once close starts. AccountStartupController publishes source only
  while active/not closed; active source may still return null before Auth/vault/
  profile readiness or when disabled. Captured generation/drain guard unchanged.
- No App provider override, Riverpod conversation binding/controller/view/route,
  learner endpoint/key, provider/default/staging activation or automatic dispatch.
  Source is borrowed: consumers recheck authority/captured identity, never reset
  uncertainty or close owner resources. No wider Auth/REST privileges, credential
  writer, separate SDK/HTTP, resource-lifetime or model-driven writes.
- Two actual-owned-startup tests AUTHORED, NOT run locally: TEST ONLY conversation
  opt-in through real SDK/native journal/Windows wrapper/startup controller checks
  idle unavailable/active-unready null, same stream/session identity across all
  layers/no factory HTTP, explicit start, refresh/rotated secret/fresh generation/
  hints/logout/closed-source fences. Default-off ready Windows source returns null
  with original text factory available/no HTTP. Existing9 mounted journeys and
  assertions are exact; only fixture helper accepts optional conversationEnabled
  false. Reuse actual real-loop finally cleanup/target-release assertion; no new
  conversation UI mounted and no synthetic saved rows.
- Fresh official Dart3.9.2 SHA matched; six edited/new Dart files format zero
  changes. Inventory94/46 QA regressions/whitespace passed; all93 prior QA cases/
  gates/findings exact/all14 hosted pending. Separate source/owner/phase/factory/
  stream identity/refresh/close/default/fixture/diff review done. No new full local
  Flutter/analyzer/platform/build execution or prior denied bootstrap retry/bypass;
  new exact-head CI must confirm two startup cases/full checks.
- Nine paths: new ai/data/ai_conversation_source.dart; existing runtime,
  PersistentAccountStartup, AccountStartupController, staging_bootstrap.dart;
  extended ai_owned_startup_journey_test.dart; new docs/CONVERSATION_STARTUP_SOURCE.md;
  PROJECT_STATUS/qa matrix. Publish actual parent base_tree/full recursive tree/
  local equality/unaffected path-type-mode-blob proof, nine exact UTF8/blobSHA/
  single parent/tree readbacks before fresh own marker/head expected-head non-force
  ref update. Final commit/tree/new CI/latest attempt/released handoff in41/17/37.
- Next inspect exact-head/latest-attempt complete allfive jobs/every required step
  and both new owned-startup source cases; fix actual diagnostics retaining all
  assertions. Pending-only handoff/no duplicate implementation/long polling.
  Then conversation controller/guarded App-source binding/UI and explicit same-event
  recovery/reconciliation/new-round policy. Keep41 draft/issues open/AI flags off/
  all14 hosted pending/human gates. TEST ONLY Auth/vault/HTTP/native/builds are not
  hosted JWT/provider/receipt/voice/learner/physical launch or Alpha proof. No
  merge/close/deploy/release/Auth strategy/provider/collection/spend/security/
  schedule action.


## Deterministic timestamp range validation — CI blocker, 2026-10-24 UTC

- Marker core-20261024T1512-timestamp-guard; coordinator shared-file scope on
  draft41/automation/issue-11-plan-sdk-integration, parent47dbb080321bf49712284fdabaf913b43ebcd85c
  /tree43ad736ebc3c5809f3c1e3a416350df3fc861bcf. Main78a44fa/source37afa572a/
  Pro14/38 unchanged; previous marker released14:16:19 UTC.
- Parent CI40101695804 raw exact47dbb08/latest attempt1 completed failure.
  Complete five-job snapshot: AI/database all steps success; repo-sanity failed
  existing test_review_queue invalid-clock case2026-10-14T24:00:00Z because
  ContractError was not raised (log120895006244,58 tests/one failure). QA step,
  Windows and Flutter skipped, not passed; two source-startup cases unexecuted.
  Runner Python version/normalization cause is not established by that log.
- Existing common validator delegated all clock/offset bounds to fromisoformat
  after an unconstrained digit regex. Add explicit ASCII hour00..23/minute00..59/
  second00..59 and offset hour00..23/minute00..59 before that parser. datetime
  still validates actual calendar/zone presence; documented uppercase T/Z,
  fractional seconds and valid explicit offsets retained. No frozen schema/wire
  definition, runtime behavior, endpoint, Auth strategy/provider or dependency
  change; no tolerance for24:00/leap-second/offset rollover/Unicode clock digits.
- Added two meaningful regressions without removing old tests: mocked lenient
  host parser must never receive any of10 malformed clock/offset/case/Unicode
  inputs; actual valid leap date/time/offset/zero-offset boundaries accepted and
  invalid calendar dates rejected. New lenient-parser regression FAILED against
  unchanged validator (nine malformed inputs reached parser), then passed after
  guard. Existing queue24:00 test and all prior58 contract tests exact.
- Fresh disposable Python3.12.14 environment installed actual committed
  jsonschema4.23.0 requirement. Frozen baseline20 fixtures/60 full contract tests
  and46 QA regressions passed; inventory94/entire unchanged QA matrix/all14 hosted
  pending, py_compile/whitespace/separate diff review passed. No Pro content tests
  or curriculum/manifests changed. Local checks are Python validation only, not
  new Flutter/Windows/analyzer/startup/hosted evidence; no denied SDK bootstrap
  retry/bypass and no CI runtime pin/downgrade/check suppression.
- Three paths only: contracts/validate.py, contracts/test_contracts.py and
  docs/PROJECT_STATUS.md. Publish actual parent base_tree/full recursive tree/
  local equality/unaffected path-mode-type-blob proof plus three exact UTF8/blobSHA/
  single parent/tree readbacks before fresh own marker/head expected-head non-force
  ref update. Final commit/tree/new exact-head CI/latest attempt/released handoff
  persisted in41/17/37. No new independent conversation code while CI is blocked.
- NEXT exact-head/latest-attempt complete allfive jobs/every required step,
  existing invalid queue24:00 assertion/new regressions and both pending source
  startup cases; fix actual diagnostics retaining assertions. Pending-only handoff/
  no duplicate implementation/long polling. Then conversation controller/App source
  binding/UI/explicit same-event recovery/reconciliation/new-round policy. Keep41
  draft/issues open/AI flags off/all14 hosted pending/human gates. No merge/close/
  deploy/release/Auth strategy/provider/collection/spend/security/schedule action
  or Personal Alpha claim; fixtures/builds are not hosted JWT/provider/voice/
  learner/physical launch proof.


## Source-startup journey real-loop correction — #17, 2026-10-24 UTC

- Marker core-20261024T1612-source-real-loop; draft41 branch
  automation/issue-11-plan-sdk-integration, parent3b92997a0dce4cafc9199761b8e0a78b259e13c4
  /treefcfe0ecb93610cc63cc0ed5c988f0179a1e323a0. Main78a44fa/source37afa572a/
  Pro14/38 unchanged; previous marker released15:17:27 UTC.
- Parent CI40106242750 raw exact3b92997/latest attempt1 completed failure.
  Complete five-job snapshot: repo-sanity/AI/database/Windows all jobs/every step
  success. Timestamp validator fix/new regressions now verified. Flutter format/
  analyze passed,1005 tests passed/two new source startup cases failed: first
  ten-minute timeout, second guarded-function conflict after prior test remained
  outstanding (log120908766843). Later native/browser/wire checks and Web build/
  upload skipped, not passed. No passing new source-case/full Flutter claim.
- The new nonvisual journeys mixed FakeAsync capability/listener construction
  and cancellation with multiple real-loop runAsync I/O calls. Keep those two
  source journeys in one real-loop body each, including source factory, listen,
  async start/refresh/logout/close, cancellation and assertions. Existing fixture
  construction already runs on real loop; no nested runAsync in journey bodies.
  This addresses the cross-zone risk shown by the timeout; exact stalled await
  was not identified by the remote timeout trace and success still requires CI.
- New private _sourceJourney helper bounds entire real-loop body to15s instead
  of waiting the default10min, no test/production timeout increase. Existing
  _ownedTest real-loop finally cleanup and exclusive-vault target-release assert
  remain unchanged. No production source, ownership semantics, feature flag,
  provider/Auth strategy, endpoint, contract or resource policy changed.
- Separate diff proof: all9 original main journey cases exact; both new source
  cases have identical expect expressions/order; no case/assertion removed,
  weakened or skipped. No new empty tests, no CI/check changes. Entire QA matrix
  exact/inventory94/46 QA regressions/whitespace passed/all14 hosted pending.
- Fresh official Dart3.9.2 checksum matched; target format zero changes. No full
  local Flutter/analyzer/journey/platform/build execution or denied Flutter
  bootstrap retry/bypass. These checks validate source/diff only; new CI must
  confirm both actual owned SDK/native journal/source cases plus all full gates.
- Two paths only: apps/flutter_app/test/features/ai/ai_owned_startup_journey_test.dart
  and docs/PROJECT_STATUS.md. Publish actual parent base_tree/full recursive tree/
  local equality/unaffected mode-type-blob proof; two exact UTF8/blobSHA/single
  parent/tree readbacks before fresh own active marker/head expected-head non-force
  ref update. Final commit/tree/new workflow/latest attempt/released handoff in
 41/17/37. No Pro/content/manifest/dependency/production/QA matrix edit.
- Next exact-head/latest-attempt allfive jobs/every required step and both source
  startup cases. Fix real diagnostics retaining all assertions; pending-only
  handoff/no duplicate code/long polling. Then conversation controller/App binding/
  UI/explicit same-event recovery/reconciliation/new-round policy. Keep41 draft/
  issues open/AI flags off/all14 hosted pending/human gates intact. No merge/close/
  deploy/release/Auth strategy/provider/collection/spend/security/schedule action
  or Alpha claim; TEST ONLY fixtures/builds are not hosted JWT/provider/voice/
  learner/physical launch proof.


## Core implementation checkpoint — 2026-10-24 17:25 UTC / conversation controller

- Sole marker core-20261024T1718-conversation-controller; branch automation/issue-11-plan-sdk-integration, expected parent5313b1e318c1620248c931aa2156f703d4be43f5/draft41; main78a44fa/source37afa572a/Pro14/38 at28c20cb unchanged. #17 independent prerequisite; full hosted acceptance remains blocked, not restarted Auth/vault foundations.
- Verified parent CI40110675068 raw exact5313b1e/latest attempt1 completed success: complete allfive jobs/every required step/no skips. Flutter job120921973070 log verifies1007 Flutter/two new actual owned startup source cases/five Chrome; Web/Windows/native/SQL/Edge checks passed. TEST ONLY component proof, not hosted JWT/provider/voice/learner acceptance.
- Added borrowed AiConversationController: explicit N5/N4 start/captured-session turn/finish, safe immutable phase/projection, reserve before getter/port reentry, retain exact original DTO/event/wire for explicit retry only after drain and safe retryable/local-pending result. Unresolved flow blocks edited/new events/all other operations; nonretryable failures remain blocked pending later reconciliation. No optimistic result/save/progress/SRS write, generated IDs, timer/poll/automatic replay/reset/new-round/provider activation.
- Read/dispatch/completion guard readiness/identity; same-user replacement/A-B-A/401/hint error/closure/invalidate/dispose permanently redact view, late results fenced. Disposal closes only own subscription/void hints, not borrowed flow/SDK/port; remount preserves finished/uncertain lane and cannot reconstruct lost DTO or bypass unresolved event. Captured flow adds only read-only isCheckingAvailability hint to redact/refuse nested getter reentry without falsely revoking healthy controller. Existing flow operation semantics and prior assertions unchanged.
- Fresh SHA-verified Dart3.9.2; identical recursive12-file graph/original frozen fixture, sole Flutter->test1.26.2 import adaptation:21 new controller +20 unchanged flow tests passed/strict casts-inference-raw+lints6 analyzer clean. Initial new reentry regression failed before guard fix; retained/strengthened expectations, no old test/assertion removal. Format/QA inventory95/46 QA regressions/whitespace/separate diff review required and recorded in final PR handoff. Full local Flutter/SDK/native/build not run; no denied bootstrap retry/bypass. Formatter unavailable Flutter lint include warning is not analysis proof.
- Six intended paths: new application/ai_conversation_controller.dart, test/features/ai/ai_conversation_controller_test.dart, docs/AI_CONVERSATION_CONTROLLER.md; additive captured_conversation_session.dart read hint, PROJECT_STATUS.md, qa/matrix.json. All94 old QA cases/findings/gates retained/all14 hosted pending. No original app/controller/test/default/Auth/provider/credential writer/contract/schema/RLS/dependency/CI/content/Pro changes.
- Next observe published exact head/latest-attempt complete allfive jobs/every step/new controller cases; pending-only handoff/no duplicate code/long polling. Then guarded App/source/Riverpod binding and mounted conversation UI plus explicit trusted receipt reconciliation/durable recovery/new-round policy. Keep41 draft/17 open/default AI flags off; no merge/close/deploy/release/security/spend/schedule action/Alpha claim. Concrete commit/tree/CI/current release marker in PR41/17/37, with complete-tree preservation/readbacks/expected-head non-force publication before release.


## Conversation binding increment — core-20261024T1810-conversation-binding

Parent cb36c3f25a02ecda3de92e7eee7462046863fbee on draft41/automation/issue-11-plan-sdk-integration. Main78a44fa/source37afa572a/Pro14/38 unchanged. CI40116186234 exact parent/latest attempt1 allfive jobs/every step success/no skips; log120938276389 confirms1028 Flutter/five Chrome/new21 controller cases. Full17 hosted acceptance still blocked, not restart of Auth/vault foundations.

New default-null Riverpod source/view binding watches account readiness and source hints, captures retained current conversation flow, preserves binding identity on same flow, clears revoked/unavailable, guards notification reentry and source/stream errors. Explicit AccountStartupApp override uses active-only controller source; flags/main/staging remain off. Own subscription cancellation only/borrowed resources unchanged; no HTTP/event IDs/reset/new-round/provider activation. Ten focused TEST ONLY source/notifier/Riverpod cases authored, not locally executed (Flutter absent). Full mounted conversation App route proof remains missing. Fresh Dart3.9.2 SHA verified/format check; QA inventory96/46 regressions/whitespace/separate diff review recorded in final PR checkpoint. All95 old QA cases/findings/gates retained/all14 hosted pending.

Six paths: new ai_conversation_view_binding.dart, ai_conversation_source_test.dart, AI_CONVERSATION_VIEW_BINDING.md; AccountStartupApp override/import, PROJECT_STATUS, QA matrix. No existing test/text binding/runtime/SDK/credential/Auth strategy/contract/schema/CI/dependency/Pro/content changes. Next exact published-head/latest-attempt complete allfive jobs/every required step/new10 cases, fix actual diagnostics; pending-only handoff/no duplicate code. Then guarded mounted conversation UI, actual App startup coverage and explicit trusted recovery/reconciliation/new-round policy. Keep41 draft/17 open/AI flags off/human gates; no merge/deploy/release/security/spend/schedule action/Alpha claim. Exact commit/tree/readbacks/CAS/current CI/released marker are durable in PR41/17/37.


## Binding reentry fixture correction — core-20261024T1915-binding-reentry-fixture

Expected parent e96331055d1c041ed223ecff439a2e94f5f77b53, draft41/automation/issue-11-plan-sdk-integration. Main78a44fa/source37afa572a/Pro14/38 unchanged. Parent CI40119543273 raw exact e963310/latest attempt1 completed failure: repo-sanity/AI/database/Windows every step pass; Flutter format/analyze pass/1037 tests pass/one new source reentry case failed (expected same binding, actual null), log120948345269. Downstream native/browser/wire/Web build steps skipped, not pass. Nine other binding cases passed, full10 still require new CI.

Failed fixture called synchronous broadcast add from inside delivery of its own event; Dart prohibits reentrant add, so source acquisition threw and the production safe catch correctly cleared binding. Corrected only that test setup: emit hint during constructor acquisition after subscription is installed but before any event delivery is active. This exercises notifier reentry guard legitimately. Preserve original same-binding/no-dispatch/disposal assertions; add nonnull binding, exactlyone initial acquisition and exactlytwo after later ordinary hint. No assertion/test removal, async deferral, timeout increase, exception suppression or production change. Standalone actual Dart stream probe and pinned formatter/QA checks recorded in PR checkpoint; full Flutter test/analyzer/platform new-head CI remains required. No Flutter bootstrap retry/bypass.

Only source test and PROJECT_STATUS changed; QA matrix96/all14 hosted pending exact. Next exact published-head/latest-attempt allfive jobs/every required step/new10 source cases; pending-only handoff/no duplicate UI work, then mounted conversation UI/actual startup binding coverage/trusted recovery-reconciliation-new-round policy. Keep41 draft/17 open/default AI flags off/human gates; no merge/deploy/release/Auth strategy/provider/collection/spend/security/schedule action/Alpha claim. Durable commit/tree/readbacks/CAS/released marker in PR41/17/37.


## Mounted conversation host coverage — core-20261024T2014-conversation-host

Expected parent de693d9a67f787d9bd7283895395e64c37dabeea/draft41/automation/issue-11-plan-sdk-integration. Main78a44fa/source37afa572a/Pro14/38 unchanged. Parent CI40124687806 raw exactde693d9/latest attempt1 completed success: allfive jobs/every required step/no skips; log120964001435 confirms1038 Flutter/all10 binding source cases including corrected reentry/five Chrome; Web/Windows/native/SQL/Edge passed. TEST ONLY component proof, not hosted acceptance.

Added2 actual mounted AccountStartupApp/default Riverpod/router-to-conversation cases over existing real SDK/native journal/Windows owner/startup. Enabled conversation-only startup holds refresh-token write before account exposure then own-profile readiness before binding; exact source/flow/stream identity/no automatic AI HTTP. Explicit real conversation controller start checks exact frozen request/path/captured bearer. Refresh synchronously redacts old flow/controller, held rotation/profile keep binding null, new ready generation empty/notStarted/no automatic replay; logout clears replacement. Default-off logged-in mounted host still has null conversation binding/factory and no HTTP while original text capability is available. Test ports/unsigned JWT are TEST ONLY; no hosted learner/receipt/provider/voice claim.

Existing11 journey bodies/helper/assertions and real-loop finally/exclusive vault target release retained; new provider subscriptions/controller/SDK operations created/read/closed in real-loop zones with case-local finally, UI pumps separate. Only2 imports/2cases; no production/default/runtime/SDK/Auth strategy/provider/schema/CI/dependency/Pro/content changes. New cases authored/unrun locally (Flutter absent); fresh Dart3.9.2 SHA/format, QA inventory97/46 regressions/old96 cases-findings-gates exact, whitespace/separate diff review recorded in PR. All14 hosted human gates pending/no denied bootstrap retry/bypass.

Four paths:extended ai_owned_startup_journey_test.dart,new CONVERSATION_MOUNTED_HOST.md,PROJECT_STATUS,qa/matrix.json. Next exact published head/latest-attempt allfive jobs/every step/new2cases; fix actual diagnostics/pending-only handoff/no duplicate code. Then guarded mounted conversation screen/trusted scenario source/explicit safe recovery-reconciliation-new-round. Keep41 draft/17 open/AI flags off; no merge/close/deploy/release/security/spend/schedule action/Alpha claim. Durable exact commit/tree/readbacks/CAS/released marker in PR41/17/37.


## Mounted profile barrier zone correction — core-20261024T2114-profile-barrier-zone

Expected parent9f46aa942dbe9277678d1f0cc744f3912d14ea66/draft41/automation/issue-11-plan-sdk-integration. Main78a44fa/source37afa572a/Pro14/38 unchanged. Parent CI40129083822 raw exact9f46aa9/latest attempt1 completed failure: four non-Flutter jobs/every step success; Flutter format/analyze passed/1039 tests passed/one new enabled mounted journey failed. Log120977100466 at981 shows second profile readiness after refresh stayed loadingProfile until original5s readiness deadline; follow-on exception check failed. Default-off mounted case and previous11 journey cases passed. Downstream native/browser/wire/Web steps skipped, not pass.

Only new enabled case changes: construct initial/refresh vault/profile Completers inside the same real-loop runAsync block that starts SDK startup/refresh, rather than in FakeAsync. Futures may schedule their completion through their creation zone; waiting for profile in real-loop while a completion is queued in the suspended fake zone risks deadlock. This addresses a concrete mixed-zone hazard; CI trace does not prove the exact stuck continuation/root cause, and new success still requires exact-head CI. No increased deadline, added wait loop, catch/skip/mock success, assertion/cleanup/default/production change. All expectations/order, previous11 cases, new default-off case and real-loop finally/exclusive vault target release remain exact. Standalone Dart zone probe/format/QA/separate diff recorded in PR checkpoint; no local full Flutter/analyzer/native/build or denied bootstrap retry/bypass.

Only ai_owned_startup_journey_test.dart and PROJECT_STATUS changed; entire QA matrix97/all14 hosted pending unchanged. Next new exact-head/latest-attempt allfive/every required step/both new mounted cases; fix actual diagnostics, pending-only handoff/no duplicate UI work. Then guarded screen/trusted scenario source/explicit recovery-reconciliation-new-round. Keep41 draft/17 open/AI flags off/human gates; no merge/deploy/release/Auth/provider/collection/spend/security/schedule action/Alpha claim. Durable source/tree/readbacks/CAS/released checkpoint in41/17/37.


## Guarded conversation session panel — core-20261024T2209-conversation-view

Expected parent72c62e1169deeb4ee140cba85abb56fdd2dacbb3/draft41/automation/issue-11-plan-sdk-integration. Main78a44fa/source37afa572a/Pro14/38 unchanged. CI40133533178 raw exactparent/latest attempt1 completed success/allfive jobs/every step/no skips; log120990516687 verifies1040 Flutter/five Chrome/both mounted conversation host cases. TEST ONLY components, not hosted JWT/provider/receipt/voice/learner acceptance.

New reusable read-only ConversationSessionPanel owns view controller/void-hint subscription only, fresh guarded reads every build, old view disposal on binding replacement/unmount, borrowed flow/receipt ownership retained. Literal assistant Japanese/Vietnamese, explicit absent translation/audio, ready notStarted/active/finished and unavailable/uncertain/busy/empty states; exact validated finish scores/corrections/strength/focus and SRS count/not-saved notices. No HTML/URL/audio loader, invented user transcript/live feedback/progress/mastery/write. Narrow/large-text scroll layout. Not wired into a route; no start/send/retry/finish/reset/new-round/event generator/scenario input/default activation. Trusted scenario source and recovery policy still needed before mutation UI.

Eight actual-flow/TEST ONLY Auth-port/frozen-fixture widget cases authored, NOT run locally (Flutter absent): unavailable/idle no dispatch, literal text/no translation/no audio fetch, empty summary/no-save, revoked/A-B-A hints clear, binding replacement/unmount preserve borrowed flows, safe explicit uncertainty/no autoretry,320px/200% scroll, numeric bounds/fraction/correction text. Fresh official Dart3.9.2 SHA/format/QA inventory98/46 regressions/whitespace/separate diff review recorded in final checkpoint; old97 cases/findings/gates exact/all14 hosted human gates pending. No new full local Flutter/analyzer/native/build or denied bootstrap retry/bypass.

Five paths:new presentation/conversation_session_panel.dart,test/features/ai/conversation_session_panel_test.dart,CONVERSATION_SESSION_PANEL.md; PROJECT_STATUS,qa/matrix.json. No existing app/router/default/SDK/Auth strategy/credential/provider/schema/RLS/dependency/CI/Pro/content edits. Next exact published head/latest-attempt allfive/every required step/new8 widget cases, fix diagnostics; pending-only handoff/no duplicate work. Then trusted scenario/read capability and safe explicit mutation UI/recovery-reconciliation-new-round with mounted host coverage. Keep41 draft/17 open/AI flags off; no merge/close/deploy/release/security/spend/schedule action/Alpha claim. Durable commit/tree/readbacks/CAS/current CI/released marker41/17/37.


## Conversation panel fixture lint correction — core-20261024T2306-panel-lint

Expected parent243c9c0e6346b2b85d50ebaf1ce7997751b7c5a2/draft41/automation/issue-11-plan-sdk-integration. Main78a44fa/source37afa572a/Pro14/38 unchanged. Parent CI40137630258 raw exact243c9c0/latest attempt1 completed failure:database/AI/repo-sanity/Windows every step success, Flutter format passed/analyzer failed solely curly_braces_in_flow_control_structures in conversation_session_panel_test.dart38 (log121002812930). Flutter tests/all8 widget cases/downstream native-browser-wire-Web build/upload skipped, not pass.

Added only brace block around fixture uncertain return; exact condition/error payload/control flow/all8 widget test bodies/assertions retained. No production panel/default/route/SDK/credential/Auth strategy/provider/contract/schema/CI/dependency/content/Pro change, no lint suppression/removed assertion/test/timeout increase. Fresh Dart3.9.2 SHA/target format/QA inventory98/46 regressions/whitespace/separate diff recorded in PR; whole QA matrix/all14 hosted pending exact. No new local Flutter/analyzer/widget/native/build or denied bootstrap retry/bypass.

Only conversation_session_panel_test.dart and PROJECT_STATUS changed. Next exact published head/latest-attempt allfive jobs/every required step/all8 widget cases, fix actual diagnostics; pending-only handoff/no duplicate feature work. Then trusted scenario/read source/safe explicit mutation UI/recovery-reconciliation-new-round with mounted host coverage. Keep41 draft/17 open/AI flags off/human gates; no merge/close/deploy/release/security/spend/schedule action/Alpha claim. Durable commit/tree/readbacks/CAS/current CI/released marker41/17/37.


## Conversation panel revocation frame correction — core-20261025T0013-panel-redaction

Expected parentadc2b97b86491f91cd9f1e7cc9d82a7dbeb4a6ba/draft41/automation/issue-11-plan-sdk-integration. Fresh main78a44faf/source37afa572a/Pro14/38 at28c20cb unchanged. CI40141452588 raw exactparent/latest attempt1 completed failure; complete allfive job metadata/every step read: DB/AI/repo-sanity/Windows all success, Flutter format/analyze success then1047 passed/one failed. Seven of eight new panel cases passed; same-user replacement/A-B-A revocation case failed at194 seeing prior text. Downstream Flutter native/browser/wire/Web build/upload skipped, not pass.

Only test scheduling changes: add explicit tester.idle before both original pumps after void hints. Pinned Flutter3.35.4 framework source reviewed: automated pump checks hasScheduledFrame before flushing microtasks; controller async notification may schedule the frame only during that flush, so the old render tree remains until another frame. Idle drains notification before the existing pump; no wall-clock wait/deadline extension or production change. This explains a concrete fixture timing hazard, not a verified corrected-widget pass. All8 original cases/helpers/pumps/assertions exact after removing only two insertions; QA matrix98/all14 hosted pending byte-identical. No lint suppression/catch/skip/fake success/session-guard weakening/SDK or default activation.

Fresh official Dart3.9.2 archive SHA256 ec22e81271582def81d3e10e2a555ae5d3d81c6951465a3d16cfc47938e9f92a verified; target format0changes (missing Flutter lint include warning is not analyzer evidence). Inventory98/46 QA regressions/whitespace/separate exact-insertion diff passed. Full local Flutter/analyzer/widget/native/build unrun; no denied bootstrap retry/bypass. Only conversation_session_panel_test.dart, CONVERSATION_SESSION_PANEL.md and this status change. Original app/flow/controller/route/Auth strategy/credential/provider/API/schema/RLS/dependencies/CI/curriculum/Pro bytes unchanged.

Next inspect new exact-head/latest-attempt allfive jobs/every required step/all8 panel cases and fix actual diagnostics; pending-only means durable handoff/no duplicate implementation or long polling. Then trusted scenario/read capability and safe explicit mutation UI/recovery-reconciliation-new-round with mounted host coverage. Keep41 draft/17 open/default AI flags off/all14 hosted human gates pending. TEST ONLY fixtures/native builds are not hosted JWT/provider/receipt/voice/learner acceptance. No merge/issue closure/deploy/release/security/spend/schedule action/Alpha claim. Durable commit/tree/readback/CAS/current CI/released marker in41/17/37.


## Captured public scenario read — core-20261025T0115-scenario-read

Expected parent4f5e7a959a378b606fb91fc0b3f634c1ab0a2acc/draft41/automation/issue-11-plan-sdk-integration. Fresh main78a44fa/source37afa572a/Pro14/38 at28c20cb unchanged. Exact parent CI40145863403/latest attempt1 completed success: complete allfive jobs/every required step/no skips verified. Flutter log121027210918 confirms1048 Flutter/five Chrome/all8 panel widgets, including corrected revocation. Prior test-frame correction verified; component evidence, not hosted learner acceptance.

Added standalone captured public scenario read repository and immutable descriptor, borrowing Auth/fixed read port/caller generation readiness. No construction dispatch/cache/provider/SDK/route/default activation. Exact N5/N4 level and captured session identity, single-flight reserved before getters/port reentry, permanent fencing after observed readiness/identity loss/401/revoke. Timeout<=15s ends caller wait while retaining busy until both original wire and caller drain; late success/error consumed/no auto retry/publication. No SDK close/ownership transfer. Previously returned snapshots cannot be erased; host must discard by generation.

Public projection is internal, not frozen wire API: exactly id,jlpt_level,title_vi,title_ja,description_vi,content_version,is_active, bounded0..100 rows, all-or-nothing decode, unique case-insensitive UUIDs, active/level equality, positive int32 version, nonblank Unicode titles<=200/description<=2000. Text/case/order preserved/immutable. Reject unknown/private fields incl system_context. Existing authenticated SQL column grants permit projection; no grants/migration/RLS change. Future SDK port must enforce fixed table/columns/filter/id order/limit101/bounded HTTP/JSON/captured credentials. Valid client rows do not authorize mutation: backend still revalidates scenario active/level/owner. No real catalog/provisioning/linguistic freshness proof.

15/15 new tests passed in fresh identical five-library graph with only flutter_test->test1.26.2 adaptation: no auto loading/exact capture/N4/empty/immutable/literal/Unicode/max bounds, malformed/private/duplicate/mixed rows, no-dispatch validation/local-slot release, concurrent/reentrant port, timeout late success/error, same-user/other-user/logout/readiness/revoke/A-B-A, safe raw/401/getter failures. Fresh official Dart3.9.2 SHA256 verified; strict casts/inference/raw types+lints6 analyzer no issues after three required brace blocks, assertions unchanged. Final pinned format2/0changes, inventory99/46 QA regressions/whitespace/separate source/lifecycle/harness parity review passed. All98 earlier QA cases/findings/gates preserved/all14 hosted groups pending. Full local Flutter/SDK/widget/native/build unrun; no denied bootstrap retry/bypass.

Five paths: new lib/features/ai/data/captured_conversation_scenarios.dart, test/features/ai/captured_conversation_scenarios_test.dart, docs/CONVERSATION_SCENARIO_READ.md; existing PROJECT_STATUS.md and qa/matrix.json. Old app/controller/flow/route/Auth/credentials/SDK/API/schema/RLS/CI/dependencies/Pro/content untouched. Next inspect new exact-head/latest-attempt allfive/every required step/new15 cases, fix actual diagnostics; pending-only handoff/no duplicate work/long polling. Then concrete caller-owned bounded SDK read/runtime source/lifecycle and real HTTP/mounted host coverage before trusted scenario selector/explicit mutation/recovery-new-round UI. Keep41 draft/17 open/default AI off/all14 hosted human gates pending. No merge/closure/deploy/release/security/spend/schedule action/Alpha claim. Durable tree/readbacks/CAS/CI/released checkpoint41/17/37.


## SDK-bound public scenario HTTP — core-20261025T0215-scenario-http

Expected parentd1a882099dcfe21c6980ef1b731f3c9258434f06/draft41/automation/issue-11-plan-sdk-integration. Fresh main78a44fa/source37afa572a/Pro14/38 at28c20cb unchanged. Parent CI40150141408 raw exactparent/latest attempt1 completed success: complete allfive jobs/every required step/no skips verified. Flutter log121040130461 confirms1063 Flutter/five Chrome/all15 captured scenario tests; TEST ONLY component proof, not hosted acceptance.

SupabaseAiTextTransport now implements ConversationScenarioReadPort via explicit read(capturedSession,N5/N4) only. Fixed GET same validated project/rest/v1/conversation_scenarios, exactly seven public columns, active/exact level filter/id order/limit101/empty body. Existing SDK/token/expiry/ready owner guards and shared bounded HTTP lease reused across read/text/conversation operations. No new client/resources/provider call/auto read/retry/default activation. Existing 1MiB/4096read/JSON UTF8/depth16/duplicate-key/header/length/no-redirect/abort/deadline/late-header/cancel-drain/fixed-error defenses retained. Array/>101 fails at transport;101 sentinel/all row shape/owner-level/version/private/duplicate constraints fail in captured repository, no partial selectable list. Server still revalidates active scenario/owner/level on start. No new learner endpoint/table/key input, SDK ownership/Auth strategy/grant/RLS/wire/schema change.

49/49 actual-SDK injected HTTP tests passed: all38 previous cases/helpers/assertions byte-identical plus11 new GET/query/headers/no-provider/unsupported-level/foreign-owner/operation-injection/private/mixed/duplicate/overflow/empty/header/redirect/UTF8/JSON/chunk/read limits/late-header success-error/shared exclusion/SDK session-ready-401/borrowed close cases. Fresh official Dart3.9.2 archive SHA verified; identical14-library graph/original frozen fixture bytes, only flutter_test->test1.26.2 runner adaptation. Eight SDK/HTTP version+hash lock records match repository. Strict targeted analyzer of changed transport/test clean. Whole temporary graph analyze reports one existing unnecessary_underscores info in unchanged supabase_review_binding.dart47; not changed/suppressed, no whole-graph clean claim. No actual local full Flutter/browser/native/build; no denied bootstrap retry/bypass. Pinned format2/0changes/inventory100/46QA/whitespace/separate diff/lifecycle/harness parity passed, all99 prior QA cases/findings/gates exact/all14 hosted groups pending.

Five edited paths: supabase_ai_text_transport.dart +test, CONVERSATION_SCENARIO_READ.md, PROJECT_STATUS.md, qa/matrix.json. All old mutation dispatch/receipt/controller/runtime/source/default/route/SDK close semantics retained; source/content/Pro/credentials/dependencies/CI untouched. Adapter not wired into runtime/source/App/UI yet, no real catalog provisioning or hosted PostgREST/JWT/RLS/provider/voice/learner proof. Next inspect exact new-head/latest-attempt allfive/every required step/new11+old38 SDK cases; fix diagnostics, pending-only handoff/no duplicate implementation/long polling. Then retained captured catalog runtime/source lifecycle/App and mounted host coverage before scenario selector/mutation/recovery-new-round UI. Keep41 draft/17 open/default AI off/all14 human gates; no merge/closure/deploy/release/security/spend/schedule action/Alpha claim. Durable commit/tree/readbacks/CAS/CI/released checkpoint41/17/37.


## Retained scenario runtime owner — core-20261025T0310-scenario-owner

Expected parent7c7c20795b62dd0ed49c75d1ff13970e1c362a85/draft41/automation/issue-11-plan-sdk-integration. Fresh main78a44fa/source37afa572a/Pro14/38 at28c20cb unchanged. Exact parent CI40153934517/latest attempt1 completed success: complete allfive jobs/every required step/no skips verified. Flutter log121051431950 confirms1074 Flutter/five Chrome/new11 SDK scenario cases. Component evidence only, not hosted JWT/PostgREST/RLS/provider/voice/learner acceptance.

AiTextRuntimeOwner.acquireScenarios retains one captured public reader on its existing text/conversation transport lease, construction/factory no dispatch. Optional read-port absence returns unavailable preserving text lease. Guard lease/repository/transport/epoch, creation slot installed before reentrant getters, publish only current/orphan revoke. Existing conversation factory/uncertain/finished receipt lane never reset. check includes retained reader; invalidate revokes reader before sibling conversation/text/transport callbacks; old generation retired. New acquisition waits for actual shared transport close/drain; failed cleanup permanently blocks replacement. Previously returned lists still require host generation discard. No new transport/SDK/token owner/cache/auto read/retry/default activation.

50/50 relevant pure Dart cases passed (10 new owner cases plus40 prior text/conversation-owner and captured-scenario cases), fresh identical11-library/four-test/original fixture graph; only flutter_test->test1.26.2 runner import adaptation. New cases: retained/no-dispatch/same-transport/finished conversation preserved, optional port absent, callback order/actual held-read drain/fresh-versus-retired generations, same-user/other-user/logout/readiness/A-B-A permanent fencing, revoked reader retires siblings, failed cleanup, reentrant readiness/close/orphan cleanup. All old production owner code exact after only explicit additions; all previous tests byte-identical. Fresh official Dart3.9.2 SHA verified, strict casts/inference/raw types+lints6 analyzer no issues, pinned format2/0changes/QA101 inventory/46 regressions/whitespace/separate diff/lifecycle/harness parity passed. All100 prior QA cases/findings/gates exact/all14 hosted groups pending. Full local Flutter/SDK/browser/native/build unrun; no denied bootstrap retry/bypass.

Five paths: owner file, new scenario_runtime_owner_test.dart, CONVERSATION_SCENARIO_READ.md, PROJECT_STATUS.md and qa/matrix.json. This increment is runtime owner only; persistent SDK runtime/startup/source/Riverpod/App/UI still need forwarding/gated acquisition and actual mounted lifecycle coverage. No Auth strategy/credentials/default flags/transport HTTP/API/schema/RLS/CI/dependency/curriculum/Pro changes or new real-catalog provisioning. Next exact-head/latest-attempt allfive/every step/new10+old40 cases; fix diagnostics, pending-only durable handoff/no duplicate code/long polling. Then host/source forwarding after persisted rotation/own-profile readiness and refresh/logout/account generation barriers, before scenario selection/mutation/recovery-new-round UI. Keep41 draft/17 open/AI off/all14 hosted human gates pending; no merge/closure/deploy/release/security/spend/schedule action/Alpha claim. Durable tree/readbacks/CAS/CI/released checkpoint41/17/37.


## Owned scenario startup source — core-20261025T0415-scenario-startup

Expected parent554bc8b4ca010a5f44ccdbafe51c5afeee951b5e/draft41/automation/issue-11-plan-sdk-integration. Fresh main78a44fa/source37afa572a/Pro14/38 at28c20cb unchanged. Exact parent CI40157396485/latest attempt1 completed success: complete allfive jobs/every required step/no skips verified. Flutter log121061914615 confirms1084 Flutter/five Chrome/all10 scenario-owner cases; component evidence, not hosted learner acceptance.

New separate optional AiConversationScenarioSource preserves existing source implementations. PersistentSupabaseRuntime acquires one retained reader via shared owner only under existing aiConversationEnabled (default false), exact owned ready runtime/session/generation after persisted rotation/own-profile. Factory sends nothing, same owner changes hints; all preexisting lifecycle invalidation/drain retained. PersistentAccountStartup forwards; WindowsStagingOwner stops acquisition as close starts; AccountStartupController exposes optional source only active/not closed. No new SDK/token/storage ownership, auto read/retry, flags, App/Riverpod override/route/UI or Auth strategy.

Six actual-SDK/runtime fixture tests AUTHORED, NOT locally executed: persisted vault/profile barriers and retained/no-dispatch reader, ready text-only/default-off, separate vault/profile failure, refresh-before-rotation revocation/ignored HTTP drain/fresh bearer/logout, actual WindowsStagingOwner+PersistentAccountStartup/controller source forwarding and close. All earlier SDK test/helper/assertion bytes exact except three added imports/continuation. Existing real-loop test style retained; TEST ONLY Auth/vault/HTTP/native journal, no hosted JWT/provider proof. Full Flutter/SDK/native-wrapper/strict host analysis requires new exact-head CI; local Flutter unavailable/no denied bootstrap retry/bypass.

Two new pure startup-controller lifetime tests PASSED: optional source hidden idle/loading/closed and legacy source absent, acquisition never implicit. Fresh identical28-library graph, only flutter_test->test1.26.2 runner adaptation; fresh official Dart3.9.2 SHA verified. Strict targeted analyzer for changed pure controller/source/test clean, not full host/Flutter analysis. Pinned format7/0changes, QA inventory102/46 regressions/whitespace/separate scope/lifecycle/harness review passed. All101 previous QA cases/findings/gates exact/all14 hosted human groups pending.

Ten paths: new optional interface +new scenario_startup_source_test.dart; existing persistent SDK runtime/startup/controller/Windows staging owner, persistent_ai_text_runtime_test.dart, CONVERSATION_SCENARIO_READ.md, PROJECT_STATUS.md, qa/matrix.json. Source reader/owner/SDK transport implementation unchanged. Default preview/staging flags/Auth strategy/credentials/API/schema/RLS/CI/dependencies/curriculum/Pro untouched. Next exact-head/latest-attempt allfive/every required step/new6 SDK+2pure cases; fix actual diagnostics without weakening assertions. Pending-only durable handoff/no duplicate work/long polling. Then guarded scenario source/Riverpod/App binding and actual mounted host lifecycle tests before selector/explicit mutation/recovery-new-round UI. Keep41 draft/17 open/AI off/all14 hosted release gates pending; no merge/closure/deploy/release/provider/collection/spend/security/schedule action/Alpha claim. Durable tree/readbacks/CAS/current CI/released checkpoint41/17/37.


## Borrowed scenario Riverpod/App binding — core-20261025T0516-scenario-binding

Expected parent3da0456fd8761c409a4bc566d5b79f709e733334/draft41/automation/issue-11-plan-sdk-integration. Fresh main78a44fa/source37afa572a/Pro14/38 at28c20cb unchanged. Exact parent CI40161439700/latest attempt1 completed success: complete allfive jobs/every required step/no skips verified. Flutter log121073929580 confirms1092 Flutter/five Chrome/all6 owned scenario SDK/source cases. Component evidence only, not hosted JWT/RLS/PostgREST/provider/voice/learner acceptance.

Added separate AiConversationScenarioBinding/notifier/providers borrowing runtime-retained reader and owner void hints, default source null. Watch account state independently for initial readiness; guarded factory/reentry slot/current checks, same-reader binding identity preserved, null/revoked/source getter failure clears, stream error/close permanently disables notifier. Cancellation/disposal owned subscription only; never reader/SDK/transport/receipt reset. No rows/request/text snapshots in hint/binding. AccountStartupApp installs only optional source override from active controller. Existing text/conversation binding/routes/default-off flags and Auth/runtime/SDK behavior exact; factory/read-binding makes no request.

11 source/Riverpod +2 actual mounted App/SDK/native-journal/Windows-owner cases AUTHORED, NOT locally run. Source cases default/null/broken stream/ready identity/no dispatch/readiness/new owner/revoked/source failure/stream error+closure/borrowed disposal+override/reentry/same-user replacement-A-B-A. Mounted enabled case holds saved-token rotation and own-profile before availability, explicitly reads fixed scenario GET/captured bearer, refresh revokes immediately, binding remains null through held rotation/profile, fresh reader/new bearer/no auto reload, explicit reload then logout clears. Default mounted app ready/text still exposes no reader/no HTTP. Barriers created inside real-loop runAsync as prior verified journeys; all original mounted test/helper/assertion/cleanup bytes exact except one import/continuation. New journey has no simulated success/source override or view factory substitution. No scenario/mutation UI mounted yet; /ai remains existing tutor/preview.

Fresh official Dart3.9.2 archive SHA verified. Pinned format4/0changes after applying new-test formatting; inventory103/46 QA regressions/whitespace/separate source/lifecycle/preservation review passed. All102 previous QA cases/findings/gates exact/all14 hosted groups pending. Full local Flutter/analyzer/Riverpod/SDK/widget/native/build unrun; no denied bootstrap retry/bypass or new-test pass claim. Exact-head CI must execute all13 new cases and strict host checks.

Seven paths: new ai_conversation_scenario_binding.dart +ai_conversation_scenario_binding_test.dart; existing account_startup_app.dart,ai_owned_startup_journey_test.dart,CONVERSATION_SCENARIO_READ.md,PROJECT_STATUS.md,qa/matrix.json. App preservation proof removes only import+override to recover old bytes; all prior journey bodies exact. Existing source/runtime/owner/read transport/credential/Auth strategy/API/schema/RLS/CI/dependency/Pro/content unchanged; no real catalog provisioning. Next inspect new exact-head/latest-attempt allfive/every required step/new11 binding+2 mounted cases; fix actual diagnostics preserving assertions, pending-only durable handoff/no duplicate code/long polling. Then explicit guarded scenario loading/selection and mutation/recovery-new-round policy UI with owned host coverage. Keep41 draft/17 open/AI off/all14 hosted human gates pending; no merge/closure/deploy/release/provider/collection/spend/security/schedule action/Alpha claim. Durable tree/readbacks/CAS/CI/released checkpoint41/17/37.


## Explicit read-only scenario selector — core-20261025T0610-scenario-selector

Expected parent7d3f235b1775f5de2b198bfdfecd4f08b9acdb4f/draft41/automation/issue-11-plan-sdk-integration. Fresh main78a44fa/source37afa572a/Pro14/38 at28c20cb unchanged. Exact parent CI40165101431/latest attempt1 completed success: full allfive jobs/every required step/no skips verified. Flutter log121084748241 confirms1105 Flutter/five Chrome/both mounted scenario binding journeys. Prior13 cases verified; TEST ONLY component proof, not hosted JWT/RLS/PostgREST/provider/voice/learner acceptance.

Added pure ConversationScenarioController and reusable unrouted ConversationScenarioPanel. Borrow one captured reader/hints, no construction/read/recheck/level-choice dispatch. Explicit load N5/N4 only, one view load, clear old rows/selection/error before sending, publish only current epoch/owner. Selection requires identical object in current immutable result list; old equal-ID/foreign row rejected. Level/reload clears choice; loading/external busy blocks control changes. Timeout holds reader busy until actual drain, explicit recheck/reload only/no polling or automatic retry. Invalid/empty/error stays honest. Observed loss/same-user-A-B-A/hint error/closure/dispose permanently redacts view, late response/error cannot publish; nested readiness reads redact without revoking a healthy reader. View disposal never closes/revokes borrowed reader/SDK.

Panel explicit read button, N5/N4 dropdown, unavailable/idle/loading/empty/fixed safe error, literal titles/descriptions/local choice, voice/start unavailable, narrow/large-text scroll. Callback closures bind original controller, cannot retarget replacement account or setState after unmount. No arbitrary UUID/URL/key input, start/send/finish/event IDs/reset/new-round/save/mastery/SRS/progress/route/default activation. Selected row is not server mutation authorization or permission to bypass unresolved receipts. Actual selector-to-conversation/recovery integration remains next.

13/13 pure controller tests passed in fresh identical six-library graph, only flutter_test->test1.26.2 runner adaptation. Covers no auto dispatch, exact immutable selection/level, stale equal-ID/reload/single-flight, empty/malformed/safe errors, timeout late success-error/drain, same-user/readiness/dispose late fencing, hint error/close/borrowed disposal/queued hints and getter reentry. Fresh official Dart3.9.2 SHA verified; strict casts/inference/raw types+lints6 analyzer no issues after new-code required braces; assertions retained. Seven widget cases AUTHORED, NOT locally run: explicit load/unavailable, literal selection/level, empty/error/no private detail, identity revocation, replacement/unmount retained callback fences, late unmount,320px/200% scroll. Full Flutter/widget/SDK/native/build requires new CI/no denied bootstrap retry/bypass.

Pinned format4/0changes, inventory104/46 QA regressions/whitespace/separate scope/lifecycle/harness parity review passed; all103 earlier QA cases/findings/gates exact/all14 hosted groups pending. Seven paths: four new controller/panel+tests, CONVERSATION_SCENARIO_READ.md,PROJECT_STATUS.md,qa/matrix.json. Existing app/router/binding/source/runtime/transport/Auth strategy/credentials/API/schema/RLS/dependencies/CI/curriculum/Pro untouched. Next exact-head/latest-attempt allfive/every step/new13pure+7widget cases; fix real diagnostics preserving assertions, pending-only handoff/no duplicate code/long polling. Then compose selection with retained conversation and explicit mutation/recovery-new-round policy+actual owned mounted coverage; no fake default provider or hosted proof. Keep41 draft/17 open/AI off/all14 hosted human gates pending/no merge/closure/deploy/release/provider/collection/spend/security/schedule action/Alpha claim. Durable tree/readbacks/CAS/CI/released checkpoint41/17/37.

## Pure conversation workspace composition — core-20261025T0722-conversation-workspace

Expected parentbc62c8ac881203c0d45e55c649bd7d71732147fc/draft41/automation/issue-11-plan-sdk-integration. Fresh main78a44fa/source37afa572a/Pro14/38 at28c20cb unchanged. Exact parent CI40168397758/latest attempt1 completed success: full allfive jobs/every required step/no skips verified. Flutter log121094353973 confirms1125 Flutter/five Chrome/all20 previous scenario selector cases; Web/Windows/native/SQL/Edge retained gates passed. TEST ONLY component proof, not hosted learner acceptance.

Added pure ConversationWorkspaceController owning two ephemeral views over trusted same-ready-generation borrowed reader/retained flow. No construction/read/recheck/remount/dispose dispatch or event generation. Missing either capability permanently redacts pair; optional trusted event factory absent disables new mutations. Explicit selected-current-row start only/row ID+level, turn/finish derive accepted session. Reserve workspace slot before supplied callback, validate text before ID, generate once/recheck owner+selection/session after callback; reentry/loss/dispose cannot retarget or double dispatch. Exact existing DTO/Unicode/whitespace/events retained. Local nil-ID DTO validation never dispatches. Fixed safe factory/text errors, no raw detail.

Active/pending/finished flow blocks catalog changes/new start; existing shared busy/unresolved/receipt lane remains authoritative. Allthree timeout late-success/error paths retain original immutable command/event, block edits/new IDs/finish/reload while unresolved, and enable only explicit original retry after real I/O drains/safe retry policy. No polling/reset/new-round/recovery fallback. Disposed pending view cannot reconstruct/retry by remount; accepted active/finished state survives borrowing with no auto catalog/start. Missing secure host factory/pairing/UI/approved durable client recovery/new-round policy remain explicit next work, no arbitrary learner UUID/endpoint/key configuration.

Either view loss/same-user-A-B-A/hint error+closure/disposal permanently clears both public projections/errors; late completion cannot republish. Capability checks followed by fresh projection reads prevent later readiness loss exposing earlier text. CapturedConversationScenarios adds only readonly isCheckingAvailability hint matching existing flow; nested raw/view getter reentry redacts without retiring healthy pair. Reader reverse-diff exactly reproduces all previous bytes after removing the additive four-line hint. Borrowed resources/flow receipts/SDK never reset/revoked/closed by workspace disposal. Trusted host must pair same runtime generation and broadcast owner hints; component does not authenticate cross-source pairing. Externally retained snapshots still require host discard.

22/22 new pure tests PASSED, plus all34 prior conversation/selector controller cases PASSED with identical production/test bodies/original frozen fixtures, ONLY flutter_test->test1.26.2 runner adaptation. Fresh official Dart3.9.2 archive SHA verified; recursive13-library/three-test graph, strict casts/inference/raw types+lints6 analyzer clean. Cases cover missing pair/factory, explicit exact N4 progression/finished and active remount, foreign/stale row/level, six uncertainty/late success-error/exact retry paths, unresolved remount, malformed text/event factory failure, each-side/session loss, stream closure/error, callback/getter reentry, loss during factory, held read/unmount, loss discovered at later capability check. Initial local harness analysis launched before pub resolution completed; rerun after completed pub get was clean. Six new multiline-if lint corrections retained all assertions. Full local Flutter/widgets/SDK/native/build unrun; no denied bootstrap retry/bypass.

Pinned formatter3/0changes, inventory105/46QA/whitespace/separate scope/lifecycle/harness parity passed; all104 earlier QA objects/findings/gates exact/all14 hosted release groups pending. Six paths: new workspace controller/test/CONVERSATION_WORKSPACE.md, existing captured reader hint/PROJECT_STATUS/qa matrix. Existing selector/controller/session/transport/runtime/source/App/router/default flags/Auth strategy/credentials/API/schema/RLS/CI/dependencies/content/Pro untouched. No voice/provider/transcript storage/study minutes/mastery/SRS/progress write or simulated default success.

Next inspect exact new-head/latest-attempt allfive/every required step/new22cases, fix actual diagnostics preserving assertions. Pending-only durable handoff/no duplicate implementation/long polling. Then guarded workspace UI/actual owned mounted host pair+secure event factory and explicit safe error/pending/manual-retry controls, retaining unresolved/finished-round fences and all human gates. Keep41 draft/17 open/AI off/all14 hosted groups pending; no merge/closure/deploy/release/provider/collection/spend/security/schedule action/Alpha claim. Durable tree/readbacks/expected-head CAS/new CI/released checkpoint41/17/37.

## Opt-in workspace command panel — core-20261025T0819-workspace-panel

Expected37b1b1503e20d07c60696fe4855908fa3a764315/draft41/automation/issue-11-plan-sdk-integration. Fresh main78a44fa/source37afa572a/Pro38at28c20cb unchanged. Parent CI40172900658 raw exactparent/latest attempt1 allfive jobs/every required step/no skips success; Flutter log121107648494 confirms1147 Flutter/five Chrome/all22 workspace cases plus retained Web/Windows/native/SQL/Edge gates. Component evidence, not hosted acceptance.

New immutable ConversationWorkspaceBinding borrows trusted same-ready-generation reader/retained flow/broadcast hints/optional host event factory; no pairing authentication or secure generator installed. ConversationWorkspacePanel owns ephemeral workspace controller/editor/subscription. Explicit catalog loading/level/current-row selection/start/text-send/finish/original manual retry through existing controller; captured callbacks never retarget replacement controller/editor, send checks current identity before editor access and after await. Typing never sends; editor clears on unavailable/unresolved/finished/accepted send, replacement/unmount disposes it. No durable draft/user transcript/cache, arbitrary learner UUID/URL/key, receipt reconstruction/reset/newround or auto retry.

Missing pair/factory, idle/loading/empty/safe errors/uncertainty/finished states honest, active/pending/finished blocks catalog/new start. Exact request/text/session/event semantics delegated unchanged. Retained unresolved remount cannot reconstruct retry or reset; original safe retry preserves DTO/event/no ID generation. Accepted assistant/translation literal/no HTML/URL/audio fetch; voice unavailable and no progress/SRS save claim. Detailed summary remains existing independent read-only panel; actual host composition/secure UUID factory/runtime generation pair/route integration remain next. Existing /ai/default flags/App/providers/SDK/Auth/transport/security/API/schema/RLS/CI/dependencies/content/Pro untouched.

Seven widget cases AUTHORED, NOT locally executed: missing/unconfigured/no auto dispatch; exact draft/send/finish/fences; controlled provider retry same original body/event/no edited send; same-user loss/A-B-A editor/view clearing; replacement/unmount old callback guard/borrowed preservation; unresolved remount no reconstructed retry;320px/200% scroll. Real captured reader/controller/flow with TEST ONLY injected Auth/ports/frozen fixtures, not actual owned startup/mounted SDK/hosted learner proof. No new Flutter/analyzer/widget/native/build pass claimed; local SDK unavailable/no denied bootstrap retry/bypass. Fresh official Dart3.9.2 SHA verified; pinned format3/0changes, inventory106/46QA/whitespace and separate callback/lifetime/scope review passed; all105 earlier QA objects/findings/gates exact/all14 hosted groups pending.

Six paths: new conversation_workspace_binding.dart,conversation_workspace_panel.dart,conversation_workspace_panel_test.dart,docs/CONVERSATION_WORKSPACE_PANEL.md; existing PROJECT_STATUS.md,qa/matrix.json. No prior production/test bytes altered. Next exact new-head/latest-attempt allfive/every required step/new7widget cases; fix real diagnostics preserving assertions. Pending-only durable handoff/no duplicate work/long polling. Then actual owned host pair/event factory/route composition with explicit opt-in and summary/recovery states; no unsafe newround/receipt bypass. Keep41 draft/17 open/AI off/all14 human gates pending/no merge/closure/deploy/release/provider/collection/spend/security/schedule action/Alpha claim. Durable tree/readbacks/expected-head CAS/CI/released checkpoint41/17/37.

## Workspace message type correction — core-20261025T0910-workspace-message-type

Resume draft41/automation/issue-11-plan-sdk-integration expected d496440b0ac780eef8410a3a89dc4ab848e88d9e. Fresh main78a44fa/source37afa572a/Pro38at28c20cb unchanged;17open. Exact CI40176232761/latest attempt1 completed FAILURE: repo-sanity/database/AI/Windows every required step success; Flutter strict format passed, analyzer failed exactly two argument_type_not_assignable diagnostics at panel249/250. Empty untyped fallback caused dynamic message projection; Flutter full tests/new7widgets/Chrome/Web/downstream skipped, never passed. Raw complete latest-attempt allfive jobs and Flutter log121117757806 observed.

Bounded source fix imports ConversationAssistantMessage and types only const empty fallback in the assistant loop. Same retained snapshot list/ordinary Text/nullable translation/phase/callback/receipt/SDK behavior. No cast, dynamic allowance, suppression, removed assertion or weaker gate. Independent reverse-diff proof recovers all original panel bytes after removing import/typed loop; all seven widget cases and all assertions byte-identical, original QA106/CI/security/dependencies/content/Pro untouched. Two append-only docs record actual failure and pending evidence. No further host/UI work before this correction is verified.

Fresh official Dart3.9.2 archive SHA256 verified. Pinned format1/0changes, QA inventory106/46regressions/whitespace/separate diagnostic/source/scope review passed. Local full Flutter/analyzer/widget/SDK/native/build unavailable and UNRUN; no denied bootstrap retry/bypass. Three edited paths only: conversation_workspace_panel.dart, CONVERSATION_WORKSPACE_PANEL.md, PROJECT_STATUS.md. Corrected-head strict analysis/seven widgets/full retained platform checks require exact-head CI.

Next inspect new exact-head/latest-attempt allfive/every required step, fix actual remaining diagnostics retaining assertions; pending-only handoff/no duplicate work/long polling. After green continue actual owned host same-generation pair/secure UUID factory/opt-in route+summary integration, retain uncertainty/finished/no-newround guards. Keep41 draft/17open/AIoff/all14 hosted learner groups pending; no merge/closure/deploy/release/provider/Auth strategy/collection/spend/security/schedule action/Alpha claim. Durable complete-tree/readbacks/expected-head CAS/CI/released checkpoint41/17/37.

## Composed workspace provider — core-20261025T1020-workspace-provider

Resume draft41/automation/issue-11-plan-sdk-integration expecteddcf0e134cb8204b92161cdcc68f8a0d71f992820. Fresh main78a44fa/source37afa572a/Pro38at28c20cb unchanged/17open. Parent CI40179525017 raw exactparent/latest attempt1 completed success: complete allfive jobs/every required step/no skips verified. Flutter log121127676798 confirms1154Flutter/fiveChrome/all7workspace panel cases; dynamic fallback fix verified. Web/Windows/native/SQL/Edge retained gates passed; TEST ONLY component evidence, not hosted learner acceptance.

New conversationWorkspaceBindingProvider composes existing source/binding providers, requiring SAME source object before acquisition, identical nonnull owner hint stream, ready retained reader/session/reader recheck. Null/mixed source/stream/retired/raw getter failure yields null/no partial pair. Default sources null, no request or ID generation during reads/acquisition. Existing notifiers own account/readiness/hints; new provider owns no SDK/subscriptions/transport/receipt cleanup. Source/hint identity prevents accidental mixing, not authentication of an arbitrary in-process host; actual owned runtime remains responsible for same-generation lease/revocation/drain. AccountStartupApp already provides both source overrides unchanged; actual mounted provider-to-panel/route+summary proof remains next.

New trusted conversationEventFactoryProvider captures callable only; createConversationEventId uses16 Random.secure bytes/version4/variant/lowercase shape. No timestamp/counter/pseudorandom fallback; entropy failure propagates to existing safe controller error. New explicit command calls once after reserve; pending retry keeps original DTO/event and never invokes factory. No new flow/reset/reconciliation/newround/durable transcript, arbitrary learner UUID/endpoint/key or default AI activation. App/router/flags/Auth strategy/runtime/SDK/frozen API/schema/RLS/CI/dependencies/content/Pro and all prior source/test bytes unchanged.

Ten source/Riverpod tests AUTHORED, NOT locally run: default null, different same-user source before acquisition, retained binding identity/no request or ID until explicit callable, mismatched streams, readiness hint, same-user replacement/A-B-A, stream error/close preserving borrowed resources, source factory failure/no partial pair, UUIDv4 shape/unique sample. Fixtures use real captured reader/flow and TEST ONLY source/Auth/ports, no actual mounted App/SDK/hosted identity proof. Official Dart3.9.2 SHA verified; exact copied production UUID function executed256 canonical/unique smoke checks PASS (not statistical entropy assurance). Format2/0changes/inventory107/46QA/whitespace/separate source/scope/security review PASS; all106 old QA objects/findings/gates exact/all14 hosted groups pending. Full local Flutter/analyzer/Riverpod/widgets/native/build UNRUN/no denied bootstrap retry/bypass.

Five paths: new conversation_workspace_provider.dart +conversation_workspace_provider_test.dart +docs/CONVERSATION_WORKSPACE_PROVIDER.md; existing PROJECT_STATUS.md,qa/matrix.json. Next exact new-head/latest-attempt complete allfive/every required step/new10cases; fix actual diagnostics preserving assertions. Pending-only handoff/no duplicate code/long polling. After green actual owned host pairing+secure factory journeys and opt-in route/summary composition, preserve uncertainty/finished/no-reset/manual-original-retry semantics. Keep41 draft/17open/AIoff/all14 human gates pending/no merge/closure/deploy/release/provider/Auth strategy/collection/spend/security/schedule action/Alpha claim. Durable full-tree/readbacks/expected-head CAS/CI/released checkpoint41/17/37.
