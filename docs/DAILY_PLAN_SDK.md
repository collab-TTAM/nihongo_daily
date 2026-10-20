# Owned Daily Plan SDK integration — Issue #11

This draft integration lane combines Auth/SRS #37 atafa572a and Daily Plan #40
atb03bf10 without changing either source branch, main or Pro #38/N4/reader #39.
Both parents passed all five required CI jobs before composition. That historical
evidence does not establish the merged source works; every retained current-head
gate must run again. No draft PR is merged/released by creating this lane.

## Composition and ownership

`PersistentSupabaseRuntime.createDailyPlanRepository()` is an explicit nullable
owner factory. It returns no repository until rotated-secret persistence and
own-profile readiness are established. Each successful factory call captures
the exact ready SRS runtime and ReviewSession identities. Runtime replacement,
refresh's vault/profile barrier, logout, expiry or close invalidates the old lease.
A new same-user login cannot reactivate an old repository. No profile/date/Auth
success is manufactured; the caller still supplies a valid profile-local date.

`CapturedDailyPlanGateway` borrows the existing ReviewAuth/ReviewRpcTransport. It
creates no SDK, token writer, credentials, store, listener or automatic refresh
loop. A failed identity/readiness check permanently revokes that lease. Checks
run before dispatch and after success/failure, using the ready-runtime identity
as well as session identity. Construction/unknown transport errors are redacted.

The existing registry allowlist gains exactly `get_daily_plan` (date) and
`submit_study_session` (the five versioned event fields); arbitrary functions,
owner/derived overrides, invalid envelopes and oversized scalar values remain
rejected before dispatch. The unchanged Supabase binding uses the captured
immutable Bearer token and PostgREST serializer, disables implicit RPC retry and
redirects and retains its transport/response bounds. The owned HTTP origin,
15-second/1 MiB bounds and resource draining remain unchanged. The gateway adds
an at-most15-second operation deadline with no retry; timed-out writes may have
committed and require the original immutable event for reconciliation.

## Reviewed integration resolutions

The workflow retains the core parent's exact validator step name and all existing
Chrome/SQL/parity/native/Windows/startup/exit/security gates. Both parents installed
the same pinned validator, so no dependency change is needed. The database runner
retains review parity/atomic races/queue export and appends every Daily Plan,
session-ledger and authenticated-submit suite. Both Supabase README sections and
both complete PROJECT_STATUS histories are preserved. All other auto-merged paths
were reviewed; frozen v0.1, dependencies/lockfile, Auth persistence/lifecycle
implementation and Pro data are unchanged. The only Auth runtime addition is the
explicit ready-state factory; the only registry change is the two fixed envelopes.

## Verification and limits

Six process-local gateway cases exercise fixed-envelope dispatch, forbidden
fields, readiness revocation, A-B-A/expiry, late success/error, bounded timeout
and safe errors. Four actual pinned-SDK/mock-HTTP/vault cases exercise persistence
before profile before factory, real serialized endpoints/headers, logout with a
pending submit and same-user relogin, refresh's vault fence and one-shot HTTP
failure/expiry/close. The logout fixture explicitly retains its simulated server
commit while rejecting the obsolete client's response. These fixtures use
unsigned TEST ONLY JWTs and a memory vault, not hosted Auth or OS persistence.

Local pinned-Dart formatting, pure gateway/registry analysis, standalone actual
registry/envelope/typed-read-write/revocation smoke, shell syntax, whitespace,
QA inventory49 and all17 QA regressions passed. Full Flutter/analyze/SDK fixtures,
combined SQL/wire/races and Windows/browser builds remain unverified until the
new exact-head CI; local Flutter/jsonschema/PostgreSQL dependencies are absent.

The initial SDK increment did not install this factory into routes/providers.
The subsequent read-only UI composition is documented in DAILY_PLAN_UI.md.
The configured separate study journal/recovery is in OWNED_STUDY_RECOVERY.md
and foreground SRS elapsed reports in SRS_STUDY_TIMER.md. Existing SRS review
storage remains separate. Automatic profile-local date selection, live Supabase
configuration and actual learner save/restart/two-device acceptance remain. Default main/CI artifacts remain explicit preview.
Keep all14 hosted Personal Alpha release groups and #11 open; integration is
draft, with no deployment/provider/security/schedule change.
