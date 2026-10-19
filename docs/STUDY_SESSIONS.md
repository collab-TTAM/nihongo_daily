# Trusted study-session progress — Issue #11

This is an additive **internal backend** boundary, not a new public API, a
deployed service or a completed learner flow. Existing frozen v0.1 definitions,
client grants/RLS and `get_daily_plan` request/response remain unchanged.

## Caller and ownership

Only the trusted `service_role` can execute
`private.record_study_session(p_owner uuid, p_request jsonb)`. This narrow definer
uses an empty search_path and qualified tables. Anonymous/authenticated callers
cannot execute it, read/write its private receipts or directly update progress.
The service cannot directly access the receipt table either. A private parser
has no client/service execution grant. There is no exposed public wrapper.

The future authenticated backend must verify the user's JWT/session, derive
`p_owner` from that identity, authorize/validate genuine study activity, apply
bounded transport/rate/deadline controls and retain the immutable event for retry.
No service credential goes into Flutter. **The helper itself does not verify
JWTs or prove that a learner was actively studying.** Receiving times from a UI
alone is insufficient activity evidence. The table's historical broad trusted
service maintenance rights remain unchanged; this is not hardening against a
compromised service account. Receipt authority is inaccessible through ordinary
service table writes.

The strict internal command is exactly five string fields (JSONB size <=4096):

```json
{
  "client_event_id": "e1400000-0000-4000-8000-000000000001",
  "plan_date": "2026-10-18",
  "session_type": "VOCABULARY",
  "started_at": "2026-10-18T00:00:00Z",
  "ended_at": "2026-10-18T00:15:00Z"
}
```

No owner, actual/planned minutes, score, completion status or metadata can be
supplied inside this command. Unknown fields/types/dates/times fail closed.
Timestamps require uppercase T/Z or explicit offsets, real dates, hours00..23,
seconds00..59 and at most six fractional digits. Naive/infinite/leap-second times
are rejected. UUID and profile must be valid; the plan must already exist.

## nd-study-1 policy

The existing plan must be a valid nd-plan-1 snapshot. Its frozen timezone, level,
allocation and availability govern the session even after profile settings
change. A BLOCKED area cannot accrue minutes through this boundary. The interval
must fit inside that snapshot's calendar day; ending exactly at next midnight is
allowed. Cross-midnight activity requires separately validated, immutable events
for each day in the future backend. Calendar conversion handles23/25-hour DST
days. Elapsed duration must be60..90000 seconds and end no more than five minutes
ahead of server time. Credit is floor(elapsed seconds/60), per completed session;
sub-minute intervals are rejected and fractional remainders are not carried.

The same owner's profile is locked before receipt/plan reads; this serializes
submissions, including across dates, and follows profile-before-plan lock order.
Exact owner/event replay returns its original frozen plan response, even after
later progress; a fresh `get_daily_plan` read returns the latest progress. Changed
requests under that ID yield SYNC_CONFLICT. Distinct IDs with overlapping
half-open intervals for that owner also conflict, across all days and areas.
Adjacent intervals are allowed. Accounts remain independent. Input JSON equality
is exact JSONB equality; changing timestamp spelling/offset is a changed retry.

The accepted session, private immutable receipt and derived plan update commit
together. Minutes are added once without capping at the target. The area's
validated ledger minutes determine IN_PROGRESS/DONE; a previously DONE area
stays DONE. Other blocks, counts, row identity, generation time and snapshot
settings remain intact. Unreceipted legacy `study_sessions` rows are not summed
into progress. Private receipts keep their original intervals/credits, so later
trusted maintenance of a public row cannot rewrite those ledger values.
Unexpected errors (including receipt failure/overflow) roll back all three writes
and return fixed Vietnamese text. No automatic retry is added. READ COMMITTED is
the tested concurrency target; stronger isolation can require a new transaction.

Success is exactly the existing frozen `get_daily_plan_response`; failure is the
existing named `error`. This internal operation is deliberately absent from the
frozen client endpoint registry. Adding an authenticated client mutation transport
requires its own versioned contract/review and runtime integration. It must not
expose `p_owner` or service credentials as learner-controlled authority.

## Verification and remaining work

`bash scripts/test_database.sh` retains every prior gate and runs
`scripts/test_study_sessions.py`. Native fixtures assert role denial, strict
requests, derived minutes, per-owner replay/conflict/overlap, snapshot settings,
IN_PROGRESS/DONE, over-target progress, midnight/DST, corrupt snapshots and atomic
rollback after a late receipt failure. Eleven actual SQL success responses and
one error are checked against the frozen named models. Native connection races
cover an uncommitted duplicate, adjacent distinct events without lost updates,
changed replay/overlap conflicts and fresh-connection read/replay.

Local Python compilation, shell syntax, separate source/test review, whitespace
and17 QA regressions passed. This runtime has no PostgreSQL or jsonschema, so
native SQL/wire/races require the new exact-head CI; no native pass is inferred.
Earlier911eb7 passed allfive jobs/16 client cases/Web/Windows before this change.
No hosted migration, real JWT verification, genuine learner activity, end-user
save action, offline crash recovery or multi-device acceptance is established.
Keep #11/#40 and all14 live Personal Alpha gates open pending actual integration.
