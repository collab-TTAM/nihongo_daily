# Original curriculum browser — Issue #12

The /vocabulary and /grammar routes now browse the original N5 exports already
present on main. This is a read-only preview, not a completed study session or
progress integration. No Auth/network/table/enrollment/write endpoint is added.
The separate #37 SRS/Auth draft is not merged or copied into this branch.

## Data and ownership

App assets under assets/curriculum/n5 are unchanged packaged copies of the
canonical data/n5 vocabulary.json and grammar.json. Repository tests require
exact text equality with the original exports so updates cannot silently drift.
Paths stay inside the Flutter asset directory on Web/Windows. No authored data,
manifest, content validators/tests or Pro-owned N4 documentation changed.
BundledCurriculumRepository reads only those fixed asset paths and typed kinds.
N4 is explicitly empty/unavailable in this build until its separate content lane
is reviewed/integrated; it never substitutes N5 or TEST ONLY fixtures.

The display decoder retains canonical IDs, N5/N4 level and positive integer
content_version, filters inactive/wrong-level rows and preserves Japanese
expression/pattern/readings, Vietnamese meaning/context/explanations/notes/errors
and examples. Duplicate IDs, malformed metadata/text/examples and bounded-list
violations fail before publication. This projection is not a replacement for
contracts.validate_content, a new schema or linguistic certification.

## User flow

From study, open vocabulary/grammar, select a level, open a real exported item,
read its examples and return to the list/study. Level changes remove old details.
Loading/empty/safe error and explicit retry states are visible. Audio absence is
explicit; an audio reference alone never starts playback or external navigation.
No completion button, mastery counter or fake saved study result is installed.
The existing process-local preview level preference is used; it is not stored
in an account. The screen labels the initial content and missing progress.

## Verification and remaining acceptance

Five repository/asset/decoder cases and six widget cases are authored. The actual
N5 JSON must match rootBundle assets; reader tests preserve original IDs/versions/
Japanese examples. Widget cases exercise vocabulary/grammar details/navigation,
missing N4 without old content, loading/redacted errors/manual retry and both
screens at 320px/200% text. The existing home-to-study CTA test now opens the real
default asset-backed vocabulary route instead of asserting a placeholder.

Source requires exact-head format/analyze/Flutter/web/Windows CI; no local SDK
execution is claimed when the runtime has no Dart/Flutter. Main-based QA metadata
is separate from #37's newer unmerged inventory/evidence. All live learner gates
remain open. Issue #12 stays open/draft: validated study-event/progress integration,
complete N5/N4 coverage/curation/audio and configured learner acceptance are still
missing. Integrating #37/#38 later needs coordinator conflict review and fresh CI.

The required format step retains its name and fails on mismatches. It additionally
formats only the disposable CI checkout and prints the Dart diff on failure,
allowing an SDK-less cloud worker to apply the actual pinned SDK output. It never
commits fixes or lets a formatting failure continue as success.
