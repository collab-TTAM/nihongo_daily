# Windows receipt MethodChannel — Issue #17

Optional createWindowsConversationReceiptStore now has a separate native receiver
registered in the normal Windows runner, on the fixed channel
nihongo_daily/conversation_receipts_v1. Runner CMake compiles the existing receipt
Credential Manager primitive and new receipt_vault_channel.cpp. FlutterWindow
retains both channels independently and removes the receipt handler before engine
destruction. The existing Auth receiver, allowlist and refresh namespace are unchanged.

Receiver accepts only read/clear with the exact target key, or write with exact
target/reference keys. Map cardinality, key names, scalar types, target namespace,
bounded metadata and owner/project matching validate before storage access.
Unknown methods are NotImplemented. Only confirmed OS success returns true;
only actual not_found returns null. Invalid/corrupt/unavailable/exception paths
return fixed receipt_storage_unavailable / Receipt storage unavailable, no details.
No input echo/logging, synthetic success, secret field, plaintext/file fallback,
arbitrary directory or network capability is introduced. The Dart facade retains
canonical scope/reference validation, Windows-only guard and strict acknowledgments.

The channel is a process-local storage capability, NOT an Auth check. Credential
Manager is OS-user scoped; other same-user processes and callers with this channel
are not excluded. The raw write primitive can replace a slot. The caller-owned
store's serialization/no-overwrite and isolate-only ownership rules remain required;
no cross-process CAS/mutex or application lifecycle ownership is claimed.

## Actual bridge probe (authored, execution pending CI)

The existing mandatory Windows bridge build/PowerShell step now runs additive
receipt-write/reopen/clear/absent phases in separate real Flutter processes. The
new windows_receipt_fixture.dart imports the actual facade/store/codec and uses
the real runner/channel/OS (no mock messenger/storage). Unique invocation .invalid
origins and fixed TEST ONLY UUIDs only; no learner input/service/network/credentials.

Write confirms three initially empty account/project slots, exact reserve/read and
idempotent same-reference reserve. Raw codec calls reject null/non-map/wrong-key/
wrong-type/extra arguments, refresh namespace, malformed target, token field,
oversized/noncanonical/foreign metadata; all original slots remain exact. Unknown
method is unavailable. Fresh-process reopen reads all exact original metadata,
rejects a different pending event without overwrite, and preserves on close.
Clear A twice leaves B/other-project intact, then clears them; a fourth process
confirms absence. Synthetic refresh marker remains intact throughout. Finally
cleanup attempts all three receipt slots plus that separate synthetic Auth slot,
even if old bridge cleanup fails. Cleanup failure fails CI. All original Auth,
runtime, directory, owned window-exit probes and assertions remain mandatory.

This is a component process persistence probe, NOT learner restart recovery,
server receipt reconciliation, actual Auth/JWT/RLS, live provider or voice proof.
No app composition creates this store yet. Current route recovery remains
memory-only. Captured runtime persist-before-send, fresh Auth/profile/generation,
old actual-I/O drain, authenticated lookup and verified conditional release are
still required. Metadata/null/unknown receipt never permits a new event/provider
redispatch. AI stays off/default unavailable; all14 hosted release gates pending.

## Observed evidence

Parent516f809 CI40243813552 exact head/latest attempt1 completed success: all five
jobs/every required step/no skips. Windows121321113833 logs include actual receipt
Credential Manager metadata isolation/corruption/clear PASS. Existing 17 mock-channel
cases and full Flutter/platform suite passed the parent; these do not execute the
new receiver/probe. New receiver and process phases are authored, locally UNRUN:
no local Flutter SDK/Windows OS. Official Dart3.9.2 archive SHA verified; formatter
passed, with unresolved Flutter lint include warning (not analyzer proof). Portable
original C++17 validation passed, not new channel/Windows execution. New exact-head
CI must build/run all retained and added probes before claiming bridge success.
