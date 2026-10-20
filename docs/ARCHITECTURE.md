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
