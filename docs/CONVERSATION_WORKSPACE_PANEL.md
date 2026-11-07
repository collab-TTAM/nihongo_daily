# Opt-in workspace command panel — Issue #17

ConversationWorkspacePanel owns one ephemeral workspace controller, text editor
and void subscription. Its immutable trusted ConversationWorkspaceBinding borrows
reader/retained flow, broadcast owner hints and optional event factory. The host
MUST pair the same ready runtime generation and supply a secure UUID factory;
this descriptor does not prove that pairing. No factory/source/default, route or
App override is installed. Existing /ai and all default flags remain unchanged.

Explicit load/level/current-row selection/start/turn/finish/manual original retry
use existing guarded workspace methods. Only text is learner command input;
no scenario/session/event UUID, endpoint/key, new-round/reset or recovery mode.
Construction/build/recheck/remount sends nothing; new commands get one trusted
factory event, retry uses original DTO/event only after the retained flow drains
and permits retry. Active/pending/finished lock catalog/new start. Missing sources
are unavailable; missing factory clearly disables new mutations. Empty catalog,
loading, safe errors, pending, finished and unavailable states are explicit.

Editor is process-local, never persisted/logged or sent on typing. Unavailable,
unresolved and finished states clear it; binding replacement/unmount disposes it.
Successful accepted send clears the draft; invalid local text remains editable.
Only a fresh controller state controls each render. Async hints carry no data.
Callbacks capture old controller/editor; old send checks mounted/current identity
before reading an editor and after await. Old read/start/finish/retry callbacks
remain bound to disposed old controllers, never a replacement owner. Late results
cannot mutate a replacement editor. Cleanup owns only view/subscription/editor;
borrowed capabilities and uncertainty remain runtime-owned. Previously held
snapshots require host discard; frame redaction is not runtime revocation.

Accepted assistant text/translation renders literally; no invented user transcript,
voice player/URL/HTML action. Voice is always unavailable, results not saved to
progress/SRS. Finished notice does not open a new round. Detailed summary remains
in the existing separate read-only ConversationSessionPanel; a final mounted host
composition is still required. Remount cannot reconstruct a discarded pending
command, enable retry for an external receipt or erase uncertain/finished state.
No durable client recovery or reviewed new-round policy is claimed.

Seven TEST ONLY widget cases AUTHORED, NOT locally run: absent/missing factory/no
auto calls; exact draft progression/finish/no new round; controlled safe retry with
same original event/body/no edited resend; same-user loss/A-B-A editor redaction;
replacement/unmount old send callback fencing/borrowed preservation; unresolved
remount no reconstructed retry/reset;320px/200% scroll. Actual captured controller/
reader/flow/receipt lane and unchanged frozen fixtures use injected Auth/ports.
These are component fixtures, not actual mounted startup/SDK/hosted learner proof.
Full Flutter analysis/widgets/builds await exact-head CI, local Flutter unavailable;
no denied bootstrap retry or bypass. Official Dart3.9.2 archive SHA verified and
three new files formatted; QA inventory106/46 regressions and whitespace checked.

Parent37b1b15 CI40172900658/latest attempt1 passed allfive jobs/every required
step/no skips; Flutter log121107648494 confirms1147 Flutter/five Chrome including
all22 workspace cases plus retained Web/Windows/native/SQL/Edge gates. Next inspect
new-head allfive/latest-attempt/new7widget cases, fix actual diagnostics retaining
assertions, then guarded actual owned host pairing/secure ID factory/route integration
with explicit opt-in only. Keep41 draft/17 open/AI off/all14 hosted gates pending;
no deployment/merge/provider/Auth strategy/collection/spend/security/release change.

## Exact-head analyzer correction — 2026-10-25

CI40176232761 at d496440/latest attempt1 completed with allfour non-Flutter jobs
successful, every required step. Flutter formatting passed but strict analysis
failed at panel249/250: the untyped nullable-list fallback inferred dynamic message
values, which cannot be passed to Text under strict casts. All Flutter tests,
including the seven widgets, Chrome/Web and downstream Flutter checks were skipped.
Windows success does not substitute for those results.

The panel now imports ConversationAssistantMessage and explicitly types only the
const empty fallback. The real snapshot list and literal Japanese/nullable Vietnamese
rendering are unchanged; no cast/dynamic allowance/lint suppression or runtime
fallback conversion. Every existing widget case/assertion remains byte-identical.
Pinned Dart3.9.2 format1/0changes and46QA/inventory106 passed. Full corrected-head
Flutter analyze/widgets/build still require exact-head CI; no local Flutter claim
or retry of a denied bootstrap. Inspect allfive latest-attempt jobs first, then
continue host integration only after actual new-panel evidence is observed.

## Guarded route composition — 2026-10-25

The earlier route/summary integration limit above is superseded by
CONVERSATION_ROUTE.md: /conversation consumes the existing optional combined
binding, default unavailable. ConversationSummary preserves the original summary
column for both panels; workspace uses only its current guarded snapshot and no
second view/controller. Old tests/assertions unchanged; seven additional actual
App/router fixture cases authored, awaiting exact new-head CI. No default flag,
owned source, receipt/recovery policy, live provider/voice or persistence change.
Actual owned SDK-to-route command/summary journey remains next after CI passes.
