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

## Observed checks and remaining work

Parent060187ee CI39413895560 passed allfive jobs/every required step:573 Flutter
and five actual Chrome tests, retained SDK/native/process/SQL/Web/Windows builds/
artifacts. Completed Windows log confirms actual cancelable close and owned drain;
the prior marker publication fix and all four new real-file regressions passed.
These are parent results, not execution of the new N4 widgets.

Local checks passed: deterministic output for both levels,29 Python QA regressions
(including four new N4 actual mapping/notices/tamper/level-lock cases), inventory49,
pinned Dart format/pure-domain analysis and actual103-guide projection smoke with
identity/version/count/bounds/immutability and foreign-level/coverage rejection.
Four intermediate sheets of all95 normalized glyphs were visually reviewed for
shape/placement/order continuity. This is engineering review, not independent
teacher/native-speaker quality assessment or calibrated handwriting evaluation.

The expanded Flutter guide suite authors24 cases: all original8 N5/all95 N4
mappings, immutable geometry, fixed path separation, swapped level/version/coverage
rejection and identity mismatches; N4 explicit step/draw independence and foreign
result rejection; missing/redacted retry and320px/200-percent controls for both
levels; late same-level/cross-level results; expanded attribution EditableText
retained through awaited owned exit for both actual bundles. Retained N5/other
flow assertions remain. Obsolete N4-unavailable expectations are replaced by
N4's fixed-asset and explicit-loading contract, not relaxed coverage assertions.
Full new Flutter/widgets/platform execution requires exact-head Actions. The
prior local Flutter metadata automatic-review rejection is not retried/bypassed.

Keep #41 draft/#16 open/default preview/all14 hosted acceptance groups pending.
No real recognition/grading/mastery/attention or saved Kanji progress claim.
Independent pedagogical quality, reviewed real evaluation and wider curriculum
remain open. No Auth strategy/storage/schema/RLS/dependency/CI/security/provider/
spend/merge/deployment/release/schedule change; one asset-only pubspec declaration.
