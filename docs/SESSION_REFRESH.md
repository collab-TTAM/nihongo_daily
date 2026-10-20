# Opt-in owned session refresh scheduling

`PersistentSupabaseRuntime(automaticRefresh: true, ...)` installs one scheduler
inside its exclusively owned SDK/persistence runtime. Default is false; normal
main remains unconfigured. SDK built-in auto-refresh remains disabled. No Auth
provider/strategy/API/schema changes or browser persistence are enabled.

Only an accepted persisted session plus the binding's validated expiry hint
can schedule. The default target is 60 seconds before expiry; dispatch requires
a fresh matching identity/expiry and future expiry. Long timers rearm at most
24 hours; rollback rechecks due time. One attempt per identity/expiry and a
30-second minimum spacing prevent unchanged/very-short-expiry loops. A fresh
rotation/identity may schedule a new attempt. Failed attempts do not create a
retry loop; repeated foreground resumes cannot retry the same lease. Existing
pinned SDK internally retries some transport/5xx refresh attempts; the scheduler
does not change this policy or promise a whole-operation 15-second timeout.

During refresh the existing persistence barrier fences study access, saves the
exact rotated secret and only then allows profile/study readiness. Saving/auth
operations cannot dispatch another automatic attempt; logout/invalid expiry/close
cancel timers. Expired resume never restores an old lease. Stored refresh-secret
startup remains a separate explicit server verification path. Decoded hints are
not JWT signature or server authorization proof. No token enters scheduler state
or callbacks/logging. A safe phase getter is available to configured callers.

The configured startup app observes foreground resume and forwards it only to an
active ResumableAccountStartup owner. Close disposes scheduling before draining
persistence/SDK operations, preventing late rescheduling. Foreground integration
does not guarantee background execution while OS suspends the process. Factory
and supplied journal ownership rules remain those in ACCOUNT_STARTUP.

Twelve clock/timer/lease fixtures cover normal scheduling, logout/stale callbacks,
identity replacement, valid/expired resume, pending operations, failures, unchanged
expiry/short TTL, long timers/rollback, disposal and invalid hints. Two actual
pinned-SDK/mock-HTTP tests cover persistence/profile ordering and fenced failure
without resume retry; one widget test covers forwarding before/after ownership.
Verified source evidence is recorded below; no hosted rotation/device/OS suspend proof. Existing
Windows probes, native/SQL/Chrome/security gates and 14 live release integrations
remain mandatory/pending. Keep #37 draft.

## Verified source evidence

Source `c65528fbea77313f386666c37ab10a1f58efbae0` passed all five jobs in
https://github.com/collab-TTAM/nihongo_daily/actions/runs/38596070841 .
Observed 339 Flutter tests (12 scheduler/two pinned-SDK/one widget added), five
actual Chrome tests, format/analyze, retained actual Windows vault/runtime
process markers, native/SQL/wire/security gates and normal web/Windows artifacts.
Raw run/latest-attempt metadata passed exact-source/every-required-step QA.
Pure scheduler/startup controller type analysis and 49 contracts/17 QA passed
locally. Resume generic boundary now has explicit nonnull/checked-interface
forwarding; no ownership/expiry/assertion/lint/security gate was relaxed.
Scheduler clock/timer/HTTP/lifecycle tests remain fixtures, not hosted Auth or
OS suspension evidence. Source evidence is historical for later commits.

## Explicit owned account action

AccountSessionRefreshAction is a credential-free command port. Only an active
owned startup publishes it into accountSessionRefreshActionProvider; preview
and owners without that capability keep the default null action. The owned
Supabase runtime, persistent startup adapter and Windows staging owner forward
it to the existing persistence.refresh operation. No public SDK mutation port
or learner-selected URL/key is introduced.

The configured account page shows “Làm mới phiên” only with a ready profile and
that action. It clears input buffers, hides study/profile/login controls while
the action is pending, prevents duplicate clicks and keeps explicit logout
available. The port must still save the exact rotated refresh token before
profile/study readiness; UI state itself grants no authorization. No success
simulation, automatic dispatch, new timer or failure retry loop is installed.

An unexpected failure that leaves the same valid ready session shows fixed
Vietnamese text and offers a later explicit click. Actual failed persistence
uses the existing safe notice/login recovery path. A late error after logout,
owner/session change, action replacement or unmount cannot add old feedback.
Form fields remain mounted/offstage/disabled through the existing exit drain.

Nine new action/controller/widget fixtures cover startup capability publication
and exact owner wiring, absent capability, duplicate clicks/delayed profile,
redacted explicit retry at 320px/200% text, logout, account switch, same-session new profile generation and unmount.
Two retained pinned-SDK/mock-HTTP rotation/pending-journal cases now invoke the
credential-free action interface while preserving every vault/readiness/history
assertion. These new-source tests are pending CI, not hosted Auth or OS UI
rotation proof. Existing Windows/native/SQL/Chrome gates and all 14 live release
groups remain unchanged/pending. No N4/content/dependency/provider/schema changes.


## Integration readiness test correction

At integration head ccd006e3, CI39474040443 attempt1 passed format/analyze and
604 Flutter cases; the existing SDK explicit-rotation readiness test failed
because readyRuntime remained null after eight zero-delay flushes. All19 new
quiz cases passed. Downstream Flutter checks were skipped; no full-suite pass.

The persistence refresh Future waits for credential writes; profile loading is
a separate asynchronous AccountController operation. Inference from this source
and the failure: the fixture sampled readiness before the profile operation
completed. Use this file's existing bounded waitForReady helper after login and
after rotation. The saved-secret equality assertion remains immediately after
rotation, before the readiness wait. Every original assertion, pending-vault
revocation check, logout check and five-second helper bound is retained.
No production lifecycle, timeout, retry, SDK, dependency or workflow change.
Correction awaits exact-head Actions; no local execution environment is available.
