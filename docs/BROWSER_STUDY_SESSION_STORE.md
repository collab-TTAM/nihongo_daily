# Browser completed-study storage — Issue #11 / #15

The Web-only `openBrowserStudySessionStore` opens a separate IndexedDB database
(`nihongo-daily-study-sessions-v1`) and object store (`journal`). It implements
the existing `StudySessionStore` capability without changing the native
`NativeStudySessionJournal`, the review journal, the quiz-history database or
any Supabase table/schema.

## Transaction and integrity rules

- One canonical JSON state value is read and replaced in a single IndexedDB
  transaction. The read/modify/write callback is synchronous; no await or
  microtask gap can deactivate the transaction.
- A write resolves only from the transaction `complete` event, never from the
  individual `put` request. Abort, request errors, quota failures, blocked/open
  failures, malformed state and unsupported storage return a fixed
  `StudySessionStorageFailure`.
- IndexedDB serializes overlapping read/write transactions for this object
  store across independent connections. A per-instance FIFO additionally orders
  accepted operations and `close()` stops new work before draining them.
- The canonical decoder requires exact record fields, valid UUID owner/event
  identity, the strict five-field `CompletedStudySession`, valid terminal
  transitions, unique owner/event keys and canonical re-encoding. Duplicate JSON
  members, unknown fields, alternate encodings and corruption fail closed.
- Same owner/event with changed event fields returns `SYNC_CONFLICT`. Identical
  staging is idempotent. Acknowledgment/rejection is terminal and idempotent
  only for the same terminal result; pending events are never evicted.

## Bounds and ownership

The journal is bounded to 1 MiB and 512 records across owners. It reserves 256
bytes per pending event for a future terminal transition. Capacity is checked
before a new event is staged, so storage exhaustion cannot follow a server write
that has no room for its local receipt.

The owner UUID is only a local partition key. It is not authentication, an RPC
credential or proof of ownership. The store is not encrypted and browser site
data may be evicted or cleared. It does not provide backup, cross-device
transport, hostile same-origin isolation or hosted JWT/RLS evidence.

The native conditional-export stub always fails with the fixed storage error;
there is no memory/plaintext fallback. The store is a caller-owned component and
is not installed into the default app, Auth startup, Daily Plan provider or
automatic save/retry path. The caller must keep it alive through repository
operations and await `close()` before replacement.

## Verification

The Chrome check uses real IndexedDB and two independent connections:

```bash
cd apps/flutter_app
flutter test --platform chrome test/features/daily_plan/browser_study_session_store_check.dart
```

It covers concurrent duplicate/distinct writes, owner isolation, changed replay,
close/drain, exact reopen, terminal transitions, the 512-event bound and invalid
database names. The native VM test separately verifies that unsupported
platforms do not silently substitute memory storage. These are browser-local
component tests, not hosted learner or multi-device acceptance.
