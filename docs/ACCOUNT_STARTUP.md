# Explicit account startup host

`AccountStartupController<T>` owns one async factory and its runtime. `AccountStartupApp`
captures that controller for its widget lifetime. Caller creates a fresh
`PersistentAccountStartup(PersistentSupabaseRuntime(...))` in the factory using
trusted configured origin/public key, the Windows vault and durable review store.
No secrets are read from widget/navigation state. Default main/provider remains
unconfigured; no browser persistence or service settings are activated.

Before start completes, the account override/app router is not installed. The
host shows a loading screen. Success opens the existing account route, whose
profile/study barrier remains authoritative. Failure shows fixed Vietnamese text;
raw exceptions never become UI state/logging. Restore failure can explicitly
open login only when the adapter reports failed persistence, null accepted session
and no study runtime. That login keeps the same runtime and existing explicit
failed-state cleanup. Factory failure offers only explicit startup retry.

Retry serially closes the prior runtime before constructing another. Cleanup
failure blocks replacement and is visible; no automatic retry/backoff occurs.
Close revokes publication, drains pending factory/start and then closes the late
owner. Caller must await close before replacing project/configuration or assuming
cleanup complete. The widget also starts cleanup on disposal; a fixed
`onCleanupFailed` callback allows the host to report failures without raw details.
Factory errors before returning an owner must clean any partially constructed
resources themselves. The provided store remains caller-owned; host does not
delete user journals or sign out a successfully preserved session.

Controller identity/configuration is captured once. Replace the widget/controller
only after awaiting old close; changing constructor fields on the same widget
identity does not authorize a new project. No timeout pretends late Auth stopped;
existing SDK per-attempt bounds/retry policy remain. This is configured-host UI,
not automatic service configuration, hosted identity proof or refresh scheduling.

Eight controller tests cover publication, explicit fenced login, factory retry,
close-before-replacement, failed cleanup, late factory/restore and safe close
retry. Four widget tests cover loading/error/login, actual account route wiring,
320px/200% text and unmount with late completion. These fixtures are TEST ONLY;
source evidence is recorded below. Existing OS/SQL/security and all 14 live release
gates remain; keep #37 draft. Next explicit refresh scheduling and configured
hosted learner acceptance.

## Verified source evidence

Source `9388b5813d3c3eacf727f8fae7eec5cd388f070a` passed all five jobs in
https://github.com/collab-TTAM/nihongo_daily/actions/runs/38593010698 .
Observed 324 Flutter tests (eight controller/four startup widgets added), five
actual Chrome tests, format/analyze, retained real Windows vault/runtime process
probes, native journal/SQL/wire/security gates and web/Windows release artifacts.
Raw run/latest-attempt metadata passed exact-head/every-required-step QA.
The configured UI tests use explicit fake owners/Auth/profile, not hosted learner
identity or UI-to-OS restart acceptance. Default main stays unconfigured.
Follow-up source only enclosed retry's multiline guard in a lint-compliant block,
without changing conditions/assertions. Evidence is historical for later commits.

The ordinary application entrypoint can now select the owned host through trusted
Windows staging build settings. STAGING_BOOTSTRAP.md documents configuration,
project-scoped OS app-data journal ownership and observed empty-vault native
assembly/build evidence. Default remains preview; no hosted learner proof.

## Cancelable window close

The owned host observes didRequestAppExit and awaits controller.close before
returning exit. Publication is revoked immediately; while factory/start/cleanup
is pending, only a fixed Vietnamese closing screen is shown. Concurrent close
requests share one drain. The router stays mounted while the binding awaits
its exit-observer snapshot; the account override becomes null and routes are
offstage with focus/tickers blocked. This prevents disposal of another pending
framework lifecycle listener during the drain. Account form fields also remain
mounted, offstage/disabled/unfocusable when login is unavailable; state/notice
listeners still clear their controllers. EditableText owns lifecycle listeners,
so preserving only the router was insufficient. No hidden route can grant study. Cleanup failure returns cancel and a fixed redacted
message; login/startup retry stay unavailable. A later explicit window-close
request can attempt the same retained owner's cleanup again, never a replacement
SDK or a new login. A failing underlying owner is not assumed repaired.

