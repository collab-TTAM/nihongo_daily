# Original Kanji catalog and selected-character practice

The existing /kanji free canvas now offers **Chọn chữ N5/N4**. The catalog at
/kanji/characters reads the unchanged original metadata exports: 8 N5 and95 N4
characters. Select a character to display its glyph, Vietnamese meaning, On/Kun
readings, metadata stroke count and optional radical, then draw with the existing
mouse/touch/stylus canvas. Empty readings/radical are explicit. Undo/clear remain.
Metadata counts describe the export; they never assess the user's stroke count.

## Public reads and identities

KanjiCatalogEntry keeps original ID, level and positive content version plus
immutable readings. Two packaged assets exactly match canonical data/n5/kanji.json
and data/n4/kanji.json bytes. No authored content or Pro #38 source changes. A
fixed typed level chooses a fixed asset path, never an ID path or fallback level.
Strict bounded list/UUID/duplicate/version/active/character/readings/count/text/
nullable-reference checks precede publication. Inactive/other-level records are
filtered after validation. Canonical contract/content validation remains separate.
A reference string is presence metadata only; it is never fetched or graded.

Local search matches glyph/readings/Vietnamese meaning, ignoring Vietnamese case
and diacritics including combining accents. Queries are bounded to128 characters,
not sent or saved, and return immutable original-order results. Empty export,
no matches, loading and safe redacted error/explicit retry have distinct states.
Changing the catalog level clears the search. Selection is public/process-local
and never changes authenticated profile or SRS level or dispatches plan/learning
writes. Full JLPT coverage and independent linguistic review remain outstanding.

## Practice and lifecycle

/kanji/practice/:level/:id resolves the original character only at its explicit
N5/N4 level. Unsupported levels/unknown IDs/wrong-level IDs never fall back to
another character. Loading/refresh/error removes the practice canvas; retry is
explicit. The original /kanji route remains an independent unselected free canvas.

A keyed local ProviderScope isolates the existing capture controller by level,
canonical ID and content version. Previous free/selected strokes do not enter a
new character. Route/identity/version replacement or source reload discards local
strokes. Nothing is uploaded, journaled, timed, credited or restored after exit.
The selected screen returns to the catalog at the same level. All Kanji subroutes
keep the Kanji navigation destination. Search EditableText remains mounted and
unfocusable beneath the existing owned host's awaited exit blocker; no new Auth,
SDK/store owner or close path is introduced.

This is practice from displayed metadata, not tracing/stroke animation/recognized
handwriting or mastery. The UI retains explicit unavailable real grading. #16
still owns vetted/licensed geometry, reproducible import/versioning/coverage and
real evaluation. No stroke asset, synthetic production grade or attention/progress
claim is added; server KANJI availability and study recorder area support unchanged.

## Verification and remaining gates

Parent613024bf CI39393662381 verified every step/allfive jobs successful with523
Flutter tests/five actual Chrome tests, native/SQL/SDK/process/Web/Windows and all17
reader timer cases. This is parent evidence, not execution of the new Kanji tests.

Eighteen repository/codec cases authored for both actual bundled exports and every
original display field, fixed-path failure/no fallback, active/level filtering,
immutable lists,11 invalid-field cases, duplicate/list/size/missing bounds, literal
Japanese/diacritic-insensitive Vietnamese search and nonloaded reference metadata.
Twelve widget cases authored: both original levels/from free to isolated selected
capture/return/change character, search/clear/level, loading/redaction/retry/empty,
late old-level completion, four invalid/wrong-level routes,320px/200-percent draw/
undo/clear, direct identity/held-source refresh reset and actual bundled catalog
owned-host exit with retained search listener. Existing capture/widget/domain/
reader/SRS/owned tests unchanged; normal visible taps and original exports used.
TEST ONLY fixtures do not prove hosted Auth/learner or actual OS shutdown.

Local pinned Dart formatting/pure-domain analysis, exact original-record/asset
smoke, malformed/bounded/duplicate/search/immutability smoke, QA inventory49/all17
regressions, whitespace and separate diff review passed. Full new Flutter/widget/
SDK/platform results require exact-head CI. Prior local Flutter metadata-endpoint
automatic-review rejection remains; no retry/bypass. No new-source full Flutter,
real grading or hosted learner result is claimed. Keep #41 draft/#16 open/all14
hosted gates pending; no merge/deployment/Auth strategy/dependency/schema/RLS/CI/
security/provider/spend/schedule change.


## Malformed-fixture type correction — 2026-10-20

Exact ba7b06f CI39408920908 repo-sanity/database/AI succeeded. Flutter format
passed; analyze stopped on the empty malformed-object literal at repository test
line123 (inference_failure_on_collection_literal). Full Flutter tests, Chrome and
downstream Web steps were skipped, never passing. Windows remained running at
review after configured staging build success. No production error was observed.

The fixture now spells its empty map as Map<String,Object?>. Encoded JSON remains
exactly [{}], so the strict malformed/missing-field rejection and all30 new cases/
original assertions remain unchanged. No production/lint/CI/security change.
Pinned local format, pure-domain analysis, QA17/inventory49, whitespace and
separate one-line source diff review passed. Corrected full Flutter/widget/build
execution requires new exact-head Actions; prior local Flutter metadata automatic
review rejection is not retried/bypassed. Keep #41 draft/#16 open/all14 hosted
gates pending and inspect complete latest-attempt CI before further development.


## Search result finder correction — 2026-10-20

Exact a041fc9 CI39409601599 Flutter format/analyze passed; full suite reported
552 passed/one failed. All18 Kanji repository and11 other new Kanji widget cases
passed, including both selected levels, source/identity isolation,320px/200-percent
capture and actual bundled owned exit. Database/repo/AI passed; Windows still
running at review. Downstream Flutter/browser/Web skipped, not successful.

The search test's global find.text(日) also matched the active search EditableText
when the query itself was 日. The correct result already existed alongside the
input. Scope the glyph assertion to its original-ID keyed ListTile, additionally
require exactly one such tile and preserve the exact entered query. Keep the
one-result count, all query variants, clear/level behavior and all30 cases. No
production/finder warning suppression or weaker findsWidgets expectation.

Local pinned format/QA17/inventory49/whitespace and separate exact diff review
passed. Full corrected widget/platform results need new exact-head Actions.
Prior local Flutter metadata automatic-review rejection remains, no retry/bypass.
Next inspect complete same-head/latest-attempt CI before new implementation;
pending-only means release/handoff, no duplicate work/long polling. All14 hosted
gates remain pending, #16 open/#41 draft.
