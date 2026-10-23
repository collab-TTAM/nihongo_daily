# Reading material domain — Issue #34

This increment is a pure local model/importer and deterministic comprehension
round. It installs no route, repository, default lesson, audio or study-session
writer. Frozen v0.1 APIs/database models and seven Daily Plan blocks are unchanged.
No canonical N5/N4 asset, content manifest or Pro-owned content/test is modified.
Fixtures in the new domain test are TEST ONLY and are not reviewed curriculum.

## Local import format v1

`decodeReadingMaterial(source, level)` accepts exactly `schema_version: 1` and
`passages`. The encoded UTF-8 source is at most 262144 bytes, checked before JSON
decoding; the catalog holds zero to 50 passages. The entire catalog is validated
before filtering by the existing N5/N4 PreviewLevel. Invalid hidden-level content,
duplicate passage IDs, unknown/missing fields and non-integer versions fail closed.
Errors expose only the fixed `Invalid reading material`, never raw JSON excerpts.

Each passage has exactly these fields:

| Field | Rule |
| --- | --- |
| id | Stable lowercase ASCII identifier, 1–64 characters: letters/digits/underscore/hyphen; first is letter/digit |
| jlpt_level | Exact N5 or N4 |
| content_version | Integer 1–2147483647 |
| title_ja, title_vi | Required nonblank strings, at most 256 UTF-16 code units |
| text_ja, reading_ja, translation_vi | Required nonblank strings, at most 8192 code units each; paragraph breaks retained |
| source_note_vi | Required nonblank attribution note, at most 1024 code units |
| questions | 1–10 questions, unique IDs within passage |

Each question has exactly id, prompt_ja, reading_ja, prompt_vi, choices,
correct_choice_id and explanation_vi. IDs follow the same identifier rule;
prompts/readings are required nonblank strings up to512 code units, explanations
up to2048. Choices number2–4, each exactly id/text_ja/reading_ja/text_vi; all text
up to512 code units. Choice IDs and trimmed Japanese labels must be unique within
the question. The answer key must reference an actual choice. Unsupported control
characters are rejected; ordinary tabs/newlines are preserved. All collections
returned by the parser are copied and unmodifiable, with private model constructors.

`source_note_vi` is attribution metadata, not proof of licensing, source authenticity
or linguistic review. This local format is neither a hosted API nor an approved
curriculum distribution format. Reviewed original/licensed material must be supplied
and verified separately with #26/#14 coordination. Import validation cannot certify
that a Japanese reading or Vietnamese translation is correct.

## Local answer semantics

A passage snapshot key is level/id/content_version. ReadingRound accepts the first
valid choice for each question only when supplied with that exact snapshot key.
Foreign question/choice, duplicate answer and callbacks carrying another passage,
level or version return false without mutation. Questions may be answered in any
order. Completion requires an answer for every question; correctCount compares
accepted choices against this immutable snapshot only. Answers are unmodifiable.
A new round starts empty; no persistence or replay authority is implied.

This score does not authorize minutes, mastery, progress, SRS or server writes.
Answer keys are local study aids, not protected assessment credentials. Content
changes must increment content_version; identical identity/version is assumed to
refer to the same reviewed snapshot. The future trusted repository must enforce
that mapping; this model cannot authenticate a content source.

## Verification and remaining work

Eleven new domain cases cover level/version/readings/translation/order, empty
catalog/filter, maximum collection counts, immutable copies, bounded safe errors,
malformed hidden-level material, duplicate/invalid IDs/answers/labels/fields,
first-answer behavior, stale callbacks, restart reset and mixed deterministic score.

Full Flutter formatting/analyze/tests/build must run at the new exact head.
Local pure Dart harness evidence, if available, uses identical production/model/test
bodies with only flutter_test imported as package:test in disposable scratch; it
is not Flutter widget/platform or learner evidence. There is no new dependency or
lock change in the repository. Actual local results and CI are recorded in the PR
checkpoint and PROJECT_STATUS; previous Edge success is not new Dart test evidence.

Next: trusted bounded content repository/version mapping and explicit loading,
error/empty/offline reading UI; then captured-session valid study reports and durable
retry/restart deduplication. No audio reference is accepted by this text-only format.
Listening playback/source/license/availability needs a separate reviewed adapter;
absent/broken audio cannot complete listening. No permission/capture/retention/spend
change is made. #34 remains open and all14 Personal Alpha release gates remain pending.

Observed local verification: official Dart3.9.2 SDK archive checked against the
official SHA256, both new repository Dart files formatted. Identical model/level
files and all11 test bodies copied into a disposable pure-Dart harness; only
flutter_test import changed to package:test1.26.2. Strict casts/inference/raw-types
plus recommended lints analyze with no issues; all11 cases passed. This is pure
Dart logic evidence, not the actual Flutter runner/widget/platform build. SDK/test
harness dependencies live outside the repository and do not alter its lockfile.
QA46 cases/inventory73 passed, all14 release cases still pending. Full new-head
Flutter validation remains pending CI.
