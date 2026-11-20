$ErrorActionPreference = 'Stop'
$scope = 'bridge-' + [Guid]::NewGuid().ToString('N')
$exe = (Resolve-Path 'build/windows/x64/runner/Release/nihongo_daily.exe').Path

function Invoke-Bridge([string] $phase) {
    Write-Output "Windows bridge phase started: $phase"
    $diagnosticId = [Guid]::NewGuid().ToString('N')
    $stdoutPath = Join-Path ([System.IO.Path]::GetTempPath()) ("nd-bridge-$diagnosticId.out")
    $stderrPath = Join-Path ([System.IO.Path]::GetTempPath()) ("nd-bridge-$diagnosticId.err")
    $process = Start-Process -FilePath $exe -ArgumentList @($phase, $scope) -WorkingDirectory (Split-Path $exe) -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru
    try {
        if (-not $process.WaitForExit(60000)) {
            $process.Kill()
            $process.WaitForExit()
            throw "Windows bridge phase '$phase' timed out"
        }
        if ($process.ExitCode -ne 0) {
            # The TEST ONLY runner emits only a fixed message and bounded stack
            # locations. Never print exception text, request bodies or tokens.
            if (Test-Path -LiteralPath $stderrPath -PathType Leaf) {
                foreach ($line in @(Get-Content -LiteralPath $stderrPath -Tail 12)) {
                    Write-Output $line
                }
            }
            throw "Windows bridge phase '$phase' failed (exit code $($process.ExitCode))"
        }
    } finally {
        $process.Dispose()
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
    Write-Output "Windows bridge phase passed: $phase"
}

function Wait-BridgeMarker([System.Diagnostics.Process] $process, [string] $path, [string] $expected) {
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    while ([DateTime]::UtcNow -lt $deadline) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            try {
                if ([System.IO.File]::ReadAllText($path) -ceq $expected) { return }
            } catch [System.IO.IOException] {
                # The runner may still be completing the marker write.
            }
        }
        $process.Refresh()
        if ($process.HasExited) { throw 'Windows owner lease holder exited early' }
        Start-Sleep -Milliseconds 25
    }
    throw 'Windows owner lease marker timed out'
}

function Invoke-OwnerLeaseContention() {
    $directory = Join-Path ([System.IO.Path]::GetTempPath()) ('nd-' + $scope)
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $readyPath = Join-Path $directory 'owner-ready'
    $releasePath = Join-Path $directory 'owner-release'
    $donePath = Join-Path $directory 'owner-done'
    Remove-Item -LiteralPath @($readyPath, $releasePath, $donePath) -Force -ErrorAction SilentlyContinue
    $diagnosticId = [Guid]::NewGuid().ToString('N')
    $stdoutPath = Join-Path ([System.IO.Path]::GetTempPath()) ("nd-owner-$diagnosticId.out")
    $stderrPath = Join-Path ([System.IO.Path]::GetTempPath()) ("nd-owner-$diagnosticId.err")
    $holder = $null
    try {
        $holder = Start-Process -FilePath $exe -ArgumentList @('runtime-owner-hold', $scope) -WorkingDirectory (Split-Path $exe) -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru
        Wait-BridgeMarker $holder $readyPath 'TEST_ONLY_OWNER_READY'
        # This is a separate runner process and native mutex handle. It must fail
        # before its one-shot read fault can be consumed by the vault read path.
        Invoke-Bridge 'runtime-owner-contend'
        [System.IO.File]::WriteAllText($releasePath, 'TEST_ONLY_OWNER_RELEASE')
        if (-not $holder.WaitForExit(60000)) { throw 'Windows owner lease holder timed out' }
        if ($holder.ExitCode -ne 0) {
            if (Test-Path -LiteralPath $stderrPath -PathType Leaf) {
                foreach ($line in @(Get-Content -LiteralPath $stderrPath -Tail 12)) { Write-Output $line }
            }
            throw 'Windows owner lease holder failed'
        }
        if (-not (Test-Path -LiteralPath $donePath -PathType Leaf)) { throw 'Windows owner lease release marker missing' }
        if ([System.IO.File]::ReadAllText($donePath) -cne 'TEST_ONLY_OWNER_RELEASED') { throw 'Windows owner lease release marker invalid' }
        Write-Output 'Windows cross-process native owner lease contention passed'
        # A third process proves the first lease was released, not merely that
        # the competing process failed for an unrelated startup reason.
        Invoke-Bridge 'runtime-owner-reacquire'
    } finally {
        if ($null -ne $holder) {
            $holder.Refresh()
            if (-not $holder.HasExited) {
                [System.IO.File]::WriteAllText($releasePath, 'TEST_ONLY_OWNER_RELEASE')
                if (-not $holder.WaitForExit(10000)) {
                    $holder.Kill()
                    $holder.WaitForExit()
                }
            }
            $holder.Dispose()
        }
        Remove-Item -LiteralPath @($stdoutPath, $stderrPath) -Force -ErrorAction SilentlyContinue
    }
}

