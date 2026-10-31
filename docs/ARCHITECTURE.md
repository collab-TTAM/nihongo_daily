# ARCHITECTURE — Nihongo Daily

## Stack
Frontend: Flutter/Dart, Riverpod, GoRouter, feature-first modules.
Backend: Supabase, PostgreSQL, Auth, RLS, Edge Functions where needed.
AI: Flutter -> authenticated backend/Edge Function -> AI provider. Never place private provider keys in Flutter.
Offline: Drift/SQLite or equivalent cache, isolated sync layer.

## Flutter layout
```text
lib/
  app/           router, theme, bootstrap
  core/          auth, networking, storage, errors
  features/      auth, home, vocabulary, kanji, grammar, srs, quiz, ai_tutor, conversation, progress, settings
  shared/        widgets, models, contracts
```

## Rules
- UI does not call raw database tables directly.
- Shared models/contracts are canonical.
- User learning events should be append-only where practical.
- Server is authoritative for security-sensitive state.
- Major architecture changes require proposal, impact summary, migration plan and Lead review.

## Frozen baseline v0.1

`contracts/v0.1/models.schema.json` defines language-neutral payloads; contract.json binds endpoints/defaults. Dart adapters in #2/#4 and SQL/Edge adapters in #3/#7 preserve fields/enums. API_CONTRACTS specifies transport/semantics; DATABASE_SCHEMA specifies storage/ownership; CONTRACT_BASELINE gives review decisions and dependencies.

Read/mutation flow: UI -> Riverpod application service -> typed repository -> RPC/Edge adapter -> authenticated backend -> RLS/persistence. Clients do not directly overwrite derived SRS/progress. Content adapters combine normalized examples into wire objects. Demo repositories are clearly labeled.

Offline events retain client_event_id and occurred_at; sync resends immutable events, deduplicates receipts and displays SYNC_CONFLICT for stale/conflicting writes. It never overwrites newer state or another user's data. Account changes isolate/clear user caches. Full sync is later integration work, not a baseline implementation.

The opt-in bounded native append journal and write-before-dispatch repository
are specified in DURABLE_REVIEW_JOURNAL.md. They preserve the existing RPC/auth
boundaries and server-authoritative schedule. This is a transient equivalent
local store (no dependencies), not the full SQLite/browser cache/sync layer;
Opt-in UI recovery and lossless native compaction are documented in
STUDY_RECOVERY.md and JOURNAL_COMPACTION.md. Opt-in browser transactions are
specified in BROWSER_REVIEW_STORE.md; the default runtime remains unconfigured.
Secure session storage, terminal retention and hosted acceptance remain pending.

The separate opt-in completed-study report journal and write-before-dispatch/
fresh-plan reconciliation library are documented in DURABLE_STUDY_SESSIONS.md.
It preserves the captured Auth/RPC boundary and does not share the SRS journal
format. Configured Windows ownership, captured service, explicit recovery UI
and parallel Auth/study operation drain before SDK/store close are documented
in OWNED_STUDY_RECOVERY.md. Default preview remains unconfigured.

The additive authenticated server/profile current-day projection, optional captured
read capability and explicit date-fill UI are reviewed in PROFILE_STUDY_DAY.md.
The database timezone catalog owns calendar conversion; no device-date/UTC-offset
guess or client timezone package is introduced. Existing plan/report contracts
and server-authoritative progress remain unchanged.


The #41 router also composes the reviewed public bundled curriculum reader/search
from #39 (CURRICULUM_BROWSER.md). Its provider reads only fixed packaged original
N5/N4 vocabulary/grammar exports, retains IDs/versions, and has no account or learning-write capability.
Public preview-level browsing never changes the authenticated profile or SRS
level. Owned startup/plan/recovery/SRS routes and shutdown ownership remain under
the same existing host; no extra SDK, token writer or persistence owner is added.


The completed-study recorder now has one account-scoped slot shared across the
SRS/vocabulary/grammar core, including frozen events before successful local
staging. SHARED_STUDY_RECORDER.md specifies area guards, exact retry, scoped
interruption and legacy-provider aliasing. SRS and configured vocabulary/grammar
now share StudySessionTimerPanel. Reader readiness requires settled original
content at the authenticated profile's level; the existing durable service alone
stages/submits explicit finished reports. Curriculum asset loading remains public
and has no write capability. See CURRICULUM_STUDY_TIMER.md.


The public Kanji metadata catalog uses fixed packaged N5/N4 exports through a
separate typed read-only repository/provider. Original IDs/versions map catalog
selection to an isolated instance of the existing capture controller; canonical
metadata stroke counts never become reference geometry or grading. Existing
/kanji free capture and all owned resource lifetimes remain. KANJI_CATALOG.md
specifies catalog/practice routes, reset behavior and remaining #16 reference gate.
