# Hosted Supabase workflow handoff — 2026-11-17T15:07Z

Status: implementation persisted; exact-head PR CI and review are the next gates.

## Source and scope

- Branch: `automation/hosted-supabase-acceptance-workflow`
- Base: `main` at `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`
- Source commits: `9bc7518c1ed4365d818e6b05dc58bb23b815b2f0` (workflow, CI guard and operator guide); `8d37ae48bb76e3fc21c96db11db7cc8f83248dd7` (corrected static trigger-scope assertion).
- Paths: `.github/workflows/hosted-supabase-acceptance.yml`, `.github/workflows/ci.yml`, `scripts/test_hosted_workflow.py`, `docs/HOSTED_SUPABASE_ACCEPTANCE.md`.
- The workflow is manual-only, requires `confirm_non_production=true` (default false), runs in protected `supabase-staging` on ephemeral `windows-2022`, requests only `contents: read`, does not cancel a running acceptance job, and references exactly six documented staging secrets only in the two probe steps.
- Checkout explicitly uses the selected `github.ref`; the operator guide instructs selecting `automation/issue-22-atomic-review` so the candidate PR #37 source is exercised after the workflow definition is on the default branch.

## Validation and review

- Added five standard-library unittest regressions for manual-only dispatch/default-false confirmation, protected environment/job gating, least-privilege permissions/non-cancelling concurrency, selected-ref checkout/pinned Windows runner, and exact six-secret step scoping.
- CI invokes `python3 scripts/test_hosted_workflow.py` in repo-sanity.
- Full main tree was read untruncated before writing (185 entries); after the initial workflow increment it was 188 entries, with no removed/unexpected paths or mode/type changes, 129 unchanged original blobs, and only the existing CI blob changed. The follow-up test correction preserved the same 188-entry tree, no removed/added paths or mode/type changes, one expected test blob change, and all 132 other blobs unchanged. All branch updates used the exact parent tree SHA and expected branch SHA with `force=false`.
- The cloud authoring runtime does not provide a Git checkout/CI runner; the exact-head GitHub Actions result is the authoritative formatter/test/build evidence. No local test result is claimed in this checkpoint.

## Limits and next action

- No workflow dispatch occurred. No protected environment, secrets, or staging users were read, created, or changed. No real hosted Auth/PostgREST/RLS or Windows Credential Manager learner result is claimed.
- PR #37 remains Draft and its component CI is not hosted learner acceptance. The hosted environment still needs an owner to create `supabase-staging`, configure the six secrets, pre-provision two disposable email-confirmed users, and ensure the reviewed `submit_review` migration plus one active N5 vocabulary row exist.
- Next: open a separate PR to main, review the four-file diff, inspect every latest-attempt job and step on its exact head, and integrate only after all required checks pass. Then an authorized owner can dispatch the workflow on `automation/issue-22-atomic-review` with confirmation true. Keep #20/#22/#15 and all hosted Personal Alpha gates open until actual evidence is recorded.
- No Auth strategy/provider, production schema/RLS, default runtime activation, production deployment, Pro-owned #14/#38/N4 content, or production data was changed.
