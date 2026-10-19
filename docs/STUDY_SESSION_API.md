# Scoped interface review — study-submit-v1

The private completed-session ledger passed native SQL/ACL/wire/replay/overlap/
rollback/races at02e9ee0, CI39307231511 allfive jobs. The next integration step
needs a learner mutation without a service credential or caller-supplied owner.
This addition has a separately versioned contract at `contracts/study/v1`;
all frozen `contracts/v0.1` files and existing endpoint semantics are unchanged.

## Ownership and compatibility review

`public.submit_study_session(p_request jsonb)` grants EXECUTE only to
authenticated. It derives the owner exclusively from the existing `auth.uid()`
boundary and invokes the private atomic ledger. It is a narrow definer with an
empty search_path/qualified calls; anonymous and identity-free service-role
execution is denied. Private-helper/table grants and all existing client table
RLS/grants remain unchanged. Auth providers, lifecycle and strategy are unchanged.
No new personal-data fields, scores or paid calls are introduced.

The Supabase gateway must validate the actual signed JWT before this role is
entered. Native claim fixtures do not establish signature/issuer/expiry/revocation
or genuine A/B learner identity. No hosted configuration/migration is applied.

The operation records **authenticated self-reported elapsed study time**. It
does not prove attention, successful recall, completion of curriculum or mastery,
and it never creates scores/SRS learning results. This is the explicit policy
choice for personal study minutes; only independent validated review/quiz/grading
events can establish learning outcomes. Current BLOCKED resources still cannot
accrue time. All existing interval/day/availability/replay/overlap rules remain.

## Request, response and retry policy

Send exactly five strings as `p_request`: client_event_id, plan_date, session_type,
started_at, ended_at. No owner, actual/planned/completed minutes, metadata or score
is accepted. This public version requires explicit UTC uppercase Z and at most
six fractional digits; the internal service helper retains offset support.
The schema asserts UUID/real dates/UTC forms. The server additionally validates
duration, future skew, the snapshot-local day, availability and overlap.

Success and failure reuse the frozen named daily-plan and error responses.
Exact retries must retain the entire original event, including ID and timestamp
spelling. Original replay can contain an older progress snapshot; after an
acknowledgment, load `get_daily_plan` for the latest dashboard state. Do not
replace a newer visible total with an older receipt. No implicit retry is added.
An interrupted response may follow a committed write: preserve the immutable
event for reconciliation, never assume failure means it was not saved.

`CompletedStudySession` encodes canonical UTC and no owner/derived fields.
`DailyPlanRepository.submit` requires the optional `DailyPlanStudySessionGateway`
capability bound to the same owned/captured Auth session as reads. Revoked leases
cannot dispatch, and late old-owner success/failure is discarded. Shared strict
response/date/error validation is retained for reads and writes. Missing writer
fails explicitly; there is no local success, caching or automatic replay loop.

The concrete borrowed-SDK gateway and explicit ready-state owner factory are
reviewed in DAILY_PLAN_SDK.md. No durable pending-session queue, timer/completion
UI or configured route is installed. These remain mandatory before
claiming saves work through the learner app, restart/offline recovery or sync.
The owned gateway retains bounded transport/body/deadline controls and uses
only the learner session, never service credentials or an arbitrary RPC name.

## Verification

Five Python contract cases run with the retained contract-discovery gate. Eight
Dart unit cases cover fixture encoding/invalid events, exact submit, explicit
immutable retry, missing/revoked capability, late write success/failure, malformed
response/date and safe conflict. Existing16 read cases remain intact. Native role
tests verify anonymous/service denial, absent identity/profile, derived A/B
ownership, forbidden overrides/private access, UTC version, replay, own RLS and
latest authoritative read. Four actual versioned request/response pairs are
validated against the new request and frozen response/error definitions.

Local Dart format/pure-source analysis, standalone typed-submit fixture/stale
smoke, Python compilation, JSON/UTC-regex spot-check, shell syntax, whitespace
and17 QA regressions passed. No local PostgreSQL/jsonschema/full Flutter test:
these and the new-source builds require exact-head CI. Historical02e9ee0 green
CI is not execution evidence for this increment. Keep #11/#40 and all14 hosted
Personal Alpha gates open; no merge/deployment/schedule/security reduction.
