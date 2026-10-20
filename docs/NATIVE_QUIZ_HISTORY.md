# Opt-in native quiz history — Issue #13

NativeVocabularyQuizJournal implements VocabularyQuizAttemptStore as a separate,
bounded append-only local library. No app runtime or public /quiz route opens it
yet. A future captured-ready-session repository must derive the owner from Auth,
fence every await, and expose explicit save/history UI. Supplying an owner UUID
to this library is isolation, not authentication or server authorization.

## File protocol and replay

The caller owns one writer isolate and a trusted private project directory.
quiz-attempts.lock holds an exclusive OS lease, with an additional same-isolate
resolved-directory guard. quiz-attempts.ndjson is independent of all review,
completed-study and credential files. The local envelope has exactly version
(integer1), owner_id (canonical UUID) and attempt (existing local-v1 snapshot).
It stores no credentials, display text, supplied score, timer or server credit.

Accepted operations serialize. An append writes canonical JSON plus newline and
flushes before updating memory or reporting success. Same owner/event and exact
payload returns the original without another write; changed time, level, answers
or choice order raises VocabularyQuizHistoryConflict before mutation. Different
owners may use the same event ID. Reads return immutable owner-filtered lists.

A failed write/flush poisons the open instance: later reads/writes fail until
close/reopen. The outcome may be uncertain, so callers must retain and retry the
same immutable event rather than inventing another ID. Reopen can recover a
complete flushed line and exact replay avoids duplicates. An injected write/flush
failure test is still outstanding; the poisoning path has source review only.

Restore validates all complete lines before repairing only an incomplete EOF
tail under the lease. Strict existing attempt decoding and exact writer encoding
reject unknown versions/keys, malformed owners, duplicate JSON keys, changed
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
covered by authored tests; sudden hardware power loss is not certified. Browser
storage, encryption, retention/compaction and full synchronization remain future
work. No existing journal format, shared contract or dependency changes.

## Verification and remaining composition

New Flutter tests use real disposable files for immutable reopen, interleaved
owners/equal event IDs, concurrent replay/conflict, queued-work close/drain,
incomplete-tail repair, complete corruption/duplicate-key/canonical rejection,
record and byte limits, bootstrap failure and ownership cleanup. A pure Dart
child exits after flush without graceful close; another child must fail to
acquire an active lease. Reopening after release and exact child replay are
checked. The reports are explicitly synthetic local fixtures, not Auth evidence.

Run from apps/flutter_app:

    flutter test test/features/quiz/native_vocabulary_quiz_journal_test.dart

Existing Flutter CI discovers these tests on Linux, including their actual Dart
child processes. This increment does not change the workflow; new-store native
Windows execution remains unverified. Existing Windows build/native checks do
not constitute execution of this new journal. No local execution environment is
available, so all new format/analyze/test results require exact-head Actions.

Parent43094ac2 CI39480610637 latest attempt1 completed all five jobs/every required
step:621 Flutter tests (including all16 history-model cases), five Chrome tests,
retained native/process/SQL checks, Web and Windows release builds/artifacts.
This verifies the parent models, not the new store.

After this store passes current-head checks, add captured-ready-session
save/history composition with stale-session fences, storage error/manual retry
and explicit lifecycle ownership. Public /quiz still loses results on exit.
No mastery or server credit. Keep #13 open/#41 draft/default preview and all14
hosted acceptance groups pending. No live activation, merge, deployment or
schedule change.
