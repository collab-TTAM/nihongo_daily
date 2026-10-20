# Owned Daily Plan read UI — Issue #11

Continue on integration PR #41, not either source draft. Baseline4461fd9 has
verified five-job CI39311989226 success, including the ten captured/actual-SDK
cases, native SQL, Chrome, Web and Windows gates. This does not validate the new
UI head; its complete retained checks must run independently.

## Publication and read flow

The production WindowsStagingOwner forwards DailyPlanRepositorySource through
PersistentAccountStartup to the existing owned SDK factory. It returns no new
repository after close begins. The outer wrapper must expose this capability;
implementing it on the inner session alone does not publish it to startup. AccountStartupController only
publishes this capability while active and revokes it immediately at close,
before asynchronous draining. The startup host overrides an otherwise-null
Riverpod source. The repository provider additionally requires the current
account/profile/ready-runtime barrier and creates a fresh captured lease on
account changes. The UI owns no SDK, credentials, storage, token writer or timer.
Existing Auth persistence/refresh/logout/close and all transport limits remain.

After configured startup and sign-in/profile readiness, the account page exposes
**Kế hoạch học**, opening /plan. The learner explicitly enters YYYY-MM-DD according
to the displayed profile timezone and presses **Tải kế hoạch**. No device date or
UTC-offset approximation selects a profile day; no timezone dependency or wire
change is introduced. Configured users can explicitly fill today from the
server/profile clock using PROFILE_STUDY_DAY.md; no automatic plan read/write.
Unconfigured/unsupported/signed-out/profile-pending states show an account link
and dispatch no plan request. The ordinary home remains clearly marked preview.

Only the authoritative response supplies date, target, completed minutes and all
seven blocks/statuses/item counts. Over-target time is preserved numerically;
the visual progress bar caps at100 percent. BLOCKED is displayed as unavailable,
and an all-BLOCKED plan explains that no area is currently available. READY
means the server's candidate availability, not a connected activity route.
The read view provides no study launch, timer, save, fake credit or completion.

## Errors, lifecycle and reload

Date validation rejects invalid Gregorian days before dispatch. One explicit
read runs at a time, with loading feedback and disabled input. Starting a read
clears the prior response. Errors use fixed safe repository messages; unknown
errors are redacted, no result is represented as cached/offline success, and no
automatic retry/background fetch occurs. The learner can explicitly load again.
Navigation/restart reconstructs an empty view and reads the server again on
explicit action; it does not persist selected dates or progress locally.

Repository replacement clears date/result/error/loading state. A late response
cannot publish after logout/refresh/account replacement, disposal or a newer
lease. New same-owner login does not revive the old request. As with the account
form, the date EditableText is keyed, kept mounted but cleared/disabled/hidden
and excluded from focus during revocation/owned exit. This preserves its binding
observer until the existing cancelable OS-exit snapshot finishes; no lifecycle
or forced-exit bypass is added.

## Authored evidence and limits

Ten Flutter widget cases cover unconfigured routing, delayed profile publication
and explicit Tokyo date, malformed date/no dispatch, loading/one fixed envelope,
server statuses/over-target progress, offline clearing/explicit retry, safe raw
failure, route return/fresh server progress, late old success/same-owner relogin,
late old failure/other-owner login, all-BLOCKED plus320px/200-percent text, and
actual startup-source/account-navigation/awaited exit with the same cleared
EditableText state. These are deterministic Auth/profile/RPC fixtures. They do
not prove a hosted login, OS credential storage, actual user activity or saved
study event. Existing actual SDK and native tests remain unchanged.

Local formatting, pure-source analysis/startup publication smoke, shell/diff and
QA checks are recorded in the current checkpoint. Full new-head Flutter analysis,
widget execution, native checks and Web/Windows builds require exact-head CI;
no passing parent result is reused as new-head evidence.

The durability library is documented in DURABLE_STUDY_SESSIONS.md. Its owned
journal/service and explicit recovery are installed in configured Windows
startup; see OWNED_STUDY_RECOVERY.md. Foreground SRS timer/new-report UI is in
SRS_STUDY_TIMER.md. Other activities and hosted JWT/A-B/two-device validation remain. Server-derived
today lookup is documented in PROFILE_STUDY_DAY.md.
All14 hosted Personal Alpha acceptance gates and #11 stay open; keep the PR draft.
No provider/Auth strategy, schema/RLS, dependency, Pro/reader content, deployment,
release, merge or schedule change.


## Windows production-wrapper correction

The initial UI source a12d95d passed Flutter analysis/full tests/Web, but its
fixture startup owner bypassed the production outer Windows wrapper. Inspection
found that wrapper did not expose the new source capability, so configured
Windows would show no plan action. WindowsStagingOwner now forwards the exact
capability and remains responsible for the unchanged runtime-before-journal
close order. The public constructor exposes the same assembly used by the
default Windows factory for direct fixture verification; it creates no resource
or additional owner and changes no build option.

An additional actual-SDK/mock-HTTP/native-journal regression runs through this
production wrapper and AccountStartupController: no source before startup, no
repository before profile readiness, fixed plan read after login, immediate
revocation during refresh/close, journal lease held while vault write drains,
existing interrupted-refresh cleanup, old repository rejection and disk reopen
after owned close. It retains the prior ten widget and ten gateway/SDK cases.
The vault/JWT/HTTP remain TEST ONLY; no hosted/OS acceptance is inferred.
Current-source execution still requires independent exact-head Actions.
