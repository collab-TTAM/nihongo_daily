# Captured conversation scenario read prerequisite — Issue #17

## Final readiness identity fence — 2026-10-29

Currentness already rejected reentry and final callback revocation, but only
checked session identity before the second readiness callback. Re-read the exact
captured session after that callback as well. Synchronous same-user replacement
must not authorize one last borrowed-port read or post-decode catalog publication.
Observed replacement permanently retires the capability, even if the old session
hint later returns. Existing checking/finally/busy/timeout/drain/error semantics
and active/level/public-column decoder remain unchanged.

Two TEST ONLY Auth/read-port cases target the final pre-port boundary and the
final post-decode boundary (four/eight readiness calls after construction). Both
must fail unauthorized with exactly0/1 port reads, idle busy/checking flags and
terminal denial after restoring the old hint. Without the identity recheck the
first can dispatch one read and the second can publish a result. Original test
bodies/assertions/timeouts/cleanup are byte-identical. This is not hosted Auth.

Parentd4c6fa1 CI40814863902/latestattempt1 all5/EVERYstep SUCCESS/no skips,
1509Flutter/fiveChrome/Web/Windows/native markers verified. New2/format/analyze/
build locally UNRUN(noSDK); exact-head CI required. QA46/inventory152/diffcheck
recorded separately.41draft/17open/defaultAIoff/all14hostedpending; no provider/
Authstrategy/API/RLS/Pro/content/collection/spend/security/retention activation.

CapturedConversationScenarios borrows Auth, a fixed read port and the caller's
vault/profile/runtime generation readiness fence. Construction does not dispatch.
Only explicit load(N5/N4) reads; no SDK/global client, cache, route, provider,
scenario data, default activation, subscription, timer retry or mutation is added.
The runtime must revoke on every readiness barrier and drain/close its own port.

The internal public projection is deliberately separate from frozen v0.1 API
operations. The future SDK implementation must select exactly id, jlpt_level,
title_vi, title_ja, description_vi, content_version, is_active from the fixed
conversation_scenarios table, filtered active/exact requested level, ordered by
id and limited to101 (overflow sentinel). The current SQL authenticated grants
already allow these columns; system_context and target joins are not fetched.
No SQL migration/grant/RLS/Auth change. HTTP/JSON size/redirect/credential guards
belong in the concrete captured SDK port, which is NOT implemented here.

Decode the whole response before publication: array0..100, exact seven keys,
UUID IDs unique case-insensitively, N5/N4 exactly matching requested level,
is_active==true, integer positive PostgreSQL content_version<=2147483647.
Nonblank titles max200 Unicode points each; description max2000, with early
UTF16 bounds. These are conservative local read limits, not changed server
schema constraints. Preserve text/UUID spelling and order, copy into immutable
objects/list. Empty is honest; malformed hidden/extra rows fail the entire read.
No HTML/audio/URL action or system prompt exposure. A bounded valid projection
is not proof of catalog authenticity, freshness, provisioning or authorization:
start_conversation still revalidates active scenario, level and owner server-side.

Reserve single-flight before supplied readiness/port code. Guard exact session
identity/readiness before dispatch and before/after decoding. Observed loss,
throwing getters, explicit revoke or safe UNAUTHORIZED permanently fence this
instance, including same-user replacement/A/B/A. Reentrant availability reads
redact without exposing a retained result. Other safe port errors retain their
fixed code; raw failures become fixed INTERNAL_ERROR, never echo payloads.

Timeout in(0,15s] ends the view wait but holds the busy slot until actual I/O AND
the caller have settled. Late success/error is consumed only to drain, never
cached/published or auto-retried. Explicit reload can run after drain/current
checks; this read invokes no AI provider. No cancellation/rollback/hard wire
size guarantee or previously returned snapshot erasure is claimed. Hosts must
discard stale returned lists when their owner generation changes.

Injected-port tests cover immutable/literal projection, exact N4/empty catalog,
bounds/malformed/unknown/private/duplicate rows, local validation/slot release,
single-flight/reentry, timeout with late success/error, same-user/other-user/
logout/readiness/revoke/A/B/A, fixed errors and getter loss. Results and exact-head
CI are recorded in PROJECT_STATUS/PR41. These are component tests, not real SDK,
PostgREST/JWT/RLS/provider/voice/learner acceptance. All14 live gates remain.

Next: concrete caller-owned bounded SDK public-column read, runtime/source
lifecycle wiring and actual HTTP/mounted host tests before trusted selection UI.
Only then compose explicit start/send/finish and retained uncertain-event recovery;
never allow arbitrary learner scenario UUIDs/endpoints/keys as a substitute.

