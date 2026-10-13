# Nihongo Daily Flutter shell

This is an explicitly labeled UI preview, not Personal Alpha. No login, real
curriculum, SRS scheduling, grading, progress persistence, network adapter or live
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

On Windows with Visual Studio's Desktop development with C++ workload:

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
- `shared/`: pure preview level model, layout and reusable unavailable pages.

The home domain/repository interface does not import Flutter. Riverpod injects
the repository, so failures and empty/loading states are testable without any
backend. Domain/transport adapters added later must preserve `contracts/v0.1`.
Screens call application providers, never raw database tables. Placeholder
routes are replaced by feature modules as their dependency issues are merged.

Routes: `/`, `/study`, `/settings`, `/auth`, `/vocabulary`, `/grammar`, `/srs`,
`/quiz`, `/listening`, `/kanji`, `/ai`, `/conversation`, `/progress`.

Tests cover preview/contract allocation parity, route recovery, all placeholders,
study navigation, N4/theme state, injected loading/error/retry/empty results, and
320/375-pixel layouts at 200% text size. Builds do not establish live auth/RLS,
multi-device sync, AI availability or curriculum coverage.
