# Hosted Supabase staging acceptance

This opt-in probe targets an isolated non-production Supabase project. It is
manual-only and never runs on pull requests, pushes or the default preview.

## Protected environment setup

After this workflow reaches the repository default branch:

1. Create a GitHub Actions environment named supabase-staging.
2. Add these six environment secrets:
   - ND_STAGING_SUPABASE_URL: exactly https://<project-ref>.supabase.co.
   - ND_STAGING_SUPABASE_PUBLISHABLE_KEY: sb_publishable_... or a legacy anon
     JWT whose role claim is anon.
   - ND_STAGING_USER_A_EMAIL and ND_STAGING_USER_A_PASSWORD.
   - ND_STAGING_USER_B_EMAIL and ND_STAGING_USER_B_PASSWORD.
3. Pre-provision two distinct, email-confirmed test users in that non-production
   project. The probe never signs up or deletes users. ensure_profile may create
   a missing own profile but does not change profile settings.
4. Apply the reviewed submit_review migration and ensure at least one active N5
   vocabulary row exists. The probe reads this row; it never seeds, inserts,
   updates or deletes curriculum content.
5. Add environment reviewers/branch restrictions if separate human approval is
   required before staging secrets are released to the job.

Dispatch .github/workflows/hosted-supabase-acceptance.yml manually and set
confirm_non_production=true. A false confirmation starts no job. The workflow
uses only the supabase-staging environment secrets and never uses a service-role
key or JWT signing secret.


When using **Actions → Hosted Supabase Acceptance → Run workflow**, select
`automation/issue-22-atomic-review` in the branch/ref selector. The workflow file
must first exist on the default branch, but the job explicitly checks out the
selected `github.ref`; selecting `main` would test main's source, not the still-draft
PR #37 candidate. Keep `confirm_non_production` false until the protected staging
environment, two disposable accounts and reviewed migration/content prerequisites
are ready.

## Assertions

- Password login returns two distinct Auth user IDs.
- Each refresh rotates its refresh token without changing the captured identity.
- ensure_profile({}) returns exactly the caller-owned profile contract.
- Each user reads its own profile; cross-owner profile queries return no rows.
- An unauthenticated profile query is denied.
- User A is opened in two independent Auth sessions. Logging out the current A
  session with `scope=local` revokes only that session's rotated refresh token;
  A's second session and B's independent session must still refresh and read
  only their own profile. A global/default logout would incorrectly invalidate
  A's second session and fail this acceptance.
- A cannot update B's allowlisted `preferred_jlpt` setting, and B cannot update
  A's; each target user's own read must remain unchanged.
- Each test user can update only its own `preferred_jlpt`, and repeating
  `ensure_profile({})` must preserve that existing value. The probe restores
  the original preference in a finally path before finishing.
- The probe also submits one fresh submit_review event for each dedicated test
  account against the same existing active N5 vocabulary row. It verifies exact
  original replay, changed-payload SYNC_CONFLICT, one counter increment and
  owner-only user_learning_items / review_events visibility. An unauthenticated
  RPC call must be denied. These two review events are intentionally retained;
  use disposable staging accounts, and do not use real learner accounts.

The HTTP client is pinned to a validated *.supabase.co origin, rejects redirects,
bounds response bodies and never prints request/response bodies, emails,
passwords, access tokens or refresh tokens. The legacy anon JWT role check is a
local guard only; Supabase verifies the actual key on the server.

## Evidence limits

The Python probe is hosted GoTrue/PostgREST/Auth/RLS API evidence using two
pre-provisioned test accounts, including the real authenticated submit_review
RPC and owner-isolated review/event reads. It requires an already migrated staging
project with at least one active N5 vocabulary row; it never changes shared content.
Each run appends one review event per dedicated staging account and does not delete
those rows. The same manual workflow also builds and runs
an actual Windows runtime fixture; that adds Credential Manager process-restore
evidence only when the Windows job itself passes. Neither path proves a
cryptographically expired JWT, physical multi-device offline sync or the
complete learner journey. Those remain separate #20/#15/#18 acceptance work. Existing SDK/Windows/SQL/local
Supabase CI remains component evidence only.

Do not mark QA case auth-live complete until both the hosted API probe and the
Windows runtime process-restore phases succeed against the approved
non-production environment. Record exact run, head SHA, environment and
redacted result in docs/PROJECT_STATUS.md.


The profile-settings portion temporarily changes only the two pre-provisioned
staging users' `preferred_jlpt` value to N4, verifies that repeated caller-bound
bootstrap does not reset it, then restores the original N5 default. No other
profile setting is written. The review-RPC portion appends one event per test
account and intentionally does not delete review data. Use disposable staging
accounts; do not point this workflow at production or real learner accounts.

## CI guard for the protected staging boundary

The existing repo-sanity step `Verify hosted Supabase probe safety and behavior` also runs static workflow regressions. They require a manual-only `workflow_dispatch`, a required boolean confirmation defaulting to false, a job condition tied to that confirmation, the `supabase-staging` environment, read-only `contents` permission, non-cancelling concurrency, and exactly the six documented staging secrets. The workflow is constrained to checkout, Python setup, pinned Flutter setup and the reviewed probe/build/PowerShell commands. Only the Python probe and Windows runtime steps receive the six secrets; the Flutter setup and build steps do not. These checks protect the workflow definition; they do not prove that environment reviewers, secrets or the two pre-provisioned accounts exist, and they are not hosted learner evidence.


## Windows hosted runtime process restore

