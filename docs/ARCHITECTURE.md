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