## SDK-bound fixed HTTP read

SupabaseAiTextTransport now implements ConversationScenarioReadPort with explicit
read(capturedSession, level), N5/N4 only. The private dispatcher constructs GET
on the same fixed SDK-validated project /rest/v1/conversation_scenarios, with
exact seven-column select, is_active=eq.true, jlpt_level=eq.N5/N4, order=id.asc,
limit101 and empty body. The query accepts no learner table/columns/URL/key or
system prompt. This is public-curriculum PostgREST reading, not an AI provider call.

The existing captured SDK Session/token/local owner/expiry/readiness checks,
no redirects/no-store, abort/deadline/late-header discard/cancel-drain, one shared
HTTP busy slot across all text/conversation/read operations, and safe errors
apply unchanged. Body<=1MiB/<=4096 reads, strict JSON UTF8/content headers/length,
duplicate escaped keys and nesting16 defenses apply before repository decoding.
Non-array/>101 results fail at the port;101-row sentinel fails in the repository,
never silently truncates a selectable catalog. Repository validates every row.
Borrowed HTTP/SDK resources stay caller-owned, no auto retry or new SDK instance.

Existing text/conversation assertions are retained. Additional actual SDK tests
with TEST ONLY unsigned JWT/Auth HTTP/read responses exercise exact GET/query/
headers, unsupported/foreign owner/operation injection, malformed/private/mixed/
duplicate/overflow rows, header/redirect/UTF8/JSON/chunk/read limits, timeout late
success/error +cross-operation exclusion, SDK replacement/readiness/401 and owned
close preserving borrowed clients. They are not hosted JWT/PostgREST/RLS evidence.
See current PROJECT_STATUS/PR41 for execution results. This adapter is not wired
into runtime/source/UI; no default activation or authored scenario provisioning.
Next bind one retained catalog to owned readiness generations, with source/App
and real mounted host lifecycle tests, before selector/mutation/recovery UI.

## Retained runtime-owner lease

AiTextRuntimeOwner.acquireScenarios borrows the same owned ready generation,
Auth/session, text repository and transport as acquire/acquireConversation. One
CapturedConversationScenarios is retained in that lease; repeated acquisition
returns it without reading or replacing a completed/uncertain conversation.
If the transport lacks the optional read interface, return null and preserve the
text lease. No separate transport/cache/SDK or implicit readiness transition.

Register creation before supplied getters can reenter. The reader captures an
epoch/lease/repository/transport current guard and is only published after both
readiness checks. Orphans are revoked. check also checks the retained reader;
revocation retires the entire shared lease. invalidate revokes the reader before
conversation/text and transport callbacks; old generations stay retired. Transport
close/drain blocks all replacement acquisition, including ignored late reads;
failed cleanup permanently blocks fresh capabilities. close drains retained work.
Previously returned projection lists still require host generation discard.

This increment is only the reusable runtime owner and injected lifecycle tests.
PersistentSupabaseAccountRuntime/startup/source/Riverpod/App/UI do not yet call
this acquisition API. Existing opt-in flags/default-off behavior remain exact.
Next wire those host boundaries and test persisted rotation/profile barriers,
refresh/logout/account replacement on actual SDK/mounted app before selection UI.
No hosted catalog/JWT/RLS/learner acceptance is inferred from owner tests.

## Optional owned startup source

AiConversationScenarioSource is a separate optional interface, preserving legacy
text/conversation sources. PersistentSupabaseRuntime exposes its retained reader
only under the existing aiConversationEnabled opt-in (default false) and exact
owned ready-runtime/session/generation after persisted rotation/own-profile.
Factory sends nothing and uses AiTextRuntimeOwner.acquireScenarios; all readiness
transitions already revoke/drain the shared owner before a replacement is exposed.
The source's void hints are the existing owner.changes stream, not authority.

PersistentAccountStartup forwards the same source without another SDK/store owner.
WindowsStagingOwner forwards it only until close starts. AccountStartupController
exposes the optional source only in active phase while not closed; idle/loading/
failed/closing/closed or legacy runtimes cannot invent availability. Borrowed
source consumers must still use the guarded factory, discard stale projections
and never reset old pending/finished conversation receipts or close SDK resources.

