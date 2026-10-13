# PROJECT STATUS

Current release target: Personal Alpha
Overall status: IN_PROGRESS — shared contracts implemented; no app build yet.

| Milestone | Status | Owner / prerequisite |
| --- | --- | --- |
| Architecture baseline | IMPLEMENTED; integration tracked in #1 | Lead |
| Flutter skeleton | READY after #1 merge | #2 Flutter |
| Supabase schema/auth | READY after #1 merge | #3 Backend |
| SRS engine | BLOCKED on usable Dart package from #2 | #4 Learning |
| Kanji writing engine | BLOCKED on #2/reference data | #6 Kanji |
| AI tutor | BLOCKED on #3 | #7 AI |
| N5/N4 content pipeline | N5 ready after #3 mapping; N4 follow-up needed | #5 Content |
| QA/security baseline | BLOCKED on first implementation PR | #8 QA |

## Latest handoff — Issue #1, 2026-10-13

- Completed: resolved rating/units/date/retry/ownership ambiguities; 37 named schema definitions, eight endpoint bindings, 20 fixtures, validator and 14 regression tests; dependency and merge order documented.
- Remaining: Flutter #2, database/RLS #3, SRS #4, curriculum #5 and remaining Personal Alpha modules.
- Changed files: contracts/v0.1/*, contracts/validate.py, contracts/test_contracts.py, contracts/requirements.txt, API_CONTRACTS, DATABASE_SCHEMA, ARCHITECTURE, CONTRACT_BASELINE, this status, README, CI workflow.
- API changes: typed definitions for eight already-planned operations; RPC/Edge boundaries, safe errors, bounded outputs and scoped retries.
- Database changes: specification only; user-scoped review uniqueness/original-result receipts, conversation receipts, parent-message ownership, integrity and validated write requirements. No migration applied.
- Known issues: no Flutter app or live service; fixture validation does not test deployed RLS/providers. Audio streaming/upload contract remains later work.
- Tests: local validator passed all 20 fixtures and all 14 regression tests passed. PR/current-head CI is the integration gate; see #1/its PR for evidence.
- Next task: #2 Flutter shell after #1 integration, without external credentials.
- Blockers/decisions: none for #2; live Supabase/AI/voice configuration is addressed when integration is implemented.
