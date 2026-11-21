# Server profile-local study day — Issue #11 / PR #41

This additive profile-study-day-v1 read enables **Chọn hôm nay theo hồ sơ** on
configured /plan and /srs. It fills a date only; load/start/finish remain separate
explicit actions. Manual dates remain available. Default preview, signed-out and
profile-pending states cannot issue a lookup. No client timezone database,
fixed UTC offset or device-local/UTC date approximates the profile calendar.

## Compatibility and security review

New contracts/calendar/v1 binds get_study_day(p_request jsonb) to a strict empty
object and a new exact two-field response: date (YYYY-MM-DD) and timezone. Errors
reuse the unchanged frozen named error. All contracts/v0.1 and study-submit-v1
payloads/semantics remain unchanged; the registry adds only the fixed empty
get_study_day envelope. No caller identity, timezone, date, clock, progress or
service authority is accepted. SDK origin/body/deadline/no-retry/captured-token
policies and every earlier allowed envelope remain intact.

The public function has an empty search_path, EXECUTE only authenticated and
an auth.uid-derived profile read. It uses one server statement instant and the
current own profile's validated timezone. private.study_day_at is a strict,
non-client-executable calendar helper for deterministic boundary tests; its
clock/zone arguments are never exposed through the public read. Public inputs
cannot choose another owner, clock or timezone. Missing profile stays NOT_FOUND:
no bootstrap, plan/session/receipt/progress write occurs. Unexpected conditions
return fixed safe INTERNAL_ERROR. Table privileges/RLS/Auth strategy unchanged.
Profiles already normalize Asia/Saigon to Asia/Ho_Chi_Minh and validate named
zones against PostgreSQL's timezone catalog. Date rendering is independent of
connection DateStyle/timezone. DST/calendar conversion belongs to PostgreSQL.
This is source/migration composition only: no hosted migration is deployed.

## Captured client and UI

DailyPlanStudyDayGateway is optional, preserving legacy read-only/submit ports.
The configured captured gateway uses the existing SDK and ready-runtime fence;
repository decoding requires exactly two typed canonical fields, a real calendar
date and bounded safe zone spelling. Response timezone must equal the ready
profile timezone. A different zone fails with a fixed message directing the
learner to refresh their account session; it never silently selects an old or
new zone. Raw server/SDK errors cannot reach the UI. Account/readiness loss,
including same-owner relogin, fences late success and failure.

The explicit button disables duplicate lookup. The returned date fills the
existing keyed text field and does not fetch plans, start a timer, submit or
retry a report. A manual text edit while lookup waits is preserved rather than
overwritten. Starting another operation, disabling the action, profile/source
replacement, logout or navigation invalidates its result. Existing date fields
remain mounted/cleared/disabled/hidden and excluded from focus on revocation,
preserving awaited OS-exit observer ownership. A running/frozen uncertain SRS
interval cannot be retargeted by today's button.

The date is current at the server lookup, not an automatic midnight subscription.
Select it again after a day change. A completed report keeps its original date
through reconciliation; this helper does not move a report to today or split
an interval across profile midnight. Existing frozen-plan calendar validation
remains authoritative for submission. This read also does not synchronize the
recorder's device clock or establish study activity/mastery.

## Evidence and limits

Three Python contract cases cover binding/schema, empty strict request, canonical
calendar/zone and exact response fields. Native SQL tests check anonymous/service/
helper denial, definer path, missing identity/profile, forbidden overrides, A/B
isolation, current profile change/normalized alias, no writes, connection locale
independence, Vietnam midnight, leap/year rollover and23/25-hour DST days. Python
validates four actual native wire responses. The existing database runner appends
this suite; no previous step/assertion/workflow is removed.

Six pure captured-registry cases cover codec, empty fixed envelope/forbidden
inputs, response/zone/error policy, old-owner/late failure fencing, missing legacy
capability and bounded timeout/no retry. They run as Flutter cases and in the
existing Linux/Windows native verifier, alongside15 previous real-disk recorder/
recovery cases and abrupt child/process lease checks. One actual-SDK/mock-HTTP
case verifies empty serialization, captured headers, no redirects and late logout
fencing. Six widget cases cover absent configuration, plan field/load separation,
duplicate lookup/manual edit, retained field/late logout, zone/raw-error explicit
retry and SRS field/start separation. Prior cases/assertions remain.

Local pinned Dart format/pure-source analysis, expanded21-scenario verifier and
actual child restart/process lease passed. Python compilation, JSON parse, shell
syntax, QA inventory49/17 regressions and whitespace passed. Full jsonschema/
PostgreSQL/Flutter widget/SDK/browser/platform execution is unavailable locally;
new exact-head Actions is required. No local Flutter CLI retry/bypass of the
previous metadata-endpoint approval rejection is attempted.

Parent ebf09bc CI39370830597 verified allfive jobs/every required step success,
461 Flutter/five Chrome/native/Web/Windows; historical only for this increment.
Keep #11 open/#41 draft/default preview/all14 hosted JWT/A-B/restart/two-device
acceptance groups pending. Other activity flows, browser study storage and full
learner acceptance remain. No main/source draft merge, dependency, Pro/reader
content, paid provider/spend, security reduction, deployment or schedule change.
