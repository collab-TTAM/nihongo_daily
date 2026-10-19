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

## Original curriculum browser — 2026-10-19 UTC

- Single core run core-20261019T1358-curriculum-browser, main-based branch
  automation/issue-12-curriculum-browser from 78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c.
  #2/#3/#5 closed and original N5 exports present; #12 permits independent reader
  work before Daily Plan/study-event linking. Full #12 acceptance stays open.
- Resumed/reviewed #37 first: exact source afa572a27f050048990ad4feb07fd6f01758e7e2
  passed all five jobs in CI39263961507, 381 Flutter + five Chrome tests and all
  downstream/native/SQL/build gates. That source is still an unmerged draft, not
  hosted learner proof or current main. Its Auth/SRS files are not copied here.
- Added typed/version-preserving vocabulary/grammar projection and repository,
  actual canonical N5 assets (24 vocabulary/10 grammar), list/detail navigation,
  level filtering, Japanese readings/Vietnamese usage/notes/mistakes/examples,
  safe loading/error/empty/manual retry and explicit missing N4/audio/progress.
  N4 returns unavailable/empty without substituting N5 or fixture content.
- Five repository/asset/decoder and six widget cases authored; existing default
  home/study CTA opens actual vocabulary content. New widgets include both
  screens at 320px/200% text. No content/data/manifest/Pro N4 paths or content
  validators/tests or dependencies/API/schema/Auth/RLS changes. No study writes.
- Local QA17 regressions, main-based inventory27 and git diff --check passed;
  original-export spot-check confirms required display fields/24+10 rows. No
  local Dart/Flutter/format/analyze/build/contract-validator pass claimed (SDK/
  jsonschema unavailable). Exact-source Actions still required before pass.
- Keep focused PR draft and #12 open: validated study events/progress, full
  coverage/curation/audio/hosted learner acceptance still missing. Pro #14/#38
  remains independent and untouched. All 14 live release groups remain pending.
  Coordination heartbeat/release and exact source/CI are persisted in PR bodies.

- First reader source 9781260cc2dde6d04aa7de891a4467f5a21813a7 / CI39266546355
  stopped at formatting in four new files. Preserve the required format step
  name and strict failure; on failure only, print the SDK-formatted Dart diff
  from the disposable runner so a cloud worker without SDK can apply the exact
  correction. No automatic commit, test skip or success fallback; format still
  exits 1 on a mismatch. Fresh corrected-source full CI is required.
- Reviewed pinned Flutter 3.35.4 asset copying: output paths join the asset key.
  Package unchanged N5 exports inside app assets instead of parent-relative keys;
  actual rootBundle-to-canonical equality remains mandatory in repository tests.
  Canonical data/N4 files remain untouched; new-source build/test proof pending.
