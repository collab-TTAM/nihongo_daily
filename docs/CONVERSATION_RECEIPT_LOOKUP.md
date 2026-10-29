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

## Full original-command association prerequisite — 2026-10-27

`ConversationReceiptCommandMatch.forStart/forTurn/forFinish` is a pure decoder
for a prospective SIX-field projection: the five existing receipt columns plus
`request_json`. The trusted host must supply its retained immutable original
request DTO and the exact reference captured for that command. It cannot rebuild
that DTO from the five-scalar Windows metadata. No original text/command is added
to disk, logs, defaults, transport or UI. Existing five-column SDK/owned-reader
lookup remains unchanged; it cannot satisfy this new decoder for an existing row.
A future separately reviewed reader must retain the same authenticated session,
trusted project, own-profile, bounds, busy/deadline/abort/drain and stale guards.

Before interpreting an existing row, require exact operation and reference event,
zero/one row, <=1MiB UTF-8 JSON, exactly six row keys and every original request
key/value with no extras or missing fields. JSON member order is immaterial.
UUID spelling in request_json, Japanese code points, whitespace, level, scenario,
session and event remain EXACT; database row UUID association retains the existing
case-insensitive rule. A valid-looking response or matching event alone cannot
substitute a changed original request. Reuse the original five-field decoder for
owner/operation/event/status and strict typed start/turn/finish results. Failure
returns only fixed `FormatException('Invalid receipt command projection')`, with
no raw source/offset. No row/request map is retained, and decoded output remains
immutable. Empty/invisible is UNKNOWN, not proof of a matched command or absence
of dispatch; pending requires the full original even when response_json is null.

This establishes only stored-JSON association given a caller-supplied original.
It does not authenticate the row's origin/project/upstream provider, prove the
server has released its reservation or identify which caller retained the DTO.
It does not make a response safe to apply to a newer transcript/phase/generation.
It supplies NO clear/reset/retry/dispatch/new-event/store/UI capability. Conditional
release, original command capture across restart, authenticated hosted RLS proof
and integration with current captured runtime still require reviewed work. Read
absence, metadata and successful association must never unlock a pending slot.

Twelve new tests cover all3 completed operations, unknown/pending, key reordering,
changed scenario/level/session/event/text, exact Unicode/whitespace and UUID case,
reference mismatch even for empty rows, missing/extra/wrong-type requests, foreign
rows/duplicates, strict status/result rejection, bounded safe errors and immutable
results/no input mutation. Frozen request/response fixtures are unchanged. Local
results and exact new-head CI are recorded in PROJECT_STATUS/PR41 checkpoint.

