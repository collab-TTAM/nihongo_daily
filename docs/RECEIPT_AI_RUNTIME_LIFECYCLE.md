# Receipt store/runtime lifecycle — Issue #17

ReceiptAiRuntimeOwner owns one existing secure account/project receipt store and
an AiTextRuntimeOwner. Its typed transport factory receives that SAME borrowed
store and returns ReceiptGuardedAiTransport bound to the same trusted project,
exact captured Auth hint and vault/profile/runtime-generation readiness. The
factory owns orphan cleanup on construction failure, as for existing owner
factories. Construction performs no storage I/O, Auth success, HTTP or provider
call. Runtime acquisition/revocation semantics stay in the existing runtime owner.

createWindowsReceiptAiRuntimeOwner explicitly creates the already reviewed
Windows MethodChannel/Credential Manager facade and gives ownership to this
lifecycle. It accepts a trusted canonical scope/factory, not learner URL/key input.
Missing native support/unsupported platform fails unavailable with no fallback.
No default/staging app/SDK factory is changed to activate this composition.

The lifecycle owner has two mutually exclusive terminal shutdown choices:

- close synchronously starts runtime retirement, waits actual storage/HTTP drain
  and owned inner close, then closes/releases the store while preserving metadata.
- signOut synchronously starts that same runtime shutdown, waits actual drain,
  clears only its exact store partition with confirmed secure-store success,
  then closes/releases ownership. This is local metadata deletion, not remote
  Supabase logout, server cancellation or permission for another provider call.

Promises/mode are installed BEFORE supplied cleanup/backend code can reenter.
Concurrent calls share the chosen operation. Once preserve-close has started,
signOut is rejected: ownership may already be released to another caller. During
sign-out, close shares the ongoing result; after failed clear, close fails without
retrying or releasing the store. Only another EXPLICIT signOut may retry that
failed clear. A failed runtime drain also blocks clear/release; a cached failed
runtime cleanup cannot be interpreted as a new successful lifecycle.

Late persisted writes cannot start HTTP after retirement. Pending metadata is not
deleted until actual old I/O settles. Store close is NEVER a finally action after
failed drain/clear, so a new owner cannot bypass ambiguous cleanup. A caller must
observe these errors; the component makes no remote Auth revocation or successful
learner logout claim. The host still owns Supabase session-generation barriers,
refresh/profile readiness and the approved logout strategy.

Nine pure tests use actual runtime/session/decorator around TEST ONLY storage and
transport ports: inert construction, preserve-close, shared held clear, failed
clear/blocked-close/explicit retry, held write preserve versus signout, held wire
late success/error, and failed runtime cleanup. They check exact clear ordering,
no late HTTP, metadata retention and ownership held/released at the right point.
Three separate Flutter mock-channel cases cover explicit Windows close/signout
arguments and false acknowledgment followed by explicit retry; these are authored,
not locally executed. Pure tests/mocks are not Windows OS/SDK/hosted learner proof.

Parent9b0067a CI40258343027 raw exact head/latest attempt1 all5 jobs/every required
step passed. That verifies the prior decorator and its12 cases, not this increment.
Full new-head Flutter/analyzer/mock/native builds remain required CI evidence.

Next actual Windows process probe with this lifecycle and actual SDK/runtime
storage-failure/refresh/account journeys. Authenticated receipt lookup/verified
conditional release remains necessary before additional conversation commands.
One pending command only, no automatic retry/metadata-derived command/reset/clear
outside explicit signout. Learner route remains memory-only/default AI unavailable;
all14 hosted release groups pending. No Auth strategy/API/SQL/RLS/dependency/CI/
provider/collection/spend/content/Pro/default activation/release change.
