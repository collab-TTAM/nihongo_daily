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
