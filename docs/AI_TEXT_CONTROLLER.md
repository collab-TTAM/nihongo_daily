# Captured AI text view controller — Issue #17

`AiTextController` is a pure Dart prerequisite for the tutor/correction UI. It
borrows one `CapturedAiTextRepository` belonging to one ready generation; it owns
no SDK, HTTP, credential store, provider configuration or durable state. Missing
capability starts unavailable and never synthesizes a response. No app route,
Riverpod provider, main or staging activation is changed by this increment.

Only explicit `explain` or `correct` dispatches. N5/N4 view scope is enforced
without changing the five-level frozen wire models. Existing DTOs validate exact
text and Unicode limits; whitespace is retained. Loading clears the previous
result. A successful state contains exactly one typed explanation/correction,
accepted text, operation and level, allowing the view to label the accepted
request even if the learner later edits a draft. Empty correction arrays remain
empty; there is no invented learning error, saved progress, mastery or plan credit.

Unavailable, idle, loading, success, error and local pending are distinct. Local
registration precedes readiness/transport callbacks to block cross-method taps and
synchronous reentry. An externally busy repository is also respected. A timeout
can finish the result wait while the underlying wire remains busy: subsequent
explicit attempts report pending, never overlap or automatically resend. Reading
availability, clearing a settled result, drain completion and notifications do not
retry. Explicit `recheck()` publishes availability only so a pending view can
observe a settled wire without polling or resending. The controller stores no
retry request. Another explicit submission is a
new text operation and may incur a new provider invocation; there is no text
receipt, cancellation/remote rollback or zero-cost guarantee.

Failures contain fixed safe codes/messages from the repository, never raw
Auth/provider/HTTP error text. Invalid input gets VALIDATION_FAILURE; malformed
output/unknown exceptions get INTERNAL_ERROR. UNAUTHORIZED permanently disables
this controller. Retryable metadata describes the error, not permission to replay
a request automatically. Clearing a busy view is refused; it is not cancellation.

The owner/host must call `invalidate()` synchronously on readiness loss and mount
a fresh controller for a fresh ready capability. `state`, `canSubmit`, explicit
availability checks and request completion also check the captured repository.
Readiness loss, session replacement including A/B/A, getter failure, explicit
invalidation or disposal clear accepted text/results immediately and permanently.
Late success/error cannot publish. A supplied availability stream is an additional
hint: data checks the current lease, errors/closure disable the view. It cannot
replace the synchronous owner fence. The existing runtime owner still independently
revokes/drains its transport; controller disposal never closes or revokes borrowed
resources or manufactures a fresh repository.

Changes are asynchronous void hints rather than text/state snapshots. A consumer
must read current state when processing a notification, not render a previously
cached snapshot. Disposal cancels its own subscription and closes notifications
without waiting for a paused UI listener. The host must also clear text-editing
controllers/drafts, invalidate on level/source replacement as appropriate and
perform mobile/accessibility/widget tests when the screen is assembled. This
component alone is not an account-aware mounted screen or a live tutor.

Fresh official Dart3.9.2 archive/checksum matched. The identical six-library/four-
test graph and original frozen fixture bytes, with only flutter_test import
adapted to package:test1.26.2, passed 78 tests:20 new controller +58 unchanged
models/repository/owner cases. Strict casts/inference/raw types and lints6.0.0
focused analysis is clean. New source/test pinned format has zero changes;
formatter warned the app Flutter lint include was unavailable (not analyzer proof).
QA inventory84 and46 regressions passed separately. No local full Flutter/widget/
build/SDK graph or hosted proof. New exact-head Actions remains required.

Tests cover unavailable/default no dispatch, exact request/accepted level/typed
result and empty corrections; duplicate/reentrant taps; invalid text/level/Unicode;
old-result clearing and malformed/safe errors; no automatic replay; external and
timeout-held wire busy; late success/error and A/B/A; readiness/getter failure;
401; void notifications/stream error/closure; paused listener/idempotent disposal
and preserved borrowed lifetime; fresh capability required after account change.

Parent5c3e58a CI40025398321 attempt1 passed every step in allfive jobs:871 Flutter,
five Chrome, eight owned SDK/runtime/vault/profile/AI HTTP tests,19 owner tests and
Windows/native/SQL/Edge component checks. This is verified parent evidence, not
new-head or hosted JWT/provider/voice/learner acceptance. All14 release groups stay
pending. Next: exact new-head CI, then Riverpod/route/screen assembly with explicit
unavailable/loading/error/success, safe plain-text rendering, request-bound draft
controls, synchronous owner clearing and 320px/large-text tests. Existing approval
and provider/collection/spend gates remain; default AI remains disabled.
