# PROJECT STATUS

Current release target: Personal Alpha
Overall status: IN_PROGRESS — shared contracts merged; Flutter demo shell in development.

| Milestone | Status | Owner / prerequisite |
| --- | --- | --- |
| Architecture baseline | MERGED via PR #10; #1 completed | Lead |
| Flutter skeleton | IN_PROGRESS; build/CI evidence pending | #2 Flutter |
| Supabase schema/auth | READY after #1 merge | #3 Backend |
| SRS engine | BLOCKED on usable Dart package from #2 | #4 Learning |
| Kanji writing engine | BLOCKED on #2/reference data | #6 Kanji |
| AI tutor | BLOCKED on #3 | #7 AI |
| N5/N4 content pipeline | N5 ready after #3 mapping; N4 tracked in #14 | #5 Content |
| QA/security baseline | BLOCKED on first implementation PR | #8 QA |

## Latest handoff — Issue #1, 2026-10-13

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

## Current worker — Issue #2, 2026-10-13

- Branch: automation/issue-2-flutter-shell; base main 33f31a8 (PR #10).
- Implemented: Vietnamese Material 3 adaptive shell, GoRouter module discovery and
  unavailable pages, Riverpod-injected typed demo repository, session-only N5/N4
  and theme settings, loading/error/retry/empty handling, regression tests.
- Changed files: apps/flutter_app, README, CI workflow, .gitignore, this status.
- API/database changes: none; demo allocation does not implement get_daily_plan.
- Checks: contract validator passed 20 fixtures; 15 contract regression tests passed.
  Flutter format and analyze passed (no issues); 22 Flutter tests passed, including
  200% text on 320/375px layouts after fixing the theme dropdown overflow. Web
  release build succeeded locally; a missing optional Cupertino icon font was
  then supplied, so the final dependency lock awaits current-head CI/build.
  Windows build and PR CI remain pending. Direct browser smoke was not observed:
  the local headless Chrome process crashed before the app could load.
- Known limitations: real content, auth, storage, sync, SRS, scoring, progress,
  providers and voice remain unimplemented; preview routes state this explicitly.
- Next: complete Flutter checks and review/CI, integrate #2, then select #3.
- Blockers: none requiring user input. Windows build needs Windows CI; iOS runner,
  signing and device validation remain later work.
