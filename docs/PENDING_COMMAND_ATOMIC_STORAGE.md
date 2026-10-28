# Pending command atomic storage — proposed boundary, 2026-10-27

Status: implementation handoff, NOT an implemented backend or retention approval.
Issue17/PR41; current learner recovery stays memory-only. No caller/default is
changed. WINDOWS_PENDING_COMMAND_PROTECTION.md documents the existing codec,
DPAPI byte component, captured capability and actual Windows composition probes.

## Decision and scope

Use one immutable, scope-bound encrypted command record as the future authoritative
local reservation, rather than separately committing plaintext metadata and a
payload file. PendingConversationCommandEnvelope already contains the exact
reference AND original request. Encrypt the whole canonical envelope with the
captured WindowsPendingCommandProtector; a separate reference is an index/hint,
never sufficient proof that the command is durably reserved. No token/password,
response/audio or extra learner fields belong in this record.

This design authorizes development with synthetic fixtures only. Wiring actual
learner text retention is broader collection and remains behind AUTOMATION.md
approval, with explicit learner disclosure and approved lifetime/deletion policy.
No new Auth strategy/provider/spend or remote deletion is part of this design.

## Backend acceptance contract

- Trusted host selects one fixed project/account partition, not a learner path,
  endpoint, key, filename or owner field. Logical scope is validated independently
  before I/O and after decryption; exact event/request spelling is preserved.
- One cross-process writer lease per canonical partition is mandatory. The current
  isolate-local receipt store owner is insufficient. A second process fails closed;
  it must not replace, evict, migrate or clear the first process's reservation.
- Commit one encrypted record containing the complete envelope. Backend must bound
  both reads before allocation and writes: plaintext <=32768, ciphertext <=65536
  bytes. The concrete file framing/OS implementation is separately reviewed.
- The commit protocol must preserve either the old complete record or the new
  complete record across every injected crash boundary. It must confirm durable
  success before dispatch; rename success alone is not accepted as power-loss proof.
  Never expose plaintext in a temporary file, journal, log, exception or fallback.
- Actual Windows directory ACL, reparse/symlink handling, handle ownership,
  flush/replace/crash guarantees and exclusive-open behavior need implementation
  and process-level tests before a filesystem adapter can satisfy this contract.
- DPAPI/context/checksum validates neither the original writer nor freshness.
  Same-OS-user code can create accepted frames. Claims about trusted writers,
  rollback detection or stronger process isolation require a separately reviewed
  threat model and enforcement; a hash or UUID alone cannot provide those claims.

## State and migration rules

| Observed state | Allowed behavior |
| --- | --- |
| Confirmed empty, no legacy reference | Explicit captured-current command may attempt reserve |
| Same exact envelope already reserved | Preserve it; no automatic mutation/replay |
| Different envelope or event | Conflict; preserve original; no overwrite/eviction |
| Legacy metadata only | Pending unresolved; never infer absence of dispatch or recreate payload |
| Payload/reference mismatch, malformed/truncated/oversized data | Fixed safe failure; preserve evidence; block mutation |
| Read/write/flush result uncertain | Fence dispatch and future reservations; explicit reconciliation only |
| Valid local envelope restored | Data only; captured hosted receipt check and conditional application still required |

Legacy metadata remains readable by the existing code. No automatic migration,
metadata deletion, synthesized command, event-ID replacement or fallback is
introduced. Adoption of the new authoritative record requires its own reviewed
integration diff; two unrelated writes cannot be described as atomic.

## Lifecycle and release

Reserve must claim serialization before callbacks; protect/commit each use the
same captured generation. Revocation after protect but before commit prevents a
new write. A commit already accepted by the OS may finish after revocation; the
host must drain actual I/O, suppress its result and reconcile the uncertain record,
never release the slot because a caller timeout/abort completed.

Close preserves pending data and joins actual accepted work before releasing the
writer lease. Logout revokes publication/acquisition synchronously, attempts Auth
cleanup, drains old writes, then clears only the exact authorized local partition
under its lease. Failed clear stays explicit and terminal until explicit retry;
new-account publication must not race a late old write or clear. No cleanup path
may clear server receipts or grant a new mutation. Crash during cleanup remains
unresolved on restart rather than silently treated as empty.

