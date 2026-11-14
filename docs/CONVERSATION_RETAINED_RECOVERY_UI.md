# Explicit retained-original recovery UI — Issue #17

AiConversationController adds separate canRecoverRetained/recoverRetained for a
view that no longer has its own pending DTO. Existing canRetry/retryPending remain
unchanged. Only a current captured flow with safe retained original retry authority
is eligible; getter rechecks availability, submitting/epoch guards fence reentry,
disposal and late publication. Explicit method delegates no-payload retryRetained,
uses fixed errors and refreshes only guarded projection/ready-pending state. No
command reconstruction, new event, edited text, reset/new round or auto dispatch.

ConversationWorkspaceController threads that separate capability through its
existing both-capability checks/final fresh projections, action reservation and
safe error handling. Reader loss or flow loss disables recovery. Event factory is
not called for recovery; same immutable captured original DTO/event travels through
the existing lane and actual wire drain guards. Legacy current-view original retry
continues to work; retained recovery is offered only when local DTO is absent.

Reusable ConversationWorkspacePanel defaults enableRetainedRecovery=false. The
existing optional /conversation route opts in after its SAME composed owned binding
is ready; default conversation runtime/source flags remain OFF. New explicit
'Thử lại yêu cầu trước' button appears only when retained recovery is currently
allowed. No HTTP on build/navigation/recheck. Callback captures old controller and
checks mounted/current identity+current host flag before dispatch, so replacement/
unmount cannot retarget a new owner. No learner event/session/endpoint/key controls.

This recovers after leaving a route in the SAME process/ready generation only.
Refresh/logout or process restart cannot restore this memory-only command. No disk
storage, transcript cache, saved progress/SRS/mastery/time, voice/provider activation
or uncertain receipt abandonment/new-round policy. Secure persisted restart recovery
and human hosted release gates remain separate.

Six new pure cases PASS: exact retained start/turn/finish after old-view disposal,
no event generation/no repeat, reader vs flow loss, concurrent/disposed recovery.
All43 old workspace/conversation-controller cases PASS unchanged, strict source/new
test analysis clean. Fresh17-file exact graph with ONLY Flutter_test->test1.26.2
and frozen fixture path adaptation, official Dart3.9.2 SHA verified/lints6. This is
not full Flutter/SDK execution. All old test/helper/assertion bodies retained.

Three new actual owned App/Windows owner/pinned SDK/native journal /conversation
journeys AUTHORED locally UNRUN, one per operation. Existing real-loop taps/SDK
fixture ports, unoverridden source/combined provider/secure event factory/router.
503 safe retryable failure -> leave/reopen -> original retry stays disabled ->
explicit retained recovery sends identical body/event/URL/method/bearer, clears
pending notice, preserves exact owner flow and returns accepted active/finished
summary-not-saved. No auto request. Original six retry/remount cases unchanged;
these additional actions are independently appended. New full SDK/UI tests await CI.

Parentf177a217 CI40216596639/latest attempt1 passed allfive/every required step/no
skips, log1212393701811193Flutter/fiveChrome/all9retained cases. Retained Web/Windows/
native/SQL/Edge checks passed; TEST ONLY component proof, not hosted JWT/RLS/provider/
voice/physical learner assurance. Format6/0changes/46QA/inventory115/whitespace and
separate availability/epoch/drain/callback/exact-body/old-assertion review PASS.
All114 old QA cases/findings/gates exact/all14 hosted pending. Full local Flutter/
widgets/SDK/native/build UNRUN/no denied bootstrap retry/bypass. After exact newhead
allfive/every step/new6+3, extend actual owned recovery loss/replacement/late-response
UI coverage; secure persistence/restart recovery remains outstanding. Keep41draft/
17open/AIoff/no merge/deploy/release/Auth strategy/provider/collection/spend/security/
schedule change or Alpha acceptance.

## Recovery action account and late-response fences — core-20261026-recovery-account-fences

Parent2f6ca69 CI40217442842/latest attempt1 SUCCESS allfive/every required step/no
skips. Flutter log121241960413 confirms1202Flutter/fiveChrome/all3 actual owned
retained-recovery route actions plus6 new pure cases; Web/Windows/native/SQL/Edge
passed. Prior UI integration is now verified; not hosted learner acceptance.

