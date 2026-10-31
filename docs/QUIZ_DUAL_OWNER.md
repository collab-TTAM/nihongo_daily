# Quiz histories under one caller-owned runtime

## Acceptance audit (Issue #13, 2026-10-31 UTC)

Issue #13 requires deterministic scoring, immutable attempts/deduplication,
user-owned derivations, existing-item weak points, Vietnamese feedback and an
integrated dashboard. The vocabulary and grammar components implement these
bounded local-report behaviors. Current-content question coverage is not mastery;
no reviewed mastery threshold or mastered-item projection is delivered. No quiz
result grants study minutes, attention, server credit or the reserved MASTERED
scheduling state. This issue stays open.

The two existing native widget journeys each enabled only one borrowed quiz
store. They proved the opposite destination unavailable, but did not prove both
stores working under the same ready SDK/owner. The independent integration gap
addressed here is co-enabled store ownership and dashboard isolation. This adds
TEST ONLY composition, not an app-default capability or hosted persistence.

## New executable journey

`apps/flutter_app/test/features/quiz/dual_quiz_disk_journey_widget_test.dart`
opens real review, vocabulary and grammar native journals in one disposable
directory. One PersistentSupabaseRuntime borrows both quiz stores; one
WindowsStagingOwner owns both journals through actual shutdown. The SDK, account
readiness/profile barrier, bundled N5 providers, application router, quiz panels,
UUID capture and native append/read implementations are used without provider,
content, router or capture overrides.

- Actual vocabulary UI answers produce 9/10; explicit save appends only the
  vocabulary journal. Actual grammar UI answers produce PRIMARY 8/10; its explicit
  save appends only grammar and preserves the exact vocabulary bytes.
- Actual dashboard buttons move between both configured destinations. Each starts
  without a summary or automatic read; explicit native reads show separate 9/10
  with one vocabulary weak point versus 8/10 with two grammar weak points. Read
  counters verify no cross-store or navigation-triggered I/O; no extra HTTP.
- SDK logout/login A -> B -> A clears visible summaries. Both B histories are
  empty; explicit reads recover A's separate results without another append.
- Actual owner close releases both journal leases. A fresh owner uses the same
  files/vault and must refresh the SDK session and complete own-profile readiness.
  Explicit dashboard reads recover both results; exact original DTOs and complete
  bytes match, both B histories remain empty, and neither reopened store appends.

Real asynchronous disk completion is awaited through runAsync and bounded
completion barriers. Wrappers count operations and signal completion; they never
substitute records or saved success. Existing single-store fixtures, assertions,
deadlines and workflow/security checks are unchanged.

Auth HTTP, unsigned JWT and memory credential backend are TEST ONLY. This is not
hosted identity/JWT/RLS, actual Windows Credential Manager, learner, linguistic,
power-loss or multi-device proof. No configuration or secret is solicited.

## Evidence and next boundary

Parent `82dfd7521a206df84c3756d8e50590a9de18c003` passed exact-head
[CI41154492745](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41154492745),
latest attempt1: all five jobs and every returned step SUCCESS, no skips. Raw
Flutter job124398551957 confirms both existing single-store journeys; Windows
job124398218525 confirms grammar factory/evidence and persistent vault/SDK/profile
markers. Parent success does not execute this new journey.

New journey execution/full Flutter analysis/Web/Windows builds require its own
exact-head Actions result. Local verification and the published commit/run are
recorded in PROJECT_STATUS and PR41. All14 hosted release groups remain pending;
Auth/RLS/sync/provider/voice/content/assets and actual learner release gates are
still required for Personal Alpha. Pro-owned content is untouched.
