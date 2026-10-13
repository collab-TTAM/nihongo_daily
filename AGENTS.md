# Nihongo Daily worker instructions

Repository: `collab-TTAM/nihongo_daily`. GitHub is the durable source of truth; do not depend on files left in a previous scheduled run.

Read README, `project_manifest.json`, all applicable `docs/`, and `docs/SINGLE_ACCOUNT_AUTOMATION.md` before changes. Use Flutter/Dart/Riverpod/GoRouter and Supabase as specified. Follow the matching `prompts/auto/AUTO_*.md` for each issue.

Use one worker at a time. Resume an existing automation PR before starting another. No parallel agents are required for this workflow. Branches use `automation/issue-N-short-name`; use PRs into main and keep changes scoped to one issue.

Implement, verify, persist to GitHub, and record the next task before ending a run. Never claim tests, builds, deployment, or completion without observed evidence. Local files and credentials are not durable across scheduled web runs.

Routine development PRs may be integrated according to `prompts/auto/AUTO_LEAD.md` after a separate review pass and passing relevant checks for their current head commit. Respect repository rules and user review requests. Never force-push shared branches or weaken tests/security to obtain green CI. A skipped required job is not a passing test.

Human gates remain those in `docs/AUTOMATION.md`. Missing credentials do not block pure models, UI with explicit demo data, local migrations, fixtures, or tests. Report the missing integration clearly and continue independent work.

Write updates in Vietnamese. Store progress in issue/PR bodies and `docs/PROJECT_STATUS.md`; avoid repetitive comments or notifications when nothing changed.