After the Python A/B probe succeeds, the same protected job builds the alternate
tool/windows_hosted_runtime_fixture.dart entrypoint and executes
tool/verify_windows_hosted_runtime.ps1 on GitHub-hosted windows-2022. The
fixture uses the production PersistentSupabaseRuntime, pinned Supabase SDK,
real Windows Credential Manager MethodChannel and real hosted GoTrue/PostgREST.
It does not use MockClient, unsigned JWTs or TEST ONLY Auth responses.

The PowerShell driver starts a fresh Windows process for each phase:

1. login-a: empty vault, password-login User A, wait for the captured
   own-profile barrier, then cleanly close while preserving the refresh token.
2. restore-a: a new process restores A through the saved refresh token and
   waits for A's own profile before closing again.
3. logout-a: a new process restores A, performs the SDK's local logout and
   verifies the exact project credential slot is empty.
4. login-b: a new process starts signed out, authenticates User B, verifies
   B's own-profile barrier, then logs out and verifies the slot is empty.
5. cleanup: clear only this project's credential target before and after the
   sequence, including the failure path.

The fixture validates the configured origin as an exact *.supabase.co HTTPS
origin and validates the public key. It reads the six documented values only
from the protected job-step environment; credentials are not command-line
arguments, printed, or uploaded as artifacts. The review store is an empty
in-memory fixture: no review event is created, queued or submitted. Profile
provisioning uses the existing ensure_profile({}) contract and may create a
missing profile for either pre-provisioned test user; it does not update learner
preferences or delete accounts.

Runner boundary: the script clears the project-scoped Credential Manager
target for the current Windows OS user. It must run only on the ephemeral
GitHub-hosted windows-2022 runner, never on a self-hosted/shared machine. The
workflow pins that runner and requires the protected supabase-staging
environment plus confirm_non_production=true.

This adds hosted Windows process-restart and account-switch evidence when the
manual workflow actually passes. It does not force access-token expiry, test
Windows logoff/power-loss, run the learner GUI or prove physical multi-device
offline sync. The API probe separately verifies refresh-token rotation and
deployed A/B RLS. Until the workflow is dispatched and its complete latest
attempt is observed, all hosted learner QA cases remain pending.


## Windows harness failure and cleanup reporting

The PowerShell driver records only the fixed phase identifier when a child process fails. Once the executable is resolved and the phase sequence starts, a final exact-project Credential Manager cleanup is attempted in `finally`, even after a failed login, restore or logout phase. If the primary phase and cleanup both fail, the reported message names the failed phase and says cleanup could not be verified; if only cleanup fails, a fixed cleanup error is returned. Raw PowerShell error records, environment values and credential material are never echoed. The 90-second child-process timeout requests termination of the entire child process tree. The driver refreshes process state before killing to tolerate a child that exits at the timeout boundary, then waits at most 15 seconds for the phase process to exit. A failed kill or unverified exit becomes a fixed phase failure; it never falls back to an unbounded wait. The caller still attempts final exact-project Credential Manager cleanup in `finally`.

Offline repo-sanity regressions protect the exact fresh-process phase order, 90-second timeout, process-tree kill, natural-exit race, bounded 15-second reap, unconditional final cleanup and redacted primary/cleanup failure reporting. These static tests protect the harness definition; they do not substitute for dispatching the protected staging workflow.


## Hosted staging probe session cleanup

The manual Python probe tracks the current access token for each of its three
pre-provisioned sessions as refresh rotates. The explicitly tested User A local
logout remains separate so the probe can prove that A's second session and User B
remain usable. After the normal flow, or after any probe failure, a finally path
attempts local-only logout for every still-owned session in reverse creation
order. It never uses global logout, creates/deletes accounts, or deletes profiles
or review events. If cleanup fails after a successful probe, the workflow fails;
if a primary probe assertion already failed, that failure is preserved and a
fixed redacted cleanup warning is appended. Offline regressions cover both
failure-path cleanup and preservation of the original failure. This does not
replace hosted execution or the protected environment review.


## Refresh identity mismatch cleanup

After a refresh response has been shape-validated, the probe transfers cleanup ownership to the returned session before checking that the user identity is unchanged or that the refresh token rotated. This ordering matters because the server may already have consumed the previous refresh token. If the response unexpectedly identifies another user, the primary identity failure remains fixed/redacted, while the finally path locally logs out the returned session and every other still-owned session. The offline regression forces this case and requires all refresh sessions to be revoked; it does not simulate a hosted provider incident or replace the protected staging run.


## Probe implementation checkpoint — 2026-11-22

The workflow's referenced scripts/hosted_supabase_probe.py is now present.
It uses only the six protected environment values above, accepts an exact
https://<project-ref>.supabase.co origin and a publishable key or legacy anon
JWT, rejects redirects, bounds responses, and emits fixed redacted failures.
It verifies two independent A sessions plus B, refresh-token rotation, local
logout isolation, own/cross-owner profile reads and allowlisted preference
updates with restoration in a finally path. It also exercises the real
authenticated submit_review RPC with one shared event UUID across A and B,
exact replay, changed-payload conflict, one counter increment, owner-only
learning/review reads and unauthenticated denial. The two review events are
intentionally retained on the disposable staging accounts.

The new probe has offline protocol/safety regressions in
scripts/test_hosted_supabase_probe.py; repo-sanity runs them without secrets.
These tests do not call Supabase and do not establish hosted acceptance. The
manual workflow has not been dispatched; the protected supabase-staging
environment, six secrets, two disposable accounts, reviewed migration and
active N5 vocabulary row remain prerequisites. Keep confirm_non_production
false until those prerequisites and human environment controls are in place.
