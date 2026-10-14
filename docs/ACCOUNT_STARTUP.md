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
