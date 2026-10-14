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

function Invoke-WindowExit([string] $phase) {
    $directory = Join-Path ([System.IO.Path]::GetTempPath()) ('nd-' + $scope)
    $process = Start-Process -FilePath $exe -ArgumentList @($phase, $scope) -WorkingDirectory (Split-Path $exe) -PassThru
    try {
        Wait-ExitMarker $process (Join-Path $directory ($phase + '-ready'))
        $process.Refresh()
        if (-not $process.CloseMainWindow()) { throw 'Windows close request failed' }
        Wait-ExitMarker $process (Join-Path $directory ($phase + '-closing'))
        if ($phase -eq 'exit-cancel') {
            Wait-ExitMarker $process (Join-Path $directory ($phase + '-canceled'))
        }
        # Drain is unreleased, or cleanup failed: the real process must stay alive.
        if ($process.WaitForExit(1000)) { throw 'Windows exited before owned cleanup' }
        [System.IO.File]::WriteAllText((Join-Path $directory ($phase + '-release')), 'TEST_ONLY_EXIT_MARKER')
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

try {
    Invoke-Bridge 'directory-write'
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
    Invoke-Bridge 'clear'
}