Pending deletion needs authenticated exact original receipt correlation AND a
reviewed conditional result-application/release protocol. UNKNOWN does not prove
no dispatch. COMPLETED alone does not prove local application committed. No TTL,
capacity eviction, auto retry, new event or forced discard is authorized here.

## Next executable increment and evidence

Implement the bounded encrypted-record OS backend as an isolated synthetic-only
component after reviewing concrete Windows ownership/ACL/atomicity choices. Test
actual process lock contention, crash before/after each commit/flush boundary,
partial/torn/truncated/oversized/corrupt records, unchanged-old-record on failure,
wrong scope, ambiguous write, late completion, close-preserve and logout-clear
failure/retry. Repeat with the same owned SDK/profile and native vault; no mock
file/OS port may be reported as native proof. Existing metadata and refresh slots
must remain exact and cleanups must be account-isolated.

Activation additionally requires approved retention/collection, exact-head CI,
separate security/diff review, hosted Auth/receipt correlation and actual learner
restart/recovery evidence. All14 Personal Alpha release gates remain pending.

## Isolated exclusive sentinel primitive — 2026-10-27

`windows/runner/pending_command_file_lease.{h,cpp}` is a first OS prerequisite,
NOT the encrypted record backend. Acquire accepts a bounded absolute drive-local
host-selected existing directory and fixed `pending-command.lock` basename. It
rejects relative/UNC/device/ADS/dot/empty/trailing-dot-or-space path forms. The
opened directory is held without delete sharing and checked as disk/directory,
not a reparse point. The sentinel is opened READ|WRITE with share mode zero,
OPEN_ALWAYS (never truncate), OPEN_REPARSE_POINT and non-inheritable handles.
Handle metadata must identify a non-directory, non-reparse, single-link empty
file. Unsupported OS and every failure return null without path/OS diagnostics.
RAII closes file before directory; the empty sentinel remains after release or
crash to avoid deleting/replacing a live lock identity. No payload bytes are read,
written, protected, restored or dispatched. No runtime/channel/default uses it.

This primitive deliberately does not validate/create directory ACLs, bind the
path to Auth/project/account, walk/protect all ancestor directories or authenticate
a writer. A trusted host must establish that boundary BEFORE using it; an ancestor
junction or attacker-controlled parent is NOT made safe by checking final handles.
The default inherited sentinel security descriptor is not a reviewed data ACL.
No atomic record replace/flush/power-loss/freshness/rollback/retention guarantee
follows. Same-OS-user code can participate; file sharing is cooperating-writer
exclusion, not sandboxing. The component is compiled only into the TEST ONLY
native executable in this increment, never activated in the learner app.

The existing mandatory Windows credential probe retains all original checks and
now additionally tests same-process and actual child contention, inability to
delete sentinel/rename its containing directory while leased, abrupt ExitProcess
without C++ destruction followed by reacquisition, hard-link/nonempty/directory
sentinel rejection, preservation of unknown file content, stable reacquisition
and cleanup in a unique synthetic temporary directory. It emits a required extra
success marker only after the complete new matrix succeeds. Reparse/ancestor/ACL
and power-loss cases are explicitly not covered; they remain backend prerequisites.
Linux C++17 warnings-as-errors compile/fail-closed checks pass; actual Windows
process semantics require new exact-head CI and marker, not a Linux claim.

Implementation references reviewed 2026-10-27:
- https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilew
- https://learn.microsoft.com/en-us/windows/win32/api/fileapi/ns-fileapi-by_handle_file_information

## Ancestor handle walk and junction probe — 2026-10-27

The isolated lease now opens every absolute directory prefix from the drive root
through the supplied leaf with OPEN_REPARSE_POINT and no delete sharing. Each
opened handle must be an ordinary disk directory; all handles remain owned until
the sentinel closes, then release in reverse order. A reserved null ownership
slot precedes CreateFile so vector allocation cannot leak a new OS handle. Failure
at any prefix closes earlier handles through the same RAII owner. No new payload
read/write or directory/ACL modification is introduced by Acquire.

