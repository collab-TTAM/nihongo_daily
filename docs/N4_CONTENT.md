# N4 content — seed batches

## Scope

Issue #14 adds original N4 seed batches without claiming a complete JLPT
curriculum. The published export contains:

| Model | Count | Examples |
| --- | ---: | ---: |
| Vocabulary | 54 | 108 |
| Kanji metadata | 17 | — |
| Grammar | 22 | 44 |
| **Total** | **93** | **152** |

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
- A native-speaker/teacher review and broader coverage review remain outstanding.

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
