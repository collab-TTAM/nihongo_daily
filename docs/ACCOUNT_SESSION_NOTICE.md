# Safe account session notices

The configured persistent runtime publishes only `none`, `checking`, and
`needsLogin`. It maps owned persistence phases to these display states; no Auth
object, refresh secret, raw exception, owner identifier or path is exposed.
`AccountSessionNoticeSource` is explicitly installed from the active startup
owner; the unconfigured/default provider remains null. Source changes dispose
the old notifier/subscription; initial/read/stream errors become a fixed state.

On the account route, checking hides the credential form, clears its controllers
and shows a fixed Vietnamese progress message. Failure shows a fixed message
requesting explicit login; login follows the existing failed-state cleanup and
profile barrier. A successful saved session clears the notice; ordinary logout
does not display a refresh failure. Existing account errors take precedence to
avoid duplicate messages. There is no automatic login/retry or fabricated success.

Notices are display-only, not authorization. Clearing a notice never grants study
access; account/persistence/profile barriers remain authoritative. Runtime close
cancels scheduling before awaiting cleanup and closes notice publication without
allowing a paused display subscriber to delay SDK/credential cleanup. The caller's
review journal is unchanged. No default service setup/refresh opt-in is enabled.

Seven notice/provider/widget cases cover hidden/cleared credentials, fixed error
form, no manufactured study, 320px/200% layout, redacted stream errors, old-source
rejection and actual configured-host source wiring. An additional actual pinned
SDK/mock-HTTP case checks rejected restore -> explicit login -> ordinary logout;
retained automatic-refresh cases also assert checking/failure/success notices.
These are fixture/build checks; verified source evidence is recorded below. Hosted Auth, real
learner expiry/two-client/OS suspension proof and 14 live release groups remain
pending. Keep #37 draft.

## Verified source evidence

Source `bb6be63deefa307e130c1a840c5aedaa1054a0d2` passed all five jobs in
https://github.com/collab-TTAM/nihongo_daily/actions/runs/38599504856 .
Observed 347 Flutter tests (seven notice/provider/widget plus one pinned-SDK case
added), five real Chrome tests, format/analyze, retained actual Windows vault/
runtime process markers, native/SQL/wire/security gates and normal web/Windows
artifacts. Raw run/latest-attempt metadata passed exact-head/every-required-step
QA. Pure port/controller analysis, 49 contracts/17 QA passed locally.

Configured-host test now asserts exact owner/source and propagated notice before
rendering its stream update; the no-fields expectation stays mandatory. Initial
single-frame failure was corrected in test synchronization, not production logic
or assertion/lint/CI weakening. Display/error tests use fixtures; actual learner
Auth/refresh and UI-to-OS expiry/suspension acceptance remain pending. Source
evidence is historical for later commits. Default main/source stay unconfigured.
