# Retained original conversation command — Issue #17

CapturedConversationSession now retains one private retry closure capturing the
original immutable typed request, plus an exact operation/JSON fingerprint and
safe retry eligibility. No tokens, caller-supplied replacement payload, new event,
reset/new-round operation, disk storage, automatic dispatch or transcript writer.
This is a same-process/same-ready-generation prerequisite, NOT durable recovery
across refresh/logout/process restart. Runtime must keep/revoke its existing flow.

canRetryRetained is an explicit trusted host capability only when captured identity/
readiness remains current, one unresolved original command exists, the latest exact
original attempt failed retryably, and actual wire/caller work has drained. It
fails closed during readiness reentry or another submission. retryRetained takes
no payload/event: explicitly delegates to the SAME start/turn/finish method with
the original DTO; existing phase/session/receipt fingerprint/capacity guards remain
authoritative. Existing mutation/lane validates safe error policy and captured
Auth/readiness immediately before I/O. Simultaneous calls cannot overlap.

A foreign pending event cannot overwrite the saved closure or retry eligibility.
Successful completion and revocation clear closure/fingerprint/eligibility. Timeout
retains original command but busy old wire prevents retry until drain; late replies
never authorize a new ID. Nonretryable/malformed/authorization failures do not gain
retry authority. Completed original receipt replay does not reset later progress.
Retained command remains bounded to ONE current request, alongside existing bounded
lane history; original user text is never exposed by this capability getter.

Existing AiConversationController/workspace/panel/default providers/routes remain
unchanged, so legacy remount still blocks reconstructed retry. A disposed view
cannot dispatch; trusted host can explicitly use the retained flow capability and
then obtain a fresh guarded projection. UI wiring/actual owned lifecycle tests of
that explicit recovery action remain next after CI. No route automatically enables
this method and no uncertain receipt abandonment/new-round policy is implied.

Nine TEST ONLY pure cases cover exact original start/turn/finish retry and no extra
replay; disposed view/legacy remount policy; same-user identity replacement/A-B-A;
nonretryable errors; foreign-event overwrite denial; timeout/drain; readiness
reentry/concurrent retry. Actual flow/controller/lane/strict DTOs with injected
Auth/port and frozen fixture bytes. All9 plus all20 original session cases PASS in
fresh12-file source graph using official Dart3.9.2 (SHA verified), ONLY flutter_test
runner -> test1.26.2 and fixture path adaptation. Strict casts/inference/raw-types
source/new-test analysis clean (lints6). Initial harness package/path setup failures
were corrected before the final completed resolution/test run; no weakened assertion.
Not actual Flutter/SDK/hosted execution; full new-head CI still required.

Parent7ef7dc0 CI40215546634/latest attempt1 passed allfive/every required step/no
skips. Log121236182966 confirms1184Flutter/fiveChrome/all6 owned route retry/remount
cases. Retained Web/Windows/native/SQL/Edge gates passed; component proof only.
Format2 zerochanges/46QA/inventory114/whitespace/separate lifecycle/fingerprint/
retention/diff review PASS. All113 prior QA objects/findings/gates exact/all14 hosted
pending. All old test bodies unchanged. No Auth strategy/provider/default/UI/SDK/
API/schema/RLS/CI/dependencies/Pro/content changes. Keep41draft/17open/AIoff.
Next exact new-head/allfive/every step/new9 and explicit guarded host/UI integration,
then separately reviewed secure persistence/restart recovery. No plaintext fallback,
provider activation/spend/collection/release/deploy/security reduction/Alpha claim.
