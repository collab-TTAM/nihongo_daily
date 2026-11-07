# Proposed pending-command payload format — Issue #17

PendingConversationCommandEnvelope is a PURE, unused codec for the payload BEFORE
any future reviewed secure-storage boundary. It has no backend, channel, file,
writer, lifecycle, network, runtime binding or default. encode() returns sensitive
PLAINTEXT JSON; this is NOT encryption or a plaintext storage fallback. No existing
retainedCommand getter is serialized by this increment. Its memory-only/no-persist
contract remains unchanged. No learner retention/collection policy is activated.

## Local format proposal

Version1 has exactly version, reference and request. Reference uses the existing
five-scalar receipt reference v1; request uses strict original typed Start/Turn/
Finish DTO, selected only by reference.operation. Factory captures all original
fields, including level/scenario/session, event spelling and Japanese code points/
whitespace. Require EXACT reference/request event spelling. Decode requires the
trusted expected project/owner scope BEFORE returning a payload. Scope matching
normalizes only existing origin/account aliases, not original command text/event.
Local scope is not verified Auth, an authenticated origin or upstream provenance.

Bound complete encoded UTF-8 JSON to32KiB with early UTF-16 length rejection before
JSON parse. At most one original command, no token, response, credential, transcript
history, retry flag, dispatch claim or derived result. All keys/types/UUIDs/levels/
text limits use existing strict DTO/reference validation. Canonical re-encoding
must match input bytes, so duplicate members, key reordering, whitespace/escape
aliases and unknown/missing fields are rejected. Safe failures have a fixed
FormatException without payload/source/offset; string display reveals only type.
The immutable model retains no raw decoded map; exported DTO maps are fresh.

This format is independent of frozen API and existing receipt-store encoding.
It does not change those schemas or add a field to their native storage target.
A full turn exceeds the existing reference format's1KiB metadata limit; do not
send this payload to the metadata or refresh-token namespace or loosen native
limits. No OS backend is supplied and native encryption/capacity is NOT proved.

## Required before actual persistence or restored recovery

A separately reviewed design must define platform-specific protection/key ownership,
bounded encrypted/authenticated storage and exclusive ownership, loss/corruption/
rollback/partial-write behavior, atomic command/reference write-before-send and
captured Auth/profile/generation guards. Define user-visible retention/logout/
backup/deletion behavior; preserve docs/AUTOMATION.md human approval gates for any
broader collection, production deletion or security reduction. No new lifetime or
expiry/eviction/automatic pending-discard policy is inferred here. Missing keys or
secure OS support must fail closed without a plaintext/file fallback.

No schema validation, local tuple or decoded DTO establishes authenticated receipt
association, provider result provenance, current transcript phase or server release.
Restored bytes must not create a new event or obtain dispatch/retry/replay/clear/
result-application authority. Current one-pending guard and memory-only learner
recovery remain. Hosted RLS and verified conditional release still need proof.

## Validation

Ten new pure cases cover three canonical commands, original Unicode/whitespace/
UUID casing, maximal5000 escaped/multibyte codepoints, expected-scope aliases and
foreign partition rejection, exact schema/version, operation/event mismatch,
strict nested fields, duplicate/canonical aliases, oversized safe failures and
immutable outputs. Existing request/reference tests remain unchanged. Local results,
source commit and new exact-head CI are recorded in PROJECT_STATUS and PR41.

Fresh parent b2db5f2009b36a1530b127b71535e9891ec7d59f CI40400812089/latestattempt1
passed all5 jobs/EVERY step/no skips. Flutter121846625907 confirms owned retained
command lookup UNKNOWN/PENDING/COMPLETED cases; Windows121845926431 all3 OWNED
runtime/lookup/original-read markers. Those are TEST ONLY Auth/HTTP components,
not hosted learner proof. New full Flutter/native/build CI remains required.
Keep PR41 draft/17open/defaultAIoff/all14 hosted groups pending; Pro unaffected.


Observed local: fresh officialDart3.9.2 SHA256 verified. Fresh seven-file actual
pure source/test graph ONLY flutter_test->test1.26.2/exact fixtures:27/27 PASS
(10new+17retained reference/request), no skips; strict casts/inference/raw+lints6
analysis No issues. Format2/46QA/inventory146/whitespace/separate bounded-schema/
canonical identity/partition/immutability/no-storage/no-authority review PASS.
All145priorQA/findings/gates exact; source and fixture parity verified. Full new
Flutter/native/build unrun locally/no bootstrap retry/bypass. This is NOT secure
persistence/OS crypto/hosted/release proof; codec unused and encoding sensitive
plaintext. All14 hosted groups pending. Published head/CI/next action in PR41.
