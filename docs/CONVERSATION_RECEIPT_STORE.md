# Caller-owned pending receipt store component — Issue #17

`ConversationReceiptStore` manages ONE pending metadata reference per canonical
project/account partition. Caller must supply `SecureConversationReceiptBackend`;
there is no production backend, default, file/memory fallback, native channel or
application wiring in this increment. The port contract requires bounded secure
I/O, confirmed durable writes/clears and no sensitive logs. A type/interface does
not prove encryption, OS security or persistence. TEST ONLY memory ports exercise
the state machine; they must never become a learner storage backend.

`ConversationReceiptScope` reuses the reference codec's HTTPS/UUID validation,
canonicalizes origin and logical owner case, and supplies no authentication.
`reference.scope` is additive; original v1 JSON/codec/factories stay unchanged.
The separate target namespace is
`NihongoDaily.ConversationReceipt.v1|<origin>|<lowercase owner UUID>`.
It never shares the refresh-secret target. Existing Windows refresh-vault native
validation remains unchanged and does NOT accept this new namespace. A reviewed
OS implementation/probe is still needed; do not bypass it or use plaintext.

## Pending state and lifecycle

`read` returns a validated immutable reference/null from the exact partition.
`reserve` first reads existing storage. It writes only when empty, treats an
identical canonical reference as inert and rejects every different pending
reference with conflict. No replacement, capacity eviction, expiry, automatic
retry, completion inference or deletion of malformed/foreign data occurs. Exact
wire spelling remains conservative even within one logical scope. The future
host must confirm reservation BEFORE dispatch AND freshly check captured Auth/
generation; storage success/null/conflict is never mutation/retry authority.

Backend read/write failures permanently fence normal access with fixed errors;
corrupt, noncanonical, wrong-scope or unexpected typed values also fail closed.
No input/backend details escape errors or default toString. Wrong-scope reserve
input is rejected before I/O. Metadata still contains account/project/event IDs
and must not be logged. No token/transcript/original command is retained here.

All operations serialize before external backend reentry. `clearForSignOut`
permanently revokes immediately, then clears ONLY its exact partition after all
actual earlier I/O. Queued old operations do not reach the backend; late reads
cannot publish and late successful writes cannot reopen the store. Clear still
runs after an earlier write failure with uncertain persistence. Concurrent clear
calls share one operation; explicit retry after a failed clear is permitted but
never reopens access. This local clear is NOT server cancellation/receipt deletion
or permission to send a replacement event. No general pending-discard API exists.

`close` revokes immediately, preserves pending metadata, drains actual operations
and releases exclusive ownership afterward. It does not close the borrowed backend
or erase confirmed saved metadata. One isolate-local owner per canonical target
prevents two facade writers, including configuration/case aliases. This is NOT
cross-process CAS/locking or multi-device synchronization: caller must prevent
competing instances; a future secure OS adapter needs its own reviewed ownership
contract. Failed sign-out clear remains an explicit caller-observed error; close
does not turn it into successful logout or certify remote revocation.

## Verification and remaining work

Eleven new pure TEST ONLY backend cases cover immutable/no-overwrite reservations,
partition/namespace/owner exclusivity, corrupt/foreign data, read/write failures,
pending write then sign-out/queued work, close/preserve/actual drain, late read,
failed clear/explicit retry, serialized conflicting reservations and ambiguous
failed write then clear. Existing ten reference/seven request tests remain intact.
Execution evidence is recorded in PROJECT_STATUS/PR41.

Parenta6a2aeb CI40220251665/latest attempt1 passed allfive jobs/every required
step/no skips. Completed Flutter log121250462356 confirms1216Flutter/fiveChrome
and all10 reference codec cases; Web/Windows/native/SQL/Edge passed. This is
component proof, not hosted learner acceptance. New source needs exact-head CI.

Next: reviewed secure OS namespace/backend with actual process-restart/ownership
and failure probes; captured runtime write-before-send and generation guards;
trusted authenticated lookup and conditional release only after verified receipt
reconciliation. Metadata/null/corruption/missing/unknown lookup must never recreate
the original DTO, authorize a new event, renew claims or dispatch another provider
call. Fresh Auth/profile and old actual-I/O drain remain mandatory. Current route
recovery is still memory-only; no learner restart or secure OS store is enabled.
No default/Auth strategy/provider/public API/schema/RLS/CI/dependency/Pro change,
new collection or release acceptance. Keep41draft/17open/AIoff/all14 hosted gates.

Observed local:11new+17unchanged reference/request tests PASS. Fresh official
Dart3.9.2 archive SHA256 verified; fresh seven-file source/test graph and original
fixture, ONLY Flutter_test->test1.26.2 and fixture path adaptation. Strict casts/
inference/raw+lints6/fatalinfos analyze CLEAN. Four new-store lint infos corrected
with braces/wildcard parameters, no weakened assertions. Format3/zerochanges,
QA inventory119/46 QA regressions/whitespace/separate ownership/no-overwrite/
late-I/O/error/clear/close review PASS. All118 previous QA objects/findings/gates
and old tests exact; all14 hosted pending. Full local Flutter/SDK/native/build
UNRUN; no denied Flutter bootstrap retry/bypass. Six paths: additive scope in
conversation_receipt_reference.dart, new conversation_receipt_store.dart,
conversation_receipt_store_test.dart and this doc; PROJECT_STATUS.md, qa/matrix.json.
Branch automation/issue-11-plan-sdk-integration, parenta6a2aeb892af3b51de806f80cc66a4c18b669b53;
new commit/CI handoff in PR41/Issue17.
