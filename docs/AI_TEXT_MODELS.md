# Dart AI text contract models — Issue #17

The pure library features/ai/domain/ai_text_models.dart supplies the first app
boundary for the existing frozen text operations. API_CONTRACTS explicitly permits
text adapters before live provider configuration. No backend contract, Auth
strategy, provider, transport, persistence, route or default service is installed.
The existing /ai and /conversation previews remain unconfigured.

| Frozen definition | Dart model | Boundary |
| --- | --- | --- |
| tutor_explain_request | TutorExplainRequest | Typed input and exact toJson |
| tutor_explain_response | TutorExplanation | Strict fromJson and fresh toJson |
| correct_sentence_request | CorrectSentenceRequest | Typed input and exact toJson |
| correct_sentence_response | SentenceCorrection | Strict fromJson and fresh toJson |

## Reviewed mapping and limits

Fields and bounds were read directly from contracts/v0.1/models.schema.json,
contract.json and the original fixtures before implementation. Requests accept
no owner, role, credential, URL, operation name or extra metadata. They serialize
only the named frozen fields, with an explicit context containing both UUID lists
for tutor requests. Context is never inferred from learner history by this library.

AiTextLevel represents all five frozen API values N5/N4/N3/N2/N1. It does not add
levels/content to the preview UI or alter the Personal Alpha N5/N4 selection.
The three item-reference types remain VOCABULARY/KANJI/GRAMMAR.

Question/sentence requests and corrected/natural sentences allow1..5000 Unicode
code points; tutor answer1..10000; each example, practice and correction text
field1..2000. Bound UTF-16 size before counting runes. Preserve exact spelling,
whitespace, combining characters and line breaks; no trimming, truncation,
normalization or invented text. Empty strings fail; a whitespace string follows
the frozen minLength rule rather than adding a new semantic contract.

Every array allows0..100 entries. Both request context lists independently require
unique exact UUID strings. The36-character hex/hyphen UUID shape accepts uppercase
and nil and retains case. Correction references have no uniqueItems rule;
preserve their order and duplicates. A valid reference shape is not evidence that
the item exists, matches the selected level or is currently published. Existing
trusted backend context validation remains required.

Response objects require exactly their named keys, including every nested example,
practice, correction and reference. Reject unknown/missing fields, scalar/list/map
type substitutions, nulls, invalid enums/IDs and oversized text/arrays before
returning a model. A server error object or mixed success/error cannot become a
successful tutor/correction result. Empty correction arrays are valid and remain
empty; they do not manufacture an error, feedback or mastery conclusion.

Input arrays are copied and frozen; all nested objects have final fields/private
constructors. toJson creates fresh maps/lists, so neither later input mutation nor
exported-wire mutation can change the retained model. Parsing failure uses one
constant FormatException with no input source or raw payload echo. There is no
request/response logging or storage. Successful text remains untrusted provider
content, not executable instructions or authorization for a learning write.

## Verification and scope

Seventeen pure tests read original frozen fixtures unchanged: both exact request
encodings and response round trips, allfive levels, copied/frozen unique contexts,
UUID case/nil behavior, Unicode/exact text/length boundaries, missing/unknown/mixed
errors, every nested text/type/key, all array boundaries, all reference kinds,
duplicate/empty references, deep copy/fresh exports and redacted parse failures.
TEST ONLY mutated strings/IDs are not new curriculum content.

Fresh official Dart3.9.2 archive and freshly retrieved SHA256 matched. A fresh
two-file source/test graph and original fixture bytes were copied identically to
a disposable harness; only flutter_test import changed to package:test1.26.2.
Strict casts/inference/raw types plus lints6.0.0 analysis found no issues;17/17
tests passed. Initial new-test lint diagnostics were fixed without removing
assertions. Pinned formatting passed. This is pure Dart execution, not a full
Flutter/router/SDK or hosted AI test. Full exact-head Actions remain required.

Parentf4f822a CI39976858658/latest attempt1 passed allfive jobs/every required
step,777 Flutter/five Chrome and the extended focused native-file correction/
restart/A-B-A journey. This verifies the previous quiz component only, not these
new models or live learner acceptance. QA and current-head CI details are recorded
in PROJECT_STATUS/PR41/Issue17; all14 hosted release groups remain pending.

The models consume already-decoded objects. They are not a raw byte/JSON decoder,
stream/body limit, duplicate JSON-key detector, deadline, cancellation, identity
check or retry coordinator. No network/authenticated gateway is provided yet.
No backend error message is selected for display; a later repository must decode
the frozen error shape into fixed safe Vietnamese failures.

Next add a separately reviewed, caller-owned captured-ready-session text gateway
and repository, with checks around every await, bounded transport/timeout and
late-response tests before the actual tutor/correction UI. No mutable global
current-user client or learner-supplied endpoint/key. Tutor/correction have no
client_event_id in v0.1; repeating them can call a provider again, so no automatic
retry or conversation-receipt guarantee may be inferred. Live provider choice,
hosted Auth/Edge proof, voice/retention/spend approvals and actual learner acceptance
remain separate gates. No Personal Alpha, sync, mastery or study-credit claim.

## Verified models and captured repository increment

At1fb3611563b752e0b44acdba48025a017aa6ab47, CI39986349215 latest attempt1
completed allfive jobs/every required step successfully:794 Flutter/five Chrome,
including all17 model tests, Web/Windows and retained native/SQL/Edge gates.
The model increment now has actual Flutter/component evidence; no hosted AI claim.

AI_TEXT_REPOSITORY.md specifies the new borrowed captured-ready-session text
repository, safe failures, immutable dispatch and one-request/timeout/late-result
guards. It is not yet a concrete authenticated network adapter or owned UI/runtime
activation. Its22 authored lifecycle tests require new exact-head Actions.
