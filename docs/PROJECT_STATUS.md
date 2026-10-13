# PROJECT STATUS

Current release target: Personal Alpha
Overall status: IN_PROGRESS — shared contracts and Flutter preview merged; database/RLS baseline in review.

| Milestone | Status | Owner / prerequisite |
| --- | --- | --- |
| Architecture baseline | MERGED via PR #10; #1 completed | Lead |
| Flutter skeleton | MERGED via PR #19; #2 completed | #2 Flutter |
| Supabase schema/auth | IMPLEMENTED storage; review/CI pending; live auth unverified | #3 Backend |
| SRS engine | READY after #2 merge; usable Dart package implemented | #4 Learning |
| Kanji writing engine | BLOCKED on #2/reference data | #6 Kanji |
| AI tutor | BLOCKED on #3 | #7 AI |
| N5/N4 content pipeline | N5 ready after #3 mapping; N4 tracked in #14 | #5 Content |
| QA/security baseline | READY to start against implementation PR #19 | #8 QA |

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

## Latest handoff — Issue #3, 2026-10-13

- Base: main 9383339 (PR #19 merged). Main CI 38409499736 succeeded.
  #2 is closed; the earlier #2 handoff above is historical.
- Branch: automation/issue-3-schema-rls. Initial additive migration with 22 public
  tables, ownership/parent-message RLS, explicit column/table grants, immutable
  review receipts, typed curriculum FKs, normalized relationship FKs and indexes.
- Only own-profile allowlisted settings are client-writable. Curriculum, events,
  scores, schedules, plans and conversation writes remain backend-only.
- Original-result replay helper and PENDING/COMPLETED receipt storage implemented;
  public submit_review/atomic state-update integration is #22 after scheduler #4.
- Local checks: migration plus SQL role/grant/isolation/integrity/replay assertions
  passed on PostgreSQL 18.6 via PGlite 0.5.9; bash syntax and Python compilation
  passed. Native PostgreSQL 17 and two-session race await the new database CI job.
  Existing Flutter/web/Windows checks are retained and must pass on current head.
- Not run locally: native PostgreSQL concurrency, hosted Supabase/PostgREST/Auth,
  live Flutter integration, or deployment. No production changes or auth strategy
  changes. External configuration remains required for live integration.
- Review/dependencies: read supabase/README.md for storage/export normalization,
  full contract validation boundaries and RPC concurrency handoff. No weakened
  tests/RLS. Issue #5 can use this mapping after integration.
- Next: complete exact-head CI/review for #3, then #4 pure deterministic SRS.

- Separate review follow-ups: #20 tracks real Auth/session lifecycle; #22 tracks
  authenticated submit_review/atomic scheduler integration after #4. Neither is
  supplied by this storage baseline. Review strengthened curriculum locking to
  FOR SHARE so publication retirement cannot race an active-content check.
- Initial native database CI 38420903307 failed at profile provisioning because
  its tzdata omitted the Asia/Saigon alias. Canonicalizing the accepted alias to
  Asia/Ho_Chi_Minh fixes actual plan conversion; invalid zones remain rejected.
  Regression checks cover default/settings alias and Vietnam UTC+7 conversion.
  Await CI on the corrected head before integration.

- Review also caught inherited service-role TRUNCATE grants under older platform
  defaults. Revoke those explicitly before granting DML; an SQL catalog regression
  proves no project table retains service-role TRUNCATE. Current-head CI is required.

- Native PostgreSQL 17 reports 23503 for the restrictive-FK delete, while the local
  PostgreSQL 18/PGlite reports 23001. The regression now requires one of those two
  referential-integrity rejection codes plus unchanged curriculum and learning
  history rows. Successful deletion or unrelated errors still fail the test.
- Contract validator (20 fixtures) and all 15 contract tests passed locally using
  the installed contract environment. No Flutter source changed in this PR.
