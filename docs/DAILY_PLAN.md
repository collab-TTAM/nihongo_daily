# Daily Plan server snapshot — Issue #11

This additive migration implements `get_daily_plan`, not study-session ingestion,
progress aggregation, a deployed service or authenticated learner acceptance.
The main Flutter home remains an explicitly labeled preview; no fake save or
completion is installed. Separate Auth/SRS #37 and reader #39 remain independent.

## Transport and identity

Call Supabase RPC `get_daily_plan` with `{"p_request":{"date":"2026-10-19"}}`.
The inner object is the unchanged frozen `get_daily_plan_request`. Success is the
unchanged named response; failures are the named `error`, never an error wrapped
inside success. An adapter must distinguish these variants. Anonymous execution
is denied; an authenticated call without identity returns UNAUTHORIZED and an
unprovisioned profile returns NOT_FOUND. Unknown fields, owner/target/progress
overrides, malformed/invalid calendar dates and null/non-object requests fail.

The existing Supabase gateway verifies the end-user JWT. SQL derives identity
only from `auth.uid()`; it accepts no user ID. Fixture role/claim tests do not
verify hosted JWT signatures, issuer, expiry, profile provisioning or Auth UI.
There is no change to Auth providers/strategy or request for live credentials.

The one exposed SECURITY DEFINER function has an empty search_path and qualified
table references, explicitly filters the derived owner for every private record
and grants EXECUTE only to authenticated. Private pure helpers have no client or
service-role execution grants. Existing table/RLS/column grants remain intact;
the client cannot insert plans or overwrite their blocks/completed minutes.
The initial schema's invoker-only helper description remains historical; this
is the separately reviewed, narrowly scoped authenticated transaction boundary.

## Snapshot and allocation policy nd-plan-1

An explicit request date denotes the stored profile's local calendar day, not the
database connection's date/timezone. The caller must obtain its profile-local
date; automatic client date selection is not integrated yet. SRS candidates are
own active, matching-level items due before the *exclusive* next local midnight,
including overdue/unscheduled items. DST days may have23 or25 hours; no24-hour
UTC arithmetic substitutes for calendar conversion. Content counts are captured
in one statement snapshot and the profile is shared-locked during creation.

The seven types/order remain the frozen contract. Targets7..1440 reserve one
minute per block and apportion remaining minutes by largest remainder, with
stable original-order ties and weights19/14/19/14/14/24/9 (sum113). This exactly
reproduces20/15/20/15/15/25/10 at120. Every target has seven positive integers
summing exactly to the profile target. This policy changes no wire definition.

SRS, vocabulary and grammar use owner/active/level-filtered candidate counts;
nonempty counts give READY and empty counts BLOCKED. These are plan material
candidates, not proof of a completed study session or working hosted UI.
Kanji, listening/reading, AI conversation and quiz stay BLOCKED/0 until vetted
resources and their trusted services are connected. A reference string or
scenario row alone does not prove availability. No paid service is called.

The first insert stores policy version, level, timezone and blocks internally.
Only the four frozen response fields are returned. User/date uniqueness plus
INSERT ON CONFLICT DO NOTHING preserve the winner in READ COMMITTED; a waiting
concurrent call re-reads the committed winner. Repeated reads, changed settings,
retired/new content, a new connection and progressed/over-target plans never
rewrite an existing snapshot, row identity or generation time. Reads do not
derive progress from unvalidated study_sessions rows. Progress event ingestion,
deduplication and aggregation are still required under #11.

Stored block shape/types/uniqueness/positive-minute totals are checked before
publishing success. Corrupt trusted snapshots fail closed. Unexpected failures
roll back this function's writes and return fixed Vietnamese error text. Under
stronger transaction isolation, serialization/conflict outcomes may return an
error requiring a fresh explicit transaction; only READ COMMITTED race behavior
is covered here. No automatic retry or forced success is added.

## Verification and remaining integration

`bash scripts/test_database.sh` against an empty disposable PostgreSQL17 database
retains all baseline/AI/RLS/race gates and adds `scripts/test_daily_plan.py`.
The database CI job installs the already-pinned contract validator. The script
executes native SQL role tests, validates seven actual SQL success payloads and
one redacted failure against frozen named contracts, and races two native
connections while the first insert is uncommitted, then reopens a third.

SQL assertions cover all target allocations, default/min/max, anonymous/private
ACLs, missing identity/profile, strict requests, two owners/same date, active
level counts, Vietnam midnight, spring/fall DST cutoffs, leap dates/DateStyle,
started/over-target preservation, malformed storage and failure rollback. Test
fixtures only: the started145-minute result is deliberately seeded by trusted
SQL to prove preservation; it is not proof of validated session aggregation.

No local PostgreSQL is available in the authoring runtime. Native SQL, actual
wire output and race execution require exact-head CI before claiming success.
Do not reuse #37/#39's CI as evidence for this main-based branch. Keep #11 open:
trusted idempotent session events/aggregation, typed account-scoped app adapter,
loading/error/offline/restart UI and hosted learner evidence remain outstanding.
All14 live Personal Alpha gates remain pending. No migration/deployment is
applied to a hosted database and no draft is merged by this increment.
