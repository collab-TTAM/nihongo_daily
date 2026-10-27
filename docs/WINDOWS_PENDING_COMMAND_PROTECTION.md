# Windows pending-command protection component

Status: explicit native byte component/channel, not a durable conversation backend.
Draft PR #41 / issue #17. No default caller, file, Credential Manager payload write, startup restore,
retention, collection or default AI activation is added. Existing receipt metadata
and refresh-token vault targets/limits remain unchanged.

## Boundary and proposed format

`ProtectPendingCommand` and `UnprotectPendingCommand` take opaque byte vectors and
an existing canonical receipt target (HTTPS project origin + owner UUID). The
receipt target is validated for syntax and used only as public context; this
component never reads or writes that Credential Manager target. Syntax is not
trusted configuration, current Auth, ownership or profile readiness.

Plaintext must be 1..32768 bytes, allowing the separately proposed strict
[command envelope](PENDING_CONVERSATION_COMMAND_FORMAT.md). Ciphertext must be
1..65536 bytes. Invalid target/size gives `invalid_input`; unsupported platform,
OS/hash failure, wrong context or invalid protected frame gives `unavailable`.
Every failure returns an empty byte vector and no raw OS detail. No plaintext
fallback, logging, prompt or learner-selected endpoint/key is introduced.

On Windows, only `CRYPTPROTECT_UI_FORBIDDEN` is passed to user-context DPAPI;
`CRYPTPROTECT_LOCAL_MACHINE` is never requested. Additional entropy is the public
ASCII domain `NihongoDaily.PendingCommandProtection.v1|` plus exact receipt target.
This binds normal protection/decryption to the expected partition; it is not a
secret key, Auth credential or authorization check.

The protected frame contains eight magic/version bytes (`NDPC`, 1, 0, 0, 0),
little-endian uint32 context/payload byte lengths, exact context bytes, opaque
payload bytes and a 32-byte SHA-256 digest of all preceding frame bytes. Windows
CNG computes SHA-256. Decryption bounds OS output before copying, then requires
exact magic, lengths, context, total size and digest before exposing payload.
There is no JSON interpretation or reference/command authority at this layer.

Temporary framed/decrypted buffers, hash bytes and LocalAlloc DPAPI outputs are
zeroed on scope exit, including exception paths; DPAPI outputs are LocalFree'd.
Protection reserves its full frame capacity before inserting plaintext. Inputs
and returned plaintext remain caller-owned; this is not a guarantee that every
allocator/runtime/OS copy is erased. Callers must manage sensitive byte lifetimes.

## Security limits and future integration

DPAPI protects under the Windows user logon context, usually on the same machine
(with documented roaming exceptions). It does not isolate Supabase accounts,
other code running as the same OS user, a compromised process or an authorized
local attacker. Public context is not a hidden key. The internal digest checks
frame/corruption consistency; it is not independent keyed authentication or proof
of the original writer. In particular, successful unprotect does not certify the
flags/provenance of an externally produced DPAPI blob. This component makes no
malicious-writer, rollback, filesystem, crash-atomicity or durable-storage claim.

A future reviewed storage backend still needs trusted writer/ACL and integrity/key
ownership decisions, bounded atomic command+reference write-before-send,
exclusive ownership, read/clear ordering and explicit retention/logout policy.
After unprotect, strictly decode the Dart envelope using locally trusted expected
scope, then require captured current SDK/Auth generation and own-profile readiness.
A decoded original is data only: server-authenticated original receipt validation,
conditional result application and release remain separate requirements. UNKNOWN
never proves no provider dispatch. No automatic replay/new event/slot release.
The present memory-only recovery flow is unchanged. Broader retention/collection
or Auth/provider/security changes remain subject to AUTOMATION.md human gates.

## Executable evidence

