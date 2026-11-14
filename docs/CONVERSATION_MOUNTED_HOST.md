# Mounted startup conversation binding journeys — Issue #17

Two authored journeys extend ai_owned_startup_journey_test using the existing
actual AccountStartupApp, default Riverpod providers/router, WindowsStagingOwner,
PersistentAccountStartup/PersistentSupabaseRuntime, pinned Supabase SDK and native
review journal. Only TEST ONLY Auth/profile/vault/AI HTTP ports are injected;
conversation binding/source providers and app host are not overridden by tests.
No production flag, runtime, route, schema or Auth strategy is changed.

The enabled conversation-only case holds the vault rotation write before startup
can expose an account, then holds own-profile readiness while mounting the real
app. Source override is the exact Windows owner; binding/factory remain null and
no AI HTTP occurs until both barriers settle. Once ready, the captured flow and
void stream match that same owner. A real AiConversationController explicitly
starts the flow through the actual bounded SDK/HTTP adapter with exact frozen
request and captured bearer. Text remains unavailable in this opt-in test.

Refresh must immediately revoke the old flow/controller projection. A held new
rotation and profile fence leaves binding null; after both complete, binding uses
a distinct ready-generation flow with empty/notStarted projection. The retired
flow/controller stays empty; no start is automatically resent. Logout revokes
that replacement and clears the mounted provider. A separate default-off case
logs in and mounts the same app: exact source is exposed but conversation factory/
binding stay null while original text capability is available; navigation and
provider reads create no AI request.

All provider subscription creation/reads, controller requests and disposal are in
real-loop tester.runAsync zones; UI frames use explicit pumps outside them. The
existing real-loop owned finally cleanup/exclusive-vault-target-release assertion
is retained unchanged. The new view/listener close in case-local finally even if
an assertion fails. All11 existing journey cases/helper bodies are retained; only
two imports and two cases are added. The preview /ai route is still the original
tutor/unavailable UI; these cases do not mount a conversation screen or select a
live scenario. Refresh is not permission to bypass uncertain server receipts.

New cases are authored, NOT locally executed: Flutter/native SDK is unavailable.
Fresh official Dart3.9.2 checksum/format, QA inventory/regressions and separate
assertion/lifetime/diff checks are recorded in PROJECT_STATUS/PR. Exact new-head
CI must execute analyzer/allcases/platform builds; no denied bootstrap is retried.
Parent de693d9 CI40124687806/attempt1 passed allfive jobs/every required step/no
skips,1038 Flutter/all10 source binding cases/five Chrome (log120964001435).
This is parent TEST ONLY component evidence, not hosted JWT/provider/receipt/
voice/learner/physical Windows acceptance. All14 hosted release groups remain
pending. Next exact-head CI then guarded conversation screen, trusted scenario
read model and explicit recovery/reconciliation/new-round policy; no activation.

## Composed workspace owner journeys — 2026-10-25

Two additional authored cases use the actual mounted AccountStartupApp/default
provider scope, WindowsStagingOwner/PersistentAccountStartup, pinned Supabase SDK,
real native journal and existing TEST ONLY Auth/profile/vault/AI HTTP ports. The
new conversationWorkspaceBindingProvider and production secure event factory are
not overridden; both source providers must be the SAME captured startup owner.
No production route/flags/runtime/source/provider/SDK code changes.

The enabled case keeps saved-token rotation write and own-profile barriers inside
the same real-loop runAsync zone as startup. Before persisted rotation there is
no source; while profile is held the composed pair stays null/no HTTP. After both
barriers, its reader/session/hints exactly match that owner's retained capability
and createEventId is the actual default factory callable. View construction sends
nothing. Explicit workspace load selects the actual returned row and startSelected
uses fixed SDK GET/POST paths/captured bearer/exact three frozen fields/UUIDv4.
The accepted flow becomes active; no injected workspace/source/success facade.

Refresh revokes BOTH capabilities and the old workspace before new rotation/profile
complete, keeps provider null/no replay during barriers, then yields distinct
reader/session with notStarted projection and a new captured bearer. Old workspace
start/turn cannot dispatch into the fresh account generation. Explicit fresh read
uses that bearer; logout revokes both capabilities/provider and adds no AI call.
Separate default-off actual App login leaves composed binding/factories null while
existing text capability remains available; zero AI HTTP is required.

These are AUTHORED, NOT locally run: actual Flutter/native SDK unavailable. Existing
real-loop global owned finally cleanup and exclusive-vault-target release assertion
are unchanged. Case-local workspace/subscription disposal runs in real-loop finally;
old test/helper/assertion bodies are byte-identical except three new imports and
appended cases. Official Dart3.9.2 SHA verified/format1/0changes, QA inventory108/
46 regressions/whitespace/separate lifecycle/HTTP/barrier/preservation review passed.
New exact-head CI must execute both journeys and retained checks. No denied SDK
bootstrap retry or bypass, no new-host test pass claim.

Parentc699244 CI40188010889/latest attempt1 passed allfive jobs/every required step/
no skips; Flutter log121153151190 confirms1165 Flutter/five Chrome/all11 composed
provider cases. Cached fixture stream correction verified; component evidence only.
These new cases do not mount the workspace command panel or summary in the actual
route, nor prove hosted JWT/PostgREST/RLS/provider/voice/learner/network-partition
behavior. Refresh is not permission to abandon uncertain server receipts. Next
exact-head results, then guarded opt-in route/panel+summary composition and actual
owned UI/recovery/finished fences. #41 draft/#17 open/AI off/all14 hosted gates pending.
