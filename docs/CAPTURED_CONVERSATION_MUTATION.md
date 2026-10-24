# One captured conversation mutation — Issue #17

CapturedConversationMutation owns one immutable start/turn/finish request and
its typed response decoder. Factories capture one ReviewSession identity and the
caller vault/profile/ready-generation fence. All request fields are scalars;
wire snapshot is unmodifiable and retains exact client_event_id/body/operation.
Construction sends nothing. Only explicit submit dispatches; subsequent success
returns the same validated immutable result locally without another port call.
This memory cache is not a persisted server receipt or proof of remote commit.

Every submit/completion/cached-result access checks the captured identity and
readiness. Any observed loss/getter failure/unauthorized result permanently
revokes the instance; revoke also drops accepted result publication. Caller must
synchronously revoke on every owner readiness loss, even if a lease would later
look ready again. New same-user session objects cannot inherit an old operation.
No mutable global current-user SDK is selected. Readiness/identity hints do not
verify a JWT or replace backend ownership checks.

Singleflight is installed before the supplied port may synchronously reenter.
Timeout is positive and at most15 seconds. Timeout is uncertain failure, never
success/cancellation/remote rollback; busy stays set until the injected accepted
future actually settles. Late completion/error is consumed and never cached or
published. After it drains, only explicit submit retries the same immutable wire.
Safe frozen errors discard server messages, allow retryable only on transient
codes, reject malformed/mixed errors and normalize unknown exceptions.

ConversationMutationTransport is borrowed and unconfigured. Its eventual SDK/HTTP
implementation must recheck the captured bearer/generation immediately before
actual dispatch, enforce fixed trusted endpoints/HTTP/JSON limits and block
redispatch while ignored-abort network work remains held. A locally completed
port future alone cannot prove remote drain. This increment owns/closes no SDK,
HTTP, vault, journal or token writer, and introduces no service/provider activation.

This is a per-event primitive. It does not serialize separate instances, allocate
or deduplicate event IDs globally, track message sequence/session correlation,
validate server receipt ownership, persist uncertain operations across restart,
coordinate multiple conversation turns, install a UI or collect/play voice.
The next coordinator must retain accepted operation identity across errors and
account/route transitions and prevent fresh-ID substitution during uncertainty.
Server remains authoritative for operation-scoped receipts, ownership and replay.
Request text stays only in the retained object/borrowed port until caller releases
it; no history/transcript storage, automatic request or default success is added.

Thirteen injected-port test cases cover fixed request/typed response/cache,
manual same-wire retry, synchronous duplicate reentry, timeout late success/error,
A-B-A late success/error, readiness/explicit revoke, unauthorized/redaction,
malformed/error responses/unknown exceptions, nontransient retry flags/failing
getters, unavailable constructors/deadlines and new same-user identity. Evidence
in PROJECT_STATUS/exact-head PR is pure component proof, not real HTTP/SDK or
hosted learner acceptance. Parent81bd0f7 CI40073204935 allfive/every step passed,
939 Flutter/five Chrome; new exact-head full CI is still required. All14 hosted
gates stay pending, main/staging AI off, live provider/voice/Auth strategy and
applicable human collection/spend/release decisions remain unapproved.
