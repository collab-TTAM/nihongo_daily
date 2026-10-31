$ErrorActionPreference = 'Stop'
$scope = 'bridge-' + [Guid]::NewGuid().ToString('N')
$exe = (Resolve-Path 'build/windows/x64/runner/Release/nihongo_daily.exe').Path

function Invoke-Bridge([string] $phase) {
    $process = Start-Process -FilePath $exe -ArgumentList @($phase, $scope) -WorkingDirectory (Split-Path $exe) -PassThru
    try {
        if (-not $process.WaitForExit(60000)) {
            $process.Kill()
            $process.WaitForExit()
            throw 'Windows bridge phase timed out'
        }
        if ($process.ExitCode -ne 0) {
            throw 'Windows bridge phase failed'
        }
    } finally {
        $process.Dispose()
    }
}

function Wait-ExitMarker([System.Diagnostics.Process] $process, [string] $path) {
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    while (-not (Test-Path $path)) {
        $process.Refresh()
        if ($process.HasExited -or [DateTime]::UtcNow -ge $deadline) {
            throw 'Windows exit marker missing'
        }
        Start-Sleep -Milliseconds 25
    }
    if ((Get-Content -Raw $path) -ne 'TEST_ONLY_EXIT_MARKER') {
        throw 'Windows exit marker invalid'
    }
}

# A marker name must not be observable until its entire payload is closed.
# Keep Wait-ExitMarker's exact-content failure strict; do not retry corrupt data.
function Publish-ExitMarker([string] $path) {
    $pending = $path + '.publishing'
    try {
        [System.IO.File]::WriteAllText($pending, 'TEST_ONLY_EXIT_MARKER')
        [System.IO.File]::Move($pending, $path)
    } finally {
        if (Test-Path $pending) { Remove-Item $pending }
    }
}

function Invoke-WindowExit([string] $phase) {
    $directory = Join-Path ([System.IO.Path]::GetTempPath()) ('nd-' + $scope)
    $process = Start-Process -FilePath $exe -ArgumentList @($phase, $scope) -WorkingDirectory (Split-Path $exe) -PassThru
    try {
        Wait-ExitMarker $process (Join-Path $directory ($phase + '-ready'))
        # Dart's end-of-frame can precede native rasterization/window Show().
        # Wait for an actual visible main HWND before asking .NET to close it.
        $deadline = [DateTime]::UtcNow.AddSeconds(60)
        do {
            $process.Refresh()
            if ($process.HasExited -or [DateTime]::UtcNow -ge $deadline) {
                throw 'Windows main window unavailable'
            }
            if ($process.MainWindowHandle -eq [IntPtr]::Zero) {
                Start-Sleep -Milliseconds 25
            }
        } while ($process.MainWindowHandle -eq [IntPtr]::Zero)
        if (-not $process.CloseMainWindow()) { throw 'Windows close request failed' }
        Wait-ExitMarker $process (Join-Path $directory ($phase + '-closing'))
        if ($phase -eq 'exit-cancel') {
            Wait-ExitMarker $process (Join-Path $directory ($phase + '-canceled'))
        }
        # Drain is unreleased, or cleanup failed: the real process must stay alive.
        if ($process.WaitForExit(1000)) { throw 'Windows exited before owned cleanup' }
        Publish-ExitMarker (Join-Path $directory ($phase + '-release'))
        if ($phase -eq 'exit-cancel') {
            $process.Refresh()
            if (-not $process.CloseMainWindow()) { throw 'Windows close retry failed' }
        }
        if (-not $process.WaitForExit(60000)) { throw 'Windows owned exit timed out' }
        if ($process.ExitCode -ne 0) { throw 'Windows owned exit failed' }
        $done = Join-Path $directory ($phase + '-done')
        if (-not (Test-Path $done) -or (Get-Content -Raw $done) -ne 'TEST_ONLY_EXIT_MARKER') {
            throw 'Windows owned cleanup completion missing'
        }
    } finally {
        $process.Refresh()
        if (-not $process.HasExited) {
            $process.Kill()
            $process.WaitForExit()
        }
        $process.Dispose()
    }
}

