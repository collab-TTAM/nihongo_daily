# Kanji capture prototype — Issue #6

The `/kanji` Flutter route now provides a square free-drawing surface. Mouse primary
button, touch and stylus input share a single-pointer state machine. Undo removes
the last stroke; clear/route exit discards the local session. Secondary pointers,
right-clicks, cancellations and taps do not create strokes. Scroll outside the
canvas; gestures beginning inside are reserved for drawing. No data is uploaded,
persisted or counted as learning progress. The original free canvas stays available;
selected-character practice now displays original metadata (KANJI_CATALOG.md).

The public metadata loader does not load reference strokes. No backend or deployed
evaluator is installed. The UI explicitly displays unavailable real grading. Issue #16 owns vetted/licensed
reference assets; tracing, stroke animation and real feedback require those assets
and a later integration. Lack of a provider/account does not block this prototype.

## Domain and normalization

`kanji_models.dart`, `stroke_capture.dart` and `synthetic_scorer.dart` depend only on
Dart. Application state uses Riverpod; presentation draws immutable snapshots.
The capture caller supplies pixel positions, square side and monotonic milliseconds.
Divide x/y by the side; preserve the drawn placement, scale and aspect ratio. Start
must be in the canvas; subsequent outside positions clamp to its boundary. A side
change, invalid coordinate, decreasing time or >1 hour stroke cancels the active
stroke. It is never saved as a truncated valid stroke. Stationary samples are
coalesced, with final elapsed time retained. A tap has no geometry and is rejected.

Stroke t starts at 0 and never decreases; strokes have 2–4096 points, attempts 1–64
consecutive zero-based strokes, finite [0,1] coordinates and the frozen UUID
identity. Exceeding either bound displays feedback. Undo permits capture again.
Models copy collections and validate constructor inputs without assertions. JSON
encoding matches `evaluate_kanji_request`; this is not a raw JSON decoder or auth
boundary. Untrusted raw requests must still pass schema/security validation.

## Synthetic heuristic nd-kanji-synthetic-1

`scoreSynthetic` accepts explicit synthetic attempt/reference pairs with matching
IDs. It does not recognize glyphs or load canonical references. `evaluateReal`
throws `ReferenceUnavailable` unconditionally. No synthetic score is displayed as
an actual learner grade or encoded as a live endpoint response.

For testing geometry: fit each entire drawing to a centered square using its
longest bounding-box side. Resample each stroke into 32 equal arc-length points.
Greedily match unused stroke pairs by lowest forward/reversed mean point distance
(ties follow capture/reference index). Shape = clamp(100 × (1 - distance / 0.25)).
Order = percentage of matched pairs with equal indices. Direction = mean tangent
cosine mapped from [-1,1] to [0,100]. Unmatched strokes contribute zero; each sum is
divided by the greater stroke count. Balance = clamp(100 × (1 - error)), where
error is the sum of raw canvas center-x/center-y/width/height absolute differences
/ 2. Total is the equal-weight mean of those four components. Reject degenerate
strokes/geometry. Scores remain finite and bounded; no rounding to integer grades.

This is an uncalibrated first primitive, not optimal assignment, OCR, recognition,
or a measured handwriting-quality model. Duplicate/ambiguous strokes, curves and
closed paths can give imperfect matching. Real reference grading needs dedicated
fixtures and learner review before claiming useful quality thresholds.

## Verification

Domain tests cover model bounds/immutability, capture limits/cancel/reindex/clock,
synthetic identity/reversal/reorder/translation/scale/density/missing/extra strokes,
foreign identity, degenerate shapes and real-reference absence. Widget tests cover
mouse/touch/stylus, scrolling, secondary pointer/right-click/cancel, undo/clear,
route disposal, small screens and large text. Retain existing app/SRS/security tests.

From `apps/flutter_app`: `flutter pub get --enforce-lockfile`, `dart format
--output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`,
`dart run tool/verify_kanji.dart build/kanji-wire-output.json`, `flutter build web
--release`. From repo root: `python3 -m contracts.validate_kanji_wire
apps/flutter_app/build/kanji-wire-output.json`. CI also retains Windows release
and database/RLS/race checks. Actual Dart request output is checked against the
frozen contract; synthetic score tests are not evidence of deployed grading.