`tool/windows_session_vault/command_protection_probe.cpp` is TEST ONLY synthetic
in-memory bytes. Existing required Windows credential-store probe now invokes it
before success. Original refresh/metadata/child-process/cleanup assertions remain.
Both app and probe CMake compile the production component and link crypt32/bcrypt.
No CI step or assertion was removed, skipped or weakened.

Windows cases: invalid/empty/oversized inputs; exact 1/256/32768-byte binary
roundtrips without input mutation; wrong project/owner; corruption at first/middle/
last ciphertext byte and truncation. Separately DPAPI-protected unframed and
correctly framed but wrong-digest values must fail, exercising application checks
even when OS decryption itself succeeds. Failures expose no plaintext. Required
new marker only after all cases succeed:

`PASS: actual Windows user-context command protection bounds/roundtrip/scope/corruption (TEST ONLY, no persistence)`

Local Linux C++17 `-Wall -Wextra -Werror` compile and validation/fail-closed probe
PASS. This does not run DPAPI/MSVC or prove Windows crypto. Actual Windows/full
Flutter/platform build results require exact-head/latest-attempt Actions evidence;
see the first PR41 checkpoint. This is neither hosted Auth/RLS/provider evidence
nor learner restart/recovery acceptance; all14 hosted release groups remain open.

## Primary API references reviewed 2026-10-26 UTC

