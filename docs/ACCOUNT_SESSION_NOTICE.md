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
These are fixture/build checks; full new-source CI is pending. Hosted Auth, real
learner expiry/two-client/OS suspension proof and 14 live release groups remain
pending. Keep #37 draft.
