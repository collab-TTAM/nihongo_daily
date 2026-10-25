# Guarded conversation route and shared summary — Issue #17

The existing /conversation route now renders ConversationScreen. It watches only
conversationWorkspaceBindingProvider: a null pair preserves the original
unavailable preview and exposes no input or dispatch control. A trusted owned
runtime must explicitly enable conversation, settle persisted credential rotation
and own-profile readiness, and provide both captured capabilities. All default
flags remain OFF; route/navigation/provider reads do not load or send anything.
/ai remains the original tutor. No source override or learner endpoint/key/UUID
input is installed by this route.

A nonnull binding mounts ConversationWorkspacePanel with ObjectKey(binding).
Identity replacement discards the old editor/view before attaching a replacement;
callbacks stay captured to old disposed controllers. The existing panel/controller
retain all explicit load/current-row selection/start/turn/finish/original-retry
semantics. Leaving the route drops the ephemeral draft/pending DTO, never closes
borrowed flow/reader/receipts. Active remount may continue the same accepted flow;
finished stays finished. An unresolved remount cannot reconstruct a discarded
command, offer a new start or erase uncertainty. No reset/new-round/durable client
recovery, polling or automatic replay is added. Pending user recovery remains a
known limitation requiring a separate reviewed increment.

ConversationSummary is the existing read-only summary column extracted from
ConversationSessionPanel, with a public constructor/key only. The read-only panel
still uses its own freshly guarded controller snapshot; the command workspace
renders the SAME summary from its own freshly guarded workspace snapshot. No
second conversation controller, source acquisition, raw flow snapshot subscription
or divergent cached summary is introduced for workspace composition. This pure
renderer owns no authority and must receive a guarded accepted response from its
host. On either capability loss, replacement or late old completion, the current
workspace's existing guards remove summary/text along with mutation controls.

Original numeric scores, exact errors/strengths/focus text and empty-list notices
remain literal Text. SRS recommendations are a count plus not-saved notice, never
writes. Voice remains unavailable; no audio_ref/markup/URL fetch, progress/SRS/
mastery/study-minute persistence or invented transcript is installed.

Seven TEST ONLY widget cases authored in conversation_screen_test use the actual
NihongoDailyApp/router and real captured reader/flow/controller with paired-binding
fixture overrides and injected Auth/read/mutation ports. They cover untouched
production default provider/unavailable /conversation and /ai; explicit exact-text
commands/detailed literal summary/finished remount; active remount draft and old
callback fencing; unresolved remount/no reconstructed retry/reset; same-user
identity loss and A/B/A summary redaction; held finish/late old summary/replacement/
source removal; and empty summaries at320px/200% text with actual App shell.
All previous tests/assertions remain unchanged. The shared summary body extraction
is separately compared against the original renderer, not reimplemented.

Local official Dart3.9.2 SHA verified, formatting and QA/inventory/whitespace and
separate scope/lifecycle/extraction review recorded in PROJECT_STATUS. Full local
Flutter/analyzer/new widgets/native/build are UNRUN; no denied bootstrap retry or
bypass. New exact-head CI must run allfive/latest-attempt/every required step;
authored widget cases are not passed evidence. These fixture route cases do NOT
prove actual owned SDK-to-route commands or hosted JWT/PostgREST/RLS/provider/
voice/physical Windows/learner behavior.

Parent5bc7c045cc80cf6951c08b437f45102e1b89e362 CI40192637684 latest attempt1 completed
success: allfive jobs/every required step/no skips; Flutter log121167080061 confirms
1167 Flutter/five Chrome including both actual owned combined workspace App/SDK
journeys. Retained Web/Windows/native/SQL/Edge gates passed; component proof only.
Next inspect new exact-head CI/allseven cases, fix actual diagnostics preserving
assertions; after green extend actual owned SDK/App journey through this route,
explicit controls/summary and refresh/logout barriers. Keep41 draft/17open/AIoff/
all14 hosted learner gates pending. No merge/deploy/release/provider/Auth strategy/
collection/spend/security reduction or Alpha acceptance.

## Owned SDK-to-route journey — core-20261025T1415-owned-route

Parent f233b30 CI40197060772/latest attempt1 completed SUCCESS, allfive jobs/every
required step/no skips. Flutter log121180444406 confirms1174 Flutter/five Chrome
including allseven route cases. Retained Web/Windows/native/SQL/Edge gates pass;
component proof only, not hosted learner acceptance.

