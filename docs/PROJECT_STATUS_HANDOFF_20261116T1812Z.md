# Supplemental Project Status Checkpoint — 2026-11-16T18:12Z

Append-only checkpoint for PR #41. The canonical \`docs/PROJECT_STATUS.md\`
history remains unchanged because its large blob cannot be safely fetched and
replaced through the available GitHub file-content interface.

## Preflight

- Repository: \`collab-TTAM/nihongo_daily\`
- Base main: \`78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c\`
- Branch: \`automation/issue-11-plan-sdk-integration\`
- Parent HEAD: \`406299be2bc908424404950855e3d8628b1db885\`
- PR #41 was RELEASED at its prior checkpoint; exact-head Actions
  [43917384998](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43917384998)
  completed SUCCESS on the parent HEAD: database, ai-boundary, repo-sanity,
  Windows and Flutter; all returned steps succeeded.
- PR #37 remains open/Draft at
  \`b6ff2fbc1243dc39cb66f7377a9c659c6c5f8857\`; exact-head Actions
  [43900159957](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43900159957)
  completed SUCCESS across all six jobs and every returned step. Hosted
  non-production A/B and Windows process-restore evidence remain blocked on
  protected staging configuration/accounts and an approved manual dispatch.
  No secrets were read and no staging workflow was dispatched.
- Pro-owned PR #38 / Issue #14 / N4 content remains excluded.

## Delivered source increment

- \`apps/flutter_app/lib/features/quiz/presentation/quiz_history_screen.dart\`
  now adds an opt-in read-only server receipt section when the existing
  caller-owned \`QuizReportV2HistoryReader\` is available from a ready account.
- Filters: all/N5/N4 and all/vocabulary/grammar.
- Pagination: 20 entries per page with server-issued keyset cursors, older/newer
  navigation and explicit refresh.
- UI: loading, safe redacted error, empty state, server receipt time and
  original validated answer count; local-device history remains separate.
- A request revision and captured reader identity discard a late page when the
  caller replaces the reader. No default-preview transport was added.

## Regression coverage

New \`apps/flutter_app/test/features/quiz/quiz_report_v2_history_widget_test.dart\`
covers:
- N5/N4 and vocabulary/grammar filter payloads and cursor reset;
- keyset pagination in both directions;
- fixed redacted error and explicit retry/empty state;
- late response discard after reader replacement and replacement-reader success.

No attempt write, automatic retry, mastery/weak-point, SRS, study-minute or
credit mutation; no Auth strategy/provider, SQL, migration, grant, RLS, AI
spend, deployment, production or Pro-owned content change.

## Verification at handoff

- The authoring runtime has no Flutter/Dart SDK, so no local Flutter format,
  analyze, widget test or build is claimed.
- Parent exact-head CI is historical evidence only. A new exact-head GitHub
  Actions run is required for this increment.
- The complete parent recursive tree was read without truncation (987 entries).
  The tree write must preserve all unrelated paths/modes/blob SHAs and use the
  exact parent tree SHA; branch publication must compare the expected parent
  SHA with \`force=false\`.

## Next action

Inspect every job and step in the latest attempt for the new exact HEAD.
Fix only observed failures; if all checks pass, continue the next unblocked
quiz/progress integration. Hosted Edge/Auth/PostgREST/RLS, A/B learner,
mastery/weak-point and complete Personal Alpha evidence remain outstanding.
