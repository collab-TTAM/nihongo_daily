# Lead review — v0.1 shared contract baseline

Issue #1 resolves initial document ambiguities without changing Flutter/Supabase/Auth strategy or deploying a database. Review: 2026-10-13. Base commit: 0bdd0451af84f24efcef13431fc119dd49a03d77.

## Decisions

| Initial ambiguity | Frozen v0.1 rule | Delivery owner |
| --- | --- | --- |
| SRS rating/correctness unspecified | AGAIN/HARD/GOOD/EASY = 0/1/2/3; only AGAIN is false | #3/#4 |
| Difficulty and score units omitted | Difficulty/retrievability [0,1]; scores [0,100]; intervals/stability in days | #3/#4/#6 |
| Plan fields abbreviated | Seven unique blocks, total equals target, profile-local date | Daily Plan follow-up |
| Review unique key unscoped | User + client event; replay original result; reject changed payload | #3/#4 |
| Polymorphic item reference unchecked | Trigger or typed FKs; validate curriculum and event owner | #3 |
| Profiles/messages lack user_id | Profiles use id; messages inherit session ownership | #3/#7 |
| Owner tables appeared freely mutable | Owner isolation plus validated writes for derived state/events | #3 |
| Conversation operations were arrows only | Typed payloads, session ownership, scoped retry receipts | #7 |
| MASTERED had no scheduling rule | Reserved enum; first scheduler does not emit it | #4 |
| Examples had no executable checks | 37 named definitions, 20 fixtures and regression validation | This baseline |

## Dependency and merge order

READY titles do not prove prerequisites. One worker resumes its current PR first.

| Issue | Prerequisite | Deliverable | Order |
| --- | --- | --- | --- |
| #1 Lead | Setup #9 merged | Frozen contracts/consistent docs | First |
| #2 Flutter | #1 | Web shell, routing, typed interfaces, smoke test | After #1 |
| #3 Backend | #1 | Migrations, RLS tests, atomic review boundary | Worker picks after #2 |
| #4 Learning | #1 and Dart package from #2 | Pure-Dart scheduler/tests | After #2; RPC hookup needs #3 |
| #5 Content | #1 and #3 content storage mapping | Validated original N5 seed | After #3 |
| #6 Kanji | #2 and reference-data contract | Capture/normalization/scoring | After #2/#5 baseline |
| #7 AI | #3 and app interfaces from #2 | Typed provider adapter, validation/retry/auth | After #3 |
| #8 QA | First implementation PR | Reproducible feature/security matrix | Start with #2; expand each feature |

Independent pure models can continue while external credentials block another task. Follow-up issues must cover Daily Plan/UI, N4 content, quiz/mastery/weak points, offline/sync and live voice before Personal Alpha is complete.

## Validation and compatibility

The repo-sanity job runs schema/fixture checks and regression tests. Tests cover formats, bounds, contradictory correctness, unknown ownership fields, plan totals/uniqueness, stroke normalization/timing, malformed AI output and non-finite JSON. Auth/RLS/provider integration require separate backend tests.

The root schema is a definition library; validate a named $defs model and enable format assertions. Specification: https://json-schema.org/draft/2020-12/json-schema-validation.

This delivers no Flutter app, deployed SQL/RLS, SRS algorithm, real scoring or live AI. Next is #2. Future optional fields need a reviewed versioned schema update and fixtures; removals/renames or enum-meaning changes need a new contract version and adapter migration. Do not silently change frozen payloads in a feature branch.
