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


## Native owned-runtime receipt read — 2026-10-26

- Branch `automation/issue-11-plan-sdk-integration`, parent
  `f8e773e87a9f4ce005f948f7412aab5159e65fe8`, draft PR #41 / issue #17.
  CI [40348831434](https://github.com/collab-TTAM/nihongo_daily/actions/runs/40348831434)
  đúng head/latest attempt 1 đã đạt đủ 5 jobs và mọi step, không skip.
  Log Flutter121663951669 xác nhận 8 owned reader +8 SDK lookup cases;
  Windows121663118915 xác nhận native OWNED production runtime marker.
- Mở rộng `receipt-owned-reopen` trong Windows probe hiện có: tiến trình mới
  dùng production PersistentSupabaseRuntime, SDK và Credential Manager thật,
  phục hồi token rotation/own profile rồi lấy cached reader cùng AI lease.
  Trước startup/own-profile readiness không cấp reader; acquisition không I/O.
- Ba GET TEST ONLY trả UNKNOWN/PENDING/COMPLETED kiểm tra endpoint, năm query
  fields, captured bearer/key, empty body, no redirects/no-store và native
  metadata trước gửi. Kiểm tra typed completed response, metadata không đổi
  sau mỗi read, cả cùng event và event khác vẫn bị chặn với zero mutation HTTP.
  Sau close reader cũ bị từ chối không thêm HTTP; token/receipt vẫn giữ nguyên.
  Các phase logout/absent/cleanup gốc vẫn chạy, không đổi deadlines/assertions.
- Marker mới: `Windows OWNED receipt lookup unknown/pending/completed preserve/no-redispatch/stale-reader passed (TEST ONLY Auth/HTTP)`.
  Auth/JWT/profile/HTTP synthetic; không phải hosted RLS/PostgREST/provider proof.
  Không thay production code, default UI, Auth strategy, SQL/RLS hoặc Pro scope.
- Native Windows/Flutter tests/analyze/build của thay đổi mới chưa chạy local;
  phải kiểm tra CI exact-head/latest-attempt và marker mới. Format/QA/review và
  commit/CI mới được ghi ở checkpoint đầu PR #41. Inventory không thay thế test.
- Next: kiểm tra CI; sau green kiểm chứng hosted RLS, full retained-command/result
  correlation và verified conditional release. Read không cấp quyền clear,
  restore/replay hoặc lệnh mới. Learner memory-only/một pending mutation;
  cả 14 release groups chưa nghiệm thu, PR vẫn draft, không đổi lịch.

Local: official Dart3.9.2 SHA256 verified; formatter applied only new-line layout;
strict format check zero changes. 46/46 QA regressions PASS, inventory139 valid;
all138 old QA cases/findings/gates exact. Separate diff review confirms all old
fixture/PowerShell lines retained in order. Flutter lint include unresolved locally;
this is not full analysis or execution of the new native assertions.

## Correct native pending expectation after observed CI failure

CI40354457697/sourcee3bb21f/latestattempt1 FAILED Windows121683163897 in actual
Dart/native bridge verification. Four other jobs/every step succeeded; downstream
Windows staging/release/native journal/artifact checks were SKIPPED, not passes.
The new lookup marker was never observed. Parentf8e773e CI40348831434 remains prior
historical successful evidence only. Do not claim this failed run as full/native
read proof.

The added native loop wrongly required SYNC_CONFLICT for both event IDs. Existing
ConversationMutationLane deliberately retains _pendingKey after the original
receipt conflict; a DIFFERENT event is denied before transport as
AiTextRequestPending. The fixture caught only AiTextFailure, so this expected
pending denial escaped and failed the process. Production behavior is unchanged.
The loop now requires exact original-event SYNC_CONFLICT and exact different-event
AiTextRequestPending. The opposite pairing fails. Every zero mutation HTTP, native
metadata-before/after-read, three lookup statuses, stale reader, native rotation,
logout/absent/cleanup/deadline assertion remains; no success/fallback/reset added.

One regression composes actual CapturedConversationSession/lane/receipt decorator/
store with preexisting metadata and repeats the two exact denials three times,
requiring unresolved/current session, zero inner dispatch and unchanged metadata.
Fresh official Dart3.9.2 SHA verified; fresh18-file pure harness adapts ONLY
flutter_test import to test1.26.2 and copies exact original fixture bytes. All13
cases (12 old+1new) PASS, strict casts/inference/raw analysis of that graph CLEAN.
A direct real-source verifier independently reproduced all6 exact denials.
This is not Flutter/SDK/native Windows execution; new exact-head CI must prove
both lookup and original OWNED Windows markers and every required step. No new
hosted Auth/JWT/RLS/provider proof/default activation/security change. All14 gates
remain pending; next retained-command correlation and conditional receipt release.
