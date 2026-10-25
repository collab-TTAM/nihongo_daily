# Windows receipt channel facade — Issue #17

Optional createWindowsConversationReceiptStore binds the existing caller-owned
store to a separate fixed nihongo_daily/conversation_receipts_v1 MethodChannel.
Only Windows/non-web may invoke it; no app/default assembly is changed. Each
backend instance accepts only its exact canonical project/account target and
validates canonical metadata/scope on write and read. Mutation acknowledgment
must be boolean true; absent/wrong values fail, never simulated success. Native
messages/details are replaced by fixed failures; no logging or plaintext fallback.
The existing store keeps exclusive isolate ownership/serialization/late-I/O guards.

IMPORTANT: native receiver and OS backend are NOT implemented/registered by this
increment. MissingPlugin fails unavailable. The Auth vault channel, native target
allowlist, credential namespace and all old tests are untouched. This facade is
not proof of secure storage, encryption, actual Windows bridge or restart recovery.
No new endpoint, Auth strategy, collection, provider, default or Pro change.

17 mock-channel cases AUTHORED locally UNRUN cover exact method/arguments/scoped
metadata, non-Windows no-I/O, missing receiver, private errors, strict write/clear
acknowledgments, malformed/noncanonical and foreign-owner values. Full Flutter/
analyze/native/build await exact-head CI; no denied Flutter bootstrap workaround.
Parent38171ff CI40221667135/latest attempt1 allfive/every step success/no skips;
Flutter log121254760462 confirms1227Flutter/fiveChrome/all11 store cases. This is
component evidence, not hosted learner acceptance. All14 hosted gates pending.

Next implement a reviewed independent native receipt channel/namespace with
Credential Manager and bounded process probes, retaining Auth allowlist. Then
actual Dart-to-OS wiring and captured runtime write-before-dispatch, fresh Auth/
profile, real I/O drain and authenticated lookup/verified conditional release.
Metadata/missing/unknown result never authorizes redispatch/new event. Existing
route recovery remains memory-only; keep41draft/17open/AIoff/no release claim.

Local: fresh official Dart3.9.2 SHA verified/format2/46QA/inventory120/whitespace and separate scope/channel/ack/error/no-activation review PASS. All119 old QA objects/findings/gates and old source/tests exact; full local Flutter/analyze/new17/native/build UNRUN. Prior usage review failure was not bypassed; fresh git-version preflight and new clone succeeded.