The TEST ONLY native matrix constructs an actual mount-point junction with a
direct FSCTL_SET_REPARSE_POINT buffer (no shell/privilege adjustment/fallback/skip).
Both a final junction and a junction ancestor to an ordinary leaf must fail
before creating a sentinel at the target. Direct ordinary path is a positive
control. Its non-leaf parent cannot be renamed while leased; after release it
can be renamed and restored. Failed walks must allow junction rename/cleanup;
all synthetic directories and sentinel cleanup must succeed. Existing process/
abrupt-exit/hardlink/nonempty tests and markers remain mandatory. The extra
ancestor marker appears only after the entire extended matrix succeeds.

This rejects observed reparse prefixes and pins opened directory names; it does
not establish ACL trust, validate the expected directory identity before opening,
block a same-user actor with other privileges/handles, or prove hostile concurrent
reparse mutation impossible. In particular, no ACL/secure backend/Auth/atomic
commit/flush/power-loss/rollback/retention guarantee follows. Caller still must
establish a trusted namespace and access policy; learner activation remains off.
New Win32/junction/process cases are locally unrun and require exact-head CI;
Linux compile/fail-closed and Python QA do not execute those cases.

Additional primary references reviewed 2026-10-27:
- https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntifs/ns-ntifs-_reparse_data_buffer
- https://learn.microsoft.com/en-us/windows/win32/api/winioctl/ni-winioctl-fsctl_set_reparse_point

## Read-only strict leaf-directory access policy — 2026-10-27

The isolated lease exposes HasPrivateDirectoryAccessPolicy on its already-held
leaf directory. Acquire additionally requests READ_CONTROL for that leaf; it
still does not call the policy method automatically or grant payload-write
permission. A future backend must explicitly require the reviewed checks before
any payload I/O. No production/default/channel caller is introduced here.

The checker reads owner/DACL through GetSecurityInfo on the held handle, captures
the process TokenUser SID, and requires owner equality, a present non-null valid
protected DACL and exactly the explicit inheritable full-control allow ACEs for
that user and LocalSystem (one ACE if the process user itself is LocalSystem).
Other trustees, duplicate/object/deny/inherited ACEs, unexpected inheritance flags,
weaker/different masks or any token/descriptor/ACL query failure return false.
It never repairs ACLs, adjusts privileges, logs a SID/path or falls back to broad
permissions. Token handles and returned descriptors are owned with RAII.

This is a deliberately narrow proposed local policy, NOT a general Windows
AccessCheck/effective-access evaluator or Supabase identity check. It does not
validate ancestor or sentinel/payload ACLs, prevent later owner/ACL modification,
recognize an expected application directory identity, isolate code running as the
same OS user, protect against administrators/SYSTEM, or provide atomic/durable
record guarantees. Existing Acquire without an explicit positive policy check
must not be described as secure private data storage. Learner retention stays off.

The mandatory native probe creates only unique synthetic child directories with
explicit TEST ONLY descriptors. It requires the narrow positive descriptor to
pass, and Everyone-read, unprotected-DACL and extra-Administrators-read variants
to fail. Repeated checks and release/reacquire must preserve those decisions;
all synthetic sentinel/directory cleanup succeeds. Existing lease/process/junction
cases and markers stay mandatory. An additional policy marker is emitted only
after the complete extended probe succeeds. No real user directory ACL is edited.
Native Windows checks are locally unrun; require exact-head CI. Linux compile/
fail-closed and Python QA are separate evidence, not Windows access-policy proof.

Primary references reviewed 2026-10-27:
- https://learn.microsoft.com/en-us/windows/win32/api/aclapi/nf-aclapi-getsecurityinfo
- https://learn.microsoft.com/en-us/windows/win32/api/securitybaseapi/nf-securitybaseapi-getsecuritydescriptorcontrol
- https://learn.microsoft.com/en-us/windows/win32/api/securitybaseapi/nf-securitybaseapi-getace


## Held sentinel access-policy snapshot — 2026-10-27

