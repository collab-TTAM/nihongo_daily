$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
    throw 'Windows hosted runtime probe requires a GitHub-hosted runner'
}
$exe = (Resolve-Path 'build/windows/x64/runner/Release/nihongo_daily.exe').Path

function Invoke-HostedPhase([string] $phase) {
    Write-Output "Windows hosted runtime phase started: $phase"
    $process = Start-Process -FilePath $exe -ArgumentList @($phase) -WorkingDirectory (Split-Path $exe) -PassThru -NoNewWindow
    try {
        if (-not $process.WaitForExit(90000)) {
            # The phase can exit between the timeout and kill checks. Refresh
            # before killing, and tolerate only that natural-exit race.
            $process.Refresh()
            if (-not $process.HasExited) {
                try {
                    $process.Kill($true)
                } catch {
                    $process.Refresh()
                    if (-not $process.HasExited) {
                        throw "Windows hosted runtime phase '$phase' timed out; child termination could not be requested"
                    }
                }
            }
            # Never wait indefinitely after a timeout. Final project cleanup
            # still runs in the caller's finally block if termination is stuck.
            if (-not $process.WaitForExit(15000)) {
                throw "Windows hosted runtime phase '$phase' timed out; child termination could not be verified"
            }
            throw "Windows hosted runtime phase '$phase' timed out"
        }
        if ($process.ExitCode -ne 0) {
            throw "Windows hosted runtime phase '$phase' failed (exit code $($process.ExitCode))"
        }
    } finally {
        $process.Dispose()
    }
    Write-Output "Windows hosted runtime phase passed: $phase"
}

$currentPhase = 'cleanup'
$phaseFailure = $null
$cleanupFailure = $false
try {
    # The hosted Windows runner is ephemeral. Clear only this project's exact
    # Credential Manager target before the process-boundary test starts.
    Invoke-HostedPhase 'cleanup'
    $currentPhase = 'login-a'
    Invoke-HostedPhase 'login-a'
    $currentPhase = 'restore-a'
    Invoke-HostedPhase 'restore-a'
    $currentPhase = 'logout-a'
    Invoke-HostedPhase 'logout-a'
    $currentPhase = 'login-b'
    Invoke-HostedPhase 'login-b'
} catch {
    # Keep only the fixed phase identifier; never echo an ErrorRecord that
    # could contain environment or process details.
    $phaseFailure = $currentPhase
} finally {
    try {
        # Always retry exact-project cleanup after the process sequence.
        Invoke-HostedPhase 'cleanup'
    } catch {
        $cleanupFailure = $true
    }
}
if ($null -ne $phaseFailure) {
    if ($cleanupFailure) {
        throw "Windows hosted runtime phase '$phaseFailure' failed; final cleanup could not be verified"
    }
    throw "Windows hosted runtime phase '$phaseFailure' failed"
}
if ($cleanupFailure) {
    throw 'Windows hosted runtime final cleanup could not be verified'
}
