# Provider-neutral AI boundary — Issue #7

`backend/ai` is a server-only TypeScript library tested on Node 24. It is not a
published Edge Function, configured provider, Flutter AI screen or voice service.
All runtime dependencies are explicit injected ports. No deployment/bootstrap,
private key, auth strategy change or paid provider call is included. Test Auth,
limiter, context, provider, recovery and memory receipts are TEST ONLY fixtures.
They are not integration evidence. The eventual Supabase Edge binding must be
verified on its Deno runtime; Node compatibility alone does not establish that.

## Frozen contracts and typed interfaces

Five operations preserve v0.1 requests/responses: tutor_explain, correct_sentence,
start_conversation, conversation_turn, finish_conversation. `src/wire.ts` is
regenerated from all named frozen schema definitions by `generate_types.py`;
CI verifies the projection. Ajv 2020 validates the original shared schema with
formats, disabled dynamic $data schemas, strict finite numbers and no coercion, defaults or unknown-field removal.
Required nullable fields and assistant-only role remain mandatory. No new fields
are added to public wire schemas. Prepared-session UUID binding is case-insensitive;
receipt requests still compare all immutable supplied fields structurally. An invalid model answer is never a success.

The library accepts bounded JSON strings, not arbitrary executable model output.
JSON.parse uses its standard last-member semantics for duplicate JSON keys; the
same parsed, immutable object is validated and supplied to persistence. Adapters
must not reinterpret the original raw text or parse it again with another rule.
No parser mismatch can authorize a different owner/event. Model output cannot
choose session/message IDs, sequence numbers, audio links or unvetted curriculum
refs. Server-assigned IDs and allowlists are checked before the trusted repository
validates semantics. SRS recommendations do not automatically mutate SRS.

## Auth, rate and resource boundaries

`AuthVerifier.verify` must verify the supplied token with Supabase Auth, including
issuer/project/signature/expiry and current account policy; never decode a JWT and
trust its user field. Missing/expired/invalid identity yields UNAUTHORIZED. The
verified UUID supplies ownership, never a request `user_id`, message role or model
output. Tests exercise injected failures; real Supabase verification is outstanding.
Keep the platform's user JWT verification enabled in the future Edge binding.

`RateLimiter.consume` is mandatory, verified-user scoped and must be atomic/durable
across workers. Failure/denial cannot call a provider. This delivery specifies and
tests that port; it does not provide a deployed distributed limiter. The production
policy and Edge/Postgres adapter are integration work, not an in-memory fallback.

Policy limits: request 32 KiB UTF-8, bearer 8192 characters, complete prepared
context 64 KiB UTF-8 (instruction <=10000 chars, <=100 transcript entries each
<=5000 chars, <=1000 allowed refs), provider JSON 1 MiB. Overall deadline defaults
to 15 s and is configurable only between 1–30000 ms. All ports receive an abort
signal. Adapters must impose network/body read limits before constructing strings,
and abort database transactions/network calls when possible. An ambiguous commit
may have succeeded; retry must consult durable receipts, not redispatch.

The verified request, trusted prepared/recovered context and validated result are
frozen snapshots. Empty/oversized dispatch tokens fail before provider invocation. The provider
receives stable system instructions plus separate request/context data. This is
not a promise that prompt injection is impossible; authority stays outside model
output. No provider receives a bearer token or private app credential in prompts.
Errors expose fixed Vietnamese messages/codes/retry flags, never vendor/SQL details.
No logging of tokens, transcript contents or keys is implemented.

## Conversation receipts and safe uncertainty

Only the three conversation mutations carry client_event_id in frozen v0.1.
Tutor/correction have no such wire key; repeated requests there may invoke another
provider call and require rate limiting. No hidden exactly-once claim is made.

Keys are verified user + operation + event UUID. Compare the entire validated
request structurally; changed fields conflict. A completed request replays its
original validated response before session-active checks (finish retries survive
closure). A new mutation uses ContextRepository to validate ownership, active
scenario/level/content, closed-session rules and reserve server sequence/IDs.
Distinct mutation events for one session must serialize through the real adapter.

Private SQL helpers in migration `20261013185000_ai_receipt_claims.sql` implement
lookup, atomic insert/claim and token-checked completion. New private dispatch
tokens are inaccessible to clients, RLS-enabled and service-role SELECT/INSERT
only. Helpers are invoker functions with empty search_path, qualified names and
no anon/authenticated/PUBLIC execution. Authenticated users can only read their
own existing public receipt rows; no new client mutation grant exists.

A claim is acquired once, must COMMIT before dispatch, and never expires or is
automatically taken over. The native two-session READ COMMITTED test grants one
owner; duplicates see pending and changed input conflicts. Completion locks the
receipt, requires its private token, preserves the original result and belongs
in the SAME transaction as validated conversation message/session changes.
SQL helpers alone check storage shape, not full AI wire schemas. The adapter
must use Contracts/semantic checks; neither SQL fixture JSON nor test memory
storage represents a deployed conversation implementation.

