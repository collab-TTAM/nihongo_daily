# Opt-in durable study recovery — #22 / #15

The controller, notifier and screen support a DurableReviewRepository supplied
by the runtime owner. Both runtime factories accept an optional DurableReviewStore;
the owner configures and owns its lifetime/private directory. The app's default
runtime remains null. No login, credential restoration or disk path is activated
automatically. Browser storage is now opt-in through openBrowserReviewStore();
see BROWSER_REVIEW_STORE.md for persistence/activation limits.

Before reading new due cards, load checks all pending events for the captured
account, including events outside the selected level. Reading never dispatches:
the screen shows the original rating/time and an explicit manual replay action.
It offers no rating change, new event or bypass reload while a result is unknown.
Duplicate taps are blocked. Logout/A-B-A/disposal clears the visible record and
rejects old asynchronous results. The port limits recovery to 512 unique events
bound to the exact current session, while the journal retains resource limits.

Validated success is flushed to the journal. Recovered events are processed one
at a time; only after all are resolved is the authoritative due queue loaded.
An old receipt never becomes the new session's progress counter or displayed
current schedule. Normal durable-mode success also rechecks the journal and
reloads the queue, rather than advancing a stale local queue snapshot.

Local read errors block new cards and offer a safe recheck. Stage/receipt/rejection
write failures preserve the original event and offer an explicit retry. The local
storage marker is application-only: frozen error JSON still uses INTERNAL_ERROR,
with no token/path/raw error. Malformed/uncertain outcomes also retain the event;
durable mode permits manual same-event reconciliation, without automatic retry.
Unauthenticated outcomes never authorize deletion or new records.

Only nonretryable VALIDATION_FAILURE/NOT_FOUND/FORBIDDEN/SYNC_CONFLICT are terminal
rejections. The wrapper appends a checked immutable rejection before exposing a
definitive reload action. A failed rejection write remains uncertain, blocks reload
and keeps the event for retry. Explicit reload skips terminal history and checks
remaining events before reading fresh due cards. No failed event is counted saved.

## Journal compatibility and limits

Native records use version 3 with optional settled snapshots; the reader accepts
version-1 pending/receipt and version-2 terminal history. See JOURNAL_COMPACTION.md.
Browser snapshots have independent schema version 1 and no native import.
Old binaries cannot read newer records; downgrading requires a reviewed migration,
not truncating history. The release is still draft/unactivated.

Receipts and rejections both consume the reserved terminal-result slot and release
unused reservation. Neither result may replace the other, change identity or be
rewritten. NETWORK_UNAVAILABLE/INTERNAL_ERROR/UNAUTHORIZED/transient outcomes
cannot be archived as terminal rejections. All journal size/event/lease/corruption
limits remain; native lossless compaction is explicit. No encryption, terminal
retention or hardware-power-loss proof.


## Local two-runtime offline/reconnect integration — authored

The disposable `supabase-integration` SDK probe now composes two sequential,
independent runtime bundles for the same Auth owner. Each bundle has its own
native journal, in-memory TEST ONLY credential backend and HTTP client. Device A
stages an immutable review while the transport is deliberately unavailable;
the journal retains the exact event and the owned close preserves A's refresh
secret. Device B signs in through a separate Auth session and commits a newer
event to the same local GoTrue/PostgREST owner. A then reopens its own journal,
restores through its own rotated refresh token, and exposes the exact pending
event only for explicit manual replay. The server returns `SYNC_CONFLICT` for
the stale event; the local journal records a terminal rejection and the reloaded
queue remains the server-authoritative empty projection. Device A then closes and
reopens the journal again under a fresh Auth session: the terminal rejection must
still be present, `recoverPending()` must remain empty, and a duplicate manual
submission of the same event must return `SYNC_CONFLICT` without another
`submit_review` HTTP dispatch or a change to the authoritative queue.

This extends the existing HTTP-level two-session/concurrent-event tests with
the real pinned Supabase SDK, write-before-dispatch repository and two separate
on-disk journals. The runtime bundles run sequentially in one TEST ONLY process
because the production owner lease intentionally prevents two same-origin
writers in one process. It is not simultaneous physical devices, hosted sync,
a Windows Credential Manager multi-device test or a learner journey. Exact-head
CI must execute the new phase before the QA case can be advanced.


## Evidence and remaining work

Run the new controller/widget tests plus dart run tool/verify_study_recovery.dart.
The raw verifier uses actual close/reopen files and the real controller/repository,
checks pending-before-queue/manual exact replay, v2 rejection restoration, terminal
`SYNC_CONFLICT` persistence across a second restart, duplicate terminal replay
without network dispatch and authoritative reload. It is required on Linux and Windows CI. Existing subprocess
lease/restart, frozen wire/SQL/QA/AI/build gates remain.

Fixtures supply Auth/RPC/queue responses, so this is not a hosted JWT or signed-in
learner journey. Twenty-one controller/widget tests are authored; current-head CI
must confirm them. The widget cases include account clearing, storage errors,
original rating/manual action and 320px at 200% text.

Next: reviewed terminal retention, configured #20 login/profile and
secure session restoration, actual hosted A/B/expired JWT and two-client #15/#22
acceptance. Keep #37 draft and all 14 Personal Alpha release cases pending.
