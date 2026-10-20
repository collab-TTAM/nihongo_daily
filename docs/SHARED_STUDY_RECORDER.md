# Shared foreground completed-study recorder — Issue #11

The account-scoped recorder core now supports SRS, vocabulary and grammar with
one active/preflight/frozen-report slot. The configured app still exposes only
the existing SRS controls. Reader controls and their loaded-content/profile-level
readiness publication are a later increment; the production callback explicitly
rejects non-SRS starts today. No vocabulary/grammar study credit is fabricated.

## One captured owner and one report

StudySessionRecorder is extracted from the existing SRS implementation. It keeps
same-owner pending-report recovery before plan reads, current captured lease,
monotonic elapsed clock, explicit finish,60..90000-second bounds, five-second
wall-clock consistency check and existing durable stage/submit/ack/fresh-plan
path. Server identity/calendar/availability/overlap/minute validation remains
unchanged. This is authenticated self-reported time, not attention or mastery.

start(date, area: ...) accepts only the three supported areas. It requires an
area-specific readiness callback both before asynchronous preflight and after
plan lookup, then checks the requested area's nonblocked/nonempty server block.
An available SRS block cannot stand in for unavailable vocabulary or grammar.
Unsupported areas dispatch nothing. State includes the captured area for future
host labels; account revocation removes that area and fences late publication.
The callback/host must enforce actual loaded content and matching account level;
the generic core does not interpret curriculum widgets or establish hosted data.

While checking, running, saving or uncertain, a different start cannot change
the slot, date, area, event ID or interval. Crucially, a failed local stage still
has a frozen in-memory event even if recoverPending on disk would be empty. All
activities must use the same configured instance instead of creating one per
route/kind. Explicit retry uses the original event; only a resolved report can
permit a later explicit different-area start. This guarantee is within a captured
ready-owner lifetime, not cross-isolate CAS or crash durability before staging.
Owner replacement still clears memory; staged events remain owner-isolated on
disk for the existing recovery service. No new journal format or token owner.

interrupt(area: ...) affects only matching unfinished preflight/timing, never
another area's current interval or an accepted save. An obsolete route's disposal
must pass its own area so it cannot cancel a newer route. A late canceled
preflight cannot revoke the newer generation. An unscoped core interrupt remains
available for whole-owner/lifecycle callers. The provider's legacy no-argument
interrupt retains SRS scope. Save retries and runtime draining are unchanged;
accepted operations still complete with their SDK/store resources owned.

## Compatibility and phased installation

SrsSessionRecorder keeps its original constructor and no-argument SRS start path
as a compatibility wrapper, exporting the existing clock/state names. The owned
production factory now constructs StudySessionRecorder once. The old
srsSessionRecorderProvider is an alias of studySessionRecorderProvider, and the
notifier type name is compatible. Both consumers access one controller/state,
not independent slots. Provider recreation/disposal still follows the same
captured durable service/account/profile barrier. No preview configuration,
credentials, extra runtime, automatic retry or new network operation is added.

The current SRS panel, keys, readiness, level controls, messages and retained
hidden/cleared/unfocusable date field stay intact. Reader UIs must next adopt the
same provider, actual loaded same-profile-level content guard, area-aware labels
and scoped lifecycle interruption. Frozen pending reports from any other area
must remain explicitly identifiable/retryable without retargeting. Keep fields
mounted through awaited app exit. Do not enable a family of independent recorders.

## Verification and limits

Six new scenarios run against real disposable NativeStudySessionJournal files:
three-area roundtrip, failed-stage in-memory cross-area exclusion, uncertain
committed grammar exact retry, same-area availability/readiness recheck,
wrong-area interruption/late canceled preflight and held-save owner replacement.
The native verifier appends them after all prior seven recovery/eight SRS/six
captured-day cases and retains actual abrupt-child/process-lease/reopen checks.
Its27 scenarios comprise21 real-disk cases plus six captured-RPC day cases.

Flutter discovery reuses the six scenarios and adds one actual Riverpod/native
journal regression: finish through the legacy consumer with a failed stage,
try another area through the shared consumer, then retry the exact original
report through that consumer and observe confirmation from the legacy name.
All previous SRS fixtures/widgets/SDK/browser/SQL/build gates remain unchanged.
Local core/source/fixture analysis, formatting and all27 native-verifier scenarios
plus process checks passed. Full provider/widget/SDK/platform verification needs
exact-head CI; no unavailable Flutter CLI workaround is attempted.

Parent621e515 CI39374191185 passed allfive jobs/every required step,499 Flutter/
five Chrome/SDK/native/Web/Windows, explicitly including the four N4 cases. That
is historical evidence for this refactor. Keep #11/#12 open/#41 draft/default
preview and all14 hosted acceptance groups pending. No content/dependency/Auth
strategy/schema/RLS/CI/security/provider/spend/merge/deployment/schedule change.


## Cleanup lint correction — 2026-10-20

Sourcebea659ae CI39375345330 completed with database/repo-sanity/AI/Windows success.
Windows logs explicitly show all six new cross-area cases and actual abrupt-child/
lease checks passed. Flutter format passed, but analyze rejected one multiline
fixture cleanup if without a block (line267, curly_braces_in_flow_control_structures).
Full Flutter tests/provider regression/downstream browser/Web were skipped, never
counted as success. There was no observed production failure in this run.

Both fixture cleanup if statements now use explicit blocks around their existing
single completion call. Every scenario/checkStudy call, provider regression,
production byte and strict lint/CI gate is unchanged. Corrected local format,
pure targeted analysis, all27 verifier scenarios plus actual child/process checks,
QA17/inventory49 and whitespace passed. Separate exact diff/assertion review
confirms the bounded change. Full corrected-head Flutter/provider/browser/Web/
Windows results require fresh Actions. Local Flutter metadata-review rejection
is not retried or bypassed. Next inspect that exact head before reader controls;
only pending CI means save/release without duplicate work or long polling.
