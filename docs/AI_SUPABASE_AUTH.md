# Fixed-project server AI identity verification

`backend/ai/src/supabase_auth.ts` implements the existing `AuthVerifier` port.
It is an opt-in server component; no endpoint is assembled or deployed and the
ordinary Flutter preview is unchanged. The host supplies a trusted HTTPS project
origin and public publishable/legacy anon key through deployment configuration.
Neither setting can come from learner JSON, query parameters, JWT claims or a
learner-editable form. Reject credentials in URLs, paths, queries, fragments,
private/secret/service-role key classes and malformed configuration with fixed
errors. Legacy key payload decoding classifies public configuration only; it is
not verification of a learner token, key signature or project ownership.

For each request, send one GET to that fixed origin's `/auth/v1/user`, with
`apikey` equal to the configured public key and `Authorization` containing the
caller's access token. Use native fetch with redirect errors, no-store and omitted
ambient credentials. Never refresh, retry, select another project or fall back to
an identity cache. Reject redirected/different-origin responses even when a test
transport supplies them. The injected fetch implementation is trusted host code;
production must preserve native redirect/TLS/cache behavior. Do not log requests,
headers, tokens, response bodies or raw exceptions.

The trust boundary is the configured Supabase Auth server's validation of the
access token. Never use decoded learner JWT claims, user metadata, email or a
client owner field to authorize an operation. Accept only a successful JSON user
object with UUID `id` and `aud: authenticated`; return only the lowercase UUID.
Metadata and other user attributes are discarded. Each operation rechecks Auth;
this does not promise immediate JWT revocation on logout, and it does not replace
RLS, curriculum/session authorization, verified provider correlation or a trusted
server's transaction privileges. Existing Auth strategy/providers are unchanged.

## Failure and resource policy

- Empty/malformed/header-injection/over-8192-character bearer: null identity,
  before HTTP. Auth HTTP401/403: null identity. AiService maps this to its existing
  fixed UNAUTHORIZED response before limiter, context, receipt or provider calls.
- Auth HTTP429: fixed RATE_LIMITED. Network errors, other statuses, invalid or
  wrong-audience user JSON, wrong content type, body errors and resource failures:
  fixed NETWORK_UNAVAILABLE. No upstream body or abort reason appears in errors.
- Independent default five-second deadline, constrained to1–15000ms, covers fetch
  and body reads and is also cancelled by the caller's service/HTTP signal.
  Monotonic checks reject timer-starving synchronous work. Failure never renews a
  dispatch claim or retries an upstream request.
- Actual streamed decoded-body bytes are bounded to65536 before concatenation;
  do not trust Content-Length (which may describe compressed transport bytes).
  Fatal streaming UTF-8 rejects malformed/truncated text; BOM/malformed JSON is
  rejected. Bound read iterations to65537, including EOF, to stop empty floods.
- Per-read abort listeners are removed. Abort/failure cancels body readers without
  awaiting an uncooperative source cancellation, releases the reader and removes
  caller listeners/timers. Late fetch responses are cancelled and cannot return
  an identity or advance the service. Aborting I/O cannot preempt synchronous
  JavaScript or guarantee immediate remote connection closure.

## Reproduction and evidence limits

From `backend/ai`:

```sh
npm ci --ignore-scripts --no-audit --no-fund
npm run format:check
npm run check
npm test
npm audit --omit=dev --audit-level=moderate
```

Twenty-one new Node24 tests exercise configuration/key classes, the exact fixed
request, server UUID over unverified JWT/metadata, Auth401/403 rejection through
actual HTTP/service composition, status/network redaction, redirects, malformed
users/UTF-8, exact64KiB/split Japanese UTF-8, absent/forged lengths, read failures,
pre-abort, ignored/late fetch, stalled bodies, timer starvation, empty floods,
listener cleanup, concurrent A/B and later Auth rejection without cache, and
service owner propagation/no token forwarding/late timeout without dispatch.
Existing58 tests remain unchanged. These use TEST ONLY responses and injected
limiter/context/provider/receipt ports. Native Response/ReadableStream and the
new production adapter/service execute; this is not hosted Auth/signature/issuer/
expiry/other-project JWT proof, Deno/Edge compatibility, distributed quotas,
conversation transactions or a live provider. #31 remains open. No paid provider,
configuration secret or network Auth call is needed for these tests.

Supabase primary documentation checked2026-10-22:
https://supabase.com/docs/reference/javascript/auth-getuser documents server-side
user lookup as authentic identity evidence. Actual hosting must still configure
and test the intended project and reject missing/expired/forged/other-project
access tokens with provisioned learner A/B through the assembled Edge boundary.
