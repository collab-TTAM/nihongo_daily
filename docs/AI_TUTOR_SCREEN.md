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
