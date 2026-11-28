# Guarded read-only conversation panel — Issue #17

ConversationSessionPanel renders a borrowed AiConversationViewBinding. It owns
only its AiConversationController and void-hint subscription, not the runtime
flow/Auth/HTTP/SDK. Every build reads fresh guarded controller state; a source
hint requests a fresh build instead of retaining text snapshots. Binding identity
replacement disposes the old view before attaching the new one; unmount clears
view data/cancels its own subscriptions while preserving borrowed flow receipts.
Owner revocation remains the host/runtime's synchronous responsibility. A stream
hint is not authority and previously returned snapshots cannot be erased externally.

Null/revoked/missing readiness shows fixed unavailable text. Ready notStarted/
active/finished phase, empty assistant list and unresolved mutation are explicit;
busy work says to wait. Accepted assistant Japanese/Vietnamese are ordinary Text,
not HTML/Markdown, URL navigation or arbitrary widgets. Missing translation is
explicit. Audio is always labelled unavailable, even when audio_ref is present;
no image/audio/HTTP fetch/player is constructed. No invented user-turn transcript
or live feedback, model error, score, saved progress/mastery or plan credit.

Validated finish output displays the original numeric grammar/vocabulary/fluency
scores, exact correction text/explanation, strengths and next-focus strings.
Empty lists have honest absence messages. SRS recommendations display only count
and a not-saved notice; model references authorize no writes. The column scrolls
and wraps for narrow screens/large text. Scroll ownership/layout is local.

This increment is a reusable read-only panel, not a wired production conversation
route. No route/provider/default/staging flag, scenario catalog, event generator,
send/finish/retry/reset/new-round control or backend contract changes. Trusted
scenario selection and explicit recovery/reconciliation/new-round policy remain
prerequisites before mutation UI is enabled. Existing /ai tutor is unchanged.

Eight widget cases authored use the actual captured flow/DTOs with TEST ONLY
Auth/port/frozen fixtures: absent/idle no dispatch, plain literal assistant and
absent translation/no audio loading, finished empty summary/not-saved, lifecycle
same-user replacement/A-B-A/hints redaction, binding replacement/unmount preserving
borrowed flows, explicit provider-failure uncertainty with no raw detail/retry,
320px/200% text scroll/no overflow, exact bounded/fractional scores and correction/
strength/focus literal text. These cases are NOT locally run: full Flutter SDK is
unavailable; exact-head CI must execute them and analyzer/builds. No denied SDK
bootstrap retry/bypass. Fresh Dart3.9.2 checksum/format/QA/separate diff observed
checks are in PROJECT_STATUS/PR; authored tests are not passed evidence.

Parent72c62e1 CI40133533178/attempt1 completed allfive jobs/every required step/no
skips,1040 Flutter/five Chrome/both mounted conversation host cases verified in
log120990516687. This is TEST ONLY component evidence, not hosted JWT/provider/
receipt/voice/learner or physical launch proof. All14 hosted release groups and
Auth/provider/collection/spend/security/release approval gates remain pending.
Next inspect exact new-head CI then compose trusted scenario/read capability and
explicit safe mutation controls with real mounted host/lifecycle coverage.


## Revocation widget frame correction — 2026-10-25

Exact adc2b97 CI40141452588/latest attempt1 completed failure: all four
non-Flutter jobs/every required step succeeded. Flutter format/analyze passed;
1047 tests passed and one panel revocation case failed at line194. Seven other
panel cases passed. All downstream Flutter native/browser/wire/Web steps were
skipped, not passed. See job121014247792.

The controller deliberately emits asynchronous void hints. In pinned Flutter
3.35.4, AutomatedTestWidgetsFlutterBinding.pump checks hasScheduledFrame before
flushing microtasks; if no frame was scheduled yet, that pump can deliver the
hint/setState without drawing the newly scheduled frame. The failed assertion
therefore can inspect the preceding render tree. The test now calls tester.idle
before each existing pump after the same-user replacement and A/B/A hint. This
flushes the asynchronous notification before the frame check. All eight test
bodies, original pumps and assertions otherwise remain exact; no production
controller/panel change, longer deadline, retry, catch, fake success or disabled
assertion. The fixed case still needs new exact-head Flutter execution.

Framework source inspected at the exact pinned tag:
https://github.com/flutter/flutter/blob/3.35.4/packages/flutter_test/lib/src/binding.dart
(pump and idle). No local Flutter/bootstrap bypass or hosted proof is claimed.

## Guarded route composition — 2026-10-25

The earlier route/summary integration limit above is superseded by
CONVERSATION_ROUTE.md: /conversation consumes the existing optional combined
binding, default unavailable. ConversationSummary preserves the original summary
column for both panels; workspace uses only its current guarded snapshot and no
second view/controller. Old tests/assertions unchanged; seven additional actual
App/router fixture cases authored, awaiting exact new-head CI. No default flag,
owned source, receipt/recovery policy, live provider/voice or persistence change.
Actual owned SDK-to-route command/summary journey remains next after CI passes.
