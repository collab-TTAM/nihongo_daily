# Conversation source and view binding — Issue #17

The default aiConversationSourceProvider is null. The explicit AccountStartupApp
host overrides it with its active startup controller's borrowed conversation
source. Neither override nor binding enables the runtime flag, starts HTTP, creates
event IDs, or substitutes mock success. Main and Windows staging opt-in flags are
unchanged. No route, conversation screen or scenario selector is introduced.

A private Riverpod notifier watches accountStateProvider independently of the
owner's AI hints: readiness may arrive before any AI lease exists. It subscribes
to the source's void hint stream and acquires the existing retained ready flow.
The binding holds that flow and the same hint stream, never a token or HTTP client.
For identical captured flow, owner notifications preserve binding identity;
missing/revoked flow clears it and a new generation replaces it. Acquisition is
serialized against synchronous source notification reentry. Exceptions publish
only null; stream getter/error/closure fails closed. Disposal cancels only its
subscription (including consuming cancellation errors), preserving borrowed flow,
source and SDK ownership. It never revokes, restarts or resets a conversation.

Bindings are capabilities, not snapshots or proof of readiness at future use.
Consumers must check captured session on every read/dispatch and synchronously
invalidate their controller/view on owner loss. The existing controller redacts
late/revoked results. A hint cannot make an old flow current. Uncertainty and
finished receipts remain with runtime; remounting must not create a replacement
flow or fresh event to bypass them. Durable receipt recovery/reconciliation and
reviewed new-round policy are still absent. Voice remains unavailable.

Ten source/notifier/Riverpod cases are authored: null/default unconfigured,
throwing stream getter, same-flow identity/no request, readiness loss/new account,
revoked/failing source, stream error and closure, preserved borrowed lifetime and
cancelled listener, default/source override replacement, synchronous acquisition
reentry. They use actual CapturedConversationSession with TEST ONLY Auth/port;
no mock response or provider invocation is supplied. Tests are NOT locally executed:
Flutter SDK/native runtime is unavailable; exact-head CI must run analyzer/tests/
platform builds. Full mounted App-to-conversation route proof remains later work.
Existing text binding/tests and all previous startup/controller tests are unchanged.

Parent cb36c3f CI40116186234/latest attempt1 succeeded in allfive jobs/every step,
1028 Flutter and five Chrome tests (log120938276389), including21 conversation
controller cases. This is parent/component evidence, not new-head acceptance or
hosted JWT/provider/voice/learner proof. All14 hosted release groups remain pending.
Next inspect exact new-head/latest-attempt CI, fix diagnostics, then mount guarded
conversation UI with actual startup coverage and explicit recovery policy. No
Auth/provider/schema/security/collection/spend/release or default activation change.
