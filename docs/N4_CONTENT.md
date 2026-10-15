# N4 content - seed batches

## Scope

Issue #14 adds original N4 seed batches without claiming a complete JLPT
curriculum. The published export contains:

| Model | Count | Examples |
| --- | ---: | ---: |
| Vocabulary | 310 | 620 |
| Kanji metadata | 81 | - |
| Grammar | 118 | 236 |
| **Total** | **509** | **856** |

Themes are travel/planning, transport/shopping, work/communication, daily
habits, descriptions, common actions, safety, culture, health and study. The
second through twenty-ninth batches add confirmation/guidance, service/fees, addresses,
advice, decision, possibility, prohibition, preparation, completion, household and clothing patterns.
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
  project records KanjiVG (CC BY-SA 3.0) as the stroke-count reference, including ?, ?, ?, ?, ? and ? for these batches, but does
  not redistribute SVG/path geometry. `radical` remains null pending vetted
  metadata.
- No audio, canonical stroke-order data, tracing asset or real handwriting grade
  is included. `audio_ref` and `stroke_data_ref` are null for this batch.
- The fifth batch adds registration, communication, punctuality and return actions with ? and ? metadata. The sixth batch adds health, notification and assistance actions with ? and ? metadata. The seventh batch adds payment, quantity-change and advice actions with ? and ? metadata. The eighth batch adds transport changes, service desks, lost items and topic descriptions with ? and ? metadata. The ninth batch adds searching, repairs and deliveries with ? and ? metadata. The tenth batch adds lodging, arrivals and certainty with ? and ? metadata. The eleventh batch adds food preparation, cleaning and queues with ? and ? metadata. The twelfth batch adds weather, drying, plants and cooling with ? and ? metadata. The thirteenth batch adds health, rest and careful handling of objects with ? and ? metadata. The fourteenth batch adds invitations, replies and event decisions with ? and ? metadata. The fifteenth batch adds safety, cleaning and storage with ? and ? metadata. The sixteenth batch adds scheduling, attendance and reply vocabulary with ? and ? metadata, plus decision and reported-information patterns. The seventeenth batch adds housing, utilities and service-use vocabulary with ? and ? metadata, plus audience, decision and source patterns. The eighteenth batch adds community, environment and safety vocabulary with ? and ? metadata, plus guidance, interval and variation patterns. The nineteenth batch adds public-service procedures, documents and study attendance with ? and ? metadata, plus regulation, endpoint and set-comparison patterns. The twentieth batch adds purposes, methods, results and community activities with ? and ? metadata, plus obligation, definition and necessity patterns. The twenty-first batch adds airports, scenery, travel and forecasts with ? and ? metadata, plus recent completion, interest and importance patterns. The twenty-second batch adds applications, interviews, school milestones and contact details with ? and ? metadata, plus requests, topics and duration patterns. The twenty-third batch adds health visits, symptoms and treatment with ? and ? metadata, plus advice, completion and comparison patterns. The twenty-fourth batch adds fire, earthquakes, evacuation and accident prevention with ? and ? metadata, plus prevention, caution and advice patterns. The twenty-fifth batch adds shopping, payments, returns and stock with ? and ? metadata, plus choice, trial and polite-request patterns. The twenty-sixth batch adds repairs, construction, utilities and maintenance with ? and ? metadata, plus prepared-state, unchanged-state and interval patterns. The twenty-seventh batch adds ingredients, cooking, refrigerators and food dates with ? and ? metadata, plus sensory description, skill and permission patterns. The twenty-eighth batch adds traffic, roads, fares, timetables and destinations with ? and ? metadata, plus uncertainty, variation and purpose patterns. The twenty-ninth batch adds doors, lights and clothing with ? and ? metadata, plus in-progress, comparison and preserved-state patterns. The thirtieth batch adds schedules, presentations, submissions, deadlines and participants with ? and ? metadata, plus deadline, reported-instruction and additive-comparison patterns. The thirty-first batch adds orders, customers, store areas, stock status and store opening/closing with ? and ? metadata, plus prerequisite, viewpoint and alternative patterns. The thirty-second batch adds health condition, nursing, dental visits, travel costs, one-way/round-trip tickets, information desks and ticket gates with ? and ? metadata, plus help, permission and negative advice patterns. The thirty-third batch adds permissions, deadlines, maps, event venues, relationships, opportunities, direct contact and lost-property service with ? and ? metadata, plus polite requests, reassurance and through/means patterns. The thirty-fourth batch adds grades, urgent matters, articles, programs, floods, typhoons, cooling and electricity costs with ? and ? metadata, plus ongoing appearance, soft advice and degree-comparison patterns. The thirty-fifth batch adds Japanese calligraphy, parks, riversides, coasts, forests, agriculture, factories and residents with ? and ? metadata, plus intention, substitution and source patterns. The thirty-sixth batch adds power, screens, functions, registration, settings, saving, deletion and data input with ? and ? metadata, plus necessity, focus and partial-negation patterns. A native-speaker/teacher review and broader coverage review remain outstanding.

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

The eighth batch had two mixed-script Vietnamese meanings: vocabulary ?? and
Kanji ?. They are corrected to Vietnamese while preserving their IDs and counts.
A content regression checks that short N4 vocabulary/Kanji meanings do not contain
accidental Japanese characters; Japanese quotations remain allowed in explanations.
The draft remains the unpublished first N4 export at content version 1. Publishing
later corrections requires a version increment. Since the current validator requires
one manifest version across all levels, a future version change involving N5 must
be coordinated before editing any N5 file.

