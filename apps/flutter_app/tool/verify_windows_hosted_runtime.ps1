$ErrorActionPreference = 'Stop'
$exe = (Resolve-Path 'build/windows/x64/runner/Release/nihongo_daily.exe').Path

function Invoke-HostedPhase([string] $phase) {
    Write-Output "Windows hosted runtime phase started: $phase"
    $process = Start-Process -FilePath $exe -ArgumentList @($phase) -WorkingDirectory (Split-Path $exe) -PassThru -NoNewWindow
    try {
        if (-not $process.WaitForExit(90000)) {
            $process.Kill()
            $process.WaitForExit()
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

try {
    # The hosted Windows runner is ephemeral. Clear only this project's exact
    # Credential Manager target before the process-boundary test starts.
    Invoke-HostedPhase 'cleanup'
    Invoke-HostedPhase 'login-a'
    Invoke-HostedPhase 'restore-a'
    Invoke-HostedPhase 'logout-a'
    Invoke-HostedPhase 'login-b'
} finally {
    # Clear the exact project target even when a phase fails.
    Invoke-HostedPhase 'cleanup'
}