HasPrivateSentinelAccessPolicy reads owner/DACL from the already-held empty
sentinel handle. It shares the existing bounded token/descriptor/ACE checker,
with expected ACE flags zero for explicit non-inheritable user/LocalSystem
full-control entries. The leaf-directory method retains its exact OI/CI policy.
Require owner equal process user, protected present non-null valid DACL, exactly
user/System trustees (one if identical), exact masks/flags and no extra ACEs.
All failures return false, no ACL repair, privileges, path/SID/raw errors or
payload I/O. Acquire still does not automatically grant a private-storage claim.

Mandatory native matrix precreates only synthetic empty sentinels with private
or extra Everyone-read policies; checks positive/rejection twice, after release/
reacquire, and preserved zero length. Cleanup is required. Existing probe bytes
are unchanged except the new matrix/call. New marker follows successful matrix:
`PASS: Windows command held sentinel private ACL/rejection/reacquire (TEST ONLY)`.

This snapshot neither proves later ACL immutability nor validates payload files,
trusted writer identity, rollback or atomic commit. Existing same-OS-user limits
and explicit learner retention approval remain. Native Windows cases locally
UNRUN; Linux C++17 warnings-as-errors/fail-closed probe and QA46 are not Windows
proof. New exact-head CI all5/EVERY step is required. Microsoft GetSecurityInfo
reference above confirms handle/READ_CONTROL/LocalFree contract and warns about
concurrent descriptor mutation. Next payload/ACL-mutation and namespace checks,
then bounded encrypted-record commit/flush/crash proof before activation.

## Held ACL mutation regression — 2026-10-27

The mandatory native probe adds a synthetic directory/sentinel whose security-
control handles are opened before acquiring the unchanged exclusive data lease.
Through those same handles it changes only the synthetic protected DACL: private
user/SYSTEM to an extra Everyone-read ACE and back. The same held lease must read
current leaf/sentinel policy each time, reject the broadened descriptor repeatedly,
and observe the restored snapshot. Protected sentinel and leaf decisions remain
independent. Sentinel bytes stay empty; a second lease stays excluded; every
control/lease handle and synthetic file/directory must clean up. A success marker
is emitted only after all assertions. New actual Windows execution requires CI.

This deliberately tests an authorized same-user mutator, not a sandbox or a
malicious race guarantee. ACL snapshots do not freeze permissions between check
and use. Restoring a snapshot is NOT permission for a future backend to resume
previously fenced work. That owner must retain a terminal/uncertain state after
observed policy failure and define an independently reviewed reconciliation
protocol. No production ACL changes, repair, payload I/O or new default caller.

API references checked 2026-10-27:
- https://learn.microsoft.com/en-us/windows/win32/api/aclapi/nf-aclapi-setsecurityinfo
- https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilew

## Sticky per-lease policy fence — 2026-10-27

CheckPrivateAccessPolicy is an explicit serialized-owner operation over the held
leaf and sentinel snapshots. Any false result permanently latches failure in that
lease; later ACL restoration and raw positive snapshots cannot clear it. There is
no reset method, ACL repair, payload IO or runtime caller. Existing raw policy
methods remain diagnostic snapshots and do not update the latch themselves. A
future owner must consistently use the combined check, serialize calls/lifetime,
and fence its own operation state. Acquire alone is never payload permission.

Native synthetic mutation tests now exercise initially positive repeated checks,
leaf-triggered failure and a separate lease for sentinel-triggered failure, then
require repeated denial after each ACL restoration while raw snapshots are true.
Existing checks and cleanup remain. Marker after complete matrix:
`PASS: Windows command lease sticky policy failure fence (TEST ONLY)`.

The latch lasts only for the current object; reacquisition/restart is not reviewed
reconciliation. It cannot detect changes between snapshots or prevent check/use
races, and does not establish namespace/payload/writer/rollback/durability trust.
No learner retention or default activation; approved retention, persistent
uncertainty/reconciliation, namespace validation and atomic encrypted-record
commit/flush/crash testing remain required.

## Bounded opaque ciphertext candidate read — 2026-10-27

