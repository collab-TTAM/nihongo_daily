# Captured AI text repository — Issue #17

CapturedAiTextRepository borrows ReviewAuth, one exact ReviewSession identity hint,
a trusted owner readiness callback and an AiTextTransport. It implements explicit
explain/correct calls using the strict frozen models in AI_TEXT_MODELS.md. This
library does not install an SDK/HTTP adapter, runtime factory, UI, provider or
default service. Existing previews, Auth strategy and backend contracts remain.

## Ownership and publication

The owner must capture its exact ready vault/profile/runtime generation in isReady;
a live global boolean alone cannot describe a missed refresh/profile barrier.
ReviewSession is not a credential or JWT verification. The eventual transport
must use the captured authenticated lease and recheck it immediately before real
dispatch, rather than selecting a mutable global current-user client.

Construction requires current identity and readiness. Every dispatch, success,
error and timeout checks that same capability; decoded success is checked again
before returning. Observed identity/readiness mismatch, getter failure, explicit
revoke or a server UNAUTHORIZED permanently fences this repository, even for the
same user later. New ready lifecycles need a new owner-created capability.

The repository owns no SDK, token, client, subscription, storage or session. revoke
only blocks dispatch/publication; the owner still cancels/drains accepted transport
work before closing its resources. No logout, client close or new Auth strategy is
performed here. Multiple repository instances are not a distributed rate limiter;
the eventual owner should retain its one capability per ready generation.

## Requests, results and safe failures

The transport exposes only tutorExplain and correctSentence, with a captured
session and a deeply immutable request body. There is no arbitrary operation,
owner, credential, endpoint or provider argument. Request text/context remains
the caller's explicit immutable model; no learner history is collected or inferred.

Successful responses use strict TutorExplanation/SentenceCorrection decoding.
Unknown/missing/mixed error or malformed success cannot fabricate output.
Server errors require exactly code/message_vi/retryable with the frozen code set,
bounded nonempty text and boolean flag. Raw message text is discarded. Only
network/provider/rate-limit retry flags survive; permanent flags are clamped off.
Typed transport failures receive the same normalization, unknown exceptions become
fixed INTERNAL_ERROR. Public messages and exception strings contain no raw
transport/provider/error payload. No request/response/error logging or caching.

A local AiTextRequestPending distinguishes an active call from a server quota.
One request spans both methods, registered before synchronous transport reentry.
It remains locked until both result handling and the underlying future settle.
No implicit queue, automatic retry, batching or conversation receipt is added.

Trusted timeout configuration defaults to15 seconds and accepts only (0,15s].
Timeout ends the asynchronous result wait with NETWORK_UNAVAILABLE/retryable=false,
checks revocation first and retains the lock while the original future is pending.
Late success/error only releases that lock; it cannot publish a result, dispatch
again or become an unhandled error. This is not cancellation, rollback, a hard
CPU deadline or proof that remote provider work was not charged. A port that never
settles stays busy; the resource owner must resolve/cancel its own transport.

Even a transient server retryable flag is not an idempotency guarantee or permission
for automatic retry. Frozen text calls have no client_event_id; another explicit
call may invoke a provider again. The backend still owns verified identity, rate
limits, trusted curriculum context and provider policy. Structural references do
not authorize study writes, mastery, counters or plan time.

## Evidence and next work

Parent1fb3611 CI39986349215/latest attempt1 passed allfive jobs/every required
step:794 full Flutter/five Chrome, all17 new text-model cases, Web/Windows and
retained native/SQL/Edge gates. This verifies the prior models, not this repository.

Twenty-two repository cases are authored using original frozen fixtures and TEST
ONLY Auth/readiness/transport: both fixed encodings/identity; immutable body;
construction/timeout config; same-user/other-user/logout/revoke/readiness/getter/
generation fencing; late success/error; safe code normalization/server revocation;
malformed errors/swapped success; duplicate/cross-method/reentrant calls; timeout
lock retention, late success/error and revocation precedence. They neither verify
SDK credential capture nor call a hosted endpoint/provider.

This run has no usable execution environment. Fresh GitHub full recursive tree
and required complete source blobs were read; no previous scratch source/SDK is
used. Format/analyze/test/QA/build have not run locally. Source/diff/schema and
static inventory review are not executable Dart proof. Persist as draft and
inspect exact-head Actions/allfive latest-attempt jobs/every step before claiming
these cases pass. No skipped or prior-head evidence substitutes for that.

Next implement a separately reviewed concrete caller-owned fixed-project text
transport with actual credential capture, request/response byte/JSON limits,
redirect rejection, cancellation/deadline and SDK/HTTP late-response tests, then
owned runtime/UI assembly. Injected ports alone do not provide those guarantees.
No learner-supplied URL/key, default mock success or plaintext credential fallback.
Hosted Auth/Edge/provider/voice/learner evidence and applicable collection/spend
approvals remain open. All14 Personal Alpha release groups remain pending; keep
#17 open/#41 draft. No Pro/content/manifest/SQL/RLS/CI/dependency change or deployment.
