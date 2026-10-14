# Native durable review journal — #22 / #15

This is an **opt-in native library**, not an activated app offline mode.
The owner opens NativeReviewJournal in the application's private data directory,
wraps RpcReviewRepository in DurableReviewRepository, and closes the journal
when the runtime ends. There is no new dependency, table write, auth provider,
token serialization or storage of curriculum display text. Default app runtime
remains null; existing controller/UI does not yet invoke restart recovery.

## Write and recovery protocol

1. A currently authenticated session prepares the immutable seven-field event.
2. submit stages the account-scoped event and flushes it before any RPC. A failed
   write sends nothing. Concurrent identical submissions share one dispatch;
   changed payload under the same event ID conflicts.
3. The original validated server response is appended/flushed as a receipt.
   Only then does the wrapper report success. Failure after server success keeps
   the event uncertain; original-event replay can retrieve the server receipt.
4. Under a fresh session for the same owner, recoverPending reads only that
   owner's unacknowledged events and rebinds them to the current lifecycle. It
   preserves exact event/rating/time strings, including submicrosecond offsets.
   Recovery does not dispatch. The caller must offer an explicit manual retry
   before allowing new study events, with storage/load/error handling.
5. Receipt replay avoids another RPC and returns the historical original result.
   This is not the current schedule: reload the authoritative due queue after
   reconciliation; never apply an old receipt over newer server state.

Account/lifecycle checks run after disk awaits and RPC completion. A/B/A or
same-user re-login rejects old results. An old account's confirmed receipt can
still be persisted under its original owner after logout; it is not displayed
to the new account. Logout does not erase unresolved pending events.
Local owner IDs isolate records but are not credentials or JWT authorization.
The configured Auth/RPC binding and server retain those responsibilities.

## File safety and limits

The version-1 journal is canonical newline-delimited JSON. Only pending and
validated receipt records are allowed, with exact keys, bounds and immutable
identities. Canonical encoding also rejects duplicate JSON keys on restore.
Records contain no token/refresh token/headers or raw errors. Storage failures
have fixed safe messages; the wrapper returns INTERNAL_ERROR until manual
storage recovery, never a fabricated saved result.

An exclusive OS file lease plus a same-isolate directory guard serializes one
writer. The application must use exactly one owner isolate per directory: OS
locks on some platforms are process-scoped, and static guards are isolate-local.
This is not protection against a hostile process using the same OS account,
editing local files or replacing symlinks. The application owns the trusted
private directory/path, access policy and journal lifetime.

On reopening, complete malformed records fail closed without deletion.
Only an incomplete EOF tail is truncated under the lease. An incomplete pending
write was never eligible for dispatch; an incomplete receipt leaves the already
flushed pending event for original replay. A failed append poisons that open
instance: close/reopen before further recovery. Events/receipts are not silently
discarded, expired, rewritten or compacted.

Hard limits: 1 MiB file, 512 retained events across owners. Capacity exhaustion
fails before dispatch. Compaction/encryption/retention and migration need later
implementation; this bounded journal is not a long-term production data store.
flush plus separate process restart is tested; sudden hardware power loss,
filesystem durability, concurrent isolates and hostile local tampering are not
certified. Filesystem locks are advisory/cooperative where the OS defines them.

## Verification and remaining integration

From apps/flutter_app:

```bash
flutter test test/features/srs/durable_review_repository_test.dart
dart run tool/verify_durable_review.dart
```

The verifier stages in a child process and exits without graceful close, reopens
in the parent, checks another process cannot acquire the lease, restores/retries
the exact pending event, persists/replays its original receipt, and verifies
incomplete-tail recovery versus complete corruption. CI requires this verifier
on Linux and Windows, retaining all former gates.

Files/processes are real disposable native resources. Auth/RPC responses are
**TEST ONLY** fixtures; no real JWT/PostgREST or multi-device sync is proved.
Flutter tests cover write/ack failures, concurrency/conflicts, account switching,
exact restore, corrupt input and original receipts. Full current-head CI must
be observed before claiming those Flutter tests or Windows checks pass.

Next: integrate controller recovery/reconciliation UI, browser transactional
storage, configured login/profile/secure session restoration (#20), bounded
retention/compaction and actual two-client/hosted acceptance (#15/#22).
All 14 Personal Alpha release integration cases remain pending; keep #37 draft.
