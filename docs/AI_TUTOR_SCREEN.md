# Injectable text tutor screen — Issue #17

`/ai` now renders AiTutorScreen. With the null-default aiTextViewBindingProvider,
it returns exactly the previous unavailable FeaturePreviewScreen/title/description;
existing route and mobile smoke assertions remain unchanged. No SDK, Auth, public
key/URL input, network or paid provider is installed or enabled by navigation.
Main and Windows staging retain aiTextEnabled=false. Hosted/voice and release
acceptance remains open.

A trusted host may explicitly inject AiTextViewBinding containing one repository
from the owned runtime's ready factory and optional availability notifications.
Binding acquisition must issue no request. The binding is immutable and must be
removed/replaced after a readiness barrier or account change; never retarget an
existing binding. The actual owned-startup source/provider bridge is next work,
not implemented by this view-only increment. Injected fixtures are TEST ONLY.

The binding identity keys a mounted view. That view owns its ephemeral controller,
editor, focus node and notification subscription, borrowing the repository. It
subscribes to captured availability, reads current controller state rather than
old notification snapshots, clears/unfocuses drafts on revocation and disposes
private state when the source is removed/replaced. Runtime ownership must still
synchronously revoke its capability and remove/replace the binding on readiness
loss; the screen does not close SDK/HTTP or assert remote request cancellation.
Read-time lease fences cannot replace actual host lifecycle integration.

The screen offers N5/N4 and explain/correct controls. Only explicit send dispatches;
initial mount, choosing, edits, clear and manual status recheck do not call AI.
Pending work disables editing/selection/clear/send. An externally busy borrowed
repository also exposes a manual status recheck, without polling or auto resend.
A request-bound callback captures view revision/level/mode/text and rechecks all
of them before dispatch. Edits, clear, selection changes and source replacement
fence retained callbacks, including callbacks from an unmounted old-account view.
Level/mode changes clear drafts and results. Prior results also clear on editing
or the next request; response labels use the accepted level/text.

Input preserves whitespace and enforces the frozen 5000-code-point bound before
accepting edits, with an early UTF16 bound; it does not confuse grapheme count with
wire code points. Empty/whitespace-only drafts cannot submit. There is no URL/key
field, transcript persistence, history, learning-error/SRS/plan/mastery write or
simulated save. Error messages are fixed safe strings. The manual send warning
explains that another text operation may invoke a provider anew; no text receipt,
remote rollback or zero-cost guarantee is inferred.

Typed tutor answers/examples/readings/translations/practice and sentence
corrections are rendered through ordinary Text widgets. Model output cannot create
HTML, Markdown links, scripts, routes or widgets. Empty correction arrays produce
an explicit "no errors returned" message rather than fabricated corrections.
Outputs are labeled reference results not saved progress. Voice is explicitly
unavailable. Loading/error/local pending and missing/revoked capability states
remain distinct; no fallback answer or automatic retry is installed.

Fifteen widget cases are authored, **not run locally**: unchanged null preview,
explicit exact explanation/result fields, N4 correction/empty errors, held request
controls/duplicate tap, safe failure/manual recheck, malformed/literal output,
edit/level/mode callback fencing, revoke/editor clearing, late success/error after
A-to-B binding replacement, source removal/borrowed lifetime, Unicode input bound,
external busy status recheck and320/375px at200% text with result/error states.
Original app route/mobile tests are unchanged. New exact-head Flutter CI must
confirm analyzer/widgets/full suite/Web/Windows; formatter success is not execution.

Fresh official Dart3.9.2 archive/checksum matched; four changed Dart files format
clean. The formatter warned that the unresolved app Flutter lint include was
unavailable; no local full analyzer/Flutter/widget/build claim. QA inventory85 and
46 QA regressions passed. Parentfcd0861 CI40032646839 attempt1 passed allfive jobs/
every step:891 Flutter/five Chrome, including20 controller cases and retained
SDK/runtime/native/SQL/Edge components. This is parent evidence, not new-head or
hosted learner proof. All14 release groups stay pending.

Next review exact new-head CI and fix real diagnostics retaining assertions. After
full green, connect the explicit startup/ready-generation source to this binding
with actual owned SDK/vault/profile/UI fixtures covering refresh/logout/A-B-A/drain.
Keep defaults off and retain hosted Auth/provider/collection/spend/security gates;
no approval or live credentials can be inferred from an injected successful widget.

## Owned startup source bridge

AiTextRepositorySource now exposes the existing no-request captured factory and
credential-free availability stream. PersistentSupabaseRuntime implements it;
PersistentAccountStartup forwards it without exposing SDK/HTTP/tokens. Startup
controller publishes this borrowed source only while active and not closing, and
AccountStartupApp overrides a null-default aiTextRepositorySourceProvider.
The existing aiTextEnabled=false default/main/staging settings remain unchanged.