function Wait-ExitMarker([System.Diagnostics.Process] $process, [string] $path) {
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    $observedFile = $false
    while ([DateTime]::UtcNow -lt $deadline) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $observedFile = $true
            try {
                # File creation can precede completion of Dart's asynchronous write.
                if ([System.IO.File]::ReadAllText($path) -ceq 'TEST_ONLY_EXIT_MARKER') {
                    return
                }
            } catch [System.IO.IOException] {
                # The writer may still hold the short-lived file handle.
            }
        }
        $process.Refresh()
        if ($process.HasExited) {
            throw 'Windows exit marker missing'
        }
        Start-Sleep -Milliseconds 25
    }
    if ($observedFile) {
        throw 'Windows exit marker invalid'
    }
    throw 'Windows exit marker missing'
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
    # A new process must persist rotation before releasing a held own-profile response.
    Invoke-Bridge 'runtime-restore-profile-held'
    Invoke-Bridge 'runtime-restore'
    Invoke-Bridge 'runtime-logout'
    Invoke-Bridge 'runtime-signedout'
    Invoke-Bridge 'runtime-rejected'
    Invoke-Bridge 'runtime-native-read-failure'
    Invoke-Bridge 'runtime-signedout'
    # Exercise a real CredWriteW commit/ambiguous error plus failed clear through
    # the pinned SDK owner; B must wait for A's exact-slot cleanup before Auth.
    Invoke-Bridge 'runtime-native-rotation-write-failure'
    Invoke-Bridge 'runtime-signedout'
    # Combine native refresh-write/compensation failure with a held A profile;
    # B must remain isolated when A's captured response is released after B ready.
    Invoke-Bridge 'runtime-native-rotation-write-failure-late-profile'
    Invoke-Bridge 'runtime-signedout'
    # Exercise a CredWriteW failure before commit; compensation must clear A
    # before B can authenticate, and a fresh process must remain signed out.
    Invoke-Bridge 'runtime-native-rotation-write-fail-before'
    Invoke-Bridge 'runtime-signedout'
    # A failed native CredDeleteW must retain A and fence B until explicit logout retry.
    Invoke-Bridge 'runtime-native-logout-clear-failure'
    Invoke-Bridge 'runtime-signedout'
    # A committed delete with a lost acknowledgement must still fence B until explicit retry.
    Invoke-Bridge 'runtime-native-logout-clear-commit-failure'
    Invoke-Bridge 'runtime-signedout'
    Invoke-Bridge 'runtime-late-refresh'
    # Hold A's real OS-backed own-profile response across logout and B readiness.
    Invoke-Bridge 'runtime-late-profile'
    Invoke-Bridge 'runtime-signedout'
    # Close a fresh owner during held startup restore, then prove a new process
    # observes the cleared OS credential slot.
    Invoke-Bridge 'runtime-close-restore'
    Invoke-Bridge 'runtime-signedout'
    Write-Output 'Windows persistent SDK runtime cross-process verification passed'
    Invoke-Bridge 'clear'
    Invoke-OwnerLeaseContention
    Invoke-WindowExit 'exit-drain'
    Invoke-WindowExit 'exit-cancel'
    Write-Output 'Windows actual cancelable window close and owned drain verification passed'
} finally {
    # Cleanup runs on failure too; cleanup errors fail CI instead of being hidden.
    Invoke-Bridge 'clear'
}

# Remove the compile-time hook and rebuild the same TEST ONLY Dart entrypoint.
# The following staging and learner-preview builds also inherit OFF from CMake.
cmake -S windows -B build/windows/x64 -DND_SESSION_VAULT_TEST_HOOKS=OFF
if ($LASTEXITCODE -ne 0) { throw 'Disabling native vault test hooks failed' }
cmake --build build/windows/x64 --config Release --target nihongo_daily
if ($LASTEXITCODE -ne 0) { throw 'Rebuilding without native vault test hooks failed' }
Invoke-Bridge 'native-test-hook-absent'
Write-Output 'Native vault test hooks absent from uninstrumented runner'
