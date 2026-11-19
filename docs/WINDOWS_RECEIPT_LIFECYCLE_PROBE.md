# Windows receipt lifecycle process probe — Issue #17

The existing TEST ONLY Flutter bridge now runs four additional sequential phases
plus finally cleanup in separate actual Windows runner processes. The mandatory
existing PowerShell step retains its per-process60s bound/exit checks and all old
Auth/directory/runtime/window-close/receipt assertions; new phase failure fails CI.
Normal learner builds/default factories and production source are unchanged.

windows_receipt_lifecycle_fixture.dart uses the actual Windows secure-store
factory, ReceiptAiRuntimeOwner, AiTextRuntimeOwner, conversation session, receipt
decorator/barrier, fixed MethodChannel and Credential Manager. Auth hints and the
held mutation port are TEST ONLY, with no SDK session, HTTP, provider, billing or
learner credential. It uses invocation-unique validated .invalid origins, three
fixed account/project partitions and one separate synthetic refresh marker.
No token/text/response is written into receipt metadata or emitted in logs.

- write: assert initial absence, synthetic refresh marker, actual receipt metadata
  already readable via native channel at mutation-port entry. Hold synthetic wire,
  preserve-close the runtime, verify revoked transport/no early inner close or
  ownership release and metadata still present, release late callback and drain.
  Preserve A metadata; write/close B in the same project for isolation checks.
- reopen: fresh real process/factory reads A metadata; sending even the same event
  fails conflict with ZERO mutation-port sends. Close preserves metadata and B.
- logout: another project starts a held mutation, then signOut. Its actual native
  metadata stays present and isolate ownership stays claimed until callback drain;
  only then is its exact slot cleared/ownership released. Earlier A/B survive.
  Signout A then B, checking A deletion never clears B. No server cancellation or
  remote Supabase logout is inferred.
- absent: a fourth process confirms all three native slots absent and can create/
  preserve-close fresh lifecycle owners; synthetic refresh marker is unchanged.
- cleanup: a separate finally phase attempts all three owned synthetic receipt
  slots and that invocation's synthetic Auth slot, even if earlier cleanup fails.
  Any cleanup failure fails the process/CI. No credential enumeration/bulk clear.

Held callback errors are observed; finally releases the synthetic callback and
awaits lifecycle close. Early port-entry failure is observed without waiting for
the held callback. Existing runner catches errors with a fixed message, never raw
OS/input/credential details. PowerShell process deadline remains the outer bound.
This is planned actual OS/runtime process evidence, NOT actual HTTP cancellation,
JWT validation, hosted provider, learner app restoration or cross-process locking.
The claim check is isolate-local; host must still exclude competing same-user
processes. The raw native read is test observation only, not dispatch authority.

Parent23b3fdf CI40263300013 raw exact head/latest attempt1 all5 jobs/every required
step passed. Completed Flutter121380505374 logs explicitly contain all3 Windows
factory mock cases and the failed-clear lifecycle case. This verifies the earlier
owner/factory, not the new process phases. New probes are authored, locally UNRUN:
Windows/full Flutter unavailable here. Pinned official Dart3.9.2 archive SHA256
verified; formatter2 zero changes, with unresolved Flutter lint include warning
(not analysis proof). Full new-head analyze/build/probe execution awaits CI.

Next inspect exact new-head/latest attempt full5jobs/every required step and
explicit Windows actual receipt lifecycle preserve/reopen/no-redispatch/drain/
signout/isolation marker. Then actual SDK/runtime storage-failure/refresh/account
journeys and authenticated receipt lookup/verified conditional release before
later commands. No default activation, automatic replay/new event, frozen API/
SQL/RLS/Auth strategy/CI/dependency/Pro/provider/collection/spend/release change.
Learner route remains memory-only/one pending command; all14 hosted gates pending.


## Owned completion handle reopen acceptance — 2026-11-18

The existing mandatory receipt-owned-reopen process now makes three additional
original-command reads through production PersistentSupabaseRuntime's reader,
private SDK and actual Windows refresh/receipt vault. The TEST ONLY host supplies
the full original start DTO explicitly; native metadata never reconstructs it.
UNKNOWN/PENDING yield no handle. COMPLETED returns the same immutable original
and typed start result, supports no-I/O repeat capture and fixed redacted text.
Every status preserves the actual rotated refresh secret and exact native pending
reference; both original-event conflict and different-event pending denial must
still prevent mutation HTTP. Owned close retires/redacts the completion handle
while preserving token/receipt metadata. Existing shutdown/logout/absence/cleanup
phases remain mandatory with their original deadlines and assertions.

