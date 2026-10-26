# Captured own-receipt read projection

SupabaseAiTextTransport.lookupReceipt(reference) is an explicit read-only host
capability. It uses existing operation_receipts authenticated SELECT/owner RLS;
no migration, RPC, grants or RLS changes. Fixed GET /rest/v1/operation_receipts
selects only user_id,operation,client_event_id,status,response_json; filters exact
captured owner/operation/event, limit2 detects duplicate rows. No caller URL,
table, columns, owner override, original request or dispatch token is accepted.
Project/owner metadata must match the trusted configured project/current captured
Auth before I/O. The SAME private SDK Session/token, profile/generation readiness,
busy lane, request deadline, bounded stream/1MiB JSON decoder, no redirects,
no-store headers, abort, late-result fences and actual close drain apply. Text,
scenario and mutation requests cannot overlap this read. No provider invocation,
receipt reservation, retry, claim renewal, storage mutation or Auth writer.

ConversationReceiptSnapshot validates zero/one exact five-field row. Empty means
UNKNOWN (absent or invisible), never proof of no previous dispatch. PENDING must
have null response. COMPLETED requires the existing strict typed start/turn/finish
response decoder. Foreign owner/op/event, extra keys, duplicate rows, inconsistent
status/response, malformed or oversized content fail with fixed safe errors.
UUID association is case-insensitive; payload decoding retains original response.
Snapshot text formatting contains only status, never response text. Models are
immutable; no raw decoded response map is retained.

This result describes the current own-account server receipt, not upstream
provider provenance or correlation with a retained FULL original command. It does
not restore a conversation/UI, clear metadata, unlock a store, authorize another
event or permit provider redispatch. Missing/unknown stays ambiguous. Verified
conditional release and retained-command/response correlation need a separate
reviewed protocol. Runtime/UI/decorator do not install/call this method by default.
Caller must acquire it only after persisted refresh and own-profile readiness,
retain sole ownership and close it before SDK teardown. Server must verify JWT
and RLS; local unsigned JWT fixtures are not that evidence.

Eight SDK cases are authored locally UNRUN: unknown/pending/completed exact GET,
completed turn/finish decoding, foreign project/owner rejected before HTTP,
malformed/misassociated/duplicate/inconsistent rows, and shared-busy/revoke with
ignored-abort late HTTP/actual close drain. Original SDK tests remain unchanged.
Full Flutter/analyzer/build/native execution requires exact-head CI. Parentf012aad
CI40329878789/latestattempt1 all5/every required step SUCCESS; both owned A-B-A
cases explicitly passed in Flutter121596969914, retained native OWNED marker in
Windows121596256276. New read capability requires separate evidence; no hosted
PostgREST/JWT/provider/learner proof or Personal Alpha acceptance. All14 hosted
gates remain pending; defaults/Pro/provider/Auth strategy/security unchanged.

Observed local: 27 real-source Dart receipt projection checks PASS across all3 operations (unknown/pending/completed, duplicate/foreign/extra/inconsistent responses and fixed FormatException with no source). This is model execution only, not SDK/Flutter/RLS/hosted proof. Format3 zerochanges and46 QA PASS; eight new SDK cases locally UNRUN.

## Owned runtime read binding

PersistentSupabaseRuntime.createConversationReceiptLookup now exposes an explicit
borrowed CapturedConversationReceiptLookup only under existing conversation opt-in,
persisted refresh and own-profile readiness. Default/staging configuration is
unchanged and UI does not acquire it. AiTextRuntimeOwner caches one reader on the
SAME lease used by text/conversation/scenarios. No SDK/transport/token writer/store
owner or independent busy lane is added. Acquisition sends no HTTP/storage call.
Lease creation/orphan/reentry guards mirror the retained scenario reader; account
invalidation synchronously revokes the read capability, then original transport
actual drain blocks another generation. Repeated acquisition retains same reader.

The read-only port is implemented by the existing SDK transport and forwarded
through ReceiptGuardedAiTransport with pre/post-session checks; forwarding does
not consume/reset its mutation attempt or call receipt storage. Reader captures
exact Auth hint/ready generation, checks before/after I/O and suppresses stale
success/error, maps unknown/private errors to fixed safe codes. Busy errors stay
busy; wrapper owns no shutdown or transport. Host owns original runtime close.
Read results still cannot clear metadata/restore conversation/grant another event.

Eight actual owned-runtime/SDK cases are authored locally UNRUN: unknown/pending/
completed fixed captured GET with cached reader and no storage; held own profile/
explicit flag; completed lookup leaves pending mutation blocked; foreign owner
no HTTP; shared text busy and refresh/logout during ignored-abort GET. Original
lease is revoked immediately; no replacement or receipt clear until real HTTP
drains. Refresh permits a new reader after drain while metadata remains; logout
clears only after drain and keeps source terminal. Auth/JWT/profile/vault/storage/
HTTP are TEST ONLY. No hosted RLS/PostgREST/provider proof or default activation.

Parentd36d6d6 CI40338776513/latestattempt1 observed all5/every required step SUCCESS;
all8 lookup SDK cases in Flutter121628430241, native OWNED marker121627494082.
New8/fullFlutter/analyze/native/build require new exact-head CI. Fresh official
Dart3.9.2 SHA verified;4 real-source wrapper/owner-graph checks PASS (no-I/O capture,
unknown read and same-user new-session late-result revocation), not SDK/Flutter
proof. Initial disposable verifier lacked its error-type import; adding ONLY that
harness import fixed it, no repository diagnostic or test weakened. Formatting/
46 QA/inventory138/whitespace/separate review recorded in PR41. All137 previous
QA/findings/gates retained/all14 hosted pending. Next host/native read journey,
retained full-command/result correlation and verified conditional release; missing
or unknown never grants provider redispatch or a new event.