# Exact closed-file handshake: Dart GUI stdout is not reliable CI evidence.
# Only this invocation's GUID scope is read; never relay child output or payloads.
function Assert-GrammarFactoryEvidence([string] $path) {
    try {
        $expected = [System.Text.Encoding]::ASCII.GetBytes('TEST_ONLY_GRAMMAR_FACTORY_COMPLETE_V1')
        if (-not [System.IO.File]::Exists($path) -or
            [System.IO.FileInfo]::new($path).Length -ne $expected.Length -or
            [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($path)) -cne [Convert]::ToBase64String($expected)) {
            throw 'Invalid evidence'
        }
    } catch {
        throw 'Windows grammar factory evidence missing or invalid'
    }
}

$evidenceDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('nd-' + $scope)
$grammarEvidence = Join-Path $evidenceDirectory 'grammar-factory-done'
# Negative regressions run in an independent disposable scope. Missing, truncated
# and extra bytes must fail immediately; no timeout/retry can turn them into pass.
$negativeDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('nd-' + $scope + '-grammar-negative')
$negativeEvidence = Join-Path $negativeDirectory 'grammar-factory-done'
try {
    [System.IO.Directory]::CreateDirectory($negativeDirectory) | Out-Null
    foreach ($value in @($null, '', 'TEST_ONLY_GRAMMAR_FACTORY_COMPLETE', "TEST_ONLY_GRAMMAR_FACTORY_COMPLETE_V1`n")) {
        if ($null -ne $value) { [System.IO.File]::WriteAllText($negativeEvidence, $value) }
        $rejected = $false
        try { Assert-GrammarFactoryEvidence $negativeEvidence } catch { $rejected = $true }
        if (-not $rejected) { throw 'Windows grammar evidence rejection regression failed' }
        if (Test-Path $negativeEvidence) { Remove-Item $negativeEvidence }
    }
    # A BOM is extra data, even though ReadAllText would silently strip it.
    $bom = [byte[]](0xEF, 0xBB, 0xBF) + [System.Text.Encoding]::ASCII.GetBytes('TEST_ONLY_GRAMMAR_FACTORY_COMPLETE_V1')
    [System.IO.File]::WriteAllBytes($negativeEvidence, $bom)
    $rejected = $false
    try { Assert-GrammarFactoryEvidence $negativeEvidence } catch { $rejected = $true }
    if (-not $rejected) { throw 'Windows grammar evidence BOM rejection failed' }
    [System.IO.File]::WriteAllText($negativeEvidence, 'TEST_ONLY_GRAMMAR_FACTORY_COMPLETE_V1')
    Assert-GrammarFactoryEvidence $negativeEvidence
} finally {
    if (Test-Path $negativeDirectory) { Remove-Item -Recurse $negativeDirectory }
}