One new owned journey AUTHORED, NOT locally run, uses actual AccountStartupApp,
Windows owner/persistent startup/native journal/pinned Supabase SDK and unchanged
unoverridden composed provider/event factory/router /conversation. Only TEST ONLY
Auth/profile/vault/AI HTTP ports injected. Explicit actual widget taps load/select/
start/send/finish; SDK actions/taps await in real tester.runAsync event loop as the
existing tutor helper, frames outside. No added helper/source/default overrides.
Reader/session/factory identities match owner; navigation/typing sends nothing.
Accepted start/turn/finish use captured bearer/fixed endpoints/exact wire fields,
secure distinct UUIDv4 events and unchanged Unicode/whitespace. The illustrative
turn fixture repeats start sequence0/ID: this test alone deep-copies response and
sets distinct assistant ID/sequence2 plus explicit marker, preserving strict
correlation rather than weakening decoder. Canonical fixture file unchanged.

Actual route renders accepted next assistant/summary scores/strength/not-saved
notice; finished has no editor. Leave/reopen retains summary/disabled start/no
extra HTTP. Actual owned logout synchronously revokes both capabilities; UI removes
assistant/summary, provider null/no further AI calls. Original real-loop owned
cleanup/exclusive vault-target release assertion and every old helper/test/assertion
body retained exactly before appended case. No production change, reset/newround,
durable client recovery/progress save/provider/voice or live Auth activation.

Official Dart3.9.2 SHA verified; format1/0changes,46 QA/inventory110/whitespace and
separate event-loop/SDK wire/lifecycle/assertion review PASS. All109 old QA cases/
findings/gates unchanged; all14 hosted groups pending. Full local Flutter/analyzer/
new journey/native/build UNRUN/no denied bootstrap retry/bypass. New exact-head
CI must run allfive/latest attempt/every required step/new journey. After green
extend actual owned route refresh/held rotation/profile/account replacement and
uncertainty UI cases before reviewed durable client recovery/new-round policy.
Keep41draft/17open/AIoff; no merge/deploy/release/provider/Auth strategy/security/
collection/spend/Pro/schedule action or Alpha claim.

## Owned route refresh barriers — core-20261025T1512-route-refresh

Parent f488b9b CI40201684602/latest attempt1 completed SUCCESS, allfive jobs/every
required step/no skips; Flutter log121194430353 confirms1175Flutter/fiveChrome
including prior owned route command/summary/logout case. Component proof only.

One appended actual App/Windows owner/pinned SDK/native journal /conversation
journey AUTHORED, NOT locally run. Existing fixture/helper/test/assertion bytes
unchanged. Real UI load/select/start/send establish accepted reply; second private
draft/captured old send callback precede same-user refresh. Actual owner refresh
revokes both captured capabilities immediately. Held token-rotation write then
held own-profile readiness keep combined provider null and no editor/old reply/
draft or automatic request. All barriers/callbacks/SDK actions share existing real
tester.runAsync event loop; frames outside, same prior tap helper body reused.

After persisted rotation and profile complete, route sees distinct exact owner
reader/session/notStarted and new bearer. Old send callback cannot retarget fresh
workspace through either barrier or afterward. No auto start/replay; explicit
fresh catalog tap uses new bearer. Logout revokes fresh pair; old callback stays
inert/no extra HTTP. Refreshed notStarted does NOT grant permission to abandon an
uncertain receipt or reset a round; test dispatches no replacement start. No
production/default/Auth strategy/provider/SDK/source/CI/dependency/content/Pro
change, no plaintext fallback/token logging/persistence/voice/hosted learner proof.

Official Dart3.9.2 SHA verified, format1/0changes,46QA/inventory111/whitespace and
separate old-body/event-loop/callback/barrier/wire review PASS. All110 previous
QA objects/findings/gates retained/all14 hosted pending. Local full Flutter/
analyzer/new journey/native/build UNRUN/no denied bootstrap retry/bypass. New
exact-head/latest-attempt allfive/every required step/newcase remain required.
After green actual account replacement and uncertain/late-response route cases;
reviewed durable client recovery/new-round policy still pending. Keep41draft/
17open/AIoff/no merge/deploy/release/collection/spend/security/schedule/Alpha claim.

## Owned route account replacement and late I/O — core-20261025T1609-route-accounts

Parent f4df8fb CI40205962436/latest attempt1 completed SUCCESS: allfive/every
required step/no skips; log121207282900 confirms1176Flutter/fiveChrome/new owned
route refresh barrier case. Retained Web/Windows/native/SQL/Edge gates passed.

