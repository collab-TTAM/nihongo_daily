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