Parent `ecb50960814df6892f0a15a44569800747a24378` is now verified by
[CI40357884098](https://github.com/collab-TTAM/nihongo_daily/actions/runs/40357884098),
latest attempt1: all5 jobs and EVERY step SUCCESS, no skips. Windows121695205220
explicitly records BOTH native lookup and original OWNED production runtime
markers; Flutter121696095677 explicitly passes the pending-event regression.
This supersedes that source's pending handoff, not any hosted acceptance gate.
New matcher/native/full Flutter checks need their own exact-head evidence.


Observed local for original-command matcher: fresh official Dart3.9.2 archive
SHA256 verified. Actual9-file source/test graph, only flutter_test -> test1.26.2
runner import and exact fixture copy; all27 cases PASS/no skips (12new +15 retained
request/response), strict casts/inference/raw types +lints6 analysis No issues.
Format2 zerochanges,46 QA PASS, inventory141 valid (not141executed), whitespace
and separate association/bounds/safe-error/immutability/no-authority diff review
PASS. All140 previous QA objects/findings/gates exact/all14 hosted pending.
Full Flutter/SDK/native/build new-head checks UNRUN locally; CI still required.


## Original-bound SDK receipt reads — 2026-10-27

SupabaseAiTextTransport.lookupStartReceipt/lookupTurnReceipt/lookupFinishReceipt
now explicitly bind a supplied FULL original typed DTO to an own-account receipt
read. Trusted host must retain that DTO; five-scalar vault metadata cannot restore
it. The existing five-field lookupReceipt stays unchanged. No runtime/default/UI
reader is enabled by this increment; same-owned reader forwarding/capture remains
next. No commands or text are added to disk/logs or learner configuration.

Before HTTP: current captured SDK Session/token/profile generation and trusted
project/owner match, then operation/event association via strict matcher preflight.
Foreign scope maps UNAUTHORIZED; inconsistent original reference maps fixed
VALIDATION_FAILURE without HTTP. Fixed GET /rest/v1/operation_receipts with ONLY
user_id,operation,client_event_id,request_json,status,response_json, captured owner/
operation/event filters and limit2. Original DTO/text is NEVER in URL/query/body;
only original association is checked locally against the response. No caller table,
column/endpoint override, provider call, mutation, token writer or storage owner.

Use the SAME private _send/captured bearer/key/shared busy lane/deadline/abort/
1MiB/stream limits/no redirects/no-store/actual close drain as retained reads and
text/mutations. A private boolean selects exactly one of TWO fixed projections;
all prior operations keep their original request/response behavior. Pre/post read
and post strict decode current checks suppress late results. Six-field original
mismatch/legacy five-field row/malformed projection maps fixed INTERNAL_ERROR.
Unknown remains ambiguous, and even exact stored association proves neither
upstream provenance nor server reservation release/current transcript applicability.
No clear/reset/retry/redispatch/new-event or recovered conversation authority.

Twelve SDK cases authored: nine operation/status combinations check exact six-field
captured GET/empty body/bearer/key/no-store/no redirects/typed result; foreign scope/
original op/event before HTTP; changed/missing/extra request fields, foreign rows,
duplicates and legacy projection; held GET blocks both text/legacy lookup and close
waits actual ignored-abort HTTP while late completed data is suppressed. All prior
test bodies are retained. Local/CI execution results in PR41 and PROJECT_STATUS.

Parente36ab681997515bd798f449c91152e5744ffaa1d CI40367461388/latestattempt1 now
SUCCESS all5 jobs/EVERY step/no skips. Flutter121731441493 explicitly all12 matcher
cases; Windows121730946426 BOTH native lookup and original OWNED markers. This is
TEST ONLY Auth/HTTP component proof, not hosted RLS/JWT/provider/learner proof.
All14 hosted gates pending; keep draft41/17open/AI default off. Next exact-head CI,
same-owned captured port binding, hosted RLS and reviewed conditional release.


Observed local: fresh officialDart3.9.2 SHA verified. Fresh34-file actual SDK/source/
test graph with ONLY flutter_test -> test1.26.2 runner import/exact fixture bytes;
original pinned supabase2.16.5/http1.6/logging1.3 and ALL shared lock versions exact
except harness-only lints5.1.1->6.0.0/new test deps. All86 SDK cases (12new+74old)
PASS/no skips. Strict casts/inference/raw+lints6 analysis of two changed files
CLEAN. Original old test bodies byte-identical. Initial disposable SDK execute-bit
setup and test-boundary verifier selection corrected; no production diagnostic
or failed case suppressed. Format2/46QA/inventory142/whitespace/source parity/
separate captured authority/fixed query/old-lane parity/no-release diff review PASS.
All141 prior QA/findings/gates exact/all14hosted pending. Not actual Flutter runner,
Windows/hosted evidence; new full Flutter/analyze/build/native CI still required.


## Same-owned original receipt reader — 2026-10-27

ConversationOriginalReceiptReadPort is an optional three-method typed capability
implemented by the existing Supabase transport and ReceiptGuardedAiTransport.
CapturedConversationReceiptLookup.lookupStart/lookupTurn/lookupFinish forward the
FULL immutable DTO on the SAME cached AiTextRuntimeOwner lease already exposed by
PersistentSupabaseRuntime.createConversationReceiptLookup. Existing factory/profile/
persisted-refresh/explicit-conversation flag/generation readiness and actual drain
remain unchanged. No additional SDK/token writer/store/busy owner or acquisition
I/O. Legacy five-field reader remains available; a port without original-read
support fails fixed INTERNAL_ERROR, never falls back to metadata-only matching.

Captured reader reuses original lookup pre/post readiness/exact Auth hint checks,
owner preflight, busy propagation, safe error normalization and permanent revoke.
Receipt decorator checks its captured readiness before/after read and requires the
optional inner port. It never consumes/resets _attempted, calls receipt storage or
permits another mutation. SDK still checks trusted project/original op/event and
strict six-field original result. Original command/text is not persisted or sent
in GET parameters/body. Missing/unknown/pending/completed association grants NO
clear/reset/retry/replay/new-event/provider/UI state authority. No default or route
auto-acquires/calls it; host must supply its retained full DTO in the SAME generation.

Thirteen actual owned-runtime/private SDK cases authored: all3operations x3statuses
with cached acquisition/no I/O/captured bearer/fixed six-column GET/empty body and
no storage calls; completed association leaves existing pending metadata and
mutation rejection unchanged; foreign owner no HTTP; refresh/logout during held
ignored-abort GET revoke immediately, shared text busy, no early metadata cleanup
or replacement capability until actual drain. Refresh preserves receipt and yields
fresh reader; logout clears after drain, source terminal. Original fixture/helpers/
test bodies retained. These new Flutter-dependent cases require exact-head CI;
no local execution is inferred from pure SDK tests.

Parentae35117a881d78910886e272ecb10f09b00abe7e CI40375805507/latestattempt1 now
SUCCESS all5/EVERY step/no skips. Flutter121759316396 explicitly all12 original-bound
SDK reads; Windows121758533456 BOTH native lookup and original OWNED markers.
TEST ONLY Auth/HTTP, not hosted RLS/JWT/provider/learner proof. New full Flutter/
owned13/native build checks pending new exact-head CI. Next native original-read
journey, full-command secure retention design, hosted RLS and reviewed conditional
release; do not infer recovery/dispatch permission from a stored association.
Draft41/17open/defaultAIoff/all14hosted pending; Pro/Auth/SQL/RLS/CI/deps unchanged.


Observed local: fresh officialDart3.9.2 SHA256 verified; actual34-file SDK graph,
ONLY flutter_test -> test1.26.2/exact fixtures. All86 retained SDK cases PASS/no
skips; three changed production files strict casts/inference/raw+lints6 analysis
CLEAN. Pinned SDK2.16.5/http1.6/logging1.3 and all shared lock versions exact except
harness-only lints6/new test deps. Source parity verified. The owned runtime test
graph includes Flutter (137 files); no framework stubs or full Flutter bootstrap
retry. NEW13 owned cases and full analyzer/native/build locally UNRUN/require CI.
Format4zerochanges/46QA/inventory143/whitespace/separate port/lease/readiness/error/
no-storage/no-authority diff review PASS. Initial preservation verifier chose a
new nested loop; corrected boundary confirms ALL old owned tests/helpers byte-
identical. All142 priorQA/findings/gates retained/all14hosted pending. Seven paths:
three AI data files +persistent_ai_text_runtime_test.dart, this status/lookup doc
and qa/matrix.json. Published source/CI/next action in PR41 checkpoint.


## Native original-command read extension — 2026-10-27

The existing receipt-owned-reopen Windows bridge phase now explicitly supplies
its immutable TEST ONLY original Start DTO to the SAME captured production runtime
reader. It never reconstructs a full command from Credential Manager metadata.
After all original five-field lookup assertions, perform UNKNOWN/PENDING/COMPLETED
six-field GET reads, check strict typed completion, real native receipt bytes and
rotated Auth token unchanged. Each status repeats exact same-event SYNC_CONFLICT
and different-event AiTextRequestPending denials with ZERO mutation HTTP.

TEST ONLY _Http mode defaults false so old phases/reads retain their exact
five-field response and counter. Original reads have an independent counter;
validate fixed six-column GET and original owner/op/event/limit2/captured bearer/
key/no-store/no redirects/empty body/native metadata BEFORE returning synthetic
rows. Include original request_json ONLY in that mode. Wrong original event fails
before GET; changed scenario with the same event and valid result fails association;
legacy five-field response under original-read mode fails without fallback. Require
exact original GET counts3/4/5 and unchanged native metadata/zero mutation HTTP.
After actual runtime close both legacy and original reader calls are unauthorized
without more HTTP; rotation and receipt persist for the unchanged logout process.

All previous owned write/reopen/logout/held-logout/absent/cleanup phases, deadlines,
partition checks, Auth rotation/profile barrier, legacy read checks and zero-I/O
assertions remain. PowerShell adds a marker only after successful owned-reopen:
`Windows OWNED original receipt match/status/mismatch/legacy/stale/no-redispatch passed (TEST ONLY Auth/HTTP)`.
Three markers (this +legacy lookup+original OWNED runtime) and EVERY required CI
step must be observed on the new source. No production/default/store/protocol/SDK/
SQL/RLS/Auth strategy/Pro/content changes. Synthetic Auth/JWT/profile/AI HTTP is
not hosted RLS/upstream/learner proof or full-command durable recovery. Association
never grants clear/reset/replay/redispatch/new event; all14 hosted gates pending.

Parent579970d42ff422cb09f822c2e361ed948442123f is verified in CI40385964541,
latestattempt1 all5/EVERY step SUCCESS/no skips. Flutter121795067754 explicitly
all13 owned original-read cases; Windows121794255029 legacy lookup+OWNED markers.
New Windows/Flutter/analyzer/build checks locally UNRUN/await new exact-head CI.
Local fresh officialDart3.9.2 SHA verified; formatting/QA/separate preservation/
no-dispatch/error-pair/count/native metadata review in PR41. Full-command secure
retention, hosted RLS and reviewed conditional release remain next; draft41/17open.


Observed local: fresh officialDart3.9.2 archive SHA256 verified; format1 zerochanges
(unresolved Flutter lint include warning, NOT analyzer proof). 46/46 QA PASS,
inventory144 valid (not144executed). All143 old QA/findings/gates exact; original
owned fixture/PowerShell lines retained in order. Whitespace/separate query/mode/
exact denial-pair/GET-count/metadata preservation/stale/rotation/cleanup review PASS.
Native Windows, PowerShell execution, full Flutter/analyzer/build locally UNRUN;
no bootstrap retry/bypass. Source remains TEST ONLY/no hosted acceptance. Five
paths: windows_sdk_receipt_fixture.dart, verify_windows_vault_bridge.ps1 (Flutter
tool), docs/CONVERSATION_RECEIPT_LOOKUP.md, docs/PROJECT_STATUS.md, qa/matrix.json.
Published commit/new CI/next action in PR41 checkpoint; all14 hosted gates pending.


## Retained original-command access — 2026-10-26 UTC

`CapturedConversationSession.retainedCommand` exposes a sealed typed Start/Turn/
Finish wrapper around the exact immutable request already captured by its retry
closure. The first unresolved input wins; a changed body, event or operation
cannot replace it. UUID casing, level, Japanese code points and whitespace are
preserved. Hosts can pass that DTO to the existing current authenticated
`lookupStart`/`lookupTurn`/`lookupFinish` capability without reconstructing payload
from the five scalar receipt fields. No lookup is triggered by reading the getter.

Read availability is independent of retryability: a nonretryable uncertain command
still needs investigation. The getter redacts during execution, readiness reentry,
actual wire drain after timeout, or revoked/unready ownership. Success or revocation
clears the session reference. Same-user replacement and host A-B-A barriers cannot
restore it. Existing retry, one-pending-slot, receipt and SDK owner guards remain.

The returned value is sensitive data, NOT a capability: it carries no account,
result-application, replay or receipt-clear authority. Its safe string projection
contains no payload. Callers must not log/persist it and must recheck the current
reader/owner before I/O. Revocation cannot erase a previously acquired value from
caller memory; this is not zeroization or durable full-command recovery. Nothing
is written to disk or exposed through the learner/default app in this increment.

Nine added pure cases and all6 existing late-result cases exercise the read fence;
three added owned PersistentSupabaseRuntime cases use the exact captured Start DTO
for UNKNOWN/PENDING/COMPLETED original lookup, then prove no optimistic application,
no metadata clear, same-event conflict/different-event busy and logout redaction.
The latter require CI; Auth/HTTP are TEST ONLY even when the real SDK executes.
Local standalone pure graph: analyzer clean,153/153 tests PASS with fresh official
Dart3.9.2 (SHA256 verified), test1.26.2 and only flutter_test imports substituted.
Full Flutter/owned SDK/native/build locally UNRUN. New-head evidence and commit are
in PR41. Secure full-command retention, verified conditional release and hosted RLS
remain outstanding; missing/pending/completed association never grants new events.

Observed final local review: format4 unchanged, QA46/46 PASS/inventory145 valid,
whitespace clean, all144 prior QA cases/findings/gates exact. Independent diff
review confirmed no changed dispatch/clear/deadline/default/storage behavior.

## Decoded recovered command routing — 2026-10-28

CapturedConversationReceiptLookup.lookupCommand accepts only the existing immutable
PendingConversationCommandEnvelope. A host may explicitly pass the result of strict
scope-bound decode/unprotect; no bytes, map, event override or reconstructed DTO
is accepted by this method. Its exhaustive operation switch forwards the SAME
reference and typed start/turn/finish request objects to the existing original
lookup methods. It cannot fall back to metadata-only lookup when an original-read
port is absent. Existing captured session/owner/readiness, post-I/O stale result/
error rejection and fixed error mapping remain the only read path; actual project/
request equality is enforced by the existing concrete original-receipt transport.

This is an optional read adapter, not automatic disk recovery, authenticated local
provenance, receipt clearing, conditional application, replay permission or a new
SDK/HTTP owner. UNKNOWN remains ambiguous; COMPLETED remains a read snapshot.
No default/runtime/UI/storage activation or retention approval is introduced.
Existing legacy and typed individual lookup APIs remain unchanged.

Eleven authored TEST ONLY port/Auth cases cover canonical decode then exact3
operation DTO/reference identity and pending/completed snapshot forwarding (6),
legacy port no-fallback, foreign-account/revoked refusal, late success/error after
same-owner new session (2), and unknown/readiness loss. No mutation/storage port
exists in this adapter. New Dart format/analyze/tests/build locally UNRUN (SDK
unavailable);46 Python QA/inventory151/diffcheck are separate from execution of
these new tests. Require exact-head CI before pass. Native parent6de953e
CI40683551755 all5/EVERYstep passed, including process/read-publish scope markers;
that is not new Dart routing or hosted learner proof. Remaining backend/captured
lifecycle/root/durable uncertainty/conditional-release/retention gates stay open.

## Decoded envelope through owned SDK — 2026-10-28

Eleven added TEST ONLY cases use the actual PersistentSupabaseRuntime and pinned
SDK, with simulated Auth/vault/HTTP. Canonical scope-bound decode feeds the new
lookupCommand adapter for all three operations and UNKNOWN/PENDING/COMPLETED.
Assert exact GET origin/path/filter/projection, empty body, captured bearer,
no-store/no redirects, one request, correct typed response and byte-identical
pending receipt retained without clear. No lookup grants mutation or release.
Two held-I/O cases exercise refresh/logout: shared SDK busy exclusion, actual
abort, old reader revoked, receipt retained until drain, late COMPLETED ignored,
logout vault clear before receipt clear and fresh reader only after refresh.
Original direct-lookup tests, timeouts, ownership and finally cleanup remain.

Parent28c13d1 CI40685977469 attempt1 passed all5 jobs/every step, including
format/analyze/full tests and required Windows persistent SDK/protected markers.
New11 SDK cases, Dart formatter/analyzer/fullFlutter/build locally UNRUN (SDK
unavailable); QA46/inventory151/diffcheck pass separately. Require new exact-head
CI. This is not hosted JWT/RLS/provider, native full-command persistence, verified
conditional release or learner proof. Secure backend/root/lifecycle/uncertainty/
retention approval and all14 hosted release groups remain open; default unchanged.

## Owned SDK formatter repair — 2026-10-28

CI40690942981 exact79e8817/latestattempt1 passed repo/AI/database/Windows but
Flutter122826040014 stopped at dart format; analyzer/new11 SDK tests/build were
SKIPPED, not passes. The workflow printed the actual pinned formatter diff and
output blob prefix f9254f0: one blank line between recoveredRead and originalAnswer.
Apply that exact output; reverse substitution restores the previous fixture bytes.
No assertion/input/test/deadline/controlflow/production/default/security/CI change.
Local file hash matches the formatter's output; this is not a local formatter
execution claim. QA46/inventory151/diffcheck are separate checks. New exact-head
CI must confirm formatting, analyzer and all eleven owned SDK cases plus every
retained required job/step. No learner/release/retention acceptance follows.

## Owned protected-envelope receipt lookup — 2026-10-28

PersistentSupabaseRuntime.lookupProtectedConversationReceipt is an explicit read
composition. It captures this owner's existing Windows command protector and
original-receipt reader only after the existing conversation opt-in, token
persistence and own-profile readiness. It unprotects/strictly decodes a supplied
bounded ciphertext in memory, then passes the immutable full original envelope to
lookupCommand. Both captured capabilities must still be current before native
work, between native completion and receipt HTTP, and before result/error return.
It does not reacquire a fresh capability after an await or reconstruct a request
from metadata. Retired generation errors become fixed unauthorized; current native
validation/unavailability and receipt errors retain their existing safe typed
failure categories. No token/log/URL/key input, new client/store owner, storage
read/write/delete, release, replay or automatic activation is introduced.

The returned UNKNOWN/PENDING/COMPLETED is a read snapshot only. This method does
not establish original writer/freshness/durable reservation or allow local result
application/receipt release. Actual native protected file backend binding, trusted
root provisioning, serialized captured storage drain and approved retention remain
separate. No learner payload is retained by calling this method.

Seven authored owned-runtime/pinned SDK cases with TEST ONLY native channel/Auth/
vault/HTTP: all3 operations decrypt then exact original receipt GET and typed
COMPLETED with metadata/token unchanged; missing opt-in/readiness does no native/
HTTP; malformed plaintext does no HTTP; logout while native response is held never
starts receipt GET; close during held receipt HTTP suppresses late snapshot and
joins actual work while preserving metadata and borrowed HTTP ownership. All old
11 decoded-envelope SDK cases/fixtures/timeouts/assertions remain unchanged.
Local46QA/inventory151/diffcheck pass separately; new7 Dart format/analyzer/tests/
build locally UNRUN, no SDK. Require new exact-head CI. Parent f784b0b
CI40712778351 all5/EVERYstep passed, all11 prior owned cases observed in Flutter
122903356266. No hosted Auth/RLS/provider/learner acceptance or retention approval.

## Protected lookup late lifecycle failures — 2026-10-28

Three additional TEST ONLY owned-runtime/pinned SDK cases retain every previous
assertion and deadline. During held native unprotect, refresh must revoke old
capabilities, suppress both late success and private error as fixed unauthorized,
and send no receipt HTTP. Metadata survives unchanged/no clear; after drain and
readiness a fresh protector is available and the retained refresh token is intact.
During held receipt HTTP, close signals abort and returns unauthorized; a late
private HTTP error must drain without escaping, preserve metadata, and leave the
borrowed HTTP client open. Finally blocks settle outstanding fixture work.
Native channel/Auth/vault/HTTP are simulated, not hosted/native-file evidence.

Parent d414f81 / CI40724115717 attempt1 passed all5/every step, including formatter,
analyzer/fullFlutter and required Windows persistent SDK/protected markers. New3
Dart cases/format/analyze/build locally UNRUN (no SDK); QA46/inventory151/diffcheck
pass separately. Require new exact-head CI. No production/default/CI/security or
retention change. Concrete file backend/root/storage lifecycle/durable uncertainty/
authenticated conditional release and all14 hosted learner groups remain open.

## Native owned protected-receipt composition — 2026-10-28

The mandatory Windows receipt-owned-reopen phase now calls the production
PersistentSupabaseRuntime.lookupProtectedConversationReceipt with a synthetic
start envelope encrypted through the SAME owned native MethodChannel/DPAPI
protector after refresh-token rotation and own-profile readiness. It checks
UNKNOWN/PENDING/COMPLETED typed snapshots via the original-bound captured SDK
GET. Existing fixed query, captured bearer/key, empty body, no redirects/no-store
and native pending metadata checks execute before every synthetic HTTP response.

The new path rejects corrupted native ciphertext before receipt HTTP; an actually
encrypted envelope with the same event but changed scenario fails original-request
association despite a valid completed response. After awaited close it rejects
stale protected lookup without more HTTP. Independent protected-read counters
require exactly3 status reads, then4 after the mismatch and unchanged4 after close;
all original five-field/original-bound counters and assertions remain intact.
Every status preserves token/reference and repeats same-event conflict/different-
event pending denials with zero mutation HTTP. Original finally/cleanup/deadlines
and all write/reopen/logout/held-logout/absent phases remain mandatory.

The outer verifier prints the additional marker only after the whole reopen phase
succeeds:
`Windows OWNED protected receipt start/status/corrupt/mismatch/stale/preserve/no-redispatch passed (TEST ONLY Auth/HTTP, no payload persistence)`.

This tests native start composition only; mocked-native SDK tests separately
cover all3 operations and held success/error lifecycle guards. New Windows phase,
Dart formatter/analyzer and builds are locally UNRUN (no SDK/native Windows);
require the new exact-head CI and marker. Parent b65e17d CI40730790570/latestattempt1
has all5 jobs/EVERY step SUCCESS; its Flutter log122967308434 confirms protected
reads/refresh late cases and Windows122966318109 confirms all prior owned markers.
Synthetic Auth/JWT/profile/receipt HTTP is not hosted learner/RLS/provider proof.
No payload file persistence, collection approval, application/release/replay
permission or default activation follows. Trusted root/backend/uncertainty,
authenticated conditional application-release and retention approval remain open.

## Native foreign ciphertext and envelope scope — 2026-10-28 UTC

Four additional mandatory receipt-owned-reopen checks use the actual native
protectCommand bridge. For both a foreign account and a foreign project, test
(1) own valid envelope encrypted under foreign DPAPI target entropy, and (2) foreign
scope envelope encrypted under the current target entropy. Production owned
lookupProtectedConversationReceipt must reject each with fixed unavailable before
any receipt HTTP. Independent counters remain3 protected/5 original/3 metadata,
mutation sends remain0, refresh count1, token/native receipt unchanged and both
captured capabilities current. The latter pair exercises strict decoded scope,
not merely cryptographic mismatch. No real learner payload or file is persisted.

All prior assertions/counters/deadlines/process phases remain intact. PowerShell
prints the new foreign account/project entropy/envelope/no-HTTP/preserve marker
only after the entire reopen succeeds. Parent57ff526 / CI40734041937 attempt1
passed all5/every step and original protected lookup marker observed in Windows
122977784908. New4 native cases/Dart formatter/analyzer/build locally UNRUN: no
Dart/Flutter/native Windows. QA46/inventory151/diffcheck pass separately. Require
new exact-head CI. TEST ONLY Auth/JWT/profile/HTTP remain synthetic; no hosted
learner proof, retention activation, replay/release authority or default change.
Concrete backend/trusted root/storage lifecycle/durable uncertainty/authenticated
conditional release and all14 hosted release groups remain open.

## Receipt reader callback lifecycle fence — 2026-10-29 UTC

CapturedConversationReceiptLookup now guards its readiness evaluation against
synchronous readiness/Auth getter reentry. A nested isCurrent returns false and
nested lookup fails before the borrowed read port; this alone does not revoke a
healthy outer reader. After the final readiness callback, recheck exact captured
session identity and terminal revocation before dispatch or result publication.
A callback revoking the reader or rotating even the same user's session cannot
publish readiness. Observed invalidation stays terminal if the old hint returns.
Finally always releases the checking guard, including private callback failures.
The same checks cover legacy and original-command reads; no new SDK or I/O lane.

Six TEST ONLY regressions add four final-callback cases (revoke/same-user session
replacement, before dispatch/after read) and two nested-lookup cases (readiness
callback/Auth getter). They require exact port counts, safe unauthorized failure,
no legacy fallback, terminal invalidation, UNKNOWN preservation and continued
healthy explicit reads after rejected nested work. All original tests/assertions
remain unchanged. These tests are AUTHORED, locally UNRUN: no Dart/Flutter SDK.
QA regression/inventory/whitespace and separate lifecycle/diff review are recorded
in PR41; exact new-head formatter/analyzer/tests/builds still require Actions.
Parent2a87ec7 CI40806643205 attempt1 passed all5 jobs/EVERY step, including Windows
123227145491 required persistent SDK/receipt and post-decrypt markers. Parent
success does not verify this change, hosted Auth/RLS or learner acceptance.

This closes a captured reader guard gap only. No receipt write, reservation,
release/application/replay permission, payload retention, default activation,
Auth strategy/provider/API/RLS or Pro content change. UNKNOWN/missing remains
ambiguous, one pending mutation stays blocking, all14 hosted gates remain pending.
Concrete trusted storage root/backend/lifecycle/durable uncertainty and approved
retention plus authenticated conditional application-release remain outstanding.

## Preserve lookup identity in typed snapshots — 2026-10-29 UTC

ConversationReceiptSnapshot now retains its immutable local lookup reference for
UNKNOWN, PENDING and each COMPLETED operation. matchesReference compares exact
canonical project origin/operation and case-insensitive owner/event UUIDs. It
exposes no raw projection or authority and toString still prints only status.
The reference identifies the query context, not authenticated provenance: UNKNOWN
remains absent/invisible/ambiguous, and metadata cannot authenticate a result.

CapturedConversationReceiptLookup checks the returned snapshot against the
requested reference after the existing post-await lifecycle check. A borrowed
port accidentally returning a valid snapshot from another project, owner,
operation or event now fails with fixed internalError before response publication.
Previously the typed status/response lost that query identity after row decode.
A mismatched result does not trigger fallback/retry or revoke a healthy reader;
an explicit fresh read can still succeed. Existing concrete SDK row validation,
original-request correlation, readiness, shared busy/abort/drain and safe errors
remain required; matching references alone prove neither those checks nor RLS.

Thirteen TEST ONLY regressions cover all3 statuses x all4 differing reference
fields and equivalent UUID spelling. Require rejection/no legacy fallback/exact
port counts/healthy later explicit read/UNKNOWN and status-only formatting.
All original test bodies/assertions remain unchanged. No local Dart/Flutter SDK:
new13/format/analyze/build UNRUN; new exact-head Actions required. QA46/inventory152/
whitespace and separate identity/case/immutability/no-authority/preservation review
are recorded in PR41. Parent9b3643c CI40827527934/latestattempt1 all5/EVERYstep
SUCCESS; Windows123293941022 required persistent SDK/profile/receipt marker seen.
Parent evidence is TEST ONLY, not new-head or hosted learner proof. No default,
payload retention, API/RLS/Authstrategy/provider/Pro/content or release policy
change. Trustedroot/backend/captured lifecycle/durable uncertainty/authenticated
conditional application-release/retentionapproval and all14 hosted groups remain
pending; learner recovery memory-only/single pending mutation/AI off unchanged.


## Original input preflight before borrowed read — 2026-10-29 UTC

CapturedConversationReceiptLookup now validates the direct lookupStart/lookupTurn/
lookupFinish reference against the supplied original DTO before invoking the
borrowed original-read port. Reuse ConversationReceiptCommandMatch with an empty
projection solely to check method operation and event UUID association, matching
the concrete SDK transport's existing preflight. Invalid input fails with fixed
validationFailure even when a permissive port would return UNKNOWN for that
reference. No legacy fallback or automatic retry is attempted. Existing lifecycle
and owner checks run first; rejected input does not revoke a healthy reader.

This does not prove a stored original command matches. The real original-read
transport must still validate full request_json, scope, response, authenticated
session and RLS; UNKNOWN remains ambiguous. No empty preflight projection is
published or used as release/application/replay authority. Valid input forwards
the identical reference and original DTO, preserving case-insensitive UUID
association and exact original request spelling for subsequent stored-row checks.

Nine TEST ONLY borrowed-port regressions cover all three direct methods with
wrong operation/event, zero original/legacy reads, a healthy later explicit read,
and equivalent event UUID case with identical DTO forwarding. Removing only the
new block reproduces the entire original fixture byte-for-byte. Parent e7f6bec
CI40831580950/latestattempt1 all5/EVERYstep SUCCESS; prior13 snapshot regressions
and native Windows persistent SDK/receipt markers observed. That evidence is
component-only, not hosted learner proof. Local46QA/inventory152/diffcheck pass
separately; no local Dart/Flutter SDK, so new9/format/analyze/build UNRUN until
new exact-head Actions. All14 hosted release gates, retention approval and
trusted-root/backend/captured storage/uncertainty/conditional application-release
remain open. No default/collection/Authstrategy/provider/API/RLS/Pro change.

## Native owned protected turn/finish lookup — 2026-10-29 UTC

The mandatory receipt-owned-reopen Windows phase now extends the existing start
journey with turn and finish envelopes already constructed in that same phase.
Each crosses the actual production runtime's cached protector/native DPAPI and
lookupProtectedConversationReceipt on its SAME private SDK/profile/generation.
The synthetic original turn retains its leading space/Japanese/newline; neither
command is persisted as a payload. Existing native token/receipt targets remain.

Six additional GETs (turn/finish x UNKNOWN/PENDING/COMPLETED) have a separate
checked HTTP path/counter. Each requires the fixed project/path/six-column original
projection, exact owner/operation/event filters, limit2, empty body, captured
bearer/key, no redirects/no-store and actual pending native reference before
reply. TEST ONLY original request_json and typed responses exercise production
full-command association. Require matching snapshot reference/status/exclusive
typed response, actual turn text/finish summary, no SRS recommendations, unchanged
rotated token/pending metadata/current capabilities. After every status repeat
original-event conflict/different-event pending denial with zero mutation HTTP.

All original start/corruption/mismatch/foreign/stale counters and assertions stay
byte-identical. Independent final counters require six new reads plus unchanged
4 protected/5 original/3 metadata reads/one refresh/zero mutations. After the
original awaited close, both new ciphertext lookups must reject unauthorized
without another read. Original process phases/60s deadlines/finally/synthetic
cleanup and normal learner rebuild are retained. Added success marker appears
only after the complete reopen phase succeeds:
`Windows OWNED protected receipt turn/finish/status/binding/stale/preserve/no-redispatch passed (TEST ONLY Auth/HTTP, no payload persistence)`.

Parent2cfa2ac CI40835008092/latestattempt1 all5/EVERYstep SUCCESS/no skips;
Windows123317681567 required persistent SDK/receipt marker observed. New Windows
cases/Dart format/analyze/build locally UNRUN (no SDK/native Windows). QA46/
inventory152/whitespace and separate original-preservation/counter/request/binding/
no-redispatch/close/cleanup review recorded in PR41. New exact-head CI/marker
required. Auth/JWT/profile/receipt HTTP are TEST ONLY; no hosted Auth/RLS/provider/
learner proof, actual durable payload storage, retention or release authority.
All14 hosted groups/trustedroot/backend/captured storage lifecycle/uncertainty/
authenticated conditional application-release/retentionapproval remain open.


## Native turn/finish formatter repair — 2026-10-29 UTC

CI40839001594 exact05310a8/latestattempt1 failed only the Flutter formatter:
Flutter123331211573 logged one continuation-line indentation change in
windows_sdk_receipt_fixture.dart. Analyzer/tests/downstream Flutter gates were
SKIPPED. All other four jobs and every returned step succeeded. Windows123330631528
actually printed the new turn/finish/status/binding/stale/preserve/no-redispatch
marker and retained persistent SDK/profile/receipt markers. This is TEST ONLY
native composition evidence, not hosted learner acceptance.

Apply exactly that logged whitespace diff; resulting blob begins e2883d3 as in
CI. Reversing it reproduces the entire original fixture byte-for-byte. Inputs,
assertions, control flow, deadlines, PowerShell phases, cleanup and production
code remain unchanged. No redundant test is added for indentation. Local QA46,
inventory152 and diffcheck are separate checks. No local Dart/Flutter/native
Windows SDK: new-head formatter/analyzer/full tests/builds remain UNRUN and must
be checked in exact-head/latest-attempt Actions. All14 hosted release gates and
trusted root/backend/storage lifecycle/uncertainty/conditional release/retention
approval remain open; default AI off and learner recovery memory-only unchanged.

## Native turn/finish original mismatch and legacy denial — 2026-10-29 UTC

Five additional mandatory owned-reopen cases use the SAME production runtime,
private SDK/profile and native DPAPI turn/finish ciphertexts as the positive
status journey. For both commands the TEST ONLY receipt HTTP response retains a
valid typed COMPLETED output but changes the original session_id or omits
request_json; turn additionally changes original text by one trailing space.
These are stored-row response faults, not a malformed caller DTO or fake lookup
success. Existing exact fixed GET/query/bearer/no-store/redirect/native pending
checks run before every response. Separate failure counter increments only after
those assertions pass, so failed setup cannot masquerade as a matching rejection.

Every case must return fixed internalError, increment exactly one mismatch read,
retain current reader/protector, rotated token and original pending native
reference. After each failure, explicit original-event conflict and different-
event pending denials must still prevent mutation HTTP. Counter5 is independent
of the original six successful turn/finish reads and all old4/5/3 read counters;
all remain exact, including after awaited close/stale lookups. Flags reset before
the next positive command. Every original assertion/phase/deadline/finally/cleanup
is retained; only the fixture response shaping/counter selection is extended.
New marker after the entire reopened process succeeds:
`Windows OWNED protected receipt turn/finish original-mismatch/legacy/rejection/preserve/no-redispatch passed (TEST ONLY Auth/HTTP, no payload persistence)`.

Parent2bc3053 CI40847539101/latestattempt1 all5/EVERYstep SUCCESS/no skips;
Windows123358699621 persistent SDK/receipt +positive turn/finish markers observed.
New native cases/Dart format/analyze/build locally UNRUN (no SDK/native Windows).
QA51/inventory153/whitespace and separate faulty-row/counter/old-assertion/pending/
cleanup review recorded in PR41. Require exact-head CI/new marker before pass.
Auth/JWT/profile/HTTP remain TEST ONLY; native components do not prove hosted
learner/Auth/RLS/provider, durable payload storage or conditional release. Default
AI off/memory-only/singlepending/all14 hosted groups unchanged; trustedroot/backend/
captured storage lifecycle/uncertainty/application-release/retentionapproval open.
No production source/Authstrategy/API/RLS/content/Pro/retention-policy change.
