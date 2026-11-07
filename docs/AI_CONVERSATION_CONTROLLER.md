# Borrowed conversation view controller — Issue #17

AiConversationController is a pure Dart application prerequisite. It borrows one
runtime-retained CapturedConversationSession and optional void availability hints.
Construction/read/recheck/disposal never sends, creates a new flow, closes the
borrowed port/Auth/SDK, revokes its lane, or generates an event ID. Main/staging
flags, routes, App overrides and Riverpod bindings remain unchanged/default-off.
This is not a conversation screen, scenario catalog, live provider or voice flow.

Only explicit start/turn/finish commands dispatch. Start requires notStarted and
N5/N4; turn/finish require active and derive session_id from the captured accepted
projection. Caller supplies a UUID event ID; strict existing DTOs preserve its
case, exact text/whitespace/Unicode and wire fields. Controller never accepts a
caller session/owner/token/endpoint. Local invalid input/phase does not reserve an
event. Loading, ready, safe error, local pending and unavailable are distinct;
conversation phase/projection is separate. No optimistic assistant result or
completion/score/progress/SRS write is invented. Empty summaries stay empty.

Before any supplied availability/port callback the controller reserves its own
submission slot. Duplicate/cross-operation taps cannot replace a command. For a
valid command it retains the original immutable DTO until accepted success or
invalidation. An unresolved flow blocks ALL new commands, including edited text,
new event IDs, finish and another start. Timeout can finish the view wait while
actual work remains busy; no retry is enabled until the captured flow is drained.
Only explicit retryPending resubmits that original DTO. It honors safe retryable
errors; local AiTextRequestPending also allows the identical command after drain.
A nonretryable failure, malformed response or externally held event does not gain
retry permission by pressing another command/recheck or by remounting. No timer,
poll, automatic retry, receipt reset, start-over or new-round API exists.

Disposal clears the controller's retained DTO/projection/error and cancels only
its own subscription; a paused listener cannot hold SDK/resource shutdown open.
The borrowed flow still holds its original receipts/uncertainty. A remount can
read an accepted active/finished projection but cannot reconstruct a lost pending
DTO, retry an external unresolved event, or restart a finished conversation.
This intentionally needs a later trusted recovery/reconciliation/new-round policy;
refresh is not permission to bypass uncertain server work. No durable transcript
or client receipt recovery is claimed. Previous snapshots held by external callers
cannot be erased; hosts must discard them and read fresh state on each void hint.
User-turn transcript/feedback/editor ownership and mounted UI remain later work.

Readiness/session identity, including same-user replacement and A/B/A, is checked
on reads, dispatch and completion. Loss/401/hint error or closure/invalidate/dispose
permanently clears this view; late success/error cannot republish it. The runtime
still independently owns synchronous revocation/drain on its lifecycle barriers.
CapturedConversationSession adds only a read-only isCheckingAvailability hint for
nested view reads: while a supplied getter is active, return a redacted unavailable
view/refuse commands without mistaking its temporary isCurrent=false reentry guard
for permanent revocation of a healthy flow. This flag is not authority: ordinary
reads still require isCurrent and the captured snapshot. Existing flow behavior,
receipts and all prior tests are retained.

21 new injected-port controller cases plus all20 unchanged captured-flow tests
passed in an identical recursive12-file graph with original fixture bytes and
only flutter_test -> test1.26.2 runner adaptation. Fresh official Dart3.9.2 SHA256
matched; strict casts/inference/raw types and lints6 analysis is clean. New tests
exercise exact progression, invalid/Unicode limits, getter/port/tap reentry,
allthree timeout/late-success/error retries with exact DTO identity, edited/new-event
fences, provider/local pending versus nonretryable errors, disposed/remounted
uncertainty, same-user replacement/A-B-A/401/getter loss, stream hints/error/close,
paused listeners and borrowed finished-flow preservation. Initial new-controller
reentry failure was reproduced, then fixed with the additive guarded-read hint;
no existing assertion was removed or weakened. Full Flutter/platform/SDK checks
for this new source still require exact-head CI; local pure tests are not those
checks and no denied Flutter bootstrap is retried.

Parent5313b1e CI40110675068/latest attempt1 passed allfive jobs/every required
step/no skips. Flutter log120921973070 confirms1007 Flutter tests including both
actual-owned startup conversation-source cases, plus five Chrome cases; Web/
Windows/native/SQL/Edge checks passed. These are TEST ONLY component results,
not hosted JWT/receipt/provider/voice/learner acceptance. All14 hosted release
groups and production/Auth/provider/collection/spend/security approval gates remain.
Next inspect exact new-head CI, then guarded source/App binding, mounted UI and
explicit safe recovery/reconciliation/new-round design without default activation.
