# Original curriculum seed — content v1 / wire v0.1

This is a small original editorial N5/N4 seed for development and initial study
screens, not full JLPT coverage or an officially certified JLPT list. The first
N4 seed batch is included below; Issue #14 still requires broader coverage. It
is authored content, not a provider mock, but it is not loaded into Flutter or
a hosted database yet.

| Level | Vocabulary | Kanji | Grammar | Embedded examples |
| --- | ---: | ---: | ---: | ---: |
| N5 | 24 | 8 | 10 | 44 |
| N4 | 24 | 8 | 10 | 68 |

## N4 first seed batch

The first N4 batch is an original editorial seed for development. It contains
24 vocabulary items, 8 Kanji metadata records and 10 grammar patterns, with 68
embedded Japanese–Vietnamese examples. Topics cover travel and planning,
transport and shopping, work and communication, daily habits, descriptions and
common actions. This is an initial batch, not complete JLPT N4 coverage.

The Japanese sentences and Vietnamese explanations were authored for Nihongo
Daily. Kanji meanings/readings and stroke counts use common reference metadata;
KanjiVG is the stated reference for stroke-count checking, under CC BY-SA 3.0.
No KanjiVG SVG/path asset is redistributed here. A later editorial/native-speaker
review is still required before treating this seed as release curriculum.

N4 content uses the same `content_version: 1` as the existing N5 seed because
this is the first publication of these N4 records. IDs are UUIDv5 values derived
from the project's fixed namespace and `n4:<model>:<authored key>` names. Existing
N5 IDs and rows are unchanged.

All `audio_ref`, `stroke_data_ref` and Kanji `radical` fields are currently null.
The app must continue to show audio, stroke-order assets and real handwriting
grading as unavailable until a separately reviewed asset issue supplies them.

N4 uses the same wire objects and validation rules as `data/n5/*.json`; the
level-specific files are kept under `data/n4/` for independent expansion.

`manifest.json` makes scope/counts/assets machine-checkable. `n5/*.json` are arrays
of the unchanged named vocabulary/kanji/grammar wire objects in
`contracts/v0.1/models.schema.json`. Examples are embedded in parent order.
The 44 examples count entries: a sentence intentionally reused to illustrate
another parent is counted again. Duplicate sentences within one item are rejected;
reuse across distinct items is permitted. No independent example IDs exist in the
wire contract. UUIDv5 IDs were assigned once with namespace
`16b67f21-2995-41d1-9a4d-285289b68f48`, names `n5:<model>:<authored key>`; preserve
these IDs on future edits, even if an expression/pattern is corrected. Increment
content_version when publishing changed content; do not silently replace history.

## Coverage and language notes

Vocabulary topics: people (5), places (3), nature (2), food (2), study (1), time (3),
actions (5), descriptions (3). Kanji: 日 月 木 山 川 人 水 火. Grammar: nominal
assertion/negation/question, の, direct object を, action location で, destination
へ／に, existence に…が, polite verb negation and polite past/negative past.
Verb headwords use dictionary forms; examples use polite forms. い adjectives
are distinct from nominal predicates. ご飯 preserves the usual polite spelling.
今日/明日 are word readings and must not be inferred from single-character lists.

`reading_ja` gives kana spelling, retaining katakana loanwords, punctuation and
orthographic particles は／へ／を. It is not a phonetic transcription: these
particles are pronounced わ／え／お. It is not positional furigana markup. Kanji
readings are selected common readings, not exhaustive; context, counters and
sound changes require later entries. Difficulty 0.2 is a seed editorial value,
not a calibrated mastery or memory estimate. Vietnamese examples/explanations
and Japanese sentences were authored for this project; no proprietary textbook
passages or third-party text corpora were copied.

A separate manual review checked sentence/reading/translation correspondence,
verb forms, particle distinctions and grammar links. Machine validation does not
prove linguistic correctness; an independent teacher/native-speaker review has
not occurred. Broader conjugations, counters, adjective lessons, listening,
quizzes and conversation content are outside this seed.

## Metadata provenance and absent assets

Eight stroke counts were cross-checked against nonvariant SVG path counts in
[KanjiVG](https://github.com/KanjiVG/kanjivg), commit
`70a0b7ae0c18ceb5cb358274b029cce0234a43bc` (checked 2026-10-13 UTC). Source files:
`kanji/065e5.svg`, `06708.svg`, `06728.svg`, `05c71.svg`, `05ddd.svg`,
`04eba.svg`, `06c34.svg`, `0706b.svg`. Counts respectively: 4, 4, 4, 3, 3, 2, 4, 4.
KanjiVG is copyright Ulrich Apel under CC BY-SA 3.0; this seed only checks factual
counts and does not redistribute/derive SVG path geometry. Any future importer
must retain required attribution/license and independently vet reference assets
under #16. Common readings/meanings are editorial metadata rather than copied
KanjiVG content. `radical` is explicitly null pending vetted metadata.

All `audio_ref` and `stroke_data_ref` fields are explicitly null. No recording,
canonical stroke order, tracing asset or real grade is claimed. UI must show
unavailable audio/grading until valid assets/integrations exist; #6's synthetic
scoring tests do not turn this metadata into grading reference data.

## Reproduce checks / integration boundary

From repository root:

```bash
python3 -m pip install -r contracts/requirements.txt
python3 -m contracts.validate_content
python3 contracts/validate.py
python3 -m unittest discover -s contracts -p 'test_*.py' -v
```

Validation is offline after installing the existing dependencies. It asserts
frozen item schemas, required nullable fields, bounded arrays/types, NFC/trimmed
text, kana readings, CJK characters, global UUID uniqueness, normalized natural
keys/tags, example uniqueness, typed grammar links, level/version/asset flags,
actual coverage counts, duplicate JSON member rejection and no undeclared JSON files. It does not call providers,
change RLS, deploy, or fetch remote schemas. All existing CI jobs remain required.

A future importer maps examples to normalized `vocabulary_examples` /
`grammar_examples` with stable parent/order and grammar links to
`grammar_relations` in one reviewed transaction (supabase/README.md). There is no
importer/migration/deployment in this change. #12 consumes these exports through
typed repositories; #14 adds N4, #16 reference assets. Personal Alpha remains
incomplete until study, auth, sync, AI/voice and release evidence are integrated.
