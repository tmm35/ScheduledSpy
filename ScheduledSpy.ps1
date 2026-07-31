$ErrorActionPreference = 'SilentlyContinue'
$IntervalMs  = 100
$Date = Get-Date -Format "HH:mm:ss"

# Process names to skip entirely - both as the new process itself AND as its
# parent, since Chrome's multi-process model means most of the noise is
# renderer/GPU/utility children spawned BY chrome.exe, not chrome.exe itself.
$ExcludeNames = @('chrome.exe')

$consoleWidth = 80
try { $consoleWidth = $Host.UI.RawUI.WindowSize.Width } catch {}

if ($consoleWidth -ge 65) {
    $banner = @"
+---------------------------------------------------------+
|                S C H E D U L E D S P Y                  |
+---------------------------------------------------------+
"@
    Write-Host $banner -ForegroundColor Cyan
}
else {
    Write-Host "=== ScheduledSpy ===" -ForegroundColor Cyan
}

Write-Host "[*] Ctrl+C to stop"
Write-Host "[*] Execution Time: $Date"
Write-Host ""
Write-Host ("{0,-10} | {1,-20} | {2,-20} | {3,-8} | {4,-20} | {5,-6} | {6}" -f "Timestamp", "User", "ProcessName", "PPID", "ParentName", "PID", "FullCommandLine")
Write-Host ("-" * 130)

function Get-ProcOwner {
    param($ProcessId)
    try {
        $p = Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId"
        if ($p) {
            $owner = Invoke-CimMethod -InputObject $p -MethodName GetOwner
            if ($owner.ReturnValue -eq 0) { return "$($owner.Domain)\$($owner.User)" }
        }
    } catch {}
    return "unknown"
}

# Track previous PID set - just IDs, not full objects, keeps the diff cheap.
$prevPids = New-Object System.Collections.Generic.HashSet[int]
foreach ($p in (Get-CimInstance Win32_Process -Property ProcessId)) { [void]$prevPids.Add($p.ProcessId) }

try {
    while ($true) {
        Start-Sleep -Milliseconds $IntervalMs

        $snap = Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId, Name, CommandLine, ExecutablePath
        $currPids = New-Object System.Collections.Generic.HashSet[int]
        $byPid = @{}
        foreach ($p in $snap) {
            [void]$currPids.Add($p.ProcessId)
            $byPid[$p.ProcessId] = $p
        }

        foreach ($p in $snap) {
            if ($prevPids.Contains($p.ProcessId)) { continue }   # not new

            $parentName = if ($byPid.ContainsKey($p.ParentProcessId)) { $byPid[$p.ParentProcessId].Name } else { 'exited/unknown' }

            if ($ExcludeNames -contains $p.Name -or $ExcludeNames -contains $parentName) { continue }

            $ts   = [DateTime]::Now.ToString('HH:mm:ss')
            $user = Get-ProcOwner $p.ProcessId
            $cmd  = if ($p.CommandLine) { $p.CommandLine } elseif ($p.ExecutablePath) { $p.ExecutablePath } else { '(no access to cmdline)' }

            Write-Host ("{0,-10} | {1,-20} | {2,-20} | {3,-8} | {4,-20} | {5,-6} | {6}" -f `
                $ts, $user, $p.Name, $p.ParentProcessId, $parentName, $p.ProcessId, $cmd) -ForegroundColor Yellow
        }

        $prevPids = $currPids
    }
}
finally {
    Write-Host "[*] stopped"
}
