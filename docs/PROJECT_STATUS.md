## PR #37 caller-close retry after uncertain Windows refresh rotation — 2026-11-12T16:14Z

- Run `core-20261112T1614Z-pr37-close-uncertain-rotation-clear` is RELEASED after persistence. Branch `automation/issue-22-atomic-review`; parent `730aec01ce534de57c6958b7a9417625feb0cb22`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Parent exact-head Actions [43235211522](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43235211522) completed SUCCESS on this exact parent: all 6/6 jobs and 101/101 returned steps succeeded (repo-sanity, database, AI boundary, disposable Supabase integration, Windows and Flutter). This is parent evidence only; the new head requires its own run.
- Added one TEST ONLY pinned-Supabase-SDK + production Dart Windows MethodChannel regression. A's refresh write commits the synthetic rotated secret but loses its acknowledgement; compensating clear and first caller-close clear fail. The caller stays fenced, retains the Dart/native owner and rejects a competing runtime. After storage recovers, a second explicit close clears the uncertain secret before releasing the owner.
- Changed exactly four paths: `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, `qa/matrix.json` (one anchor in the existing persistent-session-lifecycle case; case count unchanged), and `docs/PROJECT_STATUS.md`. No production Auth/provider, API/schema/RLS/migration, default activation, Pro-owned N4, deployment, merge or release change.
- Separate post-write review is required: complete recursive tree/path/mode/type comparison, exact changed-blob readback, and parent diff. Cloud runtime lacks the pinned Dart/Flutter SDK; local format/analyze/test/build were not run. Hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted expiry/restart and physical two-device proof remain outstanding.
- Next: inspect every latest-attempt job and step on the new exact HEAD; fix only observed failures. Keep PR #37 Draft and #20/#22/#15 open until their hosted/learner acceptance is observed.

---

## PR #37 pinned Dart formatter correction — 2026-11-12T13:25Z

- Run `core-20261112T1324Z-pr37-dart-format-account-fixtures` is RELEASED. Branch `automation/issue-22-atomic-review`; parent HEAD `46a671519d5fc8030336e981441ef37c85cbfc24`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head Actions [43216038187](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43216038187), attempt 1, targets the parent HEAD and completed FAILURE only at strict pinned Dart 3.35.4 formatting: `apps/flutter_app/test/features/srs/account_fixtures.dart` was the single changed file. Repository sanity 12/12, database 12/12, AI boundary 12/12, Windows 17/17 and disposable Supabase integration 13/13 all succeeded. Flutter analyze, tests and downstream probes were SKIPPED, not passes.
- Applied only the formatter-required multiline layout to the TEST ONLY `check(access.signInCalls == 0, ...)` assertion in `apps/flutter_app/test/features/srs/account_fixtures.dart`; no assertion, scenario, production behavior or security boundary changed.
- Changed paths: this test fixture and `docs/PROJECT_STATUS.md`. Full parent tree was read recursively without truncation (335 entries: 270 blobs, 65 trees); all unrelated paths/modes/types and untouched blob SHAs are preserved. The new exact-head Actions run is the verification gate; no new-head format/analyze/test/build pass is claimed yet.
- Cloud authoring runtime has no pinned Dart/Flutter SDK, so local formatter/analyzer/test/build were not run. Hosted signed-JWT learner A/B, deployed PostgREST/RLS, real learner expiry/restart and physical two-device sync remain unproven. PR #37 stays Draft; #20/#22/#15 remain open. Pro-owned #14/#38/N4 scope remains excluded.
- Next: inspect every latest-attempt job/step for the new exact HEAD; fix only observed failures, then continue #20/#22/#15 acceptance without changing Auth strategy/provider, schema/RLS, default activation, deployment or release gates.

---

## PR #37 explicit logout drain barrier — 2026-11-12T12:13:44.381Z

- Run `core-20261112T121142Z-pr37-logout-drain`; branch `automation/issue-22-atomic-review`; parent HEAD `cbfa09e7712182147e289b953c4316e98e24f861`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Parent exact-head Actions [43208386909](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43208386909) completed SUCCESS on `cbfa09e7712182147e289b953c4316e98e24f861`: all six jobs and every returned step succeeded (database 12, repo-sanity 12, AI boundary 12, disposable Supabase integration 13, Windows 17, Flutter 35). This is parent evidence only.
- Change: successful explicit logout keeps the session gate revoked while a cancelled restore/login/refresh drains; it waits for the in-flight operation, final serialized vault work and any required cleanup retry before resolving. This prevents the account screen from offering a replacement login while a late SDK response can still arrive.
- TEST ONLY coverage: held restore/login/refresh responses, blocked replacement login, delayed final SDK cleanup, and account-controller signing-out UI/readiness. Paths: `persistent_account_access.dart`, `session_lifecycle_fixtures.dart`, `account_fixtures.dart`, `PERSISTENT_SESSION_LIFECYCLE.md`, `qa/matrix.json`, this status file.
- Cloud authoring runtime has no pinned Flutter/Dart SDK; local format/analyze/test/build are not run. New exact-head Actions is the verification gate; no new-head pass is claimed yet.
- Limits: in-memory fixtures are not hosted signed-JWT learner A/B, deployed PostgREST/RLS, or native delayed Credential Manager proof. #20/#22/#15 remain open; PR #37 remains Draft. Pro-owned #14/#38/N4 files are excluded. No Auth strategy/provider, API/schema/RLS, default activation, deployment, merge or release change.
- Next: inspect every latest-attempt job and required step on the new exact HEAD. Fix only observed failures; if only CI is pending, release the worker with a durable handoff.

---

## PR #37 replacement-login cleanup gate — 2026-11-12T11:14Z

- Branch: `automation/issue-22-atomic-review`; parent HEAD: `4abbef96711539fc73fc7045456964b1a3ce1974`; base main: `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Resumed the released PR #37 core lane after re-reading latest main, README, project manifest, worker/security/API/database docs, open PRs/issues and exact-head CI. PR #41's worker was RELEASED at 10:56Z; exact HEAD `722ab0abfaf77d53a18e27ebeb32e71d4c70e951` passed [CI 43204739982](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43204739982): all 5 jobs and 114/114 steps succeeded.
- Exact PR #37 HEAD `4abbef96711539fc73fc7045456964b1a3ce1974` failed [CI 43200170868](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43200170868). Repo sanity, AI boundary, database, Windows and disposable Supabase integration succeeded. Flutter format/analyze passed, but the complete suite failed at `replacement-login-waits-for-out-of-band-session-clear` with a 30-second timeout. The later lifecycle cases cascaded after the held-clear assertion path stranded the shared target owner; subsequent constructors reported a safe unavailable owner collision. All later Flutter lifecycle/native/browser/SRS/Web steps were skipped, not passed.
- Root cause: `signIn` rejected whenever `currentSession != null`, before it could reserve the owned operation and use the already-captured `needsCleanup` predicate. This prevented the explicit account-switch path from draining an out-of-band null-session clear that was queued immediately after preflight.
- Change in this commit: allow explicit replacement sign-in while a session is visible; the captured current SDK session forces ordered sign-out and exact-project vault clear before password grant. The TEST ONLY fixture now releases its held clear and drains its operation in `finally`, so an earlier assertion cannot strand the shared owner or obscure the first failure with cascading timeouts.
- Changed paths: `apps/flutter_app/lib/features/auth/data/persistent_account_access.dart`; `apps/flutter_app/test/features/srs/session_lifecycle_fixtures.dart`; `docs/PERSISTENT_SESSION_LIFECYCLE.md`; this status file. Existing QA lifecycle anchor/case count remains unchanged; no assertion was removed.
- Cloud authoring runtime has no pinned Dart/Flutter SDK; local format/analyze/test/build were not run. The exact-head GitHub Actions run after this commit is the verification gate. No pass is claimed until every latest-attempt job and required step succeeds with no skips/pending/failures.
- Scope limits: TEST ONLY in-memory SDK/vault fixture; this is not hosted signed-JWT learner A/B, deployed PostgREST/RLS, or native Windows Credential Manager failure injection. No Auth provider/strategy, API/schema/RLS/migration, default activation, plaintext fallback/token logging, Pro-owned #14/#38/N4/data/manifest/content-test/docs, deployment, merge or release change.
- Next: inspect all exact-head CI jobs/steps for the new commit. If green, continue remaining #20/#22 caller-owned lifecycle and authenticated review acceptance; hosted staging A/B and #15 sync remain external release gates. Keep PR Draft until full acceptance.

## Windows ambiguous refresh-write acknowledgement and cleanup retry — 2026-11-12T06:13Z

- Branch: `automation/issue-22-atomic-review`; parent HEAD: `477f6919316f5df598715c97c68d2a924de00c02`; base main: `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Added a TEST ONLY regression in `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart` using the pinned Supabase SDK and production Dart Windows MethodChannel vault adapter. The channel commits A's rotated refresh secret, then returns a redacted platform failure; the compensating clear also fails. The runtime must remain failed/unready, reject B's password grant/profile, and accept B only after explicit cleanup succeeds, followed by B rotation write before own-profile.
- Added a QA anchor to the existing `persistent-session-lifecycle` case and clarified `docs/PERSISTENT_SESSION_LIFECYCLE.md` that this is mocked MethodChannel runtime evidence. The separate Windows native probe remains the evidence for actual Credential Manager post-CredWrite fault injection. No new QA case count, production Auth/provider, schema/RLS, migration, default activation, or Pro-owned content change.
- Parent exact-head Actions [43160796830](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43160796830) completed SUCCESS on `477f6919316f5df598715c97c68d2a924de00c02`: all 6 jobs and every returned step succeeded, including Flutter format/analyze/full suite, Windows native vault/runtime probes, disposable local Supabase and Web release build. This is parent evidence only.
- Cloud authoring runtime has no pinned Dart/Flutter SDK; local formatter/analyze/test/build were not run. The new source head requires fresh exact-head CI; no test pass is claimed yet.
- Hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted expiry/restart and physical two-device sync remain unverified. PR #37 remains Draft; #20/#22/#15 remain open; Pro-owned #14/#38/N4 scope is untouched.
- Next: inspect every latest-attempt job/step for the new exact HEAD. Fix only observed failures; if only CI remains pending, release the worker with a durable handoff rather than duplicate implementation.

---

## Pinned Dart formatter correction — 2026-11-12T05:14Z

- Branch: `automation/issue-22-atomic-review`; parent HEAD: `c06bec101f235cc98201759b4354835b0937a057`; base main: `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head Actions [43140668303](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43140668303), attempt 1, targets this parent. Database, repo-sanity, AI boundary, disposable Supabase integration and Windows completed SUCCESS; Flutter failed only the strict pinned Dart 3.35.4 formatter. The log names only `apps/flutter_app/lib/features/auth/data/persistent_account_access.dart`; analyze, full Flutter tests and downstream browser/native/Web checks were SKIPPED, not passes.
- Applied only the formatter-required line wrapping of the existing `needsCleanup` boolean expression in `apps/flutter_app/lib/features/auth/data/persistent_account_access.dart`. No control flow, assertions, Auth/session behavior, vault ordering, dependencies, API, schema, RLS or CI gates changed.
- The cloud authoring runtime has no pinned Dart/Flutter SDK; local format/analyze/test/build were not run. The corrected PR head requires fresh complete exact-head Actions evidence.
- Next: inspect every latest-attempt job and critical step on the corrected PR HEAD; record full evidence before any further source change. Hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted expiry/restart and physical two-device sync remain unverified. Keep PR #37 Draft and #20/#22/#15 open. Pro-owned #14/#38/N4 remains untouched.

---

## Windows native owner-acquisition fail-closed regression — 2026-11-09T14:10Z

- Branch `automation/issue-22-atomic-review`; source commit `a338dc5b6fdc9c4a71ba1eddc825583363fa1610` (parent `bbbb706bc621da45a92437a8bd1487db07328dc9`); base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Added a TEST ONLY Windows MethodChannel regression for native owner-lease acquisition returning unavailable. It verifies startup stops before vault read/clear, Auth restore/password grant or own-profile; the stored refresh value remains untouched; safe errors contain no private platform details; caller close releases the local Dart target reservation without releasing a native lease it never acquired; a fresh runtime then reacquires the target and performs refresh -> rotated-token write -> own-profile readiness.
- Changed exactly three paths: `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart` (+77); `docs/WINDOWS_SESSION_VAULT.md` (+19); `qa/matrix.json` (+5/-1). No production implementation, Auth strategy/provider, API/schema/RLS, default activation, N4 Pro scope, deployment or release setting changed.
- Separate post-write diff review: compare from parent reports exactly those three modified blobs and no added/deleted paths. Parent/final recursive trees are complete/untruncated at 335 entries; identical path/mode/type sets, with only those three blob SHAs and their ancestor tree SHAs changed. All three changed blob readbacks match. `create_tree` used exact `base_tree_sha=8fd0859cb90c995d0c11e5450bb0f287bb0936a6`; `update_ref` used `expected_sha=bbbb706bc621da45a92437a8bd1487db07328dc9`, `force=false`; branch readback matched the source commit.
- Parent exact-head Actions [42625204054](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42625204054), attempt 1, passed all six jobs and all 101 returned steps on exact parent `bbbb706bc621da45a92437a8bd1487db07328dc9`. This is parent evidence only; the new source head still requires its own CI.
- Cloud authoring runtime has no Dart/Flutter SDK, so local format/analyze/test/build were not run. No new-head test/CI pass is claimed until Actions is fetched for the final status head. Hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted expiry/restart and physical multi-device proof remain outstanding. Keep PR #37 Draft and #20/#22/#15 open.
- Next: inspect every latest-attempt job and step for the final PR head; fix only observed failures, then continue hosted acceptance through approved non-production configuration. No Pro-owned #14/#38/N4 path was touched.

---

## Exact-head CI correction — 2026-11-07T08:11Z

- Branch `automation/issue-22-atomic-review`; parent HEAD `59f92e5f1a2c300d1ac03a2afb6882a02fd5bdfc`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [42353111771](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42353111771) completed FAILURE only at pinned Dart 3.35.4 formatting in `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`. Database, repository sanity, AI boundary, Windows and disposable local Supabase integration all completed SUCCESS with every returned step successful. Flutter analyze, full tests, browser/native checks and Web build were SKIPPED because format failed; they are not passes.
- Applied the single formatter-required blank line between adjacent test declarations in that TEST ONLY file. No assertions, runtime behavior, Auth/vault logic, schema/RLS, or dependencies changed.
- Cloud authoring runtime has no Dart/Flutter SDK; local format/analyze/test/build were not run. New exact-head Actions is required to verify the correction and all downstream Flutter steps.
- Next: inspect every latest-attempt job and step on the corrected exact HEAD; preserve the Draft and hosted learner/security gates.

---

## Hosted staging acceptance probe — 2026-11-06T21:09Z

- Draft PR #37 / automation/issue-22-atomic-review adds a manual-only hosted Supabase probe for #20/#22. It uses a validated *.supabase.co origin, publishable/anon key and two pre-provisioned non-production accounts from the supabase-staging GitHub environment; it never uses service-role credentials, creates/deletes users, changes profile fields or runs on PR/push.
- Probe coverage: distinct Auth identities, refresh-token rotation, caller-bound ensure_profile, own-profile reads, A/B cross-owner RLS denial, unauthenticated denial, A logout/refresh revocation and B continuity. Offline fake-transport regressions cover positive/negative paths, URL/key restrictions and redacted failures.
- New paths: scripts/hosted_supabase_probe.py, scripts/test_hosted_supabase_probe.py, .github/workflows/hosted-supabase-acceptance.yml and docs/HOSTED_SUPABASE_ACCEPTANCE.md; CI/QA inventory and this status are updated.
- No staging secrets are configured or inspected in this run, so hosted acceptance is not executed. The manual workflow becomes dispatchable after it reaches the default branch. It is API-level evidence only; Flutter Windows vault/startup/restart, signed expired-JWT, physical multi-device sync and learner-journey gates remain pending. Keep #20/#22/#15/#18 and QA auth-live open.
- Exact-head CI is the verification gate; cloud authoring runtime has no Flutter/Dart SDK. No Auth strategy/provider, schema/RLS, production, default-app, Pro N4 or secret changes.

## Core worker handoff — browser IndexedDB formatter correction — 2026-11-04T16:07Z

- Run `core-20261104T1606Z-fix-browser-indexeddb-format`; branch `automation/issue-22-atomic-review`; source commit `18841eb043efdf79eca5b1f7cdcc71fef58263a1` (parent `fd7daee3334ad3410143a0bb240eb1479bb8208b`); base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- The prior exact-head CI [41855665838](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41855665838), attempt 1 on `fd7daee3334ad3410143a0bb240eb1479bb8208b`, completed with five jobs successful (repo-sanity, AI boundary, database, disposable Supabase integration, Windows) and Flutter failed at pinned Dart 3.35.4 format. Formatter identified only `test/features/srs/browser_review_store_check.dart`; Flutter analyze and all downstream Flutter checks were skipped, not passed.
- Applied a whitespace-only correction in that test file: removed the two duplicated consecutive blank-line runs around the delayed-list test fixture and account-switch test. No assertions, runtime behavior, Auth/session/vault, IndexedDB semantics, SQL/RLS, dependencies, CI gates or Pro-owned N4 files changed. Separate commit diff review reports exactly one path, 0 additions / 2 deletions.
- Complete recursive Git tree at source HEAD was fetched untruncated (328 entries: 263 blobs / 65 trees). All paths/modes/types remain; only the target test blob changed. Source tree was built from exact parent tree `1d0f4e9b9ce4eee63119ee3941455526627d0c51`; source ref update used expected head `fd7daee3334ad3410143a0bb240eb1479bb8208b`, force=false; branch readback matched.
- Exact-head CI [41864430976](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41864430976) has been queued for source commit `18841eb043efdf79eca5b1f7cdcc71fef58263a1`; no job result is yet claimed. Cloud runtime has no Flutter/Dart SDK, so local format/analyze/test/build were not run.
- Hosted signed-JWT learner A/B, deployed RLS/PostgREST, hosted session expiry/restart, physical multi-device sync and full learner journey remain unverified. Keep #15/#20/#22 open and PR #37 Draft. PR #41 and Pro-owned PR #38/#14/N4 remain untouched.
- Next: inspect every latest-attempt job/step on exact source head `18841eb043efdf79eca5b1f7cdcc71fef58263a1`; if strict format passes, require analyze, full Flutter suite, browser/native checks, Web/Windows builds and all backend/security jobs before recording final verification.

---

## Core worker handoff — IndexedDB captured-session recovery fence — 2026-11-04T15:12Z

- Run `core-20261104T1507Z-indexeddb-account-switch-recovery-fence`; branch `automation/issue-22-atomic-review`; source commit `bac58582e75c37c0a06f2dc407d42762fdb91fe1` (parent `36f1215d8cbcf2ec88e89bda072fbc189c4708da`), tree `f9f211629793c62faeed194c2fa3c9afe5a161ed`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Changed paths: `apps/flutter_app/test/features/srs/browser_review_store_check.dart`, `docs/BROWSER_REVIEW_STORE.md`, `qa/matrix.json`, and this status handoff. The new actual-Chrome IndexedDB test holds a User A recovery snapshot, switches the captured Auth session to B, then requires safe UNAUTHORIZED, preserves A's pending event, and confirms B's owner projection is empty.
- Exact-head CI [41855397832](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41855397832), attempt 1, targets source commit `bac58582e75c37c0a06f2dc407d42762fdb91fe1`. At the 15:12Z observation repo-sanity, AI boundary and database completed SUCCESS; Windows, disposable Supabase integration and Flutter were IN_PROGRESS. Flutter SDK setup was still running; formatter/analyze/tests/build had not run. No full pass is claimed.
- The previous exact-head CI [41845586766](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41845586766) passed all six jobs/every step on the parent only. Cloud runtime has no Flutter/Dart SDK, so local format/analyze/test/build are not claimed.
- Full recursive source tree was untruncated at 328 entries; four intended blobs changed and all 259 untouched blobs/path/mode/type entries were preserved. The source commit has one parent and compare shows exactly the four intended paths. QA JSON parses successfully.
- This TEST ONLY Auth port plus real browser IndexedDB is not hosted signed-JWT A/B, deployed RLS/PostgREST, physical two-device sync or Personal Alpha evidence. Keep #15/#20/#22 open and PR #37 Draft. Pro-owned #14/#38/N4 content is untouched.
- Next: inspect every latest-attempt job and required step on the final status HEAD; fix only observed failures, then continue hosted acceptance when approved non-production Supabase configuration is available.


---

## Core worker handoff — exact-head CI success and final diff review — 2026-11-04T04:14Z

- Resumed open Draft PR #37 on `automation/issue-22-atomic-review`; source HEAD `15acaede269a67d1b7732b164fac34db0800439b`, base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41765461336](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41765461336), attempt 1, completed SUCCESS on this exact HEAD. All six jobs and every step passed: repo-sanity (11), ai-boundary (12), database (12), supabase-integration (13), Windows (17), Flutter (35). Flutter included pinned Dart format, analyze, full serial suite, owned session/vault/profile checks, Chrome IndexedDB/reload, SRS/review/Kanji wire checks and Web release build. Windows included the native credential vault cross-process probe, configured staging release build, and durable journal/recovery probes. No required job or step was skipped, pending or failed.
- Separate source diff review of `c6dcb7de5d858ba6aa59d549daff374446f869bf`: exactly two formatter-required line wraps in `persistent_supabase_runtime_test.dart` and removal of the temporary read-only formatter diagnostic from `.github/workflows/ci.yml`. Assertions, runtime behavior and CI gates are unchanged. Current status commit `15acaede269a67d1b7732b164fac34db0800439b` changes only `docs/PROJECT_STATUS.md`.
- Complete recursive tree at exact source HEAD was fetched untruncated (327 entries). This handoff changes only the status document. No Dart/Flutter SDK is available in the cloud runtime, so local format/analyze/test/build were not run; exact-head CI is the observed verification.
- Windows SDK/MockClient/native-vault lifecycle probes are TEST ONLY. Hosted non-production Supabase signed-JWT user A/B, deployed RLS/PostgREST, hosted expiry/restart and physical multi-device learner proof remain outstanding. #20/#22/#15 stay open; PR #37 remains Draft and is not merged.
- Pro-owned #14/#38/N4 paths remain untouched. No Auth strategy/provider, production configuration, schema/migration/RLS, dependency, security, AI spend, deployment or release setting changed.
- Next: use approved non-production Supabase staging configuration through supported secret settings to complete hosted #20/#22/#15 evidence. Until then, keep the staging owner opt-in and continue independent app/plan/study work in a later released core turn; do not treat fixture/CI success as hosted learner proof.

---
## Core worker handoff — pinned Dart formatting correction — 2026-11-04T03:10Z

- Run `core-20261104T0307Z-fix-pinned-dart-format`; branch `automation/issue-22-atomic-review`; source commit `c6dcb7de5d858ba6aa59d549daff374446f869bf` (parent `083a9a29567d5fc5e7096ad282c9c5983026110a`); base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Changed source paths: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart` and `.github/workflows/ci.yml`. Applied exactly the two pinned Dart 3.35.4 formatter line-wraps reported by diagnostic CI and removed the temporary read-only formatter diagnostic. No assertions, test behavior, production Auth/session/vault, schema/RLS, dependency, CI gate or Pro-owned N4 content changed.
- Parent exact-head CI [41759416459](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41759416459), attempt 1, had repo-sanity, AI boundary, database/RLS, disposable local Supabase integration and Windows SUCCESS with all returned steps; Flutter strict format FAILED only because these two long reason strings needed wrapping. Flutter analyze, full suite and all downstream Flutter checks were SKIPPED, not passed.
- Separate source diff/tree review: only the two intended blobs changed; complete recursive tree was untruncated at 327 entries (262 blobs / 65 trees), with identical paths/modes/types and all other 325 entries retained. create_tree used exact base tree `958106d49897afc54ddab72d838bd476a66e3737`; source commit parent was the exact prior branch head; update_ref used `expected_sha=083a9a29567d5fc5e7096ad282c9c5983026110a`, `force=false`.
- Cloud runtime has no Dart/Flutter SDK; local format/analyze/test/build were not run. New exact-head CI is the verification gate. No hosted signed-JWT learner A/B, deployed RLS, hosted restart/expiry or physical multi-device evidence is claimed.
- Next: inspect every latest-attempt job and required step for the final status commit; require strict format, analyze, full Flutter suite, lifecycle/vault/profile/wire/Chrome/Web, Windows, disposable Supabase, database, AI boundary and repo-sanity without required skips. Fix only observed failures. Keep PR #37 Draft and #20/#22/#15 open; Pro-owned #14/#38/N4 untouched.

### Exact-head CI observation — 2026-11-04T03:11Z

- GitHub Actions run [41765389109](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41765389109) targets status HEAD `d925acec828b125f37df94da1ccfe637c8aee21a`, attempt 1. At 03:11Z the workflow was PENDING and no jobs had been published; no final-head format/analyze/test/build or full-CI result is claimed. The prior diagnostic run is not a passing substitute.
- Next: inspect the new status-commit run and every latest-attempt job/step before further source edits.

---

## Core worker handoff — account profile barrier formatter — 2026-11-04T00:22Z

- Run `core-20261104T0018Z-format-account-fixture` RELEASED. Branch `automation/issue-22-atomic-review`; formatter source commit `b4beee09d3c5b100620dfdc473ec9854c0042441` (parent `b86b7981ea3a5ab66e17b99681f1220f4bb03567`); status handoff follows source commit `b4beee09d3c5b100620dfdc473ec9854c0042441`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41745469694](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41745469694), attempt 1, on parent `b86b7981ea3a5ab66e17b99681f1220f4bb03567`: repo-sanity, AI boundary, database/RLS, disposable local Supabase integration and Windows all completed SUCCESS with every returned step. Flutter strict format FAILED because Dart 3.35.4 reformatted only `test/features/srs/account_fixtures.dart`; Flutter analyze, full suite and every downstream Flutter check were SKIPPED. This was not a full-CI pass.
- Applied the formatter-only layout to the replacement-profile barrier assertion in `apps/flutter_app/test/features/srs/account_fixtures.dart`: split the long `check(...)` call into the formatter's multiline form. No assertion, expected behavior, controller, production Auth/session/vault, API/schema/RLS, dependency or CI gate changed.
- Source commit changed exactly one blob/path. Full recursive source tree was untruncated at 327 entries (262 blobs / 65 trees); identical path/mode/type sets, one intended blob SHA changed, all other blobs retained. `create_tree` used exact parent tree `80bd7cea657c10a6a6dc0a402c4f24b5774519fa`; `update_ref` used expected SHA `b86b7981ea3a5ab66e17b99681f1220f4bb03567`, `force=false`; branch readback matched source commit.
- Cloud runtime has no Dart/Flutter SDK, so local format/analyze/test/build were not run. New exact-head CI on the final status checkpoint must confirm format, analyze, all Flutter tests, lifecycle/vault/profile/wire/Chrome/Web checks, Windows and Supabase integration. The formatter correction itself is source-only; no final-head CI pass is claimed here.
- Hosted signed-JWT learner A/B, deployed RLS, hosted restart/expiry and physical multi-device sync remain unproven. PR #37 stays Draft; #20/#22/#15 stay open. Pro-owned #14/#38/N4 scope remains untouched.
- Next: inspect every latest-attempt job and step on the final branch head; fix only observed failures. Do not merge or claim Personal Alpha from this formatter-only correction.

---

## Core worker handoff — startup formatter diagnostic — 2026-11-03T20:22Z

- Run `core-20261103T2013Z-fix-startup-format`; branch `automation/issue-22-atomic-review`; source HEAD `e38c3ec0139014144daf7ce66f978b3629a00805`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41701867443](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41701867443), attempt 1, completed FAILURE on `e38c3ec0139014144daf7ce66f978b3629a00805`: repo-sanity, database/RLS, AI boundary, disposable local Supabase integration and Windows all SUCCESS with every step; Flutter dependency resolution SUCCESS; Dart 3.35.4 strict formatter failed because only `lib/features/auth/application/persistent_account_startup.dart` was changed by formatter (115 files checked). Analyze, full Flutter suite and every downstream Flutter check were SKIPPED.
- Added a temporary read-only CI diagnostic immediately before the unchanged strict format gate. It writes `dart format --output=show` to the runner temp directory and prints a unified diff for the single identified file; it does not modify checked-out source or weaken the gate. Next: capture the exact diff, apply formatter output, remove this diagnostic step in the same final correction, then inspect full exact-head CI.
- Changed paths for this diagnostic checkpoint: `.github/workflows/ci.yml`, `docs/PROJECT_STATUS.md`. No production Auth/session/vault, database/RLS, dependencies, default activation, or Pro-owned #14/#38/N4 files changed. Cloud runtime has no Dart/Flutter SDK; no local format/analyze/test/build claim.
- Keep PR #37 Draft and #20/#22/#15 open. Hosted signed-JWT learner A/B, deployed RLS, hosted restart/expiry and physical multi-device evidence remain outstanding.

---

## Latest handoff — startup profile publication barrier — 2026-11-03T19:12Z

- Core run `core-20261103T1912Z-await-profile-before-publish`; branch `automation/issue-22-atomic-review`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`; source parent `840cc026b93414f44227345a69cf8c1e772a9507`.
- Exact-head CI [41691714798](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41691714798), attempt 1, targeted `840cc026b93414f44227345a69cf8c1e772a9507`: repo-sanity, AI boundary, database, disposable Supabase integration and Windows all SUCCESS with every step; Flutter format/analyze SUCCESS; the full Flutter suite failed at `persistent_supabase_runtime_test.dart:1351` because the configured startup host became `active` before its held own-profile response returned. All downstream Flutter lifecycle/wire/browser/Web checks were SKIPPED. No full-CI pass.
- Implemented a captured-session profile barrier: `AccountController.waitForCurrentProfile()` follows the current session through A→B changes, returns only when that session reaches ready/profileError/signed-out/disposed, and is bounded at 20 seconds (the profile transport itself retains its 15-second timeout). `PersistentAccountStartup.start()` now awaits it after the credential-vault restore/rotation barrier. This keeps the startup screen loading until the own profile settles; profile errors still reach the existing explicit retry UI.
- Added TEST ONLY account-controller scenarios for pending profile, account replacement/late response, and profile failure. Existing rotated-secret-before-profile, no-study-runtime-before-profile, logout and safe-error assertions remain.
- Paths: `apps/flutter_app/lib/features/auth/application/account_controller.dart`, `apps/flutter_app/lib/features/auth/application/persistent_account_startup.dart`, `apps/flutter_app/test/features/srs/account_fixtures.dart`, `docs/PROJECT_STATUS.md`.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. Exact-head GitHub Actions is the verification gate. No hosted signed-JWT learner A/B, deployed RLS, hosted restart/expiry or physical multi-device proof is claimed. No Auth strategy/provider, schema/RLS, CI gate, default activation, deployment or Pro-owned N4 change.
- Next: inspect every latest-attempt job and required step for the new exact head; fix only observed failures. Keep PR #37 Draft and #20/#22/#15 open until their full acceptance and hosted evidence are satisfied.

---

## Latest handoff — exact Dart formatter output applied — 2026-11-03T09:14Z

- Core run `core-20261103T0911Z-rerun-cancelled-flutter-diagnostic`; branch `automation/issue-22-atomic-review`; source parent `543514b6ac71955f627842394c4a2bfb84d19f1c`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- On exact current PR-head workflow [41603332837](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41603332837), attempt 2, the pinned Dart 3.35.4 formatter gate failed and the temporary diagnostic step succeeded. Its unified diff identified exactly one whitespace-only change in `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`: join the two-line `condition` expression for `AccountStartupPhase.restoreError` into one line. No other Dart file was reformatted.
- In that latest attempt, `repo-sanity`, `database` and `ai-boundary` completed SUCCESS with all returned steps; Flutter Analyze, the complete Flutter suite and later Flutter checks were SKIPPED after the format gate. `windows` and `supabase-integration` remained CANCELLED because only the cancelled Flutter job was rerun. This is diagnostic evidence, not a full-CI pass.
- Applied only the formatter's exact one-line change and removed the temporary diagnostic step from `.github/workflows/ci.yml`; strict formatter/analyze/test/build gates remain unchanged. No test semantics/assertions, production Auth/session, schema/RLS, dependency, default activation or Pro-owned N4 files changed.
- Changed paths in this increment: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `.github/workflows/ci.yml`, `docs/PROJECT_STATUS.md`.
- Cloud runtime has no Dart/Flutter SDK; no local format/analyze/test/build is claimed. The new exact-head Actions run must execute all six jobs and every required Flutter lifecycle/vault/profile/wire/Chrome/Web, Windows and disposable Supabase step without skips before acceptance.
- No hosted signed-JWT learner A/B, deployed RLS, hosted restart/expiry or physical multi-device proof is claimed. Keep PR #37 Draft and #20/#22/#15 open. Pro-owned #14/#38/N4 scope untouched.
- Next: inspect the new exact-head run's latest attempt and all steps; fix only newly observed failures. Do not merge until full PR acceptance and hosted gates are met.

---

## Latest handoff — capture exact Dart 3.35.4 formatter output — 2026-11-03T08:24Z

- Core run `core-20261103T0824Z-capture-dart-format-diff`; branch `automation/issue-22-atomic-review`; diagnostic commit `1e2731dfe074d19bf90aa5fef05ea9e69c0f46ea` (parent `09acbc5f10fcf574b96699864cf30b6319837f4e`); base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41602758958](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41602758958), attempt 1, on parent `09acbc5f10fcf574b96699864cf30b6319837f4e`: Flutter setup and locked dependency install passed; strict `dart format --output=none --set-exit-if-changed .` failed because exactly `test/features/srs/persistent_supabase_runtime_test.dart` was reformatted. Flutter analyze, suite and all downstream Flutter steps were skipped. Repo-sanity/database/AI boundary completed SUCCESS; Windows and disposable Supabase integration were still running at observation.
- Exact-head diagnostic CI [41603178181](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41603178181), attempt 1, targets `1e2731dfe074d19bf90aa5fef05ea9e69c0f46ea`; observed PENDING/no jobs at 2026-11-03T08:25Z. No formatter diff, analyze, test or build result is yet available.
- Add a temporary `if: always()` CI diagnostic immediately after the strict formatter gate. It formats only the affected test file in the disposable runner workspace and prints `git diff`; it does not modify the branch checkout or weaken/replace the formatter gate. Next apply only the exact emitted whitespace diff and remove this temporary step in the same source commit.
- Changed paths: `.github/workflows/ci.yml` (temporary read-only diagnostic step) and `docs/PROJECT_STATUS.md`. No production/runtime, test assertion, Auth, schema/RLS, dependency, security or Pro-owned content change.
- Cloud runtime has no Dart/Flutter SDK; no local format/analyze/test/build is claimed. New exact-head CI will capture the formatter diff; do not count any skipped Flutter step as pass.
- Next: inspect the diagnostic output on the exact new head, apply the exact formatter correction, remove the diagnostic step, then rerun all exact-head jobs/steps. Keep PR #37 Draft and #20/#22/#15 open.

---

## Latest handoff — run owned Supabase SDK lifecycle on the real test loop — 2026-11-03T08:15Z

- Core run `core-20261103T0815Z-trace-sdk-restore-barrier`; branch `automation/issue-22-atomic-review`; parent `e41b1a7ce1c05a75c02ba322cfec2e509eb5d08e`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41595439958](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41595439958), attempt 1, targeted `e41b1a7ce1c05a75c02ba322cfec2e509eb5d08e`. Repo-sanity, database/RLS, AI boundary, disposable Supabase integration and Windows completed SUCCESS with every step. Flutter format and analyze passed; the complete serial suite had 395 passes and two failures. The configured-host startup widget did not reach its held vault-write barrier (the `pumpWidgetUntil` assertion failed), then teardown/startup timed out for ten minutes; the following explicit-login widget also timed out. All downstream Flutter lifecycle/wire/Chrome/Web steps were SKIPPED, not passed.
- The two configured-host tests were driving real Supabase SDK/MockClient HTTP and credential-vault work by pumping WidgetTest FakeAsync frames. Replace that mixed clock with a bounded `tester.runAsync` helper: start the owned restore before mounting the UI, wait for the actual vault barrier/restore-error state on the real loop, and wait for profile readiness/explicit-login persistence on the real loop. UI loading/profile assertions and vault ordering assertions remain; cleanup still releases a held write and closes the startup owner.
- Changed paths: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart` and `docs/PROJECT_STATUS.md`. No production Auth/session code, SDK configuration, dependency, timeout, API/schema/migration/RLS, CI gate, default activation or Pro-owned content changed.
- Cloud runtime has no Dart/Flutter SDK; no local format/analyze/test/build is claimed. Exact-head Actions must verify formatter/analyzer, all Flutter tests, lifecycle/vault/profile/wire/Chrome/Web checks, Windows and disposable Supabase jobs with no required skips. No hosted signed-JWT learner A/B, deployed RLS, hosted restart/expiry or physical multi-device proof is claimed.
- Next: inspect every latest-attempt job and step on the new exact head. If the two widget tests pass, continue only with observed failures and then resume remaining #20/#22/#15 acceptance; keep PR #37 Draft until all criteria and hosted evidence are met. Pro-owned PR #38 / Issue #14 / N4 scope remains untouched.

---

## Latest handoff — exact Dart 3.9.2 formatter correction — 2026-11-03T07:14Z

- Core run `core-20261103T0714Z-apply-dart-format-ci-diff`; branch `automation/issue-22-atomic-review`; source commit `670dd0c26dd64d274a639dde85436afba612d521` (parent `4b93ae079a5cef342a021f3fc2dcc9ca08a7a35c`); base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41588760679](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41588760679), attempt 1, completed FAILURE solely at strict Dart 3.9.2 formatting. The other five jobs (repo-sanity, database, ai-boundary, disposable Supabase integration and Windows) completed SUCCESS with every step. Flutter analyze, full tests, lifecycle/wire/Chrome/Web checks were SKIPPED after the formatter gate and are not counted as passing.
- The diagnostic output showed exactly three whitespace changes in `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`: split two overlong `reason` strings and add the terminal newline. Applied only those changes and removed the temporary read-only diagnostic step from `.github/workflows/ci.yml`; strict format/analyze/test/build gates remain unchanged.
- Source paths: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart` and `.github/workflows/ci.yml`. The test diff is +4/-2 whitespace only; workflow removes four temporary diagnostic lines. No assertion, runtime, Auth, dependency, API, schema/RLS, content, or default-app behavior changed.
- Separate diff review: exactly the two intended paths. Parent/result recursive trees were complete and untruncated at 327 entries; 318 entries including all untouched blobs remained identical, with no path/mode/type loss. `create_tree` used exact base tree `0bd70ee5e96390f93ba2a3f087685f722e10fd4d`; `update_ref` used `expected_sha=4b93ae079a5cef342a021f3fc2dcc9ca08a7a35c`, `force=false`; branch and PR readback matched source commit `670dd0c26dd64d274a639dde85436afba612d521`.
- New source-head CI [41595317740](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41595317740), attempt 1, targets source commit `670dd0c26dd64d274a639dde85436afba612d521` and was observed `in_progress` at 2026-11-03T07:17Z. This run precedes the status-only handoff commit below; it is not final-PR-head evidence. No format/analyze/test/build/full-CI pass is claimed for the new source yet.
- Cloud runtime has no Dart/Flutter SDK; no local format/analyze/test/build is claimed. No hosted learner A/B, deployed RLS, hosted expiry/restart or physical multi-device proof. PR #37 remains Draft; #20/#22/#15 remain open. Pro-owned PR #38 / Issue #14 / N4 files remain untouched.
- Next: inspect every latest-attempt job/step on the final status-commit head, require strict format/analyze/full Flutter tests/downstream lifecycle/wire/Chrome/Web plus all other jobs without skips, and fix only observed failures. Keep #20/#22/#15 and Personal Alpha IN_PROGRESS until hosted learner evidence and release gates are met.

---

## Latest handoff — exact Dart formatter diagnostic — 2026-11-03T06:12Z

- Branch `automation/issue-22-atomic-review`; source HEAD `75faf33cf239c3b8418e8532641ad7e2c1af1e60`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41582701283](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41582701283), attempt 1, completed with `repo-sanity`, `database`, `ai-boundary`, `windows` and disposable `supabase-integration` SUCCESS. Flutter failed at strict `dart format --output=none --set-exit-if-changed .`; every subsequent Flutter analyze/test/lifecycle/wire/browser/Web step was SKIPPED. Job log says Dart 3.9.2 still changes only `test/features/srs/persistent_supabase_runtime_test.dart`, so the prior one-line correction did not fix the complete formatted output.
- Temporary workflow diagnostic prints a unified diff generated by pinned Dart 3.9.2 to the Actions log. It writes only under `RUNNER_TEMP`, does not modify checked-out source, and does not change or bypass the strict formatter gate. This diagnostic is temporary and will be removed after the exact formatter output is applied.
- Cloud runtime has no Dart/Flutter SDK; no local format/analyze/test/build is claimed. No hosted learner A/B, deployed RLS, hosted expiry/restart or physical multi-device evidence.
- No Auth strategy/provider, production runtime, schema/migration/RLS, default app activation, secrets, deployment or Pro-owned #14/#38/N4 files changed. PR #37 remains Draft; #20/#22/#15 remain open.
- Next: inspect the diagnostic diff from the new exact-head CI, apply only the formatter's actual source changes, remove the diagnostic step, then require full exact-head format/analyze/tests and downstream checks.

---

## Core worker review follow-up — normalize helper spacing — 2026-11-02T22:15Z

- Parent `92503db4866e2218da1d84780e1c27ce83b2cf67` contained one extra blank line before the new test helper in `persistent_supabase_runtime_test.dart`; this follow-up removes only that whitespace before the pinned Dart formatter runs. No test or runtime behavior changes.
- CI [41535390299](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41535390299) was queued on the parent head and is superseded by this formatting-only commit; no result is counted from it.
- Next: inspect the corrected exact-head CI, especially formatter, bounded readiness regression, all Flutter downstream steps, Windows and Supabase integration.

---

## Core worker handoff — bound configured-host widget readiness test — 2026-11-02T22:10Z

- Run `core-20261102T2210Z-bound-configured-host-widget-test-timeout`; branch `automation/issue-22-atomic-review`; parent `7adeb47f5d93ba2905e08af8610b85976de201dd`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41527342579](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41527342579), latest attempt 1, had repo-sanity, database, AI boundary, disposable local Supabase integration and Windows complete SUCCESS with every returned step. Flutter format/analyze passed; the full suite reached 64 passing tests, then the configured-host startup widget test hit its own 10-minute timeout. The downstream Flutter lifecycle/wire/browser/Web steps were skipped. The run was later cancelled; no full-CI pass is claimed.
- The timed-out test used `pumpAndSettle()` while the account route can retain an indeterminate `LinearProgressIndicator` until the asynchronous own-profile barrier publishes ready state. Replace that unbounded settle on both successful configured-host paths with the existing five-second `waitForReady()` assertion plus two finite frame pumps. If profile readiness does not arrive, the test now fails at the bounded barrier rather than hanging for ten minutes; UI visibility and ready-runtime assertions remain.
- Changed paths: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart` and this file. No production Auth/session code, CI timeout, test assertion, schema/RLS, provider strategy, default app behavior, curriculum or Pro-owned #14/#38/N4 scope changed.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. Exact-head CI must verify the complete Flutter suite, downstream lifecycle/wire/browser/Web checks, Windows and database/integration jobs. Hosted signed-JWT learner A/B, deployed RLS, hosted restart/expiry and physical multi-device proof remain outstanding.
- Next: inspect every latest-attempt job and step for the new exact head; if the bounded readiness wait fails, fix the actual profile-dispatch/readiness defect rather than extending timeouts or removing assertions.

---

## Core worker handoff — generation-fenced delayed Auth sign-out — 2026-11-02 UTC

- Run `core-20261102T1318Z-session-event-generation-fence`; branch `automation/issue-22-atomic-review`; parent `c84dfcfe498d888347d50b07d68e21290191e544`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41444643342](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41444643342), latest attempt 1, completed FAILURE on this exact parent. Repo-sanity, AI boundary, database, Windows and disposable Supabase integration passed every step. Flutter format/analyze passed; Flutter tests were 393 passed / 1 failed: the pinned-SDK A/B recovery case expected three vault clears but observed four, with redacted operation order `read → write → write → clear → clear → clear → write → clear`. All downstream Flutter lifecycle/wire/browser/Web steps were skipped, not passed.
- The binding now assigns a monotonically increasing generation to each owned sign-in/restore/refresh. Explicit logout records its generation; a delayed null `SIGNED_OUT` event is accepted only while that generation remains current. Starting B's newer Auth operation invalidates A's queued null event. The pinned-SDK regression retains the exact three-clear and full operation-order assertions; a focused binding test covers the stale null event after a newer generation. Explicit logout and expiry paths remain fail-closed.
- Changed paths: `apps/flutter_app/lib/features/srs/data/supabase_review_binding.dart`, `apps/flutter_app/lib/features/auth/application/persistent_supabase_runtime.dart`, `apps/flutter_app/test/features/srs/supabase_review_binding_test.dart`, `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `qa/matrix.json`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, and this file.
- Cloud runtime has no Dart/Flutter SDK; local format/analyze/test/build were not run. New exact-head Actions must verify the focused regression and every retained job/step. This remains TEST ONLY SDK/MockClient/in-memory-vault evidence, not hosted signed-JWT learner A/B, deployed RLS, or physical multi-device proof.
- No Auth strategy/provider, API, migration/RLS, default activation, production config, secrets, or Pro-owned #14/#38/N4 path changed. Keep PR #37 Draft and #20/#22/#15 open.
- Next: inspect every latest-attempt job/step on the new exact head; fix only observed failures. If checks are pending, hand off without duplicate code.

---

## Core worker handoff — exact Dart 3.9.2 formatting and diagnostic cleanup — 2026-11-02T10:11Z

- Run `core-20261102T1011Z-fix-dart-format`; branch `automation/issue-22-atomic-review`; parent `fe3b2de277f71f41022526bf92efc283b37643c4`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Inspected latest main, README, project manifest, AGENTS, single-account automation, PROJECT_SPEC, AUTOMATION, API/database/security/QA docs, open issues/PRs, and PR #37 worker markers. Pro-owned PR #38 / Issue #14 scope remains reserved and untouched.
- Exact-head CI [41420437185](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41420437185), latest attempt 1, completed FAILURE solely because strict Dart 3.9.2 formatting found one file changed. The diagnostic diff required only compacting the `_bindingSubscription` callback in `apps/flutter_app/lib/features/auth/application/persistent_supabase_runtime.dart`; no behavior changed. The other five jobs (repo-sanity, ai-boundary, database, supabase-integration, Windows) completed SUCCESS with every step. Flutter analyze, tests, lifecycle/wire checks, Chrome and Web build were SKIPPED after the formatter failure and are not counted as passing.
- Applied exactly that formatter diff and removed the temporary diagnostic-only workflow step from `.github/workflows/ci.yml`. No runtime semantics, tests/assertions, Auth strategy/provider, API/schema, migration/RLS, security, dependencies, or curriculum changed.
- Changed paths: `apps/flutter_app/lib/features/auth/application/persistent_supabase_runtime.dart`, `.github/workflows/ci.yml`, and `docs/PROJECT_STATUS.md`.
- Full recursive parent tree was read untruncated: 327 entries. `create_tree` used the exact parent tree SHA as `base_tree_sha`; the new full recursive tree was checked for path/mode/type preservation and only the three intended blobs changed. Ref update used `expected_sha=fe3b2de277f71f41022526bf92efc283b37643c4`, `force=false`; branch and PR readback were checked.
- Cloud runtime has no Dart/Flutter SDK, so no local formatter/analyze/test/build result is claimed. New exact-head CI is the verification gate; inspect every latest-attempt job/step. Keep PR #37 Draft and #20/#22/#15 open. Hosted signed-JWT learner A/B, deployed RLS, physical multi-device sync, and full Personal Alpha journey evidence remain outstanding. No production/release action or human-gated change was made.

---

## Core worker handoff — suppress transient registry invalidation during SDK account switch — 2026-11-02 UTC

- Run `core-20261102T0833Z-fix-stale-lifecycle-notification`; branch `automation/issue-22-atomic-review`; parent `d59b7b7e12db8bd78b876f9da09f96891adb28d8`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Parent exact-head CI [41408614762](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41408614762), latest attempt 1, completed FAILURE: repo-sanity, ai-boundary, database, windows and supabase-integration passed every step; Flutter format/analyze passed, but Flutter tests reported 393 passed / 1 failed at `persistent_supabase_runtime_test.dart:407` (expected 3 clears, observed 4). All later Flutter lifecycle/wire/Chrome/Web checks were skipped, not passed.
- Root cause: `_OwnedSdkAccess` forwarded every review-registry notification to persistence. The registry can revoke its previous connection while a valid replacement SDK session is current but its queued Auth event has not yet been bound. That transient registry invalidation is not a real sign-out; forwarding it makes `PersistentAccountAccess` clear the vault before the replacement event is persisted.
- Fix: `SupabaseReviewBinding.shouldForwardSessionChangeToPersistence` now forwards only when SDK state is absent, invalid/expired, or exactly matches the bound user/session lifecycle, access token and expiry. The raw Auth observer remains responsible for accepted current-session events and rotation. Genuine logout/expiry still reaches persistence. The existing test still requires exactly 3 ordered clear attempts, B's rotated secret/profile bearer and B-only readiness; no assertion or gate was weakened.
- Changed paths: `apps/flutter_app/lib/features/srs/data/supabase_review_binding.dart`, `apps/flutter_app/lib/features/auth/application/persistent_supabase_runtime.dart`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, and this status file.
- Full parent recursive tree was read untruncated: 327 entries (262 blobs / 65 trees); create_tree will use exact base tree `a5db84d89f9935e19dbbb30d6c84467e7d7fde84`. Cloud runtime has no Dart/Flutter SDK or Windows OS; no local format/analyze/test/build/native execution is claimed. New exact-head CI is required.
- Keep PR #37 Draft and #20/#22/#15 open. No Pro-owned #14/#38/N4 path, Auth strategy/provider, default activation, schema/migration/RLS, secrets, production or release change. Hosted signed-JWT learner A/B and physical multi-device evidence remain unproven. Next: inspect every latest-attempt job/step on the new exact head; fix only observed diagnostics.

---

## Core worker handoff — ignore stale SDK sign-out after account replacement — 2026-11-02 UTC

- Run `core-20261102T0414Z-ignore-stale-signed-out-event`; branch `automation/issue-22-atomic-review`; parent `31743d76e7884bfc517315018dd2b7533a63dd22`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41382115777](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41382115777), attempt 1, targets `31743d76e7884bfc517315018dd2b7533a63dd22` and failed: Flutter format/analyze passed; Flutter tests reported 392 passed / 1 failed at `persistent_supabase_runtime_test.dart:406` (expected three vault clears, observed four). Five other jobs (`repo-sanity`, `ai-boundary`, `database`, `windows`, `supabase-integration`) completed SUCCESS with every returned step; downstream Flutter checks/build were skipped after the test failure. No full-CI pass is claimed.
- Root cause: `SupabaseReviewBinding._accept` unconditionally revoked on a queued `SIGNED_OUT`/null event. The pinned SDK can deliver an event for A after B is already current; persistence then observed null and queued a fourth clear over B's rotated token. The binding now validates the current SDK session and ignores a null/older-lifecycle event that does not match it. Events matching the current lifecycle, and signed-out events with no current SDK session, still revoke. The event identity comparison uses user ID + JWT `session_id`, not token persistence or logging.
- Paths: `apps/flutter_app/lib/features/srs/data/supabase_review_binding.dart`, `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, and this status file. The existing regression retains the exact three-clear operation sequence, B token/profile bearer and readiness assertions; no test expectation or CI gate was weakened.
- Full recursive parent tree: 327 entries (262 blobs, 65 trees), untruncated. No N4/content, API/schema, migration/RLS, Auth strategy/provider, default activation, secret, production or Pro-owned #14/#38 path changed. Cloud runtime has no Flutter/Dart SDK or Windows OS; local format/analyze/test/build/native execution was not run.
- New exact-head CI is required for Flutter regression, web/Windows builds and all six jobs. Keep PR #37 Draft and #20/#22/#15 open pending hosted signed-JWT learner A/B, deployed RLS and physical multi-device evidence. Next: inspect every latest-attempt job/step on the new exact head and fix only observed diagnostics.

---

## Core worker handoff — coalesce delayed SDK sign-out cleanup — 2026-11-02 UTC

- Run `core-20261102T0310Z-fix-refresh-rotation-clear-regression`; branch `automation/issue-22-atomic-review`; parent `95c4c2b0593fdec28f374c913e3bb20e6fc1567e`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41376229941](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41376229941) on the parent completed with five jobs fully SUCCESS and Flutter format/analyze SUCCESS; Flutter tests reported 392 passed / 1 failed at the new cross-account cleanup regression (expected 3 clears, observed 4), so later Flutter steps were skipped. The earlier heartbeat in this PR was queued; this is the final observed run result.
- Corrected the lifecycle boundary rather than weakening the test: `PersistentAccountAccess` now coalesces delayed duplicate null-session notifications from the owned binding/Auth observers until a non-null session is observed. Explicit cleanup marks the fence before SDK sign-out; the existing regression still requires exactly three ordered clear attempts before B's rotated-secret write.
- Paths: `apps/flutter_app/lib/features/auth/data/persistent_account_access.dart`, `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, and this status file.
- This source remains TEST ONLY pinned-SDK/MockClient/in-memory-vault evidence. No Windows Credential Manager failure injection, hosted signed-JWT learner A/B, deployed RLS, OS logoff/power-loss or physical multi-device proof is claimed. Cloud runtime has no Flutter/Dart SDK or Windows OS; local format/analyze/test/build/native execution was not run.
- New exact-head CI must verify the corrected lifecycle/test on all six jobs and every required step before integration. Keep PR #37 Draft and #20/#22/#15 open; no default Auth activation, provider strategy, schema/RLS, secret, production or Pro-owned #14/#38/N4 change.

---

# PROJECT STATUS

## Core worker handoff — configured Supabase lifecycle test isolation — 2026-11-04T01:22Z

- Core run `core-20261104T0114Z-replace-cross-zone-sdk-widget-tests`; branch `automation/issue-22-atomic-review`; source commit `ea123f377dc87562b856f57e00e3944200b69a64` (parent `9d0420349df568d1b64490ee931d0b0f17a963e7`); base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Changed source path: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`. The two configured-host Supabase SDK/MockClient/vault scenarios are now ordinary bounded async tests rather than WidgetTests mixing FakeAsync frame pumping with real HTTP/SDK continuations. They retain the rotated-refresh-secret-before-profile barrier, no account publication/readiness while own-profile response is held, captured bearer verification, rejected-restore explicit-login path, clear-before-password-auth ordering, and rotated-secret persistence before profile readiness. Separate `account_startup_widget_test.dart` and `account_widget_test.dart` continue to cover the rendered loading shell, hidden login form, explicit login form, profile readiness UI and study gating.
- Parent exact-head CI [41746396784](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41746396784), attempt 1, on `9d0420349df568d1b64490ee931d0b0f17a963e7`: repo-sanity, AI boundary, database/RLS, disposable Supabase integration and Windows SUCCESS with every step; Flutter format and analyze SUCCESS; full serial suite FAILED after 398 passes with two 10-minute timeouts in the configured-host restore/profile and explicit-login tests. All downstream Flutter checks were SKIPPED; not a full-CI pass.
- New source-head CI [41753639582](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41753639582), attempt 1, targets `ea123f377dc87562b856f57e00e3944200b69a64`. At 2026-11-04T01:24Z: repo-sanity (11/11 steps), AI boundary (12/12) and database (12/12) SUCCESS; Supabase integration, Windows and Flutter IN_PROGRESS (3, 2 and 2 steps completed respectively, no failure yet). No formatter/analyzer/full-test/downstream result is claimed for this source head.
- Separate source diff review: exactly one test file changed; unused WidgetTest-only imports/helpers removed, two configured-host tests replaced. Complete recursive tree was untruncated at 327 entries (262 blobs / 65 trees), with identical path/mode/type set and exactly one leaf blob SHA changed. `create_tree` used exact base tree `2f98ca582e082e1865716e492b1be6c7d793af40`; source commit parent is exact previous HEAD; `update_ref` used expected SHA `9d0420349df568d1b64490ee931d0b0f17a963e7`, `force=false`. Branch readback matched the source commit.
- Cloud runtime has no Dart/Flutter SDK, so local format/analyze/test/build were not run. This is TEST ONLY scheduling/lifecycle evidence with synthetic Auth/MockClient and in-memory vault, not hosted learner A/B, signed-JWT/PostgREST, deployed RLS, hosted restart/expiry or physical multi-device proof. No production Auth/session/vault, API/schema/RLS, dependency, CI gate, default activation or Pro-owned #14/#38/N4 path changed.
- Next: inspect every latest-attempt job and required step on the final status-commit HEAD; require strict format, analyze, full Flutter suite, lifecycle/vault/profile/wire/Chrome/Web, Windows, disposable Supabase, database, AI boundary and repo-sanity without skipped required steps. Fix only observed failures. Keep PR #37 Draft and #20/#22/#15 open.

---

## Latest core handoff — 2026-11-04T00:16Z

- Run `core-20261104T0014Z-fix-profile-switch-barrier` RELEASED after publishing source commit; PR #37 branch `automation/issue-22-atomic-review`, parent `be39abe86a3a4d75dac5f4444b8970ce891514b9`, base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41728874434](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41728874434), latest attempt 2 on `be39abe86a3a4d75dac5f4444b8970ce891514b9`: repo-sanity, AI boundary, database/RLS, disposable local Supabase integration and Windows completed SUCCESS with every returned step; Flutter format and analyze succeeded. The serial Flutter suite exposed `account readiness wait-current-profile-switch` failing with `startup barrier did not follow the replacement account`; the job was later CANCELLED, and all Flutter downstream checks were SKIPPED. This is not a full-CI pass. The log also showed the next profile-error scenario beginning before cancellation; no result for that scenario is claimed.
- Implemented a per-session profile settlement completer. A session replacement or disposal settles the previous waiter; the startup loop re-reads the currently captured session and waits for its own profile. Profile errors are now associated with the exact session so startup does not silently retry the same failed profile; the existing explicit retry remains the only retry path.
- Regression coverage strengthens A→B: a late A profile cannot release the B startup barrier, and B's matching profile must settle it. The profile-error test asserts exactly one request and a safely released barrier.
- Changed paths: `apps/flutter_app/lib/features/auth/application/account_controller.dart`, `apps/flutter_app/test/features/srs/account_fixtures.dart`, `docs/PROJECT_STATUS.md`. No Auth strategy/provider, token handling, native vault, schema/RLS, N4/Pro-owned content, production configuration or release setting changed.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. New exact-head CI must pass all Flutter tests and every downstream lifecycle/vault/profile/wire/Chrome/Web, Windows and Supabase job with no required skips. Hosted signed-JWT learner A/B, deployed RLS, hosted restart/expiry and physical multi-device proof remain outstanding.
- Next: inspect every latest-attempt job/step for the new exact HEAD. If tests fail, fix only the observed cause; keep #20/#22/#15 open and PR #37 Draft.

---

## Core worker handoff — failed refresh rotation plus failed vault cleanup — 2026-11-02 UTC

- Run `core-20261102T0205Z-review-next-session-boundary`; branch `automation/issue-22-atomic-review`; parent `36421e57de14bec2ef720a968e43c46b1c2e8ded`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Added one TEST ONLY pinned-Supabase-SDK regression combining a failed refresh-token rotation write with a failed compensating vault clear. The old secret remains physically present but is not accepted as a session; readiness stays fenced and no profile request is dispatched.
- A User B login while cleanup still fails must not send another Auth token request. After the vault recovers, explicit cleanup clears A's uncertain slot, persists B's rotated secret, and waits for B's matching profile response before opening readiness.
- Paths: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, `qa/matrix.json`, and this status file.
- Parent exact-head CI [41371848770](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41371848770) completed SUCCESS on `36421e57de14bec2ef720a968e43c46b1c2e8ded`: all six jobs and every returned step passed, including Flutter format/analyze/tests, Chrome IndexedDB/reload, Windows release/native vault/journal probes, disposable local Supabase GoTrue/PostgREST rotation/replay/A-B RLS, database and AI boundary. This parent run does not certify the new regression.
- Cloud runtime has no Flutter/Dart SDK or Windows OS. New regression is TEST ONLY MockClient/in-memory-vault evidence, not native Windows storage-failure injection or hosted signed-JWT learner A/B. No Auth strategy/provider, default activation, schema/RLS, secret, production or Pro-owned N4 change.
- Next: inspect every latest-attempt job and step on the new exact head; fix only observed diagnostics. Keep PR #37 Draft and #20/#22/#15 open pending hosted learner A/B and physical multi-device evidence.

---


## Core worker handoff — refresh rotation vault-write failure — 2026-11-02 UTC

- Resume PR #37, branch `automation/issue-22-atomic-review`; parent `5b0546a046f3a35c1ca7138f0cde913f5e577196`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Added a TEST ONLY pinned-Supabase-SDK regression for explicit refresh rotation when the credential-vault write is delayed and then fails. It verifies the previous secret is not replaced while pending, readiness/profile dispatch remain fenced, the uncertain secret is cleared after failure, and only a later explicit login can recover.
- Recovery holds the own-profile response and verifies the newly rotated secret is saved before the profile barrier opens.
- Changed paths: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, `qa/matrix.json`, and this status file.
- Parent exact-head CI [41366109566](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41366109566) completed SUCCESS on `5b0546a046f3a35c1ca7138f0cde913f5e577196`: all six jobs and every step passed. A fresh exact-head CI is required for this increment; no new-source test/build result is claimed yet.
- Cloud runtime has no Flutter/Dart SDK or Windows OS. This fixture is not Windows OS storage failure injection or hosted learner A/B. No production Auth/provider/default activation, API, migration/RLS, secret, or Pro-owned N4 scope changed.
- Next: inspect every latest-attempt job/step on the new exact head; fix only observed failures. Keep PR #37 Draft and #20/#22/#15 open pending hosted signed-JWT learner A/B and physical multi-device evidence.

---


## Formatter correction handoff — runtime close-drain test (2026-11-02 UTC)

- Run `core-20261102T0012Z-dart-format-diagnostic`; branch `automation/issue-22-atomic-review`; diagnostic parent `a61592e535568a6b0cef2bd723a09bc231822519`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head diagnostic CI [41365877205](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41365877205), attempt 1, targets `a61592e535568a6b0cef2bd723a09bc231822519`. repo-sanity, database and ai-boundary passed every step; Flutter failed only strict pinned-Dart formatting, so Analyze/tests/build were skipped. Windows and local Supabase integration were still in progress at last job inspection.
- The temporary always-run diagnostic printed the exact Dart 3.35.4 diff: wrap the two new `requests.where(...ensure_profile...)` arguments, compact the awaited `expectLater`, and put the caller-owned probe route's return inside a block. Applied only these formatter edits; removed the temporary workflow diagnostic step in this same commit. No assertions, CI gates or production code changed.
- Changed paths: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `.github/workflows/ci.yml`, this status file. Parent formatter failure is not treated as a pass; a fresh exact-head CI must run format/analyze/test/build and all other jobs.
- Cloud runtime has no Flutter/Dart SDK or Windows OS, so no local format/analyze/test/build/native execution is claimed. The new runtime-close test remains TEST ONLY pinned-SDK/MockClient/in-memory-vault evidence, not hosted signed-JWT learner A/B or physical multi-device acceptance.
- Next: inspect all latest-attempt jobs/steps on the corrected exact head; fix only observed failures. Keep PR #37 Draft and #20/#22/#15 open pending hosted learner and multi-device evidence.

---


## Latest handoff — caller-owned runtime close drains startup refresh (2026-11-02 UTC)

- Resume PR #37, branch `automation/issue-22-atomic-review`; parent `fcb8de1300aa1728c339ac7f9bf09dd1501a8bf3`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Added one TEST ONLY pinned-Supabase-SDK regression: close the owned runtime while startup refresh is pending; verify close waits for the late response, cleanup performs `read -> clear`, no own-profile request is dispatched, the same-project owner slot remains held until close completes, and a replacement owner can start only after cleanup. The injected HTTP client remains usable after wrapper disposal.
- Changed paths: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, this status file. No production Auth behavior, default activation, schema/RLS, provider strategy, URL/key handling or Pro-owned #14/#38/N4 content changed.
- Parent exact-head CI [41361214986](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41361214986) targets `fcb8de1300aa1728c339ac7f9bf09dd1501a8bf3` and is observed SUCCESS: all six jobs and every returned step succeeded (Flutter format/analyze/test, Chrome IndexedDB/reload, web build; Windows vault/process/build; disposable local Supabase integration; database/RLS; AI boundary; repo-sanity). This is parent evidence only.
- New-source exact-head CI is required. Cloud runtime has no Flutter/Dart SDK or Windows OS, so local Flutter format/analyze/test/build and native execution are not claimed. The test is fixture evidence, not hosted signed-JWT learner A/B or physical multi-device acceptance.
- Next: inspect every latest-attempt job/step on the new exact head; fix only observed failures. Keep PR #37 Draft and #20/#22/#15 open pending hosted learner A/B, expiry/restart and real multi-device evidence.

---


## Latest handoff — same-session refresh-expiry rotation guard (2026-11-01 UTC)

- Resume branch `automation/issue-22-atomic-review`, parent source head `086a6f12be245ad35b6f90c8cf822160771ccd0a`, main baseline `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41315035250](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41315035250) completed SUCCESS on `086a6f12be245ad35b6f90c8cf822160771ccd0a`: all six jobs (`repo-sanity`, `ai-boundary`, `database`, `supabase-integration`, `windows`, `flutter`) and every returned step succeeded. Flutter format/analyze/test, SRS wire checks, web release build, Windows vault/process and durable-journal checks, local Supabase GoTrue/PostgREST two-session checks, database/RLS and AI boundary/audit all passed on that exact head.
- Added one TEST ONLY scheduler regression: when the same accepted session identity receives a later expiry after token rotation, an already-queued timer callback captured against the old expiry must not refresh the new lease. It must preserve one correctly timed timer and dispatch zero stale refreshes. Updated `docs/SESSION_REFRESH.md` from 12 to 13 clock/timer fixtures.
- This closes a specific stale-expiry callback test gap only. Clock/timer/SDK fixtures and local Supabase are not hosted signed-JWT learner A/B, deployed RLS or physical multi-device evidence. No production Auth, provider strategy, schema/RLS, API, default activation, learner-selected URL/key, or Pro-owned #14/#38/N4 paths changed.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. Require all six latest-attempt jobs/every step on the new exact head before treating this increment as verified.
- Next: inspect the new exact-head CI; fix only observed failures. Keep PR #37 Draft and #20/#22/#15 open until hosted learner and real multi-device acceptance are observed.


## Latest handoff — pinned Dart formatter follow-up (2026-11-01 UTC)

- Exact-head CI [41314789659](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41314789659) targets `55d69788cdec5a0877fcdb9a44301f2c65baa6a8`. Repo-sanity, AI boundary and database completed SUCCESS with all steps; Windows and disposable Supabase integration were still running at the last observation. Flutter failed only at pinned Dart 3.35.4 strict format: the log identified `test/features/srs/account_fixtures.dart` as the sole changed file; Analyze, tests and Web Build were SKIPPED on that attempt.
- Applied only the formatter-required collapse of the two new explicit sign-in calls in `account_fixtures.dart`; no logic/assertions changed. This follows the exact CI formatter output naming one file; the next exact-head run must verify format and then execute the full test suite.
- Parent commit `55d69788cdec5a0877fcdb9a44301f2c65baa6a8` contains the Auth error-retention fix and deterministic readiness wait. No Auth strategy/provider, schema/RLS, API contract, default activation or Pro-owned #14/#38/N4 paths changed.
- Cloud runtime has no Dart/Flutter SDK; local format/analyze/test/build were not run. Keep PR #37 Draft and #20/#22/#15 open. Next: inspect every latest-attempt job/step on the new exact head; fix only observed failures.


## Latest handoff — exact-head Auth lifecycle test regressions (2026-11-01 UTC)

- Run `core-20261101T1405Z-auth-ci-regressions`; branch `automation/issue-22-atomic-review`; parent `6834c92cea31263343ffa4559b478f17c634bc0a`; main baseline `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41310396025](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41310396025) targeted the parent and completed with repo-sanity, database, ai-boundary, supabase-integration and Windows fully SUCCESS. Flutter format and analyze passed; Flutter Test reported 385 passed / 2 failed, so all later Flutter checks were skipped.
- Failure 1: after corrupt stored refresh data and an explicit cleanup failure, a queued null-session event changed `AccountPhase.signInError` back to `signedOut`. Updated `AccountController._sessionChanged` to preserve the fixed sign-in/sign-out error while there is no session; only explicit retry/logout transitions away. Added `sign-in-error-preserved` controller fixture, including successful explicit retry.
- Failure 2: the real-disk rotation/logout test used a fixed microtask flush after its second sign-in, then dereferenced readiness before the asynchronous SDK/profile barrier had settled. Replaced that timing assumption with the existing `waitForReady()` condition; no production behavior or assertion is weakened.
- Changed paths: `apps/flutter_app/lib/features/auth/application/account_controller.dart`, `apps/flutter_app/test/features/srs/account_fixtures.dart`, `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, and this status file.
- Separate diff review and exact-head CI are still required. Cloud runtime has no Flutter/Dart SDK, so local format/analyze/test/build were not run. No Auth strategy/provider, schema/RLS, API contract, default activation, production configuration or Pro-owned #14/#38/N4 paths changed.
- Next: inspect the parent-to-commit diff separately, then require all six latest-attempt CI jobs and every step to pass on the new exact head. Keep PR #37 and #20/#22/#15 open; hosted signed-JWT learner A/B and physical multi-device sync remain unproven.


## Latest handoff — corrupt-vault cleanup failure remains fenced (2026-11-01 UTC)

- Run `core-20261101T1307Z-corrupt-clear-retry`; source increment authored on `automation/issue-22-atomic-review`, parent `87c1a7e23fc49ef6be49dd790aa95b53756b5e16`, main baseline `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Extended `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`: malformed stored refresh data fails startup before Auth/profile; if explicit cleanup clear fails, sign-in remains fenced, the corrupt value is preserved, and no Auth token/profile request is dispatched. A successful explicit logout cleanup retry is required before a new sign-in can persist the rotated secret and open own-profile readiness.
- Updated `docs/PERSISTENT_SESSION_LIFECYCLE.md`. This is TEST ONLY pinned-SDK/MockClient/in-memory-vault coverage, not native Credential Manager failure injection or hosted signed-JWT/PostgREST/RLS/learner evidence. No production/Auth strategy/provider/schema/RLS/default/Pro N4 behavior changed.
- Exact-head CI for the new source/doc checkpoint is required; no new-head format/analyze/test/build result is claimed. Cloud runtime has no Flutter/Dart SDK.
- Next: inspect all six latest-attempt CI jobs and every step for the exact new head; fix only observed failures. Keep #20/#22/#15 and PR #37 draft until hosted learner A/B and physical multi-device sync gates are evidenced.


## Latest handoff — corrupt-vault fixture correction (2026-11-01 UTC)

- PR #37 branch `automation/issue-22-atomic-review`; source commit `a82db3032948148c5f1e27e665c90f79a1535bd4`, parent `7c35e51d88b6c506749f0c16c8c74f41506c9b0f`; main baseline `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Separate diff review found the new test's control-character escape was double-escaped and therefore printable. Corrected only the TEST ONLY literal in `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart` to one Dart newline escape; direct GitHub readback confirms one backslash in source. The corrupt-value assertions remain intact: fail before Auth/profile dispatch, preserve the malformed value until explicit cleanup, then `read -> clear -> write` before profile readiness.
- Parent exact-head CI [41300703129](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41300703129) remains all-six-jobs/all-steps SUCCESS for `7254202d2347081cfc400d586577d1f67f47dc6a` only. Exact-head run [41305432574](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41305432574) targets `a82db3032948148c5f1e27e665c90f79a1535bd4`, attempt 1, and was observed `pending` with no jobs reported at `2026-11-01T12:13Z`; no new format/analyze/test/build pass is claimed. Cloud runtime has no Flutter/Dart SDK.
- No production source, Auth/provider strategy, schema/RLS, API contract, default activation, deployment or Pro-owned #14/#38/N4 paths changed. Fixture remains TEST ONLY MockClient/in-memory vault; hosted signed-JWT/PostgREST/RLS/learner and two-device offline acceptance remain outstanding. Keep #37 draft and #20/#22/#15 open.
- Next: inspect the latest exact-head CI run after the docs checkpoint; fix only observed failures, otherwise hand off pending CI without duplicate code.


## Latest handoff — corrupt vault restore regression (2026-11-01 UTC)

- PR #37 branch `automation/issue-22-atomic-review`; parent source head `7254202d2347081cfc400d586577d1f67f47dc6a`; main baseline `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. Added a TEST ONLY pinned-Supabase-SDK/owned-runtime regression in `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart` for a malformed stored refresh value.
- Startup must fail closed before Auth token refresh or `ensure_profile`, retain the corrupt value until explicit cleanup, then require the sequence `read -> clear -> write` on explicit login. The new rotated refresh secret is verified before the own-profile barrier publishes readiness. This complements existing storage read/write/clear failures, late-response and account-switch cases.
- Updated `docs/PERSISTENT_SESSION_LIFECYCLE.md`; no production Auth/runtime, schema/RLS, frozen API, default activation, deployment or Pro-owned #14/#38/N4 files changed.
- Parent exact-head CI [41300703129](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41300703129), attempt 1, exact parent `7254202d2347081cfc400d586577d1f67f47dc6a`, completed SUCCESS: all six jobs (`repo-sanity`, `database`, `ai-boundary`, `supabase-integration`, `windows`, `flutter`) and every returned step succeeded. This is parent evidence only; the new regression has not run yet. The cloud runtime has no Flutter/Dart SDK, so local format/analyze/test/build were not run.
- Exact-head CI for the new commit is required. The fixture uses an invalid control-character value, TEST ONLY MockClient and an in-memory vault backend; it is not a native Credential Manager failure injection or hosted signed-JWT/PostgREST/RLS/learner proof. Keep PR #37 draft and #20/#22/#15 open; Pro #14/#38 remains untouched.
- Next: inspect all six latest-attempt jobs/every step on the new exact head; fix only observed failures. Hosted non-production learner A/B/expiry/restart and physical two-device offline sync remain external acceptance gates.


## Latest handoff — Windows OS-backed late refresh and account switch (2026-11-01 UTC)

- PR #37 branch automation/issue-22-atomic-review; parent head 6e6b5b036ccb7344a57359289a694d5022eb1437. Added a TEST ONLY runtime-late-refresh phase in apps/flutter_app/tool/windows_runtime_fixture.dart and registered it in apps/flutter_app/tool/verify_windows_vault_bridge.ps1.
- The probe runs the pinned Supabase SDK and caller-owned PersistentSupabaseRuntime through the production Dart MethodChannel and actual Windows Credential Manager, with a real NativeReviewJournal lease. It stores User A's synthetic refresh token, holds the startup refresh response, logs out/clears the OS slot, releases A's stale rotation response and requires no A profile/secret restoration. It then signs in User B, verifies exactly one B profile request with B's captured bearer, confirms B's rotated secret is readable from the OS vault before profile readiness, verifies B cannot read A's pending journal records, and logs out/clears B.
- Updated docs/WINDOWS_SESSION_VAULT.md, docs/PERSISTENT_SESSION_LIFECYCLE.md and the windows-session-vault QA anchors. Storage failure injection remains covered by the isolated pinned-SDK backend tests; this bridge case does not fabricate a native Credential Manager failure.
- Parent exact-head CI [41251469435](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41251469435), attempt 1, head 6e6b5b036ccb7344a57359289a694d5022eb1437: all six jobs (repo-sanity, database, ai-boundary, windows, supabase-integration, flutter) and every returned step completed SUCCESS. This is parent evidence only, not verification of the new source.
- New-source exact-head CI has not yet been observed at this checkpoint. No Flutter/Dart SDK is available in this cloud runtime; do not infer formatter/analyzer/test/Windows success from the parent run. Keep PR #37 draft and #20/#22/#15 open.
- Evidence limits: real Windows Credential Manager/MethodChannel/native journal plus pinned SDK, but Auth HTTP uses a TEST ONLY MockClient and unsigned synthetic JWT. No hosted Supabase, signed JWT, deployed RLS, real learner A/B, two-device sync, OS-logoff or hardware-power-loss acceptance. Default preview remains unconfigured and never simulates Auth/save success. Pro #14/N4 and PR #38 are untouched.
- Next: inspect every latest-attempt job/step for the new exact head; fix only observed failures. After CI, continue the remaining hosted non-production Auth/PostgREST A/B and learner acceptance when approved staging configuration is available.


## Latest handoff — Flutter analyzer correction (2026-10-31 UTC)

- PR #37 branch `automation/issue-22-atomic-review`; code commit `a28f0521dd5aa25e28522d4d06e22e6bcab4d6be`, parent `f100277130ffee47c833a71a82461a4e6c741a66`. In `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, changed two test-local closure-valued variables to local function declarations (`List<http.Request> profileRequests()` and `int authCalls()`) to satisfy the existing `prefer_function_declarations_over_variables` analyzer lint. No test assertions, HTTP fixtures, Auth/runtime behavior or timeouts changed.
- Exact-head CI [41247508208](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41247508208), attempt 1, source `f100277130ffee47c833a71a82461a4e6c741a66`: `repo-sanity`, `database`, `ai-boundary`, `windows` and `supabase-integration` completed SUCCESS. Flutter dependency resolution and Dart format completed; `flutter analyze` failed on exactly two `prefer_function_declarations_over_variables` infos at lines 292 and 296. Flutter tests and downstream Flutter checks were skipped by fail-fast. The lint-only correction is committed as `a28f0521...`; this does not make the failed parent run pass.
- Current-head CI for `a28f0521...` is required. No Flutter tests/analyze/build on the corrected head are yet claimed; no local Flutter SDK is available in the cloud runtime. Do not merge while the corrected-head checks are pending or failed.
- Scope is one test file plus this status handoff. No production Auth, vault, RLS, migration, API, dependency, preview-default, N4 content or Pro-owned paths changed. #20/#22/#15 and hosted learner acceptance remain open; PR #37 stays draft.
- Next worker: inspect all latest-attempt jobs and every step for the exact current PR head; fix only newly observed failures. Keep the core worker single-writer and preserve the separate Pro #14/N4 branch.

## Latest handoff — credential clear failure retry guard (2026-10-31 UTC)

- PR #37 branch `automation/issue-22-atomic-review`, parent head `59e9c5965bdc747b0d1ac06673522d9c4c252fcf`. Added a pinned-Supabase-SDK/owned-runtime regression in `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`: when User A's vault clear fails during logout, the account remains fenced, no User B Auth/profile request is dispatched, and a successful explicit cleanup retry is required before B can persist its own rotated secret and load B's profile.
- Updated `docs/PERSISTENT_SESSION_LIFECYCLE.md` with the failure boundary and evidence limits. The new test uses TEST ONLY in-memory OS/HTTP ports; it is not a Windows Credential Manager failure injection or hosted Auth proof.
- Exact-head CI for the resulting commit is required; this status entry records implementation intent, not a test pass. Keep #20/#22/#15 open and PR #37 draft. Hosted JWT/PostgREST learner A/B, two-device sync and release evidence remain outstanding. No Pro #14/N4 paths changed.

## Latest handoff — local Supabase Auth/PostgREST integration (2026-10-31 UTC)

- PR #37 branch `automation/issue-22-atomic-review`, parent `4b25515dc4a27dcab5c748c38ba854824ba26f06`. Added a pinned Supabase CLI local stack gate using GoTrue, PostgREST and PostgreSQL 17; no hosted URL, key, service-role credential, deployment or Auth strategy change.
- New `supabase/config.toml` is local-only; `supabase/tests/local_integration_seed.sql` inserts one synthetic active vocabulary item only after a disposable local reset. `scripts/test_supabase_local.py` uses local user tokens and anon key to verify two real Auth users, refresh rotation, logout revocation, signed-expired JWT rejection, caller-derived profile bootstrap, atomic review replay/conflict and A/B RLS.
- CI adds `supabase-integration` with Supabase CLI 2.122.0 via pinned setup action SHA. This run has not yet produced an exact-head CI result; pending CI is not pass evidence. The Python script is authored but has not been executed in this cloud runtime.
- This is actual local GoTrue/PostgREST integration, not hosted Supabase learner evidence. Keep #20/#22/#15 and Personal Alpha open; next worker must inspect all exact-head CI jobs/steps and fix only observed failures. No Pro #14/N4 paths changed.


Current release target: Personal Alpha
Overall status: IN_PROGRESS — starter baselines #1–#8 merged; real learner flows, N5/N4 expansion and live integrations remain outstanding.

## Core session-lifecycle checkpoint — 2026-11-02 UTC

- Resumed draft PR #37 on `automation/issue-22-atomic-review` at parent `b9eaa458914fd5f41dca1da216d856821a8ff436`. Exact-head CI [41387850885](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41387850885) ran all six jobs: five jobs and every step succeeded; Flutter format/analyze succeeded, but the test suite reported 392 passed / 1 failed at `persistent_supabase_runtime_test.dart:406` (expected 3 credential clears, observed 4). All Flutter downstream lifecycle/native/web checks and web build were skipped after the test failure.
- Root cause: the owned runtime intentionally listens to both the review binding stream and raw Supabase Auth stream so same-session refresh-token rotations are observed. The raw listener forwarded every queued Auth event, bypassing the review binding's stale-session filter and allowing an old null/sign-out notification to enqueue a fourth vault clear after account B became current.
- Bounded correction: expose one validated current-session predicate from `SupabaseReviewBinding`, apply it to both binding and raw persistence event delivery, and ignore stale non-null lifecycle events without revoking a newer valid SDK session. Genuine current-session sign-out and no-current-session events still revoke. Added a focused predicate regression and retained the full SDK A-to-B test's exact three-clear, B-token, captured-profile-bearer and readiness assertions.
- Changed paths for this increment: `apps/flutter_app/lib/features/srs/data/supabase_review_binding.dart`, `apps/flutter_app/lib/features/auth/application/persistent_supabase_runtime.dart`, `apps/flutter_app/test/features/srs/supabase_review_binding_test.dart`, `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, and this file.
- Verification for the new source head is pending GitHub Actions. Do not infer a pass from parent CI. Cloud runtime has no Flutter/Dart SDK or Windows OS; no local Flutter format/analyze/test/build/native execution or hosted learner JWT/A-B proof is claimed.
- Next: inspect every latest-attempt job and step on the exact new commit; fix only observed diagnostics. Keep PR #37 Draft and #20/#22/#15 open until hosted learner A/B, expiry/restart and multi-device acceptance is recorded. Pro-owned #14/#38/N4 scope remains untouched.

| Milestone | Status | Owner / prerequisite |
| --- | --- | --- |
| Architecture baseline | MERGED via PR #10; #1 completed | Lead |
| Flutter skeleton | MERGED via PR #19; #2 completed | #2 Flutter |
| Supabase schema/auth | MERGED via PR #21; live Auth tracked in #20 | #3 Backend |
| SRS engine | Pure nd-srs-1 MERGED via PR #24; PR #37 draft includes atomic SQL/SDK/UI/durable recovery/profile readiness; live integration pending | #4 / #22 / #20 / #15 |
| Kanji writing engine | MERGED via PR #29; capture/synthetic core; real assets #16 | #6 Kanji |
| AI tutor | MERGED via PR #32; runtime bridge #31 / live providers #17 | #7 AI |
| N5/N4 content pipeline | N5 seed MERGED via PR #27; expansion #26 / N4 #14 | #5 completed |
| QA/security baseline | MERGED via PR #35; #8 inventory completed | #18 integrated release still pending |

## Historical handoff — Issue #1, 2026-10-13

- Completed: resolved rating/units/date/retry/ownership ambiguities; 37 named schema definitions, eight endpoint bindings, 20 fixtures, validator and 15 regression tests; dependency and merge order documented.
- Remaining: Flutter #2, database/RLS #3, SRS #4, curriculum #5 and remaining Personal Alpha modules.
- Changed files: contracts/v0.1/*, contracts/validate.py, contracts/test_contracts.py, contracts/requirements.txt, API_CONTRACTS, DATABASE_SCHEMA, ARCHITECTURE, CONTRACT_BASELINE, this status, README, CI workflow.
- API changes: typed definitions for eight already-planned operations; RPC/Edge boundaries, safe errors, bounded outputs and scoped retries.
- Database changes: specification only; user-scoped review uniqueness/original-result receipts, conversation receipts, parent-message ownership, integrity and validated write requirements. No migration applied.
- Known issues: no Flutter app or live service; fixture validation does not test deployed RLS/providers. Audio streaming/upload contract remains later work.
- Tests: local validator passed all 20 fixtures and all 15 regression tests passed. PR/current-head CI is the integration gate; see #1/its PR for evidence.
- Next task: #2 Flutter shell after #1 integration, without external credentials.
- Blockers/decisions: none for #2; live Supabase/AI/voice configuration is addressed when integration is implemented.

Personal Alpha gaps are queued as #11–#18; see CONTRACT_BASELINE for the map. Issue #16 provides real Kanji reference assets, while #6 can start synthetic primitives after #2.

## Latest handoff — Issue #2 / PR #19, 2026-10-13

- Branch: automation/issue-2-flutter-shell; base main 33f31a8 (PR #10).
- Implemented: Vietnamese Material 3 adaptive shell, GoRouter module discovery and
  unavailable pages, Riverpod-injected typed demo repository, session-only N5/N4
  and theme settings, loading/error/retry/empty handling, regression tests.
- Changed files: apps/flutter_app, README, CI workflow, .gitignore, this status.
- API/database changes: none; demo allocation does not implement get_daily_plan.
- Checks: contract validator passed 20 fixtures; 15 contract regression tests passed.
  Flutter format and analyze passed (no issues); 22 Flutter tests passed, including
  200% text on 320/375px layouts after fixing the theme dropdown overflow. Web
  release build succeeded locally again with the final dependency lock, including
  the optional Cupertino icon font. Local source matches the uploaded tree
  2554e82a1b6e5c8f787fba350bbfe8e734022bfa (code head 20e3088 before this status update).
  Exact-head CI and Windows build evidence are tracked in
  https://github.com/collab-TTAM/nihongo_daily/pull/19/checks; repo-sanity, flutter
  (format/analyze/22 tests/web build), and windows (release build) must all pass
  before integration. Artifacts: flutter-web-preview and flutter-windows-preview.
  CI run 38407859810 passed repo-sanity and all Flutter checks, but Windows failed
  because windows-latest supplied VS 2026 and Flutter 3.35 selected the fallback
  VS 2019 CMake generator. The Windows job is now pinned to windows-2022 / VS 2022;
  no checks were removed. Current-head rerun remains the integration gate.
  Direct browser smoke was not observed:
  the local headless Chrome process crashed before the app could load.
- Known limitations: real content, auth, storage, sync, SRS, scoring, progress,
  providers and voice remain unimplemented; preview routes state this explicitly.
- Next: integrate #2 only after separate review and current-head CI; then #3
  Supabase schema/RLS. #4 can use the Dart package after #2 merge.
- Blockers: none requiring user input. Native Windows launch, iOS runner,
  signing and device validation remain later work.

## Integrated handoff — Issue #3 / PR #21, 2026-10-13

- Merged: PR #21 (https://github.com/collab-TTAM/nihongo_daily/pull/21) as
  4dd5e134ec2bfdc93bac97ed796ba882c9e98af6; #3 completed. Shared contracts #1 and
  Flutter preview #2 are also integrated; earlier handoffs above are historical.
- Delivered: additive 22-table migration; owner/parent-message RLS; explicit
  table/column grants; allowlisted own-profile settings; backend-only scenario
  context; immutable review requests/original responses; typed curriculum FKs;
  normalized relationship FKs, indexes and checked receipt state.
- Evidence: separately reviewed head 240ef15190dbaa3ffc191cf212dba7a8c262e686.
  CI https://github.com/collab-TTAM/nihongo_daily/actions/runs/38421789675 succeeded:
  repo-sanity (20 contract fixtures, 15 tests), database (250 SQL assertions plus
  two native concurrent sessions committing exactly one event), flutter
  (format/analyze/22 tests/web release build), windows (release build).
- Local checks: the migration/SQL suite passed on PostgreSQL 18.6 via PGlite 0.5.9;
  contract fixtures/tests, bash syntax, Python compilation and whitespace passed.
  Native PostgreSQL 17 evidence comes from CI, not this local environment.
- Review fixes: canonicalize Asia/Saigon to Asia/Ho_Chi_Minh with UTC+7 conversion
  checks; use FOR SHARE for active-content validation; revoke inherited service-role
  TRUNCATE; verify restrictive FK rejection and unchanged curriculum/history across
  observed native PG17/local PG18 error codes. No security/test gates removed.
- Not delivered: hosted Supabase/PostgREST/Auth, public submit_review, account
  lifecycle, real providers, offline sync or production deployment. Storage replay
  is not a functioning review endpoint, and the UI remains a labeled demo.
- Follow-ups: #20 real Auth/session lifecycle; #22 authenticated atomic review RPC
  after #4 pure scheduler; #7 provider-neutral validated interfaces; #17 live
  AI/voice. Read supabase/README.md for storage/export mapping and safe test setup.
- Next task: #4 deterministic pure Dart SRS on automation/issue-4-srs-core, then
  #5 original N5 content according to dependency order. #4 needs no live secrets.
  Main stays IN_PROGRESS toward Personal Alpha; no release completion claimed.

## Integrated handoff — Issue #4 / PR #24, 2026-10-13

- Merged: https://github.com/collab-TTAM/nihongo_daily/pull/24 as
  d4ed337dc8a5bcce46bc830e0e10528b8bd04e56; #4 completed as a pure scheduler.
- Delivered: immutable Dart card/request projections, nd-srs-1 rating/transition
  rules, bounded learning/relearning/early/overdue intervals, capped review growth,
  validated counters/difficulty and deterministic UTC duration arithmetic.
- Evidence: reviewed head 7e656d445bbca00216f601fc203f14f923068b03; all jobs succeeded at
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38426443750:
  repo-sanity (20 baseline fixtures/17 regression tests), database (retained SQL/RLS
  and native race), Flutter (format/analyze without issues, full unit suite,
  26 policy cases and actual Dart output/schema validation, web release build),
  Windows (release build). Separate source and verifier lint-fix reviews recorded.
- Local evidence: raw pure-Dart execution and actual-output validation of all 26
  cases, domain/tool analysis, formatting, 17 Python tests and whitespace/syntax.
  Full Flutter package resolution was unavailable locally; full unit/build evidence
  comes from CI. No browser/native interactive smoke or hosted integration claim.
- Shared fields/enums are unchanged. docs/SRS_ALGORITHM.md specifies the heuristic,
  rounding and #22 backend parity/auth/locking/replay requirements. Versioned
  golden cases are contracts/srs/v1/golden.json. No calibrated memory prediction.
- Not integrated: SRS UI study flow, public submit_review, stored receipt replay,
  auth or durable offline persistence. #22/#15/#20 retain these responsibilities.
  MASTERED remains reserved; memory stability/retrievability are not estimated.
- Next task: #5 original schema-valid N5 seed content. #22 can now port the pure
  scheduler with authoritative transaction tests; #11's #2/#3/#4 dependencies are
  satisfied. Live configuration does not block original content work.
- Personal Alpha remains IN_PROGRESS with curriculum, study screens, real auth,
  sync, Kanji, AI/voice and integrated release evidence still outstanding.

## Development handoff — Issue #5, 2026-10-13 UTC

- Branch automation/issue-5-n5-seed, base main 73c1dc8. Original editorial N5
  seed: 24 vocabulary, 8 Kanji, 10 grammar and 44 embedded example entries.
  Stable IDs, version/count/scope manifest, Vietnamese explanations and readings.
- Added strict offline export gate and 17 mutation/regression tests; CI runs the
  gate and all existing tests. Wire models, Flutter source and database unchanged.
- Local: content/schema/count/reference validation passed; 20 baseline fixtures
  and all 34 Python tests passed; Python compile/whitespace passed. Eight stroke
  counts cross-checked against pinned KanjiVG metadata; assets not redistributed.
- Flutter SDK/native PostgreSQL are absent locally. Existing full Flutter format,
  analyze/tests/SRS output validation, web/Windows builds and SQL/race checks must
  pass in CI for the PR's exact head before integration; no such result claimed yet.
- Not full N5/N4 curriculum; no audio, reference strokes, importer, hosted service
  or UI integration. Linguistic correspondence manually reviewed by the worker;
  independent teacher review is not observed. Details/provenance in data/README.md.
- Resume this PR first, then #6 Kanji capture/synthetic primitives. #26 tracks N5 expansion; #14 can extend
  the content gate with N4; #12 consumes original exports; #16 provides real assets.
  Personal Alpha remains IN_PROGRESS; no new user action is needed for #6.

- Separate review fix: reject duplicate JSON object members and fullwidth romaji
  readings; two mutation regressions added. No validation/security gate weakened.

## Integrated handoff — Issue #5 / PR #27, 2026-10-13 UTC

- Merged PR #27 as d5afac06f129f1c9ae899bd3827b24dfc89ae8d6; #5 completed.
  Separately reviewed exact head d1756a389895e7910d0fe6ff20b8d684006558fb.
- Original seed: 24 vocabulary, 8 Kanji, 10 grammar and 44 embedded examples with
  kana readings/Vietnamese text; stable IDs and honest scope/count/asset manifest.
  Pinned metadata provenance and linguistic notes are in data/README.md.
- Evidence: https://github.com/collab-TTAM/nihongo_daily/actions/runs/38443120630
  completed successfully; repo-sanity, database, flutter and windows all passed.
  repo-sanity validates the exports, 20 baseline fixtures and 34 Python regressions.
  Flutter retained format/analyze/full tests, 26 SRS policy cases and actual-wire
  schema checks/web release build; Windows release and SQL/RLS/native race passed.
- Local checks: 34 Python tests, content/contracts, Python compile, manifest schema,
  forbidden-file and whitespace checks. Local Flutter/native PostgreSQL unavailable;
  their evidence is CI, not local execution. Remote uploaded tree matched reviewed
  local files. No interactive browser/native or hosted service validation claimed.
- Review fixes: duplicate JSON object members and fullwidth romaji are rejected.
  No frozen wire schema, RLS, migration, Flutter or provider change.
- Limits: small editorial seed, not complete N5/N4 support. No audio/stroke geometry,
  importer or content UI integration; independent teacher review not observed.
  #26 tracks N5 scope/expansion, #14 N4, #12 study and #16 real reference assets.
- Next: #6 Kanji capture/normalization and synthetic scoring primitives, with #2
  and #1 already merged. No external credential blocks this work. Resume any open
  evidence PR first. Personal Alpha remains IN_PROGRESS with live integration,
  broader curriculum, offline/sync and release acceptance still outstanding.


## Development handoff — Issue #6, 2026-10-13 UTC

- Fresh main 8559956 includes merged #5 evidence PR #28; no open PR on claim.
  Branch automation/issue-6-kanji-capture, one sequential worker.
- Added pure immutable normalized models, bounded single-pointer capture, undo/
  clear, square mouse/touch/stylus prototype and synthetic-only geometric scores.
  Real grading is explicitly unavailable; no canonical assets or persisted progress.
- Local SDK exists but Flutter dependency bootstrap cannot complete in this
  environment. Raw Dart capture/scorer verifier passed and emitted two actual
  schema-valid requests; full Flutter analyze/tests/build and database/Windows
  checks require observed exact-head CI before integration.
- Added domain/widget regressions and actual-wire CI gate; no dependencies or
  frozen contracts/auth/RLS changed. docs/KANJI_CAPTURE.md records heuristic/limits.
- Resume this PR and CI first; after integration next worker task is #7 validated
  AI interfaces. #16 still gates real stroke assets/grading. Personal Alpha remains
  IN_PROGRESS; no hosted/backend/recognition/real-grade claim.

- Separate review fix: enforce event-time monotonicity even for coalesced stationary
  samples; added targeted regression. Added spacing for readable canvas guidance.


## Integrated handoff — Issue #6 / PR #29, 2026-10-13 UTC

- Merged PR #29 as 9d66f36123e5a2a958cf4a1c1b2177bbf5a46494; #6 completed.
  Separately reviewed/tested head 2743ed2e0388d2aaa69f2bf4282c6931a00c58f9.
- Delivered immutable finite/bounded square-coordinate models; single-pointer
  capture with relative monotonic time, boundary clamp, cancel/tap/limit handling,
  undo/clear; local Riverpod prototype on /kanji for mouse/touch/stylus.
  Pure nd-kanji-synthetic-1 primitives compare shape/order/direction/balance.
- Evidence: https://github.com/collab-TTAM/nihongo_daily/actions/runs/38446275479
  succeeded with all four jobs. Flutter format/analyze (no issues), 91 tests
  (21 new domain/6 widget tests), 26 SRS wire cases, 2 actual Kanji capture encodings
  validated against frozen schema, web release build; Windows release and retained
  database/RLS/native concurrent uniqueness passed. No required job skipped.
- Local evidence: raw Dart identity/reversal verifier, actual request schema,
  authored content/20 baseline fixtures/34 Python regressions, formatting/Python
  compilation/whitespace. Flutter dependency bootstrap unavailable locally; full
  Flutter/native PostgreSQL evidence comes from CI. All 15 uploaded files matched
  reviewed local hashes. No interactive browser/native device launch observed.
- Review fix: decreasing time after stationary/coalesced input cancels the stroke,
  with regression. Documentation distinguishes pure engines from integrated flows.
  No auth/RLS/dependency/provider/frozen-schema changes or weakened gates.
- Limits: no persisted Kanji attempts, curriculum selection, tracing/animation,
  canonical reference assets or real grade. evaluateReal explicitly reports
  reference absence; synthetic scores never appear as learner grades. #16 retains
  vetted assets/real grading work; docs/KANJI_CAPTURE.md records heuristic limits.
- Next sequential worker task: #7 provider-neutral validated AI interfaces after
  any open evidence PR. No secret/configuration needed for pure adapter tests;
  #17 still owns live services/voice. Personal Alpha remains IN_PROGRESS.


## Development handoff — Issue #7, 2026-10-13 UTC

- Branch automation/issue-7-ai-boundary; fresh main 59506e2, no open PR on claim.
- Added server-only provider-neutral TypeScript contracts/ports, strict original
  JSON Schema validation, immutable bounded requests/context, auth/rate guard,
  safe Vietnamese errors and deadline/abort handling. No live provider configured.
- Added private durable SQL receipt lookup/claim/token-completion, permission tests
  and native two-session claim race. Pending uncertainty never renews dispatch;
  lookup-only recovery must validate/correlate an existing result.
- Local: TypeScript check/format and 38 Node tests passed, original 34 Python tests,
  20 contract fixtures/content checks, Python compile/bash syntax/whitespace passed.
  Native PostgreSQL/full Flutter/web/Windows checks require exact-head CI; no such
  result claimed until observed. Existing CI gates retained; ai-boundary job added.
- Limits: injected test Auth/limiter/context/provider/memory store only; no deployed
  Edge/Deno compatibility, distributed runtime limiter, complete conversation
  transaction adapter, live provider, Flutter AI UI or voice. Follow-up runtime
  binding #31 must prove ownership/sequence/restart/reconciliation; #17 live/voice.
- Resume PR/CI/review first. After #7 merge next sequential task #8 QA matrix.
  Personal Alpha remains IN_PROGRESS; no external configuration needed for #8.

- Local additive migration, retained SQL/RLS suite and new AI receipt/security
  assertions passed on PGlite 0.5.9; native multi-session concurrency still needs CI.

- Separate review fixes: reject empty/oversized dispatch tokens before provider
  calls, freeze validated outputs/recovered context before asynchronous persistence,
  with two targeted regressions. No security/test gate weakened.

- Dependency audit found moderate Ajv advisory GHSA-2g4f-4pwh-qvx6; $data is
  disabled, and Ajv was upgraded from 8.17.1 to pinned 8.20.0 before integration.
  Added production dependency audit gate; current-head CI must rerun.

- UUID compatibility review: prepared-session binding compares logical UUIDs
  case-insensitively, while receipt comparison keeps immutable request fields.
  Added an uppercase client UUID regression; no auth/ownership check weakened.


## Integrated handoff — Issue #7 / PR #32, 2026-10-13 UTC

- Merged PR #32 as edb6465ed07af54ee2495be706afc2712382efb1; #7 completed.
  Separately reviewed/tested head e3200bc60c58e175d3d0414621f06c6d0b887467.
- Delivered provider-neutral server TypeScript interfaces for five frozen AI
  operations, original-schema validation/generated types, bounded immutable
  request/context/result, required verified-auth/rate/context ports, server identity
  and curriculum-ref checks, safe Vietnamese errors and deadline/abort handling.
  Private invoker receipt lookup/claim/token-completion helpers preserve ownership,
  original replay and pending uncertainty; recovery never dispatches a new call.
- Evidence: https://github.com/collab-TTAM/nihongo_daily/actions/runs/38452125458
  succeeded with all five jobs: repo-sanity, ai-boundary, database, flutter, windows.
  AI format/strict TypeScript/generated-type checks and all 38 Node tests passed;
  production dependency audit reported zero findings. Native PostgreSQL passed
  28 added AI SQL/security assertions and two-session dispatch claim race, retaining
  existing SQL/RLS/review uniqueness tests. Flutter retained 91 tests, analyze with
  no issues, SRS/Kanji actual-wire gates and web release; Windows release passed.
- Local: Node checks/tests, 34 Python regressions, 20 baseline fixtures/content,
  PGlite 0.5.9 migrations/SQL/RLS/AI assertions, Python compilation/bash syntax and
  whitespace. Native concurrency/full Flutter build evidence is CI, not local.
  Uploaded initial/patched trees matched 21 reviewed local files; no secrets.
- Review fixes: frozen output/recovery context, invalid dispatch token, equivalent
  UUID capitalization; Ajv moderate GHSA-2g4f-4pwh-qvx6 audited/patched to 8.20.0
  ($data disabled), production audit gate added. No test/security gate weakened.
- Limits: no deployed Edge/Deno proof, real Supabase Auth verification, distributed
  runtime limiter, actual conversation session/message transaction adapter,
  real provider, Flutter AI UI or voice. Test ports are explicit fixtures and do
  not count as integrations. #31 tracks trusted runtime/transaction/reconciliation
  binding; #17 live provider/voice, #20 account lifecycle, #18 integrated evidence.
  docs/AI_BOUNDARY.md details scope and safe pending recovery requirements.
- Next sequential worker task: #8 reproducible QA/security regression matrix after
  any open evidence PR. No external configuration needed for that inventory.
  #31's library dependency is resolved; real hosted/provider evidence remains
  pending configuration. Personal Alpha stays IN_PROGRESS beyond starter tasks.


## Development handoff — Issue #8, 2026-10-13 UTC

- Fresh main 98397e72; no open PR on claim. Single sequential worker on
  automation/issue-8-qa-matrix. #1–#7 implementation/evidence already merged.
- Added 27-case machine-readable QA matrix: 13 executable baseline groups with
  concrete test anchors, reproduction/scope limits; 14 pending integrated release
  cases. Six ranked findings distinguish missing assurance from a proven exploit
  and the remediated Ajv advisory. Created #34 for unassigned Listening/Reading.
- Added standard-library inventory and exact-head Actions evidence verifier:
  explicit repository/workflow/head/run/attempt, all five jobs/critical steps,
  complete pagination, no missing/skipped/pending/mixed results. CLI never executes
  matrix commands or certifies metadata authenticity. Synthetic test data is TEST ONLY.
- Local: 17 QA negative regressions, original 34 Python tests, 20 frozen fixtures
  and content export checks passed. Prior-main CI 38453557158 passed all five jobs;
  this is historical, not the #8 head. Full current-head Node/SQL/Flutter/web/Windows
  CI must be observed before integration. No new runtime/provider/migration change.
- QA_SECURITY_MATRIX documents reproduction, evidence retrieval, ranked findings
  and the unchecked release checklist. Baseline green cannot pass --release while
  live Auth/RPC/plan/study/content/assets/Edge/AI/voice/sync/progress/smoke/journey
  evidence remains pending; no Personal Alpha completion claim.
- Resume #8 PR/CI and separate review first; next priority #22 authenticated atomic
  review transaction, then #31 runtime bridge and #11 plan/session work by dependency.
  Local implementation can proceed without secrets; hosted evidence remains pending.

- Separate review hardening: verify command/step anchors within their actual CI
  job, so moving an audit elsewhere cannot preserve coverage; reject removed
  ranked findings and out-of-repository test anchors. Three regressions added.

## Integrated handoff — Issue #8 / PR #35, 2026-10-13 UTC

- Merged https://github.com/collab-TTAM/nihongo_daily/pull/35 as
  250cc1ff2c21da876ce7a8e9004b77c0bb6145ef; #8 completed as QA inventory/evidence tooling.
  Separately reviewed/tested head 7ee60f0f54297231147e1dd7ac1e1fe4662ea6fd.
- Delivered qa/matrix.json: 27 assurance cases (13 executable baseline groups,
  14 pending integrations), exact file/statement anchors, reproduction commands,
  issue owners and limits; six severity-ranked findings distinguish five missing
  assurance gaps from the already patched dependency advisory. docs/QA_SECURITY_MATRIX.md
  maintains the reproduction/evidence instructions and unchecked release checklist.
- Standard-library verifier rejects stale head/repo/workflow, mixed run/attempt,
  incomplete pagination, missing/duplicate/unreviewed jobs or steps and non-success
  states. It never executes matrix commands or authenticates saved metadata.
  CI now validates inventory and all 17 QA regressions, retaining every prior gate.
- Evidence: https://github.com/collab-TTAM/nihongo_daily/actions/runs/38455196645
  succeeded with all five jobs: repo-sanity (17 QA, 34 existing Python tests,
  20 frozen fixtures/content), ai-boundary (38 Node tests/format/type/generated
  checks, zero production audit findings), database (retained SQL/RLS and both
  native concurrency races), flutter (analyze without issues/tests/SRS/Kanji
  actual-wire checks/web release), windows (release build/artifact).
- Fetched unmodified workflow run and complete latest-attempt jobs via connected
  GitHub; verifier accepted exact-head evidence. Prior-main CI was rejected for
  missing the new QA step. With the real successful CI snapshot, --release
  intentionally returned nonzero because 14 integration cases remain pending.
  No release completion, interactive device/browser or hosted-service claim.
- Local: 17 QA regressions, 34 Python tests, contract/content checks, compilation
  and whitespace passed. Remote uploaded tree c462f344 matched reviewed local
  files. Full Node/native SQL/Flutter/Windows results came from current-head CI.
- Review hardening: scope step anchors to their actual job, reject test paths
  outside the repository and removal of ranked findings. No wire/auth/RLS,
  runtime/provider/migration changes or weakened checks.
- Follow-up #34 covers the previously unassigned Listening/Reading module with
  honest audio availability and valid-session/retry requirements. Existing issues
  retain all auth, RPC, plan/study, N5/N4, real Kanji, AI/voice, sync and progress gaps.
- Next sequential task: #22 authenticated atomic submit_review, whose schema/SRS
  dependencies are merged. Implement local SQL/typed adapter/transaction evidence
  without waiting for live secrets; do not close #22 without its full acceptance.
  Then #31 runtime binding and #11 plan/session work by dependency. #18 remains
  blocked by integrated Personal Alpha evidence; independent development continues.


## Development handoff — Issue #22 server transaction increment, 2026-10-13 UTC

- Fresh main 78a44faf; no open PR on claim. Single sequential worker on
  automation/issue-22-atomic-review; #3/#4 schema/policy dependencies are merged.
- Added strict seven-field request/canonical instant/response helpers, private
  nd-srs-1 SQL port and narrow authenticated caller-bound submit_review(jsonb).
  No direct table grants/RLS weakening or auth strategy/provider/deployment change.
- Owner mutex + content share lock/item row lock provide replay-before-stale,
  active-content/five-minute skew validation and atomic event/state/counter writes.
  Exact raw fractional identity/chronology survives microsecond scheduling;
  reserved memory fields remain unchanged. Corrupt stored responses fail closed.
- Local observed: migration/retained baseline/AI and 62 new RPC SQL assertions
  passed on PostgreSQL via PGlite 0.5.9; actual private SQL outputs matched all
  26 frozen Dart policy cases. 40 Python regressions, 17 QA tests and inventory
  passed. Six Python parity-validator regressions are TEST ONLY fixtures.
- Five native race scenarios authored; native PostgreSQL and full Node/Flutter/
  web/Windows CI remain current-head acceptance checks until observed. Local
  PGlite cannot certify two-session/native concurrency or real JWT/PostgREST.
- docs/SRS_RPC.md records transport wrapper, normalization/resource limits,
  permissions, serialization/rollback policy and evidence limits. QA matrix now
  has 28 groups; review-rpc remains a pending integration release case.
- This is a complete SQL increment within an incomplete #22. Keep issue/PR open:
  typed Flutter adapter, integrated SRS UI and real Auth/PostgREST acceptance
  remain. Resume this draft/review/CI first, then implement typed transport/UI
  without presenting fixtures as live integration. No secrets requested in chat.
  Personal Alpha remains IN_PROGRESS; do not close #22 from SQL fixture success.

- Separate review: native race harness now observes the second backend actually
  waiting on the advisory lock before releasing the first transaction; no timing
  guess/sequential replay can count as concurrency. Clarified private invoker vs
  narrow public definer documentation. Keep draft for remaining full #22 gates.


## Sequential resume — Issue #22 typed repository, 2026-10-13 23:04 UTC

- Resumed existing draft PR #37 / automation/issue-22-atomic-review after its
  unchanged head 7018a339 and no newer worker activity for three hours. Fresh
  main remains 78a44faf; no other open PR. No parallel worker/agent.
- Observed all five jobs successful for SQL head 7018a339 at
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38459542474, including
  native PostgreSQL/RLS/62 RPC assertions, 26 SQL/Dart cases and five lock-observed
  concurrency scenarios, retained Flutter/web/Windows and AI gates. That run is
  historical SQL-head evidence, not evidence for this new Dart increment.
- Added typed ReviewRepository/RpcReviewRepository using injected Auth/RPC ports,
  immutable session-bound events, strict five-field success/three-field errors,
  safe fixed Vietnamese messages, timeout uncertainty and old-session isolation.
  No scheduler/client-derived writes, automatic retry or direct table calls.
- Added 21 Flutter regressions plus a raw-Dart verifier: actual encoder/decoder
  outputs for 26 original server-response fixtures, invalid data, timeout/immutable
  retry and session replacement. Fixture ports/responses are TEST ONLY and cannot
  count as SQL-to-Flutter, live Auth, actual retry-after-later-reviews or UI evidence.
- Local raw-Dart verifier and 26 encoded schema pairs passed; 40 Python tests,
  17 QA tests and inventory passed before final docs/CI changes. SDK dependency
  bootstrap cannot complete here, so full Flutter analyze/tests/web/Windows and
  all final-head gates require observed GitHub Actions before any success claim.
- QA now tracks 29 cases; new fixture adapter group and CI steps are explicit.
  All 14 integration release cases stay pending. No frozen contract/dependency,
  Auth strategy/RLS, data collection/provider, production or release change.
- Keep #22 open and PR #37 draft. Next worker resumes final-head CI/review, then
  concrete SDK/Auth binding and SRS UI/queue acceptance with #20/#15; independent
  implementation still needs no secrets in chat. Personal Alpha IN_PROGRESS.

- CI 38482842040 passed repo-sanity/AI/database at head 74a8d110, but Flutter
  analyze found one missing if block and one untyped empty test list. Both were
  fixed without relaxing lint/tests; all final-head checks must rerun. Flutter
  tests/builds skipped after failed analysis are not counted as success.

## Sequential resume — Issue #22 SRS screen readiness, 2026-10-13 23:55 UTC

- Fresh main 78a44faf; only open PR is existing draft #37 at b0375f67. Prior worker
  released. All five jobs at CI 38483096635 succeeded for the typed repository,
  including 112 Flutter tests/web/Windows and native SQL/RLS/parity/races. This is
  prior-head evidence, not evidence for this new UI increment.
- SDK/Auth/real due queue are not configured. Continue independent application/UI
  work on the same branch, not a new issue/PR: pure SRS controller, typed queue
  projection, Riverpod lifecycle binding and /srs load/reveal/rate/save/retry flow.
  Default runtime is null; no fake due content, account, confirmation or progress.
- One immutable prepared event; controls lock during save; uncertain retry keeps
  original rating/ID/time/duration. No reload discards an uncertain event; explicit
  definitive conflict/rejection permits reload. Only validated receipt advances
  local acknowledged count. No Daily Plan/mastery/server-state overwrite.
- Session callbacks clear old visible curriculum/receipt and invalidate asynchronous
  replies by generation; route navigation retains in-memory pending state, not
  app restart. Closed lifecycle stream disables runtime. No credentials or disk
  storage added. Real SDK/Auth/cache/queue/reconciliation are #20/#15/#22 work.
- Local raw-Dart controller/repository verifier passed 26 TEST ONLY fixture pairs,
  reveal-before-rating, uncertain immutable retry and session-change suppression;
  emitted request/response schema check passed. Pure source/tool analysis passed;
  40 Python and 17 QA tests passed before final CI/documentation changes.
- Flutter dependency bootstrap is unavailable locally; full format/analyze/unit/
  widget/web/Windows and retained database/AI gates must be observed in current-head
  CI. New tests include accessible 320/375px UI at 200% text and controller failure/
  duplicate/disposal/deadline bounds. 30 QA groups, all 14 integration gates pending.
- No dependency/schema/Auth strategy/RLS/deployment/cost/data collection change.
  Review diff separately; resume PR #37 CI first. Keep #22 open/PR draft; next
  increment is concrete SDK/Auth/queue binding and durable event integration with
  non-production evidence. Independent work continues; no secrets requested.

- First UI CI 38488298013 passed repo/AI/database but found one router format
  difference after full Flutter package resolution. Reproduced with the correct
  local package language version and formatted that route; no format/analyze/test
  gate changed. Skipped later checks are not counted as passes; rerun final head.

- Follow-up CI 38488570435 passed formatting, but analyze found a missing direct
  ReviewRating domain import and three multiline if blocks without braces. Fixed
  import/blocks without changing behavior or weakening lint; full test/build
  evidence still requires the next exact-head run.

## Sequential resume — Issue #22 due-queue bridge, 2026-10-14 00:57 UTC

- Fresh main 78a44faf; resume only open draft #37 at 104dcdd8 after previous worker
  released. All five prior-head jobs at CI 38488768979 passed, with 139 Flutter
  tests/web/Windows and retained SQL/RLS/races. That is not new-head evidence.
- Actual due data read was missing behind the SRS UI's abstract queue. Added
  separately versioned nd-review-queue-1 contract and local get_review_queue RPC:
  stable invoker, empty search_path, existing RLS plus explicit auth.uid owner,
  provisioned profile, reviewed/due/active/level/order/bounded-limit read snapshot.
  No v0.1 operation/field, table/RLS grant, enrollment or derived-state write changed.
- Added strict RpcSrsStudyQueue/ReviewQueueSnapshot: ownerless captured-session
  envelope, limits/fields/UTC precision/due/order/duplicates, safe errors/deadline,
  old-session rejection. Canonical grammar reading is explicitly absent, not an
  example pronunciation; UI shows that absence instead of fabricated content.
- Added native SQL read/security/filter/assertions and actual seven-case response
  export. Flutter now depends on database and consumes the same-run artifact for
  actual SQL fixture output -> Dart DTO/RPC projection -> schema checks. Original
  full tests/builds/races retained; missing/skipped/past-head artifacts cannot pass.
- Local pure Dart DTO/RPC verifier and schema passed seven HAND-AUTHORED TEST ONLY
  cases; source/tool analysis/formatting and 49 Python tests passed. No native SQL,
  full Flutter/widget/web/Windows or real JWT/PostgREST success claimed locally.
  Final-head CI must establish new SQL/SQL-to-Dart/build evidence. QA: 32 groups;
  all 14 release integrations remain pending. docs/REVIEW_QUEUE records review/impact.
- Default app runtime stays null. No SDK/Auth binding, credentials, deployment,
  token persistence, paid call or data collection change. Keep PR draft/#22 open.
  Next: concrete SDK/Auth/profile/runtime binding with #20, durable pending/receipt
  reconciliation/restart with #15, and real non-production A/B/expired JWT/SRS UI
  evidence. This read bridge is independent implementation, not release completion.

- First queue CI 38495122637 correctly rejected fixture enrollment into already
  inactive curriculum. Fixed fixture ordering: enroll while active, then retire;
  no validation/RLS trigger weakened. Exporter now prints disposable-fixture SQL
  diagnostics and exits safely without an artifact on failure; no connection URL
  is included in its failure message. Final-head native/Flutter checks must rerun.

- CI 38495371143 observed all 36 native queue assertions and seven actual SQL
  response exports passing, plus repo/AI gates. Flutter analyze found three
  multiline if blocks without braces; fixed without relaxing lint. Its skipped
  test/SQL-to-Dart/build steps are not yet counted; wait for final-head rerun.

## Verified prior due-queue handoff — PR #37, 2026-10-14 UTC

- Head 7273e62d4c13d04e5a8566d9b6932090de72a70b passed all five jobs at
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38495696580:
  Flutter analyze/no issues, 149 tests/web, Windows release/artifact, 36 native
  queue assertions/seven actual same-run SQL -> Dart projections, retained
  SQL/RLS/parity/races/AI/repo gates. Exact-head metadata verifier accepted all
  critical steps. Separate diff reviews and worker release are saved on GitHub.
  This is historical evidence, not proof for the next source increment.

## Sequential resume — Issue #22 lifecycle readiness, 2026-10-14 02:05 UTC

- Fresh main remains 78a44faf; only open draft #37 unchanged at verified prior
  head 7273e62d after worker release. Resume the same branch with one worker.
- Flutter dependency bootstrap was blocked by runtime policy after attempted
  access to unrelated cloud metadata; no retry/workaround. Continue independent
  dependency-free lifecycle source and fixture tests; concrete SDK resolution,
  Auth event listener/profile/storage and real HTTP remain unimplemented.
- Added ReviewConnectionRegistry: fresh lifecycle vs same-user refresh, expiry
  timer/access guard, synchronous clearing, closure snapshot/old-result rejection,
  bounded immutable ownerless request, redacted failure and explicit disposal.
  Added explicit runtime factory wiring the existing typed queue/repository to
  that same registry. Default app runtime remains null; no network is activated.
- Tests/tool use TEST ONLY captured connection closures; closure credentials/JWT
  cannot be authenticated by this registry. Source/format/raw verifier can run
  locally; full Flutter tests/analyze/native SQL/web/Windows require observed
  current-head CI. No full build/SDK/learner success is claimed locally.
- QA inventory adds a lifecycle group (33 total); all 14 integration release
  cases remain pending. No dependencies, frozen API/SQL/RLS, Auth strategy,
  production/data collection/provider/cost changes. Keep PR draft/#22 open.
- Next: approved SDK dependency resolution and concrete captured-token/Auth
  events with #20/profile provisioning, then #15 durable recovery/reconciliation
  and real non-production A/B/expired JWT/learner evidence. No secrets in chat.

- CI 38500368761 passed database/repo-sanity/AI but Flutter analyze found three
  verifier CLI lint issues (relative lib imports and print). Replaced with package
  imports and stdout; no lint gate weakened. Skipped Flutter tests/builds are not
  successes. Full corrected-head CI remains required.

- CI 38500591480 passed analysis and 165 tests; one runtime assembly test exposed
  nonidentical stream wrappers from repeated controller.stream access. Cache the
  registry lifecycle stream so assembled runtime has a stable handle; retain the
  assertion and add a raw-Dart regression. No test expectation weakened. Native
  database/repo/AI passed; full final-head Flutter/build evidence must rerun.

## SDK binding resume — Issue #22, 2026-10-14 03:02 UTC

- Fresh main 78a44faf; resume draft #37 at unchanged 3ff15977 after released
  worker. CI 38500891063 observed all five jobs successful with 166 Flutter tests,
  web/Windows and retained native SQL/AI gates. This is prior-head evidence only.
- Resolve SDK candidate lock in isolated read-only Actions at 5bfa29b4, run
  38504490159 observed successful. Import its public manifest/lock; already-locked
  logging becomes direct for security log controls. Remove temporary bootstrap
  workflow, recoverable in git history. No local blocked dependency retry and no
  change to original app enforce-lockfile/format/analyze/test/RLS/build gates.
- Add concrete Supabase Auth event/current-session and captured-token PostgREST
  bridge with explicit runtime factory. Same server session_id refresh retains
  identity; new login/A-B-A/expiry/disposal rejects old results. Bounded HTTPS
  config/public-key guards, no direct table write/automatic RPC refresh/retry,
  1 MiB HTTP response cap, safe errors and disabled unsafe SDK Auth/RPC logs.
- SDK/HTTP fixture tests authored; unsigned test tokens cannot authenticate real
  users or certify hosted JWT/RLS. Local formatting and Python/QA checks only;
  full SDK/Flutter/build/native SQL must be observed for the current head in CI.
  QA: 34 groups; all 14 integrated release cases remain pending.
- Default runtime remains null. No login UI, profile provisioning, secure token
  storage/restoration, durable pending queue, deployment or live learner evidence.
  No Auth provider/strategy, RLS, frozen API/SQL, production, data collection or
  paid provider/cost change. Keep PR draft/#22 open. Next #20 profile/login/storage,
  #15 durable recovery and actual non-production A/B/expired JWT/SRS journey.

- Separate follow-up review: add explicit whitespace/config bounds, block braces
  for multiline verifier-facing guards, and chunked-body/malformed-session-ID
  regressions. Preserve expectations and all checks; final-head CI must rerun.

- CI 38505690541 passed database/repo/AI but SDK Flutter analysis rejected three
  multiline if blocks and a closure-variable declaration. Use blocks/local
  function, not disabled lint. Its skipped tests/builds do not prove success.

- CI 38506024037 observed all five jobs successful at 7c27af43, including new
  SDK HTTP tests/builds. Follow-up security review extends OFF logging to the
  whole supabase logger family and strengthens the root-ALL sink test. This
  prior-head success does not certify that final log-policy change; rerun gates.

## Verified concrete SDK binding handoff — 2026-10-14 UTC

- Source head d7df49b472b3e74ce8bc85546d50e598ee3e0aea passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38506398102 .
  Observed Flutter format/analyze (no issues), **184 tests including 18 SDK/HTTP
  cases**, enforce-lockfile, web release/artifact, Windows release/artifact and
  retained SQL/RLS/parity/observed-lock races/AI/repo gates. The unmodified run
  and all five latest-attempt jobs passed scripts/verify_qa.py for that exact
  source head and every critical step. This evidence is historical for later
  commits; documentation-only successors require their own CI before merging.
- Concrete pinned Supabase SDK Auth events and captured-token PostgREST binding
  now have build/test evidence. HTTP/Auth fixtures still use TEST ONLY unsigned
  JWTs; they do not verify hosted signatures, real Auth/RLS or a learner journey.
  Unsafe SDK loggers are OFF including the parent family; all assertions remain.
- Default runtime is null. No login screen, own-profile provisioning, secure
  token persistence/restoration, durable pending event/restart reconciliation,
  deployment or hosted JWT evidence is claimed. QA inventory: 34 groups,
  all 14 Personal Alpha integration cases remain pending. Keep PR #37 draft
  and #22 open; do not merge this incomplete integration.
- Bounded sequential SDK worker released after evidence persistence. Next worker
  must inspect the current PR head first, then implement #20's login/profile and
  secure session lifecycle using the approved Auth strategy, followed by #15's
  durable owner-scoped pending/receipt recovery. Actual non-production missing/
  expired JWT, account A/B isolation and signed-in SRS acceptance still require
  supported service configuration; never request secrets in chat. Independent
  source/tests can continue without configuration. No RLS, provider, production,
  data collection or paid-cost changes.

## Native durable-review resume — 2026-10-14 UTC

- Resume unchanged draft #37 at 3f9fc78a with one worker after the released SDK
  handoff. Add opt-in native bounded append journal and DurableReviewRepository:
  flush pending before dispatch, immutable original-receipt persistence/replay,
  strict exact timestamp restore, explicit manual pending recovery under fresh
  same-owner Auth and late lifecycle rejection. Default runtime remains null.
- Actual raw-Dart subprocess/disk verifier passed locally: exit without close,
  reopen/exact pending recovery, reject second-process writer, original manual
  replay/durable receipt and interrupted tail versus complete corrupt record.
  Auth/RPC responses are TEST ONLY; no hosted/two-device learner proof.
  Pure source/tool analyzer and formatting passed. Local QA inventory/17 QA
  regressions passed; full Flutter lint/test/web and Windows require current-head
  CI. Twenty Flutter cases authored, not yet claimed passed locally.
- Add required real-disk subprocess verifier to Linux Flutter and Windows CI,
  retaining all existing gates. QA 35 groups, all 14 integration releases remain
  pending. No dependencies, frozen RPC, RLS, Auth strategy or deployment change.
- Limits/risks: native-only, single owner isolate, 1 MiB/512 retained events,
  fail-closed capacity/corruption, no compaction/encryption or hardware power-loss
  certification. This is an opt-in storage/repository library; no automatic send,
  token storage, runtime installation or UI restart flow is implemented.
  Separate architecture/security impact is recorded in DURABLE_REVIEW_JOURNAL.
- Keep #37 draft/#22/#15 open. Next: controller reconciliation/storage-error UI
  that recovers pending before allowing new events, browser transactional store,
  #20 configured login/profile/secure session restoration, bounded retention
  and real non-production missing/expired JWT/two-client SRS acceptance.

- Separate follow-up review reserves worst-case receipt bytes before dispatch,
  preventing disk-capacity exhaustion caused by staging too many unresolved
  events. Add reservation-exhaustion/freeing regression; retain the global
  event cap test with acknowledged history plus a final pending event.

## Opt-in study recovery resume — 2026-10-14 UTC

- Resume released draft #37 at unchanged e64133fa; prior CI 38512449413 passed
  all five jobs/204 Flutter tests/native disk verifiers on Linux and Windows.
  This is historical evidence, not proof for this new source increment.
- Controller/notifier/screen now recover all owner-scoped pending before due
  cards, show immutable original rating/time and explicit replay, reject late
  sessions/disposal and reload authoritative queue after durable reconciliation.
  Both explicit runtime factories accept caller-owned storage; default is null.
- Journal writes v2 terminal rejections with v1 pending/receipt read compatibility.
  Strict nonretryable definitive codes only, immutable result history, reserved
  result space and failed-write uncertainty retained. Local storage failure marker
  permits safe manual retry without altering frozen RPC error JSON or rating.
- Local actual disk/controller close/reopen verifier, retained native subprocess
  verifier, pure source/tool analyzer and formatter, QA36 inventory/17 regressions
  passed. Twenty-one controller/widget cases authored; full Flutter/widget/web and
  Windows results require current-head CI. Add required disk/controller verifier
  to Linux/Windows without removing any previous gate.
- Separate impact/compatibility and reproduction in STUDY_RECOVERY.md. No new
  dependencies, Auth provider/strategy, tokens, RLS, frozen RPC, deployment or
  paid calls. Keep #37 draft/#22/#15 open; no hosted learner acceptance is claimed.
- Next: browser transactional store/retention, configured #20 login/profile/secure
  session restoration and actual hosted A/B/expired JWT/two-device validation.
  All 14 Personal Alpha integration release cases remain pending.

- Windows build and both real-disk verifiers passed at b0d5de6a; Flutter
  format/analyze passed but widget tests were still running unusually long.
  Follow-up test review uses runAsync with a bounded controller-terminal-state
  future to await native file I/O, then pumps the UI. All UI assertions remain;
  no timeout/expectation/security gate relaxed. Full corrected-head CI required.

- Prior canceled Flutter logs exposed synchronous revocation emitting a nested
  state notification. Preserve the failing assertion; drain queued notifications
  synchronously after the current listener returns, while state/session clearing
  remains immediate. Defer stream close during notification and add synchronous
  disposal regression. No old-data/new-dispatch protection weakened.


## Lossless native compaction resume — 2026-10-14 UTC

- Resume released draft #37 from verified source dccd9b70, one worker. Add
  explicit serialized lossless compact(): flushed sibling/rename/reopen under
  stable lease, v3 settled snapshots with v1/v2 read compatibility. Preserve
  every owner, exact pending event and original outcome; no automatic deletion
  or increase to 512-event capacity. Default runtime remains null.
- Local actual-file/subprocess verifier passed six scenarios plus child compact/
  exit/parent reopen, temporary-write failure and full history retention. Six
  Flutter cases authored; full lint/test/web/Windows require current-head CI.
- Retain all gates; add mandatory CLI verifier to Linux and Windows, QA37 groups
  with all 14 Personal Alpha releases pending. Separate compatibility/impact/
  reproduction in JOURNAL_COMPACTION.md. No API/RLS/Auth/provider/dependency/
  production changes. Keep #37 draft/#15/#20/#22 open. Verified handoff below.
- Next: browser transactional store and reviewed terminal retention; configured
  login/profile/secure sessions and actual hosted two-client learner validation.

## Verified lossless native compaction handoff — 2026-10-14 UTC

- Source head 580954f8539f790cc27a5f3fe6addea4e687ce64 passed all five jobs
  at https://github.com/collab-TTAM/nihongo_daily/actions/runs/38520798851 .
  Flutter format/analyze (no issues), 231 tests including six compaction cases,
  all native disk/controller/wire gates and web release/artifact passed. Windows
  release/artifact and all three real-file process verifiers passed. Native SQL/
  RLS/parity/observed-lock races, repo/49 Python/17 QA and AI/audit gates retained.
- Unmodified run/all latest-attempt jobs passed scripts/verify_qa.py for exact
  source head and all critical steps. QA37 groups, all 14 release gates pending.
  Source CI is historical for later documentation commits; no merge attempted.
- Separate review added interrupted-sibling bootstrap and second-process writer
  rejection after replacement. All original assertions/gates retained. Local
  six actual-file cases and child compact/exit/parent reopen, retained disk and
  controller verifiers, pure analysis/format/49 Python/17 QA passed. Full Flutter,
  Windows/web/native database results are CI, not local execution.
- Explicit lossless compact retains every event/outcome and reserved pending
  receipt capacity; v3 reads v1/v2 history, old-binary downgrade needs migration.
  No automatic retention/history deletion or higher 512-event cap. Default
  runtime null; no web store, live login/profile/secure token persistence,
  power-loss or hosted/two-device learner evidence. #37 draft/#15/#20/#22 open.
- Sequential bounded worker released after evidence persistence. Resume current
  PR head first, then browser transactional store and reviewed terminal retention,
  configured Auth/profile/secure sessions and hosted learner acceptance. No API/
  RLS/Auth/provider/dependency/production changes or secrets requested.

## Browser transactional store resume — 2026-10-14 UTC

- Resume released draft #37 at dc7994a0 after all five prior documentation-head
  jobs succeeded in CI38521325597. Verified every tracked local blob against
  current remote head; one sequential worker, same branch.
- Add opt-in canonical TransactionalReviewStore with actual IndexedDB transaction
  transport using dart:js_interop. Commit before success; synchronous mutation
  under readwrite scope, exact event/outcome and owner projections, corruption/
  bounded 1MiB/512 events with pending-outcome reservations and safe failures.
  Native unsupported stub never supplies false in-memory persistence.
- Seven pure-ledger fixtures passed locally; JS reload verifier compiles locally.
  Seven Flutter unit/four real Chrome tests plus actual page-refresh/second-tab
  verifier authored; full lint/Chrome/build success requires current-head CI.
  Chrome is absent locally, so no local browser runtime claim.
- Add two mandatory browser gates in Linux Flutter; retain every prior gate.
  QA38 groups, all 14 release integrations pending. Separate protocol/impact/
  migration/persistence/security limits in BROWSER_REVIEW_STORE.md.
- Default runtime null. No secure token/login/profile, automatic retention or
  eviction/power-loss/hosted two-device acceptance. No dependencies/frozen API/
  RLS/Auth/provider/production changes. Keep #37 draft/#15/#20/#22 open. Worker
  released after verified evidence below. Next reviewed terminal retention and configured
  Auth/profile/secure sessions, followed by hosted learner acceptance.

- First CI38522933955 passed format/analyze and 238 Flutter tests; Chrome
  frontend-server could not load a direct tool/ test entrypoint. Move the same
  browser cases into test/features/srs (non-default *_test name) and share pure
  fixtures under test/. Retain every assertion and both mandatory browser gates;
  skipped Chrome/reload/web steps do not count as passing evidence.

## Verified opt-in IndexedDB handoff — 2026-10-14 UTC

- Source a1c54ffd3a767302a6623cac77c6b1336bb88f90 passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38523331817 .
  Flutter format/analyze (no issues), 238 unit/widget tests including seven
  ledger scenarios, four real Chrome IndexedDB tests, actual compiled-Dart page
  refresh twice/second-tab persistence, all existing verifiers and web build/
  artifact passed. Windows build/nihongo_daily.exe/artifact plus all three native
  disk/process verifiers passed. SQL/RLS/parity/races/repo/49 Python/17 QA/AI
  audit gates retained and passed. Unmodified run/all latest-attempt jobs passed
  scripts/verify_qa.py for exact source head and every required step.
- Source and follow-up separately reviewed: complete-before-success, synchronous
  mutation/rollback, cross-connection serialization, exact immutable outcomes,
  owner/canonical/reservation/capacity validation, no fallback data reset. First
  Chrome entrypoint path failed; relocated unchanged tests/shared pure fixtures
  to test/ without weakening assertions or browser gates. Corrected source passed.
- Local seven pure ledger fixtures/source-tool analysis/format/JS compilation/
  49 Python/17 QA passed. Actual Chrome/reloads/full Flutter/web/Windows/native
  SQL are CI evidence, not local execution. Quota/commit failure is modeled by
  the injected atomic port; no real quota/eviction or hardware-power-loss proof.
- Browser store is opt-in and accepted by existing runtime/recovery factories.
  Default runtime remains null; no hosted JWT/login/profile/secure sessions,
  other-browser or two-device learner acceptance. 512 history cap remains; no
  automatic eviction/terminal retention. QA38 groups, all 14 releases pending.
- Sequential worker released after evidence persistence; resume latest draft
  head first. Keep #37 draft/#15/#20/#22 open, no merge/deployment. Next reviewed
  terminal retention and configured Auth/profile/secure session restoration,
  followed by actual hosted A/B/expired JWT/two-client SRS evidence. Source-head
  CI is historical for later documentation/source commits; inspect their checks.
  No dependencies/API/RLS/Auth/provider/production changes or secrets requested.

## Opt-in receipt-cache retention resume — 2026-10-14 UTC

- Resume released ff76a2cd after all five CI38523872062 jobs succeeded. Verified
  every local tracked blob against GitHub; one worker on the same draft branch.
- Add explicit ReviewReceiptRetention (default disabled, limit1..256) to native/
  browser stores. Before new stage, remove only current-owner oldest staged
  successful receipt cache entries. Preserve pending/rejected/other-owner history;
  explicit prune applies strict limit. Keep+1 possible after a fresh receipt.
- Server event history untouched; pruned replay stages original immutable event
  then revalidates RPC, never synthesizes local success/progress. Shared policy,
  native flushed replacement/lease and browser atomic transaction preserve all
  existing formats/security bounds. See RECEIPT_CACHE_RETENTION.md for review.
- Local four pure scenarios plus actual native 600-review/process-restart/temp
  failure verifier passed. Four new Flutter cases and one actual Chrome retention
  case authored; current-head full lint/browser/web/Windows CI still required.
  Add mandatory CLI on Linux/Windows, retain all previous gates. QA39 groups;
  all 14 Personal Alpha integration cases pending. Default app runtime null.
- Keep #37 draft/#15/#20/#22 open. Worker released after verified evidence below; next configured
  login/profile/secure token persistence and actual hosted A/B/expired JWT/
  two-client learner acceptance. No production history deletion, dependencies,
  frozen API, RLS, Auth strategy/provider changes or secrets requested.

## Verified receipt-cache retention handoff — 2026-10-14 UTC

- Source 1a857891c068a9c96a170743e7ff7b2062c8488b passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38525221671 .
  Flutter format/analyze (no issues), 242 unit/widget tests including four new
  retention cases, five actual Chrome tests including concurrent retention/reopen,
  real page reload/second-tab, all wire/native checks and web release/artifact
  passed. Windows build/nihongo_daily.exe/artifact plus four native file/process
  verifiers passed, including 600-review retention/child prune-exit-parent reopen/
  pending preservation/blocked temporary write. SQL/RLS/parity/races/repo/49
  Python/17 QA/AI audit retained and passed. Unmodified run/all latest-attempt
  jobs accepted by scripts/verify_qa.py at exact head/every required step. QA39
  groups; all 14 Personal Alpha integration release cases still pending.
- Separate source review checked default-disabled/own successful receipts only,
  no pending/rejection/other-owner deletion, immutable existing replay/conflict
  before maintenance, atomic browser rollback and native replacement-memory
  ordering. Native formats v1/v2/v3 and browser schema1 unchanged. Server replay
  remains authoritative; injected retention server is TEST ONLY. No live receipt
  retention policy/JWT/login/profile/secure tokens/two-device learner proof.
- Local four pure scenarios/native 600-review/process/temp-write verifier, retained
  compaction CLI/source analysis/format/JS compilation/49 Python/17 QA passed.
  Full Flutter/Chrome/web/Windows/native SQL results are CI, not local execution.
- Bounded worker released after evidence persistence; resume latest draft head
  first and inspect its CI. Keep #37 draft/#15/#20/#22 open, no merge/deployment.
  Source-head success is historical for subsequent documentation/source changes.
  Default retention disabled/runtime null; pending/rejected/shared-owner/quota
  limits may still exhaust storage. Next configured Auth/profile/login/secure
  session restoration and actual hosted A/B/expired JWT/two-client acceptance.
  No server/production history deletion, API/RLS/Auth/provider/dependency change.

## Caller-bound profile bootstrap resume — 2026-10-14 UTC

- Resume released draft #37 at 3471b92c after all five CI38525874034 jobs passed.
  Verified all local tracked blobs against remote head; one sequential worker.
- Add additive nd-own-profile-1/ensure_profile accepting empty request only,
  auth.uid plus existing auth.users identity, idempotent own default insert and
  settings-preserving read. No direct INSERT/DELETE grants or changed RLS/table
  schema; narrow authenticated definer with fixed empty search_path. Exceptions
  roll back and return existing safe errors. No Auth provider/strategy change.
- Typed Dart bootstrap uses captured Auth/RPC, strict own response projection,
  timeout/no automatic retry and old-session rejection. Registry allowlist only
  adds empty ensure_profile envelope. Default runtime null; no login/token store.
- Seven pure scenarios/source-tool analysis/format passed locally. Nine Flutter
  cases (seven unit/two SDK HTTP) and native SQL/rollback/observed-lock race/five
  actual SQL response projection tests authored; success requires exact-head CI.
  Native PostgreSQL is absent locally; no local SQL/full SDK/build claim.
- Add database export/concurrency/artifact and same-run Flutter decoder gates;
  retain every prior gate. QA40 groups/all 14 releases pending. Separate contract/
  scope/privilege/impact review in OWN_PROFILE_BOOTSTRAP.md. Worker active pending
  CI; keep #37 draft/#20/#22/#15 open. Next login/profile readiness coordination,
  secure session persistence and actual configured hosted learner evidence.

## Verified own-profile source handoff — 2026-10-14 UTC

- Source fb3a691553869fd0f01ec029c008808323e778cd passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38528310665 .
  Flutter format/analyze (no issues), 251 tests including seven profile unit/two
  SDK HTTP cases, five Chrome tests, five actual same-run SQL profile responses
  decoded through the Dart adapter and web release/artifact passed. Windows
  release/artifact/all native file verifiers passed. Database includes 25 new
  profile assertions and observed-lock concurrent creation; existing SQL/RLS/
  SRS parity/races/repo/49 Python/17 QA/AI gates retained and passed. Unmodified
  run/all latest-attempt jobs accepted by scripts/verify_qa.py at exact head/
  every critical step. QA40 groups/all 14 releases still pending.
- Separate scope/privilege review: authenticated-only caller-ID provisioning,
  empty request/no metadata, settings-preserving duplicate handling, unchanged
  direct grants/RLS, fixed-path definer and rollback/redacted errors. Typed
  adapter rejects malformed/other-owner/old-session results and has no auto
  retry. No default runtime/login/token persistence/provider change/deployment.
- Local pure/profile/source-tool/format/Python/QA checks passed; native SQL/full
  SDK/Flutter/web/Windows evidence is CI, not local execution or hosted JWT proof.
  Source success is historical for later documentation/source commits.
- User requested continuing; same sequential worker now proceeds to login/profile
  readiness UI and runtime coordination. Keep #37 draft/#20/#22/#15 open. Secure
  token restoration and actual configured hosted learner acceptance still missing.

## Account readiness implementation — 2026-10-14 UTC

- Resume the same sequential worker at restored b5b15c9c. A documentation tree
  created without its base briefly omitted source at a11492a; fast-forward repair
  restored every source blob from verified fb3a6915. Full recursive comparison
  confirmed only the two intended documentation files differed (203 blobs).
  Nothing merged or deployed. Subsequent trees require explicit nonempty base
  and full-tree comparison before advancing the ref.
- Add configured account UI/runtime assembly: transient cleared credential fields,
  existing SDK email/password/local sign-out, own-profile readiness barrier,
  owner/session/generation checks and immediate study invalidation on logout,
  expiry/account changes, stream closure or disposal. SDK logout dispatch waits
  until an active callback returns; gate is already closed. Late sign-in cleanup
  remains fenced; safe explicit retry, no credential/token state or automatic
  controller retry. Default runtime null; no provider/backend setup or deployment.
- Ten raw-Dart scenarios and pure analysis/format passed locally. Five widget/two
  actual SDK HTTP cases authored; full tests/builds require source-head CI.
  Separate scope/lifecycle/credential review and reproduction in
  ACCOUNT_READINESS.md. New mandatory readiness step retains all prior gates.
  QA41 groups/all 14 live integration releases pending. Worker active pending CI.
- Keep #37 draft/#20/#22/#15 open. Next secure session storage/restore and actual
  configured hosted A/B/expired JWT/restart/two-client learner acceptance.

## Verified account/profile readiness handoff — 2026-10-14 UTC

- Source 6a04a2cfb3dc30802da2b9169801475a72b1e63e passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38547379359 .
  Flutter format/analyze (no issues), 267 tests including ten account-controller,
  five widget and two SDK HTTP cases (generic auth placeholder replaced by richer
  dedicated route coverage), five actual Chrome tests, new mandatory readiness
  verifier and retained native/wire/same-run SQL-to-Dart checks passed. Web and
  Windows releases/artifacts plus all four Windows native file/process verifiers
  passed. SQL/RLS/profile observed-lock races, repo/49 Python/17 QA and AI/audit
  gates retained and successful. Unmodified workflow/all latest-attempt jobs
  accepted by scripts/verify_qa.py at this exact head/every critical step. QA41
  groups/all 14 integration release cases pending.
- Separate source/follow-up review checked profile barrier and caller ownership,
  immediate study invalidation before awaited logout, late sign-in cleanup,
  reentrant notification/disposal, transient cleared credential fields and safe
  errors. Initial extracted queue import/lint failure fixed with original tests
  and gates preserved. Every one of 213 local blobs matches uploaded source.
  The earlier documentation-only tree omission was fully restored before this
  source increment; corrected complete source now has all five CI jobs passing.
- Local ten pure scenarios/source analysis/format/49 Python/17 QA passed. Full
  widgets/SDK/Chrome/builds/native SQL evidence is CI, not local or hosted Auth.
  Existing SDK email/password is caller configured, no server provider change.
  App default runtime null; no registration/secure token store or restore/live
  learner acceptance. Login credentials never enter account state or journal.
- Bounded sequential worker released after evidence persistence. Resume latest
  draft head first, inspect its CI and do not overlap workers. Source-head success
  is historical for the following documentation-only handoff commit. Keep #37
  draft/#20/#22/#15 open; no merge/deployment. Next configured secure session
  lifecycle/storage/restore, then actual hosted A/B/expired JWT/restart/two-client
  learner acceptance. Missing credentials do not block independent work.

## Windows refresh-secret vault resume — 2026-10-14 UTC

- Resume eae3c63d after all five CI38548119120 jobs passed. All 213 local blobs
  match remote baseline. One core worker; Pro content lane remains reserved for
  Issue #14. No data/content/schema/migration/Auth provider changes.
- Add explicit Windows Credential Manager refresh-secret component, trusted
  HTTPS-origin namespace, 2048 printable-ASCII byte bound, strict native method
  envelope, idempotent exact-target clear and safe errors. Serialize same-target
  operations across facade instances in this Dart isolate; never fall back to
  files/browser storage. Existing app/account runtime remains unconfigured.
- Twelve pure scenarios/source analysis/format pass locally. Four platform-channel
  tests and real native Windows credential/child exit/read/project isolation/
  corrupt-input/clear probe authored. Native C++ helper is shared by app/probe;
  Windows runner lifetime registers/unregisters the bridge. Current-head CI
  required for full Flutter/native API/build claims. All prior gates retained;
  add pure verifier and mandatory actual Windows probe. QA42/all 14 releases
  pending; worker active pending CI.
- Separate source/scope/secret-memory/OS boundary review in WINDOWS_SESSION_VAULT.
  No dependencies/API/RLS/production/paid-provider changes. This component is not
  yet connected to SDK token rotation or login/logout/restart restoration. Next
  bind the vault to an explicitly owned Supabase session lifecycle with profile
  readiness and late-result guards, then actual configured hosted acceptance.
  Keep #37 draft/#20/#22/#15 open; no merge/deployment.

## Verified Windows session-vault handoff — 2026-10-14 UTC

- Source 1dd109470369884f7f776888cfab91859f9efc1c passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38558520796 .
  Flutter format/analyze (no issues), 283 tests including twelve vault cases/four
  platform-channel cases, five Chrome tests, new pure vault verifier and retained
  account/native/wire/same-run SQL-to-Dart checks passed. Web release/artifact,
  Windows app/bridge release build/artifact and all four prior native file/process
  verifiers passed. New native /W4 /WX probe used actual Credential Manager for
  write/read/replacement, child write/exit/parent read, project isolation, invalid
  write preservation, 2048-byte bounds, foreign target rejection, raw corrupt blob
  injection/recovery and idempotent deletion. PID-qualified .invalid TEST ONLY
  credentials cleared before success. SQL/RLS/races/repo/49 Python/17 QA/AI/audit
  retained and successful. Unmodified run/latest-attempt job payloads passed
  exact-head/every-critical-step scripts/verify_qa.py. QA42/all 14 releases pending.
- Initial CLI print lint was fixed with stdout. Native probe wchar narrowing
  warning was fixed with checked ASCII conversion and stricter CI-only child
  target scope; /W4 /WX, assertions and every gate remain. Separate follow-up
  review checked changed paths/no credential output, bounds, OS buffer cleanup,
  method envelope, channel lifetime and no secret fallback. Before final probe
  correction all 226 local blobs matched upload; correction preserves every
  other blob. No data/content/schema/lock/dependency/RLS/Auth/provider changes.
- Twelve pure cases/format/source analysis/49 Python/17 QA passed locally. Actual
  Windows credentials, full Flutter/channel mocks/Chrome/builds/native SQL are
  observed CI, not local execution, interactive Dart-to-OS or hosted Auth proof.
  Vault remains an explicit component; current account runtime null. No SDK token
  rotation/login/logout persistence/startup restore/browser/mobile store enabled.
  Same OS user process access remains outside application isolation; same-isolate
  queue is not interprocess CAS, and full memory zeroization is not claimed.
- Bounded core worker released after evidence persistence; Pro #14 remains
  reserved and untouched. Resume latest draft head/its CI first. Source success
  is historical for the documentation handoff successor. Keep #37 draft and
  #20/#22/#15 open; no merge/deployment. Next explicitly owned SDK/vault lifecycle:
  captured/generation-guarded token rotation, clear/logout ordering, startup refresh
  before own-profile readiness, storage/revocation/late-response tests. Then actual
  configured hosted A/B/expired JWT/restart/two-client learner acceptance.


## Owned persistent session lifecycle resume — 2026-10-14 UTC

- Resume d3fc8ad7 after latest CI38559195851 succeeded. All 226 baseline blobs
  matched GitHub; one isolated core checkout/writer. Pro N4 PR #38 stays separate.
- Add explicit exclusively owned Supabase runtime with disabled SDK auto-refresh,
  no Session JSON storage, Windows vault scope validation, single-isolate owner
  lease, server refresh-only startup and persist-before-own-profile readiness.
  App default runtime remains null; browser assembly rejected before SDK creation.
- Generation/captured-secret guards discard stale events, fence logout before awaits,
  serialize writes/clear and clean up late Auth success. Storage errors fail closed;
  explicit login cleans failed state before retry. Close preserves saved credentials
  but waits for interrupted Auth cleanup; caller must await close. Explicit refresh
  only, no automatic refresh scheduler. Auth HTTP is same-origin/no redirects,
  bounded to one 15-second attempt and 1MiB; no raw errors or secrets in state/logs.
- Twenty-two pure fixture cases pass locally. Seven actual SDK/mock-HTTP cases authored;
  full Flutter, SDK, browser, native/build evidence requires current-source CI.
  New mandatory lifecycle verifier retains every prior gate. QA43/all 14 live
  release integrations pending. Separate review: PERSISTENT_SESSION_LIFECYCLE.md.
- No dependencies, schema/RLS/API, Auth provider/strategy, N4 data or deployment
  changes. Keep #37 draft/#20/#22/#15 open. Worker active until verified handoff.
  Next actual Windows Dart-to-OS/runtime restart and configured hosted learner
  A/B/expired JWT/two-client evidence; then opt-in startup UI/configuration and
  refresh scheduling. Source implementation is not real login acceptance.

- First CI38573420584 passed repo/database/AI but Flutter lint required the
  inherited stream's @override annotation. Kept lint gate; correction also holds
  the Auth operation through late cleanup and cancels failed-state login recovery
  on logout, with two added regression cases (22 pure). Source CI rerun required.

- Source review requires an explicitly supplied DurableReviewStore in the new
  persistent factory: rotation removes the old study runtime, so a process-only
  review repository could lose an uncertain event. Added actual disposable-disk
  pending-event preservation across rotation/logout/relogin (seventh SDK test).
  Existing nonpersistent factories retain their optional store. Fixed Japanese
  HTTP fixture JSON content type; assertions and lint/build gates retained.


## Verified owned session lifecycle handoff — 2026-10-14 UTC

- Source 021c36bf7a5572dcc0111161d093a0fc7b3377f8 passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38575156585 .
  Format/analyze without issues, 312 Flutter tests (22 pure lifecycle/seven
  pinned-SDK HTTP cases), five actual Chrome tests, mandatory lifecycle verifier,
  all retained wire/native/same-run SQL-to-Dart checks and web release passed.
  Windows release/artifact, actual Credential Manager/process probe and all four
  file/process verifiers passed. Native SQL/RLS/profile races, repo/49 Python/
  17 QA/AI audit retained. Unmodified run/latest-attempt metadata passed exact-head
  and every required step in scripts/verify_qa.py. QA43/all 14 live groups pending.
- All 233 local source blobs matched GitHub. Separate review retained persist-
  before-profile, exclusive private SDK mutation port, logout/clear ordering,
  late cleanup ownership, failed-state retry cancellation and default-null scope.
  Required caller review store prevents losing uncertain events when rotation
  replaces a runtime; actual native-disk test retains the exact original event
  across rotation/logout/relogin and never auto-dispatches it. Pro #38 untouched.
- First lint annotation and Japanese HTTP fixture content-type errors fixed
  without removing checks/assertions. Local 22 pure lifecycle/ten retained account
  cases, pure source analysis/format/49 contracts/17 QA passed. Full Flutter/SDK/
  browser/build/native SQL/Windows results are observed CI, not local/hosted proof.
- Bounded HTTP timeout is per attempt. Pinned gotrue 2.27.3 internally retries
  refresh transport/5xx failures even with SDK auto-refresh disabled; observed
  timeout fixture takes about 12 seconds. Whole Auth operation can exceed the
  15-second attempt bound. Controller/persistence adds no retry loop or timer.
  Updated scope docs rather than claiming absent SDK retries or changing policy.
- Explicit SDK/vault assembly only, matching vault + caller-owned review store
  required, no default startup configuration or automatic refresh scheduler.
  Web is rejected before SDK construction; Windows store is the implemented
  native backend. No hosted login/JWT, actual Dart-to-Windows restart or two-
  device learner proof. Single-isolate owner lease is not interprocess CAS.
- Core worker RELEASED after verified source and durable handoff; resume latest
  draft head and its checks. Following documentation commit preserves source and
  has separate CI; source success is historical for later heads. Keep #37 draft
  and #20/#22/#15 open. Next actual Dart-to-Windows bridge/runtime restart, caller
  startup/error/explicit-refresh scheduling, then configured hosted learner A/B/
  expiry/restart/two-client acceptance. Missing service configuration does not
  block independent testable work. No dependencies/schema/RLS/API/Auth-provider,
  production deployment/deletion or N4 changes; schedule remains requested.

## Windows Dart/native bridge increment — 2026-10-14 UTC

- Resumed actual #37 head 0a2aad71; baseline local blobs matched prior source tree
  except the two known handoff docs. Pro #38/N4 lane remains untouched.
- Added TEST ONLY Flutter runner entrypoint and bounded PowerShell orchestration
  to exercise real Dart facade/codec/channel/Credential Manager in five sequential
  processes, including observing replaced data and absence after deletion.
  GUID `.invalid` scope; fixed synthetic values only; finally cleanup required.
- CI requires probe build/execution and then normal preview rebuild. All prior
  gates retained. Local formatting and 17 QA tests passed; initial contracts run
  lacked jsonschema in default Python (environment, not test success). Use existing
  contract-venv. Windows execution/new-head full CI are pending at upload.
- Separate review: no arbitrary target/token CLI input, bounded processes, fixed
  safe logs, per-run target cleanup, separate probe target and normal artifact.
  This increment verifies vault bridge only; persistent SDK runtime restart,
  refresh scheduling/startup UI and all 14 live integrations remain pending.
  Keep #37 draft; no deployment, migration, dependency/Auth-provider or N4 change.

### Observed bridge evidence and released handoff

- Source 92250a67629c5fd2d73090c249075478847a59dd passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38584671877 .
  Actual Flutter runner bridge build/execution passed; logs confirmed the fixed
  cross-process success marker. Normal learner entrypoint rebuilt afterward;
  Windows/web artifact uploads and all retained test/SQL/browser/native/security
  steps succeeded. Raw run/latest-attempt metadata passed exact-source-head and
  every-required-step QA. Existing 49 Python contracts and 17 QA passed locally
  using saved jsonschema packages; no dependency installed or gate weakened.
- All 235 uploaded source blobs matched local files; base tree preserved in full.
  Review kept fixed fixture values, bounded process calls, GUID-only test scope,
  fail-visible finally cleanup and normal artifact rebuild. No live learner or
  Supabase-to-OS restore claim. QA43/all 14 live integration groups remain pending.
- Core worker RELEASED. Resume actual head; following evidence-only docs commit
  has its own CI and does not inherit current-head success. Next: persistent SDK
  runtime using actual Windows bridge across processes, caller startup/error UI,
  explicit refresh scheduling, then hosted configured learner A/B/expiry/two-client
  acceptance. Keep #37 draft and #20/#22/#15 open; Pro #38/N4 untouched.

## Windows persistent runtime restart increment — 2026-10-14 UTC

- Resumed actual head 53de3784; its CI passed. Core worker ACTIVE for this
  sequential increment; Pro #38/N4 lane remains untouched.
- Added five runtime phases to the already executed real Flutter Windows bridge
  probe, using pinned SDK/mock HTTP plus actual OS vault and native review disk.
  Checks refresh-only restore, exact rotation before profile, preserved pending
  event, close persistence, immediate logout fencing, signed-out restart and
  rejected stored token with explicit recovery. No submit_review permitted.
- Local format/49 contracts/17 QA pass. New-head full analysis/Flutter/Windows
  execution are pending. No historical test result counted for new code.
- Separate review: fixed .invalid GUID scope/synthetic values; no external HTTP;
  bounded phases/cleanup of test OS entry and temp journal; production runtime
  owns SDK; normal entrypoint rebuilt before artifact upload. Fixture Auth/JWT
  remains simulated, so all 14 hosted Personal Alpha groups remain pending.
  Keep #37 draft and #20/#22/#15 open. Next caller startup/error UI and refresh
  scheduling, then configured hosted learner/restart/two-client acceptance.

- First source e31fd57e CI 38589704536 passed repo/SQL/AI but Flutter analysis
  found one missing block in fixture `_check`. Added braces without changing
  assertions or suppressing lint. Skipped test/build steps are not passes;
  corrected source requires a fresh full CI run.

- Corrected source 1475f19 CI 38590154982 passed analysis and actual Windows
  runtime probe, but one retained SDK recovery test checked readiness after only
  eight event turns and observed profile still pending (311 passed/one failed).
  Replace that timing heuristic in this test with bounded account completion
  observation; ready/profile-error/sign-in-error/unavailable are terminal, and
  ready plus original nonnull runtime assertions remain mandatory. Production
  logic and timeout/assertion/security/CI gates are unchanged. New source needs CI.

### Verified Windows runtime process handoff

- Source e39d6fee1ac554f8e9802294b09ef54d5ed17b63 passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38590916038 .
  Observed 312 Flutter tests/five Chrome tests, no analyze/format issues, actual
  Flutter vault and runtime cross-process markers, native credential/process
  probe and retained native/SQL/wire/security/build gates. Normal web/Windows
  artifacts uploaded; TEST ONLY entrypoint rebuilt to learner entrypoint first.
  Raw run/latest-attempt metadata passed exact-source/every-required-step QA.
- Ten process phases use real Windows credential vault and journal. Runtime
  phases retain the original pending event, server-refresh the saved secret,
  save rotation before profile, preserve confirmed secret on close, fence logout,
  remain signed-out after restart and recover explicitly from rejected secret.
  Pinned SDK uses mock HTTP/unsigned JWTs: no hosted identity or two-client proof.
- Full source tree preserved; 236 blobs matched after upload. Separate review
  kept original ready/non-null SDK assertion while replacing fixed event turns
  with bounded terminal-state observation. No assertion/lint/security/CI weakening
  or production auth logic change. All 14 live release gates remain pending.
- Core worker RELEASED after evidence saved. Resume actual head/checks; evidence
  successor only updates handoff/QA documentation and has separate CI. Next
  caller startup/error UI and explicit refresh scheduling, then configured hosted
  A/B/restart/expiry/two-client acceptance. Keep #37 draft; #20/#22/#15 open.
  Pro #38/N4 unaffected; no dependency/provider/schema/deployment changes.

## Opt-in account startup/error host — 2026-10-14 UTC

- Resumed actual #37 head 57cd3043 with sequential core ownership; Pro #38/N4
  lane untouched. Added pure owned startup controller, persistent runtime adapter
  and configured Flutter host. Default main/provider still unconfigured.
- Loading withholds account/router publication. Fixed errors allow explicit
  fenced login or retry, with old-owner close before replacement. Close drains
  late factory/start and never publishes late results. Cleanup failure blocks
  replacement; caller awaits close, disposal reports fixed callback. No auto retry.
- Added eight lifecycle/four widget fixture tests, including 320px/200% text,
  real account route/form wiring and disposal races. Local formatting done;
  new-source full Flutter/Windows/web/retained gates pending CI. All 14 live
  integration groups pending; no hosted Auth/refresh scheduler claim.
- Separate review retained profile/persistence gating, safe errors, project
  ownership and mandatory close-before-replacement. Factory owns partial failure
  cleanup; supplied journal remains caller-owned. No dependencies/provider/API/
  schema/N4/deployment changes. Scope/reproduction: docs/ACCOUNT_STARTUP.md.

### Verified startup host handoff

- Source 9388b5813d3c3eacf727f8fae7eec5cd388f070a passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38593010698 .
  Observed 324 Flutter tests (eight lifecycle/four startup widgets added), five
  Chrome tests, format/analyze, retained actual Windows vault/runtime process
  success markers, native/SQL/wire/security gates and normal web/Windows artifacts.
  Raw run/latest-attempt metadata passed exact-source/every-required-step QA.
- All 242 uploaded source blobs matched. Review kept one captured owner, no
  account publication before start, explicit fenced-login action, cleanup before
  replacement, immediate closed publication and drained late factory/start.
  Pro #38/N4 unchanged. Multiline retry guard enclosed without logic changes.
- Startup UI evidence is explicit owner/Auth/profile fixtures, not hosted login,
  full UI-to-OS integration or release readiness. Default main/provider stays
  unconfigured; no refresh scheduler added. All 14 live release groups pending.
- Core worker RELEASED after persisted evidence. Resume actual latest head/checks;
  following documentation/QA evidence commit has separate CI. Next tested refresh
  scheduling with lifecycle/expiry/resume/logout guards, then configured hosted
  learner A/B/restart/expiry/two-client acceptance. Keep #37 draft/#20/#22/#15 open.
  No dependency/provider/schema/API/deployment change or production data cleanup.

## Opt-in owned refresh scheduling — 2026-10-14 UTC

- Resumed actual #37 head ba506b08 with one core writer, Pro #38/N4 untouched.
  Added private runtime scheduler selected by automaticRefresh=true; default false
  and main unconfigured. SDK automatic refresh remains disabled.
- Accepted identity/expiry only, 60-second lead, 24-hour bounded rearm, 30-second
  spacing and one attempt per lease. Current gate rechecked before dispatch;
  logout/close cancel timers, late callbacks cannot dispatch old identities,
  expired resume never restores; no scheduler failure retry loop.
- Existing save-before-profile barrier used for every rotation. Startup host
  forwards foreground resume only for active owned adapters. Twelve timer/clock
  cases, two pinned-SDK/mock-HTTP cases and one widget forwarding test added.
  Local format/49 contracts/17 QA passed; new-source CI pending.
- Separate review retains SDK internal retry policy and per-attempt HTTP bounds,
  no public credentials, null default activation and caller journal ownership.
  No dependency/provider/Auth strategy/schema/API/N4/deployment changes.
  Scope/limits: docs/SESSION_REFRESH.md. Hosted JWT/device/background/OS suspend
  proof and all 14 live release groups remain pending; keep #37/#20/#22/#15 open.

- First source a60539e CI38595472805 passed repo/SQL/AI, but analysis found
  nullable receiver at generic resume forwarding. Add explicit nonnull guard
  before the resumable-owner check. No lifecycle/expiry/ownership/assertion or
  lint gate changed; skipped downstream tests/build are not passing evidence.
  Corrected source requires fresh full CI.

### Verified refresh scheduler handoff

- Source c65528fbea77313f386666c37ab10a1f58efbae0 passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38596070841 .
  Observed 339 Flutter tests (12 scheduler/two pinned-SDK/one widget added),
  five Chrome tests, format/analyze, retained actual Windows vault/runtime
  cross-process markers, native/SQL/wire/security gates and normal artifacts.
  Raw run/latest-attempt metadata passed exact-head/every-required-step QA.
- All 245 uploaded source blobs matched. Pure local controller/scheduler analysis,
  format/49 contracts/17 QA passed. Generic foreground forwarding required both
  nonnull guard and checked interface cast; kept active-owner/lifecycle/expiry
  guards and every assertion/lint/CI/security gate. No SDK retry policy change.
- Opt-in automaticRefresh=false by default; main unconfigured, SDK automatic
  refresh disabled. New scheduler attempts once per lease, keeps save-before-
  profile, rejects expired resumes and cancels on logout/close. Short TTLs cannot
  loop. Failure test fences study with no added resume retry. Fixture Auth/clock/
  timers are not hosted rotation/background/OS suspension proof. Pro #38/N4 intact.
- Core worker RELEASED after evidence saved. Resume actual head/checks; following
  evidence/QA docs commit has separate CI. Next configured non-production hosted
  learner A/B/expiry/restart/two-client acceptance and startup/refresh error
  presentation; all 14 live integrations still pending. Keep #37 draft and
  #20/#22/#15 open. No dependency/provider/schema/API/production changes.

## Safe account session notice UI — 2026-10-14 UTC

- Resumed actual #37 head 8486f440, one core writer; Pro #38/N4 unaffected.
  Added display-only three-state port from owned persistent runtime, source
  provider/notifier and active-startup wiring. Account checking hides/clears
  credentials; fixed failure text offers explicit login. Ordinary logout clears
  notices; existing profile/account errors keep their messages.
- No notice can grant/revoke authorization; existing session/profile/persistence
  gate remains authoritative. Source replacement cancels stale events; fixed
  enum state only, no raw SDK/error/token/path exposed. Runtime close cancels
  scheduler first and does not await paused display subscribers before cleanup.
- Seven notice/provider/widget tests plus one pinned-SDK/mock-HTTP case added;
  retained automatic-refresh tests now assert saved/failure/checking display.
  Local format/analysis/contract/QA checks pending below; new-source full CI pending.
- Separate review retained null default source/main, no retry/autologin, caller
  journal ownership and no production/schema/API/provider/dependency changes.
  Hosted Auth/learner/two-client/OS suspension and all 14 live groups pending.
  Scope: docs/ACCOUNT_SESSION_NOTICE.md; keep #37/#20/#22/#15 open.

- Source d7816608 CI38598860539 passed analysis and seven notice/SDK direct cases,
  but configured-host test still found form after a single frame. Preserve the
  no-fields assertion, add explicit owned-source/scoped-notice assertions and
  render after stream state propagation. This distinguishes wiring from frame
  timing; no production/auth/assertion/lint changes. New-source CI required.

### Verified session notice handoff

- Source bb6be63deefa307e130c1a840c5aedaa1054a0d2 passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38599504856 .
  Observed 347 Flutter tests (seven notice/provider/widgets + one pinned-SDK),
  five Chrome tests, format/analyze, retained actual Windows vault/runtime
  process markers, native/SQL/wire/security gates and normal web/Windows uploads.
  Raw run/latest-attempt metadata passed exact-head/every-required-step QA.
- All 249 source blobs matched local upload. Pure port/controller analysis,
  format/49 contracts/17 QA passed locally. Added owned-source/propagated-state
  assertions before next-frame no-fields check in host test; original expectation
  retained, no production/Auth/lint/security/CI relaxation.
- Display-only notices never grant study; checking clears/hides credentials,
  fixed failures request explicit login, success/ordinary logout clear notice.
  Startup installs only the owned source; replacement cancels old events.
  SDK failure and login recovery are mock HTTP/unsigned JWT fixtures, not hosted
  learner/UI-to-OS expiry/rotation proof. All 14 live release groups remain pending.
- Core worker RELEASED after persisted evidence. Resume actual head/checks;
  following documentation/QA successor has separate CI. Next configured staging
  learner A/B/expiry/restart/two-client acceptance and evidence-linked remaining
  product flows. Keep #37 draft/#20/#22/#15 open. Default main/provider unchanged;
  Pro #38/N4 untouched; no dependencies/schema/API/Auth provider/deployment changes.

## Explicit Windows staging bootstrap — 2026-10-14 UTC

- Resumed actual #37 head cfa60116, one core writer; Pro #38/N4 not changed.
  #20 still requires configured non-production Supabase/actual A/B evidence,
  and neither issue/repo supplied those values. Continue independent assembly.
- Ordinary main now selects preview by default or explicit validated staging
  build configuration. Configured Windows opens a project-scoped LocalAppData
  journal/process lease before the SDK/token writer, owns runtime + journal and
  installs existing startup/notice/refresh/account/profile/study paths.
  Invalid/missing/unsupported selected staging fails before resources/without
  silent preview or other-project fallback. Public key/URL only; no secrets/logs.
- Added read-only native known-folder/SHA256 path channel, shared unchanged target
  validation and strict Dart path/platform checks. Native root failures have fixed
  errors; no cwd/temp/network fallback. Nine Dart tests/three process phases plus
  configured TEST ONLY Windows main build added; normal preview rebuilt before
  upload. Local format/49 contracts/17 QA passed; full new-source CI pending.
- Separate review: COM already initialized by runner, known-folder memory/provider
  handles released, Unicode conversion checked; no filesystem create/delete in
  native resolver. GUID-scoped disposable probes, caller journal ownership
  transferred explicitly, no user-history deletion. No dependency/provider/
  Auth strategy/RLS/schema/API/production deployment or N4 changes.
- Scope: docs/STAGING_BOOTSTRAP.md. Hosted login/expiry/two-client/GUI acceptance
  and all 14 live release groups remain pending. Keep #37/#20/#22/#15 open.

- First bootstrap source ca859a0f CI38603915706 passed analysis/354 Flutter
  cases, but two widget platform fixtures left debugDefaultTargetPlatformOverride
  set at Flutter's invariant check. Use framework TargetPlatformVariant rather
  than late addTearDown reset. Original selection/ownership/no-resource assertions
  retained; no production behavior, lint/security/CI gate changed. Full corrected
  source CI required; skipped downstream steps are not successes.

### Verified explicit staging bootstrap handoff

- Source 5be34663e2c28e182d12c66f0dea894853e05cd9 passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38605205617 .
  Observed 356 Flutter tests (six config/selection + three directory), five
  Chrome tests, format/analyze, actual OS project app-data + empty-vault owned
  factory/start/close/reopened journal marker and retained Windows vault/runtime
  process markers/native/SQL/wire/security gates. Configured staging main compiled
  with TEST ONLY settings, then normal preview rebuilt and artifacts uploaded.
  Raw run/latest-attempt metadata passed exact-source/every-required-step QA,
  including the newly mandatory configured main build.
- All 256 source blobs matched. Local format/49 contracts/17 QA passed. Initial
  widget debug-platform invariant corrected with framework variants; redundant
  imports removed without any production behavior, expectation or gate weakening.
  Native API buffers/providers freed, scope is canonical target SHA256 and probe
  only deletes its GUID `.invalid` journal scope. No user history is deleted.
- Main now supports trusted explicit Windows staging build assembly; default
  remains preview. Journal/process lease precedes token writer; invalid/unsupported
  selected configuration fails before resources. Bootstrap now owns journal +
  runtime, preserves history and drains runtime before journal release. No secrets
  supplied through build settings, no hosted project/provider/schema deployment.
- Core worker RELEASED after persisted evidence. Resume actual head/checks;
  following handoff/QA successor has separate CI. Next supported non-production
  service configuration and actual learner A/B/expiry/restart/two-client acceptance,
  or independent remaining product flows while service configuration is absent.
  All 14 live release groups remain pending. Keep #37 draft/#20/#22/#15 open;
  Pro #38/N4 intact. No dependencies/Auth strategy/API/RLS/production changes.

## Awaited cancelable Windows window close — 2026-10-14 UTC

- Resumed #37 head 84bd5c16; sequential core worker ACTIVE, Pro #38/N4 untouched.
  Pinned engine source confirms final-window WM_CLOSE asks the framework before
  closing; owned host previously had no awaited exit observer.
- Added awaited owned controller close, immediate account-route fencing, fixed
  closing/failure UI, concurrent request coalescing and cancellation on failure.
  Explicit later native close retries retained cleanup; no automatic reopening,
  timeout pretending drain complete, raw exception or learner-history deletion.
- Four framework/widget cases and two actual Windows OS-close fixture phases
  added. Real empty-vault staging owner closes and journal lease reopens before
  natural process exit; external GUID test markers keep fixture drain observable.
  Cancellation fixture fails before delegating owner close, then explicitly retries.
- Format/local contracts/QA and new-source full CI pending. Hosted Auth/learner
  A/B/restart/rotation/logoff/power-loss and all 14 release groups remain pending.
  Scope: docs/ACCOUNT_STARTUP.md. No dependency/provider/schema/RLS/API/default
  preview/N4/production changes. Keep #37 draft and #20/#22/#15 open.

- Early source ea1c7079 CI38608189714 failed analysis on missing explicit
  dart:ui AppExitResponse import. Source 001cb178 CI38608551307 passed analysis/
  359 cases but the new pending-drain UI assertion needed a rendered frame after
  async observer dispatch. Original no-fields/owned-drain assertions retained.
- With that frame rendered, f07ffb2f CI38609111254 exposed a lifecycle defect:
  replacing the active router disposes AppLifecycleListener while the binding's
  copied observer list is awaiting our drain. Preserve the router subtree, revoke
  the account provider override and cover routes offstage with focus/tickers
  blocked until exit. Test additionally asserts same router identity, null
  account publication and focus exclusion. No swallowed framework assertion or
  test/security/build gate relaxation; corrected source needs full fresh CI.

- Source 6878b47e CI38610083054 kept router identity/null override assertions
  but still exposed EditableText lifecycle listeners disposed when account
  revocation removed form children. Keep keyed form subtree mounted but offstage,
  disabled/unfocusable and cleared on the existing state/notice transitions.
  Test now retains password-widget identity and checks disabled/empty controller.
  Windows build/native vault/runtime phases passed, but CloseMainWindow was
  requested before .NET found a main HWND; wait for the real native main window
  after Dart ready marker. Required no-early-exit/cleanup-marker assertions kept.
  No failing/skipped source run counts as verification; fresh full CI required.

### Verified cancelable window close handoff

- Source 2aa94639e99dc38c9af9f5734eba7b47c52a3469 passed all five jobs in
  https://github.com/collab-TTAM/nihongo_daily/actions/runs/38611061291 . Observed 360 Flutter tests (four new
  framework/widget exit cases), five actual Chrome tests, format/analyze, retained
  native/SQL/wire/security/AI checks and web/Windows preview artifacts.
- Actual Windows CloseMainWindow tests passed: pending owned drain keeps process
  alive until externally released; synthetic one-shot close failure cancels the
  first native request, and a later explicit close finishes the same owner. Real
  empty-vault staging runtime closes, real app-data journal lease reopens and
  completion marker precedes natural process exit. Logs contain all four vault/
  runtime/app-data/window-close success markers. Configured staging main compiled,
  then normal preview rebuilt. Raw evidence passed exact-head/every-required-step.
- Retain router + keyed form listeners during the framework observer snapshot;
  null account override revokes publication, offstage/disabled/focus/ticker guards
  block input and existing listeners clear fields. Stronger fixture checks verify
  same router/password-widget identity, empty disabled password and no framework
  exception. First .NET close needed the native main HWND after Dart frame ready.
  All assertions/gates retained; no native exit bypass or forced-exit timeout.
- All 257 source blobs preserved/verified; local format/49 contracts/17 QA passed.
  Prepared QA48 metadata adds this scoped baseline and preserves all 14 pending
  integrations. Hosted Auth, logged-in learner expiry/restart/rotation/two-client,
  uncancelable logoff/kill/power-loss and full acceptance remain unproven.
- Core worker RELEASED after saving evidence. Following four-file docs/QA
  successor has separate CI; resume actual head/checks. Next supported staging
  service configuration + actual learner acceptance, or independent remaining
  product flows while absent. Pro #38/N4 untouched; keep #37 draft/#20/#22/#15 open.
  No dependency/provider/Auth strategy/schema/RLS/API/production changes.

## Explicit owned account refresh action — 2026-10-14 UTC

- Run core-20261014T1952-manual-refresh started/claimed at 2026-10-14T20:00:09Z;
  base/head 5492475f02cfd59d2f4b64f26161660bb46ff3b2 on #37/core branch.
  Latest main 78a44faf; prior exact-head CI38612153007 completed successfully
  with all five latest-attempt jobs. Pro #38/N4 scope remains reserved/untouched.
- Clone proxy had no credential; fetched all 257 blobs freshly through GitHub
  at the actual immutable head, decoded binary/text and checked Git blob SHA1.
  No previous-run source/worktree/SDK was used. Current cloud has no Dart/Flutter
  and lacks jsonschema; retain all CI gates instead of weakening them.
- Added credential-free refresh capability/active-owner provider wiring and
  explicit account “Làm mới phiên” action. Forward to the existing exclusively
  owned SDK/persistence runtime; no learner URL/key or SDK mutation exposed.
  Existing exact-secret save-before-profile gate is unchanged/authoritative.
- Pending UI clears/hides credentials and study/profile, blocks repeated clicks
  and allows explicit logout. Fixed unexpected-error text is scoped to the same
  action/controller/session; logout/switch/replacement/unmount discard old errors.
  No Auth/default activation, automatic retry/timer, secret/log/plaintext fallback.
- Nine controller/widget fixtures added and two existing actual pinned-SDK
  rotation/durable-pending cases use the new command interface without changing
  original assertions. New-source format/analyze/Flutter/Chrome/native/build
  checks must run on GitHub Actions; none is claimed locally. Stdlib QA pending
  verification below. All 14 live release groups and #20/#22/#15 remain open.
- Scope: docs/SESSION_REFRESH.md. Source implementation complete; fresh diff
  review/checkpoint/CI handoff below. Core marker remains ACTIVE until persisted
  and released in PR body. Keep #37 draft; no merge/deployment/provider/RLS/API/
  dependency/N4 changes. Next exact-head CI review/fix, then configured hosted
  learner acceptance or independent remaining product work while unavailable.

### Manual refresh source checkpoint / CI handoff

- Fresh full-tree diff reviewed independently after writing: 13 scoped paths,
  nine new tests plus two retained pinned-SDK cases routed through the action.
  Matched 257 base blobs from GitHub before edits; preserve binary assets and all
  unrelated files. No protected content/N4/content tests, API, schema, dependency
  or CI definition changes. Additive code/test files only expand the tree.
- Stdlib QA inventory passed with 49 cases; all 17 QA regression tests passed.
  Local Flutter/Dart/format/analyze/build/native and 49 contract tests were not
  executed because this fresh cloud runtime lacks SDK/jsonschema. New source
  remains unverified until its exact-head Actions run/latest-attempt gates pass.
  Parent CI38612153007 success is historical, never substituted for new source.
- Core run core-20261014T1952-manual-refresh RELEASED at persisted checkpoint;
  source SHA, current heartbeat and CI URL/status are recorded in #37 body.
  Only waiting on CI after persistence: next run checks the actual head/complete
  latest attempt and fixes any format/analysis/test/native/build failure before
  new implementation. No duplicate worker/code, long keepalive polling, merge,
  deployment or schedule pause. Hosted config and all 14 acceptance groups still
  pending; do not request secrets or report Personal Alpha complete.


## Verified same-session refresh timeout fix — 2026-10-15 UTC

- Resumed PR #37 / `automation/issue-22-atomic-review` at source head `b7198e2`; Pro PR #38 and all N4 paths remained untouched. The diagnostic CI #228 reproduced the original 10-minute timeout after the restored-session event, before the test's readiness assertion; temporary markers were removed before the final change.
- Final source commit `7b8c184ac590d7f07658deccae99a7e3f04fe7b3` changes only `apps/flutter_app/test/features/srs/manual_session_refresh_test.dart`. It replaces the unbounded zero-duration fixture drain in this widget test with bounded Flutter frame pumps, retaining the same-session identity, no-error, ready-runtime and no-exception assertions and the existing 10-minute test timeout.
- Exact-head CI run 38667034793 passed on its latest attempt: ai-boundary, repo-sanity, database, flutter (format, analyze, full test suite and all downstream verification/build steps) and windows. The first Windows attempt failed at an exit-marker fixture check; rerunning only the failed job passed without changing code or gates.
- This proves the regression test and cloud CI path; it is not hosted Auth/learner or Personal Alpha acceptance evidence. Live Auth, multi-device/session rotation, provider integrations and remaining release groups remain open. Next: keep PR #37 draft for review, then continue the documented Auth/vault/session acceptance work without touching Pro N4 scope.


## Verified duplicate same-session Auth event guard — 2026-10-15 UTC

- Resumed PR #37 at source head `437255fa159fd112c361df7f11f495daf9ef7704` after the prior RELEASED marker; Pro PR #38/N4 remained untouched. Added one TEST ONLY lifecycle scenario in `apps/flutter_app/test/features/srs/session_lifecycle_fixtures.dart` for a repeated Auth event with the identical session object and refresh secret.
- The scenario asserts that readiness remains available and the credential vault write count does not increase. It covers the existing `PersistentAccountAccess` same-session/same-secret short-circuit without changing production code, Auth strategy, storage schema, or CI gates.
- Source commit `555dd9a6d09f56e2d84c740aea0829c7b6a7a3c8`; exact-head CI 38678938196 passed all five required jobs, including Flutter format/analyze/full tests and downstream Chrome/native/web/Windows checks. No required job was skipped.
- This is fixture evidence only; hosted Auth signatures, real learner A/B, multi-device rotation and remaining Personal Alpha gates still require supported staging configuration. Keep PR #37 draft and continue only with independently scoped work until that human gate is available.


## Verified pending same-session Auth event coalescing — 2026-10-15 UTC

- Resumed PR #37 at source head `54c010c4bca7197fd4a9ee878192dda6bd6d02aa`; Pro PR #38/N4 remained untouched. Added one TEST ONLY lifecycle scenario in `apps/flutter_app/test/features/srs/session_lifecycle_fixtures.dart` for a duplicate same-session/same-refresh event while the first vault write is still pending.
- The scenario asserts that the duplicate event does not queue a second vault write and that readiness is published only after the original write completes. Production Auth/vault behavior, assertions, API/schema, CI, and security gates are unchanged.
- Source commit `c399870d51f612e5cb76006da3b5133da9e43af8`; exact-head CI run [38681835045](https://github.com/collab-TTAM/nihongo_daily/actions/runs/38681835045) passed on its latest attempt: ai-boundary, repo-sanity, database, flutter (format/analyze/full tests and downstream checks) and windows. The first Flutter attempt exposed one transient existing test failure (370 passed, one null readyRuntime assertion); rerunning only the failed job passed all checks. No required job was skipped.
- This is fixture evidence only; hosted Auth signatures, real learner A/B, expiry/restart/two-client behavior and remaining Personal Alpha gates still require supported staging configuration. Keep PR #37 draft and continue without touching Pro N4 scope.


## Verified same-session secret rotation drain — 2026-10-15 UTC

- Resumed PR #37 at source head `02735fc2bcf31a43d92766604ac423b8f980411e`; Pro PR #38/N4 remained untouched. Added a TEST ONLY lifecycle scenario for a same-session refresh-secret rotation while the first vault write is pending.
- Fixed the owned persistence barrier in `apps/flutter_app/lib/features/auth/data/persistent_account_access.dart`: `_settle()` now drains until the queued write tail is stable, so a newer same-session rotation queued during the first write is persisted before readiness is evaluated. No retry loop, token logging, Auth strategy, schema or CI gate changed.
- Source commit `312327ec1de5e73d87dc8df7c2ef4acf5489c856`; exact-head CI run [38684718287](https://github.com/collab-TTAM/nihongo_daily/actions/runs/38684718287) passed on its latest attempt: ai-boundary, repo-sanity, database, flutter (format/analyze/full tests and downstream checks) and windows. Flutter observed 371 tests with the new scenario; the first Windows attempt hit the known exit-marker fixture flake and rerunning only that failed job passed all Windows checks. No required job was skipped.
- This is fixture and local persistence evidence only; hosted Auth signatures, learner A/B, expiry/restart/two-client behavior and remaining Personal Alpha gates still require supported staging configuration. Keep PR #37 draft and continue without touching Pro N4 scope.

## Guarded SRS due-queue level selection — 2026-10-19 UTC

- Run core-20261019T1332-srs-level-selection resumed released PR #37 at
  92744739be619d78c2df809bc30b051f69033bf3; main 78a44faf unchanged. All five
  latest-attempt exact-head jobs in CI38685894607 passed. Fresh cloud clone
  matches GitHub; no prior temporary source/SDK was used. Pro #14/#38/N4 untouched.
- Added explicit N5/N4 due-queue selection on configured SRS, guarded controller/
  notifier commands and retained level on navigation/empty/error reload. Session
  revocation clears selection. No preview preference/curriculum state is written.
- Controller/UI prevent level changes while loading/recovering/saving or any
  immutable pending/rejected event remains. Explicit rejected-event reload stays.
  Changing level hides revealed content and loads a fresh captured-session queue.
- Five controller and four widget cases added; native recovery test strengthened
  to preserve original request/selected level before exact retry. Existing mobile
  320/375px at 200% cases retained. No N4/content tests/data, dependencies,
  workflow/security/Auth strategy/schema/API/default activation changes.
- Local 17 stdlib QA tests passed; git diff --check passed. Contract tests could
  not import because jsonschema is unavailable. Flutter/Dart SDK is absent, so
  format/analyze/Flutter/Chrome/native/web/Windows checks require exact-head CI.
  Source diff/full-tree preservation reviewed before checkpoint.
- Keep #37 draft and #20/#22/#15 open. All 14 live acceptance groups remain
  pending; no hosted config, learner A/B/restart/two-client or Alpha claim.
  Next: exact-source CI/fix failures, then supported hosted acceptance or the
  next independent increment. Run ACTIVE until source/CI handoff is persisted
  and the PR marker is RELEASED.

### Formatting correction / automatic continuation — 2026-10-19 UTC

- CI39262147940 at fab49332074367204a08303a310f5ac74323fc5c stopped Flutter
  at dart format: one controller-test file changed. Other required checks and
  Flutter downstream steps are not counted as passing on that source.
- Shortened one test description to fit the formatter line width; all assertions,
  nine new cases, behavior and CI/security gates remain unchanged. Corrected
  source still needs exact-head format/analyze/test/native/web/Windows CI.
- User explicitly requested automatic continuation. Existing hourly cloud task
  6ace2a9c236c819189637e49f38182d7 was resumed, enabled=true, in Asia/Saigon;
  no duplicate schedule or cadence/guard changes. Read actual PR/head/CI first.
- Core run core-20261019T1343-srs-format uses fresh GitHub source, expected-head
  update and full-tree verification. Pro #14/#38/N4 unchanged. Keep #37 draft;
  all 14 live release groups remain pending. Final release/CI checkpoint is in
  PR #37 body; next scheduled run fixes any remaining CI failure before new work.

### Analyzer correction — 2026-10-19 UTC

- Exact-head CI39262893248 at c303af4493998a2c33c5167fa2d70333d9848285 passed
  format and four complete jobs (repo-sanity/database/ai-boundary/windows), but
  Flutter analyze stopped on unnecessary_import in srs_study_widget_test.dart.
- Removed the direct PreviewLevel import already exported by preview_preferences.
  No lint suppression, assertion/test removal, production behavior or CI change.
  All nine new level-selection cases still require execution on corrected source.
- Core run core-20261019T1351-srs-analyze resumed released source with a fresh
  GitHub clone, full-tree/expected-head checks and separate diff review. Pro N4
  scope unchanged. Hourly continuation remains enabled; keep PR #37 draft and
  all hosted learner/release gates pending. Exact-source CI and final RELEASED
  checkpoint are recorded in PR #37; next run checks CI before new development.


## Caller-owned Supabase vault integration regressions — 2026-10-31

- Resumed released PR #37 at `afa572a27f050048990ad4feb07fd6f01758e7e2` on
  `automation/issue-22-atomic-review`; Pro #14/N4 files and branch remain
  untouched.
- Added two TEST ONLY cases to
  `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`:
  storage-write failure must block own-profile readiness until an explicit
  retry succeeds; a delayed User A Auth response after logout must not restore
  A or dispatch its profile, and a later User B login must persist/use B's
  captured refresh token and bearer.
- Existing vault ordering, generation/session identity checks, same-session
  rotation drain, timeout/late-startup response, A/B fixture isolation, and
  Windows Credential Manager process probes are unchanged. No Auth strategy,
  default preview activation, schema/RLS, deployment or credential fallback
  changed.
- Source/test commit: `0b844f1f57b1873ed3073efa28860f8d408ee0c2` (parent `afa572a27f050048990ad4feb07fd6f01758e7e2`). Four paths
  changed: runtime SDK test, lifecycle documentation, PROJECT_STATUS, and
  QA matrix. Full 324-entry recursive tree preserved; 320 untouched blobs,
  paths, modes and types are unchanged.
- Source/test/docs/QA increment is committed on this PR branch. Exact-head
  format/analyze/test, native Windows, SQL and web/Windows builds are pending
  GitHub Actions; no local Flutter SDK execution or new test pass is claimed yet.


## Exact-head CI remediation — 2026-10-31

- Exact PR #37 source `de7be9269fde0db734e6b4595f98380da91781f5`, [CI 41196096277](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41196096277), latest attempt 1 exposed two independent environment/source failures: `npm audit --omit=dev` found fast-uri 3.1.8 affected by newly published GHSA advisories; the repo-sanity contract test found the runner's Python accepts `24:00` through `datetime.fromisoformat`, contrary to the frozen canonical-UTC rule. Database was still running at the observation; Windows was skipped and Flutter was not scheduled after the dependency failures. No all-check pass is claimed.
- Remediation: upgrade only the locked transitive fast-uri package to patched 3.1.9 (Ajv's existing `^3.0.1` range already permits it); validate canonical UTC timestamp syntax before datetime parsing, retaining the existing invalid-hour/offset/leap-second/submicrosecond tests.
- New exact-head CI is required for npm audit, Python contracts, Flutter format/analyze/tests, native SQL, Windows and web/Windows builds. No audit gate or test was weakened.


### UTC parser CI correction — 2026-10-31

- CI `41196244613` confirmed the first regex literal was over-escaped: valid fixture timestamps were rejected. The lock-only fast-uri 3.1.9 remediation already passed the exact-head `npm audit` and Prettier steps; AI TypeScript/tests and database were still running at observation.
- Corrected the raw-string regex to use Python digit/decimal escapes once. Existing valid fixtures and the invalid `24:00`, offset, leap-second and >6-digit fraction cases remain unchanged. Re-run the complete latest-attempt workflow; no partial check is treated as release evidence.


## Exact-head CI repair — 2026-10-31 UTC

- Resumed released PR #37 on `automation/issue-22-atomic-review`, source head
  `9c225f16cf825d314fe012abda8e55cc21e1b370`; Pro #14/N4 scope remains untouched.
- Exact-head CI [41196307161](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41196307161)
  completed with repo-sanity, database and ai-boundary successful. Flutter
  stopped at `dart format` for
  `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`.
  Windows completed project-directory, Dart/native bridge and persistent SDK
  runtime checks, then rejected an exit marker at
  `apps/flutter_app/tool/verify_windows_vault_bridge.ps1` line 31.
- Corrected only two overlong test descriptions using adjacent string literals;
  no assertions or behavior changed. Hardened the TEST ONLY Windows marker
  reader to wait for the complete exact sentinel, tolerating a short-lived
  partially-written/locked file rather than treating file existence as write
  completion. The 60-second bound and invalid/missing marker failures remain.
- Exact-head rerun is required for formatter, full Flutter analyze/tests,
  native Windows cancelable-close/drain, and all retained database/security/
  AI/repo checks. No hosted Auth, production, default runtime, Auth strategy,
  schema/RLS, or release acceptance is claimed.


## Exact-head Flutter format correction — 2026-10-31

- Exact-head CI [41200164963](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41200164963), latest attempt 1, source `af17a6468d7cd69b44f59a0adaf11e1a74166acb`, completed with repo-sanity, database, ai-boundary and Windows SUCCESS. Flutter failed only at `dart format --output=none --set-exit-if-changed .` because `test/features/srs/persistent_supabase_runtime_test.dart` was reformatted; Flutter analyze, tests, browser verification and web build were skipped and are not passing evidence.
- Applied the pinned Dart formatter's continuation indentation to the two adjacent test-description literals in that file. No test body, expectation, deadline, production code or assertion changed.
- This runtime has no Flutter/Dart SDK, so the correction awaits a new full exact-head Actions run. Previous successful Windows/SQL/AI/repo jobs are parent evidence only; the new source must execute every required job/step.
- Pro-owned PR #38 / Issue #14 N4 scope remains untouched. No hosted Supabase learner login, Auth strategy, deployment, default activation or Personal Alpha acceptance is claimed.
- Next: inspect the new exact-head latest attempt and all five jobs/every step. Fix only observed failures while retaining assertions/security gates; if only jobs remain pending, hand off without duplicate code.


### Exact-head Flutter formatter correction — 2026-10-31 UTC

- Read the complete latest-attempt jobs and Flutter log for CI 41209781746 at source `b597b3bdd96aa6dae3bc54d2a2d5aaa4ce7e50ec`. Repo-sanity, database, ai-boundary and Windows completed successfully. Flutter failed only because the pinned Dart 3.9.2 formatter changed `test/features/srs/persistent_supabase_runtime_test.dart`; analyze, tests, native/browser checks and web build were skipped and are not passing evidence.
- Applied the formatter's exact three-hunk output to that test file. A token comparison allowing only Dart formatter trailing-comma normalization confirms no test logic or assertion changed; test bodies and timing bounds remain intact.
- Removed the temporary read-only formatter-diagnostic step from `.github/workflows/ci.yml`; the existing `dart format --output=none --set-exit-if-changed .` gate remains unchanged.
- Source, workflow and this handoff are committed together on PR #37. The new commit's full five-job latest-attempt Actions run is the required evidence; no Flutter/analyze/test/build pass is inferred from the failed parent run.
- Pro-owned Issue #14 / PR #38 N4 paths and content tests remain untouched. No Auth strategy, credential behavior, schema, RLS, production, dependency or default-runtime activation changed. PR #37 remains draft; hosted learner and Personal Alpha gates remain pending.


### Exact-head Flutter formatter follow-up — 2026-10-31 UTC

- Inspected complete latest-attempt CI `41214320472` at source `1357b29c16df81e4cc3d851ed431aa2cea8ba5fd`. Repo-sanity, database, ai-boundary and Windows all completed SUCCESS with every returned step successful. Flutter failed only at `dart format --output=none --set-exit-if-changed .`; the formatter reported exactly `test/features/srs/persistent_supabase_runtime_test.dart` as changed. Analyze, Flutter tests, native/browser checks and web build were skipped and are not passing evidence.
- The previous formatter-only correction was insufficient for the pinned Flutter 3.35.4 / Dart 3.9.2 run. This checkpoint adds a temporary read-only `dart format --output=show` + unified-diff diagnostic immediately before the unchanged format gate. It does not rewrite the file, suppress the gate or change tests.
- Next: read the exact diagnostic diff from the new exact-head Actions run, apply only that formatter output to the one test file, remove the diagnostic step, and rerun the full five-job workflow. Keep PR #37 draft; no hosted learner, JWT/PostgREST, staging or Personal Alpha evidence is inferred.


## Core worker checkpoint — RELEASED

- Run marker `core-20261031T1709-dart-format-cleanup`; released UTC 2026-10-31T17:12:49.179Z. Branch `automation/issue-22-atomic-review`; formatter/workflow source commit `c78c8ba3ae501cf7a6bbe94ce05f11be13b1ac95` (parent `da8d7bba9784aafd84b561e5abd37985ba601d2b`). Final handoff commit is recorded by the PR checkpoint.
- Exact-head parent CI [41218145283](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41218145283), attempt 1, head `da8d7bba9784aafd84b561e5abd37985ba601d2b`: repo-sanity, database, ai-boundary and Windows SUCCESS; Flutter FAILURE only at `dart format --output=none --set-exit-if-changed .`. Pinned Dart 3.9.2 diagnostic showed exactly one extra blank line at EOF in `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`; analyze, tests, Chrome, web build and downstream steps were skipped, not passed.
- Applied only that EOF formatting correction and removed the temporary read-only diagnostic step from `.github/workflows/ci.yml`; the original formatter gate and all later checks remain intact. No assertions, test cases, application behavior, Auth strategy, RLS, schema, dependencies or defaults changed.
- Paths: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `.github/workflows/ci.yml`, and this status handoff. Complete recursive source tree was checked untruncated at 324 entries before and after; only the two intended blobs changed in the source commit, with path/type/mode preserved. Pro-owned #14/N4 paths were excluded and unchanged.
- No local Flutter/Dart SDK is available in this runtime. The new exact-head CI must still verify format, analyze, all Flutter tests, browser persistence, web build and the remaining Windows/database/AI/repo gates; no new-head pass or hosted learner proof is claimed.
- Next: inspect all five jobs and every step on the new exact head. Fix only observed failures while retaining assertions and security gates; if checks are merely pending, hand off without duplicate code. Keep PR #37 draft until #20/#22/#15 acceptance and Personal Alpha evidence are complete.


## Core worker handoff — late refresh response fence, 2026-10-31 UTC

- Resumed released PR #37 on `automation/issue-22-atomic-review`, source
  `a17059f5a32f0840d666b6bb036f85b1ea9ca290`, after verifying its exact-head CI
  `41223443638`: all five jobs (`repo-sanity`, `ai-boundary`, `database`,
  `windows`, `flutter`) and every returned step completed SUCCESS. Windows
  included actual Credential Manager/Dart bridge and owned-runtime process
  probes; Flutter included format, analyze, full tests, Chrome IndexedDB,
  native restart/recovery, wire/parity and web build.
- Added one pinned Supabase SDK/owned-runtime regression in
  `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`:
  hold A's refresh-token rotation response, logout and clear, deliver the late
  response, assert no A readiness/profile dispatch/token survives, then
  explicitly sign in B and verify B's rotated secret and captured bearer.
- Updated `docs/PERSISTENT_SESSION_LIFECYCLE.md` with the new test boundary and
  explicit limitation. No Auth strategy/provider, production configuration,
  default preview activation, database/RLS, dependency, N4 content or release
  gate changed. The test uses TEST ONLY HTTP and vault fixtures, not hosted JWT
  or real Supabase A/B evidence.
- Changed paths: the runtime test above, `docs/PERSISTENT_SESSION_LIFECYCLE.md`,
  and this status file. No local Flutter/Dart SDK is available in this runtime;
  run pinned format/analyze/tests and all five required jobs through exact-head
  GitHub Actions. Do not treat parent CI as evidence for the new commit.
- Next: inspect the new exact-head workflow's latest attempt and every job/step;
  fix only observed failures while retaining assertions. Keep PR #37 draft and
  #20/#22/#15 open until hosted Auth, review transaction and multi-device
  learner acceptance are observed.


## Trusted staging refresh default — 2026-10-31 UTC

- Resumed released draft PR #37 on `automation/issue-22-atomic-review` at source
  `a0bdbd01963e3279801a44d2111c3cb272c6e661` after confirming exact-head CI
  [41228518710](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41228518710):
  all five jobs (repo-sanity, database, ai-boundary, Windows and Flutter) and
  every returned step completed SUCCESS. Windows exercised the TEST ONLY
  Credential Manager/Dart bridge, owned runtime, journal compaction/restart and
  configured staging build; Flutter exercised format, analyze, full tests,
  Chrome IndexedDB/restart, session lifecycle, wire/parity and web release.
- For a trusted `ND_MODE=staging` Windows build, `ND_AUTOMATIC_REFRESH`
  now defaults to true; an explicit false remains a supported operator opt-out.
  Absent/preview mode is unchanged and still never constructs Auth, vault or
  learner save success. No learner-entered URL/key, credentials in build values,
  provider/strategy change, schema/RLS change or production activation.
- Updated paths: `apps/flutter_app/lib/app/staging_bootstrap.dart`,
  `apps/flutter_app/test/features/srs/staging_bootstrap_test.dart`,
  `docs/STAGING_BOOTSTRAP.md`, and this handoff. Tests assert the staging
  default, explicit opt-out, and that the configured Windows factory receives
  the refresh setting. Existing pinned-SDK lifecycle tests continue to cover
  startup refresh -> token rotation persistence -> profile readiness, storage
  write failure, late A response after logout, B isolation, and automatic
  refresh/logout fencing.
- No local Flutter/Dart SDK is available in this cloud runtime; this source
  requires fresh exact-head Actions for formatter, analyzer, full Flutter tests,
  native Windows and web build. CI 41228518710 is parent evidence only. No hosted
  signed JWT, deployed PostgREST/RLS, real A/B learner or Personal Alpha proof.
- Next: inspect every job/step on the new exact-head CI. If green, continue #20
  non-production Auth/profile acceptance where approved configuration exists;
  otherwise fix only observed failures. Keep PR #37 draft and #20/#22/#15 open.


## Local Supabase integration CI — connection export repair (2026-10-31 UTC)

- Resumed released PR #37 at `automation/issue-22-atomic-review`, exact source
  `de9cb630cdf05d5485ff087dacc368611621d55e`, after fetching the latest attempt
  of [CI 41238351077](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41238351077)
  and all six jobs/every step. `repo-sanity`, `database`, `ai-boundary`,
  `flutter` and `windows` completed SUCCESS. The new local Supabase job started
  its disposable stack and applied all migrations, then failed while seeding:
  `psql "$DB_URL"` fell back to the runner's Unix socket; the HTTP GoTrue/
  PostgREST step was skipped. This is not an integration pass.
- Root-cause correction: `supabase status -o env` emits shell/dotenv-quoted
  assignments, while GitHub's `GITHUB_ENV` parser does not evaluate shell quotes.
  The workflow now parses with Python `shlex`, validates the local API/database
  loopback endpoints and exports only `API_URL`, `ANON_KEY`, `DB_URL` and
  `JWT_SECRET`. Service-role, secret and storage keys are not propagated to later
  steps. The documented local reproduction imports the same four values only.
- Changed paths: `.github/workflows/ci.yml`, `supabase/README.md`, and this
  status record. No migration, schema, RLS/grant, Auth strategy/provider, test
  assertion, app default, production setting or N4-owned path changed. No local
  Flutter/Docker/Supabase execution is claimed in this cloud runtime.
- New exact-head CI must run the local seed and GoTrue/PostgREST A/B flow before
  this integration can be considered verified. Hosted Supabase and real learner
  evidence remain separate #20/#22 acceptance gates; #15 offline/two-device sync
  remains open. Keep PR #37 draft and do not merge on parent evidence.


## Core worker checkpoint — Windows runtime fixture formatter correction — 2026-11-01 UTC

- Run core-20261101T0109-dart-format-fix; source commit b13158b0b3b88361aeef3f1307b29051fb9cdacb, branch automation/issue-22-atomic-review, parent f19adba75d5d2563fc2c52342c6daeb7044c419b; main baseline 78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c.
- Exact-head CI 41256258064, attempt 1, targeted f19adba75d5d2563fc2c52342c6daeb7044c419b. repo-sanity, database, ai-boundary, windows and supabase-integration completed SUCCESS with all returned steps. Flutter failed only at dart format --output=none --set-exit-if-changed .: pinned Dart 3.9.2 reported only tool/windows_runtime_fixture.dart changed. Flutter analyze, tests, native/browser verification and web build were skipped because the format gate failed.
- Applied formatter continuation indentation to the two nested conditional expressions in apps/flutter_app/tool/windows_runtime_fixture.dart. Commit diff confirms only whitespace/continuation indentation changed; no condition, selected value, assertion, fixture behavior or production runtime code changed. No test/security gate was weakened.
- Changed paths in this increment: the Windows runtime fixture above and this status document. Full recursive source tree was untruncated at 327 entries; the source tree was built with the exact parent commit tree as base_tree_sha. All paths/modes/types were retained and all untouched blobs preserved. The docs tree was based on the exact source commit tree. Ref updates used expected_sha and force=false.
- No local Flutter/Dart SDK is available in this cloud runtime. The corrected source requires exact-head Actions for format, analyze, all Flutter tests, Windows bridge, Supabase local integration and web build. No new-head CI pass is claimed at this checkpoint.
- Auth HTTP/JWT in the Windows fixture remains TEST ONLY MockClient/unsigned synthetic data. No hosted Supabase, signed hosted JWT, deployed RLS, real learner A/B, two-device sync, production setting, Auth provider/strategy, schema/RLS, or Pro #14/N4 scope changed. PR #37 remains draft; #20/#22/#15 and Personal Alpha acceptance remain open.
- Next: inspect every latest-attempt job and every step on the corrected exact head; fix only observed failures. If all checks pass, continue hosted non-production Auth/PostgREST A/B and learner acceptance when approved staging configuration is available.

## Latest handoff — pinned Dart formatter diagnostic (2026-11-01 UTC)

- Core run `core-20261101T0211-dart-format-diagnostic`; branch `automation/issue-22-atomic-review`; source parent `4c8cfc4a0c2c1cc57499571412ebc5b3a19075c8`; main baseline `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41260058857](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41260058857), attempt 1, completed on `4c8cfc4a0c2c1cc57499571412ebc5b3a19075c8`: `repo-sanity`, `database`, `ai-boundary`, `windows`, and `supabase-integration` all succeeded. Flutter failed only at `dart format --output=none --set-exit-if-changed .`, which reported `tool/windows_runtime_fixture.dart` changed; Flutter analyze, tests, wire verifiers and web build were skipped, not passed.
- Added a temporary read-only diagnostic immediately before the unchanged strict format gate. It writes Dart 3.9.2 formatted output to `$RUNNER_TEMP` and prints a unified diff; it does not modify source or turn a formatting failure into success. The diagnostic must be removed after applying the exact diff.
- No production/Auth/RLS/schema/dependency/default-preview changes. No N4/Pro paths touched. No local Flutter/Dart SDK is available here; exact pinned CI is the formatter authority.
- Next: inspect the diagnostic run's latest attempt and all jobs/steps; apply only the emitted formatter changes, remove this temporary step, then rerun full CI on the resulting exact head. Keep PR draft and #20/#22/#15 open; hosted learner A/B and Personal Alpha evidence remain outstanding.

## Core worker checkpoint — pinned Dart formatter correction — 2026-11-01 UTC

- Run `core-20261101T0310-dart-format-finalize`; source commit pending at this checkpoint, branch `automation/issue-22-atomic-review`, parent `16e1da0c351e76673b8fc47face8aac9235c0978`, main baseline `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head diagnostic CI [41264316676](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41264316676), attempt 1, targeted `16e1da0c351e76673b8fc47face8aac9235c0978` and completed with five of six jobs successful: `repo-sanity`, `ai-boundary`, `database`, `supabase-integration`, and `windows` completed SUCCESS with all returned steps. `flutter` failed only at `dart format --output=none --set-exit-if-changed .`. The diagnostic step reported three formatter hunks in `tool/windows_runtime_fixture.dart`: two nested-conditional continuation-indent corrections and one multiline `_check` assertion. The trailing `Formatted 1 file` line is formatter CLI output, not source content. `flutter analyze`, `flutter test`, downstream native/browser/wire checks and web release build were SKIPPED, not passed.
- Applied exactly the pinned Dart 3.9.2 formatter output to `apps/flutter_app/tool/windows_runtime_fixture.dart`; only whitespace/line wrapping changed. No condition, selected value, assertion meaning, test behavior, production runtime, or security gate changed.
- Removed the temporary read-only diagnostic from `.github/workflows/ci.yml`; the strict format gate and every downstream CI step remain unchanged.
- Changed paths in this increment: `apps/flutter_app/tool/windows_runtime_fixture.dart`, `.github/workflows/ci.yml`, and this status document. The full recursive parent tree was untruncated at 327 entries (262 blobs, 65 trees); no path, mode or type changes are intended, and every untouched blob is retained by the exact parent tree base.
- No local Flutter/Dart SDK is available in this cloud runtime. The corrected exact-head Actions run must establish format, analyze, full tests, Windows bridge/vault, local Supabase integration, native/browser checks and web build; no corrected-head result is claimed yet.
- Test evidence remains bounded: the Windows bridge uses real Windows Credential Manager/MethodChannel/native journal but TEST ONLY MockClient and unsigned synthetic JWT. No hosted Supabase signed JWT, deployed PostgREST/RLS, real learner A/B, two-device sync or Personal Alpha proof. No Auth provider/strategy, migration, RLS, default preview, production setting or Pro-owned #14/#38/N4 path changed.
- Next: inspect every latest-attempt job and every step on the new exact head; fix only observed failures. Keep PR #37 draft and #20/#22/#15 open until their complete acceptance is met.


## Core worker checkpoint — analyzer correction — 2026-11-01 UTC

- Run core-20261101T0414-remove-unnecessary-assertion; branch automation/issue-22-atomic-review; source parent 1548bddafda85feef90710dc94b77b117f01a236; main baseline 78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c.
- Exact-head CI 41268186316 (https://github.com/collab-TTAM/nihongo_daily/actions/runs/41268186316), attempt 1, targeted 1548bddafda85feef90710dc94b77b117f01a236. repo-sanity, ai-boundary, database, supabase-integration, and windows all completed SUCCESS with every step successful. flutter failed at flutter analyze after the format gate passed: one warning, unnecessary_non_null_assertion at tool/windows_runtime_fixture.dart:216; flutter test and all downstream Flutter checks/build were SKIPPED, not passed.
- Corrected only the redundant ! in lateRefresh!.complete(authResponse()). Flow analysis already proves the completer is non-null after assignment in this branch; completion timing and late-refresh/logout assertions are unchanged.
- Full recursive parent tree was untruncated at 327 entries (262 blobs, 65 trees). The write is based on the exact parent tree; no path/mode/type changes. Only the fixture and this status document are intended to change; all other blobs are retained.
- No Flutter/Dart SDK is available in this cloud runtime, so no local analyze/test/build is claimed. New exact-head CI must verify formatter, analyzer, full Flutter tests, Windows bridge/vault, local Supabase integration and web build.
- Test limits remain: the Windows vault/MethodChannel/native journal checks use TEST ONLY MockClient and synthetic unsigned JWT. No hosted signed JWT, deployed PostgREST/RLS, real learner A/B, two-device sync or Personal Alpha acceptance is established. No Auth strategy/provider, migration, RLS, default preview, production or Pro-owned #14/#38/N4 paths changed.
- Next: inspect every latest-attempt job and every step on the corrected exact head; fix only observed failures. Keep PR #37 draft and #20/#22/#15 open.


## Core worker checkpoint — caller-owned vault read failure — 2026-11-01

- Run `core-20261101T0509-auth-read-failure`; bounded source/test increment on `automation/issue-22-atomic-review`, parent `64181b8562962c92c1a7640d6712c7f44b9e65b1`, main baseline `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Added a pinned Supabase SDK + caller-owned `PersistentSupabaseRuntime` regression for a stored refresh secret whose vault read fails at startup. It requires failed persistence phase, no Auth token request, no own-profile request, no published study runtime and preservation of the stored entry until explicit cleanup. Once storage recovers, explicit login must execute method order `read -> clear -> write`, persist the newly rotated secret, then issue exactly one own-profile request with the captured User A bearer.
- TEST ONLY method-name trace was added to the in-memory lifecycle backend; it never records token/password values. No production Auth logic, provider/strategy, default preview activation, API/schema/RLS, Pro-owned #14/#38/N4 content or deployment changes.
- Changed paths: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `apps/flutter_app/test/features/srs/session_lifecycle_fixtures.dart`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, `qa/matrix.json`, and this status document.
- Parent exact-head CI [41272488852](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41272488852), attempt 1, on `64181b8562962c92c1a7640d6712c7f44b9e65b1` passed all six jobs and every returned step, including Flutter format/analyze/tests, Windows vault/runtime process probes, disposable local Supabase integration and web/Windows release builds. This is parent evidence only; it does not verify this new regression.
- No Flutter/Dart SDK is available in this cloud runtime; local format/analyze/test/build were not run. New exact-head CI is required. Fixtures still use TEST ONLY MockClient/unsigned JWT/in-memory credential backend; no hosted signed JWT, deployed PostgREST/RLS, real learner A/B or two-device sync evidence is claimed.
- Next: inspect the latest attempt for the new exact head and every job/step; fix only observed failures. Keep PR #37 draft and #20/#22/#15 open until their full acceptance and hosted learner evidence are met.


## Exact-head formatter diagnosis — 2026-11-01 UTC

- Resumed the released core checkpoint on `automation/issue-22-atomic-review` at exact source head `4a7006da3454b810dc8ac4f36acd53d2516efaef`; main remains `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. PR #37's prior worker marker was RELEASED at 05:14:56Z; no active core writer was observed before this run.
- Fetched complete latest-attempt CI [41276156887](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41276156887), attempt 1, targeting exactly `4a7006da3454b810dc8ac4f36acd53d2516efaef`. Five jobs succeeded with every step: repo-sanity, ai-boundary, database, supabase-integration and Windows. Flutter failed only at pinned Dart 3.35.4 `dart format --output=none --set-exit-if-changed .`, which reported exactly `test/features/srs/persistent_supabase_runtime_test.dart` and `test/features/srs/session_lifecycle_fixtures.dart`. Flutter analyze, tests and downstream verifiers/build were skipped, not passed.
- Added a temporary read-only CI diagnostic immediately before the unchanged strict formatter gate. It runs pinned `dart format --output=show` for those two files and emits unified diffs; it does not edit files or turn the strict gate into success. Remove this diagnostic after applying the exact output.
- Changed paths in this diagnostic checkpoint: `.github/workflows/ci.yml` and this status document. No Auth/runtime, schema/RLS, API, dependency, default-preview or Pro-owned N4 changes. No local Flutter/Dart SDK is available in the cloud runtime; no local format/analyze/test/build is claimed.
- Test limits remain: Auth HTTP/JWT and in-memory credential storage are TEST ONLY; local Supabase is disposable CI, not hosted learner evidence. No hosted signed JWT, deployed PostgREST/RLS, real learner A/B, two-device sync or Personal Alpha acceptance is claimed. Keep PR #37 draft and #20/#22/#15 open.
- Next: inspect all latest-attempt jobs/steps on the diagnostic exact head; apply only the emitted Dart formatter hunks to the two files, remove the temporary diagnostic, and rerun full CI on the final source head. If diagnostic output is unavailable, do not guess formatting.


## Exact-head formatter repair — 2026-11-01 UTC

- Resumed the released PR #37 core checkpoint on `automation/issue-22-atomic-review` at `c2524b1c72e484409e3fd2d20a59089d549556e5`. Re-read current `main`: `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. PR #37 remained open/draft; Pro-owned PR #38 remained on `automation/issue-14-n4-content` at `28c20cb02790cc7b5591c4839cda537dd516a29a`, untouched.
- Exact-head diagnostic CI [41279806755](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41279806755), attempt 1, targeted `c2524b1c72e484409e3fd2d20a59089d549556e5`. `repo-sanity`, `ai-boundary`, `database`, `windows` and `supabase-integration` completed SUCCESS with all returned steps. `flutter` failed only at `dart format --output=none --set-exit-if-changed .`; its read-only diagnostic emitted the exact pinned Dart 3.35.4 formatter hunks for `test/features/srs/persistent_supabase_runtime_test.dart` and `test/features/srs/session_lifecycle_fixtures.dart`. Flutter analyze, tests, native/browser/wire verifiers and web build were SKIPPED, not passed.
- Applied the emitted formatting: split the `ensure_profile` request filter across the formatter-required lambda lines; split the TEST ONLY `operations.add(method)` call to keep its explanatory line comment; retained the formatter-emitted terminal blank line in both files. Removed the temporary diagnostic step from `.github/workflows/ci.yml`. The strict formatter, analyzer, test, native/browser, wire and web-build gates remain unchanged.
- Source commit: `895edef159f10a69360120f6b6ee1f9d56042331`, parent `c2524b1c72e484409e3fd2d20a59089d549556e5`, tree `b5d66f3233ae66891d8dd78bc1b04578a7bc756f`. Changed source paths: `.github/workflows/ci.yml`, `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `apps/flutter_app/test/features/srs/session_lifecycle_fixtures.dart`; no assertion meaning or production behavior changed.
- Full recursive source tree was read untruncated before and after: 327 entries (262 blobs, 65 trees); no path additions/removals or mode/type changes. Exactly the three intended blob SHAs changed; seven ancestor tree SHAs changed as expected; all 259 untouched blobs remained identical. `create_tree` used exact parent tree `f7273f8c60f58d0b52016637ef0249ecf411d860`; ref update used `expected_sha=c2524b1c72e484409e3fd2d20a59089d549556e5`, `force=false`; branch and PR readback matched the new head.
- No Flutter/Dart SDK is available in this cloud runtime; local format/analyze/test/build were not run. The corrected source requires fresh exact-head Actions. The local Supabase job is disposable CI, not hosted service evidence. Auth/JWT test fixtures remain TEST ONLY; no hosted signed JWT, deployed PostgREST/RLS, real learner A/B, two-device sync or Personal Alpha acceptance is claimed. No Auth strategy/provider, migration, RLS/grant, production setting, default preview activation, paid AI, Pro #14/N4 content or PR #38 scope changed.
- Next: inspect every latest-attempt job and step on the documentation/final exact head. Keep PR #37 draft and #20/#22/#15 open until full acceptance and hosted learner evidence are observed; do not treat skipped Flutter checks or local Supabase fixtures as release proof.


## Exact-head formatter re-diagnosis — 2026-11-01

- Resumed the released core PR #37 checkpoint on `automation/issue-22-atomic-review` at exact head `7e7c03c7feda4ad30ee7b48e687a36affa644784`; latest main remains `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. The previous worker marker was RELEASED at 07:14Z; no other active core writer was observed.
- Exact-head CI [41283759870](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41283759870), attempt 1, targeted `7e7c03c7feda4ad30ee7b48e687a36affa644784`. `repo-sanity`, `ai-boundary`, `database`, `supabase-integration`, and `windows` completed SUCCESS with every step. Flutter failed at pinned Dart 3.35.4 `dart format --output=none --set-exit-if-changed .`, which reported exactly `test/features/srs/persistent_supabase_runtime_test.dart` and `test/features/srs/session_lifecycle_fixtures.dart`. Flutter analyze, tests, native/browser/wire verifiers and web build were SKIPPED, not passed.
- The earlier claimed formatter repair did not satisfy the exact pinned formatter on this head. To avoid another guessed edit, this checkpoint adds a temporary read-only Python wrapper around `dart format --output=show` immediately before the unchanged strict format gate. It prints unified diffs for those two files only; it does not write either file. The strict format/analyze/test/build gates are unchanged.
- Changed paths: `.github/workflows/ci.yml` (diagnostic ordering only) and this status document. No production Auth/runtime, API/schema, migration/RLS, dependency, preview-default, Pro-owned #14/#38/N4 or deployment change.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. TEST ONLY MockClient/unsigned JWT/in-memory vault and disposable local Supabase remain non-hosted evidence; no real learner A/B, hosted PostgREST/RLS or two-device sync proof is claimed.
- Next: inspect the diagnostic output from the new exact-head CI; apply only its actual formatter diff, remove this temporary step, then rerun the complete latest-attempt CI on the final exact head. Keep PR #37 draft and #20/#22/#15 open.


## Core checkpoint — formatter EOF repair — 2026-11-01

- Run `core-20261101T0908Z-dart-eof-fix`; branch `automation/issue-22-atomic-review`; main baseline `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`; parent `2a3f26e6563ca757c4dbd75fdf0d75b7ed88adb9`; source fix commit `997bcb5c600829a62f3ac3982882f158202bc5e2`; tree `f28f9b1b9bb717417642fd3f416d279631d0a7df`.
- Exact-head CI [41288194908](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41288194908), attempt 1, targeted parent `2a3f26e6563ca757c4dbd75fdf0d75b7ed88adb9`. Latest-attempt jobs: `repo-sanity`, `ai-boundary`, `database`, `windows`, and `supabase-integration` SUCCESS with every step; `flutter` FAILURE at `dart format --output=none --set-exit-if-changed .`. Flutter analyze, tests, lifecycle/vault/profile/browser/native/wire verifiers and web build were SKIPPED, not passed.
- The pinned Dart 3.35.4 diagnostic emitted exactly one extra blank line at EOF in each of `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart` and `apps/flutter_app/test/features/srs/session_lifecycle_fixtures.dart`; no executable source lines differed. Removed only that final empty line from each file. Removed the temporary read-only formatter diagnostic step from `.github/workflows/ci.yml`; the strict formatter/analyze/test/build steps remain unchanged.
- Parent-to-source diff review confirms exactly those three paths; the only Dart source diff is one deleted blank line at EOF in each test file. No assertions, runtime behavior, Auth, vault, schema, RLS, API contracts, dependency lock, or Pro-owned #14/#38/N4 files changed.
- `create_tree` used the exact parent tree `d3202d1c64d44c7e56d81ebc6fecd37c73719218`; the previously verified full parent tree contains 327 entries (262 blobs, 65 trees), and all unmentioned entries were inherited through the base tree. Parent-to-child comparison reports exactly three intended paths, with no additions/deletions.
- The Windows job in the parent CI passed the TEST ONLY Dart-to-Windows bridge, cross-process credential-store, Windows release build, native receipt-cache, journal compaction, durable review restart and durable study recovery steps. Supabase Integration passed against a disposable local stack (GoTrue/PostgREST, rotation/replay/A-B RLS); this is not hosted learner evidence.
- Cloud runtime has no Flutter/Dart SDK, so no local format/analyze/test/build was run. The source fix is now persisted and a fresh CI is expected on the documentation/final head; no result for that new head is claimed yet.
- Keep PR #37 draft and #20/#22/#15 open. Hosted signed JWT/PostgREST/RLS, real learner A/B, restart/expiry and two-device sync evidence remain outstanding; no Personal Alpha acceptance is claimed.
- Next: inspect every latest-attempt job and step for the final documentation head. Fix only observed failures; if all required checks pass, continue the next unblocked integration acceptance without merging this still-incomplete draft.



## Local two-session atomic review integration — 2026-11-01 UTC

- Run `core-20261101T1009Z-two-session-replay` on branch `automation/issue-22-atomic-review`; source parent `9c1a9f5a635b30f3b23311d2a2af7bea9e4f38f8`; main baseline `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Extended `scripts/test_supabase_local.py` to sign the same disposable learner into two independent GoTrue password sessions, submit one immutable review concurrently through both bearers, require identical original receipts and one counter increment, reject changed replay and a stale second-session event, compare the same authoritative user-learning projection from both sessions, and verify global logout revokes both refresh sessions. Existing separate A/B RLS, expired signed JWT, profile bootstrap and token-rotation checks remain.
- Updated `docs/SRS_RPC.md` and the `review-transaction` QA anchor. The `offline-sync` release case remains pending: this is two authenticated local HTTP sessions, not two physical devices, browser/native cache transfer, hosted learner accounts or offline restart/reconnect acceptance.
- This source change requires the exact-head disposable Supabase integration job and full six-job CI. Cloud runtime has no Docker/hosted project or Flutter/Dart SDK; no local Supabase, Flutter, Windows or web build is claimed. No Auth strategy/provider, migration/RLS, API schema, secrets, production/default-preview or Pro-owned #14/#38/N4 scope changed.
- Next: inspect every latest-attempt job/step on the new exact head; fix only observed failures. If CI passes, retain #20/#22/#15 open until hosted learner A/B and actual multi-device sync evidence are supplied.



## Local two-session review test and six-job QA evidence gate — 2026-11-01 UTC

- Run `core-20261101T1009Z-two-session-replay`; source increment `3621480e5ec795aba88058dee0e7dbb120db41b1` extends the disposable GoTrue/PostgREST test. The exact parent CI [41292002923](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41292002923) on `9c1a9f5a635b30f3b23311d2a2af7bea9e4f38f8` completed SUCCESS: all six jobs and every returned step (including local Supabase integration, Windows, Flutter format/analyze/test/Chrome/browser restart/native recovery/web build) passed. This is parent evidence, not evidence for the new source.
- Review of `scripts/verify_qa.py` found its `REQUIRED_JOBS` and `qa/matrix.json` tracked only five CI jobs although `.github/workflows/ci.yml` runs six, omitting `supabase-integration`. A full run could therefore not be represented faithfully by the QA evidence validator. The follow-up corrects the required six-job set, adds exact Supabase integration steps and a dedicated `local-two-session-sync` automated-baseline case, plus a regression that rejects the omission. The 14 Personal Alpha release cases remain pending.
- Changed source paths in the follow-up: `scripts/verify_qa.py`, `qa/test_verify_qa.py`, `qa/matrix.json`, `docs/QA_SECURITY_MATRIX.md`, `docs/PROJECT_STATUS.md`. No workflow jobs/checks are removed or weakened; no production/Auth strategy/provider, SQL migration/RLS, API contract, curriculum or Pro-owned #14/#38/N4 scope changes.
- The new same-owner test uses two separate password sessions against the disposable local GoTrue/PostgREST stack. It is not hosted learner proof or physical-device offline-cache transfer. Cloud runtime has no Docker/hosted project or Flutter/Dart SDK; exact-head CI is required. No local Supabase, Flutter, Windows or web build is claimed.
- Next: inspect all six latest-attempt jobs and every critical step on the final exact head; keep #37 draft and #20/#22/#15 open until hosted learner and physical multi-device acceptance is observed.


## Core handoff — cross-session historical replay after newer review — 2026-11-01

- Branch `automation/issue-22-atomic-review`; source parent `f4079ca02039363f56c616b6c1c8399d2a926a5d`; main baseline `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. Previous exact-head CI [41296769317](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41296769317) completed SUCCESS on `f4079ca02039363f56c616b6c1c8399d2a926a5d` with all six jobs and every step successful; this is parent evidence only.
- Added a local disposable GoTrue/PostgREST regression in `scripts/test_supabase_local.py`: two independent same-owner sessions concurrently submit one event; session A then commits a later distinct review; session B retries the original event and must receive the original immutable receipt while the server-authoritative row remains at review_count 2 and is byte-for-byte unchanged. Existing changed-payload/stale conflicts, A/B RLS, refresh rotation and global logout assertions remain.
- Updated `docs/SRS_RPC.md` to state the cross-session historical replay guarantee and its LOCAL ONLY boundary. No schema/migration, RLS, API contract, Auth strategy/provider, default app activation, production setting, secret, or Pro-owned #14/#38/N4 file changed.
- Exact-head CI for the new source/doc commit is required; this cloud runtime has no Docker/Flutter SDK, so no local Supabase/Flutter execution is claimed. This test remains disposable local-service evidence, not hosted learner or physical-device/offline cache-transfer proof.
- Next: inspect every latest-attempt job/step on the new exact head; fix only observed failures. Keep PR #37 draft and #20/#22/#15 open until their full acceptance evidence is met.


## Exact-head formatter diagnosis — 2026-11-01 UTC

- Resumed draft PR #37 at branch `automation/issue-22-atomic-review`, source head `1df667b6455f1c5788ce62b21be790dc6841e8b2`; the previous corrupt-vault restore fixture remains intact. The latest exact-head run [41320726555](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41320726555), attempt 1, completed all six jobs: `repo-sanity`, `database`, `ai-boundary`, `supabase-integration`, and `windows` passed every returned step; `flutter` failed only at strict `dart format --output=none --set-exit-if-changed .`. Analyze, tests, browser/native verification and web build were skipped by that failure, so they are not pass evidence.
- CI log identifies `test/features/srs/session_refresh_scheduler_test.dart` as the formatter delta. A temporary read-only diagnostic step now prints the formatter's exact unified diff before the unchanged strict format gate. It neither writes files nor changes the gate/exit behavior. Next: read the diagnostic output on the new exact head, apply only the formatter output, remove this temporary step, then require all six jobs/every step on the resulting exact head.
- This is CI diagnosis only; no production behavior, Auth strategy/provider, API/schema/RLS, default app activation, deployment or Pro-owned #14/#38/N4 scope changes. Cloud runtime has no local Flutter/Dart SDK; no local format/analyze/test/build was run. Keep #37 draft and #20/#22/#15 open.


- Diagnostic command syntax was re-read from GitHub before Actions: the first checkpoint had an escaped line-continuation typo (two backslashes). It was corrected to a single shell pipeline on the next expected-head commit; the strict formatter gate remains untouched. The diagnostic step is still read-only and temporary.


## Exact-head formatter correction — 2026-11-01 UTC

- Run `core-20261101T1705Z-dart-format-cleanup`; source parent `cab705e9ead890b26f8969ff1d560e4a14999de7`, branch `automation/issue-22-atomic-review`, main baseline `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. The complete base tree contained 327 entries and was checked untruncated before writing.
- Exact-head CI [41325343958](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41325343958) failed only at pinned Dart `format --set-exit-if-changed`. The read-only diagnostic emitted one formatter change in `test/features/srs/session_refresh_scheduler_test.dart`: collapse the three-line `RefreshLease(identity, oldExpiry.add(...))` construction to one line. The other five jobs (repo-sanity, AI boundary, database, Windows and disposable Supabase integration) completed successfully; Flutter analyze, tests and web build were skipped after the format failure.
- Applied exactly that formatter output, removed the temporary diagnostic workflow step, and left the strict formatter gate, analyzer, tests, browser/native checks and builds unchanged. No production Auth/session behavior or test assertions changed.
- Cloud runtime has no Flutter/Dart SDK, so local format/analyze/test/build were not run. New exact-head GitHub Actions is required; no new-head pass is claimed. No hosted signed-JWT learner A/B, physical multi-device sync, Auth strategy/provider, migration/RLS, default activation, production deployment or Pro-owned #14/#38/N4 change.
- Next: inspect every latest-attempt job and step for the new exact head. Fix only observed failures; if checks remain pending, persist a released handoff without duplicate source changes. Keep PR #37 draft and #20/#22/#15 open.


## Core worker handoff — bounded Auth response classification — 2026-11-01 UTC

- Run `core-20261101T1805Z-bounded-auth-response-classification`; branch
  `automation/issue-22-atomic-review`; parent `5f0428d8cf78cf836b5a29b951037253a924c0a1`; base main
  `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Before this increment, exact-head CI
  [41329988599](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41329988599)
  completed **all six jobs and every returned step successfully** on
  `5f0428d8cf78cf836b5a29b951037253a924c0a1`: repo-sanity, ai-boundary, database, supabase-integration,
  windows and flutter. Flutter strict format, analyze, full tests, session/vault/
  profile checks, Chrome IndexedDB/browser reload, native recovery, actual Dart
  wire projections and Web release build passed. Windows vault bridge/cross-process
  Credential Manager, Windows release, retention, compaction and durable restart
  checks passed. The disposable local Supabase GoTrue/PostgREST A/B/rotation/
  replay/RLS test passed. These are exact-head CI component/local-stack results,
  not hosted learner A/B or physical multi-device acceptance.
- Corrected the owned Auth HTTP error boundary: oversized response bodies retain
  non-retryable INTERNAL_ERROR; request/body timeouts and HTTP client transport
  failures retain retryable NETWORK_UNAVAILABLE. Only sanitized
  ReviewTransportFailure values cross the SDK/persistent-account adapters;
  unknown exceptions still collapse to a safe generic error. Added an oversized
  Auth response fail-closed regression and strengthened the timeout classification
  assertion. No token/body is logged or exposed.
- Paths: `apps/flutter_app/lib/features/auth/application/persistent_supabase_runtime.dart`,
  `apps/flutter_app/lib/features/auth/data/persistent_account_access.dart`,
  `apps/flutter_app/lib/features/auth/data/supabase_account_access.dart`,
  `apps/flutter_app/lib/features/srs/data/supabase_review_binding.dart`,
  `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`,
  `qa/matrix.json`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, and this status file.
- Cloud runtime has no Flutter/Dart SDK or Windows OS; local format/analyze/test/
  build and native execution were not run. The exact-head Actions run for the new
  commit is the required verification; pending/skip/fail steps are not passes.
- No Auth strategy/provider, migration/RLS, API contract, default Auth activation,
  secrets, production deployment, or Pro-owned #14/#38/N4 paths changed. Keep
  PR #37 draft and #20/#22/#15 open; hosted signed-JWT/PostgREST learner A/B,
  real expiry/restart and physical two-device offline reconciliation remain
  outstanding. Next: inspect every latest-attempt job/step on the new exact head
  and fix only observed failures.


## Core worker checkpoint — formatter diagnostic for Auth regression — 2026-11-01 UTC

- Run `core-20261101T1909Z-format-diagnostic`; branch `automation/issue-22-atomic-review`; parent `00384258bd6a549be3cbd4525c32da028b90c9a4`; main baseline `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41335171988](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41335171988) targeted that parent and completed all six jobs. `repo-sanity`, `database`, `ai-boundary`, `supabase-integration`, and `windows` passed every returned step. `flutter` failed only strict pinned-Dart formatting, naming `test/features/srs/persistent_supabase_runtime_test.dart`; analyze, tests, browser/native checks and Web build were skipped, not passed.
- Added a temporary read-only CI diagnostic that prints the pinned Dart 3.35.4 unified formatter diff for that exact test file before the unchanged strict format gate. It writes only under `$RUNNER_TEMP`, never edits source, and exits successfully after printing the diff; no checks/assertions were weakened.
- Changed paths in this diagnostic checkpoint: `.github/workflows/ci.yml` and `docs/PROJECT_STATUS.md`. The complete base tree was fetched untruncated (327 entries / 262 blobs); `create_tree` uses its exact tree SHA. No Pro-owned #14/#38/N4 paths or production Auth/default activation changed.
- Cloud runtime has no Dart/Flutter SDK; local format/analyze/test/build were not run. The diagnostic exact-head Actions run is pending; no new-head test/build pass is claimed.
- Next: inspect all six latest-attempt jobs/every step, read the exact formatter diff, apply only that output, remove the temporary diagnostic, then require all six jobs/every step on the corrected exact head. Keep PR #37 draft and #20/#22/#15 open; hosted signed-JWT learner A/B and physical multi-device acceptance remain outstanding.

## Core worker handoff — pinned Auth test formatter correction — 2026-11-01 UTC

- Run `core-20261101T1917Z-format-fix`; parent `301e9237b818293d25f724a307583a5b451e240b`; branch `automation/issue-22-atomic-review`; main baseline `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head diagnostic CI [41340760524](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41340760524) observed: `repo-sanity`, `database`, and `ai-boundary` passed every step; Flutter failed only strict format, and the read-only diagnostic emitted the exact change for `persistent_supabase_runtime_test.dart`. `supabase-integration` failed at disposable service startup; its command redirects output to `/dev/null`, so the cause is unknown and is not inferred. Windows was still in progress at the last observation.
- Applied only the emitted formatter layout to the new oversized-Auth-response regression and removed the temporary diagnostic step. Test logic/assertions, strict format gate, analyzer, test suite, browser/native checks and builds are unchanged.
- Paths: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `.github/workflows/ci.yml`, and this status file. Full base tree was verified untruncated (327 entries); exact `base_tree_sha` is used. No production Auth/default activation, schema/RLS, secrets or Pro-owned #14/#38/N4 changes.
- Cloud runtime has no Dart/Flutter SDK; local format/analyze/test/build were not run. New exact-head CI is required; no new-head pass is claimed.
- Next: inspect all six latest-attempt jobs/every step on the corrected head. If the disposable Supabase startup fails again, diagnose safely without printing local keys; keep PR #37 draft and #20/#22/#15 open pending hosted learner A/B and physical multi-device acceptance.
- Follow-up formatter diff review retained the blank line between adjacent test cases and a terminal newline; no behavior or assertion changed.


## Core worker handoff — preserve Auth transport failures across SDK wrapping — 2026-11-01 UTC

- Run `core-20261101T2012Z-auth-transport-errors`; branch `automation/issue-22-atomic-review`; parent `d1fbc7e9978d7402082772b3d30be1ad9f9a1281`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41341151828](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41341151828) completed on `d1fbc7e9978d7402082772b3d30be1ad9f9a1281`: `repo-sanity`, `ai-boundary`, `database`, `windows` and `supabase-integration` passed every step. Flutter format/analyze passed, but `flutter test` reported **388 passed / 2 failed**; every later Flutter verification/build step was skipped. The two failures were the existing oversized-Auth-response test (expected `INTERNAL_ERROR`, received `UNAUTHORIZED`) and timeout/late-response test (expected retryable `NETWORK_UNAVAILABLE`, received `UNAUTHORIZED`).
- Root cause confirmed from the pinned SDK path: `_BoundedSessionHttp` threw the correct typed error, but Supabase Auth wrapped the injected-client exception; `_OwnedSdkAccess` then mapped the wrapper through its generic catch to unauthorized.
- Implemented a private, ephemeral, single-operation transport-failure channel in `_BoundedSessionHttp`; `_OwnedSdkAccess` clears/consumes it around serialized sign-in/restore/refresh. Only typed safe codes cross the SDK wrapper; unknown errors remain unauthorized. Auth request bounds, 1 MiB cap, timeout, late-response cancellation, SDK retry policy, vault ordering and profile barrier are unchanged.
- Paths: `apps/flutter_app/lib/features/auth/application/persistent_supabase_runtime.dart`, `qa/matrix.json` (anchor the two pinned-SDK regressions), `docs/PERSISTENT_SESSION_LIFECYCLE.md`, and this status file. No test/assertion gate, API, Auth strategy/provider, default activation, migration/RLS, dependency or Pro-owned #14/#38/N4 scope changed.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. New exact-head Actions must verify the code and QA anchors; no new-head pass is claimed.
- Next: inspect every latest-attempt job/step on the new exact head, fix only observed failures, then continue hosted non-production learner A/B/session-restoration evidence and real two-device offline reconciliation. Keep PR #37 Draft and #20/#22/#15 open.


## Core worker checkpoint — owner-scoped cross-account event identity — 2026-11-01 UTC

- Run `core-20261101T2106Z-owner-scoped-offline-idempotency`; branch `automation/issue-22-atomic-review`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`; parent `fbd6a60869e55379d104092c4ce9cafa4a09b2cc`.
- Prior exact-head CI [41346020033](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41346020033) completed successfully on `fbd6a60869e55379d104092c4ce9cafa4a09b2cc`: all six required jobs and every returned step passed, including Flutter format/analyze/test, Chrome IndexedDB/reload, Web release build, Windows Credential Manager/process/restart checks, SQL, and disposable local GoTrue/PostgREST A/B/RLS integration. This is local-stack/component CI, not hosted learner or physical multi-device acceptance.
- Added a regression in `scripts/test_supabase_local.py`: two distinct verified Auth users may use the same `client_event_id` with different valid payloads; each owner receives/replays its own receipt, and changed replay conflicts only within that owner. The test also verifies B's stored event owner and rating. Updated `docs/SRS_RPC.md` to document the owner-scoped idempotency boundary.
- Changed paths: `scripts/test_supabase_local.py`, `docs/SRS_RPC.md`, `docs/PROJECT_STATUS.md`. No migration, RLS, frozen API, Auth provider/strategy, production config, default activation, credential, or Pro-owned #14/#38/N4 path changed.
- Cloud runtime has no Flutter/Dart SDK or Windows OS; local Flutter/native tests were not run. The new Python/GoTrue/PostgREST regression must run in exact-head GitHub Actions. No new-head test/build pass is claimed.
- Next: inspect every latest-attempt job/step on the new exact head; fix only observed failures. Keep PR #37 Draft and #20/#22/#15 open until hosted signed-JWT learner A/B, real expiry/restart, and physical multi-device reconciliation are evidenced.


## Core worker checkpoint — concurrent cross-owner event identity — 2026-11-01 UTC

- Run `core-20261101T2210Z-cross-owner-concurrency`; branch
  `automation/issue-22-atomic-review`; parent
  `82fd44940dd8aadf18752273540e44f36f55e366`; base main
  `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Added a TEST ONLY local GoTrue/PostgREST race: two distinct Auth users
  synchronize on a two-party barrier, then submit the same new
  `client_event_id` with different valid ratings and the same event instant.
  Each must commit/replay its own receipt, reject changed input within its own
  owner scope, and persist exactly one event row with its own owner/rating.
  Existing sequential cross-owner, same-owner concurrency, A/B RLS and logout
  tests remain.
- Updated the existing `local-two-session-sync` QA case with a second exact
  executable anchor, its regression test, and QA/SRS documentation. No new
  release case was promoted; no production SQL/migration/RLS/API/Auth strategy,
  default activation, secret, or Pro-owned #14/#38/N4 path changed.
- Paths: `scripts/test_supabase_local.py`, `qa/matrix.json`,
  `qa/test_verify_qa.py`, `docs/SRS_RPC.md`,
  `docs/QA_SECURITY_MATRIX.md`, and this status file.
- This checkpoint is pending exact-head CI. Cloud runtime has no Flutter/Dart
  SDK or disposable local Supabase services, so no local GoTrue/PostgREST run
  is claimed. The regression must execute in GitHub Actions before acceptance.
- Next: inspect every latest-attempt job and step on the new exact head. Keep
  PR #37 Draft and #20/#22/#15 open; hosted signed-JWT learner A/B and physical
  multi-device offline reconciliation remain unproven.


## Core worker checkpoint — expired JWT RPC guards — 2026-11-02 UTC

- Run `core-20261101T2312Z-expired-rpc-auth-guards`; branch `automation/issue-22-atomic-review`; parent `c9a8330a0b18310dbd207a3bd5ffc908d2d5c184`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Parent exact-head CI [41356318234](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41356318234) completed all six jobs and every step successfully on `c9a8330a0b18310dbd207a3bd5ffc908d2d5c184`: repo-sanity, database, ai-boundary, disposable Supabase integration, Windows and Flutter (format/analyze/full tests/Chrome IndexedDB/native recovery/Web release). This is parent evidence, not evidence for this new increment.
- Extended `scripts/test_supabase_local.py` so a validly signed but expired TEST ONLY local JWT is sent to `ensure_profile` and `submit_review`, not just a profile read. The gateway must reject both RPC calls; a subsequent valid-session query must show no review event and no learning-item side effect. `docs/OWN_PROFILE_BOOTSTRAP.md` records the exact LOCAL ONLY boundary.
- Changed paths: `scripts/test_supabase_local.py`, `docs/OWN_PROFILE_BOOTSTRAP.md`, and this status file. No migration, RLS, API contract, Auth strategy/provider, default runtime activation, secrets or Pro-owned #14/#38/N4 path changed.
- Cloud runtime has no Docker/Flutter SDK; local GoTrue/PostgREST, format/analyze/test/build were not run. Exact-head Actions must execute the new regression. This does not satisfy hosted signed-JWT learner A/B or physical multi-device offline acceptance.
- Next: inspect all latest-attempt jobs/steps on the new exact head; fix only observed failures. Keep PR #37 Draft and #20/#22/#15 open.


## Core worker handoff — apply observed Dart formatter correction — 2026-11-02 UTC

- Resumed PR #37 from released head `77ebe28d960b1292edd48a2c228c3e679543fe5e` on `automation/issue-22-atomic-review`; base main is `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. Pro-owned PR #38 / N4 branch was read-only and untouched.
- Exact-head CI [41398747443](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41398747443), run 652, latest attempt 1: repo-sanity, ai-boundary, database, supabase-integration and windows all completed SUCCESS with every step successful. Flutter failed only at `dart format --output=none --set-exit-if-changed .`; the temporary diagnostic step succeeded and showed the exact Dart 3.9.2 change was the listener closure in `persistent_supabase_runtime.dart` from multiline callback arguments to the canonical single-line `listen((state) { ... }, onError: ...)` form. Flutter analyze, tests and downstream browser/build checks were skipped after the formatter failure; they are not counted as passed.
- Applied only that formatter-emitted layout and removed the temporary read-only diagnostic step. Strict formatter, analyze, full test suite, browser/native checks, Windows build, Web build, SQL/RLS and disposable Supabase integration gates remain unchanged. No production behavior, test assertion, Auth strategy/provider, schema/RLS, secret, default activation or N4/content path changed.
- Changed paths: `apps/flutter_app/lib/features/auth/application/persistent_supabase_runtime.dart`, `.github/workflows/ci.yml`, and this status file. Cloud runtime has no Flutter/Dart SDK; no local formatter/analyzer/test/build result is claimed. New exact-head CI must execute the full suite before this correction is accepted.
- Next: inspect all latest-attempt jobs and every step on the corrected exact head. Keep PR #37 Draft and #20/#22/#15 open; hosted signed-JWT learner A/B, real restart/expiry and physical multi-device sync remain unproven.


## Core worker diagnostic checkpoint — 2026-11-02T11:07Z

- Run `core-20261102T1107Z-diagnose-vault-clear`; branch `automation/issue-22-atomic-review`; parent `64c0b03e929a83de1fd13c60aa0a9d28263fd98a`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41427173196](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41427173196), attempt 1, completed FAILURE on this head. Repo-sanity, AI boundary, database, Windows and disposable Supabase integration each passed every step. Flutter format and analyze passed; the test suite reported 393 passed and one failure in `persistent_supabase_runtime_test.dart`: expected three vault clears, observed four. All downstream Flutter lifecycle/wire/browser/Web checks were skipped after the test failure.
- The failing regression still asserts the original operation order and three-clear boundary. A diagnostic reason was added to that existing assertion to print only the fake backend's method-name sequence (`read/write/clear`); it never includes tokens or raw errors and does not change the expected count/order or runtime behavior.
- Cloud runtime has no Dart/Flutter SDK, so no local format/analyze/test/build is claimed. The next exact-head CI must expose the sequence; only then change the event/cleanup path. Keep PR #37 Draft and #20/#22/#15 open. TEST ONLY MockClient/in-memory vault evidence is not Windows Credential Manager failure injection or hosted signed-JWT learner A/B. No Auth strategy/provider, schema/RLS, default activation, Pro N4, production or release change.


## Core worker checkpoint — synchronous owned Auth notifications — 2026-11-02T12:13Z

- Run `core-20261102T1213Z-fix-stale-registry-event`; branch `automation/issue-22-atomic-review`; parent `3ede6feaf28374089a30e2722b7ac456c4ecf5b0`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Inspected exact-head CI [41434940519](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41434940519), attempt 1. Repo-sanity, AI boundary, database, Windows and disposable Supabase integration passed every step. Flutter format and analyze passed; Flutter tests failed 393 passed / 1 failed at the existing A-to-B vault assertion (expected 3 clears, actual 4). The redacted operation order was `read → write → write → clear → clear → clear → write → clear`. All later Flutter lifecycle/wire/browser/Web steps were skipped, not passed.
- Changed the private owned SDK event controller to synchronous delivery. A transient registry/Auth null notification can no longer sit in a second asynchronous queue and be replayed after a replacement session has settled. While sign-in/restore/refresh is in flight, the persistence callback is ignored and `_settle` samples the final SDK state and drains writes. The real no-session/invalid/expired path outside Auth operations remains immediate; no SDK mutation occurs inside the callback.
- Extended the same pinned-SDK regression with a post-profile flush assertion: exactly three clears, the complete expected operation sequence and B's rotated secret must still hold after readiness. Updated lifecycle documentation.
- Changed paths: `apps/flutter_app/lib/features/auth/application/persistent_supabase_runtime.dart`, `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, and this file. No Auth strategy/provider, token logging, plaintext fallback, schema/RLS, default runtime activation, production configuration or Pro-owned #14/#38/N4 path changed.
- Cloud runtime has no Flutter/Dart SDK; no local format/analyze/test/build claim. Exact-head Actions must run the regression and all downstream checks before acceptance. The Windows job's OS-backed bridge/restart probes are TEST ONLY; they are not hosted signed-JWT learner A/B.
- Next: inspect every latest-attempt job/step on the new exact head. Keep PR #37 Draft and #20/#22/#15 open until hosted learner A/B, deployed RLS, real restart/expiry and physical multi-device reconciliation are evidenced. Pro-owned #14/#38/N4 remains untouched.


## Core worker checkpoint — distinguish signed-out event identity and repair recovery fixture — 2026-11-02 UTC

- Run `core-20261102T1711Z-fix-auth-notification-cleanup-races`; branch `automation/issue-22-atomic-review`; parent `c86f076b18eab1625604428e25a08c4df192aa90`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41452989979](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41452989979), attempt 1, completed FAILURE. Repo-sanity, database, AI boundary, disposable Supabase integration and Windows passed every step. Flutter format/analyze passed; tests were 393 passed / 2 failed; every later Flutter lifecycle/wire/browser/Web step was skipped. The binding regression failed at line 329 (current-session SIGNED_OUT expected true, actual false). The A-to-B recovery test failed at line 407 (expected three clears, actual four; redacted order `read → write → write → clear → clear → clear → write → clear`).
- Root cause 1: the binding applied the null-event generation guard to session-bearing SIGNED_OUT events too. It now checks a non-null event's stable user/session identity against the current SDK session; only an identity-less null event requires the still-current explicit sign-out generation and a null current SDK session. This retains rejection of old A events after B replacement while accepting a genuine current-session sign-out.
- Root cause 2: the recovery fixture left `backend.failWrite` enabled after injecting the failed A rotation. The later explicit B recovery therefore attempted another failing vault write and correctly triggered the fourth fail-closed clear. The fixture now disables that injected write failure before B recovery; the exact three-clear count and full operation-order assertions are unchanged.
- Changed paths: `apps/flutter_app/lib/features/srs/data/supabase_review_binding.dart`, `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, and this status file. No API/schema/migration/RLS/Auth strategy/provider, default activation, token logging/plaintext fallback, Pro-owned #14/#38/N4 or production/release scope changed.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. This commit must be verified by exact-head GitHub Actions; no new-head pass is claimed.
- Next: inspect all six latest-attempt CI jobs and every step for this exact head. Keep PR #37 Draft and #20/#22/#15 open; hosted signed-JWT learner A/B, deployed RLS, hosted restart/expiry and physical multi-device proof remain outstanding.


## Core worker checkpoint — configured-host startup UI persistence barrier — 2026-11-02 UTC

- Run `core-20261102T1811Z-configured-host-startup-barrier-widget-tests`; branch `automation/issue-22-atomic-review`; parent `72c0c23a010874b2816b5d40eab2a6a886b4884e`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Added two widget-level integration regressions that mount the actual `AccountStartupApp` with `PersistentAccountStartup` and `PersistentSupabaseRuntime`, using the pinned Supabase SDK plus TEST ONLY MockClient HTTP and in-memory credential backend.
- Startup test holds the rotated refresh-token write and proves no `ensure_profile` request/account UI is published until storage succeeds; it then holds the captured own-profile response and proves study readiness remains blocked until that response completes.
- Recovery test rejects a stored refresh token, proves the UI exposes only explicit re-login, then verifies cleanup/credential clear occurs before password Auth. A held new-token write blocks profile dispatch/readiness until persistence succeeds. Assertions record method names and request grant types only; no secret values are logged.
- Changed paths: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `docs/ACCOUNT_STARTUP.md`, and `docs/PROJECT_STATUS.md`. No production source, default preview/runtime, Auth strategy/provider, schema/RLS, migration, CI, secret, or Pro-owned #14/#38/N4 path changed.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. Exact-head GitHub Actions must verify the two new widget tests and every required job/step. No new-head pass is claimed.
- Next: inspect all latest-attempt jobs/steps for the new exact head; fix only observed diagnostics. Keep PR #37 Draft and #20/#22/#15 open. Hosted signed-JWT learner A/B, deployed RLS, real expiry/restart and physical multi-device sync remain unproven.


## Core worker checkpoint — exact Dart formatter diagnosis — 2026-11-02 UTC

- Run `core-20261102T1826Z-dart-format-diagnostic`; parent `ba2c8d4ea86fe90ad9e5b96b6275091ed6a92dbf`; branch `automation/issue-22-atomic-review`.
- Exact-head CI [41499960522](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41499960522), attempt 1, observed Flutter strict format failure only: Dart 3.9.2 reported `test/features/srs/persistent_supabase_runtime_test.dart` changed. Flutter analyze/test and every downstream Flutter step were skipped, not passed. Repo-sanity/database/AI boundary had succeeded; Supabase integration and Windows were still running at the observation.
- Added a temporary read-only CI diagnostic that prints the exact unified diff from pinned Dart 3.9.2 `dart format --output=show`; the strict formatter gate remains immediately afterward and is unchanged. This diagnostic commit does not alter tests, assertions, runtime, security or build gates.
- Changed paths for this diagnostic checkpoint: `.github/workflows/ci.yml` and `docs/PROJECT_STATUS.md`. Cloud runtime has no Dart/Flutter SDK; no local format/analyze/test/build result is claimed.
- Next: read the diagnostic diff from exact-head Actions, apply only that formatting change to the test file, remove the temporary workflow step, and rerun full CI.


## Core worker checkpoint — exact formatter correction — 2026-11-02 UTC

- Run `core-20261102T1907Z-fix-formatter`; branch `automation/issue-22-atomic-review`; parent `11305d574e8532b0c187c09f50988d383a579c5c`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Inspected exact-head CI [41500674650](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41500674650), latest attempt 1. Repo-sanity, database, AI boundary, disposable Supabase integration and Windows completed SUCCESS with every returned step. Flutter failed only strict Dart 3.9.2 formatting; its read-only diagnostic identified two exact hunks in `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`: compact the grant-type `expect` invocation while retaining the two-element expected list, and remove the extra blank line before the closing brace. Flutter analyze, tests and downstream Flutter checks were SKIPPED, not passed.
- Applied only those two formatter hunks and removed the temporary read-only diagnostic from `.github/workflows/ci.yml`; strict `dart format --output=none --set-exit-if-changed .` remains unchanged. No assertions, runtime behavior, API/schema/RLS, Auth strategy/provider, default activation, or Pro-owned #14/#38/N4 content changed.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. New exact-head CI must verify format, analyze, all Flutter tests, lifecycle/wire/browser/Web build and all other required jobs/steps before any pass claim.
- Next: inspect every latest-attempt job and step for the new exact head. Keep PR #37 Draft and #20/#22/#15 open. Hosted signed-JWT learner A/B, deployed RLS, hosted expiry/restart and physical multi-device sync remain unproven; no merge/deployment/release.


## Flutter CI timeout diagnostic — 2026-11-02T21:14Z

- Core worker run: `core-20261102T2114Z-flutter-test-serial-diagnostic`; branch `automation/issue-22-atomic-review`; source head before this checkpoint `69b015b58c80ca56bacf51fed9c00250dd8abbb5`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41507564573](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41507564573), latest attempt 2, targets `69b015b58c80ca56bacf51fed9c00250dd8abbb5`. Repo-sanity, AI boundary, database, disposable Supabase integration and Windows completed SUCCESS with every returned step. Flutter dependency setup, strict format and analyze succeeded. The test log emitted 395 individual `✅` case lines, then the process remained alive without a suite summary/exit until the 30-minute Flutter job timeout at 2026-11-02T20:43:24Z. Downstream Flutter lifecycle/wire/browser/Web steps were SKIPPED, not passed. No full Flutter-suite or full-CI pass is claimed.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. The current CI job has a 30-minute timeout; this change does not increase it.
- Changed paths for this diagnostic checkpoint: `.github/workflows/ci.yml` and `docs/PROJECT_STATUS.md`. The complete existing Flutter test suite and every assertion remain required; only scheduling is serial (`--concurrency=1`) and output is expanded so the last active test/resource can be identified. No test, assertion, security gate, downstream verification or build step is removed.
- Next: inspect the exact-head serial run and identify the final active test/resource if the process still does not exit. Fix only the observed cleanup/ownership defect; retain all tests and all six CI jobs. Keep PR #37 Draft and #20/#22/#15 open.


## Core worker handoff — bounded widget readiness wait — 2026-11-02 UTC

- Run: `core-20261102T2309Z-fix-widget-readiness-fake-async-timeout`; branch `automation/issue-22-atomic-review`; parent/source head `1d2edc06d7fa5a0265b84b0f540e562d03ad7e9b`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41535492396](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41535492396), latest attempt 1, targeted `1d2edc06d7fa5a0265b84b0f540e562d03ad7e9b`. Repo-sanity, database, AI boundary, Windows and disposable Supabase integration completed SUCCESS with every step. Flutter format and analyze completed SUCCESS. Flutter test log showed 64 passing tests, then `configured host waits for rotated vault secret and own profile before publishing account UI` timed out after 10 minutes. The remaining Flutter lifecycle/wire/Chrome/Web steps were skipped after cancellation; no full Flutter/full-CI pass is claimed.
- Root cause in the test helper: `pumpReadyAccountUi` awaited `waitForReady()`, whose five-second `Future.timeout` was created inside WidgetTest's fake-async zone. Awaiting it without pumping frames did not advance that fake clock, so the bounded guard never fired and the suite waited until Flutter's ten-minute per-test timeout.
- Fix: replace only the widget helper with at most 50 explicit 100 ms `tester.pump` frames, stopping on ready or a terminal account error and asserting both `AccountPhase.ready` and a non-null ready runtime. This advances the WidgetTest clock deterministically, never waits for an indeterminate progress animation, and bounds a missing profile to five seconds of test time. The ordinary non-widget `waitForReady` helper and all production Auth/session code remain unchanged; every existing readiness, vault-rotation and profile assertion remains.
- Changed paths: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `docs/PROJECT_STATUS.md`. No production Dart, API, schema, migration, RLS, Auth strategy/provider, default activation, content/N4 or dependency changes.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. New exact-head CI must verify strict format, analyze, full tests, downstream Flutter checks, Windows and Web. No result is claimed until all latest-attempt jobs/steps finish successfully without skips.
- Next: inspect every latest-attempt job/step on the new exact head. If the readiness test passes, continue the remaining #20/#22/#15 integration acceptance; keep PR #37 Draft and those issues open until hosted signed-JWT learner A/B, deployed RLS, hosted restart/expiry and multi-device evidence are observed. Pro-owned #14/#38/N4 untouched.


## WidgetTest fake-async fixture flush — 2026-11-03T00:14Z

- Core run: `core-20261103T0014Z-fix-widget-fixture-flush-fake-async`; branch `automation/issue-22-atomic-review`; parent/source `aa14ab829166bad8119cd202fdf94c3c6194d95e`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41543591874](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41543591874), latest attempt 1, completed with repo-sanity, AI boundary, database, disposable Supabase integration and Windows SUCCESS/all steps; Flutter format/analyze SUCCESS. The serial full Flutter suite timed out after 10 minutes at the configured-host readiness widget test; all later Flutter lifecycle/wire/browser/Web steps were skipped. No full-CI pass is claimed.
- Corrected root cause from the log and source: the widget test awaited `fixture.flush()` before reaching `pumpReadyAccountUi`. That helper performs eight `Future.delayed(Duration.zero)` timers; inside WidgetTest fake-async, the fake clock was not advanced, so the await itself never completed. The prior bounded pump helper was downstream of this blocked await and therefore could not fix it.
- Change: add a widget-only `flushWidgetFixture(tester)` using `tester.runAsync(fixture.flush)` followed by one bounded `tester.pump()`; replace exactly six fixture flush calls across the two configured-host widget tests. Production Auth/session code, fixture behavior, test expectations, vault/profile barriers and all existing assertions are unchanged.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. New exact-head CI must prove the widget tests finish and all downstream Flutter checks run. No hosted signed-JWT learner A/B, deployed RLS, hosted restart/expiry or physical multi-device proof is claimed.
- Next: inspect every latest-attempt job/step for the new exact head. If the widget test completes, continue #20/#22/#15 acceptance; keep PR #37 Draft and those issues open until hosted evidence is supplied. Pro-owned #14/#38/N4 untouched.


## WidgetTest fixture event-turn correction — 2026-11-03T01:09Z

- Core run: `core-20261103T0109Z-pump-widget-fixture-fake-async`; branch `automation/issue-22-atomic-review`; parent `8b538aeb4bc4804b28f22226f0212a8b685869f8`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41551775292](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41551775292), attempt 1: repo-sanity, database, AI boundary, disposable Supabase integration and Windows all SUCCESS with every step. Flutter format/analyze SUCCESS; the full serial test step FAILED. The first configured-host widget test expected the rotated vault secret but still observed the prior secret after `tester.runAsync(fixture.flush)`; it then timed out after 10 minutes. The following widget test could not construct a second same-target runtime (`SessionVaultFailure(unavailable)`), consistent with the first test's unresolved owner/cleanup; this is a cascading hypothesis to verify on rerun, not a production defect claim. Later Flutter lifecycle/wire/Chrome/Web steps were skipped.
- Correction: replace the real-zone `runAsync` wrapper with eight bounded 1 ms `tester.pump` turns. This advances the fixture's eight `Future.delayed(Duration.zero)` continuations inside WidgetTest FakeAsync, allowing the SDK/Auth/vault futures themselves to progress in the same fake clock. The six call sites and all persistence/profile barriers and assertions are retained.
- Changed paths: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `docs/PROJECT_STATUS.md`. Production Auth/session code, CI timeout, security gates, API/schema/migration/RLS, default activation and N4/content remain unchanged.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. New exact-head CI must verify the widget tests settle, the second runtime owner is released, all downstream Flutter lifecycle/wire/Chrome checks run, and Web/Windows builds complete. No hosted signed-JWT learner A/B, deployed RLS, hosted restart/expiry or physical multi-device evidence is claimed.
- Next: inspect every latest-attempt job/step on the new exact head; only accept full CI when no required step is skipped. Keep PR #37 Draft and #20/#22/#15 open pending their full acceptance. Pro-owned #14/#38/N4 untouched.

## Core worker checkpoint — 2026-11-03T04:10Z — owned SDK session reconciliation

- Run: `core-20261103T0410Z-sync-owned-sdk-session-before-persistence`; branch `automation/issue-22-atomic-review`; implementation commit `b745251ee45b2bb45a917380fdf30461579eaa05` (parent `2d4bc42f885b0aa7fa921cfd6c05f00cfc4d5763`); base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-parent CI [41558075780](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41558075780), latest attempt 1, targeted the parent SHA. Repo-sanity, database, AI boundary, disposable Supabase integration and Windows completed SUCCESS with all returned steps. Flutter format/analyze completed SUCCESS; the full serial Flutter suite failed at `persistent_supabase_runtime_test.dart:1221`: expected `TEST_ONLY_ROTATED_SDK_1`, observed `TEST_ONLY_SAVED_SDK`. The suite later hit its 10-minute timeout; all downstream Flutter lifecycle/wire/Chrome/Web steps were SKIPPED, not passed. No full-CI pass is claimed.
- Fix: after a successful caller-owned SDK sign-in/restore/refresh, `_OwnedSdkAccess` now calls `SupabaseReviewBinding.synchronizeOwnedAuthSession()`. The binding revalidates and synchronously accepts the SDK's final current session before `PersistentAccountAccess` drains the exact rotated refresh-token write. The asynchronous Auth stream remains for out-of-band events and retains lifecycle/generation guards.
- Regression: the configured-host widget test now waits for the observed vault write to enter its held barrier, asserts no profile dispatch while it is held, releases it, and waits for the exact rotated secret plus the single own-profile dispatch. It then separately waits for profile readiness. A test teardown releases any held vault write, unmounts the widget and closes its startup owner even after an assertion failure, preventing a leaked runtime from cascading into the next test.
- Changed implementation/test/docs paths: `apps/flutter_app/lib/features/auth/application/persistent_supabase_runtime.dart`, `apps/flutter_app/lib/features/srs/data/supabase_review_binding.dart`, `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`; this checkpoint also updates `docs/PROJECT_STATUS.md`.
- Separate post-write diff review: exactly four intended blobs changed in the implementation commit; full recursive base/result trees both untruncated at 327 entries (262 blobs / 65 trees), no paths added/removed or mode/type changes, 258 existing blobs unchanged. `create_tree` used base tree `9f864dd377a680c7e3f05e06e93578bafef652c9`; branch update used expected head `2d4bc42f885b0aa7fa921cfd6c05f00cfc4d5763`, `force=false`; GitHub branch readback matched the implementation commit.
- Local Flutter/Dart SDK is unavailable in this cloud runtime; no local format/analyze/test/build is claimed. The new exact-head GitHub Actions run is the verification gate and has not yet been observed here.
- No production configuration, Auth strategy/provider, schema/migration/RLS, default app activation, secrets, deployment or Pro-owned #14/#38/N4 scope changed. Windows vault CI and local Supabase integration are fixtures/probes, not hosted learner A/B, deployed-RLS or multi-device proof.
- Next: inspect every latest-attempt job and step for the final status-doc head; fix only exact-head diagnostics. Keep PR #37 Draft and #20/#22/#15 open until complete acceptance and hosted learner evidence are observed.


## Core worker checkpoint — exact Dart formatter correction — 2026-11-03T05:09Z

- Run: `core-20261103T0509Z-fix-dart-format-after-exact-head-ci`; branch `automation/issue-22-atomic-review`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41577252287](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41577252287), latest attempt 1, targeted `ceb00b4bbce5b816dac2dbe5f1ea165ea71091c9`. `repo-sanity`, `database`, `ai-boundary`, `windows`, and disposable `supabase-integration` all completed SUCCESS with every returned step. Flutter dependency setup succeeded, but strict Dart 3.9.2 format failed: `dart format` reported only `test/features/srs/persistent_supabase_runtime_test.dart` changed. Flutter analyze, tests and all downstream Flutter steps were SKIPPED, not passed.
- Read-only source inspection isolated the sole formatter hunk: one extra blank line before the first configured-host widget test's closing delimiter (line 1277 on the failed head). Removed only that blank line; no test, assertion, production code, workflow gate, API/schema/RLS, Auth strategy/provider or default activation changed.
- Source commit: `7cb73d485b84ff93b6c145aaf5355be347fec0e7` (parent `ceb00b4bbce5b816dac2dbe5f1ea165ea71091c9)); changed path: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart` (one deletion, zero additions). `create_tree` used exact parent tree `28ae55b0516dab27f3e3c84a642461abb4ae6ef7`; full recursive tree before and after was untruncated at 327 entries (262 blobs / 65 trees). Separate compare confirmed exactly the one intended file/hunk; branch update used `expected_sha=ceb00b4bbce5b816dac2dbe5f1ea165ea71091c9`, `force=false`, and readback matched.
- Cloud runtime has no Dart/Flutter SDK; no local format/analyze/test/build is claimed. New exact-head CI on the final status commit is the verification gate; no new-head result is claimed yet.
- No hosted learner A/B, deployed RLS, hosted expiry/restart or physical multi-device proof is claimed. PR #37 remains Draft; #20/#22/#15 remain open. Pro-owned PR #38 / Issue #14 / N4 files were not touched.
- Next: inspect all latest-attempt jobs and every step for the final status commit; only continue after the strict formatter result is observed. If formatting passes, verify analyze/full serial Flutter suite and all downstream lifecycle/wire/Chrome/Web/Windows/Supabase checks without skips. Keep the PR draft and human/configuration gates intact.

## Core worker checkpoint — 2026-11-03T10:26Z

- Run `core-20261103T1013Z-fix-configured-host-widget-barrier-cleanup`; branch `automation/issue-22-atomic-review`; source commit `03b5dcf09f36191e859dbf28eb87448263e4498d` (parent `15fc4f02f047e32f6950555d3c31bf093b41cdd9`); base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-parent CI [41609516287](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41609516287), attempt 1, completed FAILURE on the Flutter serial suite: 395 tests passed, then the configured-host restore/profile widget timed out after 10 minutes; the next widget setup saw `SessionVaultFailure(unavailable)`. Flutter format/analyze passed. Repo-sanity, database/RLS, AI boundary, Windows and disposable local Supabase integration all passed every step. All Flutter downstream lifecycle/wire/Chrome/Web steps were SKIPPED after the suite failure, not passed.
- The test failure path could leave its held `profileWait` unresolved while teardown awaited the startup owner; this can retain the exclusive vault owner and cascade into the next test. The previous CI log does not establish a production Auth or token-rotation defect. This checkpoint changes TEST ONLY synchronization/cleanup, not production Auth/session code.
- Changed paths: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `apps/flutter_app/test/features/srs/session_lifecycle_fixtures.dart`. Replaced the polling loop that scheduled `Future.delayed` timers from WidgetTest with explicit write-start/profile-request/profile-response Completer signals and five-second root-zone waits. Widget taps remain in the WidgetTester zone. Teardown now releases held read/Auth/write/profile barriers, awaits controller close with a bounded five-second guard, then unmounts. The exact rotated-secret-before-profile, no-readiness-before-profile, explicit-login, clear-before-password-auth and successful rotation assertions remain; the second widget case now explicitly asserts the rotated secret is saved.
- Separate source diff review: exactly two test/fixture paths; recursive trees before/after are complete and untruncated at 327 entries (262 blobs / 65 trees), no path or mode/type changes, 325 entries preserved. `create_tree` used exact base tree `111211187e2d3c3fc417d41b8c5040655db9b6e6`; `update_ref` used `expected_sha=15fc4f02f047e32f6950555d3c31bf093b41cdd9`, `force=false`. Branch/PR readback is `03b5dcf09f36191e859dbf28eb87448263e4498d`.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. New exact-head CI must validate this test harness and every downstream Flutter/Chrome/Web, Windows and local Supabase job. No hosted signed-JWT learner A/B, deployed RLS, hosted restart/expiry or physical multi-device proof is claimed.
- Keep PR #37 Draft and #20/#22/#15 open. Pro-owned #14/#38/N4 paths remain untouched. Next: inspect all latest-attempt jobs and steps on the final docs checkpoint head; fix only observed failures.


## Exact-head Flutter formatter diagnostic — 2026-11-03T11:13Z

- Run `core-20261103T1113Z-dart-format-diagnostic`; branch `automation/issue-22-atomic-review`; parent `04ebeed7388843cfc4446be4f63aa4bd3c00077a`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41619166528](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41619166528), attempt 1, targeted `04ebeed7388843cfc4446be4f63aa4bd3c00077a`: repo-sanity, database, AI boundary, disposable local Supabase integration and Windows all completed SUCCESS with every step. Flutter dependency setup succeeded; strict Dart 3.35.4 format failed because only `test/features/srs/persistent_supabase_runtime_test.dart` was reported changed. Analyze, full tests and all downstream Flutter checks were SKIPPED, not passed.
- This diagnostic increment adds a temporary read-only CI step that prints the pinned formatter's unified diff for that single test file before the unchanged strict format gate. The step is `continue-on-error`; it does not alter the gate or source/test behavior. Next: apply only the emitted formatter output, remove the diagnostic, then run complete exact-head CI.
- Cloud runtime has no Dart/Flutter SDK; no local format/analyze/test/build is claimed. No hosted learner A/B, deployed RLS, hosted restart/expiry or physical multi-device proof. PR #37 remains Draft; #20/#22/#15 remain open. Pro-owned #14/#38/N4 scope untouched.


## Exact Dart formatter correction — 2026-11-03T11:16Z

- Core run `core-20261103T1113Z-dart-format-diagnostic`; branch `automation/issue-22-atomic-review`; diagnostic commit `be3f4303a299cae2b37986dc6d2198a4c14eb3c7`; parent `04ebeed7388843cfc4446be4f63aa4bd3c00077a`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Diagnostic exact-head CI [41625858602](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41625858602), attempt 1, printed the pinned Dart 3.35.4 unified diff for only `persistent_supabase_runtime_test.dart`: compact two `Zone.root.run` calls, reindent the `profileWait` fallback expression, and add the final newline. Repo-sanity, database and AI-boundary completed SUCCESS/all steps. Flutter diagnostic completed SUCCESS; strict format then failed as expected. Flutter analyze/tests/downstream steps were SKIPPED. Windows and disposable Supabase integration were still in progress when the formatter output was applied; no full-CI pass is claimed.
- Applied exactly the three formatter hunks plus final newline and removed the temporary diagnostic step. No test assertions/semantics, production Auth/session, API/schema/RLS, dependencies, default activation or Pro-owned N4 content changed. Next: inspect the final exact-head CI on this correction commit.
- Cloud runtime has no Dart/Flutter SDK; local format/analyze/test/build are not claimed. No hosted learner A/B, deployed RLS, hosted restart/expiry or physical multi-device proof. PR #37 remains Draft; #20/#22/#15 remain open; Pro-owned #14/#38/N4 scope untouched.


## Final formatter-fix exact-head handoff — 2026-11-03T11:18Z

- Final source commit: `4ebc5d09df17c0dc047099495d2effd9697055a2` (parent `be3f4303a299cae2b37986dc6d2198a4c14eb3c7`); branch `automation/issue-22-atomic-review`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Changed paths in source increment: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart` (exact pinned Dart 3.35.4 formatting only), `.github/workflows/ci.yml` (temporary formatter diagnostic removed), and this status file. Source diff review found exactly three paths; the test change is limited to two compact `Zone.root.run` calls, formatter indentation of the profile fallback, and final newline. No assertion or behavior changes.
- Diagnostic CI `41625858602`, attempt 1, exact head `be3f4303a299cae2b37986dc6d2198a4c14eb3c7`: diagnostic SUCCESS; strict format failed as expected; analyze/full tests/downstream Flutter checks SKIPPED. Repo-sanity/database/AI-boundary passed all steps. Windows and disposable Supabase integration were still running when the fix was committed.
- Final source-head CI `41626242970`, attempt 1, targets `4ebc5d09df17c0dc047099495d2effd9697055a2`; observed PENDING with no jobs published yet. No final-head format/analyze/test/build/full-CI pass is claimed. Next: inspect all latest-attempt jobs/steps for the final docs checkpoint head, require all six jobs and no skipped required Flutter steps.
- Cloud runtime has no Dart/Flutter SDK; local checks were not run. No hosted learner A/B, deployed RLS, hosted restart/expiry or physical multi-device evidence. PR #37 remains Draft; #20/#22/#15 remain open; Pro-owned #14/#38/N4 scope untouched.


## WidgetTest real-signal timeout correction — 2026-11-03T12:07Z

- Exact-head CI [41626344170](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41626344170), attempt 1, targets `689a37f290978bd542a8a96602717f0d6a21dd1c`. Repo-sanity, database/RLS, AI boundary, Windows release/native probes and disposable local Supabase integration completed SUCCESS with every returned step. Flutter format and analyze passed; the serial suite failed in the configured-host restore widget at `waitForRealSignal` (five-second timeout). The following configured-host login widget did not complete; all downstream Flutter lifecycle/wire/Chrome/Web steps were SKIPPED, not passed.
- The timeout helper created a `Future.timeout` timer inside `Zone.root` while called from `WidgetTester.runAsync`; CI reported the timeout as an unhandled tester-shell exception instead of returning the helper's bounded diagnostic. The first widget also started `controller.start()` in a `runAsync` callback that returned before waiting for the vault barrier, separating startup from the real event-loop wait.
- Test-only correction: introduce `runRealUntil`, which starts/waits for the operation within one `tester.runAsync` callback and uses `Future.any` with a five-second non-throwing deadline. Apply it to the vault write-start, startup completion, own-profile response, account-ready and owner-close barriers. Keep the login tap in WidgetTester. Preserve all token-rotation-before-profile, no-readiness-before-profile, clear-before-password-auth and profile/UI assertions. No production Auth/session, vault, API, schema/RLS, dependencies, default activation or Pro-owned N4 files change.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build are not claimed. New exact-head CI must prove formatter, analyze, full Flutter suite and downstream lifecycle/wire/Chrome/Web checks, plus Windows and disposable Supabase jobs. No hosted signed-JWT learner A/B, deployed RLS, hosted restart/expiry or physical multi-device proof is claimed.
- Keep PR #37 Draft and #20/#22/#15 open. Pro-owned #14/#38/N4 scope remains untouched. Next: inspect every latest-attempt job and step on the new exact head; fix only observed failures.


## Configured-host WidgetTest real-zone polling correction — 2026-11-03T13:10Z

- Run: `core-20261103T1310Z-investigate-configured-host-widget-lifecycle`; branch `automation/issue-22-atomic-review`; parent `78336357e029f4ce76ef13ad3d5d96bff72901c0`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41633901930](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41633901930), attempt 1, completed FAILURE. Repo-sanity, database/RLS, AI boundary, Windows release/native vault/journal and disposable local Supabase integration all completed SUCCESS with every returned step. Flutter format and analyze passed. The serial suite recorded 395 passed / 2 failed: the first configured-host restore test timed out waiting for a `writeStarted` Completer even though synchronous diagnostics showed `writes=1`, persistence `saving`, and zero profile requests; teardown then failed to drain within five seconds. The following configured-host login test could not acquire the exclusive runtime owner (`SessionVaultFailure(unavailable)`) and timed out. All later Flutter lifecycle/wire/Chrome/Web steps were SKIPPED, not passed.
- Root cause is isolated to cross-zone test synchronization: the widget tests awaited Completers created in WidgetTest FakeAsync from `tester.runAsync`; their completion callbacks remain queued while that fake zone is paused. The first failure occurred after the write barrier had already been reached, so this log does not establish a production token-rotation/Auth defect.
- Test-only fix: replace awaited signal Completers with bounded 10 ms real-zone polling of synchronous observable state (`writes` + `SessionPersistencePhase`, profile request/response flags, account phase). Start and release held operations in `tester.runAsync`; close completion is observed with a real-zone completion flag. Remove the unused `MemoryVault.writeStarted` fixture signal. Preserve every existing token-before-profile, no-readiness-before-profile, clear-before-password-auth, rotated-secret, UI and account-readiness assertion. Production Auth/runtime, vault implementation, API, schema/RLS, dependencies, default activation and Pro-owned N4 scope remain unchanged.
- Changed paths: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `apps/flutter_app/test/features/srs/session_lifecycle_fixtures.dart`, `docs/PROJECT_STATUS.md`. Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. New exact-head CI must execute the full Flutter suite and every downstream lifecycle/wire/Chrome/Web check plus Windows and disposable Supabase jobs; no hosted signed-JWT learner A/B, deployed RLS, hosted restart/expiry or physical multi-device proof is claimed.
- Next: inspect every latest-attempt job and step for the new exact PR HEAD. Keep PR #37 Draft and #20/#22/#15 open; Pro-owned #14/#38/N4 files remain untouched. Worker will be marked RELEASED after source/diff/tree and CI handoff are persisted.

## Configured-host WidgetTest close-barrier correction — 2026-11-03T14:18Z

- Run `core-20261103T1409Z-fix-configured-host-close-barrier`; branch
  `automation/issue-22-atomic-review`; source commit
  `189249b9127f6de908cd386462a0ef84fdb42809` (parent
  `0a76c0803083bab98898ea58c526b930a01efbe4`); base main
  `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Parent exact-head CI [41643013488](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41643013488),
  attempt 1, failed only in the Flutter test job after format/analyze passed:
  395 tests passed and two configured-host widget tests failed. The first
  reported `startup owner did not close within five seconds`; the next could
  not acquire the still-owned project target (`SessionVaultFailure(unavailable)`).
  Repo-sanity, AI boundary, database/RLS, disposable local Supabase integration
  and Windows release/native vault/journal jobs passed every step. All downstream
  Flutter lifecycle, wire, Chrome and Web build steps were skipped; this was not
  a full-CI pass.
- The failing teardown waited for controller close inside `tester.runAsync`
  while the mounted `AccountStartupApp` listener belonged to WidgetTest
  FakeAsync. The close stream's final delivery was not pumped, so the test left
  the owner undrained; this is a test-zone scheduling failure, not evidence of
  a production refresh-token or Auth failure.
- TEST ONLY correction in
  `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`:
  release held fake barriers, pump their queued callbacks, initiate owner close
  in the widget-test zone, then pump that zone in bounded 10 ms increments
  while observing close completion. Failure diagnostics expose only controller/
  persistence/account phases and operation counts, never tokens or raw errors.
  All token-rotation-before-profile, profile-readiness, explicit-login,
  clear-before-password-auth and UI assertions remain unchanged.
- Source diff separately reviewed: exactly one leaf file changed in commit
  `189249b9127f6de908cd386462a0ef84fdb42809`; the complete recursive tree had
  327 entries, was not truncated, and had no path additions/removals or
  mode/type changes. No production Auth/session, vault, API/schema/RLS,
  dependencies, default activation, Windows code or Pro-owned N4 scope changed.
- Cloud runtime has no Dart/Flutter SDK; local format/analyze/test/build are not
  claimed. Next: observe the latest-attempt CI on the final docs head, including
  the full Flutter suite and every downstream lifecycle/wire/Chrome/Web step,
  plus all non-Flutter jobs. No hosted learner A/B, deployed RLS, hosted
  restart/expiry or physical multi-device evidence is claimed. PR #37 stays
  Draft; #20/#22/#15 remain open; Pro-owned #14/#38/N4 remains untouched.

## Exact-head CI handoff — 2026-11-03T14:18Z

- Branch `automation/issue-22-atomic-review`; candidate HEAD before this
  documentation-only handoff: `3f5bf0b4c31c1a1b706db786aa0124ac6e815491`.
  Source fix: `189249b9127f6de908cd386462a0ef84fdb42809`; status checkpoint:
  `3f5bf0b4c31c1a1b706db786aa0124ac6e815491`; base main remains
  `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact candidate-head CI [41652266626](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41652266626),
  attempt 1, targets `3f5bf0b4c31c1a1b706db786aa0124ac6e815491`. At
  2026-11-03T14:18Z the workflow was PENDING and its latest-attempt jobs list
  was empty. No format/analyze/test/build or full-CI result is claimed for this
  candidate head.
- This checkpoint changes documentation only. Its push will create another
  exact-head CI run; the next worker must inspect the latest attempt for the
  resulting PR head, including all six jobs and every required Flutter step,
  before making any further source change. Do not treat run 41652266626 as
  evidence for a later docs commit.
- Core worker RELEASED after persisting the source/test fix, exact parent-CI
  diagnosis, complete-tree/diff review and pending-CI handoff. PR #37 stays
  Draft; #20/#22/#15 stay open. Pro-owned PR #38 / Issue #14 / N4 scope remains
  separate and untouched. No hosted learner A/B, deployed RLS, hosted
  restart/expiry or physical multi-device proof is claimed.


## Configured-host WidgetTest cross-zone polling correction — 2026-11-03T15:13Z

- Run `core-20261103T1513Z-pump-widget-fakeasync-lifecycle`; branch `automation/issue-22-atomic-review`; parent HEAD `e0887436c8a5b9838c0dfab0d365a7ee536feed0`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41652507045](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41652507045), attempt 1, targets `e0887436c8a5b9838c0dfab0d365a7ee536feed0`. Repo-sanity, AI boundary, database/RLS, Windows native vault/journal/release and disposable Supabase integration passed every step. Flutter format/analyze passed; full serial suite failed after 395 passes: the configured-host restore WidgetTest timed out after ten minutes, and the following explicit-login WidgetTest did not reach its credential write barrier (`writes=0`, persistence `failed`, no profile request). All downstream Flutter lifecycle/wire/Chrome/Web steps were skipped; this is not a full-CI pass.
- The preceding helper polled only inside `tester.runAsync`, while test-owned Completers and widget listeners require FakeAsync pumping. A callback queued in the paused test zone could therefore remain undelivered; the first test timed out and its owner was not released before the next test. This is test scheduling evidence, not a demonstrated production Auth/vault defect.
- Test-only correction: replace real-zone-only polling with a bounded loop that pumps 10 ms WidgetTest frames and yields 10 ms to real asynchronous I/O. Keep startup construction in the real zone, complete FakeAsync-owned barriers in their creating zone, and pump before closing the owner. Preserve every Auth, rotated-token-before-profile, no-readiness-before-profile, explicit-login, logout/clear-order, and UI assertion. No production Auth/session/vault, schema/RLS, dependencies, default activation, Windows or Pro-owned N4 paths change.
- Changed path: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`. This documentation checkpoint is paired with the source change; exact-head CI for the resulting commit is pending. Cloud runtime has no Flutter/Dart SDK, so local format/analyze/test/build are not claimed.
- Next: inspect every latest-attempt job and step for the new exact head. Fix only observed failures. Keep PR #37 Draft and #20/#22/#15 open; Pro-owned #14/#38/N4 remains untouched. No hosted signed-JWT learner A/B, deployed RLS, hosted restart/expiry or physical multi-device proof is claimed.


## Latest handoff — configured Supabase startup WidgetTests — 2026-11-03 16:21 UTC

- Core run `core-20261103T1613Z-fix-widget-profile-readiness-test` is RELEASED on branch `automation/issue-22-atomic-review`. Source head `3fd38c07014b6928082c8f2b45a93b768cad8f8c`, parent `7a9e97e1cce567ea69b2f5bd41a3f498c276d188`, base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Changed only `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`. The configured-host startup test no longer waits for the startup controller to become ACTIVE before releasing the own-profile response that ACTIVE itself awaits. It asserts the account remains unpublished while profile provisioning is pending, then releases the response and checks readiness. Both configured-host WidgetTests close their owned startup controller/runtime in `finally`, cancelling the one-hour ReviewConnectionRegistry expiry timer before WidgetTest FakeAsync checks pending timers.
- Separate diff review: the three source commits `588102a576e58c211d4dfc8cc67bfdeab255152d`, `7a9e97e1cce567ea69b2f5bd41a3f498c276d188`, and `3fd38c07014b6928082c8f2b45a93b768cad8f8c` change only this test path. Final diff from prior released head `efef5a2170d0f81f1970508123b5944271bee6a4` is one modified file; complete recursive tree is 327 entries / 262 blobs / 65 trees, untruncated, with the original path/mode/type set retained. The first tree used base tree `dabd725a5d1d429945ca5ccd0e998e6e9e981f8d`; each ref update used the exact previous HEAD as `expected_sha`, `force=false`.
- Parent exact-head CI [41662458008](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41662458008) failed only in the full Flutter test job after format/analyze passed: the profile-readiness WidgetTest timed out due to the circular wait; the following WidgetTest failed the pending one-hour FakeAsync timer invariant. Repo sanity, AI boundary, database/RLS, Windows and disposable local Supabase integration passed all steps on that parent only.
- New exact-head CI [41673241359](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41673241359), attempt 1, targets `3fd38c07014b6928082c8f2b45a93b768cad8f8c`. At 2026-11-03T16:21Z the run was queued/in progress; only repo-sanity (queued), ai-boundary (in progress) and database (in progress) had been published. Flutter, Windows and Supabase integration jobs/results were not yet observed. No new format/analyze/test/build or full-CI pass is claimed.
- Cloud runtime has no Dart/Flutter SDK, so local format/analyze/test/build were not run. No hosted signed-JWT learner A/B, deployed RLS, hosted restart/expiry or physical multi-device evidence is claimed. Production Auth/vault code, Auth strategy/provider, database/RLS, default runtime, N4 content, #14 and PR #38 are unchanged.
- Next: inspect every latest-attempt job and required step for the exact final head after the documentation checkpoint; fix only any observed failure. Keep PR #37 Draft and #20/#22/#15 open until their complete acceptance and real non-production learner evidence are satisfied.



## Exact-head Dart formatting correction — 2026-11-03T17:08Z

- Run `core-20261103T1708Z-fix-dart-format-widget-test`; branch `automation/issue-22-atomic-review`; parent HEAD `32f512e530a37bdf27c0c7c4d8fd7bd64ff84e49`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41673492149](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41673492149), attempt 1, targets `32f512e530a37bdf27c0c7c4d8fd7bd64ff84e49`. Five non-Flutter jobs (ai-boundary, database, repo-sanity, Windows and disposable Supabase integration) completed SUCCESS with every step. Flutter failed only at `dart format --output=none --set-exit-if-changed .`: Dart 3.35.4 reported `persistent_supabase_runtime_test.dart` as the single file needing formatting (115 files checked, 1 changed). Flutter analyze, full test suite and every downstream Flutter check were SKIPPED; this is not a full-CI pass.
- TEST ONLY whitespace correction: normalize the indentation inside the safe-logging/scope WidgetTest's `try` body. No assertion, test behavior, production Auth/session/vault code, API, SQL/RLS, dependency, default activation or Pro-owned content changes.
- Before writing, re-read the exact branch head and complete recursive tree: 327 entries (262 blobs, 65 trees), untruncated. Only the test and this status document are intended leaf updates; all other paths/modes/types remain inherited from exact base tree `6cb0f988e5a369d44c947b101e1df7fab038fb54`.
- Cloud runtime has no Dart/Flutter SDK; local format/analyze/test/build are not claimed. Next: inspect all six latest-attempt CI jobs and every step for the resulting exact commit; require Flutter format/analyze/full suite and downstream lifecycle/wire/Chrome/Web checks, Windows, database, repo-sanity, AI boundary and disposable Supabase integration to complete without skips. Keep PR #37 Draft and #20/#22/#15 open. Hosted signed-JWT learner A/B, deployed RLS, hosted restart/expiry and physical multi-device proof remain outstanding; Pro-owned #14/#38/N4 remains untouched.


## Exact-head startup formatter correction — 2026-11-03T21:08Z

- Core run `core-20261103T2108Z-fix-startup-format-and-remove-diagnostic`; branch `automation/issue-22-atomic-review`; parent HEAD `8ebc20529c8772135f8ffa70fe05bbbdb1b8d5f8`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41711121555](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41711121555), attempt 1, targets `8ebc20529c8772135f8ffa70fe05bbbdb1b8d5f8` and completed FAILURE only in Flutter strict formatting. Repo-sanity, AI boundary, database/RLS, disposable local Supabase integration and Windows completed SUCCESS with every step successful. Flutter's temporary formatter diagnostic showed exactly one required change: insert one blank line between the end of `start()` and the following `@override` in `persistent_account_startup.dart`. Analyze, tests and downstream lifecycle/wire/Chrome/Web checks were SKIPPED because strict format stopped the job.
- Applied only that whitespace change and removed the temporary diagnostic step from `.github/workflows/ci.yml` in the same correction. The strict `dart format --set-exit-if-changed`, analyze, full serial Flutter tests and all downstream gates remain unchanged. No production Auth/session/vault, API/schema/RLS, dependency, default activation, N4 or Pro-owned scope changed.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. The correction requires a fresh exact-head Actions run; no new-head pass is claimed until all six jobs and every required step are inspected.
- Hosted signed-JWT learner A/B, deployed RLS, hosted restart/expiry and physical multi-device proof remain outstanding. Keep PR #37 Draft and #20/#22/#15 open. Next: inspect the latest-attempt CI for the resulting exact head; fix only any observed failure.


## Exact-head analyzer correction — 2026-11-03T22:11Z

- Core run `core-20261103T2211Z-fix-account-fixture-analyzer`; branch `automation/issue-22-atomic-review`; parent HEAD `52af83b5727b361d32a0863a0d4abacaa642a8de`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head PR workflow [41719258105](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41719258105), attempt 1, targets this PR head and completed FAILURE. Repository sanity, AI boundary, database/RLS, disposable local Supabase integration and Windows completed SUCCESS with all returned steps successful. Flutter dependency resolution and strict Dart format completed SUCCESS; `flutter analyze` failed only on one lint warning: `test/features/srs/account_fixtures.dart:104:14 unnecessary_non_null_assertion`. The complete Flutter suite and all downstream lifecycle/wire/Chrome/Web checks were SKIPPED, not passed.
- Corrected only the test fixture by removing the redundant `!` from `delayed!.complete(ownProfile())`; flow analysis already proves the local completer non-null in this branch. The existing startup profile-barrier assertion and scenario are unchanged. No production Auth/session/vault, API/schema/RLS, dependency, workflow, N4 or Pro-owned files changed.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. A fresh exact-head Actions run is required to observe analyze, the full Flutter suite and downstream gates. Hosted signed-JWT learner A/B, deployed RLS, hosted restart/expiry and physical multi-device proof remain outstanding. Keep PR #37 Draft and #20/#22/#15 open; Pro-owned #14/#38/N4 untouched.


## Core worker diagnostic handoff — Dart formatter output — 2026-11-04T02:12Z

- Run `core-20261104T0211Z-diagnose-dart-format-runtime-test`; branch `automation/issue-22-atomic-review`; starting HEAD `773e751bc097bdcb5ab21ac2d674745129ddecc4`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41753815439](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41753815439), latest attempt 1, completed with repo-sanity, AI boundary, database/RLS, Windows and disposable Supabase integration SUCCESS (every returned step); Flutter strict format FAILED because Dart 3.35.4 reformatted only `test/features/srs/persistent_supabase_runtime_test.dart`. Flutter analyze, full suite and all downstream lifecycle/vault/profile/wire/Chrome/Web checks were SKIPPED, not passed.
- Added a temporary read-only diagnostic before the unchanged strict format gate. It prints a unified diff from pinned Dart 3.35.4 `dart format --output=show` for that one file, writing only under `RUNNER_TEMP`; it does not alter checkout contents or bypass the formatter gate. Next worker must apply the exact output and remove this diagnostic in the same correction.
- Changed paths: `.github/workflows/ci.yml` and `docs/PROJECT_STATUS.md`. No production Auth/session/vault, API/schema/RLS, dependencies, tests/assertions, default activation, Pro-owned N4 paths or release settings changed.
- Cloud runtime has no Dart/Flutter SDK; no local format/analyze/test/build was run. Hosted signed-JWT learner A/B, deployed RLS, hosted restart/expiry and physical multi-device proof remain outstanding. PR #37 stays Draft; #20/#22/#15 remain open; Pro-owned #14/#38/N4 untouched.
- Next: inspect the exact diff from the new exact-head CI, apply only Dart's formatting output, remove the temporary diagnostic, then require all six jobs and every required step on the final head.


## Caller-owned close during pending credential-vault read — 2026-11-04T06:12Z

- PR #37 branch `automation/issue-22-atomic-review`, starting HEAD `4494c3c9df3e9e6c1299a44fcf7c114af07b5b2e`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Added a pinned-Supabase-SDK regression in `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`: caller close begins while the startup vault read is held; the owner remains draining until the read settles, then rejects the late saved secret, performs one ordered `read -> clear`, and completes closed. The test requires zero `/auth/v1/token` and zero `ensure_profile` requests.
- Updated `docs/PERSISTENT_SESSION_LIFECYCLE.md` and the existing `persistent-session-lifecycle` QA anchor; no new acceptance case was claimed.
- Previous exact-head CI [41772535782](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41772535782) completed SUCCESS on `4494c3c9df3e9e6c1299a44fcf7c114af07b5b2e`: repo-sanity 11/11, AI boundary 12/12, database 12/12, disposable Supabase integration 13/13, Windows 17/17, Flutter 35/35; every job and returned step SUCCESS. This is parent-head evidence only.
- No Dart/Flutter SDK is available in this cloud runtime; local format/analyze/test/build were not run. New exact-head CI is required before claiming the regression passes.
- No production Auth/session/vault code, Auth strategy/provider, SQL/schema/RLS, dependencies, default runtime activation, secrets, deployment, merge, or Pro-owned #14/#38/N4 paths changed. Hosted signed-JWT learner A/B, hosted restart/expiry, deployed RLS and physical multi-device proof remain outstanding.
- Worker remains ACTIVE while the source/tree/diff checkpoint is persisted; next action is inspect every latest-attempt job and step on the final exact head.


### Source checkpoint persisted — 2026-11-04T06:14Z

- Source commit `9462b501944aeba783992542b5084b5f73c3e4f3` (parent `4494c3c9df3e9e6c1299a44fcf7c114af07b5b2e`) adds only the caller-close/pending-vault-read regression, lifecycle documentation, one QA anchor, and this status handoff.
- Separate diff review: exactly four intended paths; test +50 lines, lifecycle doc +22, QA matrix +5/-1, status +11. No production code or assertions were modified.
- Recursive base/result trees were both complete and untruncated at 327 entries (262 blobs / 65 trees); same path/mode/type set, no additions/removals, 258 unchanged blob SHAs. `create_tree` used base tree `dbdb926380e4cccd75c38bdeb4e1dac6aad28dbe`; source `update_ref` used expected SHA `4494c3c9df3e9e6c1299a44fcf7c114af07b5b2e`, `force=false`; branch readback matched.
- Exact-head CI [41784564786](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41784564786) was QUEUED on source head `9462b501944aeba783992542b5084b5f73c3e4f3` at handoff; no test/build result was yet available. This is not a CI pass.
- Cloud has no Dart/Flutter SDK; local format/analyze/test/build were not run. New final-head CI is required. Hosted signed-JWT learner A/B, deployed RLS, hosted expiry/restart and physical multi-device proof remain outstanding.
- Final checkpoint before this status-only handoff: branch head `7c9dad01628e9b7690ebd3e43162c9b2ab493893`; exact-head CI [41784645989](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41784645989) is PENDING with no jobs published. Source-head CI [41784564786](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41784564786) remains IN_PROGRESS on the parent source commit and is not final-head evidence. Worker RELEASED after this handoff; next action is inspect the successor exact-head workflow and every latest-attempt job/step, without duplicate code while CI is pending.


## Windows vault + pinned Supabase SDK bridge regression — 2026-11-04 UTC

- Resumed the released PR #37 / `automation/issue-22-atomic-review` checkpoint after exact-head CI 41784735725 completed all six jobs and every listed required step successfully on `4ab32b3b228e1adceef91964f9c56b1d6c54355e`.
- Added `windows_persistent_supabase_runtime_test.dart`, composing the actual Windows Dart MethodChannel vault factory with the pinned Supabase SDK/runtime and TEST ONLY MockClient/native-journal fixtures. Coverage: saved refresh-secret read -> server refresh -> rotated-secret write -> own-profile RPC; SDK logout before vault clear; redacted read/write failure blocks readiness; late User A login after logout cannot restore before User B signs in and receives the profile.
- Added one anchor to the existing `persistent-session-lifecycle` QA case and clarified that this combined test mocks the MethodChannel. The separate Windows CI child-process probe remains the actual OS Credential Manager evidence; neither is hosted Supabase learner proof.
- Changed paths: `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, `qa/matrix.json`, `docs/PROJECT_STATUS.md`.
- Cloud runtime has no Flutter/Dart SDK; no local format/analyze/test/build is claimed. Exact-head Actions must verify the new test. Hosted signed-JWT learner A/B, deployed RLS, hosted expiry/restart and physical multi-device evidence remain outstanding. PR #37 stays Draft; #20/#22/#15 remain open; Pro-owned #14/#38/N4 untouched.


## Formatter diagnostic checkpoint — 2026-11-04 UTC

- Exact-head CI [41792111168](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41792111168) targets `f6a4b7f571409e7b75f2acaefde5e886e872b6f8`. Repo-sanity, AI boundary and database completed SUCCESS/all steps. Flutter strict Dart format FAILED on the new `windows_persistent_supabase_runtime_test.dart`; analyze, full tests and downstream Flutter gates were SKIPPED. Disposable Supabase integration and Windows jobs were still IN_PROGRESS at the last observation.
- Added a temporary read-only CI diagnostic to print the exact Dart 3.35.4 formatter diff into the Flutter job log. It writes only to `RUNNER_TEMP`, does not modify the checkout, and does not bypass the strict formatter gate. Remove this diagnostic in the same commit that applies the exact formatter output.
- No test/analyze/build pass is claimed. Cloud runtime has no Dart/Flutter SDK. Keep PR #37 Draft and #20/#22/#15 open; hosted learner/Auth/expiry/restart and multi-device gates remain pending.


## Diagnostic workflow syntax correction — 2026-11-04 UTC

- The temporary diagnostic workflow revision `d9a44ccce4e271c05204c47cb0a20549c489feeb` produced Actions run [41792517944](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41792517944) with no jobs. The unquoted colon in the temporary step's `name` was not valid YAML plain-scalar syntax.
- Corrected only the diagnostic step label (the read-only formatter diff command and strict formatter gate are unchanged). The diagnostic remains temporary and will be removed with the exact formatting correction.
- No new source test/analyze/build result is claimed; the previous test-head run 41792111168 still targets parent `f6a4b7f571409e7b75f2acaefde5e886e872b6f8`. Keep PR #37 Draft and all hosted gates pending.


## Pinned Dart formatter correction — 2026-11-04 UTC

- Exact-head diagnostic run [41792913013](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41792913013) (head `a2b0ba88645f89ecae96fa869562c598d1e48ff5`) printed the Dart 3.35.4 formatter's exact output. Only three layout hunks and the final formatter newline differed; no other Dart file changed.
- Applied those exact formatter hunks to `windows_persistent_supabase_runtime_test.dart`. Added a non-vacuous `auth.logout` presence assertion before checking the later Windows vault clear.
- Removed the temporary read-only diagnostic step from `.github/workflows/ci.yml` in this same correction. The strict repository-wide `dart format --output=none --set-exit-if-changed .` gate remains unchanged.
- Run 417929: repo-sanity, AI boundary and database SUCCESS; Flutter formatter diagnostic showed the mismatch and strict format failed before analyze/tests; Windows and Supabase integration were IN_PROGRESS at the last observation. A new exact-head full CI run is required; no analyze/test/build pass is claimed. Hosted signed-JWT learner A/B, deployed RLS, hosted expiry/restart and physical multi-device evidence remain outstanding.


## Follow-up formatter diagnostic — 2026-11-04 UTC

- Corrected source head `7ccb03a3b8943f2d8824f825ab55766ca617be44` still failed the strict Dart format step in exact-head CI [41793363427](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41793363427); repo-sanity passed, database and AI boundary passed, Flutter analyze/tests were skipped after formatting, and Windows/Supabase jobs were still running at last observation.
- The first diagnostic's three hunks were applied, but the strict formatter still reports this test file changed. Re-added the same read-only `dart format --output=show` + `diff -u` diagnostic (unique step name, no YAML colon) to capture the remaining exact diff. It writes only to `RUNNER_TEMP`; strict formatting remains mandatory.
- Next: apply the second exact diff and remove the diagnostic in the same commit. No analyzer/test/build success is claimed.


## Core worker handoff — Windows vault formatter cleanup — 2026-11-04T09:12Z

- Run `core-20261104T0910Z-windows-vault-formatter-cleanup`; branch `automation/issue-22-atomic-review`; source/status commit pending; parent `82835f88155cb31d80a18f3f800a4109fb9ac533`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41793684254](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41793684254) targets `82835f88155cb31d80a18f3f800a4109fb9ac533`, attempt 1. Repo-sanity, AI boundary, database/RLS, disposable local Supabase integration and Windows all passed every listed step. Flutter failed only strict Dart 3.35.4 formatting: the new `windows_persistent_supabase_runtime_test.dart` had one extra blank line after the final closing brace. Flutter analyze, full tests, lifecycle/vault/profile/wire/Chrome/Web and artifact upload were skipped, not passed.
- Applied exactly the formatter's one-blank-line EOF correction and removed the temporary read-only diagnostic from `.github/workflows/ci.yml` in the same source change. No assertions, production Auth/session/vault code, API/schema/RLS, dependencies, defaults, or Pro-owned #14/#38/N4 content changed. Strict repository-wide formatter gate remains unchanged.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. The new exact-head CI must verify all six jobs and every required step before this correction can be considered green. TEST ONLY SDK/MethodChannel/native probes are not hosted learner A/B proof.
- Next: inspect all latest-attempt jobs/steps for the exact final commit, then address only observed failures. Keep PR #37 Draft and #20/#22/#15 open until full issue and hosted acceptance is demonstrated.


## Windows vault late-write generation regression — 2026-11-04 UTC

- Added a pinned Supabase SDK + Windows MethodChannel regression in
  `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`.
  It holds User A's credential write across logout, proves immediate readiness
  revocation, verifies the serialized clear occurs only after the pending write,
  rejects any A own-profile request, then accepts B only after B's rotated
  refresh secret is stored and B's captured bearer/profile agree.
- Updated `docs/PERSISTENT_SESSION_LIFECYCLE.md` to distinguish this mocked
  MethodChannel/SDK evidence from the separate native Credential Manager probes.
- Local Flutter/Dart format/analyze/test/build were not run because the cloud
  runtime has no Flutter/Dart SDK. Exact-head GitHub Actions is the required
  verification; no pass is claimed until every required job and step completes.
- Hosted signed-JWT learner A/B, deployed RLS, restart/expiry on the hosted
  service and real multi-device sync remain unverified. PR #37 stays Draft;
  #20/#22/#15 remain open. Pro-owned #14/#38/N4 are untouched.
- Next: inspect exact-head/latest-attempt CI for all jobs and steps; fix only
  observed diagnostics, then continue the remaining hosted acceptance gates.


## Exact-head Dart formatter correction — 2026-11-04T14:12Z

- Core run `core-20261104T1412Z-pr37-format-correction`; branch `automation/issue-22-atomic-review`; starting HEAD `c8b19daf29247d5ef3e09e61117e26e62d83d202`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41835945318](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41835945318), attempt 1, targets this starting HEAD. Repository sanity, AI boundary, database/RLS, disposable Supabase integration and Windows all completed SUCCESS with every listed step. Flutter failed only at strict Dart 3.35.4 format: the diagnostic output showed one line-wrap compaction in `windows_persistent_supabase_runtime_test.dart` around the User B `ensure_profile` request filter. Flutter analyze, the complete test suite and downstream lifecycle/wire/Chrome/Web/build steps were SKIPPED, not passed.
- Applied only the formatter-emitted line wrap to that test and removed the temporary read-only diagnostic step from `.github/workflows/ci.yml` in the same correction. The repository-wide strict formatter command remains unchanged; no assertions, test semantics, runtime/Auth behavior, API/schema/RLS, dependencies or defaults changed.
- Cloud runtime has no Flutter/Dart SDK; no local format/analyze/test/build is claimed. The successor exact-head Actions run must verify format, analyze, the full Flutter suite, all native/browser verifiers and builds.
- Hosted signed-JWT learner A/B, deployed RLS, hosted expiry/restart and physical multi-device sync remain unverified. Keep PR #37 Draft and #20/#22/#15 open; Pro-owned #14/#38/N4 untouched.
- Next: inspect every latest-attempt job and required step on the successor exact HEAD; fix only observed failures. Do not merge this draft from formatter correction alone.


## Core worker handoff — formatter correction — 2026-11-04T18:12Z

- Run `core-20261104T1812Z-pr37-browser-store-format-fix`; branch `automation/issue-22-atomic-review`.
- Source commit: `bfd99f84327799db77bd451c6aad3254374c1d1d` (parent `6cd904e430087b78c08b88382686d043b304a7ec`); base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Applied the exact Dart 3.35.4 formatter diff from diagnostic CI [41875730877](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41875730877) to `apps/flutter_app/test/features/srs/browser_review_store_check.dart`: compact the `reject` override signature and wrap its delegate call as emitted; retain one final newline.
- Removed the temporary read-only diagnostic step from `.github/workflows/ci.yml` in the same source commit. The strict repository-wide formatter gate remains unchanged. No assertions, runtime, Auth, schema/RLS, dependencies, defaults or Pro-owned N4 files changed.
- Exact diagnostic job observed: repo-sanity, AI boundary, database, Windows and disposable Supabase integration all SUCCESS; Flutter failed only at strict Dart format. The diagnostic output identified this single file/hunk plus the EOF newline. Flutter analyze, full tests and downstream checks were skipped, not passed.
- Complete base tree previously read back for the 6cd diagnostic checkpoint: 328 entries (263 blobs / 65 trees), with the only delta from its parent being `.github/workflows/ci.yml`. Reconstructed that exact current-head tree from the verified parent tree `592ac416c4115e7bab41775ee63ea0ef7ee3f7df` plus the recorded workflow blob `f684c799d8dde266cc4c034d25b9e02d8be52b62`; the source tree is based on that reconstructed current-head tree, preserving all untouched paths/modes/types.
- Cloud runtime has no Dart/Flutter SDK; no local format/analyze/test/build is claimed. Successor exact-head Actions must pass formatter, analyze, all Flutter tests, Windows, disposable Supabase integration and all required downstream checks before this correction is green.
- PR remains Draft; #20/#22/#15 remain open. Hosted signed-JWT learner A/B, deployed RLS, hosted expiry/restart and physical multi-device proof remain unverified. No merge or deployment.



## Core worker handoff — Windows vault formatter diagnostic — 2026-11-04T22:14Z

- Run `core-20261104T2214Z-pr37-dart-format-diagnostic`; branch `automation/issue-22-atomic-review`; parent HEAD `8627685d76431c4637e01815a10deeab223f6bfd`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41913994938](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41913994938), attempt 1, completed: repo-sanity, AI boundary, database, disposable local Supabase integration and Windows all SUCCESS with every listed step. Flutter failed only at pinned Dart 3.35.4 strict formatting: `windows_persistent_supabase_runtime_test.dart` was the sole changed file. Flutter analyze, full suite and downstream Flutter steps were SKIPPED, not passed. The job log did not include formatter output, so no guessed source patch was applied.
- Added a temporary read-only formatter output/diff step in `.github/workflows/ci.yml` for that one test file, before the unchanged strict repository-wide formatter gate. The diagnostic is to expose the exact formatter hunk; remove it in the same source correction after applying the emitted patch.
- No production Auth/vault/runtime/API/schema/RLS/default behavior, assertions, dependencies, Pro-owned #14/#38 or N4 content changed. Cloud runtime has no Flutter/Dart SDK; no local Flutter format/analyze/test/build was run.
- Next: inspect the new exact-head Actions run and its Flutter job log, apply only the exact Dart 3.35.4 diff, remove the temporary diagnostic, update this status with observed final checks, and require all jobs/steps on the corrected HEAD. Keep PR #37 Draft and #20/#22/#15 open; hosted signed-JWT learner A/B, deployed RLS/PostgREST, hosted expiry/restart and physical multi-device acceptance remain outstanding.


## Windows vault formatter correction — 2026-11-04T23:13Z

- Core run `core-20261104T2311Z-apply-windows-vault-formatter-fix`; branch `automation/issue-22-atomic-review`; source commit `3abcaf227d69b0a49f565414f0d0de21f7aedeac` (parent `fae3d8b22f564bb01336252e846f6d7d09b7bf17`); base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Changed source paths: `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart` and `.github/workflows/ci.yml`. Applied only the exact Dart 3.35.4 formatter output captured in CI [41924070670](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41924070670): compact the three-line `expect(failedClear, greaterThan(...))` call to one line and preserve the formatter's final blank line. Removed the temporary read-only formatter diagnostic. The strict repository-wide format gate remains unchanged; no assertion semantics, Auth/runtime, API/schema/RLS, dependencies, defaults or Pro-owned content changed.
- Parent diagnostic CI [41924070670](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41924070670), attempt 1 on `fae3d8b22f564bb01336252e846f6d7d09b7bf17`: repo-sanity, AI boundary, database, Windows and disposable local Supabase integration completed SUCCESS with every listed step. Flutter failed strict format only; analyze, complete Flutter suite and downstream checks were SKIPPED. The diagnostic output identified the exact single test-file formatting hunk and EOF blank line.
- Source exact-head CI [41932014463](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41932014463), attempt 1 on `3abcaf227d69b0a49f565414f0d0de21f7aedeac`, was QUEUED when observed; no format/analyze/test/build result is claimed for the corrected source yet. The cloud runtime has no Flutter/Dart SDK, so no local Flutter command was run.
- Full recursive base/result trees were untruncated at 328 entries (263 blobs / 65 trees), with identical path/mode/type sets; exactly the two intended blobs changed and all other blobs were preserved. Source `create_tree` used exact `base_tree_sha=4beb1db04bffe3cf646cefb740b77566d777cdd6`; the single-parent commit used `update_ref` with `expected_sha=fae3d8b22f564bb01336252e846f6d7d09b7bf17`, `force=false`; branch readback matched.
- PR #37 remains Draft; #20/#22/#15 remain open. Hosted signed-JWT learner A/B, deployed RLS/PostgREST, hosted expiry/restart and physical multi-device evidence remain outstanding. Pro-owned #14/#38/N4 scope untouched.
- Next: inspect every latest-attempt job and required step on the final status HEAD; fix only observed failures, then continue the remaining hosted acceptance gates. No merge/deployment.


## Core worker handoff — PR #37 formatter correction — 2026-11-05 UTC

- Run `core-20261105T0310Z-pr37-format-fix`; branch `automation/issue-22-atomic-review`. Source commit `d183901a88f4a3743ca702ceab2449db207b95f2` (parent `8a53136ac006426ab543ff75dbe75841b1a881a8`). The status checkpoint is committed immediately after this source change; its final SHA is recorded in the PR body.
- Exact-head diagnostic CI [41953498188](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41953498188), attempt 1, targeted `8a53136ac006426ab543ff75dbe75841b1a881a8`. Repository sanity, AI boundary, database/RLS, Windows, and disposable Supabase integration all completed SUCCESS with every listed step. Flutter failed only in the temporary write-mode formatter reproduction. The runner's pinned Dart 3.35.4 output showed exactly one change: remove the extra blank line at EOF in `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`. Because that diagnostic intentionally exits nonzero when it detects a formatting diff, the normal strict formatter, analyze, full Flutter suite, and downstream Flutter checks were skipped on that diagnostic run; they are not passes.
- Applied exactly that EOF-only formatting change and removed the temporary diagnostic from `.github/workflows/ci.yml`. The repository-wide `dart format --output=none --set-exit-if-changed .` gate remains unchanged. No test assertions or runtime behavior changed.
- Separate diff review: two source paths only; test diff is a single removed blank line; workflow diff removes only the temporary diagnostic step. No Auth strategy/provider, API/schema, migration, RLS, default activation, logging, or security changes.
- Full recursive source tree before/after was untruncated at 328 entries (263 blobs / 65 trees); identical path/mode/type sets; exactly the two intended blobs changed and every other blob preserved. `create_tree` used the exact parent `base_tree_sha=52c49d50b436c28ca342e0d97f875bb610f749d8`; source commit used `update_ref` with `expected_sha=8a53136ac006426ab543ff75dbe75841b1a881a8`, `force=false`; branch readback matched.
- Source exact-head CI [41960250114](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41960250114), attempt 1, targets `d183901a88f4a3743ca702ceab2449db207b95f2`; it was QUEUED when the status checkpoint was prepared. The status commit below triggers a newer exact-head workflow; no new format/analyze/test/build/full-CI pass is claimed yet. Cloud runtime has no Flutter/Dart SDK, so those commands were not run locally.
- Hosted signed-JWT learner A/B, deployed RLS/PostgREST, hosted expiry/restart, physical multi-device sync and full Personal Alpha journey remain unverified. Keep #20/#22/#15 and #18 open. PR #37 stays Draft; no merge/deployment. Pro-owned #14/#38/N4 untouched.
- Next: inspect every latest-attempt job and required step for the final status HEAD; fix only observed failures. Then continue the remaining hosted acceptance gates when approved non-production configuration is available.

## Windows rejected-refresh recovery — formatter handoff — 2026-11-05 UTC

- Source commit `4ea53631b1870100cda3fe133d22440f614b23f7` adds a TEST ONLY Windows MethodChannel + pinned Supabase SDK regression for a rejected saved refresh secret. It verifies no profile/readiness after rejection; a failed vault clear preserves the secret and blocks password Auth; explicit retry clears before password Auth and persists the rotated secret before own-profile readiness. QA anchor and Windows vault limitations were updated.
- Exact-head CI [41973101500](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41973101500), attempt 1, targets this commit. Observed repo-sanity, AI boundary and database SUCCESS with every listed step; Flutter failed only at `dart format --output=none --set-exit-if-changed .` for the new Windows test. Flutter analyze, full tests and downstream checks were SKIPPED, not passed. Windows and disposable Supabase integration were still IN_PROGRESS at last observation; no full-CI pass.
- Added a temporary read-only diagnostic before the unchanged strict format gate: copy only the test to `RUNNER_TEMP`, format the copy with pinned Dart 3.35.4, and print the exact unified diff. It does not modify repository files or bypass the gate. Remove it in the same correction after applying only the emitted formatter patch.
- No local Dart/Flutter SDK in the cloud runtime; local format/analyze/test/build were not run. No production Auth/vault, API/schema/RLS/default/security or Pro-owned #14/#38/N4 changes. Hosted signed-JWT learner A/B, deployed RLS/PostgREST, hosted expiry/restart and physical multi-device acceptance remain outstanding.
- Next: inspect every latest-attempt job/step and the diagnostic output on the new exact HEAD; apply only the formatter diff, remove the diagnostic, then require complete exact-head CI. Keep PR #37 Draft and #20/#22/#15 open; no merge/deployment.



## Windows rejected-refresh formatter correction — 2026-11-05 UTC

- Core run `core-20261105T0610Z-pr37-format-repair` resumes the explicitly RELEASED PR #37 checkpoint on `automation/issue-22-atomic-review`, starting from exact HEAD `5e68413d49402841bfbdd12d641a06a7fef99f2d` (base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`).
- Exact-head GitHub Actions [41973406185](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41973406185), attempt 1: repo-sanity, AI boundary, database and Windows completed SUCCESS with every listed step. Flutter failed the unchanged repository-wide Dart formatter because the new Windows test contained one expression that Dart 3.35.4 collapses to a single line; analyze, full Flutter tests and downstream Flutter checks were SKIPPED, not passed. The pinned formatter diagnostic emitted exactly that one-line diff; it is applied without changing assertions or behavior.
- The same run's disposable Supabase integration job failed at `supabase start`; migration, local Auth/PostgREST, token rotation, replay and A/B RLS steps were SKIPPED. The command redirects CLI output to `/dev/null`, so this run does not reveal the startup cause. This is not hosted learner evidence and is not a pass.
- Remove the temporary formatter-only diagnostic from `.github/workflows/ci.yml`; retain the strict `dart format --output=none --set-exit-if-changed .` gate unchanged. No Auth/provider, API/schema/migration/RLS, default activation, secret/logging or Pro-owned N4 changes.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. The corrected exact-head CI must execute formatter, analyzer, full Flutter tests, Windows and disposable Supabase integration before any pass claim. Hosted signed-JWT learner A/B, deployed RLS/PostgREST, expiry/restart and physical multi-device acceptance remain outstanding; keep #20/#22/#15/#18 open and PR #37 Draft. No merge/deployment.

## Windows caller-close during pending startup restore — 2026-11-05

- Core run `core-20261105T0708Z-pr37-windows-close-during-restore` resumes the RELEASED PR #37 checkpoint on `automation/issue-22-atomic-review`; source commit `17caf70c4a4cce7885c1ac907f564a138285396d` (parent `b7b9d2f55c2e9d02c23a409ab64f6dec22737595`), base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Added TEST ONLY `runtime-close-restore` to `apps/flutter_app/tool/windows_runtime_fixture.dart`: a fresh Windows runner writes a synthetic refresh value to the real OS Credential Manager, holds the SDK startup refresh response, begins caller-owned runtime close, releases the late response only after persistence is closed, and requires restore failure, no profile/readiness, SDK cleanup and an empty OS credential slot. `verify_windows_vault_bridge.ps1` then launches a fresh `runtime-signedout` process to verify the clear persisted across process boundaries.
- Updated `qa/matrix.json` with exact fixture/script anchors and `docs/WINDOWS_SESSION_VAULT.md` with the evidence boundary. No production Auth/provider, schema/migration/RLS, default mode, token logging/fallback, dependency, or Pro-owned #14/#38/N4 path changed.
- Parent exact-head CI [41979327928](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41979327928), attempt 1, completed SUCCESS: all 6 jobs and every listed step passed, including formatter/analyzer/full Flutter suite, native Windows bridge/runtime probes, local GoTrue/PostgREST A/B/RLS integration, and Web/Windows release builds/artifacts. This is TEST ONLY CI evidence for parent `b7b9d2f55c2e9d02c23a409ab64f6dec22737595`, not hosted learner acceptance.
- New exact-head CI [41987017895](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41987017895), attempt 1, targets source commit `17caf70c4a4cce7885c1ac907f564a138285396d`: repo-sanity, AI boundary, database and disposable Supabase integration completed SUCCESS with every listed step; Flutter failed only the strict formatter because Dart 3.35.4 reports `tool/windows_runtime_fixture.dart` as changed. Flutter analyze, full suite and downstream steps were SKIPPED, not passed. Windows was still IN_PROGRESS at the TEST ONLY bridge build when this checkpoint was prepared; no result for the new close-during-restore phase is claimed.
- Added a temporary read-only formatter reproduction in `.github/workflows/ci.yml`: it formats a copy under `RUNNER_TEMP` and prints the exact unified diff; the strict repository-wide format gate is unchanged. Remove this diagnostic immediately after applying only the emitted patch.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. No full CI pass is claimed for source commit `17caf70c4a4cce7885c1ac907f564a138285396d`. Hosted signed-JWT learner A/B, deployed RLS/PostgREST, hosted expiry/restart and physical multi-device acceptance remain outstanding; #20/#22/#15/#18 remain open. PR #37 stays Draft; no merge/deployment.
- Next: inspect the Windows job's result for the new native phase, inspect the diagnostic formatter diff, apply only that diff and remove the temporary workflow step, then require all latest-attempt jobs/steps on the corrected exact head.


## Windows close-during-restore formatter correction — 2026-11-05 UTC

- Core run `core-20261105T0807Z-pr37-close-restore-format-fix` resumes the released PR #37 lane on `automation/issue-22-atomic-review`; parent HEAD `b0591f251aec1f05d2ff34da1e92cc58dc4b5734`, base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. Previous core checkpoint was RELEASED; no concurrent core writer was observed. PR #41 and Pro-owned #14/#38/N4 scope remain untouched.
- Exact Dart 3.35.4 formatter output from diagnostic CI `41987670242` changes only a line break in `apps/flutter_app/tool/windows_runtime_fixture.dart` around the refresh-grant expected-token conditional. No assertion, fixture phase, token value, lifecycle behavior or production code changes.
- Removed the temporary read-only formatter-diff step from `.github/workflows/ci.yml`; the strict repository-wide `dart format --output=none --set-exit-if-changed .` gate is retained unchanged.
- Source HEAD `17caf70c4a4cce7885c1ac907f564a138285396d`, run [41987017895](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41987017895), attempt 1: repo-sanity, AI boundary, database, disposable Supabase integration and Windows all SUCCESS/all steps; Flutter failed only the strict formatter. Analyze/full Flutter tests and downstream Flutter checks were SKIPPED, not passed.
- Diagnostic HEAD `b0591f251aec1f05d2ff34da1e92cc58dc4b5734`, run [41987670242](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41987670242), attempt 1: repo-sanity, AI boundary, database, Windows and disposable Supabase integration SUCCESS/all steps; Flutter diagnostic printed the exact one-line formatter diff, then the unchanged strict formatter gate failed. Analyze/full tests/downstream checks were SKIPPED. This is not a full CI pass.
- Cloud runtime has no Dart/Flutter SDK; local format/analyze/test/build were not run. Corrected exact-head CI must execute formatter, analyzer, full Flutter suite, Web/Windows builds, native Windows vault and disposable Supabase integration before any pass claim. CI's local Supabase A/B is TEST ONLY, not hosted learner proof.
- Keep PR #37 Draft and #20/#22/#15/#18 open. Hosted signed-JWT learner A/B, deployed RLS/PostgREST, hosted expiry/restart and physical multi-device acceptance remain outstanding. No Auth/provider/schema/RLS/default/security change, no merge/deployment/issue closure.
- Next: inspect every latest-attempt job/step on the corrected exact head; if all required jobs pass, separately review the PR and continue the remaining caller-owned vault/hosted acceptance work. If any check is pending or skipped, record it without treating it as pass.


## Windows runtime fixture analyzer correction — 2026-11-05 UTC

- Core run `core-20261105T0910Z-pr37-windows-fixture-analyzer-fix` resumes PR #37 on `automation/issue-22-atomic-review`, parent HEAD `994f7e0405190a99df90d9eaf7c53c98fddb1d7b`, base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head CI [41992663350](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41992663350), attempt 1, completed on parent `994f7e0405190a99df90d9eaf7c53c98fddb1d7b`: repo-sanity, AI boundary, database, Windows and disposable local Supabase integration all SUCCESS with every listed step; Dart formatter SUCCESS. Flutter analyze failed on exactly three `unnecessary_non_null_assertion` warnings in `apps/flutter_app/tool/windows_runtime_fixture.dart` at lines 225, 341 and 343. Full Flutter suite and all downstream Flutter checks were SKIPPED, not passed.
- Removed only those three redundant `!` operators. The local variable is assigned before the close-restore completion and is promoted by the non-null guard in `finally`; no fixture assertions, phase ordering, token values, HTTP behavior or production code changed.
- Changed paths: `apps/flutter_app/tool/windows_runtime_fixture.dart` and `docs/PROJECT_STATUS.md`. The strict repository-wide Dart formatter/analyzer/test/build gates are unchanged. No Auth/provider/schema/migration/RLS/default/security change, no token logging/plaintext fallback, and no Pro-owned #14/#38/N4 path changed.
- Cloud runtime has no Dart/Flutter SDK, so local format/analyze/test/build were not run. The new exact-head CI must execute formatter, analyzer, full Flutter suite, Windows native bridge/vault probes, disposable Supabase integration, Web and Windows release builds before any pass claim. CI's local Auth/JWT/A/B cases remain TEST ONLY, not hosted learner acceptance.
- PR #37 remains Draft; #20/#22/#15/#18 and hosted signed-JWT learner A/B, deployed RLS/PostgREST, hosted expiry/restart and physical multi-device acceptance remain open. No merge, deployment or issue closure.
- Next: inspect every latest-attempt job and required step on the corrected exact head. If all checks pass, separately review the broader PR and continue the remaining caller-owned Auth/session integration and hosted acceptance; do not treat skipped/pending jobs as pass.


## Disposable Supabase startup diagnostics — 2026-11-05 UTC

- Core run `core-20261105T1011Z-pr37-supabase-start-redacted-diagnostics` resumed PR #37 on `automation/issue-22-atomic-review`; parent HEAD `a380d40abdca06dfeb880abb97b40095e314aad2`, base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. Previous #37 worker was RELEASED; latest #41 core checkpoint was RELEASED. Pro-owned #14/#38/N4 paths remain untouched.
- Exact-head CI [42000844039](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42000844039), attempt 1, completed on `a380d40abdca06dfeb880abb97b40095e314aad2`: repo-sanity, AI boundary, database, Windows and Flutter all SUCCESS with every listed step. Flutter format/analyze/full serial tests, Chrome IndexedDB, Web release and Windows native vault/recovery/build checks ran. The disposable Supabase integration job FAILED at `supabase start`; migration, local Auth/PostgREST/rotation/replay/A-B steps were SKIPPED. The command redirected all output to `/dev/null`, so the startup cause was not observable.
- Added `scripts/redact_supabase_start_log.py` to capture startup output only in runner temp, print at most 120 redacted lines on failure, and remove the temporary log on step exit. Redaction covers common key/token/secret/password assignments, JWTs, bearer values and PostgreSQL URL passwords. Added synthetic regressions in `qa/test_supabase_start_log.py`, inventory anchor `ci-supabase-log-redaction`, and updated `docs/QA_SECURITY_MATRIX.md` to 51 assurance cases. No secret values are written to repository artifacts.
- Changed paths: `.github/workflows/ci.yml`, `scripts/redact_supabase_start_log.py`, `qa/test_supabase_start_log.py`, `qa/matrix.json`, `docs/QA_SECURITY_MATRIX.md`, and this status file. Strict integration and CI gates remain unchanged; no Auth/provider/schema/RLS/default/security change.
- Local Python/Flutter execution was not performed in this cloud run. The synthetic redaction tests and the full exact-head CI must execute on the new commit. This does not establish hosted Supabase learner A/B or deployed RLS/PostgREST.
- Next: inspect every latest-attempt job and step on the new exact HEAD. Use only sanitized startup diagnostics to identify the failure; do not claim integration success if startup or downstream steps fail/skip. Keep PR #37 Draft and #20/#22/#15/#18 open; no merge/deployment/issue closure.


## Supabase diagnostic regression fixture review — 2026-11-05 UTC

- Follow-up review of `core-20261105T1011Z-pr37-supabase-start-redacted-diagnostics` found two synthetic-test gaps before relying on the queued CI: the JWT was inside an `anon key` assignment (so the assignment redactor masked it before the JWT-specific branch), and the tail fixture placed its token outside the returned last two lines.
- Corrected `qa/test_supabase_start_log.py` to cover an unlabelled JWT independently, a separate anon-key assignment, and a token assignment that remains inside the bounded output; the test now asserts the raw token is absent from returned output. No production behavior or security boundary changed.
- The first exact-head CI for the diagnostic implementation, [42009495967](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42009495967), was queued on the pre-correction head and is superseded by the new exact-head run. Its result must not be used as evidence for the corrected commit.


## Redaction tail assertion correction — 2026-11-05 UTC

- Exact-head CI [42009743437](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42009743437) ran the new synthetic redaction suite and found one assertion mismatch: the helper correctly retains the field label while replacing its value (`TOKEN=[REDACTED]`); the test expected the label itself to be removed.
- Corrected only the expected output in `qa/test_supabase_start_log.py`. The test still asserts that the raw synthetic token is absent and the tail is bounded. No helper, workflow, production or security behavior changed.
- Repo-sanity failed at this one test; AI boundary passed; database was still cleaning up; Windows and Supabase integration were skipped behind the repo-sanity dependency. A new exact-head run is required.


## Windows startup refresh late-response A/B fence — 2026-11-05T11:20Z

- PR #37 / branch `automation/issue-22-atomic-review`; source test commit `c93f39b50753fb48497fc4c4bd4f2cf2b9f05541`.
- Added a TEST ONLY Windows runtime regression in `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`: hold User A's stored refresh response during startup, logout, prove User B's password Auth is fenced while A's owned request is unsettled, release A's late response, verify cleanup clears the vault and no A profile becomes ready, then authenticate B and verify only B's rotated refresh secret and captured profile bearer are accepted.
- No production Auth/session implementation, provider strategy, schema/RLS, default runtime activation, secret fallback or Pro-owned N4/content paths changed. Existing read/write/clear failure, rotation-before-profile, late-login/write and logout-order assertions remain.
- Parent exact-head CI [42009953024](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42009953024) passed all six jobs and every returned step on `9c3a9113695b7dec9e5710f2e06c6552f3d07634`, including Flutter format/analyze/full suite, Chrome IndexedDB, Web/Windows release, Windows credential store/process bridge and disposable local Supabase GoTrue/PostgREST rotation/replay/A-B RLS. This is TEST ONLY local-stack evidence, not hosted learner Auth proof.
- New source head `c93f39b50753fb48497fc4c4bd4f2cf2b9f05541` has not yet produced an observed exact-head workflow result. Cloud runtime has no Flutter/Dart SDK; the new regression was not run locally. No new-head format/analyze/test/build pass is claimed.
- Next: inspect every latest-attempt job/step for the exact final PR head; fix only observed failures while preserving the assertions. Hosted signed-JWT learner A/B, deployed RLS/PostgREST, expiry/restart and physical multi-device acceptance remain open.

## Exact-head Windows refresh-switch formatter correction — 2026-11-05T12:05Z

- Resumed Draft PR #37 on `automation/issue-22-atomic-review`, parent HEAD `4448bcd12d0f97fee2cf4f412f5b26ab9f4c2aad`, base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. Previous core marker was RELEASED; no overlapping active writer was observed. Pro-owned #14/#38/N4 paths remain untouched.
- Exact-head CI [42018533167](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42018533167) completed on `4448bcd12d0f97fee2cf4f412f5b26ab9f4c2aad`: repo-sanity, database, AI boundary, Windows and disposable local Supabase integration all SUCCESS with every step; Flutter failed only `dart format --output=none --set-exit-if-changed .` on `test/features/srs/windows_persistent_supabase_runtime_test.dart`. Flutter analyze, full tests, wire checks and web build were SKIPPED; no full-CI pass is claimed.
- Applied the single Dart 3.35.4 formatter-required multiline layout to the long refresh-token grant-type expectation in that test. Assertion value/order and runtime behavior are unchanged. Source diff is intentionally one formatting-only hunk.
- No Auth/provider/schema/RLS/default activation/security or Pro-owned N4/content change. Next: exact-head CI must pass formatter, analyze, the complete serial Flutter suite, Web/Windows builds and all retained jobs; hosted learner A/B remains a separate release gate.



## Exact-head Flutter analyzer import correction — 2026-11-05T13:12Z

- Resumed Draft PR #37 on `automation/issue-22-atomic-review`, exact parent HEAD `fc09a4268ddb31cd251601a94f95a12ffb3c5d1f`, base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. Previous core worker marker was RELEASED; this run recorded its ACTIVE marker in the PR body before implementation. Pro-owned #14/#38/N4 files and tests remain untouched.
- Exact-head CI [42024998627](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42024998627), attempt 1, completed on `fc09a4268ddb31cd251601a94f95a12ffb3c5d1f`. Repository sanity, database/RLS, AI boundary, disposable local Supabase integration and Windows jobs all succeeded with every listed step. Flutter strict format also succeeded; `flutter analyze` failed with one undefined identifier, `SessionPersistencePhase`, at `windows_persistent_supabase_runtime_test.dart:361`. The complete Flutter suite, lifecycle/vault/profile/browser checks and Web build were skipped because analysis failed; they are not counted as passing.
- Root cause: the test references the public enum declared in `features/auth/data/persistent_account_access.dart`, but only imported `PersistentSupabaseRuntime`; Dart imports are not transitive. Added the direct library import to the TEST ONLY Windows runtime test. No assertions, production code, Auth strategy, schema/RLS, defaults, security gates or content scope changed.
- Cloud runtime has no Flutter/Dart SDK, so no local Flutter analyze/test/build is claimed. Exact-head GitHub Actions must now run formatter, analyze, full serial Flutter tests, wire checks, Chrome/Web and retained Windows/database/Supabase jobs. Hosted signed-JWT learner A/B, deployed PostgREST/RLS and physical multi-device proof remain separate release gates.


## Empty-vault first-login regression — 2026-11-05

- Resumed released PR #37 on `automation/issue-22-atomic-review`, starting HEAD `5025f6b5e54cb2fd191800b0670503b126299574`, base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. The exact-head parent CI [42034517945](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42034517945) completed all six jobs and every listed step successfully; this is component/local-stack evidence, not hosted learner proof.
- Added a pinned-Supabase-SDK regression for a fresh install with an empty credential vault. It proves startup reads the vault once, makes no refresh-token or own-profile request, and publishes the same owned account as signed out. The first explicit password login then persists the rotated refresh secret before `ensure_profile` and study readiness. The test uses TEST ONLY MockClient, synthetic identity and in-memory vault; it does not prove hosted Auth/JWT/RLS or physical Windows Credential Manager behavior.
- Updated `docs/ACCOUNT_STARTUP.md`, `qa/matrix.json` (52 assurance cases) and `docs/QA_SECURITY_MATRIX.md`. Separate diff review caught and removed one extra blank line before the test file's closing brace and made the login-completion future non-null at its await site; no assertion was weakened. No production Auth/provider, RLS/schema, default runtime, security policy, secret handling or Pro-owned #14/#38/N4 content changed.
- Cloud runtime has no Flutter/Dart SDK; no local format/analyze/test/build claim. New exact-head CI must run formatter, analyzer, complete Flutter suite, Chrome/Web, Windows vault/process and database/Supabase jobs. PR #37 remains Draft; #20/#22/#15 and hosted learner A/B, deployed PostgREST/RLS, expiry/restart and physical multi-device evidence remain open.
- Next: inspect every latest-attempt job and required step on the final status HEAD; fix only observed diagnostics while preserving assertions. Do not treat local Supabase/unsigned test identities as hosted learner evidence.


## Local GoTrue fresh-process session restoration — 2026-11-05 UTC

- Resumed PR #37 after re-reading latest main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`, current PR/branch HEAD `f069bd0bcd9547073531a4b810d23ff382745620`, the #20/#22/#15 acceptance criteria, and the released core-worker marker. Exact-head CI [42044113517](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42044113517) completed SUCCESS on that exact SHA: all six jobs and every step passed.
- Extended `scripts/test_supabase_local.py` with a TEST ONLY fresh-child-process restore: a separate Python process receives a synthetic refresh token over stdin, rotates it against disposable local GoTrue, verifies the authenticated owner, provisions/reads that same owner's profile through PostgREST `ensure_profile`, and returns the rotated token only through captured stdout. Parent checks stderr does not contain the supplied token and later proves global logout revokes the child-rotated token. No token is written to disk or printed.
- Added QA case `local-auth-process-restore` to `qa/matrix.json` (53 assurance cases) and documented its process boundary/limits in `docs/ACCOUNT_STARTUP.md` and `docs/QA_SECURITY_MATRIX.md`. Existing RLS, Auth, SQL and content gates remain unchanged.
- Scope is TEST ONLY local GoTrue/PostgREST plus synthetic short-lived accounts. It does not prove the app's Windows vault and hosted Auth in one integrated run, hosted JWT/RLS, physical multi-device restore, or learner acceptance. No production Auth/provider, schema/migration/RLS, default runtime, dependencies, security policy or Pro-owned #14/#38/N4 content changed.
- Cloud runtime has no Flutter/Dart SDK or local Supabase stack; local Flutter/SQL execution was not run. New exact-head CI must execute repo-sanity, disposable Supabase integration, Flutter format/analyze/full tests, Windows Credential Manager/process probes and Web/Windows builds. No result on the new head is claimed yet.
- Next: inspect every latest-attempt job and step on the new exact HEAD; correct only observed failures while preserving assertions. Keep PR #37 Draft and #20/#22/#15/#18 open; hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted expiry/restart and physical multi-device evidence remain outstanding.


## Windows vault read/logout fence — 2026-11-06

- Core run `core-20261105T2209Z-windows-vault-read-logout`; source branch `automation/issue-22-atomic-review`; source commit `92f01af82b55d500c272d28da66160b4ad06984d` (parent `19f4719f0e640a4bd73529f080902c32293c7c17`), based on main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Added a TEST ONLY pinned-Supabase-SDK/Windows-MethodChannel regression in `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`: hold the stored User A refresh-secret read, request logout, verify no Auth refresh or profile request and no User B password grant while clear is serialized behind the read; after drain, User B signs in and its rotated refresh secret is persisted before its own-profile request. Added the case to `qa/matrix.json` and documented the boundary in `docs/PERSISTENT_SESSION_LIFECYCLE.md`.
- Separate commit diff review: exactly three paths (116 test additions; lifecycle doc 3 additions/1 deletion; QA matrix 5 additions/1 deletion). No production Auth/provider/schema/RLS/default activation, dependencies, security policy or Pro-owned #14/#38/N4 paths changed.
- Recursive tree review: 330 entries before/after, untruncated; identical path/mode/type sets; exactly the three intended blob paths changed; 262 untouched blobs preserved; no paths added or removed. Source `create_tree` used `base_tree_sha=2cd64b5e0dd553982469281ff20b22c5ccc8beea`; ref update used `expected_sha=19f4719f0e640a4bd73529f080902c32293c7c17`, `force=false`; branch readback confirmed source HEAD `92f01af82b55d500c272d28da66160b4ad06984d`.
- Exact-source-head CI [42120017448](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42120017448), attempt 1, targets `92f01af82b55d500c272d28da66160b4ad06984d`. At this checkpoint: repo-sanity and AI boundary SUCCESS/every listed step; database IN_PROGRESS at profile bootstrap/concurrency validation; Windows IN_PROGRESS at Flutter SDK setup; disposable Supabase integration IN_PROGRESS at local stack startup; Flutter job not yet published. Pending/unpublished steps are not passes. No new-head format/analyze/full-test/Web/Windows-build/full-CI pass is claimed.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. The held MethodChannel response and Auth HTTP are TEST ONLY; the separate Windows native Credential Manager probe is not hosted learner evidence. Hosted signed-JWT learner A/B, deployed RLS/PostgREST, hosted expiry/restart, physical multi-device sync and Personal Alpha release gates remain outstanding.
- Next: inspect the latest attempt and every required job/step on the resulting status HEAD; correct only observed diagnostics while preserving all assertions. Keep PR #37 Draft and #20/#22/#15/#18 open.



## Windows vault read/logout formatter correction — 2026-11-06 UTC

- Core run `core-20261105T2312Z-windows-vault-formatter` resumed Draft PR #37 on `automation/issue-22-atomic-review`, exact parent HEAD `5ea1b4bc83edf5cd2c730ebe9b73367a47a0d228`, base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. The previous #37 and #41 worker checkpoints were RELEASED before this run; no overlapping core writer was observed.
- Exact-head diagnostic CI [42120508941](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42120508941), attempt 1, targets `5ea1b4bc83edf5cd2c730ebe9b73367a47a0d228`. Repo-sanity, AI boundary, database/RLS, Windows and disposable Supabase integration completed SUCCESS with every listed step. Flutter failed only the strict Dart formatter. Its pinned Dart 3.35.4 diagnostic emitted exactly three layout changes in `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`: wrap the long `reason` value, collapse the single-predicate `where`, and remove the extra continuation layout. Flutter analyze, full tests and downstream Web/Flutter checks were SKIPPED, not passed.
- Applied only those exact formatter hunks and removed the temporary read-only diagnostic step from `.github/workflows/ci.yml`. The repository-wide `dart format --output=none --set-exit-if-changed .` gate remains unchanged; test expectations, production behavior and all other CI gates are unchanged.
- Full recursive tree at parent was untruncated (330 entries / 265 blobs). The successor tree is based on that exact parent tree; only the workflow, TEST ONLY regression test and this status file are intended to change. Pro-owned #14/#38/N4 source/content paths remain untouched.
- Cloud runtime has no Dart/Flutter SDK, so local format/analyze/test/build were not run. The new exact-head Actions run must execute strict format, analyze, the complete Flutter suite, Web/Windows release builds, Windows vault/process probes, database/RLS and disposable Supabase integration before any full-CI pass claim. CI local-stack/fixture Auth is not hosted learner evidence.
- Next: inspect every latest-attempt job and every required step for the corrected exact HEAD. Keep PR #37 Draft and #20/#22/#15/#18 open; hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted expiry/restart and physical multi-device acceptance remain outstanding. No merge, deployment or issue closure.


- Corrected source head `78904c4ccd594fef2da84d86bdb1d5c3710cff73` has exact-head CI [42128332961](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42128332961), attempt 1. At 2026-11-05T23:17Z, `repo-sanity`, `database` and `ai-boundary` completed SUCCESS with every listed step; `flutter`, `windows` and `supabase-integration` were still IN_PROGRESS. The formatter step had not yet completed in that observation; no full-CI pass is claimed. This status-only follow-up will trigger a new exact-head run, which must be inspected independently.


## Caller-owned close during pending logout clear — 2026-11-06

- Core run `core-20261106T0707Z-caller-close-during-logout-clear`; source commit `31957d1d195ad0ebdb645693ca6db414ad5e7856` (parent `687d87b6a1dd8edc9aeb3268741ac4fac0c09d63`), branch `automation/issue-22-atomic-review`, base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Added a TEST ONLY pinned-Supabase-SDK regression that establishes a persisted User A session, holds the serialized vault clear during logout, calls caller-owned runtime close, and proves close remains pending until cleanup completes. It also asserts immediate readiness revocation, no extra own-profile request, empty vault after release, and continued use of the caller-borrowed HTTP client.
- Added a held-clear control to the in-memory test vault, extended the existing `persistent-session-lifecycle` QA anchor, and documented the boundary in `docs/PERSISTENT_SESSION_LIFECYCLE.md`. Changed paths: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `apps/flutter_app/test/features/srs/session_lifecycle_fixtures.dart`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, `qa/matrix.json`.
- Separate source diff review: exactly four intended paths; 60 test lines added, one fixture barrier added, lifecycle boundary documented, and one existing QA case scope/anchor extended. Full recursive tree remained 330 entries / 265 blobs, no path/mode/type changes; exactly four blobs changed and 261 prior blobs remained byte-identical. `create_tree` used base_tree_sha `0d0b3ebb72e70a5640c55509e511894c3d14def4`; ref update used expected_sha `687d87b6a1dd8edc9aeb3268741ac4fac0c09d63`, force=false; branch readback is `31957d1d195ad0ebdb645693ca6db414ad5e7856`.
- Parent exact-head CI [42128559496](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42128559496) completed SUCCESS on `687d87b6a1dd8edc9aeb3268741ac4fac0c09d63`: all six jobs (repo-sanity, ai-boundary, database, supabase-integration, windows, flutter) and every returned step SUCCESS. This is parent evidence only.
- New source exact-head CI [42179620494](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42179620494) is IN_PROGRESS on `31957d1d195ad0ebdb645693ca6db414ad5e7856`: repo-sanity, database and ai-boundary completed SUCCESS/all steps; Windows is IN_PROGRESS at Flutter SDK setup; disposable Supabase integration is IN_PROGRESS at local stack startup; Flutter is QUEUED. The new regression, format/analyze/full Flutter suite and downstream builds have not yet completed; no new-head full-CI pass is claimed.
- Cloud runtime has no Flutter/Dart SDK, so local Flutter format/analyze/test/build were not run. This remains TEST ONLY in-memory vault/MockClient evidence, not delayed native Credential Manager or hosted signed-JWT learner Auth/RLS proof. No production Auth/provider/schema/RLS/default/security change, no plaintext fallback/token logging, and no Pro-owned #14/#38/N4 path changed.
- Next: inspect every latest-attempt job and required step for the final exact HEAD, fix only observed diagnostics, then continue hosted Auth A/B, deployed RLS/PostgREST, expiry/restart and two-device acceptance. Keep PR #37 Draft and #20/#22/#15/#18 open; no merge/deployment/issue closure.


## Caller-owned close during pending logout clear — formatter repair — 2026-11-06 UTC

- Core run `core-20261106T0811Z-pr37-formatter-fix`; branch `automation/issue-22-atomic-review`; parent HEAD `00e04d863ec42c59347af9d1399a41637257c706`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head diagnostic CI [42179965337](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42179965337) targets the PR merge ref containing this source HEAD. Database, repo-sanity, AI boundary, disposable Supabase integration and Windows completed SUCCESS with all listed steps. Flutter failed only the unchanged strict Dart formatter; analyze, full Flutter suite and downstream Flutter/Web checks were SKIPPED, not passed.
- Pinned Dart 3.35.4 diagnostic showed one source formatting change in `persistent_supabase_runtime_test.dart`: wrap the long close-order assertion's `reason` value onto the formatter-required continuation line. The extra diagnostic summary line is formatter output, not source content. Applied only that hunk and removed the temporary read-only diagnostic step from `.github/workflows/ci.yml`; the strict repository-wide format gate remains unchanged.
- Changed paths in this correction: `.github/workflows/ci.yml`, `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, and this status file. No assertion, production behavior, Auth/provider, schema/RLS, security, or Pro-owned #14/#38/N4 content changed.
- The complete parent-to-current comparison contains exactly three commits and six modified paths, with no additions/deletions. This runtime cannot read a recursive Git tree and the cloud container cannot resolve GitHub; the current tree is reconstructed from the previously verified parent tree `0d0b3ebb72e70a5640c55509e511894c3d14def4` plus all six current blobs, preserving every untouched base entry. The final commit diff will be checked separately before the ref update.
- Cloud runtime has no Dart/Flutter SDK; local format/analyze/test/build were not run. The corrected exact-head Actions run must execute formatter, analyze, full Flutter tests, Windows, disposable Supabase integration and Web build before any full-CI pass claim. Hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted expiry/restart and physical multi-device acceptance remain outstanding.
- Next: inspect every latest-attempt job and required step on the corrected exact HEAD; fix only observed failures while retaining assertions. Keep PR #37 Draft and #20/#22/#15/#18 open; no merge, deployment or issue closure.


## Core worker handoff — late User A vault write plus failed logout clear — 2026-11-06T10:15Z

- Run `core-20261106T1015Z-pr37-late-write-clear-retry` is RELEASED. Branch `automation/issue-22-atomic-review`; source commit `71eaa1b993c828f438a12f049806ca9e481b6cc7` (parent `07d34acdbd9b23c14de72435d2be5763ac694379`); base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Added one pinned-Supabase-SDK/Windows MethodChannel TEST ONLY regression in `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`: hold User A's refresh-secret write, begin logout, force the serialized clear to fail, verify readiness stays revoked and User B cannot issue Auth/profile requests, then explicitly retry cleanup and require B's rotated secret before B's own-profile request. Updated `docs/PERSISTENT_SESSION_LIFECYCLE.md` and the `persistent-session-lifecycle` QA anchor/limitation.
- Source diff review: exactly three paths changed (117 test lines; 21 lifecycle-doc lines; QA scope/anchor/limitation 6 additions and 2 removals). No production code, Auth strategy/provider, schema/RLS, default runtime, CI/security gate, dependency, N4/Pro-owned content or deployment changed. Full recursive tree remained untruncated at 330 entries/265 blobs; identical path set and modes/types; every untouched blob and unrelated subtree SHA preserved. `create_tree` used base tree `a00eec51881a0c75b1908faafbfa71ac18e40e45`; source ref update used expected HEAD `07d34acdbd9b23c14de72435d2be5763ac694379`, force=false.
- Cloud runtime has no Dart/Flutter SDK, so local format/analyze/test/build were not run. Exact-source CI [42202050500](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42202050500) targets `71eaa1b993c828f438a12f049806ca9e481b6cc7` and is IN_PROGRESS at this checkpoint; no new test/build pass is claimed. The next run must inspect every latest-attempt job/step on the final PR HEAD and fix only observed failures.
- This is pinned SDK + MockClient + in-memory MethodChannel evidence, not delayed native Credential Manager failure injection or hosted signed-JWT learner A/B. Deployed PostgREST/RLS, hosted expiry/restart, physical multi-device sync and Personal Alpha learner journey remain outstanding. PR #37 stays Draft; #20/#22/#15/#18 remain open; no merge, deployment, release or issue closure.


## Core worker update — pinned Dart formatter diagnostic — 2026-11-06T10:24Z

- Run `core-20261106T1015Z-pr37-late-write-clear-retry` remains the sole active core writer on `automation/issue-22-atomic-review`; current pre-diagnostic HEAD `749dd3d08ea862fb1b932ef229a6e14fc30cdfb9`.
- Source CI [42202050500](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42202050500), attempt 1, targets source commit `71eaa1b993c828f438a12f049806ca9e481b6cc7` and is COMPLETED/CANCELLED after the status successor superseded it. Repo sanity, AI boundary and database completed SUCCESS; Flutter strict Dart formatter FAILED; analyze, full Flutter tests and Web build were SKIPPED; Windows and disposable Supabase integration were CANCELLED. This is not a full CI pass.
- Exact final-status-head CI [42202179704](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42202179704), attempt 1, targets `749dd3d08ea862fb1b932ef229a6e14fc30cdfb9`: repo sanity and AI boundary SUCCESS; database IN_PROGRESS; Windows and Supabase integration QUEUED; Flutter had not yet been published. No full pass is claimed.
- Added a temporary read-only Dart 3.35.4 formatter-output diagnostic immediately before the unchanged strict formatter gate in `.github/workflows/ci.yml`. It writes formatted output only under RUNNER_TEMP and diffs it against the checked-in file; it does not modify the checkout, skip or weaken the gate. This commit will trigger an exact-head diagnostic workflow. Next: capture the exact hunk, then remove the diagnostic and apply only the formatter correction.
- No local Flutter/Dart SDK is available in the cloud runtime. No new analyze/test/build success is claimed; hosted JWT A/B, deployed RLS/PostgREST, physical multi-device proof and Personal Alpha remain pending.


## PR #37 — late refresh write / failed vault-clear formatter correction — 2026-11-06 UTC

- Re-read the complete PR #37 source tree at diagnostic HEAD `fbc9a93f6ba3c835806f1e02d23b900c526a52c2`: recursive tree was untruncated (330 entries); this bounded correction preserves the existing tree and changes only the workflow, one TEST ONLY Windows runtime test line-wrap, and this status document.
- Exact-head diagnostic CI [42202491684](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42202491684), attempt 1, targets `fbc9a93f6ba3c835806f1e02d23b900c526a52c2`. `database`, `repo-sanity`, `ai-boundary`, `windows`, and `supabase-integration` completed SUCCESS with every listed step successful. `flutter` failed only the strict pinned Dart 3.35.4 formatter because the final vault-write-before-profile assertion required a four-line wrap. Flutter analyze, the full test suite, downstream runtime verifiers and Web build were SKIPPED, not passes.
- Applied only that exact formatter hunk in `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`; removed the temporary read-only formatter diagnostic from `.github/workflows/ci.yml`. The repository-wide strict formatter gate and every later CI step remain unchanged. No assertions, production behavior, Auth strategy/provider, API/schema/RLS, default runtime, security boundary, dependency or Pro-owned #14/#38/N4 content changed.
- Cloud runtime has no Flutter/Dart SDK, so local format/analyze/test/build were not run. The corrected exact-head workflow must execute formatter, analyze, full Flutter tests, Windows, disposable Supabase integration and Web build before a new full-CI pass can be claimed.
- TEST ONLY pinned-SDK/MockClient/MethodChannel/Windows process evidence is not hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted expiry/restart or physical multi-device proof. #20/#22/#15/#18 remain open; PR #37 stays Draft. No merge, deployment, production release or issue closure.
- Next: inspect every latest-attempt job and step for the corrected exact PR HEAD; fix only observed failures, otherwise retain the CI handoff. Hosted staging/learner proof remains externally unverified.


## Core worker checkpoint — ACTIVE — 2026-11-07T07:33Z

- Run `core-20261107T0733Z-pr37-close-retry`; branch `automation/issue-22-atomic-review`; starting HEAD `e145a1202a01d5e75eb1003abbdf76fb998a157c`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Code change: failed logout/rotation cleanup is now remembered by `PersistentAccountAccess`; caller close retries SDK sign-out and vault clear before releasing the project owner. A failed close returns a fixed safe error, retains ownership and is retryable. The outer `PersistentSupabaseRuntime.close()` also clears its cached failed future so a later explicit close can finish cleanup.
- Tests authored: pure lifecycle scenario `close-retries-failed-cleanup` and pinned-SDK Windows MethodChannel regression `Windows caller close retries failed logout clear before releasing owned runtime`. The regression keeps User A's token fenced, rejects a replacement owner while clear still fails, then verifies a second close clears it before owner release.
- Paths: `persistent_account_access.dart`, `persistent_supabase_runtime.dart`, `session_lifecycle_fixtures.dart`, `windows_persistent_supabase_runtime_test.dart`, `PERSISTENT_SESSION_LIFECYCLE.md`, `qa/matrix.json`, `PROJECT_STATUS.md`.
- Previous exact-head CI [42296020766](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42296020766) passed all six jobs/every returned step on its own head; this is historical parent evidence, not the new source. Cloud runtime lacks Flutter/Dart SDK; local format/analyze/test/build were not run. New exact-head CI is required.
- Hosted signed-JWT A/B, deployed RLS/PostgREST, actual native Credential Manager failure injection, learner restart/expiry and physical multi-device evidence remain outstanding. No Auth strategy/provider/default activation, migration/RLS, Pro N4, merge or deployment change.
- Next: review the full diff/tree, publish with exact base tree and expected HEAD/force=false, then inspect all latest-attempt jobs/steps on the new exact head. Keep PR #37 Draft and #20/#22/#15 open.


## PR #37 formatter repair — 2026-11-07T12:08Z

- Resumed the stale formatter checkpoint on `automation/issue-22-atomic-review` from exact starting HEAD `8cb7e40583c154fd7598c53638be33fb072d95ba`; main remains `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. The recursive parent tree was complete and untruncated (335 entries).
- Exact-head CI [42362945395](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42362945395), attempt 1, failed only the pinned Dart 3.9.2 format step in `windows_persistent_supabase_runtime_test.dart`. The other five jobs completed successfully; Flutter analyze, full tests and downstream Flutter checks were skipped, not passes.
- Pinned formatter run [42362940960](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42362940960), attempt 1, succeeded and emitted the exact two-hunk patch. Applied only those two formatting changes in the TEST ONLY Windows runtime test and removed the temporary formatter workflow; all assertions and strict CI gates remain unchanged.
- No production Auth/provider, API/schema/RLS, default runtime activation, N4 content, deployment, merge or issue closure changed. Cloud runtime lacks Flutter/Dart SDK, so local format/analyze/test/build were not run; corrected exact-head CI remains the verification gate.
- Hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted expiry/restart, actual native Credential Manager failure injection and physical multi-device proof remain unverified. PR #37 stays Draft; #20/#22/#15/#18 remain open.
- Next: inspect every latest-attempt job and step on the corrected exact PR head; fix only observed failures, or hand off if CI is still pending.


## PR #37 direct vault type import — 2026-11-07T12:16Z

- Exact-head CI [42371431572](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42371431572) passed pinned Dart formatting, then Flutter analyze found two `non_type_as_type_argument` errors for `SessionVaultFailure` in the Windows runtime TEST ONLY file. Database, repo-sanity and AI-boundary passed; Windows and disposable Supabase integration were still running. Full Flutter tests and downstream checks were skipped, not passes.
- Root cause: the test referenced a type declared in `session_credential_vault.dart` but imported only the Windows adapter, which does not re-export the type. Added the direct package import only in commit `0f9d36fec95a9ae4824df2c314cd4604786407fa`; existing assertions and runtime behavior are unchanged.
- No production/Auth/provider/API/schema/RLS/default runtime, N4 content, deployment or security behavior changed. Cloud runtime lacks Flutter/Dart SDK; local analyze/test/build were not run.
- Next: inspect all latest-attempt jobs/steps on the corrected exact PR head. Hosted learner A/B, deployed PostgREST/RLS, expiry/restart and physical multi-device acceptance remain open.


## Core worker checkpoint — ACTIVE — 2026-11-07T13:13Z

- Run `core-20261107T1313Z-pr37-start-race`; branch `automation/issue-22-atomic-review`; parent HEAD `194d70a93fbcc9b0e9eb192f5ceb21052048e614`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head Actions [42371680102](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42371680102) completed: database, repo-sanity, AI boundary, disposable Supabase integration and Windows all SUCCESS with every listed step successful. Flutter format and analyze SUCCESS; full suite FAILED at `persistent session lifecycle: close-retries-failed-cleanup` because the first sign-in after an empty-vault start was rejected at the operation guard. All later Flutter steps were SKIPPED, not passes.
- Changed paths in this checkpoint: `apps/flutter_app/lib/features/auth/data/persistent_account_access.dart` (reserve operation before scheduling work), `apps/flutter_app/test/features/srs/session_lifecycle_fixtures.dart` (explicit empty-vault/first-login regression), this lifecycle document, and this status record. No Auth strategy/provider, API/schema/RLS, Pro-owned N4 or default activation change.
- New exact-head CI will verify the correction. Cloud runtime has no Flutter/Dart SDK, so local format/analyze/test/build were not run. Hosted signed-JWT learner A/B, deployed RLS/PostgREST, hosted expiry/restart and physical multi-device proof remain outstanding. PR #37 stays Draft; #20/#22/#15/#18 remain open.
- Next: inspect every latest-attempt job/step for the new exact HEAD; fix only observed failures, then continue unblocked study/quiz/progress integration without entering Pro #14/#38/N4 scope.


## Empty-vault first-login race — formatter correction — 2026-11-07T15:24Z

- Exact-head diagnostic CI [42385808366](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42385808366) targets `ba7f4d42652626091c5729a5d5b1a31a8acb6189`. Repo-sanity and AI boundary passed; Flutter's read-only formatter diagnostic emitted the exact pinned Dart 3.35.4 hunk for `persistent_account_access.dart`. The strict format step then failed; analyze, full Flutter suite and downstream Flutter checks were skipped, not passes. Database completed successfully; Windows and disposable Supabase were still in progress at the observation. A preceding diagnostic-only run had no jobs because its temporary YAML step name was unquoted; that name was quoted before this run.
- Applied only the formatter hunk and removed the temporary diagnostic from `.github/workflows/ci.yml`. No assertions, runtime behavior, Auth/provider strategy, API/schema/RLS, default activation or Pro-owned N4 content changed.
- Complete recursive base tree contained 334 entries and was untruncated. The corrected commit preserves all paths/modes/types and all untouched blobs; exact base tree and expected branch head are used with force=false. Cloud runtime lacks Flutter/Dart SDK, so local format/analyze/test/build remain unrun; new exact-head CI is required.
- Next: inspect every latest-attempt job/step on the corrected head; confirm `empty-start-login` regression and complete Flutter/Windows/Supabase/Web checks before moving beyond PR #37.


## Core worker checkpoint — cancellation survives deferred Auth start — 2026-11-07T16:10Z

- Resumed PR #37 at exact branch HEAD `dd35c25a433d543a5e31dff19dbf766f28046524`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. Full recursive tree read was untruncated: 334 entries; exact branch ref matches PR head.
- Exact-head CI [42386095421](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42386095421) passed repo-sanity, AI boundary, database, Windows and disposable Supabase integration with every returned step successful. Flutter format/analyze passed; full suite failed 4 lifecycle cases: three late-auth/logout cancellation races and one fixture double-login in `close-retries-failed-cleanup`. Downstream Flutter/Chrome/Web checks were skipped, not passes.
- Fix: reset `_cancelledOperation` synchronously inside `_runTracked` before publishing `_operation`; `_run` no longer resets it when the queued microtask starts. This preserves logout/close cancellation across the scheduling gap and lets the finalizer clean any late SDK session/refresh secret. Removed only the redundant second login from the close-retry fixture; no assertions were relaxed and no retry loop added.
- Paths: `apps/flutter_app/lib/features/auth/data/persistent_account_access.dart`, `apps/flutter_app/test/features/srs/session_lifecycle_fixtures.dart`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, this status file. No Auth strategy/provider, API/schema/RLS, default runtime, Pro-owned #14/#38/N4, deployment or security gate change.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. Require all six exact-head CI jobs and every step, including complete Flutter suite, Chrome/Web and Windows/Supabase, before claiming the correction verified.
- Next: inspect exact-head CI; fix only observed regressions. Hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted expiry/restart and physical multi-device acceptance remain open; PR #37 stays Draft and #20/#22/#15/#18 remain open.


## Core worker handoff — caller-owned runtime restart restoration — 2026-11-07T17:16Z

- Run `core-20261107T1716Z-pr37-runtime-restart-restore`; branch `automation/issue-22-atomic-review`; parent HEAD `cb0c4d7ba5396940cc7eb7ae5e795dab2c188a56`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. The previous core checkpoint was RELEASED at 2026-11-07T12:18Z; this bounded step resumed after re-reading the PR marker, branch and comments.
- Added `caller-owned runtime restart restores saved refresh token before own profile` to the pinned-Supabase-SDK runtime suite. It signs in, closes the first caller-owned runtime without clearing a confirmed secret, creates a fresh SDK/runtime, verifies refresh-only startup from that secret, checks the rotated secret is written before the second own-profile request, and holds the profile response to prove study readiness remains closed.
- Paths: `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, `qa/matrix.json`, and this status file. No production Auth/provider/API/schema/RLS/default activation or Pro-owned N4 scope change.
- Cloud runtime has no Flutter/Dart SDK; local format/analyze/test/build are not available. Parent exact-head CI [42390645462](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42390645462) passed all six jobs/every step on `cb0c4d7`; it does not execute this new regression. The new exact-head CI must run formatter, analyze, full Flutter suite, Windows, disposable Supabase integration and Web build before this increment is verified.
- Limitation: TEST ONLY MockClient/in-memory vault with the caller-owned disposable journal; SDK/runtime reconstruction occurs in one test process. It is not native Credential Manager restoration, forced process/power-loss restart, hosted learner A/B, deployed RLS/PostgREST or physical multi-device proof. Next: inspect every latest-attempt job/step on the new exact HEAD and fix only observed failures.


## Exact-head CI observation — 2026-11-07T17:29Z

- New source commit: `6e734d0e0558055ba570396946622e69d11e76e8` on `automation/issue-22-atomic-review`. It adds the caller-owned runtime close/recreate refresh-restoration regression described above.
- Exact-source Actions [42396410812](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42396410812), attempt 1, targets this exact SHA and is `in_progress`. Latest-attempt snapshot: repo-sanity 12/12 SUCCESS; AI boundary 12/12 SUCCESS; database IN_PROGRESS at PostgreSQL client installation; Windows IN_PROGRESS at pinned Flutter SDK setup; disposable Supabase integration IN_PROGRESS at service startup; Flutter job not yet published. All later steps are pending/unpublished, not passes.
- No new-source Flutter format/analyze/test, Windows bridge, local Supabase integration or Web build result is claimed yet. The parent `cb0c4d7` CI is historical evidence only.
- Worker released with code and docs persisted. Next run: inspect the newest exact-head attempt and every job/step; correct only observed failures. Keep PR #37 Draft and #20/#22/#15 open; hosted signed-JWT learner A/B, deployed RLS/PostgREST, physical restart/expiry and multi-device acceptance remain outstanding.


## Core worker checkpoint — Windows refresh rotation write failure — 2026-11-07T21:35Z

- Run `core-20261107T2135Z-windows-refresh-write-failure`; branch `automation/issue-22-atomic-review`; parent HEAD `259a0b39f0f27a8d7ccf691a1b87ea5ce3d0fca0`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Added a pinned-Supabase-SDK + Windows MethodChannel regression: after User A is ready, an explicit refresh rotates its refresh token but the vault write fails. The test requires immediate session/profile revocation, cleanup of the uncertain secret, no extra profile request, then explicit cleanup before User B password Auth, B token persistence and B profile readiness.
- Paths: `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`, `qa/matrix.json`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, `docs/PROJECT_STATUS.md`. QA anchor remains in the existing automated `persistent-session-lifecycle` case; no new release status is inferred.
- Cloud authoring runtime has no Flutter/Dart SDK; local format/analyze/Flutter tests/Web/Windows builds were not run. Exact-head GitHub Actions is the executable gate; its result will be recorded after observation. No production Auth/provider/API/schema/RLS/default activation, Pro-owned N4 scope, deployment, merge or release change.
- Limitation: this is TEST ONLY pinned SDK + MockClient + mocked Windows MethodChannel, not native Credential Manager failure injection or hosted learner A/B. PR #37 stays Draft; #20/#22/#15/#18 remain open. Next: inspect every latest-attempt exact-head job and step; fix only observed failures.


## PR #37 pinned formatter diagnostic — 2026-11-07T22:09Z

- Resumed the RELEASED core lane on `automation/issue-22-atomic-review`, source HEAD `366315107f098d9e9905a33408dbff7488a9a78d`, base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. Full recursive source tree was fetched from GitHub and is untruncated at 334 entries.
- Exact-head CI [42416880862](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42416880862), attempt 1, targets `366315107f098d9e9905a33408dbff7488a9a78d`. Five jobs (repo-sanity, database, AI boundary, disposable Supabase integration, Windows) completed with every step SUCCESS. Flutter strict formatter failed only because it would change `test/features/srs/windows_persistent_supabase_runtime_test.dart`; Analyze, full Flutter tests and downstream Flutter steps were SKIPPED, not passes.
- Added a temporary read-only diagnostic step to `.github/workflows/ci.yml`, scoped to PR #37, which emits the pinned Dart formatter diff without modifying the checkout. The existing strict formatter gate remains unchanged. No test assertion, runtime behavior, Auth/provider strategy, schema/RLS, default activation, security, N4 content or production setting changed.
- This commit triggers exact-head Actions; no formatter/analyze/test/build result is claimed until its latest attempt and every step are inspected. Cloud authoring runtime has no Dart/Flutter SDK.
- Next: retrieve the diagnostic diff, apply only its formatting hunk to the test file, remove the temporary workflow step, update this handoff with the correction and rerun all exact-head CI. Keep PR #37 Draft and #20/#22/#15/#18 open; hosted signed-JWT learner A/B, deployed RLS/PostgREST, hosted expiry/restart and physical multi-device evidence remain outstanding.


## Core worker checkpoint — PR #37 pinned formatter repair — 2026-11-07T23:10Z

- Run `core-20261107T2310Z-pr37-formatter-repair`; sole core writer on `automation/issue-22-atomic-review`. Parent/expected HEAD `9ec16d52517ac62d042cff9a3488d74126e31c5e`; base `main` `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`; parent tree `742e72dcce6a18c66ee9a29a3a42cc9c98cfe0d1` (recursive read complete: 334 entries, untruncated).
- Exact-head Actions [42419564491](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42419564491), attempt 1, completed FAILURE only at the strict pinned Dart formatter. Its read-only diagnostic showed exactly two line-wrap changes in `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`. Repo-sanity, database, AI boundary, Windows and disposable Supabase integration completed SUCCESS with all returned steps; Flutter analyze and every later Flutter test/build step were SKIPPED, not passes.
- Applied only those two formatter hunks; no test assertions/behavior changed. Removed the temporary PR37-only read-only diagnostic from `.github/workflows/ci.yml`; the strict `dart format --output=none --set-exit-if-changed .` gate remains unchanged.
- Paths: `.github/workflows/ci.yml`, `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`, `docs/PROJECT_STATUS.md`. No production Auth/vault, provider/API/schema/RLS/default activation, Pro-owned N4, deployment, merge or release change.
- Cloud authoring runtime lacks Flutter/Dart SDK; local format/analyze/test/build were not run. New exact-head CI is the executable verification. Next: inspect its latest attempt and every job/step; if it is pending, hand off without another source commit; if it fails, fix only observed failures. PR #37 remains Draft and #20/#22/#15/#18 remain open; hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted expiry/restart and physical multi-device evidence remain outstanding.


## Exact-head CI verification — PR #37 session lifecycle — 2026-11-08T00:14Z

- Branch `automation/issue-22-atomic-review`; exact source HEAD `1bb54e26c220badf50f603c72470711bbb030496`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- GitHub Actions [run 42424220410](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42424220410), attempt 1, completed SUCCESS on this exact HEAD. Fetched latest-attempt job collection contains all six jobs — `ai-boundary`, `repo-sanity`, `database`, `windows`, `supabase-integration`, and `flutter` — all `completed/success`; every returned step is `completed/success` (101/101 steps). No job or step is skipped, pending, or failed.
- Flutter evidence on this exact head includes pinned Dart format, `flutter analyze`, the complete serial Flutter suite, owned persistent-session/vault/profile lifecycle probes, actual Chrome IndexedDB/reload checks, typed SRS/review/Kanji wire verifiers, and Web release build. Windows includes release build and cross-process Credential Manager/journal probes. Disposable local Supabase includes GoTrue/PostgREST refresh rotation, replay and A/B RLS checks. These are CI/component tests, not hosted learner proof.
- Separate review of commit `1bb54e26c220badf50f603c72470711bbb030496` against parent `9ec16d52517ac62d042cff9a3488d74126e31c5e` found exactly three paths: removal of the temporary formatter diagnostic while retaining the strict formatter gate, two pinned-Dart line-wrap corrections in the Windows runtime test, and this status document. No assertion/runtime behavior changed in the formatter repair.
- Cloud authoring runtime has no Dart/Flutter SDK; no local format/analyze/test/build is claimed. Hosted signed-JWT learner A/B, deployed hosted PostgREST/RLS, hosted expiry/restart, native interactive learner startup and physical multi-device sync remain unverified. The manual hosted-acceptance workflow is not on default branch and no staging environment/secrets were inspected or requested.
- PR #37 remains Draft; #20/#22/#15/#18 remain open. Do not merge/close from component CI alone. Next: proceed to the existing released app/plan/quiz lane only after this checkpoint is released; keep hosted gates explicit and preserve Pro-owned #14/#38/N4 scope.


## Core worker checkpoint — in-flight refresh/account switch scheduler regression — 2026-11-08T02:35Z

- Branch `automation/issue-22-atomic-review`; source parent `c80640a015e080ec2753ab1e34d17ddbc55a7857`; PR #37 remains Draft. Run marker `core-20261108T0234Z-pr37-refresh-inflight-account-switch` was recorded in PR conversation comment #6716257845 before implementation. The prior marker was older than 90 minutes and PR #41's latest worker checkpoint was RELEASED.
- Added the deterministic regression `in-flight A refresh completion schedules B without reusing A lease` in `apps/flutter_app/test/features/srs/session_refresh_scheduler_test.dart`. It holds A's refresh, switches the current lease to B, verifies B is scheduled only after A settles, delivers a stale queued A callback, and proves B still refreshes exactly once at its own due time.
- Updated the `owned-session-refresh` QA anchor and `docs/PERSISTENT_SESSION_LIFECYCLE.md` to record the in-flight account-switch scheduling guarantee. No production Auth/session/vault code, Auth strategy/provider, API/schema/RLS, default activation, Pro-owned N4, deployment, merge or release behavior changed.
- Cloud authoring runtime has no Flutter/Dart SDK; local format/analyze/test/build were not run. Parent exact-head CI on `c80640a015e080ec2753ab1e34d17ddbc55a7857` was observed completed SUCCESS in run [42429127305](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42429127305), all six jobs and every listed step successful. That is parent baseline only; the new regression requires exact-head CI after this commit and is not yet counted as passing.
- Next: inspect all jobs/steps for the new exact-head Actions run. Keep #20/#22/#15/#18 open until hosted signed-JWT A/B, deployed PostgREST/RLS, learner expiry/restart and two-client evidence are observed. No N4 Pro scope was changed.



## Exact-head formatter repair — PR #37 — 2026-11-08T04:08Z

- Branch `automation/issue-22-atomic-review`; parent/expected HEAD `81a02db0e14a77e71472e4bdfd3dc8726557ed0a`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head Actions [run 42439420758](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42439420758), attempt 1, targets this HEAD and completed FAILURE. The Flutter job failed only at `dart format --output=none --set-exit-if-changed .`; the pinned Dart 3.35.4 log identified `test/features/srs/session_refresh_scheduler_test.dart` as the sole changed file. Flutter Analyze, the full Flutter suite, lifecycle/vault/profile probes, Chrome checks and Web build were SKIPPED downstream and are not passing evidence.
- All other exact-head jobs completed SUCCESS with every returned step successful: repo-sanity 12/12, AI boundary 12/12, database 12/12, Windows 17/17, disposable Supabase integration 13/13. The complete run contains six jobs; Flutter has 35 steps including skipped downstream steps.
- Applied the one formatter-only change: removed the extra blank line before the final closing brace in `apps/flutter_app/test/features/srs/session_refresh_scheduler_test.dart`. No assertions, test logic, production code, workflow gates, Auth/provider/API/schema/RLS, or N4 content changed.
- Cloud authoring runtime has no Dart/Flutter SDK; local format/analyze/test/build were not run. A fresh exact-head Actions run is required to execute the previously skipped Flutter checks and prove this regression.
- PR #37 remains Draft; #20/#22/#15/#18 remain open. Hosted signed-JWT learner A/B, deployed hosted PostgREST/RLS, hosted expiry/restart and physical multi-device evidence remain unverified. No staging secrets were read or requested. Next: inspect all jobs and steps on the new exact HEAD; only then continue the remaining Auth/atomic-review acceptance. Pro-owned #14/#38/N4 scope remains untouched.


## Corrupt stored refresh cleanup on caller close — 2026-11-08T05:15Z

- Run `core-20261108T0509Z-pr37-corrupt-vault-close-recovery`; branch `automation/issue-22-atomic-review`; parent/expected HEAD `a0bbeca3a9cc909ac71fa75c3b294febedffe011`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. ACTIVE marker was recorded in PR #37 conversation before implementation.
- Startup now distinguishes a known corrupt stored refresh value from a transient vault read-unavailable error. Corrupt values set cleanup-required; caller close retries SDK sign-out plus exact-project vault clear and does not release the exclusive owner after a failed clear. Transient read failures remain non-destructive/retryable.
- Added regression `SDK close retries corrupt stored refresh cleanup before releasing owner`: no Auth token/profile request on corrupt startup; first clear failure retains the secret and target owner; a successful close retry clears it before owner release.
- Changed exactly five paths: `persistent_account_access.dart`, `persistent_supabase_runtime_test.dart`, `qa/matrix.json`, `PERSISTENT_SESSION_LIFECYCLE.md`, and this status document. No Auth strategy/provider, API/schema/RLS, default activation, workflow gate, Pro-owned N4, deployment, merge or release changes.
- Parent exact-head CI [42445578429](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42445578429) completed success on `a0bbeca3a9cc909ac71fa75c3b294febedffe011`: all six jobs and every returned step succeeded (101/101). This new source head requires its own exact-head Actions run. Cloud authoring has no Flutter/Dart SDK; local format/analyze/test/build were not run.
- Hosted signed-JWT learner A/B, deployed hosted PostgREST/RLS, native Credential Manager failure injection, OS restart/expiry, and physical multi-device evidence remain unverified. Next: inspect every job/step on the new exact HEAD; preserve all assertions and keep PR #37 Draft.


## Windows per-project process-owner lease — 2026-11-08T07:09Z

- Run `core-20261108T0709Z-pr37-restore-lifecycle-review`; branch
  `automation/issue-22-atomic-review`; parent/expected HEAD
  `346c223f8ec60b55727da87906e9884dda0aff54`; base main
  `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Closed a documented lifecycle gap: the Dart owner set was isolate-local, so
  two Windows app processes could read the same OS-user refresh slot and race
  Supabase refresh-token rotation. The Windows runtime now acquires a
  target-derived named mutex before vault read/Auth restore and releases it only
  after caller-owned Auth/vault work and required cleanup drain. Busy acquisition
  fails with a fixed safe unavailable error; abandoned mutex recovery allows a
  later process to continue after an earlier process exits unexpectedly.
- Native probe adds real parent/child process contention and abandoned-mutex
  recovery using only PID-qualified `.invalid` TEST ONLY targets. Windows
  MethodChannel test verifies exact target-only acquire/release arguments and
  safe busy handling. Three additional pure lifecycle cases verify acquire-before-
  read ordering, busy-lease no-storage/no-Auth behavior, and retention of both
  local/native ownership after a failed release until close retry. Existing
  per-target Dart serialization and session/generation guards remain unchanged.
- Changed paths: `session_credential_vault.dart`,
  `persistent_account_access.dart`, `windows_session_credential_vault.dart`,
  `session_lifecycle_fixtures.dart`, Windows native vault header/implementation/
  MethodChannel, native process probe, Windows MethodChannel tests, QA matrix,
  session lifecycle/vault/QA docs,
  and this status file. No Auth strategy/provider, public grants, RLS, schema,
  default runtime activation, production configuration, N4 content, deployment,
  merge or release changes.
- Cloud authoring has no Flutter/Dart SDK or Windows native runtime. Local
  format/analyze/tests/build were not run; exact-head GitHub Actions must verify
  Dart formatting/analyze/full Flutter suite and Windows mutex/process probe.
- Limit: the mutex coordinates cooperating Nihongo Daily processes in one
  Windows logon session. Credential Manager remains accessible to arbitrary
  same-user software; this is not cross-device CAS, separate-session locking,
  hosted signed-JWT A/B, deployed PostgREST/RLS, or physical multi-device proof.
  Next: inspect exact-head CI on the committed tree, fix observed failures only,
  then continue the hosted Auth/atomic-review acceptance and PR #41 formatter
  correction in the next sequential core iteration.


## Exact-head formatter repair — Windows process-owner lease — 2026-11-08T07:32Z

- Run `core-20261108T0732Z-pr37-owner-lease-format-repair`; branch
  `automation/issue-22-atomic-review`; parent/expected HEAD
  `4c449b3ca2f222c6d04eb06321f727354675c569`; base main
  `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head Actions [run 42459039744](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42459039744)
  targets parent `4c449b3`. Repo-sanity, AI-boundary and database completed
  SUCCESS with every listed step successful. Flutter failed only at
  `dart format --output=none --set-exit-if-changed .`, which identified
  `test/features/srs/windows_session_credential_vault_test.dart` as the sole
  changed file. Flutter Analyze, all Flutter tests, lifecycle/vault/profile
  probes, Chrome checks and Web build were SKIPPED downstream. Windows and
  disposable Supabase jobs were still running at the handoff observation.
- Applied only the formatter's required multiline `test(` call layout in that
  one test file. No test assertion, behavior, native code, CI gate or security
  control changed. The formatter repair requires a fresh exact-head Actions run
  before any Flutter result is counted.
- Cloud authoring has no Dart/Flutter SDK or Windows native runtime; local
  format/analyze/test/build were not run. Keep PR #37 Draft and #20/#22/#15 open.
  Hosted signed-JWT A/B, deployed PostgREST/RLS, learner expiry/restart and
  physical multi-device evidence remain pending. Pro-owned N4 paths are untouched.
- Next: inspect all jobs/steps on the new exact HEAD; fix only observed failures.


## Exact-head Windows owner-lease capability and formatter repair — 2026-11-08T11:11Z

- Run `core-20261108T1111Z-pr37-owner-capability-and-format-repair`; branch
  `automation/issue-22-atomic-review`; parent/expected HEAD `b953c2aa376ec7e70cbf48408045e274b18a667f`; base main
  `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head Actions [42459240374](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42459240374)
  completed FAILURE on this parent. Repo-sanity, AI-boundary, database and
  disposable Supabase integration completed SUCCESS with all returned steps
  successful. Windows failed at compile because Dart did not promote the
  optional owner-lease capability to the unrelated interface type. Flutter
  failed only strict Dart 3.35.4 formatting in
  `windows_session_credential_vault_test.dart`; analyze, tests and Web checks
  were SKIPPED downstream, not passed.
- Fixed the two owner calls by checking the optional capability, then using an
  explicit nullable interface cast before dispatch. Backends without the
  optional lease capability still return without native calls. Applied only
  the formatter-required indentation/argument layout in the identified test;
  assertions and behavior are unchanged.
- Changed exactly:
  `apps/flutter_app/lib/features/auth/data/session_credential_vault.dart`,
  `apps/flutter_app/test/features/srs/windows_session_credential_vault_test.dart`,
  and `docs/PROJECT_STATUS.md`. No QA anchor, production Auth strategy/provider,
  schema/RLS, default runtime activation, workflow gate, Pro N4 content,
  deployment, merge or release change.
- Full parent tree was read recursively before the write: 334 entries / 269
  blobs; all unrelated paths remain represented by the exact base tree. The
  new exact-head Actions run must verify formatter, analyze, full Flutter tests,
  Windows build/process probes and disposable Supabase integration. Cloud
  authoring runtime has Git but no Dart/Flutter SDK, so local format/analyze/test/
  build were not run.
- Next: inspect every latest-attempt job and step for the new exact HEAD; fix
  only observed failures. Keep PR #37 Draft and #20/#22/#15 open. Hosted
  signed-JWT learner A/B, deployed PostgREST/RLS, native Credential Manager
  failure injection, learner expiry/restart and physical multi-device evidence
  remain unverified. Pro-owned #14/#38/N4 scope remains untouched.


## Read-only formatter diagnostic — 2026-11-08T11:21Z

- Exact-head Actions [42475005316](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42475005316)
  targets `c7a6612d7730c00d7122e311f05f16fd46d244ad`. Database,
  AI-boundary, repo-sanity and disposable Supabase integration completed
  SUCCESS with every returned step successful. Windows remained IN_PROGRESS
  at the TEST ONLY Dart-to-Windows vault bridge build. Flutter failed only
  strict Dart formatting in `windows_session_credential_vault_test.dart`;
  analyze, tests and Web checks were SKIPPED.
- The first manual formatter-only correction did not satisfy pinned Dart
  3.35.4. Added a read-only `dart format --output=show` + `diff` step for
  that single test file before the existing strict formatter gate. The
  diagnostic does not edit the checkout, and the strict gate is unchanged.
- This diagnostic-only increment changes exactly `.github/workflows/ci.yml`
  and `docs/PROJECT_STATUS.md`. No tests/assertions, production source,
  Auth/provider, schema/RLS, security gate, or Pro-owned N4 path changes.
- Cloud authoring has Git but no Dart/Flutter SDK; local format/analyze/test/
  build were not run.
- Next: inspect the read-only diff on the diagnostic commit's exact-head CI,
  apply only the emitted formatter hunk, remove this temporary diagnostic step,
  and require a fresh full exact-head run. Keep PR #37 Draft and #20/#22/#15
  open; hosted signed-JWT learner A/B, deployed PostgREST/RLS and physical
  multi-device acceptance remain outstanding.


## Exact-head Windows vault formatter correction — 2026-11-08T12:16Z

- Diagnostic Actions [42475288513](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42475288513), attempt 1, targets exact HEAD `1e801602775697d19768851004c292c35558dedf` and completed FAILURE only in the Flutter job's strict Dart 3.35.4 formatter step. `ai-boundary`, `database`, `repo-sanity`, `windows`, and `supabase-integration` all completed SUCCESS with every returned step successful. Flutter Analyze, the full Flutter suite, lifecycle/vault/profile checks, Chrome checks and Web build were SKIPPED downstream; they are not passing evidence.
- The read-only formatter output identified exactly one TEST ONLY file: `apps/flutter_app/test/features/srs/windows_session_credential_vault_test.dart`. Applied only the emitted Dart formatting hunk to the Windows owner-lease test declaration/expect layout; no assertion or behavior changed.
- Removed the temporary read-only formatter diagnostic from `.github/workflows/ci.yml`; the repository-wide strict formatter gate remains unchanged.
- Changed paths for this correction: `.github/workflows/ci.yml`, `apps/flutter_app/test/features/srs/windows_session_credential_vault_test.dart`, and `docs/PROJECT_STATUS.md`. No production Auth/provider strategy, schema/RLS, default activation, Pro-owned N4, or security/test gate changed.
- Cloud authoring runtime has GitHub access but no Dart/Flutter SDK, so local format/analyze/test/build were not run. A fresh exact-head Actions run must execute the formatter, analyzer, full Flutter suite, Windows native probes, disposable Supabase integration and Web build.
- Hosted signed-JWT learner A/B, deployed PostgREST/RLS, learner expiry/restart and physical multi-device evidence remain unverified. Keep PR #37 Draft and #20/#22/#15 open; no merge, deployment or release.
- Next: inspect every latest-attempt job and step for the new exact HEAD; if green, continue the remaining caller-owned Auth/profile lifecycle acceptance without bypassing protected hosted gates.


## Windows runtime owner-lease fixture correction — 2026-11-08T13:12Z

- Exact-head Actions [42479903434](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42479903434) targets `84562cf2d7cbf79c9819522909ae2576b6ce1c85`. Repository sanity, database, AI boundary, Windows and disposable Supabase integration completed SUCCESS with every returned step successful. Flutter formatter and analyzer passed; the complete Flutter suite failed with 12 errors in `windows_persistent_supabase_runtime_test.dart`.
- Root cause: the TEST ONLY Windows MethodChannel mock handled `read`, `write` and `clear`, but omitted the new native `acquireOwner` / `releaseOwner` calls. The production owner lease therefore failed closed before any mocked vault read; downstream Flutter lifecycle, native-projection and Web checks were skipped.
- Corrected only the test harness: model successful owner acquire/release, assert acquire precedes the vault read, assert close releases the owner, and extend the failed-clear close regression to prove the owner remains held until a successful clear. Added a `persistent-session-lifecycle` QA anchor. No production source, Auth/provider, API/schema/RLS, default activation, CI gate or Pro-owned N4 content changed.
- Changed paths: `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`, `qa/matrix.json`, and `docs/PROJECT_STATUS.md`. Cloud authoring has no Dart/Flutter SDK; local format/analyze/test/build were not run. Fresh exact-head Actions must verify the full Flutter suite, Windows process probes and Web build.
- Hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted expiry/restart and physical multi-device acceptance remain outstanding. Keep PR #37 Draft and #20/#22/#15 open; do not treat local disposable Supabase or TEST ONLY MethodChannel evidence as hosted learner proof.
- Next: inspect every latest-attempt job and step for the corrected exact HEAD; fix only observed failures.


## Windows process restore profile-readiness barrier — 2026-11-08T15:10Z

- Run `core-20261108T1510Z-pr37-windows-restore-profile-barrier`; branch
  `automation/issue-22-atomic-review`; parent/expected HEAD
  `a22424a6dbc878da80927ef70cd50c14d59e2009`; base main
  `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Parent exact-head Actions [42484377224](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42484377224)
  was re-read: all six jobs (repo-sanity, ai-boundary, database,
  supabase-integration, windows, flutter) completed SUCCESS and every returned
  step completed SUCCESS on the exact parent SHA. This is parent evidence only.
- Added TEST ONLY `runtime-restore-profile-held` to the real Windows runner
  process sequence. A prior fresh process signs in and writes a synthetic
  refresh secret to Windows Credential Manager. The next fresh process restores
  only from that saved secret through the pinned SDK; its test HTTP response
  rotates the secret, and the own-profile handler checks the rotated value in
  the real OS vault before holding the profile response. While held, the
  account's `readyRuntime` must remain null/not ready. Releasing the profile
  permits readiness; clean close must preserve the confirmed rotated secret
  for the next process.
- Changed exactly six paths: `apps/flutter_app/tool/windows_runtime_fixture.dart`,
  `apps/flutter_app/tool/verify_windows_vault_bridge.ps1`,
  `docs/PERSISTENT_SESSION_LIFECYCLE.md`, `docs/WINDOWS_SESSION_VAULT.md`,
  `qa/matrix.json`, and this status file.
  No production Auth/provider, schema/RLS/grants, default runtime activation,
  CI gate/assertion, Pro-owned #14/#38/N4 source/content, deployment, merge or
  release change.
- Cloud authoring has no Flutter/Dart SDK or Windows OS; local format/analyze/
  Flutter test/native probe/build were not run. The parent CI is not evidence
  for this new fixture. New exact-head CI must execute the pinned formatter,
  full Flutter suite and Windows process probe before this increment is
  considered verified.
- Limitation: the process boundary and Windows Credential Manager are real in
  CI, but Auth HTTP/JWT and own-profile response are TEST ONLY MockClient
  fixtures. This is not hosted signed-JWT A/B, deployed PostgREST/RLS, real
  learner login, OS logoff/power-loss or physical multi-device acceptance.
- Next: inspect every latest-attempt job and step on the new exact HEAD; fix
  only observed failures. Keep PR #37 Draft and #20/#22/#15 open; Pro-owned
  #14/#38/N4 scope remains untouched.


## Windows process restore fixture analyzer repair — 2026-11-08T16:14Z

- Exact-head Actions [42494183095](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42494183095), attempt 1, targets `d42fd6518366913d32a86872a6c43ec00d086712` and completed FAILURE. The Windows bridge build failed because `waitForReady` was undefined in `tool/windows_runtime_fixture.dart:289`. Flutter formatting passed, but `flutter analyze` reported the same undefined helper and three unnecessary null assertions at lines 288, 395 and 396. The remaining four jobs completed SUCCESS; Windows process probes and downstream Flutter tests/build were skipped.
- Corrected only the TEST ONLY process fixture: reuse its existing bounded `ready()` helper after releasing the held own-profile response, and remove the three analyzer-proven redundant null assertions. The profile-held phase, refresh rotation, vault-before-profile checks, readiness assertions and cleanup behavior are unchanged.
- Changed exactly `apps/flutter_app/tool/windows_runtime_fixture.dart` and this status file. No production Auth/provider/API/schema/RLS/default activation, CI gate, Pro-owned N4 path, deployment, merge or release change.
- Cloud authoring has no Dart/Flutter SDK or Windows OS; local format/analyze/test/build were not run. New exact-head Actions must execute formatter, analyzer, complete Flutter suite, Windows bridge/process probes and Web build before this repair is considered verified.
- TEST ONLY Auth HTTP/JWT/profile fixtures remain synthetic; real Windows Credential Manager/process execution in CI is not hosted signed-JWT learner A/B or deployed PostgREST/RLS. Hosted learner A/B, expiry/restart and physical multi-device acceptance remain outstanding. Keep PR #37 Draft and #20/#22/#15 open.
- Next: inspect every latest-attempt job and step on the new exact HEAD; fix only observed failures.


## Windows native owner-release retry regression — 2026-11-08T17:10Z

- Re-read latest main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`, PR #37 head
  `2c08c0bc15ff74eca5d95c2a254a78c9c7fc472c`, and exact-head Actions
  [42499388888](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42499388888).
  The run completed SUCCESS: all six jobs and every returned step completed
  SUCCESS, including Windows process/vault probes, Flutter formatter/analyze/full
  suite, Chrome IndexedDB, Web release, SQL/RLS and disposable Supabase A/B.
  This is automated disposable/fixture evidence, not hosted learner acceptance.
- Added a TEST ONLY Windows MethodChannel regression for failed native
  `releaseOwner`: the runtime close returns a fixed redacted error, keeps the
  exclusive target owner, rejects a competing runtime, then succeeds on explicit
  close retry after storage-channel recovery. A replacement runtime can acquire
  and release the target afterward; no Auth/profile request is dispatched.
- Changed exactly: `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`,
  `qa/matrix.json`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, and this status file.
  No production Auth/provider/API/schema/RLS/default activation, CI gate, or
  Pro-owned #14/#38/N4 content changed.
- Cloud authoring has no Dart/Flutter SDK or Windows OS; local format/analyze/test/
  build/native execution was not run. New exact-head Actions must run the
  formatter, analyzer, full Flutter suite, Windows native/process probes and Web
  build before this increment is considered verified.
- Hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted expiry/restart,
  and physical multi-device acceptance remain outstanding. PR #37 stays Draft;
  #20/#22/#15 remain open.
- Next: inspect every latest-attempt job and step on the new exact HEAD. Fix only
  observed failures; if only CI remains pending, hand off without another source
  commit. After this component check, continue the hosted #20/#22 acceptance
  path without changing Auth strategy/provider or requesting secrets in chat.


## Exact-head formatter repair — 2026-11-08T19:09Z

- Re-read main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`, PR #37/branch HEAD
  `ec4f776d0625c68bc6d25fa2ee819cfaafee3a0f`, and exact-head Actions [42508908153](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42508908153).
  Latest attempt 1 completed with five jobs and every returned step successful:
  repo-sanity, ai-boundary, database, disposable Supabase integration and Windows.
  Flutter failed only the strict pinned Dart 3.35.4 formatter in
  `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`;
  formatter diagnostics identified one test block. Flutter analyze, full tests,
  downstream probes and Web build were skipped, not passed.
- Applied only the formatter's exact layout to the final TEST ONLY owner-release
  retry case; assertion expressions, order, test behavior and coverage remain
  unchanged. Removed the temporary read-only formatter diagnostic from
  `.github/workflows/ci.yml`; the strict formatter gate remains untouched.
- Changed exactly `.github/workflows/ci.yml`,
  `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`,
  and `docs/PROJECT_STATUS.md`. No production Auth/provider/API/schema/RLS,
  default activation, security gate, Pro-owned #14/#38/N4 content, deployment,
  merge or release change.
- Cloud authoring has no Dart/Flutter SDK or Windows OS, so local format/analyze/
  test/build/native execution was not run. The new exact-head Actions run must
  verify strict formatting, analyze, full Flutter suite, Windows process/vault
  probes, disposable Supabase integration and Web build before this increment
  is considered verified.
- Hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted expiry/restart
  and physical multi-device acceptance remain outstanding. PR #37 stays Draft;
  #20/#22/#15 remain open.
- Next: inspect every latest-attempt job and step on the new exact HEAD; fix only
  observed failures. If only CI remains pending, hand off without another source
  commit. Preserve Auth strategy/provider and do not request secrets in chat.


## Exact-head formatter follow-up — 2026-11-08T20:13Z

- Re-read main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`, PR #37 and branch `automation/issue-22-atomic-review` at exact HEAD `7a112b30e469ee61f3f1cab21aa9de03cc8a8a95`; the previous core worker was RELEASED at 2026-11-08T19:16Z. The PR body is beyond GitHub's practical body-size limit, so the run marker/heartbeat is recorded as a PR conversation comment.
- Exact-head Actions [42514160409](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42514160409), attempt 1, targets this exact HEAD and completed FAILURE. Latest-attempt jobs: `repo-sanity`, `ai-boundary`, `database`, `supabase-integration` and `windows` completed SUCCESS with their returned steps successful; `flutter` failed only at strict Dart 3.35.4 formatting of `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`. Flutter Analyze, full tests, downstream lifecycle/native checks and Web build were SKIPPED, not passed.
- The earlier read-only diagnostic on parent `ec4f776d0625c68bc6d25fa2ee819cfaafee3a0f` emitted one formatter hunk and that hunk was applied in `7a112b30e469ee61f3f1cab21aa9de03cc8a8a95`; the new exact-head run still reports the same file as changed. Do not assume the earlier hunk was sufficient. Added a temporary read-only pinned-formatter diff and SHA diagnostic immediately before the unchanged strict gate so the next exact-head run exposes the remaining difference.
- Changed paths: `.github/workflows/ci.yml` (temporary read-only diagnostic only; strict format gate unchanged) and this status file. No test assertion/source behavior, Auth/provider, API/schema/RLS, default activation, Pro-owned #14/#38/N4 content, deployment, merge or release change.
- Cloud authoring has no Dart/Flutter SDK or Windows OS; local format/analyze/test/build were not run. New exact-head Actions must provide the diagnostic output; analyze/full tests/native probes/Web build remain unverified until the formatter passes.
- Hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted expiry/restart and physical multi-device acceptance remain outstanding. PR #37 stays Draft; #20/#22/#15 remain open.
- Next: inspect the new run's diagnostic diff and hashes on its exact HEAD; apply only the emitted formatter output, remove this temporary step, then require a fresh full six-job exact-head run. Preserve Pro-owned N4 scope and all security gates.


## Exact-head Dart formatter correction — 2026-11-08T21:08Z

- Re-read latest main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`, PR #37 and branch `automation/issue-22-atomic-review` at exact HEAD `51b65133cd1aa4c5fcfd972ce3591c29ad8b68e9`; the previous core worker was RELEASED at 2026-11-08T20:14Z. A new ACTIVE run marker was posted as PR conversation comment because the existing PR body is 261 KB and cannot safely be rewritten without losing historical handoffs.
- Exact-head GitHub Actions [42519337139](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42519337139), attempt 1, completed FAILURE. Latest-attempt jobs: `repo-sanity`, `database`, `ai-boundary`, `supabase-integration` and `windows` completed SUCCESS with every returned step successful; `flutter` failed only at the strict Dart 3.35.4 formatter. Its read-only diagnostic reports one remaining extra blank line immediately before the final closing brace in `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart` (diagnostic SHA-256: source `dc2d93813d84f2dfc47659aa6cee30917f5849c1d526580cad8a2420d1a8b340`, formatted `a6529cf166f452b7bf75e416963f6a925fe2693636fd1c4768a88fe80f3ab45f`). Flutter Analyze, the complete Flutter suite, downstream lifecycle/native checks and Web build were SKIPPED, not passes.
- Applied only the formatter-reported final blank-line removal in that TEST ONLY file and removed the temporary read-only diagnostic from `.github/workflows/ci.yml`; the strict formatter gate remains unchanged. No assertion, test case, behavior, production Auth/provider/API/schema/RLS/default activation or security gate changed.
- Changed exactly `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`, `.github/workflows/ci.yml`, and this status file. Pro-owned #14/#38/N4 paths remain untouched. No merge, deployment, migration, release or issue closure.
- The cloud authoring runtime has no Dart/Flutter SDK or Windows OS, so local format/analyze/test/build/native execution was not run. A new exact-head Actions run must complete all six jobs and every required step before this correction is considered verified.
- Hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted expiry/restart and physical multi-device acceptance remain outstanding. PR #37 stays Draft; #20/#22/#15 remain open.
- Next: inspect the complete latest-attempt jobs/steps for the new exact HEAD; fix only observed failures. If only CI remains pending, release the worker without another source commit or long polling. Preserve the existing Auth strategy/provider and do not request secrets in chat.


## Windows owner-release test analyzer repair — 2026-11-08T22:10Z

- Resumed PR #37 on `automation/issue-22-atomic-review` from exact parent HEAD `3234e011e330696d704813526b00ac36335c673e`; latest main remains `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. Previous PR #37 worker was RELEASED at 2026-11-08T21:12Z; PR #41's latest worker was RELEASED at 2026-11-08T06:22Z. No overlapping active core worker was observed. Pro-owned Issue #14 / PR #38 / N4 paths remain excluded.
- Exact-head Actions [42523963068](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42523963068), attempt 1, targets parent `3234e011e330696d704813526b00ac36335c673e` and completed FAILURE only in Flutter Analyze: four `undefined_identifier` diagnostics for `vault` in `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart` at lines 1105, 1129, 1150 and 1175. Formatter succeeded. The other five jobs and every returned step succeeded; Flutter tests, downstream lifecycle/native/browser checks and Web build were skipped after Analyze failed.
- TEST ONLY repair: declare one shared `SessionCredentialVault` fixture, create it in `setUp`, and pass that same instance to the initial owned runtime. The owner-release retry test now replaces the fixture only after the prior runtime successfully releases ownership, then passes the replacement to the next runtime. Existing assertions, failure ordering, redaction checks and test semantics are preserved; no production code changed.
- Changed exactly `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart` and `docs/PROJECT_STATUS.md`. The complete parent tree contains 334 entries (269 blobs / 65 trees), untruncated. The next exact-head CI must verify analyzer, full Flutter suite, Windows bridge/process probes, disposable Supabase integration and Web build; no local Dart/Flutter SDK or Windows OS is available in this cloud runtime.
- Hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted expiry/restart and physical multi-device acceptance remain outstanding. PR #37 remains Draft; #20/#22/#15 remain open. No Auth strategy/provider, schema/RLS, default activation, Pro content, deployment, merge or release change.
- Next: inspect every latest-attempt job and step on the new exact HEAD; fix only observed failures. If CI is pending only, release the worker without a duplicate source commit or long polling.


## Exact-head Windows owner-release CI — 2026-11-08T23:09Z

- Re-read PR #37 branch `automation/issue-22-atomic-review` at exact source HEAD `b88e0c49722f0489ec98e3adb889deecc351eb94`; base `main` remains `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- GitHub Actions [42529122049](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42529122049), attempt 1, targets this exact HEAD and completed SUCCESS. All six latest-attempt jobs — `repo-sanity`, `database`, `ai-boundary`, `supabase-integration`, `windows`, and `flutter` — completed SUCCESS; every returned step in every job also completed SUCCESS. Flutter format, analyze, complete test suite, owned-session/vault/profile checks, Chrome IndexedDB/reload, native receipt/journal/recovery checks, SRS/review/Kanji wire checks and Web release build all ran successfully. Windows bridge, cross-process Credential Manager, staging build, release build and native journal checks all succeeded. Disposable local Supabase GoTrue/PostgREST A/B, rotation, replay and RLS checks succeeded.
- This is exact-head automated component/local-stack evidence only. It is not hosted learner evidence: protected `supabase-staging` configuration/two pre-provisioned users, hosted signed-JWT/PostgREST A/B, hosted expiry/restart and physical multi-device acceptance remain outstanding. PR #37 remains Draft; #20/#22/#15 remain open. No default Auth activation, production Auth/provider/API/schema/RLS change, deployment, merge or release.
- Cloud authoring runtime has no Dart/Flutter SDK or Windows OS, so local format/analyze/test/build/native execution was not run; the successful checks above are observed from this exact-head Actions run.
- Next: retain this passing component baseline; wait for the approved protected staging configuration and hosted proof before claiming #20/#22/#15 complete. Continue independent work without touching Pro-owned #14/#38/N4 scope.


## Ambiguous Windows credential-write completion guard — 2026-11-09T08:52Z

- Published source commit `e2de572b4b2dce508d5e22e237053078ddbd0333` on `automation/issue-22-atomic-review` (parent `49fb821a535589d8558499837f1eb4786bf7da69`); this status-only correction follows that source checkpoint.
- Re-read latest main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`, PR #37 branch `automation/issue-22-atomic-review` at parent HEAD `b17c7d152aca2a8d796276571d124a3004644d72`, and the full recursive parent tree (334 entries, untruncated; tree `042b5da9171b748a30f9f29ebac633e6e94c0f09`). Previous PR #37 checkpoint was RELEASED at 2026-11-09T01:14Z; no newer active core worker was observed.
- Rechecked exact-head Actions [42534249420](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42534249420), latest attempt 2 on `b17c7d152aca2a8d796276571d124a3004644d72`: all six jobs and all 101 returned steps completed SUCCESS, with no skipped/pending/failing step. This is component/local-stack evidence, not hosted learner proof.
- Added one TEST ONLY lifecycle scenario that simulates a refresh-token write committing before the backend reports failure, then forces the compensating clear and first caller-close clear to fail. It requires the accepted session to stay revoked, the uncertain token to remain inaccessible, both owner slots to stay held, and a later explicit close retry to clear before releasing ownership. Added the QA anchor and lifecycle explanation.
- Changed exactly `apps/flutter_app/test/features/srs/session_lifecycle_fixtures.dart`, `qa/matrix.json`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, and this status file. No production Auth/provider/API/schema/RLS/default activation, CI gate, Pro-owned #14/#38/N4 content, deployment, merge or release change.
- Cloud authoring runtime has no Dart/Flutter SDK or Windows OS; local format/analyze/test/build/native execution was not run. The new exact-head Actions run must verify the added fixture, strict Dart format/analyze, full Flutter suite, Windows native/process probes, disposable Supabase integration and Web build.
- Hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted expiry/restart and physical multi-device acceptance remain outstanding; protected `supabase-staging` credentials/two pre-provisioned non-production users are not available to this worker. PR #37 stays Draft; #20/#22/#15 remain open. Pro-owned #14/#38/N4 scope remains excluded.
- Next: inspect every latest-attempt job and step on the new exact HEAD. If CI passes, retain the component result and continue only with independently unblocked Personal Alpha work until the protected hosted configuration is supplied; do not claim hosted acceptance from fixtures.


## Standalone Windows vault fault-injection probe — 2026-11-09T11:14Z

- Run `core-20261109T1114Z-pr37-native-vault-fault-probe`; branch `automation/issue-22-atomic-review`; parent HEAD `390451468f588268a2e5e2a304aa534cd92fdaee`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Source commit `9c44a1180bc25fbed7852cf33ff7629d03c2b819` adds one-shot TEST ONLY fault hooks compiled solely into `tool/windows_session_vault/session_vault_probe`. The packaged Flutter Windows runner does not define `NIHONGO_SESSION_VAULT_TEST_HOOKS`; production helper behavior is unchanged when the macro is absent.
- Native probe cases: read failure leaves the prior value readable on the next read; write-before-commit leaves the old value unchanged and the next write succeeds; ambiguous write performs actual `CredWriteW` then returns unavailable while the new value is observable; clear failure leaves the value readable and an explicit retry clears it to absent. All values/scopes remain synthetic and PID-qualified `.invalid`.
- Paths: `apps/flutter_app/windows/runner/session_credential_vault.h`, `apps/flutter_app/windows/runner/session_credential_vault.cpp`, `apps/flutter_app/tool/windows_session_vault/session_vault_probe.cpp`, `apps/flutter_app/tool/windows_session_vault/CMakeLists.txt`, `docs/WINDOWS_SESSION_VAULT.md`, `qa/matrix.json`, and this status file.
- Parent exact-head Actions [42589847532](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42589847532) targets `390451468f588268a2e5e2a304aa534cd92fdaee` and completed SUCCESS: all six jobs and all 101 returned steps completed SUCCESS with no skip/pending/failure. That is parent baseline evidence only; the new native fault cases still require exact-final-head Windows CI.
- The cloud authoring runtime has no Windows OS or Flutter/Dart SDK, so local native compile/run, format, analyze, Flutter tests and builds were not run. No new-head CI pass is claimed until the latest attempt and every job/step are inspected.
- Faults are deterministic helper-boundary injections, not spontaneous Windows API errors, power-loss, hosted signed-JWT/Auth, deployed PostgREST/RLS, physical learner restart or multi-device proof. No secrets, Auth/provider strategy, schema/RLS, default activation, packaged-runner hook, Pro-owned #14/#38/N4, deployment, merge or release changed.
- Next: inspect exact-final-head Actions and all latest-attempt jobs/steps; fix only observed failures. Keep PR #37 Draft and #20/#22/#15 open pending their full acceptance and protected staging evidence.


## Retryable Windows staging-owner shutdown — 2026-11-09T13:17Z

- Run `core-20261109T1317Z-pr37-retryable-staging-close`; branch `automation/issue-22-atomic-review`; parent HEAD `9692ca9fda21eb2699ee6c3a1cb46e1db49a078d`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Found a real cleanup retry defect in `_WindowsStagingOwner.close()`: its cached `_closing ??=` future remained failed forever when `session.close()` failed. `AccountStartupController` correctly retained the owner for retry, but the wrapper returned the same failed future and never retried SDK/vault cleanup; the journal could not safely progress to close.
- Added `RetryableAsyncClose`, a single-flight close gate that memoizes success but clears its in-flight future on failure. The staging owner now retries the same session close on an explicit later call and closes the journal only after session cleanup succeeds. Journal-close failures are retryable too.
- Added two TEST ONLY regressions for concurrent close coalescing, session-close failure/retry ordering, journal-close failure/retry and successful idempotent completion. Added the test anchor to the existing `windows-staging-bootstrap` QA case and documented the ownership order.
- Changed paths: `apps/flutter_app/lib/app/retryable_async_close.dart` (new), `apps/flutter_app/lib/app/staging_bootstrap.dart`, `apps/flutter_app/test/features/srs/staging_bootstrap_test.dart`, `qa/matrix.json`, `docs/STAGING_BOOTSTRAP.md`, and this file.
- Parent exact-head Actions [42608514755](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42608514755) completed SUCCESS on `9692ca9fda21eb2699ee6c3a1cb46e1db49a078d`: all six jobs and all 101 returned steps succeeded, including Windows native vault bridge/probe, Flutter format/analyze/full suite and Web build. That is parent baseline only; the new regression and final tree require new exact-head CI.
- Cloud authoring runtime has no Flutter/Dart SDK or Windows OS; local Dart format/analyze/Flutter tests/native execution were not run. No new-head CI pass is claimed until every latest-attempt job/step is inspected.
- No Auth/provider/API/schema/RLS/default activation, Pro-owned #14/#38/N4 content, deployment, merge or release changes. Hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted expiry/restart, physical multi-device and learner-journey acceptance remain outstanding. PR #37 stays Draft; #20/#22/#15/#18 remain open.
- Next: inspect the exact-final-head Actions run and every latest-attempt job/step; fix only observed failures, then continue independently unblocked Personal Alpha work without claiming hosted proof from fixtures.


## Core worker handoff — 2026-11-09 15:12 UTC

- PR #37 branch `automation/issue-22-atomic-review`; exact source HEAD `b2db0494ceffed6d4c8193ff154cbb7ab73d226b`; base main remains `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head Actions [42633586413](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42633586413), attempt 1, targets this HEAD. `repo-sanity`, `ai-boundary`, `database`, `windows` and `supabase-integration` completed SUCCESS with every returned step successful. Flutter failed only strict Dart 3.35.4 formatting for `test/features/srs/windows_persistent_supabase_runtime_test.dart`; analyze, tests, downstream probes and Web build were SKIPPED, not passes.
- The cloud authoring runtime has no pinned Dart/Flutter SDK. A temporary read-only CI diagnostic now formats only that TEST ONLY file, emits the exact Git diff, and restores the checkout before the unchanged strict formatter gate. This diagnostic is temporary and must be removed with the formatter-only correction.
- Next: inspect the diagnostic diff from the new exact-head Actions run; apply only those formatting hunks, remove the diagnostic step, then inspect every latest-attempt job/step. No production Auth/provider, API/schema/RLS, default activation, Pro-owned N4, deployment, merge or release change. Hosted learner A/B, deployed RLS, restart/expiry and multi-device proof remain outstanding.


## Core worker handoff — 2026-11-09 16:14 UTC

- PR #37 branch `automation/issue-22-atomic-review`; parent/exact diagnostic HEAD `55c08216c51aad6d2df7f780484fcccf6fa45cda`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head Actions [42643085807](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42643085807), attempt 1, targets `55c08216c51aad6d2df7f780484fcccf6fa45cda`. Repo-sanity, AI boundary, database, Windows and disposable Supabase integration completed SUCCESS with every returned step SUCCESS. Flutter failed only strict Dart 3.35.4 formatting; analyze, full tests, session/vault probes, Web build and artifact steps were SKIPPED, not passes.
- The read-only diagnostic emitted exactly one TEST ONLY formatter hunk in `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`: the redacted-owner-error predicate becomes a single line. Applied only that hunk; no assertion or behavior changed. Removed the temporary diagnostic from `.github/workflows/ci.yml`; the strict `dart format --output=none --set-exit-if-changed .` gate remains.
- Changed paths: the Windows runtime test above, `.github/workflows/ci.yml`, and this status file. No production/Auth/provider/API/schema/RLS/default activation, Pro-owned #14/#38/N4 content, deployment, merge or release change.
- Cloud authoring runtime lacks pinned Dart/Flutter SDK; local format/analyze/test/build were not run. The next exact-head Actions run must pass all six jobs and every required step; skipped/pending jobs are not passes. Hosted signed-JWT learner A/B, deployed PostgREST/RLS, actual learner restart/expiry, physical multi-device and full learner-journey evidence remain outstanding.
- Next: inspect every latest-attempt job/step on the new exact HEAD. If fully green, continue with the next unblocked Personal Alpha acceptance increment; otherwise fix only observed failures. PR #37 remains Draft; #20/#22/#15/#18 remain open.


## Late explicit refresh response after logout — 2026-11-09T22:15Z

- Run `core-20261109T2210Z-pr37-session-rotation-guards`; branch `automation/issue-22-atomic-review`; parent HEAD `b5505bbf5eb2a0aeb069c051aa3251435d46ac29`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Resume audit confirmed PR #37 remains Draft/open and its parent exact-head Actions [42653556067](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42653556067) completed all six jobs and all 101 returned steps SUCCESS. This is parent evidence only for the new regressions.
- Coverage gap: the existing suite separately exercised late startup restore, late password login, successful explicit rotation and rotation-write failure, but did not hold an explicit `refreshSession` response across caller logout and a blocked replacement account.
- Added TEST ONLY pure lifecycle scenario `logout-during-refresh`: User A refresh remains in flight; logout revokes and clears; replacement login is rejected while the captured operation remains owned; the late A response is drained/cleared; only then can B authenticate and persist B's secret.
- Added a pinned Supabase SDK/MockClient Windows-runtime regression for the same sequence, including no extra `ensure_profile` during the late A response, the exact password/refresh/password grant sequence, B's bearer identity, and clear-before-B-login / write-before-profile ordering.
- Changed paths: `apps/flutter_app/test/features/srs/session_lifecycle_fixtures.dart`, `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`, `qa/matrix.json`, and this file. No production Auth/provider, credential format, migration/RLS, default activation, Pro-owned #14/#38/N4, deployment, merge or release change.
- Local cloud authoring has no pinned Dart/Flutter SDK or Windows OS. Source/QA assertions were authored for the exact-head Flutter and Windows jobs; local Dart format/analyze/Flutter/native execution were not run. New-head CI is pending; no new test pass is claimed.
- Separate PR #41 issue remains: exact-head CI [42701255244](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42701255244) failed only the database job in the TEST ONLY daily-plan assertion because aggregate `count/min/max` also selects `b.max_ordinal` without grouping/aggregating it. PR #41 was not modified in this run. Next PR #41 repair: make the baseline relation an aggregate-safe scalar/subquery or include the baseline in a grouped aggregate, preserving the ordinal assertions; inspect exact-head CI afterward.
- Next on this branch: inspect all latest-attempt jobs/steps for the new exact HEAD. Keep PR #37 Draft and #20/#22/#15 open; hosted signed-JWT learner A/B, deployed PostgREST/RLS, physical Windows learner restart and multi-device acceptance remain unproven.


## Pinned Dart formatter diagnostic — 2026-11-09T23:09Z

- Run `core-20261109T2309Z-pr37-pinned-format-diagnostic`; branch `automation/issue-22-atomic-review`; parent/final diagnostic source before this checkpoint: `f37879b0a9d03090f32435729f92cf182893ee64`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head Actions [42710169884](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42710169884), attempt 1, targets this HEAD. Repository sanity, AI boundary, database, disposable local Supabase integration and Windows completed SUCCESS; Flutter failed only strict Dart 3.35.4 formatting. The formatter identified exactly `test/features/srs/session_lifecycle_fixtures.dart` and `test/features/srs/windows_persistent_supabase_runtime_test.dart`; Flutter analyze, complete tests and downstream probes/build were SKIPPED.
- Added a temporary diagnostic immediately before the unchanged strict formatter gate. It formats only those two TEST ONLY files, emits their exact diff, and restores both originals on exit. This diagnostic is temporary; the next correction must apply only the emitted formatter hunks and remove this workflow step.
- No test assertion, product/Auth/provider/schema/RLS/default activation, Pro-owned N4, deployment, merge or release behavior changed. Cloud authoring has no pinned Dart/Flutter SDK; local formatter/analyze/test/build were not run.
- Next: inspect the new exact-head CI log for the emitted formatter diff; apply only those changes, remove the temporary diagnostic, and inspect every latest-attempt job/step. Hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted restart/expiry and physical multi-device acceptance remain outstanding.


## Pinned Dart formatter repair — 2026-11-10T00:08Z

- Run `core-20261110T0008Z-pr37-pinned-dart-format-repair`; branch `automation/issue-22-atomic-review`; parent HEAD `84274d7e69a3cb961e1d55b6490b81c67d396972`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head Actions [42718449190](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42718449190), attempt 1, completed FAILURE only at the strict Dart 3.35.4 formatter. Repository sanity, AI boundary, Database/RLS, Windows and disposable Supabase integration completed SUCCESS with every returned step successful. Flutter's diagnostic formatted exactly two TEST ONLY files; analyze, full Flutter suite, downstream probes and Web build were SKIPPED, not passes.
- Applied only the two formatter hunks emitted by the pinned diagnostic in `apps/flutter_app/test/features/srs/session_lifecycle_fixtures.dart` and `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`. Removed the temporary read-only diagnostic from `.github/workflows/ci.yml`; the strict `dart format --output=none --set-exit-if-changed .` gate remains unchanged. No assertion or runtime behavior changed.
- Changed paths: those two TEST ONLY files, `.github/workflows/ci.yml`, and this status file. Cloud authoring runtime has no pinned Dart/Flutter SDK; local format/analyze/test/build were not run. New exact-head Actions is required before claiming verification.
- Hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted expiry/restart, physical multi-device and complete learner-journey acceptance remain outstanding. PR #37 stays Draft; #20/#22/#15 stay open. Pro-owned #14/#38/N4 remains excluded.
- Next: inspect every latest-attempt job and step on the new exact HEAD; fix only observed failures, then continue independent Personal Alpha work. No merge, Auth/provider, migration/RLS, default activation, deployment or release change.


## Browser IndexedDB corruption fail-closed regression — 2026-11-11T03:12Z

- Run `core-20261111T0312Z-pr37-indexeddb-corruption-guard`; branch `automation/issue-22-atomic-review`; parent source HEAD `60f7b062fe1511fe36575fe50ecdfb4f6fd0325e`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Re-read confirmed PR #37 remains Draft/open and no newer core writer was active. Parent exact-head Actions [42726727778](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42726727778) completed SUCCESS on `60f7b062fe1511fe36575fe50ecdfb4f6fd0325e`: all six jobs and all 101 returned steps succeeded, including Windows vault/process checks, Flutter format/analyze/full suite, actual Chrome IndexedDB transactions and page reload/second-tab persistence. This is parent evidence only for the new regression.
- Coverage gap: pure ledger fixtures rejected duplicate-key/corrupt canonical JSON, but the actual browser IndexedDB suite did not prove that a corrupted persisted value fails closed and remains byte-for-byte untouched.
- Added a TEST ONLY Chrome regression that seeds a real IndexedDB database, injects a duplicate-key canonical-state string through the browser API, requires `ReviewStorageFailure` on read, then reads the raw object-store value and proves it was not rewritten.
- Changed paths: `apps/flutter_app/test/features/srs/browser_review_store_check.dart`, `docs/BROWSER_REVIEW_STORE.md`, `docs/QA_SECURITY_MATRIX.md`, `qa/matrix.json`, and this file. The browser-store docs now describe seven actual IndexedDB tests; the QA inventory anchor points to the new named case.
- No production storage/Auth/provider/RPC/schema/RLS/default activation, Pro-owned #14/#38/N4, deployment, merge or release change. Browser Auth/RPC remain TEST ONLY; this is not hosted learner A/B, physical multi-device sync, quota/eviction or power-loss proof.
- Cloud authoring runtime has no pinned Flutter/Dart SDK or browser runtime; local format/analyze/Chrome tests/build were not run. The new test and full existing suite require exact-head GitHub Actions; no new-head pass is claimed.
- Next: inspect every latest-attempt job/step on the new exact HEAD, especially Flutter format/analyze/full tests and the actual Chrome IndexedDB/reload steps; fix only observed failures without weakening assertions. Keep #37 Draft and #20/#22/#15 open until hosted and two-client acceptance is observed.


## Browser IndexedDB test structure correction — 2026-11-11T03:12Z

- Separate post-write diff review of `a942dfa7dcbafcc4d6dde42100aa7317f20fdc5f` caught a misplaced closing delimiter around the new TEST ONLY test before its CI result was relied upon. Corrected the test insertion after the preceding test's complete closing call; no prior test body/assertion or production source changed.
- The first source commit's queued CI is not accepted as evidence for the corrected tree. The follow-up exact-head CI must run the formatter, analyzer, full Flutter suite, actual Chrome IndexedDB test and all remaining required jobs/steps.


## Pinned formatter diagnostic — browser IndexedDB regression — 2026-11-11T04:07Z

- Run `core-20261111T0407Z-pr37-pinned-format-repair`; branch `automation/issue-22-atomic-review`; diagnostic parent HEAD `c090dee54360db99109a0924f482cfc36942b59d`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head Actions [42952315959](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42952315959), attempt 1, targets the parent. Repo-sanity, database, AI boundary, disposable Supabase integration and Windows completed SUCCESS with all returned steps successful. Flutter failed only `dart format --output=none --set-exit-if-changed .`, reporting `test/features/srs/browser_review_store_check.dart`; analyze, complete Flutter suite, browser checks and Web build were SKIPPED, not passes.
- This commit adds a temporary read-only pinned Dart 3.35.4 formatter diagnostic for that TEST ONLY file. It backs up/restores the source in an EXIT trap and prints the exact unified diff before the unchanged strict formatter gate. No test assertions, production code, Auth/provider, RPC/schema/RLS or default runtime behavior changed.
- Changed paths in this diagnostic commit: `.github/workflows/ci.yml` and this status file only. The diagnostic run must be inspected for exact formatter output; then apply only that output, remove the temporary diagnostic, re-review the final diff and require complete exact-head CI.
- Cloud authoring runtime has no pinned Flutter/Dart SDK, so local format/analyze/test/build were not run. Pro-owned #14/#38/N4 remains excluded. PR #37 stays Draft; #20/#22/#15 stay open. No merge, deployment or release.

## Pinned formatter repair — browser IndexedDB regression — 2026-11-11T05:10Z

- Exact-head diagnostic Actions [42957426421](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42957426421), attempt 1, targets `01fbd4a17e736b55eb90d60047d467480a624409`. Database, AI boundary, repo-sanity, disposable Supabase integration and Windows completed SUCCESS with every returned step successful. Flutter failed only the strict Dart 3.35.4 formatter gate; analyzer, full Flutter suite, Chrome IndexedDB/reload checks and Web build were SKIPPED, not passes.
- The pinned read-only formatter output identified exactly two whitespace-only changes in `apps/flutter_app/test/features/srs/browser_review_store_check.dart`: remove the surplus blank line before the browser IndexedDB test helpers and the blank line before the final `main()` brace. Applied only those two hunks; test logic/assertions are unchanged.
- Removed the temporary formatter diagnostic from `.github/workflows/ci.yml`; the repository-wide `dart format --output=none --set-exit-if-changed .` gate remains unchanged.
- Changed paths in this repair commit: the TEST ONLY browser check above, `.github/workflows/ci.yml`, and this status file. Full post-write tree/diff review and exact-head CI are required before treating the new browser regression as verified.
- Cloud authoring runtime has no pinned Flutter/Dart/browser SDK; local format/analyze/test/build were not run. Hosted signed-JWT learner A/B, deployed PostgREST/RLS, physical Windows learner restart/expiry and two-device offline sync remain unproven. Pro-owned #14/#38/N4 remains excluded. PR #37 stays Draft; #20/#22/#15 stay open. No Auth strategy/provider, migration/RLS, default activation, deployment, merge or release change.
- Next: inspect every latest-attempt job and step on the repair commit; only after exact-head Flutter formatter/analyzer/full tests, Chrome IndexedDB/reload and Web/Windows jobs complete successfully should this regression be counted as verified.


## Real IndexedDB concurrent conflict and owner-key isolation — 2026-11-11T14:10Z

- Run `core-20261111T1410Z-pr37-indexeddb-concurrent-conflict`; branch `automation/issue-22-atomic-review`; parent HEAD `129046c1f0aa5a12c8a20e901616b9a941cecfed`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Revalidated parent exact-head Actions [42964303842](https://github.com/collab-TTAM/nihongo_daily/actions/runs/42964303842): six jobs / 101 steps all SUCCESS. PR #41 parent source `7a94956d8dc6d6ba2fa5cce260a31d8f08eaa57e` also has [43032386868](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43032386868) with five jobs / 114 steps all SUCCESS. These are parent baselines only.
- Added an eighth TEST ONLY real-Chrome IndexedDB case using two independent connections. It races two different payloads under one owner/event ID and requires exactly one immutable winner plus a typed `SYNC_CONFLICT`; it then stores the same event ID with different payloads for two owners and verifies each projection remains isolated. Existing seven Chrome cases/assertions remain unchanged.
- Updated `docs/BROWSER_REVIEW_STORE.md`, `docs/QA_SECURITY_MATRIX.md`, and the existing `browser-transactional-review` QA scope/anchor. No production storage/Auth/provider/RPC/schema/RLS/default activation, Pro-owned #14/#38/N4, dependency, workflow, deployment, merge or release change.
- Cloud authoring runtime has no pinned Dart/Flutter/browser SDK; local format/analyze/Chrome test/build were not run. The new case is authored but UNVERIFIED until exact-head Actions completes every required job/step. This is IndexedDB multi-connection evidence, not hosted signed-JWT learner A/B or physical two-device sync.
- Next: inspect all latest-attempt jobs/steps on the new exact HEAD; fix only actual formatter/analyzer/test failures while preserving all assertions. Keep #20/#22/#15 open and PR #37 Draft pending hosted A/B, deployed PostgREST/RLS, expiry/restart and real multi-device acceptance.


## Browser IndexedDB formatter repair — 2026-11-11T19:13Z

- Resumed PR #37 / `automation/issue-22-atomic-review` from exact parent `101e01b0401846d044d322fe19cfb82f0fda0e13` after the previous worker was RELEASED. Parent exact-head Actions [43075579598](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43075579598) passed database/RLS, repo-sanity, AI boundary, Windows and disposable local Supabase integration; Flutter failed only its strict Dart 3.9.2 formatter gate.
- The read-only pinned formatter output identified one exact formatting hunk in `apps/flutter_app/test/features/srs/browser_review_store_check.dart` (split the `a.list(fixture.owner)` argument across lines and collapse the following `singleWhere` closure). Applied that hunk only; all test logic/assertions remain unchanged.
- Removed the temporary read-only formatter diagnostic from `.github/workflows/ci.yml`; the repository-wide strict `dart format --output=none --set-exit-if-changed .` gate remains unchanged.
- Changed paths: the TEST ONLY browser check, CI workflow and this status file. This repair does not claim the new Chrome IndexedDB conflict/owner-isolation case passed; analyze, complete Flutter suite, Chrome IndexedDB/reload and Web build were skipped on the diagnostic parent.
- Cloud authoring runtime has no pinned Dart/Flutter/browser SDK; local format/analyze/test/build were not run. Require a new exact-head Actions run with every required job/critical step successful and no skipped Flutter checks before counting this regression as verified.
- No production Auth/session, storage, RPC/schema/RLS, default activation, dependency, Pro-owned #14/#38/N4, deployment, merge or release change. Hosted signed-JWT learner A/B, deployed PostgREST/RLS and physical multi-device sync remain unverified.
- Next: inspect all latest-attempt jobs and steps on the new exact HEAD; fix only observed failures while preserving all assertions and security gates. Keep PR #37 Draft and #20/#22/#15 open.


## IndexedDB explicit owner-key projection correction — 2026-11-11T22:12Z

- Resumed PR #37 / `automation/issue-22-atomic-review` at exact parent `fe4be738a9b9963702da6f14510c6464946a94f7`; base main remains `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. Previous source worker RELEASED at 19:16Z; the 20:11Z entry was read-only. The last observed #41 worker checkpoint is RELEASED; its earlier ACTIVE marker is older than 90 minutes and no newer heartbeat was found.
- Exact-head Actions [43085332862](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43085332862) targets this parent. Database, repo-sanity, AI boundary, Windows and disposable Supabase integration passed. Flutter strict format, analyze and the complete serial suite passed; the eighth Chrome IndexedDB test failed at an incorrect `a.list(fixture.other) == empty` expectation after a B-owned row had been staged.
- Corrected only the TEST ONLY browser check: both IndexedDB handles now assert the same filtered projection for each explicit owner key; each owner bucket has the expected rows, and the same event ID retains distinct per-owner `response_ms` values (123 and 125). Renamed the case to describe explicit owner-key projections, not connection isolation.
- Clarified `docs/BROWSER_REVIEW_STORE.md`, `docs/QA_SECURITY_MATRIX.md` and `qa/matrix.json`: `list(userId)` is local key-based partitioning; two handles to one origin/database are not separate Auth identities. Captured Auth and server RLS remain the authorization boundary.
- No production source, Auth/provider/RPC/schema/RLS/default activation, workflow, dependency or Pro-owned #14/#38/N4 content changed. Local Flutter/Dart/Chrome checks are unavailable in this cloud runtime; no local test/build pass is claimed.
- Next: inspect every job and critical step of the new exact-head Actions run, including Chrome IndexedDB, browser reload and Web/Windows builds. Keep PR #37 Draft and #20/#22/#15 open pending hosted signed-JWT A/B, deployed PostgREST/RLS, expiry/restart and real multi-device acceptance.

## Development handoff — out-of-band logout clear barrier — 2026-11-12 UTC

- Resume draft [PR #37](https://github.com/collab-TTAM/nihongo_daily/pull/37), branch `automation/issue-22-atomic-review`, based on main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. Source commits: `4277b0a562afd88fcb32e8ba45754bac567a5c00` and follow-up `f7deed71c40fc0e154eb015e37a8a89319d3cf67`.
- Fixed a lifecycle race where an out-of-band SDK null-session notification had queued an exact-project credential clear, but a replacement password login could pass the synchronous preflight before the clear was delivered. Persistence now counts queued null-session clears and rechecks failed/cleanup/pending/session state inside the reserved operation immediately before dispatching password Auth. A delayed clear or failed compensating clear therefore keeps User B blocked until explicit cleanup succeeds.
- Added TEST ONLY scenario `replacement-login-waits-for-out-of-band-session-clear` to `apps/flutter_app/test/features/srs/session_lifecycle_fixtures.dart`. It queues the SDK event before sign-in, holds the first clear, injects failure in both the queued and compensating clear, verifies no B password grant and retained A test secret, then recovers storage and verifies explicit clear -> B auth -> B rotated-secret write. The lifecycle fixture is included by `session_lifecycle_test.dart`; QA inventory remains 54 groups with an added exact anchor.
- Changed paths across the two source commits: `apps/flutter_app/lib/features/auth/data/persistent_account_access.dart`, `apps/flutter_app/test/features/srs/session_lifecycle_fixtures.dart`, `qa/matrix.json`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, `docs/QA_SECURITY_MATRIX.md`. This status entry is the sixth path. No path outside this bounded set changed; no Auth strategy/provider, API/schema/RLS/migration, default activation, Pro-owned #14/#38/N4, deployment, merge or release change.
- Verification boundary: the previous exact-head PR #37 CI `43167884743` passed 6/6 jobs and 101/101 steps on parent `24b1cbb`; that historical result does not verify these new commits. The cloud authoring runtime has no Dart/Flutter SDK, so no local Flutter format/analyze/test/build was run. New exact-head GitHub Actions is the required verification and will be recorded separately. PR #41's released lookup-contract HEAD `32da3d340b78fb6c898516f48eab45f2ce5d73f2` passed run `43191369135` (5/5 jobs, all returned steps successful).
- Limits remain: the new race is deterministic in-memory SDK/vault fixture evidence, not hosted signed-JWT learner A/B, deployed PostgREST/RLS, native delayed Credential Manager failure, OS logoff/power-loss or physical multi-device proof. #20/#22/#15 and Personal Alpha remain open/in progress.
- Next: verify every latest-attempt job and step for the final PR #37 HEAD; fix only observed failures. Then continue the remaining #22/#20/#15 acceptance and use protected non-production hosted configuration when available. Keep PR Draft until all acceptance and human gates are met.

## Windows late-refresh/logout barrier regression correction — 2026-11-12 UTC

- Resumed draft [PR #37](https://github.com/collab-TTAM/nihongo_daily/pull/37) on `automation/issue-22-atomic-review`, expected HEAD `289e836cff86ac64a6b005be90c90463d07f2f4f`, base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. Previous core checkpoint was RELEASED at 2026-11-12T13:29Z; no newer active marker was observed.
- Exact-head CI [43227599449](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43227599449), attempt 1, targeted that exact HEAD and completed FAILURE. Database, AI boundary, repo sanity, Windows and disposable Supabase integration all passed every returned step. Flutter format and analyze passed; the full Flutter suite failed only two Windows lifecycle cases at `windows_persistent_supabase_runtime_test.dart:635` and `:751`; all downstream Flutter steps were skipped, not passes.
- Root cause was test sequencing, not an observed production isolation failure: each TEST ONLY case awaited caller-owned logout while a held Auth response was still unresolved. The runtime's bounded Auth request has a 15-second timeout, so awaiting logout allowed the request to time out and the cleanup barrier to settle before the test attempted User B. At that point `loadingProfile` was valid after a newly permitted B login, contrary to the stale `signInError` expectation.
- Source commit `72cdd30d1bbcdd463753a53c964a8890dd3d2643` changes only `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`. Both startup-restore and explicit-refresh tests now start logout without awaiting it, assert `signingOut`, no ready runtime, `logoutSettled=false`, and no B Auth/profile dispatch while the late A operation is held. They then release the captured A response, await the failed operation and logout drain, and only afterward allow B to authenticate. Existing token-count, profile-count, clear-order and B-session assertions remain; no production code or test gate was weakened.
- Separate diff review confirms exactly one changed source path (+29/-8). The complete recursive parent/final tree was untruncated at 335 entries with identical path/mode/type sets; all 334 other entries are preserved. The changed blob readback matched; single-parent commit verified; `create_tree` used the exact parent tree and `update_ref` used `expected_sha=289e836cff86ac64a6b005be90c90463d07f2f4f`, `force=false`.
- Cloud authoring runtime has no pinned Dart/Flutter SDK; no local format/analyze/test/build pass is claimed. New exact-head CI is required before this correction is considered verified. PR #37 remains Draft; hosted signed-JWT learner A/B, deployed PostgREST/RLS, hosted expiry/restart and physical two-device proof remain outstanding. No Auth strategy/provider, migration/RLS, default activation, Pro-owned #14/#38/N4, deployment, merge or release change.
- Next: inspect every latest-attempt job and step on the corrected exact HEAD. If CI is green, continue the remaining #20/#22/#15 acceptance; do not duplicate source while checks are pending.


## Windows transient vault-read recovery — 2026-11-12T20:15Z

- Run `core-20261112T2013Z-pr37-windows-transient-vault-read-recovery` on `automation/issue-22-atomic-review`; parent HEAD `3902d411038d92a640080b7c035309541c32685a`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`. The previous ACTIVE marker at 18:05Z had no later heartbeat/comment and was over 90 minutes old; this run re-read the branch/PR/tree and claimed the sole core writer before editing.
- Parent exact-head Actions [43258326884](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43258326884) completed SUCCESS on `3902d411038d92a640080b7c035309541c32685a`: six jobs and all 101 returned steps succeeded. This is parent evidence only, not proof for the new regression.
- Extended the existing TEST ONLY pinned-SDK Windows MethodChannel read-failure test. A transient read error keeps the saved A secret untouched and sends no refresh/password Auth or profile request. An explicit same-runtime password login must clear the unread project slot before the grant, then persist B's rotated refresh token before B's own-profile request. The assertion also proves no stale A refresh grant is dispatched.
- Separate diff review caught a two-space indentation mismatch introduced when the existing inline test was converted to a multiline declaration; the follow-up commit corrects only that test block structure, with all assertions unchanged.
- Changed paths: `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, `qa/matrix.json`, `docs/PROJECT_STATUS.md`. The QA lifecycle case count is unchanged; one exact test anchor and its scope were extended. No production Auth/provider/runtime, API/schema/RLS, CI, default activation, Pro-owned #14/#38/N4, deployment, merge or release change.
- Full recursive parent tree was read untruncated at 335 entries (270 blobs/65 trees); the four existing paths/modes/types are preserved. The source test uses a TEST ONLY MethodChannel fault, not native CredRead failure injection or hosted learner A/B. Cloud authoring has no pinned Dart/Flutter SDK, so local format/analyze/test/build were not run. New exact-head Actions is required; no new-source CI pass is claimed.
- Next: inspect every latest-attempt job and critical step for the new exact HEAD. Keep PR #37 Draft and #20/#22/#15 open until hosted signed-JWT A/B, deployed PostgREST/RLS, expiry/restart and real two-device acceptance are observed.

## Latest handoff — PR #37 pinned Dart formatter repair — 2026-11-12T21:20Z

- Run `core-20261112T2108Z-pr37-pinned-dart-format-followup` resumed the released core lane on `automation/issue-22-atomic-review`; diagnostic parent `9c23df02814ba8e826538e5cb34c746dc524a187`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head diagnostic Actions [43307904935](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43307904935) ran against `9c23df02814ba8e826538e5cb34c746dc524a187`. Latest-attempt repo-sanity, ai-boundary and database jobs completed SUCCESS with every returned step successful. The Flutter diagnostic step completed SUCCESS and exposed one formatter-only difference: collapse the three-line password-grant equality assertion in `windows_persistent_supabase_runtime_test.dart` to the single line emitted by Dart 3.35.4. The unchanged strict format check then failed as expected; Flutter analyze, full tests and downstream steps were skipped. Windows and disposable Supabase integration were still IN_PROGRESS at the last observation. This diagnostic run is not acceptance evidence.
- Applied only that exact TEST ONLY formatting change; no assertion or behavior changed. Removed the temporary read-only formatter diagnostic from `.github/workflows/ci.yml`, restoring the original strict CI sequence. Updated this handoff. No production Auth/provider/runtime, API/schema/RLS, default activation, Pro-owned #14/#38/N4, deployment, merge or release change.
- Cloud authoring has no pinned Dart/Flutter SDK; local format/analyze/test/build remain unrun. The next exact-head CI must prove formatter, analyze, full Flutter tests, Windows, disposable Supabase, database, AI and repo-sanity jobs; no skipped/pending job counts as a pass.
- Hosted signed-JWT learner A/B, deployed PostgREST/RLS, real restart/expiry and physical two-device sync remain unverified. Keep PR #37 Draft and #20/#22/#15 open.


## Native Windows vault failure through caller-owned Supabase runtime — 2026-11-12T23:05Z

- Run `core-20261112T2305Z-native-vault-failure-bridge`; sole writer on `automation/issue-22-atomic-review`; parent `5a32a2595a5c993a3e22a30d89b7ae9cbf6fa9a7`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Extended the TEST ONLY Windows runner so a one-shot native Credential Manager read fault is injected before `CredReadW` through a MethodChannel method compiled only when CMake option `ND_SESSION_VAULT_TEST_HOOKS=ON`. The caller-owned runtime test requires fail-closed startup, no Auth/profile dispatch, preservation of the saved A value, explicit clear before B password Auth, B rotated-secret persistence before own-profile readiness, B logout clear, and no A journal visibility.
- The PowerShell harness turns the CMake option OFF, rebuilds the bridge runner, and verifies `testInjectFault` is unavailable before staging/normal preview builds. CMake default remains OFF. No learner-configurable URL/key, production Auth/provider/schema/RLS/default activation, plaintext fallback, token logs or Pro-owned #14/#38/N4 changes.
- Changed paths: `.github/workflows/ci.yml`, `apps/flutter_app/windows/runner/session_vault_channel.cpp`, `apps/flutter_app/windows/runner/CMakeLists.txt`, `apps/flutter_app/tool/windows_runtime_fixture.dart`, `apps/flutter_app/tool/windows_vault_bridge.dart`, `apps/flutter_app/tool/verify_windows_vault_bridge.ps1`, `qa/matrix.json`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, `docs/WINDOWS_SESSION_VAULT.md`, and this status file.
- Parent exact-head Actions [43308478939](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43308478939) completed 6/6 jobs and 101/101 steps SUCCESS. Cloud runtime lacks the pinned Windows/Dart/Flutter toolchain; no local C++/Dart format/analyze/test/build is claimed. New exact-head CI must pass every latest-attempt job/step; no result for the new source is claimed at commit time.
- Separate review required: inspect the complete 335-entry tree, compare exact changed paths, verify every changed blob SHA, and confirm normal runner test-hook absence plus all Windows/runtime/Flutter CI steps. Hosted signed-JWT learner A/B, deployed PostgREST/RLS, expiry/restart and physical two-device proof remain outstanding. Keep PR #37 Draft and #20/#22/#15 open; no merge, deployment or release.


### Exact-head CI observation — native Windows vault failure bridge

- Run [43327133121](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43327133121), attempt 1, targeted source `69ed3da46752918c85050875d253546d908425c6`. Last observed: repo-sanity substantive validation steps completed SUCCESS (post-job cleanup still in progress); AI boundary was in progress at `npm run check` after install/audit/format succeeded; database was queued; Windows, disposable Supabase integration and Flutter jobs had not yet been published. No complete job/full-CI pass was claimed.
- Applied a separate import-order-only correction in `windows_runtime_fixture.dart`; this supersedes the above source head. Inspect the latest exact-head run for the follow-up commit; the earlier run is not evidence for the final head.


## Native Windows vault CI repair — 2026-11-13T00:21:36.185Z

- Re-read the complete PR #37 source tree at `d82bf4108f54d701c0ce4167adb911804f68cde7`: 335 entries (270 blobs / 65 trees), untruncated. Exact-head Actions [43327339521](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43327339521), attempt 1, completed FAILURE. Repo-sanity, database, AI boundary and disposable Supabase integration all completed successfully; Windows failed in the new caller-owned bridge sequence; Flutter failed the strict Dart 3.35.4 formatter for `tool/windows_runtime_fixture.dart` and `tool/windows_vault_bridge.dart`, so analyze/full Flutter suite/Web build were skipped.
- Code review found the native-read fixture was catching `SessionVaultFailure`, while `PersistentAccountAccess._run` intentionally normalizes storage exceptions to the fixed public `ReviewTransportFailure(UNAUTHORIZED)` boundary (the existing pinned-SDK read-failure test asserts that contract). Correct the TEST ONLY expectation; no production behavior/error surface changes.
- Add phase-only PowerShell progress/failure labels (no process stdout/stderr, token, or raw native detail) so future Windows failures identify the failing fixture phase. Add a read-only CI formatter diff for two fixture files; it formats temporary copies and leaves the strict format gate unchanged.
- This is a diagnostic checkpoint, not a passing CI result. Next: capture the pinned Dart 3.35.4 diff, apply only those exact formatting changes, remove the temporary diagnostic step, then require every latest-attempt job/step on the corrected exact HEAD. No Pro #14/#38/N4 or production Auth/schema/RLS/default activation changes.


## Exact-head formatter repair — 2026-11-13T02:07Z

- Branch automation/issue-22-atomic-review; source parent 71f41a3e2f6b9493f78bad5b83b4eeada05ac9ad; formatter-repair source commit 0ba641772e25f8ae4f79384dcf47b7bc63c9f029; base main 78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c.
- Exact-head Actions [43336473924](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43336473924), attempt 1, completed FAILURE only at strict Dart 3.35.4 formatting. Repo-sanity, AI boundary, database, Windows native and disposable Supabase integration all completed SUCCESS; Flutter analyze, full tests and downstream Web checks were SKIPPED, not passes.
- Applied only the exact formatter output to apps/flutter_app/tool/windows_runtime_fixture.dart and apps/flutter_app/tool/windows_vault_bridge.dart. Removed the temporary read-only formatter-diff step from .github/workflows/ci.yml; the strict dart format --output=none --set-exit-if-changed . gate remains unchanged.
- No assertion/test case, production behavior, Auth/provider strategy, API/schema/RLS, default activation, Pro-owned #14/#38/N4 content or release configuration changed. No local Dart/Flutter SDK is available in the cloud authoring runtime; new format/analyze/test/build evidence must come from exact-head CI.
- Complete parent tree was read recursively and untruncated: 335 entries. First correction tree preserved every path/mode/type and every untouched blob; only the two TEST ONLY Dart files and CI workflow changed. create_tree used exact parent base_tree_sha 103882e6ea98115e6f58539558d88d85d2726029; final status update is recorded in the PR checkpoint comment.
- Next: inspect every latest-attempt job and step on the corrected PR HEAD. Fix only observed failures; do not count skipped/pending jobs as passes. Hosted signed-JWT learner A/B, deployed PostgREST/RLS, real expiry/restart and physical multi-device proof remain outstanding; keep #37 Draft and #20/#22/#15 open.


## Flutter analyzer repair — 2026-11-13T03:13Z

- Exact source HEAD before repair: `8a52d430d7723f6b0e5e69ed0d809816b357ca0e`; branch `automation/issue-22-atomic-review`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head Actions [43350804396](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43350804396), attempt 1, completed FAILURE only in the Flutter job. Repository sanity, database, AI boundary, disposable Supabase integration and Windows all completed SUCCESS. Flutter dependency install and strict Dart 3.35.4 format passed; `flutter analyze` found one unused import at `tool/windows_runtime_fixture.dart:13`. Full Flutter suite and all downstream Flutter checks were SKIPPED, not passes.
- Removed only the unused TEST ONLY import of `session_credential_vault.dart`; no fixture behavior, assertions, production code or security gates changed. Cloud authoring runtime has no Flutter SDK; this repair has not been locally analyzed or tested.
- Next: inspect every latest-attempt job and step on the new exact HEAD. Keep PR #37 Draft and #20/#22/#15 open pending hosted signed-JWT learner A/B, deployed PostgREST/RLS, restart/expiry and physical multi-device evidence. Pro-owned #14/#38/N4 remains excluded.

## Windows vault owner-gated login recovery — 2026-11-13T04:14Z

- Branch `automation/issue-22-atomic-review`; parent HEAD `ff7b6fc9b7cc6dcdd0b15e12d1b24e3db2b79725`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Fixed a startup gating gap: a failed native Credential Manager owner-lease acquisition previously left `PersistentAccountStartup.canOfferLogin` true even though `PersistentAccountAccess.signIn` correctly rejected Auth without the lease. The UI could expose a login form that could not safely proceed.
- `PersistentAccountAccess.hasVaultOwner` now reports only an acquired, still-held owner; startup offers the fenced login form only when that owner exists. A TEST ONLY Windows runtime regression checks owner-acquire failure keeps login unavailable and sends no Auth/profile request. The existing transient-read failure regression now also asserts that explicit login remains available after the owner lease is acquired, preserving cleanup-before-password and rotation-before-profile ordering.
- Changed paths: `apps/flutter_app/lib/features/auth/data/persistent_account_access.dart`, `apps/flutter_app/lib/features/auth/application/persistent_account_startup.dart`, `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`, `docs/PERSISTENT_SESSION_LIFECYCLE.md`, and this status file.
- Parent exact-head Actions [43357923821](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43357923821) passed all 6 jobs / 101 returned steps on `ff7b6fc9b7cc6dcdd0b15e12d1b24e3db2b79725`; it is parent evidence only. Cloud authoring runtime has no pinned Dart/Flutter SDK, so local format/analyze/test/build are not run. New exact-head Actions is required; no new-source pass is claimed yet.
- No Auth strategy/provider, API/schema/RLS, migration, default activation, Pro-owned #14/#38/N4, deployment, merge or release change. Hosted signed-JWT learner A/B, deployed PostgREST/RLS, expiry/restart and physical multi-device evidence remain outstanding.
- Next: inspect every latest-attempt job and step for the new exact HEAD; fix only observed failures and keep PR #37 Draft / #20/#22/#15 open until their full hosted acceptance is observed.


## PR #37 exact formatter diagnostic — 2026-11-13T05:13Z

- Run `core-20261113T0513Z-pr37-dart-format-owner-gate`; branch `automation/issue-22-atomic-review`; parent HEAD `704cfc056c22e18d9ddace26a11a3807a561f921`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Exact-head Actions [43365290746](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43365290746) completed FAILURE only at pinned Dart 3.35.4 formatting: `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart` is the sole formatter-reported file. Repository sanity 12/12, AI boundary 12/12, database 12/12, disposable Supabase integration 13/13 and Windows 17/17 completed SUCCESS. Flutter analyze, full tests and downstream probes were SKIPPED, not passes.
- Added a temporary read-only formatter-diff diagnostic after the strict formatter step so the next exact-head run prints only the formatter hunk. The strict gate remains unchanged; diagnostic is intended to be removed in the immediate formatter-fix commit.
- No production behavior, Auth/provider, API/schema/RLS, default activation, Pro-owned #14/#38/N4, deployment or release changes. Cloud authoring runtime has no pinned Dart/Flutter SDK; GitHub Actions is the formatter authority.
- Next: inspect the diagnostic diff, apply only the exact formatter output to this TEST ONLY file, remove the diagnostic step, then rerun all exact-head checks.
