# Owned completed-study recovery — Issue #11 / PR #41

Configured Windows startup now opens the separate NativeStudySessionJournal in
its trusted project directory after acquiring the review lease and before SDK
construction. Assembly failure closes both acquired stores. WindowsStagingOwner
owns both stores and the existing persistent runtime; no second SDK, token writer
or default preview configuration is created. Existing journal formats are intact.

PersistentSupabaseRuntime creates a captured DurableStudySessionRepository only
with its installed study store and current ready account/profile. The capability
travels through PersistentAccountStartup, WindowsStagingOwner and the active
AccountStartupController into an otherwise-null Riverpod source. Publication is
also fenced by current account/profile readiness. Logout/refresh/replacement/close
invalidates old services; same-owner relogin uses a new captured service.

## Manual recovery

The account and plan pages expose **Buổi học chờ đồng bộ** when configured and
ready. /study-recovery initially shows no fabricated empty result. **Kiểm tra
buổi học trên thiết bị** explicitly reads current-owner pending events from disk;
it performs no RPC. Each event shows its original plan date, area and explicitly
labeled UTC interval. No date inference, editable report fields or event ID input.

**Đồng bộ buổi học** submits that exact immutable event. Controls disable during
the operation; there is no automatic retry, background replay or timer. Storage
and RPC failures use fixed safe text, retain uncertain reports and allow explicit
reconciliation. Logout/account replacement clears visible pending/result/error
state and fences late old-owner success and failure. Other-owner reports survive
on disk and cannot appear in the current account's recovery list.

Only a validated backend receipt followed by durable local acknowledgment shows
**Buổi học đã được ghi nhận.** Latest progress comes from a fresh plan read,
never from the possibly historical receipt. A failed refresh after acknowledgment
shows **Buổi học đã được ghi nhận. Chưa tải được tiến độ mới.** and no invented
progress. A failed local acknowledgment cannot claim confirmation. Definitive
rejections remain retained terminal codes; explicit rechecking removes them from
the pending list. Navigation/restart begins with another explicit local check.

## Shutdown ownership

One runtime-scoped StudySessionOperationDrain retains only unfinished recovery/
submit futures. Close revokes the account immediately and starts existing Auth
close concurrently with study draining, preserving interrupted-refresh cleanup.
Neither SDK disposal nor either journal lease release precedes both drains.
Every accepted stage, dispatch, terminal append and latest read settles while its
resources remain owned. New operations cannot stage or dispatch after revocation.
Late uncertain commits retain the original pending event for next-session retry.
The existing awaited cancelable window-exit path and keyed mounted forms remain.

## Evidence and remaining work

Seven real-disk scenarios now include a held dispatch during shutdown; the same
fixture list feeds Flutter and both existing Linux/Windows process gates. The
native tool also flushes in a child that exits without close, recovers exact
reports in another process and verifies active/released process leases.

Nine authored widget cases cover absent configuration, delayed profile/no RPC on
check, duplicate controls/fresh totals, uncertain commit/manual exact retry,
acknowledged-but-reload-failed, safe storage failures, account replacement with
late completion, 320px/200-percent text and actual startup/account navigation.
Their storage/Auth/RPC are memory fixtures, separate from real-disk checks.
Two added actual-SDK/mock-HTTP/native-journal cases cover production publication,
reopen/acknowledgment and both leases retained during held study RPC plus pending
Auth rotation. All prior tests and CI steps remain; workflow is unchanged.

Local pinned Dart format, pure-source analysis, seven-scenario native/process
verifier, QA inventory49/17 regressions and whitespace results are recorded in
PROJECT_STATUS. Local Flutter CLI execution is blocked by automatic review of
instance-metadata access; no workaround is used. Full new-head widget, SDK,
browser and Web/Windows execution requires exact-head Actions.
Parent ac8cbd9 CI39316750394 passed all five jobs/every required step; this is
historical evidence, not execution of the changed source.

Actual activity timer/new report creation, automatic profile-local today and
browser study storage remain outstanding. The ordinary app remains preview.
No hosted login/JWT/restart/two-device proof: all14 live acceptance groups remain
pending; #11 open and #41 draft. No merge/deploy/schema/RLS/Auth strategy/provider/
dependency/Pro or reader content/schedule change.

## Widget fixture clock correction — 2026-10-20

At dd9d926 CI39363253639 passed format/analyze and all seven actual-SDK cases,
including both newly added study/reopen/concurrent Auth-close cases. Database,
repo-sanity, AI boundary and Windows jobs passed. Flutter tests reported437 pass/
7 fail: six recovery cases could not find the check action while their profile
was pending; startup navigation timed out on the same pending profile. The two
other recovery widgets and every prior plan widget passed. Downstream Flutter
steps were skipped and do not establish browser/Web/new-head full success.

Recovery Harness/its synchronous Auth stream listener was constructed in setUp,
outside testWidgets' fake-clock zone. An immediate profile Future.value thus
scheduled completion outside pump's microtask queue. The delayed-profile case
used a completer created inside the widget zone and passed. A standalone pinned
Dart diagnostic using the actual account controller/fixture reproduced outside
listener/pending-after-fake-pump versus inside-listener/ready-after-fake-pump.

All nine widgets now construct their fixture inside their testWidgets body.
Cleanup remains awaited and releases held writes. Added explicit ready/service
and actual startup publication assertions; none of the original assertions were
removed. Production code, timers, Auth lifecycle and all CI gates are unchanged.
Targeted Dart analysis, pinned formatter, diagnostic, QA17 and whitespace passed.
The local Flutter test command was rejected by automatic review after metadata
access; full corrected-source execution is pending new exact-head CI.
