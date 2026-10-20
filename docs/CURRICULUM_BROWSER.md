# Original curriculum browser — Issue #12

The /vocabulary and /grammar routes now browse the original N5 and reviewed
structural N4 seed exports in integration #41. This is a read-only preview, not a completed study session or
progress integration. No Auth/network/table/enrollment/write endpoint is added.
Integration #41 now combines this public reader with the reviewed #37 Auth/SRS
and #40 Daily Plan code. The original source drafts remain unchanged; main has
not been merged or deployed.

## Data and ownership

App assets under assets/curriculum/n5 and assets/curriculum/n4 are unchanged
packaged copies of their canonical data/<level> vocabulary.json and grammar.json. Repository tests require
exact text equality with the original exports so updates cannot silently drift.
Paths stay inside the Flutter asset directory on Web/Windows. The reviewed Pro
content/manifest/docs/content-test files are copied unchanged from source #38;
its branch and authored records remain untouched. BundledCurriculumRepository
uses fixed paths for each typed level/kind. A missing or invalid N4 asset fails
for safe explicit retry; it never substitutes N5 or TEST ONLY fixtures.

The display decoder retains canonical IDs, N5/N4 level and positive integer
content_version, filters inactive/wrong-level rows and preserves Japanese
expression/pattern/readings, Vietnamese meaning/context/explanations/notes/errors
and examples. Duplicate IDs, malformed metadata/text/examples and bounded-list
violations fail before publication. This projection is not a replacement for
contracts.validate_content, a new schema or linguistic certification.

## User flow

From study, open vocabulary/grammar, select a level, open a real exported item,
read its examples and return to the list/study. Level changes remove old details.
Details provide Bài trước/Bài tiếp in original export order. The first/last item
disables the corresponding action; a single item disables both. The position
label is the current item's index, not completion, mastery or saved progress.
Opening or changing an item starts at the top. Returning to the list restores
the in-screen list position; changing levels clears that position. These scroll
positions last only while this screen is mounted and are not account storage.
Search filters the current level's original entries by expression/pattern,
reading, Vietnamese meaning or title. Vietnamese matching ignores case and
diacritics (including combining accents); displayed text, IDs, versions and
export order stay unchanged. Queries are bounded to 128 characters in the UI,
remain local to this mounted screen and are never sent or saved to an account.
Changing the query clears detail/scroll selection; opening/returning from detail
keeps the query and previous/next use the filtered order. Clear restores all
entries. No matches has a distinct message from unavailable N4 content.
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

Four additional widget cases cover adjacent navigation for both content kinds,
single-item boundaries and actual scroll restoration after reading another item.
Both existing 320px/200% cases also navigate to the next original entry, and the
unavailable-N4 case verifies navigation removal and scroll reset.
Three search unit cases check actual original Japanese/readings/Vietnamese,
combining accents, grammar titles/order, literal/no-match and immutable results.
Three widget cases cover search/clear, filtered detail navigation and editing a
detail query before unavailable N4. Both 320px/200% cases search and clear too.

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


## Combined owned app integration — 2026-10-20

Integration #41 imports reader source57acb709 unchanged for its five production
files, two canonical N5 asset copies, two original curriculum test files and
updated home CTA test. Its optional PageBody scroll controller retains the
existing default for all Auth/plan/recovery/SRS callers. Router composition adds
the two actual reader routes while keeping every prior owned route and remaining
placeholder. Asset declarations are additive; dependency constraints/lockfile,
all CI steps, canonical data and Pro N4 content remain unchanged. Study cards
now describe read/search for vocabulary/grammar and current SRS/Kanji capability.

Two additional owned-host widget cases (one per content kind) use the actual
bundled provider and explicit TEST ONLY Auth/plan fixtures. They require the same
owned plan read before reader navigation, accentless search of original content,
unchanged authenticated N4 profile while publicly browsing N5, no extra plan or
queue dispatch, and awaited app exit while the reader search EditableText stays
mounted behind the closing screen with focus excluded. Public search text is
screen-local, not learner/account history. No second runtime or token/storage
owner is created. These are authored combined-head regressions until exact-head
Actions executes them; they do not establish real learner/OS shutdown acceptance.

Both source heads had allfive required CI jobs/steps verified before composition:
#41 ad299b12/CI39372174900 (474 Flutter/five Chrome/Web/Windows/native) and
#39 57acb709/CI39272055003 (110 Flutter/Web/Windows). Source success is historical
for the combined tree. After combined-head CI, continue validated vocabulary/
grammar activity reports through the existing durable study service; do not infer
study duration, completion or mastery from reading/searching/navigation. Full
content/audio/N4/hosted acceptance remain pending; keep #11/#12 open and drafts.


## Packaged N4 integration — 2026-10-20

After combined reader #41 dbbb92e1 passed CI39373165397 allfive jobs/every required
step (495 Flutter/five Chrome/actual SDK/native/Web/Windows), reviewed Pro #38
28c20cb0 at exact CI38696918878 allfive jobs/every step. Seven source paths are
imported without any byte change: canonical data/n4 vocabulary/grammar/Kanji,
data manifest/README, N4_CONTENT and contracts/test_content.py. N5 bytes, IDs,
versions and every existing contract/security/workflow gate remain unchanged.
The Pro branch stays independent and unmodified; this does not merge a draft
into main, certify a curriculum or deploy database content.

The two exact N4 vocabulary/grammar exports are packaged as app assets. Fixed
paths now support N5 and N4 without fallback. N4 offers366 words/139 patterns,
with1010 authored Japanese/kana/Vietnamese examples. Its95 Kanji metadata records
are retained in canonical data only; no new Kanji UI, stroke order, audio or real
grading is installed. Selection/search/detail/adjacent navigation use the same
reader and public preview preference; Auth profile/SRS/plan level is unchanged.
All are initial editorial seed labels, not official JLPT certification or full
coverage. Teacher/native-speaker review remains outstanding. Reading does not
credit study, and assets are not automatically provisioned to a hosted database.

Two additional asset/codec cases compare full N4 asset text to canonical exports,
all ordered IDs/versions/meanings and every Japanese/kana/Vietnamese example.
The obsolete unbundled-N4 case becomes a both-kind missing-asset/no-N5-fallback
case. Existing injected-unavailable-N4 widgets remain valid explicit missing-port
cases with all prior assertions retained. Two new original N4 widgets exercise
N5-detail to N4 selection, actual search/reading/examples, clear/next and return
to N5 at320px/200-percent text using original content and real hit-testable taps.
All prior owned-host exit/account/plan/SRS cases remain. Full new-head results
require exact-head Actions; source-head green evidence is historical only.


The next elapsed-report prerequisite is now implemented in the common core
(SHARED_STUDY_RECORDER.md). The configured reader still has no timer/start/finish
controls or learning-write capability. Production rejects non-SRS starts until
reader readiness and scoped lifecycle UI are explicitly installed and verified.