try {
    if (Test-Path $grammarEvidence) { throw 'Windows grammar evidence scope not fresh' }
    Invoke-Bridge 'directory-write'
    Assert-GrammarFactoryEvidence $grammarEvidence
    Write-Output 'Windows opt-in grammar factory/default-off/corruption cleanup/reopen passed (TEST ONLY empty vault)'
    Write-Output 'Windows grammar factory evidence missing/truncated/extra-byte rejection passed (TEST ONLY)'
    Invoke-Bridge 'directory-reopen'
    Invoke-Bridge 'directory-clear'
    Write-Output 'Windows project app-data and staging factory verification passed'
    Invoke-Bridge 'write'
    # Each call starts a fresh Flutter runner, Dart isolate and native channel.
    Invoke-Bridge 'reopen'
    Invoke-Bridge 'rotated'
    Invoke-Bridge 'clear'
    Invoke-Bridge 'absent'
    Write-Output 'Windows Dart/native bridge cross-process verification passed'
    Invoke-Bridge 'receipt-write'
    Invoke-Bridge 'receipt-reopen'
    Invoke-Bridge 'receipt-clear'
    Invoke-Bridge 'receipt-absent'
    Write-Output 'Windows receipt Dart/native bridge metadata isolation/reopen/conflict/clear verification passed (TEST ONLY)'
    Write-Output 'Windows command protection Dart/native roundtrip/bounds/scope/metadata preservation passed (TEST ONLY, no payload persistence)'
    Invoke-Bridge 'receipt-life-write'
    Invoke-Bridge 'receipt-life-reopen'
    Invoke-Bridge 'receipt-life-logout'
    Invoke-Bridge 'receipt-life-absent'
    Write-Output 'Windows actual receipt lifecycle preserve/reopen/no-redispatch/drain/signout/isolation passed (TEST ONLY ports)'
    Invoke-Bridge 'receipt-sdk-write'
    Invoke-Bridge 'receipt-sdk-reopen'
    Invoke-Bridge 'receipt-sdk-clear'
    Invoke-Bridge 'receipt-sdk-absent'
    Write-Output 'Windows same SDK/profile receipt preserve/reopen/no-redispatch/clear passed (TEST ONLY Auth/HTTP)'
    Invoke-Bridge 'receipt-persist-write'
    Invoke-Bridge 'receipt-persist-reopen'
    Invoke-Bridge 'receipt-persist-clear'
    Invoke-Bridge 'receipt-persist-absent'
    Write-Output 'Windows persistent vault/same SDK/profile/receipt rotation preserve/reopen/no-redispatch/logout passed (TEST ONLY Auth/HTTP)'
    Invoke-Bridge 'receipt-owned-write'
    Invoke-Bridge 'receipt-owned-reopen'
    Write-Output 'Windows OWNED receipt lookup unknown/pending/completed preserve/no-redispatch/stale-reader passed (TEST ONLY Auth/HTTP)'
    Write-Output 'Windows OWNED original receipt match/status/mismatch/legacy/stale/no-redispatch passed (TEST ONLY Auth/HTTP)'
    Write-Output 'Windows OWNED SDK/profile command protection all3/corrupt/foreign/stale-close/preserve/no-redispatch passed (TEST ONLY, no payload persistence)'
    Write-Output 'Windows OWNED protected receipt start/status/corrupt/mismatch/stale/preserve/no-redispatch passed (TEST ONLY Auth/HTTP, no payload persistence)'
    Write-Output 'Windows OWNED protected receipt foreign account/project entropy/envelope/no-HTTP/preserve passed (TEST ONLY Auth/HTTP, no payload persistence)'
    Write-Output 'Windows OWNED protected receipt turn/finish/status/binding/stale/preserve/no-redispatch passed (TEST ONLY Auth/HTTP, no payload persistence)'
    Write-Output 'Windows OWNED protected receipt turn/finish original-mismatch/legacy/rejection/preserve/no-redispatch passed (TEST ONLY Auth/HTTP, no payload persistence)'
    Invoke-Bridge 'receipt-owned-logout'
    Write-Output 'Windows OWNED SDK command logout immediate-revoke/stale-protect-unprotect/token-receipt-clear/no-redispatch passed (TEST ONLY, no payload persistence)'
    Invoke-Bridge 'receipt-owned-held-logout'
    Invoke-Bridge 'receipt-owned-absent'
    Write-Output 'Windows OWNED production runtime/vault/receipt restore/preserve/reopen/no-redispatch/held-logout passed (TEST ONLY Auth/HTTP)'
    Invoke-Bridge 'runtime-login'
    Invoke-Bridge 'runtime-restore'
    Invoke-Bridge 'runtime-logout'
    Invoke-Bridge 'runtime-signedout'
    Invoke-Bridge 'runtime-rejected'
    Write-Output 'Windows persistent SDK runtime cross-process verification passed'
    Invoke-WindowExit 'exit-drain'
    Invoke-WindowExit 'exit-cancel'
    Write-Output 'Windows actual cancelable window close and owned drain verification passed'
} finally {
    # Cleanup runs on failure too; cleanup errors fail CI instead of being hidden.
    try {
        Invoke-Bridge 'clear'
    } finally {
        try {
            Invoke-Bridge 'receipt-cleanup'
        } finally {
            try {
                Invoke-Bridge 'receipt-life-cleanup'
            } finally {
                try {
                    Invoke-Bridge 'receipt-sdk-cleanup'
                } finally {
                    try {
                        Invoke-Bridge 'receipt-persist-cleanup'
                    } finally {
                        Invoke-Bridge 'receipt-owned-cleanup'
                    }
                }
            }
        }
    }
}
