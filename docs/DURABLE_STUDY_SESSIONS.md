# Completed-study durability — Issue #11

The pure Dart/native library is now installed into configured owned Windows
startup with explicit recovery, as documented in OWNED_STUDY_RECOVERY.md.
Foreground SRS timer/new-report creation is documented in SRS_STUDY_TIMER.md;
other activity timers remain outstanding. The default
app remains preview; /plan remains a read-only authoritative view. Existing
review storage, credentials and journal formats are unchanged.

## Reviewed protocol and boundaries

DurableStudySessionRepository is constructed only with a ready Auth session,
the same captured DailyPlanRepository and an owned StudySessionStore. It captures
that exact session and checks both Auth identity and the delegate's readiness
before disk work and after every await. Observed loss permanently revokes the
wrapper; new same-user login must use a new factory instance. The delegate's
captured-ready-runtime fence also detects a replaced profile/refresh barrier.
Auth errors/readiness getter errors fail closed without exposing raw text.

1. Stage the immutable canonical completed report under the local owner key.
   The store must flush before resolving. Failed staging sends no RPC. Same
   owner/event ID with changed fields conflicts; concurrent identical calls
   share one dispatch. Different owners remain separate, including equal IDs.
2. Submit the exact original five-field event using the existing authenticated
   RPC. Timeout, network/provider/internal/Auth failures or malformed responses
   retain the pending event. Nothing assumes failure means no server commit.
3. After a validated success, durably mark the event acknowledged. A failed local
   acknowledgment is reported as a safe storage failure and keeps the event
   uncertain for original-event reconciliation. Four definitive nonretryable
   backend rejections are retained as terminal codes, with no raw message.
4. Load get_daily_plan again. The historical replay response is never published
   as current progress. An acknowledgment with reloadFailure explicitly means
   the event is confirmed but latest dashboard loading failed; the caller must
   display these separately. An already-acknowledged repeat only reloads the
   latest plan, without another mutation. No progress total is cached locally.
5. Fresh-session recoverPending lists only that owner's pending immutable events.
   It performs no RPC or automatic retry. Caller must expose explicit recovery
   before allowing new potentially overlapping sessions. Logout never deletes
   unresolved or other-owner records. Late old-owner results cannot be published.

Local owner IDs are isolation keys, not credentials or RPC authorization. The
server still owns JWT validation, overlap/deduplication, elapsed-minute credit
and progress. Reports remain authenticated self-reported duration, not attention,
mastery or scores. No provider/Auth strategy or frozen wire contract is changed.

## Canonical native log

NativeStudySessionJournal uses separate study-sessions.lock and
study-sessions.ndjson files, with canonical version1 pending/acknowledged/rejected
commands. The strict CompletedStudySession.fromJson decoder accepts only the
existing encoder's five strings, normalized UUID and canonical UTC spellings;
invalid/rolled calendar timestamps, offsets, alternate precision and extra fields
are rejected. It never stores tokens, headers, curriculum text, progress totals,
SDK errors or service authority. No existing review file is read or rewritten.

One private trusted project directory and writer isolate own an exclusive OS
lease plus an isolate-local guard. Commands are serialized and flushed before
memory advances. An uncertain append poisons the instance until close/reopen.
On restore, duplicate JSON keys, complete malformed commands, invalid owners,
unknown versions, duplicate events or invalid terminal transitions fail closed
without deleting bytes. Only an incomplete EOF tail is truncated under the lease.
An interrupted terminal write therefore retains the flushed pending event.
Close rejects new work, shares one drain and releases file/lease ownership.

Hard bounds:1 MiB and512 retained events across owners, with256 terminal bytes
reserved per pending event. Capacity stops staging before RPC; acknowledged and
rejected records are not evicted. Retention/compaction, encryption, browser store,
concurrent-isolate ownership and long-term storage maintenance remain future work.
Use the OS-owned private project directory; this is not hostile same-OS-user or
symlink-race protection. Flush plus process restart is tested; sudden power loss
and hardware/filesystem crash durability are not certified.

## Evidence and next composition

From apps/flutter_app, run:

```bash
dart run tool/verify_study_session_recovery.dart
flutter test test/features/daily_plan/study_session_recovery_test.dart
```

Seven fixture scenarios execute real disposable disk for uncertain commit/replay
and fresh totals, stage/ack/reload faults and duplicate dispatch, owner changes/
late commit/irreversible readiness, all rejection policies, partial-tail repair/
complete corruption/strict codec and512-event reserved terminal capacity. A child
process flushes and exits without graceful close; a fresh parent recovers the
exact report. A second process cannot acquire the active lease, then can reopen
after close. Auth/RPC are explicit TEST ONLY fixtures, not hosted identity or OS
vault acceptance. Seven Flutter cases reuse these scenarios; native verification
is added to both existing Linux and Windows CI jobs with every former gate kept.

Local pinned Dart source analysis/formatting and the complete native verifier
passed. Full current-head Flutter analysis/tests, retained SDK/browser/native
checks and Web/Windows builds still require exact-head Actions. Historical21de4608
CI39314626994 passed allfive jobs, including the Windows source/close regression;
that does not verify this new module.

The owned journal/service and explicit pending recovery are installed; see
OWNED_STUDY_RECOVERY.md for resource ownership and new validation. Next add
other activity timer/save UI after current-head checks pass; the configured
foreground SRS flow is documented in SRS_STUDY_TIMER.md. Do not mark an
event saved until durable backend acknowledgment. Automatic profile-local today,
real JWT/A-B/restart/two-device acceptance and all14 live release gates remain.
Keep #41 draft and #11 open. No deployment, schema/RLS, dependencies, main/source
PR merge, Pro/reader content or schedule is changed by this module.