ReadCiphertextCandidate is an isolated read-only prerequisite, compiled only in
the TEST ONLY native probe. No app/channel/default invokes it. Serialized owner
first passes the sticky leaf/sentinel policy check. The fixed pending-command.bin
basename under the captured directory is opened existing/read-only/exclusive with
OPEN_REPARSE_POINT and READ_CONTROL. Disk, non-directory/non-reparse, one link,
size 1..65536 and strict protected owner/user+SYSTEM zero-ACE-flags policy are
required BEFORE buffer allocation. Exact synchronous read length, repeated size/
link/ACL and final combined policy checks precede publication. RAII closes all
handles; no partial bytes or OS/path diagnostics escape. Any uncertainty latches
the existing per-lease fence; later fixture repair cannot reset it.

Result present means opaque CANDIDATE ONLY: arbitrary bytes still need bounded
DPAPI/frame/canonical envelope/scope/hosted receipt validation. Error-file-not-found
with positive post-policy returns absent/empty; every other error returns
unavailable/empty. Absent is NOT no-dispatch, new-event, legacy-reference clearing
or restart reconciliation authority. No file creation/truncation/write/deletion/
decryption/automatic retry/collection/default activation is added by the reader.
This does not establish trusted namespace identity, immutable ACL, writer/rollback
trust, persistent uncertainty, atomic commit/flush or hardware power-loss safety.
An owner must retain unresolved state beyond lease lifetime; reacquiring is not
authorization. Actual learner retention remains behind human approval.

Mandatory native synthetic cases: absent/repeated absent, exact minimum and maximum
bytes/repeated reads, zero/oversized/broad ACL/hardlink/directory/junction rejection,
no returned partial bytes, unchanged fixture length, no target payload access,
sticky rejection even after fixture replacement, mandatory cleanup. New marker
requires all nine cases; actual Windows execution remains exact-head CI evidence.
Short-read/fault injection, sharing failure and concurrent mutation remain further
regressions, not claimed here. Official references checked 2026-10-27:
- https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-readfile
- https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getfileinformationbyhandle

## Actual sharing failure regression — 2026-10-27

The mandatory native candidate matrix adds a same-process, second-handle sharing
conflict using real CreateFileW semantics, not an injected error. First a private
one-byte candidate reads successfully through the same lease. A separate borrowed
read handle stays open; an independent exclusive-open control must fail with
ERROR_SHARING_VIOLATION before the reader is called. Raw directory/sentinel ACL
snapshots remain positive, isolating sharing from the permission-negative cases.
The reader must return unavailable/empty (never absent or prior successful bytes)
and latch failure. Closing the blocker must not revive the old lease. A TEST ONLY
fresh lease then reads the exact original bytes, proving the fixture is unchanged
and every transient reader handle closed; cleanup must succeed. No retry/renewal
or new-lease reconciliation authority is supplied to application code.

This is real OS sharing behavior within one process; it is not a cross-process
reader/crash proof or a ReadFile short-read/fault injection. Existing nine native
cases and all production methods remain unchanged. New marker is required in
exact-head Windows CI; local Linux compilation does not execute Win32 branches.
No learner/default/backend activation or retention approval. Reference checked
2026-10-27: https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilew

## Create-new private staging prerequisite — 2026-10-28

StageCiphertextCandidate is an isolated synthetic-only component, compiled into
the mandatory native probe only; no app/channel/default calls it. It accepts
1..65536 opaque ciphertext bytes (caller must supply actual protector output),
requires the combined sticky policy and prior absence of pending-command.bin,
and takes a bounded copy before creating a file. It creates only the fixed
pending-command.stage with CREATE_NEW, share zero, non-inheritable handle and an
explicit process-user owner/protected DACL. Exactly user/LocalSystem fullcontrol
allow ACEs with zero inheritance flags are built from SIDs; duplicate SYSTEM
entry is omitted when identical. No privilege adjustment or inherited fallback.

Before data I/O, the held empty stage must pass ordinary-file/single-link and
strict private policy. Exact WriteFile count, successful FlushFileBuffers, final
ordinary/single-link/exact size/private ACL and combined checks plus successful
close are required for true. Any failure (including input, existing candidate or
existing stage) latches failure. Never truncate, overwrite, delete, rename, repair
or auto retry. A possibly partial stage stays as uncertainty and blocks future
CREATE_NEW attempts even on another lease. Explicit retention reconciliation is
not implemented. Existing original candidate/receipt/refresh slots are untouched.

