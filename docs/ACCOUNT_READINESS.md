# Account and own-profile readiness

The `/auth` route uses an explicitly supplied account runtime. With no override,
the preview states that sign-in is unavailable and shows no credential form.
`createSupabaseAccountRuntime(binding, store: optionalStore)` assembles the
existing captured SDK transport, typed own-profile bootstrap and study ports.
The caller owns the controller, binding, SDK client and optional store lifecycle.
Install the controller with `accountRuntimeProvider.overrideWithValue(...)`.
This source does not initialize a service, configure providers or persist tokens.

## Profile barrier and account changes

After a trusted SDK session arrives, `AccountController` clears the prior runtime,
loads `ensure_profile`, checks the same captured session and matching owner, and
only then exposes a ready study runtime. That runtime uses a readiness-gated Auth
port for queue reads and review preparation/dispatch. Generation and session
checks discard late profile responses. Account changes, expiry notifications,
closed/error lifecycle streams, logout and disposal clear the gate. Existing
study controllers receive immediate lifecycle notifications to clear visible data.
Profile failure offers explicit retry; there is no automatic profile retry.

Logout revokes access synchronously before dispatching SDK local sign-out. The
SDK call awaits the active synchronous callback's return to avoid stream reentry.
Failure remains fenced with a safe retry message. A sign-in that settles after
logout is cleaned up by another local sign-out and cannot publish ready state.
Local sign-out does not revoke all devices' sessions or undo committed reviews.
The captured transport still rejects an old SDK lifecycle after account change.

## Credential handling and scope

The configured form submits email/password through existing SDK functionality,
obscures the password and clears both input controllers before dispatch, when
leaving the form, and on disposal. Credentials are transient method arguments,
never account state, navigation data, journal records or profile metadata.
SDK Auth responses/tokens do not escape through credential methods. Exceptions
become fixed Vietnamese UI messages. This does not guarantee memory zeroization
or override the caller's SDK storage policy. Existing SDK logging-off policy is
retained. Duplicate submissions are suppressed; no controller automatic login
retry is implemented. Registration, reset, OAuth/provider setup and secure token
storage/restore remain separate work. No new dependency, Auth configuration,
production deployment, RLS grant or API wire change occurs here.

The legacy explicitly supplied study factories remain available for existing
callers/tests; the application provider now obtains its default study runtime
from account readiness. Those lower-level factories do not provision a profile.

## Verification and separate review

Run `dart run tool/verify_account.dart` and `flutter test` in `apps/flutter_app`.
Ten pure scenarios cover profile barrier, invalid/duplicate credentials, retry,
account changes with late profile, logout failure, late sign-in, closed lifecycle,
reentrant revocation and disposal. Five widget cases cover the default route,
credential clearing, readiness-to-study wiring, safe retry/logout, and 320px at
200% text. Two additional actual SDK/mock HTTP tests exercise configured assembly
and disposed credential methods. HTTP uses unsigned TEST ONLY identities; these
are not hosted login, JWT signatures or secure restoration evidence.

Separate review checked immediate gate invalidation before async work, retained
dispatch capture checks, profile-owner/session validation, no credential state,
redacted failures and default-unconfigured behavior. Existing disk/browser/wire/
SQL/security gates remain required. QA records the account baseline separately;
all 14 Personal Alpha integration cases remain pending. Keep PR #37 draft and
#20/#22/#15 open. Next: explicitly configured secure session lifecycle/restore,
then hosted A/B, expired JWT, restart and two-client learner acceptance.
