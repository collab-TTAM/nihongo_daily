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