True means flushed STAGING ONLY: not atomic publication, durable reservation,
dispatch/replay permission or hardware-power-loss proof. Reader still reads only
.bin, so absent can coexist with a .stage and remains NO mutation authority. No
automatic stage adoption or cleanup; future reviewed owner must inspect both
slots, retain persistent uncertainty, validate DPAPI/envelope/scope/receipts, and
prove atomic publication/flush/crash behavior. Same-user/namespace/ACL-race/writer/
rollback limits remain. Actual learner retention still needs human approval.

Native synthetic tests require zero/oversize rejection before file creation,
minimum/maximum exact bytes and independently queried owner/protected/exact ACL
ACE contents, no .bin publication, duplicate-stage failure/preservation, stage
preservation across release/reacquisition, and existing-candidate rejection.
All original reader/probe assertions remain; test-only cleanup removes stages.
New Windows execution requires exact-head CI; short-write/flush/close failure
injection/process crashes/power loss are not yet demonstrated. Primary APIs
reviewed 2026-10-28:
- https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-flushfilebuffers
- https://learn.microsoft.com/en-us/windows/win32/api/aclapi/nf-aclapi-setentriesinaclw
- https://learn.microsoft.com/en-us/windows/win32/api/securitybaseapi/nf-securitybaseapi-setsecuritydescriptorcontrol

## Subprocess stage preservation — 2026-10-28

A TEST ONLY child mode now exits via ExitProcess without C++ lease destruction
after actual StageCiphertextCandidate succeeds with a 65536-byte synthetic input.
A separate explicit partial-fixture mode creates a private stage, writes three
synthetic bytes, and exits with its file/lease still held and no explicit flush.
The partial producer is NOT fault injection inside production Stage; neither
mode represents a Windows/kernel/hardware power failure. No production method
or default entrypoint changes. Child flags exist only in the native probe.

Parent uses CreateProcess without a shell/inherited handles, a 10-second wait/
fixed expected exit code and bounded termination cleanup. It must reacquire the
lease, independently read exact stage bytes/owner/protected/exact ACL, observe
no .bin publication, and refuse a new stage without altering old bytes. Rejected
lease stays fenced. Only unique synthetic fixture cleanup deletes those files.
Both partial and complete abandoned stages remain unresolved; never adopt,
rename, overwrite, discard or infer no-dispatch from them automatically. New
marker appears only after both child cases complete. Actual execution requires
new exact-head Windows CI; Linux compile is not subprocess/Win32 evidence.

Remaining: short-write/flush/close fault injection inside actual staging and
crash boundaries during actual atomic publication, namespace/durable uncertainty/
reconciliation and approved retention. API reference checked 2026-10-28:
https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-exitprocess

## Stage directory/junction collision regression — 2026-10-28

The mandatory native candidate probe adds actual directory and mount-point
junction collisions at pending-command.stage. Both contain an independent
synthetic marker (junction target referenced directly, never through the alias).
The unchanged staging method must fail and latch denial, preserve the existing
object type/reparse bit and exact marker bytes/length, and create neither a .bin
in the lease partition nor a .stage/.bin inside the collision target. Unlinking
the collision fixture cannot revive that lease or create a replacement stage.
The target marker survives junction unlink; only explicit unique synthetic
cleanup deletes it. Failure cleanup avoids traversing the stage junction.

This completes the stale core-stage-namespace checkpoint's stated scope. It is
TEST ONLY evidence after actual Windows execution, not hostile concurrent
namespace/ACL mutation protection, trusted application partition identity or
atomic publication/durable reservation/retention authority. Production reader/
staging/lease/defaults remain unchanged. Prior assertions remain mandatory.
Short-write/flush/close injection and atomic commit/crash/reconciliation still
need separate implementation/tests before learner retention approval. References
checked 2026-10-28:
- https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilew
- https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-removedirectoryw

## TEST ONLY staging syscall faults — 2026-10-28

