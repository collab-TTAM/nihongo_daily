# Progress overview

The global Progress destination opens /overview. It is an entry point for
server-derived study time and the existing separate quiz reports.

## Server study progress

- A ready account/profile and an explicitly installed DailyPlanRepository are
  required. Preview mode never creates a plan or sample completion.
- The learner explicitly chooses the profile-local day using get_study_day
  (when the captured gateway supports it), or enters a validated YYYY-MM-DD
  date. Loading the plan is a separate explicit action.
- Completed/target minutes and seven block statuses come only from the
  get_daily_plan response. The client does not write derived progress, infer a
  local day, or count page-open time.
- Every request is bound to the current repository, owner, profile timezone
  and view generation. A late result from a replaced account cannot publish.
  Errors are fixed Vietnamese messages with manual retry only.

## Quiz reports

Vocabulary and grammar quiz progress remain separate destinations:
- /progress — vocabulary quiz report
- /quiz/grammar/progress — grammar quiz report

Those reports are local owner-bound practice history. They are not study
minutes, certified mastery, the reserved SRS MASTERED state or cross-device
sync. The overview links to them without merging their counters into the
server-owned Daily Plan.

## Local quiz snapshot

The overview also offers an explicit read-only snapshot when owner-bound local
quiz repositories are configured. It reads vocabulary, grammar-primary and
grammar-correction history separately; it never combines the two grammar kinds
or treats quiz answers as Daily Plan minutes, certified mastery, SRS state or
server sync. Opening the page does not read quiz history. A manual load uses the
current account repositories, hides late results after account replacement and
shows a fixed Vietnamese error with an explicit retry. The summary keeps N5 and
N4 totals separate within vocabulary, grammar-primary and grammar-correction.
The snapshot performs no writes or remote submission.

## Server quiz receipt snapshot

When the caller-owned `QuizReportV2HistoryReader` is published by a ready
Auth/profile/runtime, `/overview` offers an explicit read of the first 20
server receipts. The page summary reports the receipt and correct/answer totals
for that page, plus separate N5/N4 counts for vocabulary, grammar-primary and
grammar-correction. These are still first-page counts, not all-time totals. A
separate link opens `/quiz/history` for filters and keyset paging.
The page is never fetched automatically, and the preview/default reader remains
null.

The server snapshot is separate from local device journals and Daily Plan
minutes. It does not derive mastery, SRS state, study credit or weak points.
Errors are redacted and manually retryable. Reader replacement, account change
or late completion cannot publish an old page. Widget fixtures do not prove
that the Edge Function is deployed or that hosted JWT/PostgREST/RLS works.

## Verification boundary

Progress overview widget tests use TEST ONLY Auth/RPC gateways. Exact-head
GitHub Actions must run Flutter format/analyze/tests and Web/Windows builds.
These tests do not establish hosted JWT, RLS, learner, expiry/restart or
multi-device acceptance. The default app runtime remains unconfigured.