Two appended actual owned App/Windows owner/persistent startup/native journal/
pinned SDK /conversation journeys AUTHORED locally UNRUN: ignored-abort recovery
success/error across A/B/A. First explicit start gets TEST ONLY503 retryable failure;
leave/reopen exposes recovery. Actual recovery tap sends identical original body/
URL/captured bearer, then its real HTTP is held. Owned logout must revoke both
capabilities, clear vault and signal abort. B login ready still cannot allocate a
combined pair until old actual I/O drains; old recovery callback before next frame
cannot send. Valid late start response or raw private error cannot restore old
button/text/summary or cross account. B and returningA get distinct notStarted
pairs, no retained recovery button/no automatic AI call; explicit catalog GETs use
the corresponding new captured bearer. Old callback remains inert in both accounts.

Held completer/taps/SDK/logout/login/abort/release all use original real runAsync
loop, frames outside. Global owned finally/drain/exclusive-vault-release assertion
and every old helper/test/assertion body unchanged. Only TEST ONLY Auth/profile/
vault/AI HTTP ports; real source/provider/event-factory/router not overridden. No
production/default/Auth strategy/provider/SDK/API/schema/RLS/CI/dependency/content/
Pro edits. No reset/new round/receipt abandonment/disk persistence or voice claim.

Official Dart3.9.2 SHA verified; format1/0changes,46QA/inventory116/whitespace and
separate original-body/callback/event-loop/drain/account/bearer review PASS. All115
prior QA objects/findings/gates exact/all14 hosted pending. Full local Flutter/
analyzer/new2SDK journeys/native/build UNRUN/no denied bootstrap retry/bypass.
New exact-head/latest-attempt allfive/every step/new2 cases required. After green
assess secure persistence/restart recovery with explicit data/identity/lifetime/
platform constraints; current recovery stays memory-only/same generation. Continue
other independent ready acceptance gaps without claiming hosted Alpha. Keep41draft/
17open/AIoff/no merge/deploy/release/security/spend/collection/schedule action.

## Retained recovery during same-account refresh

Parent6b87720 CI40218052666/latest attempt1 passed allfive jobs/every required
step/no skips. Completed Flutter log121243824146 confirms1204Flutter/fiveChrome
and both actual owned recovery A-B-A ignored-abort late success/error variants.
Web/Windows/native/SQL/Edge passed; TEST ONLY component proof, not hosted learner
acceptance. Earlier authored/unrun labels above are historical for that source.

Two additional actual owned App/Windows owner/persistent startup/native journal/
pinned SDK /conversation journeys AUTHORED locally UNRUN: retained recovery
interrupted by same-account refresh, ignored-abort late success/error. First
explicit start503retryable -> leave/reopen -> actual recovery tap repeats exact
original body/URL/captured bearer. Refresh immediately revokes old reader/flow
and signals abort. While rotated-secret write is held, no new profile request or
combined capability is allowed and the previous vault secret is unchanged.
After write completion the exact new secret is saved but held own-profile still
blocks access. Even after profile ready, old actual HTTP must drain before a
fresh combined pair can be created. Same user identity cannot restore old flow.

Old recovery callback is invoked during each barrier and after replacement;
request count stays unchanged. Valid late start response or private error never
publishes old text/pending/recovery/summary or enables start. Fresh pair is
notStarted with distinct reader/flow, no automatic AI request. Only explicit
catalog GET sends its new captured bearer; original request keeps original body/
bearer. Held completers and SDK actions stay in the original real runAsync zone,
frames outside; every prior helper/test/assertion and global finally/drain/vault
owner-release assertion remains byte-identical.

No production/default/Auth strategy/provider/SDK/API/schema/RLS/CI/dependency/
content/Pro edits, disk/transcript storage, receipt abandonment/new round, voice
or hosted acceptance. Current recovery remains memory-only/same generation.
Full local Flutter/analyzer/new2SDK/native/build UNRUN; exact new-head CI must
verify them. After green assess secure persisted restart recovery with explicit
identity/platform/data/lifetime constraints or another independent ready gap.
Keep41draft/17open/AIoff/all14 hosted gates pending; no merge/release/Alpha claim.

Local checks this increment: fresh official Dart3.9.2 archive SHA256 verified;
formatter one file/zero changes, QA inventory117 and46 QA tests passed; whitespace
and separate event-loop/rotation/profile/drain/callback/bearer diff review passed.
All116 previous QA objects/findings/gates remain exact, all14 hosted gates pending.
Original test/helper/assertion prefix is byte-identical. Full local Flutter/SDK/
analyzer/native/build unrun; no denied Flutter bootstrap retry or bypass. Four
existing edited paths: ai_owned_startup_journey_test.dart, this document,
PROJECT_STATUS.md and qa/matrix.json. Branch automation/issue-11-plan-sdk-integration,
parent6b87720adfe1bb48f63e0fb923180dadf13d76fb; new commit/CI handoff in PR41/Issue17.