The native probe now compiles the unchanged pending_command_file_lease.cpp a
second time under a distinct test class name. Only that translation unit maps
WriteFile/FlushFileBuffers/CloseHandle to serialized fixture wrappers; the normal
probe and app runner keep the actual class and APIs. No production seam, runtime
flag, caller activation, retention permission or dependency is introduced.

Four required cases use the existing private directory/sentinel fixture and64
synthetic0xa5 bytes: actual half WriteFile with successful short count; injected
WriteFile failure before any write; injected flush failure after real full write;
injected first stage close failure leaving the real handle open for RAII's real
second close. Other operations delegate to actual Win32; counters require exactly
one intended fault/one write, correct flush count and one close (two for close
failure). The same compiled staging method must return false and latch, exposing
no candidate bytes and refusing another attempt without another syscall write.

After all real handles close, the independent normal probe reads exactly32/0/64/
64 bytes plus EOF and the existing exact owner/protected ACL/size/link checks.
A fresh non-injected lease also rejects that uncertain stage and leaves bytes
unchanged. No .bin may appear. Mandatory deletion is limited to the unique
synthetic stage after inspection; no cleanup/retry/reconciliation API is added.
The original read assertion now passes a valid dummy buffer for a zero-byte read;
all original comparisons and other native cases remain. Required fixed marker:
`PASS: Windows ciphertext stage write/short-write/flush/close faults preserve/fence/no-publish (TEST ONLY)`.

These are injected API outcomes around actual OS files and unchanged source, not
observed physical disk failure, hostile races, process crash during flush or
power-loss proof. Flush/close faults cannot establish durable success. Atomic
publication, trusted partition namespace, durable uncertainty/reconciliation and
learner retention approval remain missing. New MSVC/Win32 execution needs exact-
head Actions; Linux only verifies the unsupported-OS branch.

## Same-lease candidate namespace publication — 2026-10-28

PublishStagedCiphertextCandidate is an isolated synthetic-only component method,
not wired to app/learner/runtime channels. A successful Stage now retains a
bounded opaque ciphertext copy in that lease. Publish refuses missing capture,
failed policy or an existing .bin; it never adopts another object's abandoned
.stage. The reopened source has read/write/DELETE access, zero sharing, reparse-
point open semantics and ordinary/single-link/exact-size/private-ACL checks.
Before rename it reads exactly the captured bytes plus EOF, rechecks policy and
flushes. Same-size changed bytes are rejected too; equality is not provenance.

A bounded aligned FILE_RENAME_INFO uses the fixed absolute .bin path, null root
and ReplaceIfExists=false through SetFileInformationByHandle on the still-held
source. The rename itself must refuse an existing target, including a target
created after the preliminary absence check. No replace/copy/delete fallback.
After rename, held metadata/ACL/policy, flush and checked close must succeed.
The capture is then cleared so the same object cannot publish twice. Any failure
latches the lease; uncertain rename/post-rename outcomes never cause rollback,
deletion, automatic retry or new dispatch. A true result is only namespace
candidate publication, NOT durable reservation, authenticated command or proof
of power-loss recovery. Parent-directory durability and durable failure fencing
across restart are unresolved. Stored bytes are still unauthenticated until the
separate scope-bound protection/receipt/reconciliation protocol validates them.

Required native cases:1 and65536-byte stages publish to exact readable .bin,
.stage disappears, duplicate publish fences, fresh normal reader sees exact
bytes. Five negative cases preserve absent/no-stage, abandoned stage on new
lease, preexisting target, truncated stage and same-size changed stage. Exact
stage bytes/ACL/EOF and prior target are retained; no unintended .bin, no retry,
mandatory unique test cleanup. All previous native tests/markers remain required.
Rename-race/failure/post-rename flush/close/crash injections, namespace trust and
reconciliation remain next; the initial target-conflict case is not a race test.
New method/Win32 native behavior requires exact-head CI. Linux only checks the
unsupported-OS build; no local Windows/Flutter claim. No API/schema/RLS/Auth/
Pro/provider/retention/collection/spend/default change.

Primary Microsoft API references checked2026-10-28:
- https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_rename_info
- https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-setfileinformationbyhandle
