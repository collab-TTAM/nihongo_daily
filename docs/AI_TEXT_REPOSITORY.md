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

At source9014ee7, CI39994699895 attempt1 completed with the AI, database,
repo-sanity and Windows jobs/every step successful. Flutter failed pinned
formatting for the two new Dart files; analyze, tests and downstream Flutter
platform checks were skipped. Those skipped checks are not passing evidence.

The follow-up fetched a fresh checkout and official Dart3.9.2 archive/checksum.
Its formatter diff exactly matched the pinned CI diagnostic. All22 cases and
assertions were retained; one unused StackTrace parameter now uses a wildcard
to satisfy the analyzer. A fresh identical four-library/one-test graph and original
fixture bytes, with only flutter_test import adapted to package:test1.26.2, passed
22/22 tests and strict casts/inference/raw types plus lints6.0.0 analysis. Format
reports zero changes and the81-case QA inventory is valid. This is pure Dart
component execution; full Flutter/SDK/browser/build checks require the new exact
head Actions/latest-attempt jobs/every step. No prior-head or skipped evidence
substitutes for those checks. Final commit/CI checkpoint is in PR41/Issue17.

Next implement a separately reviewed concrete caller-owned fixed-project text
transport with actual credential capture, request/response byte/JSON limits,
redirect rejection, cancellation/deadline and SDK/HTTP late-response tests, then
owned runtime/UI assembly. Injected ports alone do not provide those guarantees.
No learner-supplied URL/key, default mock success or plaintext credential fallback.
Hosted Auth/Edge/provider/voice/learner evidence and applicable collection/spend
approvals remain open. All14 Personal Alpha release groups remain pending; keep
#17 open/#41 draft. No Pro/content/manifest/SQL/RLS/CI/dependency change or deployment.


## Concrete captured HTTP transport — opt-in component

SupabaseAiTextTransport implements both fixed operations using http1.6.0 and a
caller-owned Supabase2.16.5 client. It accepts trusted owner project/public-key
configuration checked against that SDK client. It never accepts a learner URL,
key, operation path, owner or credential field. The only destinations are the
configured HTTPS origin's /functions/v1/tutor_explain and correct_sentence.
These are adapter route assumptions for later reviewed hosting, not deployed
functions or a provider selection. No runtime/default/UI assembly calls it yet.

Capture the exact ReviewAuth identity, SDK Session object and immutable bearer
once, together with the owner's captured ready-generation callback. Only fixed
captured credentials enter request headers; never select a current-token callback,
set SDK Auth, refresh, sign out, save tokens or log payloads. JWT role/sub/session/
expiry/shape are bounded fail-closed local hints, not signature verification.
Construction and dispatch require matching project/public key and ready identity;
SDK Session replacement (including refresh), identity/readiness/getter failure,
expiry, explicit revoke and HTTP401 permanently fence that capability. SDK Auth
changes are subscribed; the owner must call revoke synchronously for vault/profile/
runtime readiness loss. Checks bracket all awaits and decoding/publication.

Request maps are strictly reconstructed through the frozen DTOs, rejecting extra
owner/context fields and invalid types/IDs/bounds before HTTP. Encode once, limit
UTF8 bytes to32768, POST JSON to one fixed path with captured apikey/bearer,
no-store and redirects disabled/maxRedirects0. No automatic retry. A custom HTTP
client must honor that contract; this library cannot make a malicious client safe.

Accept only JSON UTF8 (optional charset=utf-8) and absent/identity encoding.
Canonical supplied Content-Length and StreamedResponse length metadata must agree
with actual bytes. Count real chunks up to1 MiB and4096 reads including EOF;
empty-chunk floods cannot consume unbounded reads. Fatal UTF8 and explicit BOM
rejection precede bounded JSON depth16/duplicate-key preflight (including escaped
and nested duplicate keys), then standard grammar and strict response DTO decoding.
The same JSON preflight bounds local JWT payload parsing. These operational byte/
read limits may reject otherwise schema-valid very large responses; they never
truncate or manufacture output. A single oversized custom chunk is already
allocated by that client's source; adapter-side accumulation stays bounded.

Only HTTP200 with the named valid success schema returns data. Matching bounded
frozen error objects on their expected HTTP status become fixed safe failures,
with only transient retry flags retained. Gateway/non-JSON status failures receive
fixed mappings; malformed JSON/success fails internal. HTTP401 revokes before body
parsing. Raw server/SDK/stream/cancel messages never enter exception strings or UI.
A retryable server flag still provides no text receipt or automatic retry permission.

One in-flight lease covers both methods, installed before reentrant map/HTTP code.
Use AbortableRequest, a single overall (0,15s] asynchronous wait budget and
monotonic elapsed checks around reads/dispatch/JSON. Per-read abort listeners are
removed after settlement. Timeout/revoke triggers abort and cancels the body;
late headers/errors are consumed/cancelled, never published or redispatched.
Hold busy until underlying headers and stream-cancellation cleanup settle. Even
when a result wait has ended, another operation receives local pending rather
than a new HTTP call. CapturedAiTextRepository preserves that local pending type.
Normal EOF and cooperative cleanup allow immediate subsequent calls; cancellation
errors permanently revoke the port. No remote rollback/zero-cost/hard CPU-preemption
or actual hosted proxy cancellation proof is inferred from local abort signals.

close is idempotent: revoke, remove owned SDK subscription, close only an owned
HTTP client and drain accepted work. Borrowed SDK/HTTP remain caller-owned. A custom
client that ignores abort or whose cancellation never settles can keep drain/busy
pending; the owner must resolve its resources rather than permit overlap. A failed
cancellation revokes future dispatch but does not prove the remote request stopped.
The existing Auth-only runtime HTTP wrapper does not allow function routes; later
owned assembly needs an explicitly scoped AI HTTP resource, not a broader bypass.

Verification: parent2ebe41a CI40002993953 attempt1 allfive/every step passed,
816 Flutter/five Chrome including22 repository cases. This increment passed28
new streamed-HTTP/actual-SDK cases plus all22 unchanged repository cases in a
fresh identical seven-library/two-test graph; only flutter_test import adapted to
package:test1.26.2. Fresh official Dart3.9.2 archive/checksum matched; direct app
Supabase/http/logging versions retained. Strict focused analysis clean, formatting
and QA inventory/regressions checked separately. The execution environment briefly
disconnected then reconnected with same-run files intact; final source graph was
copied again and50/50 cases rerun. No reconstructed replacement source was used.
Tests use TEST ONLY unsigned JWT/Auth and HTTP streams, not real network/TLS/
hosted identity/provider/voice or learner proof. New exact-head full CI required.
Next add separately reviewed owned runtime factory, ready-generation revocation and
transport drain before resource closure, then unavailable/loading/error tutor UI.
All hosted/collection/spend/voice gates remain; no default activation or release.
