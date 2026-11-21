# Conversation workspace composition — Issue #17

ConversationWorkspaceController is a pure application component, not an installed
screen or live activation. It owns ephemeral scenario-selection and conversation
view controllers, borrowing a retained reader/flow and void owner hints. The
trusted host MUST supply both capabilities from the SAME owned ready runtime
generation, provide broadcast owner hints, keep that runtime alive, and discard
old workspace/state on every
readiness barrier. The component does not establish cross-source identity or
replace runtime revocation/transport drain. It creates no SDK/client/storage.

Construction, state, recheck, remount and disposal send nothing and generate no
IDs. Missing either capability permanently redacts both views. Missing trusted
host event-ID factory permits explicit reading/selection but disables new writes.
The future host must install a bounded secure UUID factory; no generator or default
flag/route/App override is installed here. IDs, owner, session, scenario UUID,
endpoint, credentials and recovery mode are never learner command parameters.

Only explicit loading and exact-current-row selection are accepted before start.
A reload/level change clears selection through the existing selector. startSelected
uses that exact row's ID/level, never caller strings or an old equal-ID object.
Backend still authoritatively revalidates active scenario, level and ownership;
public catalog fields/content_version are not authorization or a frozen request
extension. Starting does not transmit the descriptor/version outside v0.1.

New start/turn/finish commands reserve the workspace slot before calling supplied
readiness/event code. Each accepted new command asks the trusted factory once,
then rechecks both views and original selection/session before delegating. Factory
reentry cannot choose/load/start/finish another command; loss/disposal during that
callback sends nothing. Invalid text is checked against the existing typed DTO
before asking for an event; exact whitespace/combining characters/code points are
preserved. Fixed validation/internal failures never display callback exceptions.
The nil UUID used for local text validation is never dispatched or retained.

The retained flow controls phases, shared busy lease and immutable receipt lane.
While active, pending or finished, catalog reload/level/selection/new start stay
blocked. Turn/finish derive only the accepted session ID. Allthree mutation timeouts
hold the original immutable DTO and event; actual I/O must drain before the existing
safe retry policy enables explicit retryPending. Retry generates no ID or edited
text and sends only that original command. No polling/automatic retry/new-round/
reset/receipt abandonment API exists. A nonretryable or externally unresolved event
stays blocked. Disposing drops the view's pending DTO; remount cannot reconstruct
it, start a replacement or erase uncertainty. Accepted active/finished projections
remain borrowed, and a finished flow cannot reopen. Safe durable client recovery
and a reviewed new-round policy remain unimplemented.

Observed loss of either view, same-user replacement/A-B-A, hint error/closure or
disposal permanently clears both public projections/local errors and disables
commands. Late responses cannot republish workspace data. Fresh guarded reads
follow capability checks so a loss discovered by a later getter cannot return an
earlier text projection. CapturedConversationScenarios adds only the read-only
isCheckingAvailability hint (matching the existing flow hint): nested reads from
either supplied readiness getter redact/refuse commands without falsely revoking
healthy borrowed capabilities. This is no authority grant; ordinary reads and
dispatch still use existing captured identity/readiness checks. Previously returned
immutable snapshots cannot be erased: the host must reread/discard on each void hint.

Disposal closes only owned views/subscriptions/void stream. It never revokes,
closes or resets borrowed reader/flow/Auth/transport/SDK. No user transcript cache,
feedback writer, study time, mastery, SRS/progress save, voice or provider success
is invented. Summary recommendations remain read-only and not saved by this code.

22 new TEST ONLY pure cases use actual captured reader/flow/receipt logic with
injected Auth/read/mutation ports and unchanged frozen fixtures. They cover missing
pair/factory, explicit N4 progression/exact text/session/events, finished remount,
foreign/stale row/level fences, allthree timeout late-success/error exact retries,
disposed unresolved remount, invalid text/factory/IDs, each-side and same-user loss,
hint error/closure/borrowed disposal, synchronous factory/getter reentry, loss during
ID generation, held read/unmount and loss at each later readiness check. All22 plus
strict source analysis passed using identical source/test bodies with ONLY
flutter_test -> test1.26.2 runner adaptation, fresh official Dart3.9.2 SHA verified.
Full local Flutter/widget/SDK/platform builds are unrun; exact-head CI is required.
These port fixtures are not hosted JWT/PostgREST/RLS/provider/recovery/voice proof.

Parent bc62c8a CI40168397758/latest attempt1 passed allfive jobs/every required
step/no skips. Flutter log121094353973 confirms1125 Flutter tests including all20
prior selector cases, five Chrome tests and retained builds/native/SQL/Edge gates.
All14 hosted learner release groups remain pending. Keep #41 draft/#17 open/AI off.
Next exact new-head CI, then a guarded mounted workspace UI/host pair/event-factory
binding and explicit error/pending/manual-retry controls, keeping uncertainty and
finished-round fences. No default activation, provider/Auth strategy, broader
collection/spend, security reduction, merge/deploy/release or Alpha acceptance.
