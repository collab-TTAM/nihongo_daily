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
  "ND_AUTOMATIC_REFRESH": "false"
}
```

Use ND_AUTOMATIC_REFRESH=true only as explicit opt-in to SESSION_REFRESH policy.
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
then rebuilds and uploads normal preview. New-source full CI is pending.

Tests do not authenticate with Supabase: no hosted learner/login/signature/
expiry/device or full configured GUI/OS-shutdown proof. Default CI artifacts remain
preview. All 14 live Personal Alpha groups remain pending; keep #37 draft.

Primary Microsoft docs checked 2026-10-14:
- https://learn.microsoft.com/en-us/windows/win32/api/shlobj_core/nf-shlobj_core-shgetknownfolderpath
- https://learn.microsoft.com/en-us/windows/win32/api/bcrypt/nf-bcrypt-bcrypthash