PendingRecovery.lookup inspects an already-correlated upstream result and NEVER
issues a new operation. A missing/unknown lookup leaves the receipt pending;
there is no automatic retry/delete/takeover. A recovered result must pass schema,
server identity/ref checks and trusted repository validation before locked,
correlation-checked reconciliation persists it. Malformed output, provider timeout,
crash after dispatch, validation failure and unknown commit do not permit duplicate
billing under the same event. Provider transport-level retries also must honor the
same idempotency key; otherwise disable automatic retries. Safe uncertainty may
reduce availability until verified recovery exists. Legacy pending receipts without
claim tokens likewise never grant a new dispatch through these helpers.

## Outstanding integration

An additive server-only standard Request adapter now enforces streamed body,
UTF-8/header and overall deadline/client cancellation guards before invoking
this library. See AI_HTTP_BOUNDARY.md. It binds a trusted fixed operation and
preserves mandatory injected Auth/limiter/context/receipt/provider boundaries;
it installs no Edge endpoint or fallback implementations. Optional parent abort
propagation is added to execute; existing callers remain compatible. Node tests
do not establish Deno/hosted compatibility or verified production Auth.

Issue #31 tracks a scoped runtime adapter to bind real verified Auth, distributed limiter,
context/ownership and session serialization, SQL transactions + original receipt
replay, persisted message sequences and upstream result reconciliation. It must
prove two-user isolation and process-restart/crash behavior end to end; do not
label this library or its test fixtures as those integrations. Live AI/provider
selection, credentials/cost approvals, audio retention/contracts, voice UI and real
provider evidence remain #17. #20 covers actual Auth/account sessions.

## Verification

From `backend/ai`: `npm ci --ignore-scripts --no-audit --no-fund`,
`npm run format:check`, `npm run check`, `npm test`.
From root: `python3 backend/ai/generate_types.py`, then format and ensure wire.ts
has no diff. The additive SQL security/claim suite and native claim race run via
`scripts/test_database.sh` on an empty disposable PostgreSQL 17 database. Retain
all existing contract/content/SQL/RLS/Flutter/SRS/Kanji/web/Windows CI gates.
Node tests cover malformed/provider output, auth/rate failures, bounds, immutable
request, server identity/ref binding, duplicate/concurrent claims, pending recovery,
timeout/late output, commit failure and safe errors using explicit test ports.

Primary references reviewed 2026-10-13:
- https://ajv.js.org/json-schema.html (draft-2020-12 class)
- https://ajv.js.org/strict-mode.html (no coercion/removal as a validation shortcut)
- https://supabase.com/docs/guides/functions/auth (user verification stays enabled)
- https://supabase.com/docs/guides/database/functions (invoker/privilege boundaries)

Dependency review: initial Ajv 8.17.1 audit reported GHSA-2g4f-4pwh-qvx6,
a ReDoS advisory when $data is enabled. This boundary does not enable $data;
nonetheless the pinned production dependency is updated to 8.20.0. CI retains
a production-only npm audit at moderate severity. Advisory reference:
https://github.com/advisories/GHSA-2g4f-4pwh-qvx6 . An audit snapshot is not proof
of overall application security; integrated regression work remains #8/#18.

## Opt-in fixed-project Auth port (#31)

`SupabaseAuthVerifier` in `src/supabase_auth.ts` resolves the existing verified
identity port through a fixed trusted Supabase `/auth/v1/user` lookup. The server
validates the access token; the adapter never authorizes from decoded JWT claims
or metadata. Public deployment configuration, redirect/resource/cancellation
rules, safe errors, test evidence and remaining hosted gates are specified in
[AI_SUPABASE_AUTH.md](AI_SUPABASE_AUTH.md). No endpoint/provider/Auth strategy or
application default is configured by this component.

## Private PostgreSQL quota component (#31)

The additive `20261022091000_ai_rate_limits.sql` implements a row-serialized
shared per-user burst/daily budget for all five operations. Private invoker/ACL/
RLS boundaries, confirmed-commit-before-dispatch requirements, clock behavior,
SQL/native concurrency verification and remaining runtime binding are specified
in [AI_POSTGRES_QUOTA.md](AI_POSTGRES_QUOTA.md). The TypeScript RateLimiter port
is still mandatory; the opt-in Node driver binding is documented in
AI_POSTGRES_RUNTIME.md. No endpoint or memory fallback is installed.

## Private read-only text context component (#31)

`20261022111500_ai_text_context.sql` adds service-only profile/active-curriculum
projection and fresh post-provider revalidation for tutor/correction. Fixed bounds,
whole-entry allowlists, strict shapes and SQL-role tests are documented in
[AI_TEXT_CONTEXT.md](AI_TEXT_CONTEXT.md). No runtime ContextRepository/endpoint or
conversation reservation/completion adapter is bound by this SQL component.
