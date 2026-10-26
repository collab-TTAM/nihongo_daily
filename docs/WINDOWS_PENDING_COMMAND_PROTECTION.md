# Windows pending-command protection component

Status: unused native component, not a durable conversation backend. Draft PR #41,
issue #17. No Dart channel, file, Credential Manager payload write, startup restore,
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
