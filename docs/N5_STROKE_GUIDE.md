# Optional original N5/N4 stroke guides — Issue #16

Selected practice offers **Xem nét mẫu** for the eight original N5 seed characters
(日/月/木/山/川/人/水) and95 original N4 records. These are the existing catalog's
records, not a claim of complete JLPT coverage. Loading remains explicit.
Nét trước/Nét tiếp show ordered prefixes; Xem toàn bộ shows all strokes. Current
stroke highlight, numbered start dots and endpoint arrows display order/direction.
The independent blank canvas retains draw/undo/clear. Guide controls never create
learner strokes, a score, progress or study credit.

## Source, license and reproducibility

103 unchanged nonvariant SVGs under third_party/kanjivg/n5_source (8) and n4_source
(95) come from KanjiVG70a0b7ae0c18ceb5cb358274b029cce0234a43bc. Original source
copyright/license notices and upstream COPYING are preserved byte-for-byte.
NOTICE.md identifies Ulrich Apel and KanjiVG contributors, project/source/license
URLs and geometry adaptations. Generated n5.json/n4.json adaptations are CC BY-SA
3.0; source/license/change attribution remains visible beside the guide in app.
No endorsement or unrelated application-code relicensing is claimed.
Source: https://github.com/KanjiVG/kanjivg
License: https://creativecommons.org/licenses/by-sa/3.0/

Reproduce both levels without downloads, provider keys or SDK:

    python3 scripts/import_kanji_references.py --check
    python3 -m unittest discover -s qa -p 'test_*.py' -v

Use --level n5 or --level n4 for an explicit single level. Omit --check only to
regenerate reviewed output. Closed configuration fixes each manifest/source/
metadata/output path, version and exact coverage (8/95). Separate n5_manifest.json
and n4_manifest.json lock source commit, license digest, canonical metadata SHA256,
original ID/glyph/content-version/count and each SVG SHA256. Names must be the
expected Unicode codepoint. Source/metadata/version/coverage/path drift rejects;
no automatic upstream update, guessed source or N5 fallback for N4. Original N5
output/manifest/license and both canonical metadata exports remain byte-identical.
Checkout attributes preserve raw source/metadata/generated digest bytes; text
output uses explicit UTF-8/LF. COPYING retains its original blank EOF line.

## Geometry and display boundary

Validate109-by109 viewBox, root glyph identity, absence of transforms, consecutive
ordered path IDs and canonical stroke count. Only the pinned sources' initial M
and cubic C/c/S/s commands are accepted, including repeated/relative/smooth curves.
Reject unsupported/truncated/nonfinite/outside/degenerate paths. De Casteljau
flattening uses0.15-source-pixel tolerance, depth12 and4096-point bounds; normalize
by109, round to eight decimals, deduplicate adjacent points. No fitting, clipping,
translation, reordering, reversal or invented timing. N4 has977 ordered strokes/
7782 normalized points. Display geometry is separate from frozen learner attempt
contracts and the synthetic scorer.

Flutter requires the expected level's exact version, coverage and provenance,
then immutable bounded finite [0,1] geometry. Repository chooses only that level's
fixed asset. Guide model and panel require matching level/ID/glyph/content-version/
count, including results from an injected repository. Missing/error/manual retry,
hidden/late selection fencing, narrow layouts and awaited owned exit are retained.
Canonical stroke_data_ref/server availability remains unchanged. No real evaluator
is installed: evaluateReal still reports unavailable; no attempt storage or grade.

## Optional tracing in the capture canvas

After explicitly showing a valid guide, **Hiện nét mẫu trong ô viết** enables a
faint prefix under learner ink. Current reference stroke/start are emphasized;
previous/next/full controls select the same original prefix in both views. No
fitting, scaling to handwriting bounds, reference-to-capture conversion or
recognition is performed. KanjiGuideTrace validates the index and exposes only
immutable original geometry. KanjiTracePainter clips normalized coordinates to
the square, paints a transparent background, then the unchanged capture painter
paints learner ink above it. It never calls the capture controller.

Default/free practice has no underlay or implicit load. Toggle off or hide the
guide removes tracing without clearing ink. Undo/clear affect only learner ink.
Entry/level/version/source replacement disposes local trace state; guide refresh,
loading/error/null/foreign result revokes it even if a refresh returns the same
instance. Re-enabling is explicit. Expanded guide attribution remains present
while tracing. Awaited owned exit retains the same hidden tracing/EditableText
widgets, with input blocked by the existing host; no owner or shutdown change.
No trace or learner stroke is saved, credited or sent to an endpoint.