A separate completionReceiptReads counter advances only after every existing
fixed endpoint/query/body/bearer/no-store/native-reference assertion. It must be
exactly three without changing legacy/original/protected/additional/mismatch read
counts. The completion flag defaults off and is cleared before close. The runner
adds the following marker only after the whole owned reopen invocation succeeds:
Windows OWNED completion handle unknown/pending/completed/capture/stale-close/preserve/no-redispatch passed (TEST ONLY Auth/HTTP)

Native Windows/Flutter/PowerShell execution is locally UNRUN; exact-head CI must
observe the new marker and all retained required steps. Auth/JWT/profile/HTTP
responses remain synthetic, so this is not hosted JWT/RLS/provider/learner proof.
There is no new plaintext payload persistence, clear/retry/new-command grant,
transcript application or conditional release/default activation.


## Owned prospective transcript preview — 2026-11-19

The existing receipt-owned-reopen phase now inspects and previews the completed
start through the production session and completion reader borrowed from the same
PersistentSupabaseRuntime/private SDK. The actual persisted receipt first blocks
mutation dispatch and the production session retains the host-supplied original.
The completion must associate with that exact original/Auth and produce an active
candidate with the same decoded first assistant message and sequence zero.
The actual notStarted snapshot and retained-command objects must remain identical,
the lane unresolved/current/idle and retry disabled after both same-event conflict
and different-event pending denials. No additional HTTP reads or mutation sends
are permitted; every old counter and native rotated token/pending assertion stays.
Owned close must make inspection and preview return null, redact the retained
command and revoke the live projection while preserving the actual native stores.

The PowerShell runner emits this only after the entire owned reopen succeeds:
Windows OWNED completion preview exact-original/unchanged-transcript/pending/stale-close/preserve/no-redispatch passed (TEST ONLY Auth/HTTP)

All existing phases, finally cleanup, process deadlines and earlier markers remain
mandatory. Native Windows/full Flutter/PowerShell execution is locally UNRUN;
new exact-head CI must execute these assertions. Parent8b2e3f2 CI44441018779
attempt1 passed all five jobs/all123 returned steps; its Windows log contains the
persistent-vault and owned-completion-handle markers. That parent run does not
verify this new preview probe. Auth/JWT/profile/HTTP remain TEST ONLY; the host,
private SDK and native vault ownership are production composition. This is not
hosted learner acceptance. No transcript application, conditional pending clear,
retry/new-command authority, payload persistence or default activation is added.


## Conditional store clear across actual processes — 2026-11-19

Three additional mandatory receipt-life-conditional phases follow all original
lifecycle phases. They reuse only the invocation's three already-cleared TEST ONLY
partitions and synthetic refresh marker. The original finally cleanup still
attempts all three receipt slots and that exact Auth slot on any failure. Every
new process uses the existing60s deadline/exit checks; no old assertion is removed.

- write: require all slots absent; reserve real native A/B metadata through the
  production Windows store factory, read it back, close and confirm preservation.
- reopen: a second actual process observes A/B. Wrong operation/event, false or
  throwing TEST ONLY currentness guard and foreign-owner input cannot clear A.
  The exact A reference must clear successfully through the production store,
  including its post-clear native confirmation read; raw native observation also
  confirms A absent while B remains exactly preserved. Close drains the store.
- absent: a third actual process requires A absent/B preserved. Clearing missing A
  must return false, not fabricate release evidence. Exact B clear must return true;
  both factory and raw native reads then require all slots absent. The synthetic
  refresh marker must remain identical before and after each phase.

Only after all three actual invocations succeed, the runner emits:
Windows conditional receipt clear exact/mismatch/guard/isolation/confirm/reopen/auth-preserve passed (TEST ONLY host guard; no completion grant)

This specifically tests the actual Credential Manager/MethodChannel/store queue
and confirmed deletion across processes. Host guards are synthetic; there is no
Supabase SDK/session/JWT/HTTP/completed server receipt, transcript/lane release,
provider dispatch, learner credential or default wiring in these additions.
This is not production authenticated recovery or hosted learner acceptance. The
reference contains no original request/session/transcript; missing metadata or
this probe's true result grants no authority to send another command.

New native Windows/Flutter/PowerShell execution is locally UNRUN and awaits the
new exact-head CI. Parenta585edf CI44479161111 latestattempt1 all6jobs/all127steps
SUCCESS, including retained persistent-vault and OWNED completion-preview markers;
that parent result does not execute these new phases. No payload persistence,
plaintext fallback, channel/native implementation, security gate or deadline
change. Next integrate authenticated completion/full-original/current-generation
validation and confirmed storage clear with matching drained lane/session atomic
application; keep every hosted Personal Alpha gate pending until real evidence.
