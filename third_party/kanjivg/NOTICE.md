# KanjiVG N5/N4 reference subsets

103 original nonvariant SVGs from KanjiVG, commit
70a0b7ae0c18ceb5cb358274b029cce0234a43bc, are retained unchanged in
n5_source/ (8) and n4_source/ (95).
Copyright (C) 2009/2010/2011 Ulrich Apel; KanjiVG contributors.
Source: https://github.com/KanjiVG/kanjivg
Project: https://kanjivg.tagaini.net/
License: Creative Commons Attribution-ShareAlike 3.0 Unported.
https://creativecommons.org/licenses/by-sa/3.0/
COPYING retains the upstream license text; original SVG copyright/license notices
are retained. There is no endorsement by KanjiVG or its contributors.

The generated apps/flutter_app/assets/kanji_references/n5.json and n4.json are
adaptations of these KanjiVG stroke paths, distributed under CC BY-SA 3.0. Changes: flatten
cubic/smooth cubic curves at 0.15 source-pixel tolerance, normalize the original
109-by-109 canvas to [0,1], round coordinates to eight decimals, retain original
stroke order/direction and map to this project's original Kanji IDs/versions.
The project-authored metadata is not claimed to be KanjiVG content. These asset
notices do not relicense unrelated application code.

Reproduce: python3 scripts/import_kanji_references.py --check
Regenerate reviewed output: python3 scripts/import_kanji_references.py
No downloads, system fonts, provider keys or SDK required. This subset covers
only the current eight original N5 seed characters and95 original N4 records,
not a full JLPT corpus. Separate manifests lock each level/version/coverage.
Guide geometry is not a calibrated handwriting evaluator or mastery evidence.

COPYING is preserved byte-for-byte, including the upstream blank line at EOF.
Its digest is locked in the manifest; it is not reformatted to remove that line.