The public view-binding Provider retains its previous override API. Internally a
StateNotifier listens to the borrowed source stream and account-state changes.
Account changes independently retry acquisition because the first ready runtime
may have no AI lease to notify yet. The actual factory still enforces persisted
session/own-profile readiness, generation and old-work drain. Same current
repository identity preserves the binding/editor across unrelated availability
hints. A missing/revoked/replaced capability clears/replaces the binding, causing
the keyed screen to dispose old private state. No factory event sends text.

Stream subscription/getter failures and stream termination fail closed; factory
exceptions expose null with no raw details. Subscription is owned by the notifier,
while SDK/source/repository remain borrowed. Reentry is guarded and notifications
are sampled against the current captured capability. This bridge does not replace
the runtime's synchronous revocation fence or prove a hosted service is configured.

Nine source/notifier/startup fixture cases are authored, unrun locally. They cover
missing source, cached identity/no request, ready-null/new-account transitions,
revoked/failing factory, broken stream getter, stream error/done, borrowed disposal
and active-only startup exposure before/after held start/close. Full new-head
Flutter analyzer/test/build is required. Next add actual owned SDK/vault/profile
startup-to-mounted-tutor refresh/logout/A-B-A/drain journey tests. Defaults remain
off and all hosted/Auth/provider/collection/spend/voice gates stay open.


## Actual Windows owner and mounted SDK journey

The WindowsStagingOwner lifetime wrapper now implements AiTextRepositorySource,
forwards the existing availability stream and delegates the captured factory only
while not closing. The prior runtime/startup/provider bridge omitted this outer
production wrapper: a controller holding the Windows owner could not publish its
source even with an explicitly enabled runtime. No build setting, default flag,
provider activation, URL/key input or resource ownership changes accompany this fix.

Eight expanded widget cases in ai_owned_startup_journey_test.dart exercise the
actual pinned SDK, NativeReviewJournal, WindowsStagingOwner,
PersistentAccountStartup, AccountStartupController, AccountStartupApp, default
Riverpod bridge, router and mounted tutor. No view/source/account provider override
manufactures readiness or an AI result. Only Auth/REST/AI HTTP and vault backend
ports are TEST ONLY. File/runtime operations use tester.runAsync and bounded
completion barriers so FakeAsync does not wait for filesystem futures.

The fixtures hold startup rotation and own-profile responses independently; assert
no factory capability/text dispatch before both; and send exact whitespace/context
and captured bearer through the real mounted explain control. Refresh cases hold
old HTTP despite abort, verify synchronous runtime revocation and retained callback
fences, persisted/profile barriers, no new allocation until old success/error drains,
fresh empty editor and explicit N4 correction with the new bearer. A-B-A checks
completed A result removal, held B error drain, fresh A capability and retired A/B
callbacks. Storage/profile failures remain unavailable until explicit recovery,
which submits no text. Disabled host remains unavailable. Owned close removes
source publication immediately, then revokes/drains the runtime before journal
cleanup while preserving the saved vault secret and borrowed HTTP client.

Parent093baab CI40053492651 attempt1 passed allfive jobs/every required step,
915 Flutter tests including allnine source cases and existing15 tutor widgets,
plus five Chrome cases and native/Windows/SQL/Edge checks. This confirms prior
components, not these new eight cases. New cases are authored, UNRUN locally;
fresh exact-head analyzer/Flutter/platform CI is required. Fresh pinned Dart
format and QA inventory/regressions are recorded in PROJECT_STATUS.

Fixtures do not verify hosted JWT signatures/TLS/provider/learner flows, real
Windows credential storage or physical app launch. Main/staging AI remain off,
voice unavailable and all14 hosted release groups pending. After exact new-head
CI, continue reviewed remaining #17 integration gaps without inferring live
provider/collection/spend approval or bypassing Auth/release gates.


## Owned journey fixture cleanup correction

Exact12e8de5 CI40058196322 attempt1 passed format/analyze and allfour other
jobs/every step, but Flutter tests reported916 passed/seven failed. The first
actual SDK/Windows-owner/startup-to-mounted-tutor rotation/profile/explain case
passed. Each following journey failed at runtime construction because the shared
fixture project still had an exclusive vault owner. Those seven paths were not
executed successfully; downstream Flutter/Chrome/native/Web steps were skipped.

The fixture now uses a widget-test-body try/finally wrapper for every case. It
awaits real-loop owned runtime/journal cleanup before returning from that body and
before automatic widget disposal can initiate close from FakeAsync. It additionally
asserts PersistentAccountAccess.isTargetOwned is false after cleanup. All eight
expanded cases, operations, service ports and existing assertions are preserved.
Production lifetime/locking, default AI flags, scope and security are unchanged;
no unique-project workaround, owner-set reset, skipped test or timeout increase.
New exact-head Flutter CI must verify corrected cleanup and all eight journeys.
The correction is formatted locally; no new local Flutter execution is claimed.
