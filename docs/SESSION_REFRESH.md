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
New-source full CI is pending; no hosted rotation/device/OS suspend proof. Existing
Windows probes, native/SQL/Chrome/security gates and 14 live release integrations
remain mandatory/pending. Keep #37 draft.
