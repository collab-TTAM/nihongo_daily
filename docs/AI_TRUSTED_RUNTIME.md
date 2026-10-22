# Explicit trusted AI server assembly (#31)

`backend/ai/src/trusted_runtime.ts` composes the existing verified Supabase Auth,
distributed PostgreSQL quota, text context and atomic conversation adapters with
AiService and all five fixed-operation HTTP handlers. It creates no listener,
Supabase function, default app binding, live provider or automatic success.

## Host configuration and ownership

`createTrustedPostgresAiHandlers(contracts, configuration, provider, recovery?)`
requires the host's original Contracts instance, trusted HTTPS project origin,
public configuration key and server database URL, plus an explicit provider.
The existing configuration validators reject private keys, URL query/fragment/
credential tricks and PostgreSQL TLS overrides. Every database lane uses
createOwnedPostgresFactory with certificate verification required and its existing
fixed application name. The constructor opens no connection and performs no Auth
or provider request. Configuration failure returns a fixed error without details.
Never pass learner JSON, URL/key input or a model-selected provider to this API.

The returned frozen record has exactly the five original operation names. The
host chooses a handler explicitly; request query/body cannot change its operation.
The original bounded HTTP/deadline/safe-error behavior is retained. No environment
lookup, CORS policy, public routing, service key, deployment or provider decision is
added. Existing human gates continue to apply before live/production enablement.

`assemblePostgresAiHandlers` is the lower-level trusted host composition seam.
It requires explicit Auth/provider ports and three exclusively owned connection
factories. It captures method functions, receivers and factory references before
any asynchronous request; replacing host properties later cannot rebind the service.
Caller-owned provider/lookup/factory internals are not cloned or frozen, so the caller still
owns their configuration/resource lifetime and must keep them safe. This module
never closes those resources or starts/refreshes an SDK session on their behalf.
Injected test/plaintext factories are test bindings; the trusted configuration API
has no plaintext/TLS-off option. Do not use a shared or pooled transaction client.

## Transaction and recovery invariants

Every request re-verifies its caller through Auth; no account/identity cache.
Quota COMMIT must be confirmed before text/conversation work. Text prepare is a
short read transaction, followed by provider I/O with no open transaction, then
result revalidation COMMIT before HTTP success. Conversation lookup/reserve/complete
uses the coherent existing store; acquire COMMIT precedes dispatch, completion
COMMIT precedes success, and each owned connection closes on success/error/abort.

The legacy receipt port is an immutable fail-closed sentinel. With coherent store
installed, no operation can silently fall back to a memory store, split claim or
legacy recovery. Optional recovery is bound to the exact internally constructed
conversation store and a captured authenticated lookup method. No new lookup
adapter is invented; authenticated upstream provenance is still the host's duty.
Pending without that explicit binding remains unavailable and never reissues a call.
No claim renewal/reset, deletion, refund or duplicate dispatch is introduced.

## Verification and limits

Twelve new Node/Deno protocol cases cover all five operations using the actual
SupabaseAuthVerifier with TEST ONLY Auth HTTP, actual PostgreSQL drivers with
TEST ONLY transaction replies, and a TEST ONLY provider. They verify owner/operation
SQL parameters, connection counts/close, confirmed COMMIT/no transaction during
provider I/O, immutable handler names, no constructor I/O, invalid trusted config,
Auth/quota/uncertain-COMMIT failures, method/receiver/factory capture, A/B/A identity,
same-store correlated recovery without acquisition/dispatch, disabled pending and
cancellation during quota COMMIT with ignored late delivery. Turn reserves
assistant sequence2 according to the existing atomic driver; wire models unchanged.
All168 prior unit cases remain unchanged (180 total); CI's existing Node/Deno glob
runs the new cases. Native PostgreSQL/Deno42 and the retained Edge probe remain
separate mandatory checks, not proof of a fully assembled production Edge service.

Parent source15896c53573e205c016c790c42aa0e4427c74262 has observed allfive jobs/every
step success in [CI39856656219](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39856656219),
latest attempt1. Its actual completed AI log proves allseven Supabase v1.77.4
main-to-user-worker HTTP groups passed; published fixture metadata artifact
[12459851532](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39856656219/artifacts/12459851532)
has zip digest3a9d7bb1736db5ebd029770e5ce5b5368980d6967c251dc4f120f2f0d10c174a.
Image registry digest ad45164b7548bf5820ed7be714789c17ac2865edce79a09cfb4c3756c3d365a8;
bundle749ba4a178e2d0d9a3dfeecbfe3536fa2db2fe6281559f29f6b6e17933c57759.
The V8/TypeScript values are bootstrap-reported metadata, not engine measurement.

That parent probe uses memory fixture ports, not this new full assembly and real
PostgreSQL inside an Edge isolate. New exact-head CI is required. The composition
still needs native assembled transport/Edge/TLS/CA/PostgREST/real Supabase identity,
approved live provider/authenticated lookup provenance and learner acceptance.
No hosted JWT signature/expiry/A-B or Personal Alpha proof is implied by protocol
fixtures, a frozen handler table or a local official container. All14 hosted release
groups remain pending; #31 stays open/#41 draft/defaults unconfigured.
