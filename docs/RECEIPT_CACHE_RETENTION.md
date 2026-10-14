# Opt-in successful receipt cache retention — #15 / #22

Configure `ReviewReceiptRetention(keepCount: 128)` on NativeReviewJournal.open,
openBrowserReviewStore or TransactionalReviewStore. Valid limits are 1..256.
Default is null/disabled, preserving every existing record. The default app
runtime remains unconfigured; no production data or server history is deleted.

## Policy and replay contract review

Before staging a new unique event, trim only this owner's oldest staged records
that have a validated successful server receipt, retaining keepCount successes.
The new event is then staged before RPC as usual. One newly acknowledged success
can make the cache keepCount+1 until the next new stage. Explicit owner-scoped
`pruneReceipts(userId)` applies the strict limit immediately and returns the count
removed. Existing-event replay/conflict checks run before retention, so an already
cached event keeps its original result/payload guard. Order is stable staging
order, not client clock or acknowledgment time; delayed events cannot manipulate
policy using timestamps. No shared-owner/global cleanup occurs.

Every pending event, definitive rejection and other owner's history is retained.
Rejections are deliberately ineligible: unlike successful events, they need not
have an immutable stored server receipt. Never infer that a failed local record
can be reconstructed safely or drop an unresolved event to free space. Multiple
accounts, many pending/rejected events or browser quota may still exhaust the
global 1 MiB/512 retained-event limits; fail closed. This is bounded success-cache
maintenance, not unlimited storage or complete sync.

Once a successful local cache entry has been pruned, resubmitting that ID must
stage the exact original event, call the authenticated RPC and revalidate its
original server receipt. No cache miss fabricates success or advances a local
schedule. A changed payload is checked by the server's immutable event identity.
The deployed server must retain successful event request/result history and
preserve replay before stale/content checks. Current submit_review SQL does this:
private.review_replay precedes content/skew checks; retained review_rpc tests
check original result/count and replay after retirement. Client retention never
deletes learning_events or derived state. Hosted deployment/retention policy still
requires real configured acceptance; injected replay-server tests are TEST ONLY.

## Atomicity, compatibility and failure behavior

Browser pruning/new staging runs in the same readwrite ledger transaction as
other tabs, so a failure aborts both changes. Explicit pruning also commits before
returning. Native pruning uses the existing flushed sibling/rename/reopen protocol
under the same serial queue and independent lease. Memory changes only after
replacement succeeds. A failed temporary write leaves original history usable;
failure after replacement begins fails closed until reopen. As a separate native
maintenance step, committed cache pruning may precede a failed new append; no
new pending event/RPC is claimed, and pruned successes remain server-replayable.

No format bump: native v3 and browser ledger v1 remain compatible. New readers
retain v1/v2 native history support; old compatible readers see fewer cached
successes and use server replay. There is no token, new data collection, RLS,
Auth strategy, provider, dependency or production change. Native/browser power
loss and browser eviction guarantees remain outside the evidence. See
JOURNAL_COMPACTION.md and BROWSER_REVIEW_STORE.md for underlying store limits.

## Reproduce and handoff

From apps/flutter_app:

```bash
flutter test test/features/srs/receipt_retention_test.dart
dart run tool/verify_receipt_retention.dart
flutter test --platform chrome test/features/srs/browser_review_store_check.dart
```

Four pure/unit scenarios cover policy selection/invalid limits, immutable original
server-fixture replay, 600 successful reviews, default-disabled behavior and
transaction rollback. The required real-file/process CLI exercises native 600
reviews, child prune/exit/parent reopen, exact pending preservation, other-owner/
rejection preservation and a blocked temporary write/retry. Both Linux and Windows
must run it. An added Chrome test uses actual IndexedDB connections with explicit
retention, server-fixture replay, concurrent prune/stage and reopen. Existing
default full-cap/native compaction/browser reload/SQL/RLS/wire gates stay intact.

These checks do not prove live server signatures, secure session restoration or
a two-device learner flow. Keep #37 draft/#15/#20/#22 open; next configured
Auth/profile/login/session persistence and actual hosted learner acceptance.
Observe exact-head CI before claiming full Flutter/Chrome/Windows results.