The pinned Flutter 3.35.4 Windows engine routes WM_CLOSE for the final process
window through RequestApplicationQuit. The unchanged runner forwards window
messages to that engine. No custom native close bypass, extra dependency, timer
retry, forced-exit timeout or deletion of learner history is added. Disposal
continues to start async cleanup but is not treated as awaited shutdown evidence.

Four additional widget tests dispatch framework exit requests and cover a delayed
drain/concurrent requests, redacted cancellation/explicit retry with accessible
layout, late factory and late restoration. Windows TEST ONLY phases launch the
actual runner with an empty-vault staging owner. PowerShell waits for a native main window after Dart frame completion, sends
CloseMainWindow,
checks the process stays alive until an external test marker releases cleanup,
and checks successful owned close plus journal-lease reopen before natural exit.
A synthetic one-shot close failure must cancel the first actual window request;
a later explicit close finishes. GUID .invalid scopes and finally cleanup remain.
Verified source evidence is recorded below; these checks do not prove hosted
Auth or saved learner sessions. Uncancelable termination, Task Manager kill, power loss and OS
logoff can bypass the hook. Durable write-before-dispatch remains essential and
is unchanged; no hook is a substitute for event/credential persistence.

Framework reference: https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver/didRequestAppExit.html
Pinned engine source: engine/src/flutter/shell/platform/windows/windows_lifecycle_manager.cc

## Verified cancelable-close source evidence

Source `2aa94639e99dc38c9af9f5734eba7b47c52a3469` passed all five jobs in
https://github.com/collab-TTAM/nihongo_daily/actions/runs/38611061291 . Observed 360 Flutter tests including the four new exit
cases, five actual Chrome tests, format/analyze, all retained native/SQL/wire/
security gates and normal web/Windows preview artifacts. Windows log contains
`Windows actual cancelable window close and owned drain verification passed`.
Both actual CloseMainWindow phases passed process-alive-before-release or
cancellation, same-owner explicit retry, drained empty-vault staging runtime,
reopened real app-data journal lease and natural exit with completion marker.
Configured staging main and subsequent ordinary preview builds also passed.
Raw run/latest-attempt evidence passed exact-head/every-required-step QA.

The retained router/keyed form resolve EditableText listener disposal while the
binding awaits its copied observer list. Test asserts same router/password widget
identity, null account override, disabled/empty password controller, focus
exclusion and no visible fields, plus both concurrent exit responses and no
framework exception. No original assertion, lint or security gate was weakened.
Local format/49 contracts/17 QA passed; 257 source blobs were preserved/verified.

This is empty-vault actual OS shutdown and explicit UI fixtures, not hosted Auth,
confirmed logged-in learner rotation/restart, OS logoff or power-loss proof.
All 14 release groups remain pending. Following evidence/QA documentation
successor has separate CI; this source-head evidence is historical for later
commits. Keep #37 draft and #20/#22/#15 open.


## Exit fixture marker publication correction

On integration source `72e984a8b24cde8e11ccff1babb927561dcf2296`, CI39412500938
passed the Windows app-data, Dart/native bridge and persistent-runtime probes,
then failed with `Windows exit marker invalid`. Inspection identifies a race:
writing directly to the final marker name lets the existence-based reader open
it before the asynchronous writer has finished. The failing log does not capture
the partial payload; this cause is inferred from the publication sequence.

TEST ONLY Dart signals now write/flush/close a same-directory `.publishing` file,
validate the exact payload and rename it to the final name. PowerShell's release
signal likewise closes a pending file before moving it. Dart also validates the
received release payload. One fixture writer owns each target; this is not a
multiwriter journal or a general atomic replacement contract. Strict PowerShell
payload rejection, deadlines, real CloseMainWindow requests, alive-before-release,
cancellation, same-owner explicit retry, drain, lease reopen and natural-exit
assertions remain unchanged. No corrupt-marker retry, timeout increase or skip.

Four real disposable-file regressions exercise held empty publication, repeated
partial staging without truncating the prior final, invalid payload rejection and
failed-write cleanup. Direct pinned Dart execution on Linux and pure analysis
passed. Normal Flutter test discovery includes these four cases; actual Windows
PowerShell/runner behavior and the full updated suite require exact-head Actions.
No local PowerShell or full Flutter execution is claimed. Application runtime,
Auth, SDK, vault, learner journal and guide behavior are unchanged.