- [Microsoft CryptProtectData](https://learn.microsoft.com/en-us/windows/win32/api/dpapi/nf-dpapi-cryptprotectdata): user context, entropy, UI flags, LocalFree and Crypt32.
- [Microsoft CryptUnprotectData](https://learn.microsoft.com/en-us/windows/win32/api/dpapi/nf-dpapi-cryptunprotectdata): exact entropy and additional integrity-check guidance; corruption can return success with corrupted output.
- [Microsoft BCryptHash](https://learn.microsoft.com/en-us/windows/win32/api/bcrypt/nf-bcrypt-bcrypthash): unkeyed SHA-256 via null secret, Windows 10 / Server 2016 minimum and Bcrypt.

## Independently produced protected frame matrix — 2026-10-27

The TEST ONLY producer now hashes a synthetic frame independently with CNG and
protects it directly with DPAPI, without calling production ProtectPendingCommand.
A valid binary control must decode to exactly 00 ff 01, proving the helper's
format/entropy/digest are usable. Twelve individually rehashed mutations must
return unavailable and empty bytes: magic, version, reserved byte, zero/uint32-max
context length, actually empty payload, oversized/uint32-max declared payload,
wrong embedded context under correct entropy, extra/truncated payload, and actual
32769-byte decrypted payload. These cases exercise parser checks independently
of a DPAPI or SHA-256 failure. A fixed extra marker follows only after the entire
existing probe (including this matrix) succeeds:

`PASS: validly protected malformed command frames/control (TEST ONLY, no persistence)`

The valid independent control also demonstrates the security limit: other code
running as the same OS user can produce an accepted frame. Neither a valid digest
nor DPAPI success authenticates the original writer. No durable storage, actual
learner input, new collection, default behavior or Auth strategy is activated.
Native Windows cases are authored but locally unrun; latest exact-head CI is the
required execution evidence. Local Linux compile/validation does not execute them.

## Explicit Dart/native byte operations — 2026-10-27

Existing `nihongo_daily/conversation_receipts_v1` now accepts `protectCommand` and
`unprotectCommand`. Each requires exactly `target` (canonical receipt-scope string)
and `bytes` (StandardMethodCodec uint8 list / Dart Uint8List). Plain int lists,
other typed arrays, null/wrong types/missing/extra keys are rejected. The existing
component enforces 32KiB plaintext/64KiB ciphertext bounds after channel decoding.
On success the channel returns Uint8List; every input/OS/parse failure returns
the existing fixed receipt_storage_unavailable error, fixed message and no details.
No plaintext fallback, raw OS error or payload is returned on failure. Unknown
methods still NotImplemented; read/write/clear metadata behavior is unchanged.

These operations neither read/write/clear Credential Manager nor dispatch HTTP.
Their target is public context, not Auth or proof of a trusted configured endpoint.
The optional captured Dart facade below remains unwired to any runtime factory,
filesystem backend or startup restore. Future caller must enforce trusted project/owner, captured SDK
generation/readiness, strict envelope decode and result suppression after logout.
Native/Dart/codec plaintext copies have caller-controlled lifetimes; no guarantee
of erasing all copies. The same-OS-user/writer/rollback limits above still apply.

Mandatory existing Windows receipt-write phase now exercises actual MethodChannel
roundtrip of synthetic binary 1/256/32768-byte values, unchanged input, strict map/
type/namespace/empty/oversize rejection, wrong owner/project decrypt, corrupt and
truncated ciphertext with fixed errors. Reads then verify all three preexisting
metadata partitions are exact, and the original outer fixture verifies the refresh
marker and later reopen/clear/absence/cleanup unchanged. PowerShell emits the new
command-protection Dart/native marker only after all four required phases succeed.
No real learner payload, file write, broader collection or retention is activated.
New platform cases locally unrun; exact-head/latest-attempt CI and actual marker
required before claiming execution. This is not hosted Auth/RLS or learner proof.

## Optional captured-session Dart facade — 2026-10-27

WindowsPendingCommandProtector accepts host-owned ReviewAuth, canonical trusted
ConversationReceiptScope and readiness callback. Construction requires the current
ReviewSession identity, matching owner and readiness. This is an identity/lifecycle
hint, not verified Auth; future assembly must pass the SAME owned SDK Auth/profile
barrier. No factory/global current client or learner endpoint/key is selected here.

protect accepts only the immutable typed command envelope in its fixed scope and
sends strict UTF8 bytes via protectCommand. unprotect accepts nonempty <=64KiB
ciphertext, validates native Uint8List output <=32KiB, strictly decodes UTF8 and the
canonical envelope in the fixed expected scope. Native protect output must be a
nonempty <=64KiB Uint8List. Input/output byte copies prevent mutable aliasing; they
do not prove crypto provenance or erase all plaintext copies. Safe fixed failures
contain only unauthorized/invalidInput/unavailable/busy, never private exceptions.

Every operation claims busy before readiness/callback/encoding and releases only
when the actual future drains. Caller timeout cannot open another native operation.
Captured identity/readiness and sticky revoke are checked before work, after the
channel future (before plaintext decode) and before result publication, including
error paths. Same-owner replacement/A-B-A cannot revive a capability. Readiness
exceptions/loss permanently revoke; synchronous callback revoke is checked again.
Revoke is immediate but does not cancel OS work, erase acquired caller data or
release any pending conversation metadata. No automatic retry/lookup/application.

Twelve TEST ONLY mock-channel cases cover all3 typed requests, strict bytes/scope,
foreign commands/input bounds/no dispatch, unsupported/missing platform, private
errors/bad output types, oversized/nonUTF8/noncanonical/foreign decoded data,
constructor/session/readiness guards, sticky revoke, late A-B-A success+error,
actual-I/O busy beyond external timeout/input snapshots, readiness reentry and
synchronous readiness revoke. New Flutter tests/analyzer locally unrun; formatter
and QA evidence are separate from exact-head CI. Mocked Auth/bytes are not native
DPAPI/SDK/hosted learner proof. Existing real native bridge evidence remains a
separate prerequisite. No default/runtime wiring, backend/disk/retention/collection
activation, Auth strategy/provider or policy change; human gates remain unchanged.


## Availability reentry fence — 2026-10-27

The captured facade reserves a separate availability-check flag before invoking
caller-supplied readiness/Auth getters. Nested isCurrent reads return false without
recursing or revoking a valid outer owner. protect/unprotect called inside a
standalone availability read fail busy before any MethodChannel I/O. Previously
only operations reserved _busy, so a standalone read could launch work through a
reentrant callback. The flag is released in finally; revocation remains sticky,
including synchronous callback revocation and every existing late-result fence.

Three additional mock-channel cases cover recursive reads and both native methods
attempted from a standalone readiness callback. They require zero nested channel
calls and allow a subsequent explicit protection operation. Original12 tests are
unchanged. Parent08b2a2b CI40437029165/latestattempt1 passed all5/EVERY step, all12
facade tests and retained native markers. New15/full Flutter/native checks need
new-head CI; local formatting/QA are not execution evidence for these cases.
No factory, disk storage, retention, default activation or release authority added.


## Explicit revoke and actual-operation drain — 2026-10-27

The optional facade now provides revokeAndDrain for a future caller-owned host.
It revokes synchronously and returns completion only after accepted native work
actually settles, including error paths. Repeated calls during the same operation
share its drain future. A caller timeout does not cancel OS work or release the
busy reservation; a late payload is still rejected by captured lifecycle checks.
The completion slot is installed before readiness/Auth callbacks, so synchronous
callback revocation cannot miss accepted work. Idle calls do not invoke readiness
or the channel. Ordinary revoke stays synchronous and non-waiting.

Drain reports quiescence only, not protection success. The original operation's
caller must still observe its result/error; drain neither swallows it nor clears
receipt metadata or erases caller-owned bytes. No runtime factory wiring, native
cancellation, backend persistence, retention or default behavior is added here.
Six new mock-channel cases exercise both methods with held late success/error,
repeated drains, external timeout/actual busy, idle and readiness-callback drain.
All15 prior tests remain unchanged. New21 tests/full native/build require new-head
CI; parentdf41515 CI40443265071/latestattempt1 all5/EVERY step passed. Hosted
Auth/RLS and learner restore proof remain outstanding. Next integrate this barrier
with the same owned SDK/profile generation before any persistence activation.

## Owned persistent SDK assembly — 2026-10-27

PersistentSupabaseRuntime now offers explicit createWindowsPendingCommandProtector.
It is unavailable off Windows, with conversation disabled, without the validated
owned receipt partition, before stored-token/own-profile readiness, during refresh/
logout/close, after terminal retirement or while an old native operation drains.
One cached protector uses the SAME ready.auth, readySession, readyRuntime and AI
generation as conversation and original receipt lookup. The project partition was
already validated against the owned SDK URL; no learner endpoint/key is accepted.
Acquisition performs no channel/HTTP/storage call. A revoked cached instance is
not silently replaced within the same generation.

Ready-runtime replacement/error/done immediately revokes the old protector and
blocks replacement until actual drain. Refresh installs an acquisition fence before
callbacks, revokes now, runs existing Auth refresh/persistence and native drain
in parallel, and completes only after both settle. Repeated refresh shares the
active future. Auth rotation/profile readiness never publishes an old native result.
Logout terminally retires command acquisition, starts original Auth/receipt cleanup
without waiting for native work and joins its actual drain before completion. Close
likewise retires synchronously, preserves existing credential-close policy and
waits native drain before disposing SDK/network. The byte capability writes no
metadata/payload, so no new storage cleanup or deletion policy is introduced.

Eight new TEST ONLY actual pinned-SDK runtime cases use simulated Auth/profile/
vault/HTTP and mock native channel: absent receipt opt-in; pending profile, saved
refresh token, same-generation cache and explicit bytes; refresh/logout/close each
with ignored late native success/error. They assert immediate old revocation, no
replacement while held, actual completion barrier, refresh future identity/new
lease only afterward, Auth clear during logout and terminal B/A re-login denial.
No AI HTTP is dispatched. Original runtime test bodies remain exact. Local new
Flutter/analyzer/native tests/builds unrun; exact-head CI required. Actual native
DPAPI remains separately evidenced by the existing Windows bridge.

This composes optional components only: no default UI/staging activation, automatic
serialization, disk backend, new collection/retention, Auth strategy/provider change
or hosted learner acceptance. Reviewed atomic command+reference storage, trusted
writer/key/ACL/integrity, logout/retention policy and original receipt conditional
application/release remain outstanding. All14 hosted release groups remain pending.


## Actual Windows owned-runtime composition probe — 2026-10-27

The existing mandatory receipt-owned-reopen process phase now acquires the typed
protector from the SAME PersistentSupabaseRuntime after native refresh-secret
rotation and held own-profile readiness settle. Before startup and during held
profile loading, acquisition must remain null. After readiness, acquisition must
return the same cached instance. No mock MethodChannel or replacement factory is
installed: synthetic typed start/turn/finish envelopes cross the actual Flutter
Windows channel and user-context DPAPI and decode to byte-exact canonical input,
including Japanese text, leading space and newline. Synthetic payload bytes stay
in memory; they are neither written to a file nor restored across processes.

A copied ciphertext with a flipped middle byte must fail with fixed unavailable;
a foreign-owner envelope must fail invalidInput; both leave the valid capability
current and the original ciphertext usable. Every successful roundtrip verifies
the rotated refresh marker and pending receipt unchanged, zero AI mutation/lookup
HTTP. Existing original receipt UNKNOWN/PENDING/COMPLETED/mismatch/legacy tests
still run afterward. After the original awaited runtime.close, both protect and
unprotect using the old instance must fail unauthorized, acquisition stays null,
and original stale-reader/token/receipt/no-redispatch/journal assertions still run.
All older fixture and PowerShell lines are retained in order.

The existing outer process verifier emits this extra marker only after the whole
receipt-owned-reopen process succeeds (including old assertions and final cleanup):

`Windows OWNED SDK/profile command protection all3/corrupt/foreign/stale-close/preserve/no-redispatch passed (TEST ONLY, no payload persistence)`

Parent78f0f07 CI40459656313/latestattempt1 all5/EVERYstep succeeded; observed1438
Flutter/fiveChrome, all8 mocked-native owned lifecycle cases and native bridge/
DPAPI/malformed/oldOWNED markers. New composition assertions are authored and
locally unrun: require new exact-head Windows process marker and all required CI.
Local official Dart3.9.2 formatting and46QA are separate evidence. Synthetic
Auth/profile/HTTP/JWT are not hosted Auth/RLS/provider/learner proof. No production
code/default activation, payload backend, new collection/retention, security/Auth
strategy/provider change or receipt release/replay authority introduced. Reviewed
atomic backend/writer/key/ACL/integrity/logout/retention remain next; all14 hosted
gates stay pending and the draft stays open.


## Native owned logout fence — 2026-10-27

The mandatory receipt-owned-logout phase now captures the production typed lease,
roundtrips a synthetic original through actual Windows DPAPI, checks unchanged
rotated token/pending reference and zero mutation/receipt HTTP, then invokes the
original account.signOut once. Its returned future is captured so immediate old
lease revocation/null factory can be checked BEFORE awaiting completion. After
await, both old protect and unprotect must fail unauthorized, all three HTTP counts
stay zero and the unchanged original signedOut/token-null/receipt-null/logout-count
assertions still execute. All other original fixture/cleanup lines are retained.
The outer verifier emits the new logout marker only after the entire phase exits
successfully. No native cancellation or held-native ordering proof is inferred;
held-success/error quiescence still comes from the separately executed SDK tests.

Parent3ba1734 CI40465655338/latestattempt1 all5/EVERYstep passed,1438Flutter/
fiveChrome and actual OWNED SDK/profile all3/corrupt/foreign/stale-close marker
observed. New logout assertions locally unrun; require new-head CI/actual marker.
Proposed next atomic storage, legacy pending handling, OS ownership/crash tests,
writer/rollback limitations and activation gates are specified in
[PENDING_COMMAND_ATOMIC_STORAGE.md](PENDING_COMMAND_ATOMIC_STORAGE.md).
That document is a design handoff, not an implemented backend, retained learner
payload or permission to broaden collection. Default/memory recovery unchanged.
