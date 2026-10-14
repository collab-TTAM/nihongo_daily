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
} finally {
    # Cleanup runs on failure too; cleanup errors fail CI instead of being hidden.
    Invoke-Bridge 'clear'
}
