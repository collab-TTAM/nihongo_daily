# Frozen conversation mutation requests — Issue #17

conversation_requests.dart supplies immutable StartConversationRequest,
ConversationTurnRequest and FinishConversationRequest for frozen v0.1 only.
Constructors validate named scalar inputs; fromJson rejects missing, additional,
null or incorrectly typed fields before construction. toJson returns fresh maps.
The three original frozen fixture requests round-trip without alteration.

Caller supplies scenario/session and client_event_id; models never generate,
normalize, replace or retry an event. UUID format retains uppercase and nil as
permitted by the existing schema. A structurally valid ID is not proof of scenario
existence, owner identity or a server receipt. Reuse an accepted immutable request
only through a separately reviewed captured-session retry mechanism; this file
cannot authorize dispatch or replay after an account switch.

Wire levels reuse AiTextLevel for N5..N1 compatibility; current product/UI scope
stays N5/N4. Turn text retains exact whitespace/combining characters and uses the
schema's 1..5000 Unicode code-point length with an early 10000 UTF16-unit bound.
Schema permits whitespace-only input; a future view may reject empty-looking
text separately without silently rewriting accepted wire data. Fixed
FormatException has no raw source, payload or credential details.

Seven authored test groups cover unchanged three fixture round trips; allfive
levels and uppercase/nil IDs; fresh exports and captured identity after mutations;
Unicode/code-point bounds; every constructor identifier; strict missing/extra/null/
wrong-type and authority-field rejection; safe failure without input/source echo.
Execution evidence is recorded in PROJECT_STATUS and the exact-head PR checkpoint.
Pure checks do not establish Flutter, network, SDK or hosted learner acceptance.

No response decoder, gateway/transport, event generator, automatic retry, durable
receipt/transcript storage, conversation UI or voice/audio contract is installed.
After new exact-head CI, add strict responses, then captured ownership/idempotent
conversation transport/recovery and explicit view states. Server remains the
owner/receipt authority. Default AI flags remain off; hosted identity/provider,
voice, collection/spend and release gates remain open. No live provider/Auth
strategy change follows from these pure models.
