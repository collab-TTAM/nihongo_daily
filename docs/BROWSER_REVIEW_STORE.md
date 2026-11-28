# Opt-in browser review ledger — #15 / #22

`openBrowserReviewStore()` returns a TransactionalReviewStore implementing the
existing DurableReviewStore. Supply it to an explicit SRS runtime factory's
`store` argument; the owner closes it after disabling that runtime. The default
app remains unconfigured. Native callers receive a safe unsupported failure and
use NativeReviewJournal; no silent in-memory/localStorage fallback.

## Transaction protocol and security review

IndexedDB schema v1 has one journal object store and one canonical state string.
Each operation reads the current ledger in a readonly/readwrite transaction.
Decode/validation/mutation/put runs synchronously inside request success, with
no await that could deactivate the transaction. The future resolves only at
transaction complete, never at put/request success. Request/transaction errors,
abort, unsupported storage, closed handles and upgrade/version changes fail
with the existing safe local-storage error. Browser/raw exceptions never leak.

The object-store transaction scope serializes readwrite operations across
connections/tabs, preventing a read-then-write lost update. Identical staging
reuses the original immutable event; changed payload conflicts and aborts.
Original success/rejection cannot replace one another or change after commit.
Only checked definitive nonretryable errors may settle a pending event. This
does not claim single client RPC dispatch across tabs: the existing server event
identity/atomic RPC remains responsible for server replay and duplicate effects.

Canonical version-1 JSON has exact root/record fields, no duplicate keys/events,
strict owner UUID and request/outcome validation. Owner projections never return
another account's records. No tokens, headers, curriculum display text, raw errors
or derived SRS updates are stored. Owner UUIDs are isolation keys, not credentials;
captured Auth plus server authorization/RLS still apply. Same-origin scripts and
XSS can access browser data; this is not encryption or a defense against hostile
code on the same origin. No Auth strategy, RLS, provider, deployment, secret or
dependency change. Reference: https://www.w3.org/TR/IndexedDB/ (transaction
scheduling/lifecycle and commit semantics); bindings use dart:js_interop.

Bounds: 1 MiB UTF-8 plus 8192 reserved bytes per unresolved outcome within that
same limit; 512 total retained events across all owners. Restoration checks the
same bounds. No automatic eviction or terminal history deletion. Corrupt data
fails closed without overwriting it. Canonical snapshots avoid append redundancy
but still hit the finite event cap; reviewed retention is a later increment.
Schema changes need reviewed migration; unknown versions fail closed.

## Browser persistence limits

Transaction completion proves browser commit, not physical-disk fsync or survival
of hardware power loss. Clearing site data, origin/port changes, private browsing,
quota restrictions or browser eviction can remove local data. No persistence
permission request, automatic retry or eviction guarantee is introduced. Closed
or upgraded connections must be reopened by the owner; pending data is reconciled
under fresh Auth through the existing manual recovery UI. Live login/profile and
secure session restoration remain missing, so the preview is not active offline
study. Native and web stores have different formats and do not migrate each other.

## Reproduce and evidence boundaries

From apps/flutter_app:

```bash
flutter test test/features/srs/transactional_review_store_test.dart
flutter test --platform chrome test/features/srs/browser_review_store_check.dart
mkdir -p build/browser-restart
dart compile js tool/verify_browser_reload.dart -o build/browser-restart/main.js
python3 ../../scripts/verify_browser_review_restart.py build/browser-restart
```

Seven pure-ledger tests use TEST ONLY atomic ports (rollback, canonical corruption,
reservations, immutable outcomes, uncertain results, full event cap and concurrency). Four Chrome
tests use actual IndexedDB: close/reopen/exact time/account projection, two actual
connections contending for duplicate/distinct/conflicting writes, durable receipt
replay/rejection immutability and safe uncertain/closed behavior. Mock Auth/RPC
cannot establish hosted signatures or learner acceptance. Browser quota failures
are modeled by the atomic port, not induced on actual Chrome.

The separate required CLI compiles the real Dart browser store and serves only
disposable localhost fixtures. A real ChromeDriver page refresh discards all
Dart memory with the DB still open, then verifies exact pending recovery and
original receipt on a second refresh; another tab sees the committed history.
It fails if ChromeDriver is absent and never replaces the check with a mock.
The Linux Actions image supplies Chrome/ChromeDriver, documented at
https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md .
Driver/server/process cleanup is bounded. No hosted service or production app
is deployed. All previous Linux/Windows/SQL/AI/wire gates remain mandatory.

Local pure Dart checks and JS compilation do not prove browser runtime behavior;
observe exact-head CI before claiming Chrome/build results. Other browsers,
mobile/private modes, power-loss, real quota/eviction, hosted two-device learning
and long-term retention remain unverified. Keep #37 draft/#15/#20/#22 open and
all 14 Personal Alpha integration cases pending.

Observed source evidence: a1c54ffd3a767302a6623cac77c6b1336bb88f90 passed all
five jobs in https://github.com/collab-TTAM/nihongo_daily/actions/runs/38523331817 .
238 Flutter tests (seven ledger cases), four actual Chrome IndexedDB tests and
compiled-Dart page reload/second tab passed, together with web/Windows builds
and retained native/SQL/AI/QA gates. Exact-head unmodified metadata was accepted
by scripts/verify_qa.py. This does not activate the default runtime or establish
hosted learner acceptance; later commits require their own relevant checks.

Optional owner-scoped confirmed-success cache retention is now documented in
RECEIPT_CACHE_RETENTION.md. It is disabled by default and never removes pending,
rejected or other-owner records; server history and all resource limits remain.
