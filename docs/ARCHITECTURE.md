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
