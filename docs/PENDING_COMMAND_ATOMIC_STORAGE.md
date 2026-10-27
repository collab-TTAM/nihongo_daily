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
