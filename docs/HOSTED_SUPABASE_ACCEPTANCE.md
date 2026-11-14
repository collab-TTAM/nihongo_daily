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
4. Add environment reviewers/branch restrictions if separate human approval is
   required before staging secrets are released to the job.

Dispatch .github/workflows/hosted-supabase-acceptance.yml manually and set
confirm_non_production=true. A false confirmation starts no job. The workflow
uses only the supabase-staging environment secrets and never uses a service-role
key or JWT signing secret.

## Assertions

- Password login returns two distinct Auth user IDs.
- Each refresh rotates its refresh token without changing the captured identity.
- ensure_profile({}) returns exactly the caller-owned profile contract.
- Each user reads its own profile; cross-owner profile queries return no rows.
- An unauthenticated profile query is denied.
- Logging out A revokes A's rotated refresh token while B remains usable and
  cannot read A's profile.
- A cannot update B's allowlisted `preferred_jlpt` setting, and B cannot update
  A's; each target user's own read must remain unchanged.
- Each test user can update only its own `preferred_jlpt`, and repeating
  `ensure_profile({})` must preserve that existing value. The probe restores
  the original preference in a finally path before finishing.

The HTTP client is pinned to a validated *.supabase.co origin, rejects redirects,
bounds response bodies and never prints request/response bodies, emails,
passwords, access tokens or refresh tokens. The legacy anon JWT role check is a
local guard only; Supabase verifies the actual key on the server.

## Evidence limits

This is hosted GoTrue/PostgREST/Auth/RLS API evidence using two pre-provisioned
test accounts. It does not prove the Flutter Windows Credential Manager bridge,
Flutter startup/restart on a learner device, a cryptographically expired JWT,
physical multi-device offline sync or the complete learner journey. Those
remain separate #20/#15/#18 acceptance work. Existing SDK/Windows/SQL/local
Supabase CI remains component evidence only.

Do not mark QA case auth-live complete until this workflow succeeds against the
approved non-production environment and the remaining Flutter startup/restart
acceptance has been observed. Record exact run, head SHA, environment and
redacted result in docs/PROJECT_STATUS.md.


The probe temporarily changes only the two pre-provisioned staging users'
`preferred_jlpt` value to N4, verifies that repeated caller-bound bootstrap
does not reset it, then restores the original N5 default and verifies the
restoration. No other profile setting is written. Do not point this workflow at
production or real learner accounts.

## CI guard for the protected staging boundary

The existing repo-sanity step `Verify hosted Supabase probe safety and behavior` also runs static workflow regressions. They require a manual-only `workflow_dispatch`, a required boolean confirmation defaulting to false, a job condition tied to that confirmation, the `supabase-staging` environment, read-only `contents` permission, non-cancelling concurrency, and exactly the six documented staging secrets. The workflow is constrained to checkout, Python setup and the hosted probe command. These checks protect the workflow definition; they do not prove that environment reviewers, secrets or the two pre-provisioned accounts exist, and they are not hosted learner evidence.
