# Captured Supabase conversation HTTP port — Issue #17

The existing SupabaseAiTextTransport now also implements the closed
ConversationMutationTransport port. Its name remains for compatibility with the
existing text runtime. invoke accepts only start_conversation, conversation_turn
and finish_conversation; arbitrary paths/URLs, text operation names and unknown
operations fail before HTTP. Trusted owner configuration still fixes the HTTPS
project/public key. Strict request DTOs snapshot exact event/session/text wire;
strict corresponding response models decode bounded successful JSON.

Text and conversation calls on the same capability share its single actual HTTP
busy/drain lease. No second network engine, new credential writer, global current
user client, wider Auth/REST allowlist or separate uncoordinated HTTP client.
Captured ReviewSession identity, exact SDK Session/token, readiness generation and
expiry checks remain before dispatch/publication. Server verifies JWTs; decoded
unsigned claims in tests are only fail-closed hints. Endpoint/operation selection
is not proof that a hosted function is configured or deployed.

Retained transport guards apply unchanged: monotonic15s maximum deadline,
32KiB request/1MiB response/4096 reads/depth16, strict UTF8/JSON without duplicate
keys/BOM/compression, no redirects, no-store, fixed safe HTTP/status errors and
401 permanent revoke. Ignored abort/held headers or stream cancellation keep
busy until actual injected HTTP cleanup settles. close drains accepted work,
revokes permanently and leaves borrowed SDK/HTTP clients open. No automatic retry.

The port itself is stateless about receipts/progression. Caller must retain the
same CapturedConversationSession/lane and immutable event for uncertain retry,
revoke every lifecycle barrier and share the owner capability for text/conversation.
Do not create another transport/session to bypass uncertain work. A local timeout
or drain does not prove backend cancellation, rollback or provider deduplication.
Runtime-owned conversation factory, startup/UI wiring, durable restart/server
reconciliation and hosted learner evidence remain outstanding. Existing default
runtime still exposes text only; no conversation dispatch/provider/default flag
is activated by this component extension.

Ten additional SDK/HTTP cases retain every original28 test/helper unchanged:
three endpoint/exact bearer/wire calls, closed operation/body/session rejection,
each operation's wrong shape/duplicate-key decoding, text-conversation busy
fencing in both directions, actual captured-session progression/cache without
redispatch, timeout/ignored-abort/exact-event retry after drain and 401/same-user
SDK replacement. Auth HTTP/unsigned JWT/AI streamed responses are TEST ONLY.
Observed runner/analysis/CI evidence is recorded in PROJECT_STATUS and PR41.
All14 hosted release groups remain pending; voice/audio collection, provider,
Auth strategy, spend and release decisions retain their existing human gates.
