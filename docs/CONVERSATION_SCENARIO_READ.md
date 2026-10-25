# Captured conversation scenario read prerequisite — Issue #17

CapturedConversationScenarios borrows Auth, a fixed read port and the caller's
vault/profile/runtime generation readiness fence. Construction does not dispatch.
Only explicit load(N5/N4) reads; no SDK/global client, cache, route, provider,
scenario data, default activation, subscription, timer retry or mutation is added.
The runtime must revoke on every readiness barrier and drain/close its own port.

The internal public projection is deliberately separate from frozen v0.1 API
operations. The future SDK implementation must select exactly id, jlpt_level,
title_vi, title_ja, description_vi, content_version, is_active from the fixed
conversation_scenarios table, filtered active/exact requested level, ordered by
id and limited to101 (overflow sentinel). The current SQL authenticated grants
already allow these columns; system_context and target joins are not fetched.
No SQL migration/grant/RLS/Auth change. HTTP/JSON size/redirect/credential guards
belong in the concrete captured SDK port, which is NOT implemented here.

Decode the whole response before publication: array0..100, exact seven keys,
UUID IDs unique case-insensitively, N5/N4 exactly matching requested level,
is_active==true, integer positive PostgreSQL content_version<=2147483647.
Nonblank titles max200 Unicode points each; description max2000, with early
UTF16 bounds. These are conservative local read limits, not changed server
schema constraints. Preserve text/UUID spelling and order, copy into immutable
objects/list. Empty is honest; malformed hidden/extra rows fail the entire read.
No HTML/audio/URL action or system prompt exposure. A bounded valid projection
is not proof of catalog authenticity, freshness, provisioning or authorization:
start_conversation still revalidates active scenario, level and owner server-side.

Reserve single-flight before supplied readiness/port code. Guard exact session
identity/readiness before dispatch and before/after decoding. Observed loss,
throwing getters, explicit revoke or safe UNAUTHORIZED permanently fence this
instance, including same-user replacement/A/B/A. Reentrant availability reads
redact without exposing a retained result. Other safe port errors retain their
fixed code; raw failures become fixed INTERNAL_ERROR, never echo payloads.

Timeout in(0,15s] ends the view wait but holds the busy slot until actual I/O AND
the caller have settled. Late success/error is consumed only to drain, never
cached/published or auto-retried. Explicit reload can run after drain/current
checks; this read invokes no AI provider. No cancellation/rollback/hard wire
size guarantee or previously returned snapshot erasure is claimed. Hosts must
discard stale returned lists when their owner generation changes.

Injected-port tests cover immutable/literal projection, exact N4/empty catalog,
bounds/malformed/unknown/private/duplicate rows, local validation/slot release,
single-flight/reentry, timeout with late success/error, same-user/other-user/
logout/readiness/revoke/A/B/A, fixed errors and getter loss. Results and exact-head
CI are recorded in PROJECT_STATUS/PR41. These are component tests, not real SDK,
PostgREST/JWT/RLS/provider/voice/learner acceptance. All14 live gates remain.

Next: concrete caller-owned bounded SDK public-column read, runtime/source
lifecycle wiring and actual HTTP/mounted host tests before trusted selection UI.
Only then compose explicit start/send/finish and retained uncertain-event recovery;
never allow arbitrary learner scenario UUIDs/endpoints/keys as a substitute.
