# Captured-connection lifecycle boundary — Issue #22

This is dependency-free **process-local readiness**, not a Supabase SDK/Auth
implementation. The app's default runtime stays null. No login, credentials,
profile provisioning, token persistence/refresh, HTTP endpoint or deployment is
enabled. A UUID/expiry hint never authenticates the caller; the real SDK and
server JWT/PostgREST/RLS boundary remain #20/#22 acceptance. #15 owns durability.

## Binding contract

`ReviewConnectionRegistry` implements the existing ReviewAuth and
ReviewRpcTransport ports. The future trusted Auth binding must call:

- `begin(userId, expiresAt, rpc)` for a fresh authenticated lifecycle, including
  another login by the same account. It always replaces the identity hint.
- `refresh(...)` only for token refresh within the **same active lifecycle**.
  It replaces the captured dispatch closure/expiry but preserves identity and
  pending immutable reviews. Invalid/different-user/expired refresh revokes the
  old identity; it cannot silently log in another account or revive expired work.
- `end()` synchronously on logout, Auth failure/closure or lost identity.
- `dispose()` when the owner shuts down: clear state, cancel expiry and close
  notifications. Disposed registries cannot begin/refresh or accept late results.

Supply a closure over that session's **captured authenticated credentials**, not
`sharedClient.rpc` which may choose a different current account later. The registry
captures and invokes the supplied closure without redirecting it on refresh.
It cannot inspect or prove the closure's credential behavior; a real SDK binding
must implement/review/test that contract. No token fields are exposed or logged
by this registry, but the owner must safely dispose any credentials/client held
by its closure. This does not supply a secure credential store.

The local session is checked before dispatch, again after copying the envelope,
and after success/failure. Old results cannot become current-user results even on
A -> B -> A. An ordinary same-lifecycle refresh permits an already-dispatched
old-token result; subsequent requests use the new closure. There is no automatic
redispatch, renewal, login fallback or fake success/empty queue.

## Expiry, UI and limits

Expiry is checked on access/dispatch and by a cancellable timer. Notifications are
synchronous so the existing controller immediately hides old content/receipts.
Browser timer delays are capped at 24 hours and re-armed for long lifetimes;
backwards clock movement is rechecked rather than expiring early. The server
still decides actual expiry/authorization. Client wall-clock checks are defensive
UI/dispatch hints, not proof of JWT validity. A lost Auth event must explicitly end
the binding; no listener to real SDK events exists in this increment.

Only submit_review/get_review_queue with exactly one p_request and each operation's
existing flat field names can dispatch. The copied request is immutable, ownerless,
finite and <=32 KiB encoded UTF-8. Repositories/server still validate values and
semantics; this is not a new payload schema. Recognized safe transport failures
are preserved, unknown exceptions become INTERNAL_ERROR and timeout remains an
uncertain NETWORK_UNAVAILABLE. No raw exceptions, URL/headers/token/SQL are logged.

`createSessionBoundStudyRuntime` explicitly assembles the real typed repository,
queue projection and notifier lifecycle stream around the same registry. The
caller owns binding/disposal. This factory is not installed into the default app.
In-memory retries surviving navigation do not establish offline/restart recovery.

## Reproduce and evidence

From apps/flutter_app:

```bash
dart run tool/verify_review_connection.dart
flutter test test/features/srs/review_connection_registry_test.dart
```

All captured dispatch closures/responses in these checks are **TEST ONLY**. Tests
cover refresh/re-login/A-B-A, invalid/expired events, proactive timer clearing,
old timer cancellation, immutable envelope/limits, redacted failure, in-flight
result rejection, disposal and runtime assembly. CI retains every existing
format/analyze/test/native SQL/build gate and adds the pure lifecycle verifier.
Baseline success is not live SDK/JWT/profile/HTTP/learner or release evidence.

Local Flutter dependency bootstrap was blocked by runtime policy after attempting
an unrelated cloud metadata endpoint. It was not retried or bypassed. The bundled
raw Dart executable can run the dependency-free verifier/analysis; full Flutter
and builds are separately observed through GitHub Actions. No secrets are needed
for these independent tests. The next SDK increment must resolve/pin dependencies
in an approved environment and preserve enforce-lockfile CI.
