# Metadata-only conversation receipt reference — Issue #17

`ConversationReceiptReference` is an additive pure Dart local format, version1.
It identifies an EXISTING receipt by trusted project origin, owner UUID, one of
start_conversation/conversation_turn/finish_conversation, and client event UUID.
Named constructors take the existing immutable typed requests; only the event
identity is retained. The three operation scopes remain distinct even with the
same event UUID. UUID spelling, including schema-permitted nil/case, is preserved.

There is no original request, Japanese text, scenario/session ID, transcript,
response, token, dispatch claim, quota or permission in the reference. No command
can be reconstructed or replayed from it. It supplies no authentication, receipt
existence, completion, ownership, cancellation or safe-new-event authority.
`matchesScope` compares only local project/account partition metadata, folding
logical owner UUID case and canonicalizing trusted HTTPS origin; it returns false
for malformed scope input. An attacker can construct matching metadata: a fresh
verified server identity/own-profile barrier and authenticated authorized lookup
are still required. No new endpoint or lookup transport is implemented.

The constructor accepts only a bounded HTTPS origin/root (no userinfo, path,
query, fragment, whitespace or non-ASCII configuration). Case/default443/root
aliases canonicalize; another host or nondefault port remains another partition.
IPv6 follows the existing vault origin convention. This checks shape, not DNS,
certificate trust or configured-project authority. Caller supplies trusted app
configuration and verified identity; never expose URL/key/owner input to learners.

`toJson` returns five fresh scalar fields. `fromJson` requires exactly those
keys, integer version1, a canonical origin, known operation and valid UUIDs;
unknown/nested/credential/payload fields are rejected. `encode`/`decode` define
ONE canonical local JSON encoding (including key order), capped at1024 UTF-8
bytes with a preliminary UTF-16 bound. Decoder parses once then requires exact
re-encoding: duplicate members, alternate escapes/order/whitespace and trailing
data fail. This rule applies only to this new local format, not frozen wire JSON.
Invalid parsing exposes one fixed FormatException with no source/offset/input.
Default toString omits every value; IDs/project metadata must not be logged.

## Scope and next integration

This is a testable identification primitive for future restart reconciliation.
It performs no I/O, secure storage, encryption, HTTP, UI, new UUID generation,
retry, dispatch, transcript collection, logout/expiry policy or automatic action.
Current retained-original route recovery remains memory-only/same generation.
No reference is captured/saved/loaded by the app yet, and no restart is restored.

Next integration needs a separately reviewed secure metadata store and lifecycle:
exact project+owner partitions, caller ownership, bounded pending capacity without
eviction/expiry that abandons uncertainty, write-before-first-dispatch, generation
guards, late-write/clear ordering and fixed storage errors. Credential storage is
not permission to store learner transcripts or plaintext fallback. Corrupt,
missing or wrong-scope metadata must never authorize replacement event dispatch.
Fresh verified account/profile, actual old-I/O drain and trusted server receipt
lookup must precede any restored state; metadata alone cannot restore readiness.
Lookup must not renew claims or call the AI provider again. Authenticated lookup,
secure OS bridge/restart, logout/refresh/account-switch failures and actual learner
proof remain outstanding. No public API/schema/migration/RLS/default/provider or
Auth strategy change is made; all14 hosted release groups remain pending.

## Verification

Ten new pure cases cover all3 typed operations/metadata-only exact round trips,
project/account partition and aliases/ports/IPv6, UUID spelling/nil, exact keys/
version/types, payload/token rejection, canonical/duplicate parsing, byte limits,
fixed errors and immutable/fresh exports/redacted toString. Existing conversation
request tests and fixture bytes remain unchanged. Execution evidence is recorded
in PROJECT_STATUS/PR41; pure tests are not SDK/storage/hosted learner acceptance.

Parent516ddf41 CI40219074959/latest attempt1 passed allfive jobs/every required
step/no skips. Completed Flutter log121246965199 confirms1206Flutter/fiveChrome
and both same-account refresh recovery variants. Web/Windows/native/SQL/Edge
checks passed; TEST ONLY component evidence. New source needs its own full CI.

Observed local result: all10 new cases and7 unchanged conversation-request tests
passed. Fresh official Dart3.9.2 zip SHA256 verified; fresh five-file source/test
graph plus unchanged frozen fixture, only Flutter_test->test1.26.2 and fixture
path adaptations. Strict casts/inference/raw-types +lints6, fatal infos analysis
clean. Two interpolation-brace lint corrections in new tests preserve assertions.
Pinned format2/zerochanges, inventory118 and46 QA regressions passed; inventory
is not execution of feature/live cases. Separate review covers metadata bounds,
canonical decoding/error redaction, scope semantics/no-authority and no activation.
All117 previous QA objects/findings/gates and old source/tests remain unchanged;
all14 hosted groups pending. Full local Flutter/SDK/native/build UNRUN; no denied
Flutter bootstrap retry or bypass. New exact-head CI remains required.
