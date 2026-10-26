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
