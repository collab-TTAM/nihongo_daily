# Owned persistent session lifecycle

`PersistentSupabaseRuntime` explicitly creates and exclusively owns a new pinned
Supabase SDK client, review binding, persistence access and account controller.
The caller supplies the trusted project URL/public key and matching credential
vault, then awaits `start()` before installing `runtime.account` into the existing
account provider. A failed start returns a fixed safe error; caller must show a
restore failure and offer explicit login, which first cleans failed storage/SDK
state. Never put secrets in Riverpod state, journals, profile fields or logging.
No application startup configuration or default runtime activation is added.

The assembly validates endpoint, public-key shape and canonical vault target
before creating the client. Web is rejected because the pinned SDK broadcasts
Session objects across tabs; this component does not authorize browser token
storage/restore. The existing Windows vault is the implemented OS backend.
Other platforms still fail unavailable through that backend. Mock backends in
tests are not alternate production stores. No dependency/provider/Auth strategy,
production deployment, RLS, migration or frozen API contract changes occur.

## Readiness and ownership

`PersistentAccountAccess` is the account Auth port. `start()` reads only the
refresh secret and invokes SDK `setSession(secret)` without an access token,
requiring a server refresh. No session JSON/local access JWT is reconstructed.
The exact current rotated refresh secret must be successfully written before a
ReviewSession is exposed. The existing own-profile barrier then grants study
access. Secret strings remain private internal operational data; public phases
and account state contain no credentials. SDK logs are disabled before client
creation. Auth HTTP accepts only same-origin Auth/REST paths, disables redirects,
limits responses to 1MiB and bounds the full headers/body attempt to 15 seconds.
Timeout/oversize/transport failures are fixed safe errors. A late timed-out
response cannot reach the SDK; the late response stream is cancelled.

The SDK and its mutation methods stay private. SDK automatic refresh is disabled;
`refresh()` is explicit and applies the same persistence barrier. No automatic
refresh timer or retry loop is installed. Caller must refresh before expiry;
expiry itself revokes review access and clears the persisted secret via the
binding event. A long-lived configured app still needs separately tested refresh
scheduling. SDK rotation signals are observed independently of review lifecycle
signals because the review binding preserves identity on same-session refresh.

One active persistence owner is allowed per canonical project target in this
Dart isolate. Closing drains operations before releasing the owner slot. This
is not cross-process CAS/locking; caller must not run competing same-project
credential writers in multiple application instances. Credential Manager remains
OS-user scoped. Server verification is authoritative; decoded JWT hints are only
fail-closed client checks. No memory-zeroization claim is added for Dart strings.

## Logout, failure and shutdown

Logout revokes readiness before awaiting anything. SDK sign-out and credential
clear are both attempted even when one fails. Clear is ordered after any already
running write. Generation/session/secret guards prevent old queued writes or
responses from granting access. Logout/disposal during an Auth request keeps the
gate fenced and cleans again after that request settles, including SDK logout
failure followed by late sign-in success. Explicit retry is required after errors.

Every session rotation/account change revokes the old persistence gate until the
new secret is saved. No profile or study request is issued through the account
runtime before that barrier. Getter checks also reject a changed SDK identity or
secret before queued notifications are delivered. Failed writes fence access and
attempt credential clear. Clear failures remain visible as failed persistence;
later explicit login/logout must clean successfully before accepting a session.
Storage read errors preserve the existing entry until an explicit cleanup/login.

Await `runtime.close()` before replacing the assembly. It revokes access, disposes
the account controller, drains interrupted Auth/credential operations, cancels
subscriptions and disposes only owned SDK/network resources. A fully saved
session is preserved for the next startup; interrupted Auth is cleaned. Supplied
HTTP clients remain caller-owned. The controller/provider's disposal alone does
not close this assembly. Neither close nor local logout promises all-device
revocation, OS-logoff/power-loss recovery or protection from same-OS-user processes.

## Reproduction and separate review

In `apps/flutter_app`, run `dart run tool/verify_session_lifecycle.dart` and
`flutter test`. Twenty pure cases cover empty/refresh startup, persistence
barriers, same-session rotation, account switches, older in-flight writes,
logout during write/restore/login, storage/read/clear/SDK errors and explicit
retry, revocation, owner exclusivity, stream closure and disposal. Six pinned-SDK
HTTP cases cover refresh-only startup/profile ordering, explicit rotation/logout,
late restore, rejected stored token recovery, log/scope checks and timeout.
Both SDK HTTP and OS storage here are TEST ONLY ports, not hosted login proof.

The existing actual Windows Credential Manager/process probe remains mandatory,
but it does not exercise this assembly's Dart-to-native bridge. Existing SQL/RLS,
profile races, Chrome, native disk, security, wire and release-build checks remain.
Current-source CI must pass; historical previous-source success is insufficient.
All 14 live Personal Alpha release groups remain pending. Keep PR #37 draft and
#20/#22/#15 open. Next: interactive Windows bridge/restart, hosted Auth learner
acceptance, caller startup/error UI and refresh scheduling.

Separate review checked persist-before-profile, no old credential fallback,
SDK ownership and log timing, exact project scope, callback-safe logout, clear
ordering, asynchronous late-result cleanup, failed-state retry and close draining.
Pinned SDK source inspected locally: supabase 2.16.5/gotrue 2.27.3 setSession,
refreshSession/session-version guards, signOut and callback/logging behavior.
Tests do not prove hosted JWT signatures, account/device isolation, real token
expiry/rotation windows, native interactive launch or production safety.
