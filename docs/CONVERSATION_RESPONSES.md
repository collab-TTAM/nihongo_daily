# Frozen conversation responses — Issue #17

conversation_responses.dart decodes and exports start, turn and finish responses
from frozen v0.1. Private constructors prevent bypassing validated construction.
Assistant messages require all six fields and role=assistant, UUID, exact Japanese
text1..5000 code points, explicitly nullable Vietnamese text1..5000 and opaque
audio_ref1..1000. sequence_no must be a nonnegative Dart integer. UUID nil/uppercase
and original text spelling are retained. Unknown/missing/null/wrong-type fields
are rejected except the explicit nullable fields. Every bounded text scan first
checks its maximum UTF16 size. This is shape validation, not session ownership,
message sequence correlation, provider trust or content authenticity.

Turn live_feedback may be omitted or an empty list; exports preserve that
distinction. Present null is rejected. Finish scores require all three finite
numbers in [0,100], retaining integer/fractional representation. Corrections,
strengths, next-focus strings and recommendation lists accept0..100 entries;
strings follow their original2000-code-point limits. Existing strict immutable
AiTextCorrection and AiTextItemRef decoders are reused and their fixed parse
errors normalized to Invalid conversation response, with no raw source.

Every exposed nested collection is immutable. Decoding snapshots its input and
each export constructs fresh maps/lists. Empty corrections and recommendations
remain empty; schema-permitted duplicate references are not silently removed.
Scores/recommendations authorize no mastery, SRS, progress or database write.
An audio_ref is opaque model data, not a safe URL or playable asset; this increment
does not fetch/open/play audio or introduce an audio collection/retention contract.

Eight test groups cover three frozen round trips; omitted/empty/null feedback;
required message keys/role/UUID/sequence; Unicode/audio limits; finite numeric
bounds; all list bounds/empties; nested input/export mutation and immutable views;
malformed corrections/references/mixed error objects and fixed safe failures.
Observed execution evidence is in PROJECT_STATUS and the exact-head PR handoff.
Pure tests are not Flutter/network/hosted learner evidence.

Parent061643f CI40069345322 passed allfive jobs/every step,931 Flutter including
seven request-model tests and five Chrome cases. New exact-head CI must confirm
these response tests. No transport/retry/receipt validation/UI/default/provider
activation is installed; next bind immutable requests/responses to a captured
owned-session idempotent gateway/recovery policy. Server remains the authorization
and receipt authority. Hosted identity/provider/voice/learner/physical launch and
all14 release groups remain open. Main/staging AI stay disabled.
