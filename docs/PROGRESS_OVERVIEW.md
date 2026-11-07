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

## Verification boundary

Progress overview widget tests use TEST ONLY Auth/RPC gateways. Exact-head
GitHub Actions must run Flutter format/analyze/tests and Web/Windows builds.
These tests do not establish hosted JWT, RLS, learner, expiry/restart or
multi-device acceptance. The default app runtime remains unconfigured.
