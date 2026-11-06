# Browser IndexedDB quiz history — Issue #13

The browser implementation is a standalone local storage component for the
existing vocabulary and grammar attempt snapshots. It is not installed into the
default preview or a web Auth runtime. The non-web conditional implementation
fails with a fixed storage error; there is no in-memory or plaintext fallback.

## Storage and transaction rules

Each quiz type uses its own fixed-version IndexedDB database and one
`journal` object store. A single `state` string contains a canonical JSON
array of immutable owner/event envelopes. The owner/event pair is the local
idempotency key; it is not authentication. The caller must derive owner identity
from its captured, ready Auth session before supplying a store to the existing
history repository.

A read/write transaction performs the complete read/validate/replay-or-append
without an await or microtask gap. The app acknowledges a new attempt only after
the IndexedDB transaction's `complete` event, not after the object-store request
succeeds. Browser transactions serialize writes across separate connections.
Exact replay returns the original record without another write; changed payload
under the same owner/event returns the existing typed conflict. Equal event IDs
under different owners remain isolated.

Complete state is revalidated on every read/write. Exact canonical re-encoding
rejects duplicate JSON members, unknown envelope fields, noncanonical ordering,
duplicate owner/event records and malformed attempt snapshots. Storage is bounded
to 1 MiB and 512 records across owners, matching the native journal. At capacity
the store fails closed without eviction; exact replay remains available.

Close stops accepting new work immediately, drains accepted operations and then
closes the database connection. Version changes/forced browser closure fence
late results. Fixed Vietnamese storage errors never expose browser exception
text, database names or record contents.

## Verification and limitations

`browser_quiz_history_check.dart` runs against actual Chrome IndexedDB in the
Flutter CI job. It covers two independent connections, concurrent identical and
distinct appends, owner separation, immutable replay/conflict, grammar primary
versus correction history, close/drain and reopen, and invalid database names.

This is browser-local persistence only. It is not encryption, backup, sync,
hosted attempts, verified JWT/RLS, account restoration or proof of current
curriculum/mastery. The web app's Auth/runtime is still explicitly unavailable;
this component is not wired into the default route or staging startup. Clearing
browser site data may remove local history. No tokens, provider credentials or
service-role secrets are stored here.
