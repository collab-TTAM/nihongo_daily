# N4 content — seed batches

## Scope

Issue #14 adds original N4 seed batches without claiming a complete JLPT
curriculum. The published export contains:

| Model | Count | Examples |
| --- | ---: | ---: |
| Vocabulary | 158 | 316 |
| Kanji metadata | 43 | — |
| Grammar | 61 | 122 |
| **Total** | **262** | **438** |

Themes are travel/planning, transport/shopping, work/communication, daily
habits, descriptions, common actions, safety, culture, health and study. The
second through fourth batches add confirmation/guidance, service/fees, addresses,
advice, decision, possibility, prohibition, preparation and completion patterns.
Examples pair Japanese sentences with kana readings and Vietnamese translations.

## Provenance and editorial limits

- Japanese sentences, Vietnamese meanings and explanations are authored for this
  project; no proprietary textbook passages are copied.
- JLPT level labels are project editorial labels, not an official JLPT-certified
  list.
- Scope references: the [official JLPT level summary](https://www.jlpt.jp/e/about/levelsummary.html)
  and [Irodori Elementary 1](https://www.irodori.jpf.go.jp/en/elementary01/pdf.html)
  / [Elementary 2](https://www.irodori.jpf.go.jp/en/elementary02/pdf.html)
  topic materials. These are planning references only; no passages are copied.
- Kanji readings/meanings and stroke counts are common reference metadata. The
  project records KanjiVG (CC BY-SA 3.0) as the stroke-count reference, but does
  not redistribute SVG/path geometry. `radical` remains null pending vetted
  metadata.
- No audio, canonical stroke-order data, tracing asset or real handwriting grade
  is included. `audio_ref` and `stroke_data_ref` are null for this batch.
- The fifth batch adds registration, communication, punctuality and return actions with 伝 and 返 metadata. The sixth batch adds health, notification and assistance actions with 薬 and 知 metadata. The seventh batch adds payment, quantity-change and advice actions with 払 and 増 metadata. The eighth batch adds transport changes, service desks, lost items and topic descriptions with 乗 and 残 metadata. The ninth batch adds searching, repairs and deliveries with 急 and 壊 metadata. The tenth batch adds lodging, arrivals and certainty with 到 and 泊 metadata. The eleventh batch adds food preparation, cleaning and queues with 焼 and 洗 metadata. The twelfth batch adds weather, drying, plants and cooling with 晴 and 曇 metadata. The thirteenth batch adds health, rest and careful handling of objects with 疲 and 痛 metadata. The fourteenth batch adds invitations, replies and event decisions with 招 and 断 metadata. The fifteenth batch adds safety, cleaning and storage with 滑 and 磨 metadata. The sixteenth batch adds scheduling, attendance and reply vocabulary with 都 and 合 metadata, plus decision and reported-information patterns. The seventeenth batch adds housing, utilities and service-use vocabulary with 所 and 設 metadata, plus audience, decision and source patterns. A native-speaker/teacher review and broader coverage review remain outstanding.

## Versioning and IDs

The N4 batch uses `content_version: 1`, matching the first publication version
of the existing N5 seed. N5 records and IDs are unchanged. N4 IDs are UUIDv5
values from the fixed project namespace with names `n4:<model>:<authored key>`.
Future corrections must preserve IDs, increment the content version, and record
the change rather than replacing learner history silently.

## Validation

From the repository root:

```bash
python3 -m contracts.validate_content
python3 contracts/validate.py
python3 -m unittest discover -s contracts -p 'test_*.py' -v
```

The validator checks schema shape, Unicode/text rules, kana readings, CJK
characters, duplicate IDs/keys/examples, typed grammar links, content versions,
asset flags, exact manifest counts and undeclared JSON files. Passing these
checks does not substitute for linguistic review.

## Draft editorial correction

The eighth batch had two mixed-script Vietnamese meanings: vocabulary 拾う and
Kanji 乗. They are corrected to Vietnamese while preserving their IDs and counts.
A content regression checks that short N4 vocabulary/Kanji meanings do not contain
accidental Japanese characters; Japanese quotations remain allowed in explanations.
The draft remains the unpublished first N4 export at content version 1. Publishing
later corrections requires a version increment. Since the current validator requires
one manifest version across all levels, a future version change involving N5 must
be coordinated before editing any N5 file.

