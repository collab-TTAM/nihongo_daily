# Opt-in native quiz history — Issue #13

NativeVocabularyQuizJournal implements VocabularyQuizAttemptStore as a separate,
bounded append-only local library. No app runtime or public /quiz route opens it
yet. An optional captured-ready-session repository is described in
QUIZ_ACCOUNT_HISTORY.md; explicit owned startup and save/history UI remain next. Supplying an owner UUID
to this library is isolation, not authentication or server authorization.

## File protocol and replay

The caller owns one writer isolate and a trusted private project directory.
quiz-attempts.lock holds an exclusive OS lease, with an additional same-isolate
resolved-directory guard. quiz-attempts.ndjson is independent of all review,
completed-study and credential files. The local envelope has exactly version
(integer1), owner_id (canonical UUID) and attempt (strict local-v1 or local-v2 snapshot).
It stores no credentials, display text, supplied score, timer or server credit.

Accepted operations serialize. An append writes canonical JSON plus newline and
flushes before updating memory or reporting success. Same owner/event and exact
payload returns the original without another write; changed time, level, answers
or choice order raises VocabularyQuizHistoryConflict before mutation. Different
owners may use the same event ID. Reads return immutable owner-filtered lists.

A failed write/flush poisons the open instance: later reads/writes fail until
close/reopen. The outcome may be uncertain, so callers must retain and retry the
same immutable event rather than inventing another ID. Reopen can recover a
complete flushed line and exact replay avoids duplicates. The TEST ONLY `openForTesting` writer seam injects both a partial-write
failure and an error reported after a complete write/flush. Each case proves the
live instance rejects later reads/writes with a fixed safe error. Reopen repairs
only an incomplete EOF tail, or restores the already-complete line; retrying the
same event then produces exactly one record. Production `open` always uses the
real write-and-flush implementation and never accepts a caller-supplied writer.

Restore validates all complete lines before repairing only an incomplete EOF
tail under the lease. Strict attempt decoding accepts legacy v1 and provenance-complete v2 snapshots; exact writer encoding rejects unknown versions/keys, malformed owners, duplicate JSON keys, changed
replays, noncanonical dates and noncanonical complete lines. Complete corruption
fails closed without deleting bytes. Identical complete replay deduplicates.
An incomplete final record has not crossed the newline commit marker.

Bounds are1 MiB and512 unique owner/event records across all owners. Either bound
stops a new append without eviction; exact replay still works at capacity.
close rejects new operations immediately, drains already accepted operations and
shares one completion before releasing file/lease ownership. Public storage errors
have a fixed Vietnamese message with no path or raw filesystem exception.

The private directory and one writer isolate are caller responsibilities.
This does not protect against hostile same-OS-user edits or symlink races;
filesystem locks are cooperative where the OS defines them. Process restart is
covered by authored tests; sudden hardware power loss is not certified. A
separate bounded IndexedDB quiz-history component is now available for browser
storage, but it is not wired to a web Auth runtime. Encryption, retention/compaction
and full synchronization remain future work. No existing journal format, shared
contract or dependency changes.

## Verification and remaining composition

New Flutter tests use real disposable files for immutable reopen, interleaved
owners/equal event IDs, concurrent replay/conflict, queued-work close/drain,
incomplete-tail repair, complete corruption/duplicate-key/canonical rejection,
record and byte limits, bootstrap failure and ownership cleanup. Injected partial-write and post-flush failures verify poisoned-instance rejection, incomplete-tail-only repair, exact replay and no duplicate append. A pure Dart
child exits after flush without graceful close; another child must fail to
acquire an active lease. Reopening after release and exact child replay are
checked. The reports are explicitly synthetic local fixtures, not Auth evidence.

Run from apps/flutter_app:

    flutter test test/features/quiz/native_vocabulary_quiz_journal_test.dart

The Windows-2022 job explicitly executes both native journal suites; the
Linux full Flutter job also includes them after the strict format gate. Exact-head
Actions [43533012357](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43533012357)
failed the first Windows child `stage` probe with exit code 254 (23 other journal
tests passed). The helper previously discarded child stdout/stderr. It now
normalizes the Dart executable path from `FLUTTER_ROOT`, captures each stream
with a 4 KiB bound and redacts the temporary directory in failure output. A
regression checks the diagnostic bound. This is a diagnostic correction, not a
Windows pass; the next exact-head Actions run must verify child startup, OS lease
and both suites. No local Flutter/Dart SDK is available.

Parent43094ac2 CI39480610637 latest attempt1 completed all five jobs/every required
step:621 Flutter tests (including all16 history-model cases), five Chrome tests,
retained native/process/SQL checks, Web and Windows release builds/artifacts.
This verifies the parent models, not the new store.

After captured-repository current-head checks pass, add owned save/history
composition with stale-session fences, storage error/manual retry and explicit
lifecycle ownership. See QUIZ_ACCOUNT_HISTORY.md. Public /quiz still loses results on exit.
No mastery or server credit. Keep #13 open/#41 draft/default preview and all14
hosted acceptance groups pending. No live activation, merge, deployment or
schedule change.

Parent78fbfae0 CI39484645098 attempt1 subsequently passed all five jobs/every
required step,634 Flutter/five Chrome/Web/Windows. All13 actual file/process
store tests passed on Linux. The new optional captured-session repository is
separately awaiting current-head CI; /quiz still does not open or use this store.


## Windows child-process Dart VM dependency boundary — 2026-11-14

The Windows journal test launches `quiz_journal_fixtures.dart` with the standalone
Dart VM. The production journal source must therefore remain Flutter-independent.
Exact-head Actions [43539947981](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43539947981)
showed the child failing before its stage command: the journal imported
`package:flutter/foundation.dart` only to annotate `openForTesting`, which
transitively loaded `dart:ui`; that library is unavailable to a standalone Dart
VM. The same run also exposed the pinned formatter layout in the process helper.
Flutter analyze/full tests and downstream probes were skipped after formatting
failed; they are not passes.

Removed only that unnecessary Flutter import/annotation. The fault-injection
factory remains explicitly named and documented TEST ONLY; production `open`
still supplies its fixed real write-and-flush callback. Added a repo-sanity
regression that prevents reintroducing a direct Flutter/`dart:ui` dependency,
while the existing Windows test continues to execute the actual child `stage`
and OS-lease process checks. The helper now matches the pinned Dart formatter.
No journal format, write protocol, owner isolation, default save activation,
Auth, schema/RLS or server credit behavior changed.

This is a source-level dependency guard plus a real Windows child-process test,
not hosted Auth/JWT/RLS or learner/multi-device evidence. Require a new exact-head
Actions run to verify formatter, analyzer, full Flutter tests, both Windows
journal suites and all downstream build/database/AI gates.