Two actual owned /conversation A/B/A journeys AUTHORED, locally UNRUN, parameterized
by ignored-abort old turn success/error. Existing actual App/Windows owner/persistent
startup/native journal/pinned SDK/unoverridden combined provider/event factory/router
and TEST ONLY Auth/profile/vault/AI HTTP ports. Explicit route taps load/select/start;
private A turn is held in the real SDK event loop. Logout revokes both and clears
vault; B login reaches ready but combined pair remains null until actual old HTTP
drains. Before new frame, retired A callback cannot send. After late valid assistant
or raw private error completes, no old text/error/summary appears; B pair is distinct,
notStarted, and explicit catalog tap uses captured B bearer. Return to A allocates
another distinct ready pair, old A/B stay revoked and retired callback remains inert.
Explicit catalog read uses new A bearer; navigation/login create no AI call. No
post-retirement mutation or uncertain receipt abandonment/new-round authorization.

Held completer creation/taps/logout/login/abort/release/SDK assertions use same real
tester.runAsync loop, frames outside; global owned finally drains HTTP/SDK/native
resources and asserts exclusive vault release. Both late response variants use
strict decoder; success explicitly sets distinct assistant ID/sequence2/marker in
a deep-copied TEST ONLY turn response, never edits frozen fixture or decoder.
All earlier helper/test/assertion bodies and all production/default/SDK/source/
Auth strategy/provider/CI/dependency/content/Pro bytes unchanged.

Official Dart3.9.2 archive SHA verified; format1/0changes,46QA/inventory112/whitespace
and separate callback/event-loop/drain/bearer/old-body review PASS. All111 old QA
objects/findings/gates retained/all14 hosted pending. Local full Flutter/analyzer/
new2journeys/native/build UNRUN/no denied bootstrap retry/bypass. Not hosted JWT/
RLS/provider/voice/physical learner proof. Next exact new-head/latest-attempt allfive/
every required step/both variants; after green current-session uncertain/manual
original retry/remount route coverage, reviewed durable client recovery/new-round
policy. Keep41draft/17open/AIoff/no merge/deploy/release/security/spend/schedule/
Alpha claim. Actual hosted configuration/human release gates remain pending.

## Owned route original retry and remount fences — core-20261026-owned-route-retry

Parent bc2a86b CI40210453315/latest attempt1 SUCCESS allfive/every required step/no
skips. Flutter log121220804663 confirms1178Flutter/fiveChrome/both actual owned
A/B/A ignored-abort late success/error journeys. Component proof only.

Six appended actual owned App/Windows owner/persistent startup/native journal/
pinned SDK /conversation journeys AUTHORED, locally UNRUN. Three operations
start_conversation/conversation_turn/finish_conversation each receive one explicit
TEST ONLY503 PROVIDER_UNAVAILABLE/retryable response with private detail. Actual
route taps and unchanged paired provider/secure UUID callable are used, no source
or binding override. TEST ONLY Auth/vault/profile/HTTP ports, no hosted service.

In-place variants require unresolved notice, fixed safe error/no private detail,
locked load/start/editor, no HTTP on recheck, and enabled explicit original retry.
Retry must send byte-identical body/event, identical URL/method/captured bearer,
then clear uncertainty and publish only accepted active/finished state. Exact
Unicode draft retained on wire; accepted turn appears once, accepted finish summary
remains not-saved. No new-ID/text substitution or automatic resend.

Remount variants leave/reopen /conversation, retain unresolved runtime receipt,
but discard view-owned DTO; old retry callback is inert. New retry/start/catalog
remain disabled; recheck sends nothing and no summary is fabricated. This honest
block is NOT durable recovery or permission to abandon uncertainty/new round.
Future safe persisted command recovery remains outstanding. All SDK/tap/response
and capability assertions use existing real tester.runAsync loop, frames outside.
Global owned cleanup/exclusive vault release and all old helpers/tests/assertions
stay byte-identical. Original canonical fixtures/strict decoder/production/defaults/
Auth strategy/provider/source/SDK/API/schema/RLS/CI/dependencies/content/Pro unchanged.

Official Dart3.9.2 SHA verified; format1/0changes,46QA/inventory113/whitespace and
separate event-loop/receipt/body/bearer/old-callback review PASS. All112 prior QA
objects/findings/gates exact/all14 hosted pending. Full local Flutter/analyzer/new6
journeys/native/build UNRUN/no denied bootstrap retry/bypass. Next exact newhead/
latest attempt/allfive/every required step/all6 then reviewed durable client
command recovery without reset/automatic replay. Live Auth/JWT/RLS/provider/voice/
physical learner acceptance remain pending. Keep41draft/17open/AIoff/no merge/
deploy/release/collection/spend/security/schedule action or Alpha claim.
