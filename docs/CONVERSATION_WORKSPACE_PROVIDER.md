# Composed workspace provider — Issue #17

conversationWorkspaceBindingProvider consumes the two existing optional owned
sources and their retained view bindings. AccountStartupApp already overrides
both source providers with its captured Windows/startup owner; this addition
changes no App/router/flag/SDK/Auth code and mounts no panel. Default sources
remain null; no preview or simulated Auth/provider/save path is installed.

Require identical source objects BEFORE acquiring child bindings. Once both exist,
require the identical nonnull owner hint stream and current reader/flow, with a
second reader check after flow readiness. Missing/mixed owners/streams/retired
capability/raw getter failure yields null, never a partial pair. Existing binding
notifiers independently observe account readiness and the shared owner hints;
stream error/closure disables them. Reading the composed provider never loads,
starts, generates IDs or resets an active/uncertain/finished retained flow.

These checks prevent accidental independent source overrides. They DO NOT
authenticate arbitrary trusted host implementations or prove generation pairing:
the actual owned runtime must retain both on one current lease and synchronously
revoke/drain at barriers. Forged in-process providers are not a learner API or a
security boundary. Actual mounted startup/SDK-to-panel pairing and route+summary
composition remain next, with explicit opt-in/no default activation.

conversationEventFactoryProvider captures createConversationEventId as a callable;
no Random instance/ID is created during provider reads or binding. Explicit new
workspace commands call it after reserving the command slot and retain that ID in
the original immutable DTO. UUIDv4 uses16 bytes from Random.secure, version/variant
bits and fixed lowercase hexadecimal shape, no timestamp/counter/fallback. If
secure entropy is unavailable, existing controller redacts the thrown failure;
never weaken randomness or retry under a new ID. Retry dispatches the captured DTO,
not this factory. Injection is trusted host/test configuration, never learner data.
The factory is not provider/Supabase authentication or an upstream idempotency proof.

Ten TEST ONLY Riverpod/source cases AUTHORED, NOT locally run: default null,
different same-user source objects rejected before acquisition, retained identity
with zero request/ID until explicit callback, mismatched owner streams, readiness
hint, same-user replacement/A-B-A retirement, stream error and closure preserving
borrowed resources, controlled factory failure/no partial pair, canonical UUIDv4
shape/256 unique smoke values. Auth/ports/source are fixtures, not actual mounted
App/SDK or hosted learner proof. Existing tests/production bytes remain unchanged.

Fresh official Dart3.9.2 SHA verified. An exact copied production UUID function
executed256 canonical shape/unique smoke checks successfully in standalone Dart;
this is not statistical entropy assurance and does not execute the Riverpod cases.
Format2/0changes, QA inventory107/46regressions/whitespace/separate scope/security
review passed. Full local Flutter/analyzer/Riverpod/widgets/build unrun; exact-head
CI required/no denied bootstrap retry or bypass.

Parentdcf0e13 CI40179525017/latest attempt1 passed allfive jobs/every required step,
no skips. Flutter log121127676798 confirms1154 Flutter/five Chrome/all7 workspace
panel cases. Earlier dynamic fallback correction now verified; no hosted claim.
Next exact new-head allfive/latest-attempt/new10cases, then actual owned host
journeys and opt-in route+summary composition with pending/manual retry/finished
fences. Keep41 draft/17open/AIoff/all14 hosted human gates pending. No merge/deploy/
release/provider/Auth strategy/collection/spend/security reduction/schedule action.

## Stable test hint identity — 2026-10-25

Exact84ecab7 CI40184370857/latest attempt1 passed format/analyze and allfour
non-Flutter jobs/every required step, but five of the ten new provider tests
failed because ready pairs were unexpectedly null. Downstream Flutter native/
Chrome/Web steps were skipped. Flutter log121142246582 observed; no full-CI pass.

The original test Source returned StreamController.stream on each getter. Dart
returns equal but nonidentical wrapper objects there. This did not model the
production AiTextRuntimeOwner's late-final cached changes stream, forwarded by
both runtime source getters. A standalone Dart probe confirms wrapper identity;
the unchanged original35-file graph reproduced the same five failures on core
Riverpod2.6.1 with only Flutter import/runner adaptation.

Test-only _Hints now captures one stream and forwards void/addError/close to its
original synchronous broadcast controller. All10 original test bodies/assertions
remain exact, including identity and closure/borrowed-resource assertions. A new
case intentionally returns uncached equal wrappers and still requires null/no
HTTP. Production provider/source/SDK/identity guards are byte-identical; no switch
to equality, assertion removal or weaker security behavior.

All11 cases passed after correction in that same graph. Strict casts/inference/
raw-types analysis of provider/test clean. Official Dart3.9.2 SHA verified; pinned
riverpod2.6.1/http/logging/supabase version+archive-hash records match repository
(direct/transitive classification differs). The portable harness substitutes
flutter_test->test1.26.2 and flutter_riverpod->core riverpod2.6.1 only; it is not
actual Flutter/SDK/hosted execution. New-head full Flutter/CI remains required.
Format1/0changes,46QA/inventory107/whitespace/separate original-body/graph parity
review passed. Keep all default flags/routes/gates and pending host work unchanged.