## Observed checks and remaining work

Parent4497cba CI39415591962 completed allfive jobs/every step:581 Flutter/five
actual Chrome tests plus retained SQL/SDK/native/process/Web/Windows builds and
artifacts. All24 N5/N4 guide cases passed, including actual95 N4 mappings and
both-level expanded-attribution owned exit. These are parent results, not new
trace-widget execution. Previous Windows marker publication fix remains verified.

Local checks passed:29 Python QA, inventory49, both-level deterministic --check,
pinned format/pure-domain analyze and direct Dart smoke over all103 original
guides/1005 ordered prefix boundaries. Prefixes retain identical immutable source
stroke lists, invalid indices reject and the independent learner capture remains
unchanged. No source/manifest/geometry/metadata/license/dependency change. Prior
four-sheet visual review of all95 original N4 glyphs remains engineering review,
not independent teacher/native-speaker handwriting-quality or scoring calibration.

Six new guide cases are authored (30 total): all103 immutable prefix/bounds checks;
N5/N4 explicit tracing and learner-ink independence through step/toggle/undo/clear/
hide; N5/N4 refresh revocation even for an identical returned guide; route/level/
free-practice isolation. Retained both-level320px/200-percent and actual bundled
owned-exit cases now additionally enable/assert tracing while preserving every
prior assertion. Full new Flutter/widget/render/platform execution requires
exact-head Actions. The prior local Flutter metadata automatic-review rejection
is not retried/bypassed; no full local Flutter pass is claimed.

Keep #41 draft/#16 open/default preview/all14 hosted acceptance groups pending.
No real recognition/grading/mastery/attention or saved Kanji progress claim.
Independent pedagogical quality, reviewed real evaluation and wider curriculum
remain open. No Auth strategy/storage/schema/RLS/dependency/CI/security/provider/
spend/merge/deployment/release/schedule change.


## Tracing refresh fixture and narrow control correction

Integration ecac51d CI39421796252 passed format/analyze;583 Flutter tests passed
and four failed. Both-level ink/control/route and actual expanded trace/attribution
owned exits passed. Failures were both-level first-frame refresh expectations and
both320px/200-percent trace-toggle hit targets. Downstream Flutter/Chrome/Web
steps were skipped, never passed. Repo/database/AI passed; Windows bridge/actual
exit passed and configured build was running when diagnosed.

The refresh fixture invalidated without reading and assumed recomputation by one
pump. Riverpod2.6.1 defers invalidate; refresh explicitly recomputes and returns
state. The fixture now refreshes and asserts loading plus exactly the second
loader call before checking the rendered frame. All previous assertions remain:
no underlay while loading, learner ink retained, identical resolved guide cannot
re-enable tracing, false toggle state and later explicit re-enable. This is an
inferred test-scheduling correction, not a claim of observed product refresh
failure or corrected full execution. Production trace lifecycle code is unchanged.
API references:
https://pub.dev/documentation/riverpod/2.6.1/riverpod/Ref/invalidate.html
https://pub.dev/documentation/riverpod/2.6.1/riverpod/Ref/refresh.html

The long adaptive SwitchListTile is replaced by a full-width outlined toggle
button with a separate explanation. Toggled semantics expose on/off state and
visible labels distinguish showing/hiding. This reduces the action target's
height at large text. Existing strict ensure-visible/hit-test assertions,320px/
200-percent dimensions, both squares, steps, capture/undo/clear and all30 guide
cases remain. Tests assert toggled semantics rather than the old widget type,
including enabled and disabled states. No ignored taps/loose finder/scale reduction.

Local pinned format2/0changes, QA29/inventory49, whitespace and separate bounded
source/assertion review passed. Corrected actual Flutter/render/platform behavior
requires exact-head Actions. No prior local metadata automatic-review rejection
retry/bypass or local full Flutter pass. Keep draft/#16 open/all14 hosted groups
pending; source geometry/capture controller/Auth/SDK/storage/dependencies/gates/
schema/RLS/main/source/Pro/merge/deployment/provider/spend/schedule unchanged.
