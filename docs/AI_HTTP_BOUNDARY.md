# Bounded AI HTTP adapter — Issue #31

backend/ai/src/http.ts supplies createAiHttpHandler(service, operation, timeoutMs)
for a trusted server caller. Each factory binds one of the five existing frozen
operations. Request URLs/query parameters cannot select a different operation,
project, provider or owner. No endpoint, deployment, CORS policy or JWT setting is
installed. Existing AiService dependencies remain mandatory: verified Supabase
identity, distributed limiter, trusted context/receipt transactions and provider.
Those concrete production adapters and Deno/Edge evidence are still outstanding.

## Envelope and streaming

Only POST, application/json (optionally charset=utf-8), absent/identity content
encoding and one bounded Bearer token are accepted. Unsupported encoding fails
before body parsing; no compressed-body fallback. Content-Length must be a
canonical nonnegative decimal at most32768, when supplied. Missing lengths do
not bypass the actual byte limit; mismatch fails closed. Envelope rejection
cancels the body and never calls Auth/provider/receipt ports.

Read through a native stream reader, counting actual Uint8Array bytes before
decoding each chunk. Bound to32768 bytes and32769 read iterations, including EOF;
the iteration cap prevents empty-chunk floods. Zero-byte chunks do not accumulate
text. Fatal UTF-8 decoding handles split multibyte sequences, rejects malformed
or truncated input, and retains BOM as data so the existing JSON parser rejects
it. Only the bounded decoded parts are concatenated. AiService alone parses and
validates JSON, preserving the same immutable request and receipt semantics.

One abort listener belongs to each pending read and is removed when it settles;
completed reads do not leave reactions attached to one ever-growing race. On
failure/abort, cancel without awaiting an uncooperative source and release the
reader lock. Raw stream errors become fixed network errors. The hosting runtime
still owns connection/header/concurrency limits and underlying I/O cancellation.

## Strict JSON member handling

After the bounded stream is decoded, the shared parseBounded path now uses
parseStrictJson. It rejects duplicate object member names at every depth,
including escape-equivalent names, before schema validation, quota reservation,
provider dispatch or receipt writes. Existing AI numeric JSON semantics are
retained; non-finite values and malformed JSON remain fixed validation failures.
This does not authenticate the caller or prove ownership/current curriculum.

## Deadline and late work

The overall deadline starts before body reads, defaults to15s and accepts only
integer1..30000ms from trusted configuration. A monotonic elapsed-time check
also runs around reads/dispatch/response serialization: synchronous pull or
already-resolved empty chunks cannot bypass it by starving timer callbacks.
Client disconnect and deadline abort the same parent signal. AiService.execute
now accepts an optional fourth parent AbortSignal; existing callers are unchanged.
Pre-aborted calls never verify identity or dispatch. A pending call races parent
cancellation, propagates abort to every existing port and retains its original
post-await guards. Timers/listeners are removed in finally blocks.

An ignored abort cannot permit a late identity/provider result to initiate a new
dispatch or complete a receipt after its existing guard. Already accepted remote
I/O/commits cannot be undone by this wrapper; production adapters must honor the
signal and preserve ambiguity/reconciliation rules. Timeout is not proof of
rollback. In particular a claimed mutation remains pending after a late result;
manual identical retry uses the existing lookup/recovery rules, never takeover
or automatic redispatch. No paid provider is configured or called by tests.

## HTTP results

Success returns the unchanged frozen response object. Errors return only the
existing code/message_vi/retryable object, with fixed Vietnamese adapter errors,
no raw exception, token, body or abort reason. Every response has JSON UTF-8,
no-store and nosniff headers. Method405 advertises POST;401 advertises Bearer.

| Condition | HTTP status |
| --- | --- |
| Service success | 200 |
| Validation / malformed UTF-8 / length mismatch | 400 |
| Missing or rejected Auth | 401 |
| Forbidden / missing item | 403 / 404 |
| Wrong method / unsupported media or encoding | 405 / 415 |
| Changed receipt replay / request too large | 409 / 413 |
| Rate limit | 429 |
| Client disconnected | 499 |
| Internal / network or provider unavailable | 500 / 503 |
| Overall HTTP deadline | 504 |

## Evidence and next adapter

Local Node24.19.0: pinned npm ci, Prettier check, strict TypeScript and all58 Node
tests passed, including20 new native Request/ReadableStream/service cases and
all38 original tests unchanged. Tests cover allfive frozen operations, envelope
rejection before dispatch, exact/forged/absent byte lengths, UTF-8 splits/errors,
empty floods, stalled/uncooperative sources, pre-abort/disconnect, late Auth and
provider results, unchanged receipts, safe errors and configuration bounds.
Auth/limiter/context/provider/receipt ports in those tests are explicitly TEST
ONLY; Node standard-API execution is not Deno/Edge/hosted evidence.

Next bind real verified Auth, atomic distributed limits and conversation/receipt
transactions, then lookup-only upstream reconciliation and observed Deno/Edge
compatibility. Preserve platform JWT verification and all human/security gates.
All14 hosted Personal Alpha groups remain pending; #31 stays open/#41 draft.

Primary API references reviewed2026-10-22:
- https://streams.spec.whatwg.org/#default-reader-release-lock
- https://nodejs.org/api/webstreams.html#readablestreamdefaultreadercancelreason
