# PR #37 exact-head CI handoff — 2026-11-26 04:20 UTC

## Source and verification

- Repository: collab-TTAM/nihongo_daily
- Branch: automation/issue-22-atomic-review
- Exact source HEAD: f02fea8927783d6dd96ebaeb25ca75354b47b356
- Base main: 61604bc21da64a0dd94dbb97ba3c4b1d035430a6
- Exact-head GitHub Actions: [run 45748053505](https://github.com/collab-TTAM/nihongo_daily/actions/runs/45748053505), attempt 1, event pull_request, completed success; GitHub head_sha matches the PR head above.
- All six latest-attempt jobs and every returned step were inspected: repo-sanity 14/14, database 12/12, AI boundary 12/12, Windows 18/18, disposable Supabase integration 17/17, Flutter 35/35 — 108/108 returned steps succeeded. No skipped, pending, failed or unpublished job was counted as a pass.

## What this CI run verifies

- Repository/content/contract/QA evidence validation and protected hosted-workflow safety regressions.
- Database migration, grants, RLS, replay, concurrency, profile bootstrap and queue projections on disposable CI services.
- Windows TEST ONLY bridge and actual Windows Credential Manager cross-process checks; native receipt cache, journal compaction, durable review restart and disk-backed recovery; Windows release build.
- Disposable local GoTrue/PostgREST refresh rotation, replay and A/B RLS.
- Pinned Flutter dependency resolution, Dart formatting, analysis, full serial Flutter suite, owned-session/vault/profile readiness probes, browser IndexedDB/Chrome checks, review queue/SRS/Kanji wire checks and Web release build.

These are exact-source CI/component and disposable-local proofs. They are NOT protected hosted learner A/B, deployed staging PostgREST/RLS, cryptographically expired JWT, hosted Windows fresh-process restore, physical two-device offline sync, or end-to-end learner journey evidence.

## Scope and safety

- The last source change remains the Windows native VaultRead copy-then-wipe hardening. It handles source strings before SSO/heap move state can obscure their original length; the TEST ONLY native probe covers short and heap-backed strings, move construction/assignment, destination wipe and oversized Credential Manager blobs.
- The PR currently contains 187 changed paths; no data/n4, data/manifest.json, data/README.md, N4 content tests or N4 editorial documents are in this PR changed-file list. Pro-owned Issue #14 / PR #38 remain untouched.
- No Auth provider/strategy change, default app activation, secret/configuration write, production deployment, merge or release occurred. No tokens or credentials are included in logs or this handoff.
- Cloud authoring runtime does not provide the Windows/Flutter SDK, so no local native build, Dart format/analyze/test or Flutter build is claimed; the exact-head Actions run is the observed verification.

## Remaining acceptance / next action

1. Keep PR #37 Draft. Do not merge or close #20/#22/#15 based on this CI result alone.
2. Complete the protected supabase-staging environment through GitHub settings: six documented staging secrets, two distinct pre-provisioned email-confirmed non-production users, the reviewed migrations and at least one active N5 vocabulary row. Do not paste credentials into chat or commit them.
3. After the protected environment is ready, manually dispatch .github/workflows/hosted-supabase-acceptance.yml with confirm_non_production=true and select automation/issue-22-atomic-review. Inspect the complete latest attempt and record redacted exact-head API A/B plus hosted Windows process-restore evidence.
4. Keep deployed staging/RLS, two-device sync, and complete user-facing learner journey as separate Personal Alpha gates. If the hosted environment is not configured, continue independent app/study work in its existing PR rather than fabricating live proof.

This handoff records CI completion only; it does not declare Issue #20, #22, #15 or Personal Alpha complete.
