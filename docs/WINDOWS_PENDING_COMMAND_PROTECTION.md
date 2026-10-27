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