Two pure controller lifetime cases and six authored actual-SDK/runtime cases cover
active-only forwarding/default-off, persisted vault/profile barriers +failures,
retained/no-dispatch factory, refresh fencing/ignored HTTP drain/fresh bearer and
logout, plus real WindowsStagingOwner/PersistentAccountStartup forwarding/close.
SDK/native wrapper tests require Flutter CI; authored cases are not passed proof.
No Riverpod/App override, selector/read UI or mutation/recovery UI is enabled yet;
next add guarded App binding and mounted lifecycle coverage before those controls.
No actual scenario provisioning/hosted JWT/PostgREST/RLS/learner claim.

## Borrowed Riverpod/App binding

AiConversationScenarioBinding contains a retained reader plus optional void owner
hints. The source provider defaults null. A private notifier observes independent
account state and owner hints, acquires only current readers and preserves binding
identity for repeated same-reader hints. Readiness/identity loss or a revoked reader
clears binding; source getter failures expose only null. Stream error/closure
permanently disables that notifier. Reentrant source hints cannot recursively
acquire. Disposal cancels only its own subscription, never the borrowed reader,
SDK/transport or conversation receipts. No catalog rows/text/requests are queued
in a hint or cached in the binding; consumers recheck reader authority on reads.

AccountStartupApp overrides the optional source from its active startup controller,
alongside unchanged text/conversation bindings. Existing conversation opt-in stays
false by default; acquisition itself makes no HTTP call. No route, read control,
selector, mutation/retry/reset/new-round UI or data provisioning is added.

Eleven source/binding cases authored cover null/default/broken stream, identity
preservation, ready loss/new owner, revoked/getter failure, stream error/closure,
borrowed disposal/override replacement, reentry and same-user replacement/A/B/A.
Two actual mounted AccountStartupApp/Windows owner/native journal/SDK journeys
are authored: held persisted rotation +own-profile barriers, explicit fixed GET,
refresh redaction/new generation +new bearer/no auto reload/logout; ready default
off/no HTTP. SDK barriers are created inside the same real-loop runAsync as the
operations, retaining prior proven cleanup and all old journey assertions.
These Flutter/Riverpod/mounted tests are NOT locally executed; exact-head CI is
required. Pinned format/QA results and CI observations are recorded in PR/status.
They do not establish hosted JWT/RLS/PostgREST or real catalog/learner acceptance.
Next inspect CI before adding an explicit guarded scenario loading/selection view
and mutation/recovery policy; no arbitrary learner UUID/endpoint/key fallback.

## Explicit read-only selector component

ConversationScenarioController borrows one retained reader and optional void
availability hints. Construction, state read/recheck and level choice issue no
read. Explicit load selects N5/N4 only, reserves one view load, clears old rows/
selection/error before dispatch and publishes only after current epoch/owner
checks. Immutable rows remain exact repository objects. Selection accepts only an
identical object in the currently loaded list, not arbitrary UUID or an equal-ID
old/foreign object. Level change/reload clears choice. No caller-supplied session,
owner, endpoint, key, event generator, provider operation or persistence.

Loading/busy blocks level, load and selection changes. Timeout/error does not
release the reader's underlying busy lease; explicit recheck can refresh controls
after actual drain, with no automatic reload, poll or retry. Empty stays empty;
malformed/error never creates scenarios. Observed owner/readiness loss, same-user
replacement/A/B/A, hint error/closure or dispose permanently redacts this view's
rows/selection/error. Nested readiness reads are redacted without revoking a
healthy borrowed reader. Late response/error cannot publish into a revoked view.
Dispose owns only view data/subscription; runtime still owns reader/SDK cleanup.
Already returned snapshots cannot be externally erased; hosts must discard them.

ConversationScenarioPanel is a reusable, unrouted read-only component. Explicit
load, N5/N4 dropdown, fixed safe errors, unavailable/idle/loading/empty states,
literal Japanese/Vietnamese/description, local choice and explicit voice/start
unavailability. No HTML/audio/URL actions, imaginary progress or start/send/finish/
reset/new-round UI. Callback closures retain their own view controller; replaced/
disposed callbacks cannot dispatch on a new account. Narrow/large-text scrolls.
No default route/flags/App/provider/SDK/Auth/RLS/contract change or data provision.

13 pure controller cases passed with the identical production graph and only test
runner import adaptation; seven widget cases are authored for exact-head CI.
These are component/fixture results, not mounted production selector, hosted
JWT/PostgREST/RLS/provider/voice/learner acceptance. Next inspect CI, then compose
selector with retained conversation/mutation/recovery policy and actual owned
mounted host tests. A selected descriptor is not server authorization or a safe
way to bypass old unresolved conversation receipts.
