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
