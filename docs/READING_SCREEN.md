# Reading practice screen — Issue #34

The existing `/listening` module now hosts read-only reading practice. It uses
Riverpod `readingRepositoryProvider` and an auto-disposed level-specific catalog
provider, not database tables or an account runtime. The provider defaults to
null: the normal preview explicitly reports missing reviewed reading material.
No TEST ONLY lesson is packaged or injected into the application. A trusted host
may supply the reviewed `LocalReadingRepository` described in READING_MATERIAL.md.
No learner URL/path/key input, arbitrary remote loader or new dependency is added.

## Reader and answers

The screen offers N5/N4 selection using the existing public preview preference;
this never changes an authenticated profile. A loaded catalog lists Japanese and
Vietnamese titles. Opening a passage displays selectable Japanese text and its
attribution, with explicit options to reveal kana and Vietnamese translations.
Question and choice labels also honor those options. Material is bounded by the
existing strict importer; attribution alone does not certify licensing or language
accuracy. Titles/questions have semantic headings and controls retain native
Flutter semantics; scrollable wrapping layouts support large text.

Each opened passage creates a fresh ReadingRound over its immutable snapshot.
Only the first valid choice per question is accepted. Answered choices disable,
with Vietnamese correct/incorrect feedback, the answer and source explanation.
The integer score appears only after every question has an answer. Restart and
return-to-list are explicit. Answer/restart/back/toggle callbacks capture the
exact round object; retained callbacks cannot answer or reset its successor,
including a restarted round with the same content identity/version.

Selection, answers and results are local to the mounted reader. Opening another
passage or leaving the route discards the round. There is no save/completed-study
button or account capability, progress/mastery inference, study-minute credit,
SRS enrollment, journal, timer or sync operation in this increment.

## Loading and source changes

Absent repository, pending catalog, safe error/manual retry and empty requested
level are distinct states. Source exceptions never appear in the UI. A failure
explains that no offline copy is available; it does not display cached old content
or automatically retry. A packaged/local source can work without a network,
but this screen installs no durable offline cache.

Both Riverpod refresh/reload paths explicitly display loading instead of retaining
old data. The panel identity includes repository, level, explicit reload revision
and returned collection. Manual reload/retry resets answers even if a source
immediately returns the identical list without an intermediate loading frame.
Level changes or repository replacement/null remove the previous panel, and
late old source successes/errors are ignored by the auto-disposed provider.
Reload callbacks additionally require the same current repository/level.
Explicit navigation resets scroll to the top through a mounted controller guard.

Listening always displays a disabled `Nghe: chưa khả dụng` control and missing
vetted audio explanation. No player, recording, permission, retention, generated
speech or simulated successful listening completion is installed. Properly licensed
playable audio and availability/failure behavior require a separate reviewed adapter.

## Verification and remaining work

Fifteen new widget cases use the actual router, Riverpod providers, parser/local
repository and explicit TEST ONLY material/read ports. They cover the null default,
reading/kana/translation, first-answer/wrong-feedback/completion, restart/back and
retained callbacks, loading/error redaction/manual retry/empty, real dropdown level
selection, pending old-level success/error, same-level source replacement/null,
late replaced-source success, pending reload/new version, immediate identical-list
reload, same-version conflict, disposal/late source errors and N5/N4 320px at200%
text with usable controls. The previous dynamic `/listening` placeholder test is
replaced by dedicated reading-route coverage; original app_test.dart and all other
existing test bodies remain unchanged.

Run `flutter test test/features/reading/reading_widget_test.dart` with Flutter3.35.4
and Dart3.9.2 after `flutter pub get --enforce-lockfile`; retain full formatter,
analyzer, Flutter/Chrome and Web/Windows CI checks. New widget execution/build
results must be observed at the actual new commit; parent CI success is not a pass
for these new cases. Local pinned Dart formatting and QA inventory are not Flutter
execution. Actual observed results are recorded in PROJECT_STATUS and PR #41.

Next: verify full current-head CI, supply separately reviewed original/licensed
reading material in coordination with #26/#14, and bind eligible reading to the
existing captured-session/durable completed-study recorder. Audio, hosted learner
acceptance and all14 release groups remain pending; #34 stays open and #41 draft.
