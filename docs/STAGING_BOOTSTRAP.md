# Explicit Windows staging application bootstrap

The ordinary entrypoint selects preview with absent/preview ND_MODE. A trusted
operator can build a configured Windows client with ND_MODE=staging, a validated
HTTPS ND_SUPABASE_URL and public ND_SUPABASE_PUBLIC_KEY. This mode does not prove
that the chosen project is non-production; the operator must supply the intended
non-production project. No provider/schema/RLS/deployment is changed by bootstrap.
Only a public publishable/anon key can ship; service-role/private keys are rejected
by the retained SDK validator. Learner credentials come only from the existing
obscured account form, not compile values, CLI arguments or environment.

Supported build settings (through Flutter --dart-define-from-file or equivalent
trusted build settings, never learner input):

```json
{
  "ND_MODE": "staging",
  "ND_SUPABASE_URL": "https://YOUR_PROJECT.supabase.co",
  "ND_SUPABASE_PUBLIC_KEY": "YOUR_PUBLIC_PUBLISHABLE_KEY",
  "ND_AUTOMATIC_REFRESH": "true"
}
```

For an explicitly selected staging build, automatic refresh defaults to true. Set ND_AUTOMATIC_REFRESH=false only to opt out. The owned runtime refreshes before expiry and persists the rotated refresh secret before own-profile/study readiness; failed rotation fences the session and does not retry automatically. The ordinary absent/preview mode remains unchanged and never opens the configured Auth runtime.
Invalid/missing selected configuration shows fixed errors before disk/SDK creation;
unsupported web/mobile/non-Windows selects a fixed unavailable screen and never
falls back to preview Auth or another project. The shipped CI preview is rebuilt
without these TEST ONLY settings before artifact upload. Hosted acceptance needs
a configured project with the reviewed migrations/RPCs and actual learner A/B.
Never include passwords, refresh/access tokens or private keys in build settings.

## Owned assembly and durable storage

Windows retrieves the current user's LocalAppData through SHGetKnownFolderPath.
A fixed NihongoDaily/ReviewJournal/v1 namespace and SHA256(canonical credential
target) partition journals by trusted project origin. BCryptHash provides the
stable 64-hex scope key; no learner credential is hashed into a file path. The
resolver only returns a path. Dart/NativeReviewJournal opens/flushes the journal
and acquires its process lease before constructing any SDK/token writer.
A second same-project assembly therefore cannot bypass the existing file lease
by opening an independent token writer through this bootstrap. Same OS user can
access application files/credentials; this is not an OS security sandbox.

The assembly transfers ownership of runtime and journal to a startup adapter.
Start invokes refresh-only server restoration when a stored secret exists; empty
vault offers the account route. Close drains the SDK/persistence runtime before
releasing the journal lease. Factory failure closes an already opened journal.
Logout/close do not delete learner history. No cwd/temp/network path fallback;
unusual/long/redirected unsupported roots fail with a fixed storage error.
Native known-folder memory is freed, hash provider closed and Unicode converted
with checked Windows APIs. Canonical credential target validation is shared
without changing the existing credential read/write/delete contract.

## Verification limits

Six config/selection/widget cases and three directory channel/platform cases
exercise default preview, invalid selection, unsupported platforms, explicit
refresh choice, configured account route and malformed/Unicode path results.
Three new Windows process phases resolve isolated GUID `.invalid` scopes, write/
reopen a fixed marker, execute the actual empty-vault owned factory/start/close
and reopen its journal lease. Finally removes only that invocation's test scope.
CI separately compiles the configured main with fixed TEST ONLY public settings,
then rebuilds and uploads normal preview. Verified source evidence is recorded below.

Tests do not authenticate with Supabase: no hosted learner/login/signature/
expiry/device or full configured GUI/OS-shutdown proof. Default CI artifacts remain
preview. All 14 live Personal Alpha groups remain pending; keep #37 draft.

Primary Microsoft docs checked 2026-10-14:
- https://learn.microsoft.com/en-us/windows/win32/api/shlobj_core/nf-shlobj_core-shgetknownfolderpath
- https://learn.microsoft.com/en-us/windows/win32/api/bcrypt/nf-bcrypt-bcrypthash

## Verified source evidence

Source `5be34663e2c28e182d12c66f0dea894853e05cd9` passed all five jobs in
https://github.com/collab-TTAM/nihongo_daily/actions/runs/38605205617 .
Observed 356 Flutter tests (six config/selection + three directory cases added),
five actual Chrome tests, format/analyze, OS app-data/empty-vault staging factory
marker and all retained Windows vault/runtime/native/SQL/wire/security gates.
Configured staging main compiled with TEST ONLY public values; normal Windows
preview rebuilt afterward and web/Windows preview artifacts passed upload.
Raw run/latest-attempt metadata passed exact-head/every-required-step QA, including
the added configured build gate. All 256 source blobs matched. Local 49 contracts/
17 QA/format passed. Platform fixtures now use framework variants; unused imports
removed without production/assertion/lint/security gate changes.

No hosted project, login/JWT/learner or full configured GUI/OS-shutdown acceptance
is inferred. Native factory probe uses a random `.invalid` project with empty
vault, so it proves assembly/disk/lease close rather than network Auth. All 14
live release groups remain pending. Source evidence is historical for later docs.
