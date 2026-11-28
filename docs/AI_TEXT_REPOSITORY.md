# Captured AI text repository — Issue #17

## Readiness callback lifecycle fence — 2026-10-29

Currentness now rejects nested readiness/Auth getter checks without dispatching
or permanently retiring a healthy outer check. A checking flag is restored in
finally. After the final readiness callback, re-read the exact captured session
identity and revoked state before authorizing send or result publication. A
same-user replacement is still a different session; restoring the old hint after
observed invalidation cannot revive the repository. Raw callback errors remain
fixed unauthorized failures; no callbacks grant hosted identity authority.

Six TEST ONLY regressions cover explicit revoke and same-user replacement from
the second readiness callback before send or after a transport response, plus
nested readiness/Auth getter calls. Require0/1 port calls at retirement, terminal
unauthorized and idle drain; nested calls must make no transport call, while the
healthy outer explain and subsequent correction retain original frozen output.
All original fixture bodies/assertions/timeouts/cleanup remain unchanged. No
single-flight/timeout/transport/default/provider/Auth/retention policy changes.

Parent140afb0 CI40809615439/latestattempt1 passed all5/EVERYstep,1497Flutter/
fiveChrome/Web/Windows and prior six receipt-readiness cases/native markers.
New6/format/analyze/build locally UNRUN(noSDK), require exact-head Actions. QA46/
inventory152/diffcheck recorded separately. This is captured-port safety work,
not hosted Auth/provider/learner proof.41draft/17open/all14hostedpending.

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


## Owned ready-generation assembly — explicit, default-disabled

AiTextRuntimeOwner retains one repository/OwnedAiTextTransport pair for one
AiTextGeneration. The generation is a fresh owner-created token per ready runtime,
not a user ID. Repeated factory access returns the same repository and issues no
request. Retired tokens are weakly marked with Expando, so A/B/A or a server401
cannot reconstruct another capability under the same ready generation without
retaining every old learner runtime in an ordinary strong-reference set.

Construction is registered before supplied getters/factories can reenter. Failed
readiness after allocation revokes/closes the orphan. Invalidate synchronously
revokes the repository and transport, then waits for accepted transport work and
cleanup before a new capability may be allocated. Old late success/error cannot
publish; drain completion only changes availability, never automatically creates
a repository or resends text. Revoke/close errors permanently disable that owner
and shutdown reports fixed INTERNAL_ERROR without raw cleanup details.
Idempotent close also waits for an orphan from reentrant construction. Availability
notifications contain no account/credential/text, and paused UI listeners cannot
hold SDK/resource shutdown open. Custom transport close must actually drain its
accepted work; a never-settling custom source keeps replacement blocked.

PersistentSupabaseRuntime now accepts trusted aiTextEnabled (default false) and
optional borrowed aiHttpClient, with createAiTextRepository/isAiTextEnabled/
aiTextChanges for later explicit UI assembly. Default main and Windows staging
startup do not enable this flag; no provider, route or live request is activated.
The flag is owner configuration, never a learner-controlled URL/key or approval
for paid provider use. Existing hosted/configuration/collection/spend gates remain.

The factory requires the exact persisted-session and own-profile ready runtime,
then binds a fresh generation and captures its readiness in both repository and
SupabaseAiTextTransport. No network call occurs on factory acquisition. Account
readiness transitions revoke synchronously. Explicit refresh and the optional
scheduler both pass through the runtime's revoke-before-persistence-refresh path.
A new ready generation waits for old transport drain, including ignored header
abort, before another factory call can succeed. After HTTP401 the same generation
remains unavailable; explicit refresh/relogin must establish a fresh ready barrier.

AI uses its own transport-owned HTTP client unless the caller explicitly supplies
a separate borrowed aiHttpClient. The existing Auth/REST-only HTTP wrapper and its
allowlist are unchanged; function requests never use that wrapper. The exclusively
owned SDK remains private and automatic SDK refresh stays disabled. close revokes
AI before its first await and drains it together with accepted persistence/study/
quiz operations before closing SDK/binding/owned resources. Supplied AI HTTP and
journal remain caller-owned; logout still clears credentials through the existing
ordered persistence path. Token storage/rotation/Auth strategy are not changed.

Parent e2b403d CI40011788906 attempt1 passed allfive jobs/every step:844 Flutter,
five Chrome and retained native/Windows/SQL/Edge gates, including28 HTTP cases.
Fresh official Dart3.9.2/checksum verified; identical eight-library/three-test graph
plus original fixtures passed69/69 cases (19 new owner +50 retained) and focused
strict analysis. Only flutter_test import adapted to package:test1.26.2. The19
new owner cases cover ready caching/no dispatch, missing/getter/readiness failures,
new/retired/same-user/A-B-A generation fencing, late results, reentrant acquire/
invalidate/close, orphan cleanup, failed revoke/close and paused listeners.

Eight additional tests target the actual PersistentSupabaseRuntime/SDK/vault/
profile/AI HTTP assembly: default-disabled, persisted-token/profile barriers,
refresh with held old headers and exact old/new bearer capture, logout/new-account
isolation, close drain/borrowed resources, vault write failure, profile retry and
401/fresh-generation recovery. They are authored, not run locally: this environment
has no full Flutter SDK; new exact-head Actions must confirm them and the builds.
All simulated Auth/vault/HTTP and unsigned JWTs are TEST ONLY, not hosted security
or learner evidence. Next review new CI, then add unavailable/loading/error tutor
UI through this factory, retaining explicit owner enablement and all release gates.
