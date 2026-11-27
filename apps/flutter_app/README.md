# Nihongo Daily Flutter app

## Default mode and current limits

A normal run/build with no `ND_MODE` setting remains the explicitly labeled
preview. It does not initialize Supabase, offer a fake login, or report a review
as saved. The home screen still uses preview plan data; the seven 120-minute
blocks are unavailable and cannot record study completion. Kanji capture remains
a local prototype with synthetic-only scoring. Complete N5/N4 curriculum study,
mastery/progress dashboard, live AI tutor and voice conversation are not yet
Personal Alpha features.

The repository also contains an **opt-in Windows staging runtime**. A trusted
build can select a caller-owned Supabase Auth session, Windows Credential
Manager refresh-token vault, own-profile readiness barrier, typed SRS RPC
binding and durable native review journal. This path is not enabled in the
default preview, is not supported by the Web/iOS bootstrap, and is not evidence
of a hosted learner release. The protected hosted acceptance and physical
multi-device gates remain separate.

## Run the default preview

Use Flutter **3.35.4** / its bundled Dart **3.9.2**, matching CI. From this folder:

```bash
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter run -d chrome
flutter build web --release
```

On Windows with Visual Studio **2022** and its Desktop development with C++
workload (matching the pinned CI image; Flutter 3.35 does not recognize VS 2026):

```powershell
flutter run -d windows
flutter build windows --release
```

CI preserves the Web and Windows release folders as `flutter-web-preview` and
`flutter-windows-preview`. Download the entire artifact folder. For Windows,
launch `nihongo_daily.exe` alongside the accompanying DLLs and data folder. For
Web, serve the folder with `python -m http.server 8080` and open localhost:8080;
do not open index.html directly. These default artifacts are previews, not
deployments.

Web uses Flutter's default hash routes, for example `/#/kanji`, so refreshing a
deep link does not require custom server rewrites. The current Auth/session
bootstrap is Windows-only; Web remains preview-only. An iOS platform runner,
signing and device/voice validation are later work; no iPhone build is claimed.

## Opt-in Windows staging account runtime

Only a trusted build operator selects the Supabase project. The learner cannot
enter or change the project URL or public key in the app. The build uses these
compile-time values:

- `ND_MODE=staging`
- `ND_SUPABASE_URL`: the intended non-production Supabase project URL
- `ND_SUPABASE_PUBLIC_KEY`: that project's publishable key or legacy anon key
- `ND_AUTOMATIC_REFRESH`: `true` by default; set `false` only when deliberately
  testing the explicit manual-refresh path

Example PowerShell run (replace the two placeholders with the isolated staging
project's public values):

```powershell
flutter run -d windows `
  --dart-define=ND_MODE=staging `
  --dart-define=ND_SUPABASE_URL=https://<project-ref>.supabase.co `
  --dart-define=ND_SUPABASE_PUBLIC_KEY=<sb_publishable_or_anon_key>
```

Release build uses the same defines:

```powershell
flutter build windows --release `
  --dart-define=ND_MODE=staging `
  --dart-define=ND_SUPABASE_URL=https://<project-ref>.supabase.co `
  --dart-define=ND_SUPABASE_PUBLIC_KEY=<sb_publishable_or_anon_key>
```

The selected configuration is validated before disk or SDK resources are
created. Empty/preview mode never opens configured resources; invalid staging
mode shows a fixed unavailable state and never falls back to preview. Only
Windows can construct this owner. The configured account screen signs in with
the user's Supabase credentials, waits for the caller-owned refresh-token write
and own-profile result before publishing study access, and exposes explicit
logout/retry. Refresh tokens are kept in the project-scoped Windows Credential
Manager slot; there is no plaintext-file fallback or token logging.

**Never compile a service-role key, JWT signing secret, password or refresh
token into the app.** The public key is not a service-role credential, but the
staging project must still be isolated from production. Build-time URL/key
selection is a trusted operator action, not a learner setting.

Before calling this hosted acceptance, follow
[Hosted Supabase staging acceptance](../../docs/HOSTED_SUPABASE_ACCEPTANCE.md).
That manual workflow requires the protected `supabase-staging` environment,
two pre-provisioned non-production test users and explicit
`confirm_non_production=true`. Local Supabase/CI fixtures and the Windows
Credential Manager process probes are component evidence only; they do not prove
deployed signed-JWT A/B, hosted Windows restore or a complete learner journey.

## Structure and extension points

- `app/`: default/staging bootstrap, Material 3 theme, adaptive shell, navigation
  and GoRouter.
- `features/auth/`: opt-in account controller, profile barrier, session refresh,
  Windows credential vault adapter and explicit account UI.
- `features/home/`: preview domain types, demo repository, Riverpod state and
  loading/error/empty UI. Real Daily Plan services remain #11; preview data does
  not implement or change the frozen `get_daily_plan` contract.
- `features/settings/`: process-local preview preferences; no Supabase writes.
- `features/study/`: discovery of planned modules.
- `features/srs/`: pure versioned scheduler, typed RPC repository, account-bound
  controller/screen, durable review repository and native/browser store adapters.
  The default route has no runtime and cannot fake a saved review. The configured
  Windows path supplies the owned Auth/RPC runtime; see
  [SRS RPC](../../docs/SRS_RPC.md),
  [session lifecycle](../../docs/PERSISTENT_SESSION_LIFECYCLE.md) and
  [Windows session vault](../../docs/WINDOWS_SESSION_VAULT.md).
- `features/kanji/`: local capture/application/UI and synthetic-only grading
  primitives; vetted stroke assets and real grading remain outstanding.
- `shared/`: preview models, layout and reusable unavailable pages.

Routes include `/`, `/study`, `/settings`, `/auth`, `/vocabulary`,
`/grammar`, `/srs`, `/quiz`, `/listening`, `/kanji`, `/ai`,
`/conversation` and `/progress`. Modules not yet integrated remain explicitly
unavailable or preview-only.

Tests cover preview/bootstrap selection, invalid configuration with no fallback,
owned startup/close, account and profile barriers, refresh rotation, vault
failure/late-response/account-switch guards, SRS transactions and browser/native
storage. CI also builds Web and Windows and runs disposable local Supabase
integration. These checks do not establish hosted Auth/RLS, real learner
curriculum coverage, physical two-device sync, live AI/voice or iPhone release.
