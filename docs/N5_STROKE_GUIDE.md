# Optional original-seed N5 stroke guide — Issue #16

Selected practice offers **Xem nét mẫu** for the eight original N5 seed characters:
日/月/木/山/川/人/水/火. It loads only after the learner clicks. Nét trước/Nét tiếp
show original ordered prefixes; Xem toàn bộ shows all strokes. The current stroke
is highlighted, starts have dots/numbers and endpoint arrows show final direction.
A separate existing blank canvas keeps normal draw/undo/clear behavior. Showing,
hiding or stepping the guide never creates learner strokes, score or progress.

N4 explicitly has no guide in this increment. Missing/incompatible N5 identity,
version, glyph or count cannot substitute a foreign reference. Loading/error is
safe and retry explicit. Late results cannot enter another character; hidden
unobserved guides cannot publish into the next selection. No new SDK, token,
store, recorder, wire endpoint, dependencies or canonical metadata mutation.

## Attribution and source reproducibility

Eight unchanged nonvariant SVGs are retained under third_party/kanjivg/n5_source,
from KanjiVG commit70a0b7ae0c18ceb5cb358274b029cce0234a43bc. Their copyright/license
notices and upstream COPYING are preserved. NOTICE.md identifies Ulrich Apel and
KanjiVG contributors, source/project URLs, CC BY-SA 3.0 and the normalization
changes. The generated guide is an adaptation distributed under CC BY-SA 3.0;
license/source/modification notice is also displayed beside the guide in the app.
Source: https://github.com/KanjiVG/kanjivg
License: https://creativecommons.org/licenses/by-sa/3.0/
No third-party endorsement or unrelated application-code relicensing is claimed.

Reproduce from repo root without downloads/SDK:

    python3 scripts/import_kanji_references.py --check
    python3 -m unittest discover -s qa -p 'test_*.py' -v

Regenerate reviewed output by omitting --check. The committed manifest locks the
source commit/version, exact canonical N5 metadata digest, original ID/glyph/
content-version/count mapping and each raw SVG SHA256. Source file names must be
the expected Unicode codepoint only. Source hash/metadata drift rejects before
XML/geometry publication. No network XML source or automatic upstream update.
Changing coverage/source requires a separately reviewed version/manifest update.

## Geometry and display projection

Validate original109-by109 viewBox, KanjiVG root glyph identity, transform absence,
consecutive ordered path IDs and metadata stroke count. Only the pinned subset's
initial M and cubic C/c/S/s commands are accepted, including implicit repeated
segments, relative offsets and reflected smooth controls. Unsupported commands,
truncation/nonfinite/outside/degenerate strokes fail; nothing is guessed/clamped.
De Casteljau subdivision stops at0.15 source-pixel control-to-chord-segment error,
with depth12 and4096-point bounds. Divide coordinates by109 and round to eight
decimals; deduplicate adjacent points only. No glyph fitting, translation, stroke
reordering/direction reversal or invented timing. This guide format is separate
from frozen learner attempt contracts and the synthetic scoring primitive.

The Flutter decoder checks provenance/version/license, bounded immutable original
identity/glyph/version/source-file/hash/count/stroke/point/finite [0,1] projections.
The repository uses one fixed asset path and matches canonical ID/glyph/content
version/count; N4 causes no asset read. Raw canonical stroke_data_ref stays null.

## Observed verification and limits

Parentcf00d081 CI39410222982 verified allfive jobs/every step,553 Flutter/five
Chrome plus SDK/native/process/SQL/Web/Windows and all30 Kanji catalog cases.
These are parent results, not execution of the new guide widgets.

Eight new Python importer tests (25 total QA regressions) passed locally, including
actual deterministic output/immutable source hashes/notices, analytic synthetic
absolute/relative/smooth curves/direction, malformed/bounds and original glyph/
count/order/canvas/transform rejection, source/metadata tamper and version/path/ID
locks. Import --check and direct pinned Dart guide decode/identity/version/count/
bounds/immutability/provenance smoke passed; pure-domain analysis, format and
whitespace passed. A rendered contact sheet of all eight normalized actual glyphs
was visually checked for shape/placement/order continuity. This is engineering
validation, not independent teacher/native-speaker handwriting-quality review.

Ten repository/codec and six widget tests are authored for actual bundle parity,
eight canonical matches, N4 no reads, incompatible identities/versions/counts,
malformed provenance/geometry, explicit step bounds/attribution/no grade, missing/
redacted retry, hidden late route result,320px/200-percent controls and actual bundled owned
exit with the expanded attribution EditableText retained. Existing
capture/catalog/reader/owned assertions are unchanged. Full new Flutter/provider/
widget/SDK/platform execution requires exact-head Actions. Prior local Flutter
metadata automatic-review rejection is not retried/bypassed.

No real evaluator is installed: evaluateReal remains unavailable. Showing a
reference/count match is not a calibrated grade, recognized handwriting, mastery
or attention/progress evidence. Independent pedagogy/geometry quality, broader
N5/N4 references and real evaluation remain open in #16; all14 hosted acceptance
groups remain pending. Keep #41 draft/#16 open/default preview; no merge,
deployment, Auth strategy/schema/RLS/security/provider/spend/schedule change.

Reference source/metadata/output checkout bytes are preserved for cross-platform
digest checks; importer text I/O uses explicit UTF-8 and LF.

The upstream COPYING file is preserved byte-for-byte, including its blank EOF
line. Full whitespace review reports that one upstream-only notice; authored-file
whitespace check passes. Its exact license digest is also locked by the importer.
