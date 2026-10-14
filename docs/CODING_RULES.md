# CODING RULES

- Prefer readable, modular code.
- No secrets in source.
- No direct feature work on main; use branches and PRs.
- Flutter: Riverpod, GoRouter, feature-first; UI -> application -> domain -> repository.
- Backend: append-only migrations, RLS on all user-owned tables, least privilege.
- AI: private keys only in trusted backend; structured outputs validated before persistence.
- Critical logic requires tests: SRS, Daily Plan, mastery, weak-point detection, Kanji normalization/scoring, AI response validation, auth/RLS boundaries.
- Logs must not contain passwords, auth tokens, refresh tokens or provider keys.
- Shared API/database contract changes require docs update and Lead review.
