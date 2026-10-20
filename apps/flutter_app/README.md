# Nihongo Daily Flutter shell

Opt-in native write-before-dispatch/restart library:
../../docs/DURABLE_REVIEW_JOURNAL.md. It does not activate offline mode or wire
recovery automatically; default runtime remains unconfigured. Explicit runtime
storage enables controller recovery as described in ../../docs/STUDY_RECOVERY.md.

This is an explicitly labeled UI preview, not Personal Alpha. No login, real
curriculum study flow, integrated SRS review, real grading, progress persistence, default network activation or live
AI/voice is implemented. N5/N4 selections and theme preferences last only for the
current process. The seven-block allocation previews the frozen 120-minute
default; every block is shown as unavailable and cannot record study completion.

## Run and verify

Use Flutter **3.35.4** / its bundled Dart **3.9.2**, matching CI. From this folder:

```bash
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter run -d chrome
flutter build web --release
```

On Windows with Visual Studio **2022** and its Desktop development with C++ workload
(matching the pinned CI image; Flutter 3.35 does not recognize VS 2026):

```bash
flutter run -d windows
flutter build windows --release
```

CI preserves the web and Windows release folders as `flutter-web-preview` and
`flutter-windows-preview`. Download the entire artifact folder. For Windows,
launch `nihongo_daily.exe` alongside the accompanying DLLs and data folder. For
web, serve the folder with `python -m http.server 8080` and open localhost:8080;
do not open index.html directly. These artifacts are previews, not deployments.

Web uses Flutter's default hash routes, for example `/#/kanji`, so refreshing a
deep link does not require custom server rewrites. Missing paths show a recovery
page. Native app routes use the same GoRouter configuration. An iOS platform
runner, signing and device/voice validation are later work; no iPhone build is
claimed by this shell.

## Structure and extension points

- `app/`: bootstrap, Material 3 theme, adaptive shell, navigation and GoRouter.
- `features/home/`: pure preview domain types, demo repository, Riverpod state,
  loading/error/empty UI. Replace with real Daily Plan services in #11; this
  preview repository does not implement or change the get_daily_plan contract.
- `features/settings/`: process-local preview preferences; no Supabase writes.
- `features/study/`: discovery of planned modules.
- `features/srs/`: pure versioned scheduler, typed RPC repository and /srs
  application controller/screen. The route is unconfigured by default; no real
  Auth/queue/RPC binding or durable queue is present. Fixture UI flows exist only
  in tests; see ../../docs/SRS_RPC.md for the integration limits.
  Process-local captured-connection lifecycle/runtime assembly is described in
  ../../docs/REVIEW_CONNECTION_LIFECYCLE.md; it is not a concrete SDK/Auth binding.
  Concrete owner-configured SDK binding is in ../../docs/SUPABASE_REVIEW_BINDING.md;
  default app still does not install it or supply login/profile/token persistence.
- `features/kanji/`: local capture/application/UI and synthetic-only primitives.
- `shared/`: pure preview level model, layout and reusable unavailable pages.

The home domain/repository interface does not import Flutter. Riverpod injects
the repository, so failures and empty/loading states are testable without any
backend. Domain/transport adapters added later must preserve `contracts/v0.1`.
Screens call application providers, never raw database tables. Placeholder
routes are replaced by feature modules as their dependency issues are merged.

Routes: `/`, `/plan`, `/study`, `/settings`, `/auth`, `/vocabulary`, `/grammar`, `/srs`,
`/quiz`, `/listening`, `/kanji`, `/ai`, `/conversation`, `/progress`.

Tests cover preview/contract allocation parity, route recovery, all placeholders,
study navigation, N4/theme state, injected loading/error/retry/empty results, and
320/375-pixel layouts at 200% text size. Builds do not establish live auth/RLS,
multi-device sync, AI availability or curriculum coverage.

Kanji capture prototype: `/kanji` supports local square drawing/undo/clear. It is
explicitly not real grading or persisted study; see `../../docs/KANJI_CAPTURE.md`.

SRS `/srs` has reveal/rating/save/retry/conflict/load/error/empty controls behind
injected runtime ports. There is no default demo success or fake due queue.
The default page states missing Supabase integration and cannot record progress.
An in-memory pending event survives route navigation, not process restart;
server-authenticated queue/Auth transport and durable recovery remain #20/#22/#15.

Opt-in web review persistence uses IndexedDB transactions and is documented in
[Browser review store](../../docs/BROWSER_REVIEW_STORE.md). Both explicit SRS
runtime factories accept it as their supplied store. Real Chrome connection,
page-refresh and second-tab tests are mandatory in CI; default runtime remains
null until Auth/profile/session configuration is supplied.


Owned Daily Plan read UI: configured staging startup publishes an account-gated
`/plan` route via **Kế hoạch học** after login/profile readiness. Enter an explicit
YYYY-MM-DD under the displayed profile timezone and load the authoritative plan;
loading, safe errors/offline retry, blocked areas and over-target time are shown.
Default preview has no plan source or fabricated progress. This read-only route
does not yet time/save study sessions or install the opt-in durable study-event
library described in [Completed-study durability](../../docs/DURABLE_STUDY_SESSIONS.md).
See [Daily Plan UI](../../docs/DAILY_PLAN_UI.md) and
[Staging bootstrap](../../docs/STAGING_BOOTSTRAP.md) for configuration/limits.

Configured Windows now installs completed-study storage and explicit
/study-recovery from account/plan pages. See docs/OWNED_STUDY_RECOVERY.md for
manual reconciliation and lifecycle ownership. Actual activity timer/new-report
creation and hosted acceptance remain pending; default app stays preview.
