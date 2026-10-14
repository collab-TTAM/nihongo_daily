# Lossless native journal compaction — #15 / #22

This explicit opt-in API reduces bytes by combining a pending record and its
original terminal outcome into one version-3 settled record. `await journal.compact()`
returns reclaimed bytes. Every owner/event ID, exact request/time, original
receipt and definitive rejection is retained. No RPC, progress recomputation,
history deletion, automatic retention or increased 512-event cap. The default
application remains unconfigured.

## Replacement protocol and compatibility review

Maintenance joins the existing serial queue and keeps the independent OS lease.
Write/flush a sibling review-journal.ndjson.compact, close the old data handle,
rename the sibling over the data path, then reopen the append handle. Never
truncate the authoritative file during maintenance. Before rename the original
is authoritative; after successful rename the replacement is. An interrupted
sibling is ignored on bootstrap and overwritten by the next explicit compaction.
Symlink siblings fail closed. Temporary write failure leaves the original usable;
failure after replacement begins poisons the instance until close/reopen.

Output cannot exceed the original length or 1 MiB including unresolved-event
receipt reservations. All historical identities remain, preserving replay,
conflicts and owner isolation. Stage/acknowledge/reject still append afterward.
v3 reads canonical v1/v2 pending/terminal history and v3 settled snapshots.
Settled records require a validated success or strict definitive rejection;
uncertain/retryable errors cannot settle an event. Old binaries cannot read v3
snapshots: review migration/export before downgrade, never delete unfamiliar data.
No frozen API, database/RLS, Auth strategy, dependency or production change.

One owner isolate and a trusted private directory remain required. OS locks do
not defend against hostile same-account file changes. Sibling rename avoids
cross-filesystem movement. Actual process restart and Linux/Windows CI verify
supported behavior; no directory-fsync, hardware-power-loss or every-filesystem
atomicity guarantee. Extra free disk approximately equal to the replacement is
required; a full disk must leave the original intact.

## Verification and limits

From apps/flutter_app:

```bash
flutter test test/features/srs/journal_compaction_test.dart
dart run tool/verify_journal_compaction.dart
```

Six actual-file cases: empty/pending no-op; mixed owners/outcomes with exact
timestamps, immutable replay/conflict and concurrent writes; legacy v1/v2;
temporary-write failure; uncertain snapshot rejection; full 512-event history.
The CLI also compacts in a child, exits without close and reopens/appends in the
parent. Required on Linux and Windows with every prior gate retained. These
fixtures do not prove hosted Auth, multi-device learning or active offline mode.
Current-head CI is required before claiming full Flutter/build success.

Compaction reduces redundant bytes only; finite event retention remains a
long-term storage gap. Next: reviewed bounded terminal retention with server
replay guarantees, browser transactional store, configured login/profile/secure
session restoration and hosted two-client acceptance. Keep #37 draft and
#15/#20/#22 open. Personal Alpha remains incomplete.
