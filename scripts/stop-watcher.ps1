<#
.SYNOPSIS
    Beendet einen laufenden 2W Watcher.

.DESCRIPTION
    Findet den Watcher-Prozess anhand der Lock-Datei und beendet ihn.
    Falls keine Lock-Datei existiert, wird nach PowerShell-Prozessen
    mit "2w-watcher.ps1" in der Kommandozeile gesucht.

.PARAMETER Force
    Beendet den Prozess auch ohne Lock-Datei (sucht nach Watcher-Prozessen).

.EXAMPLE
    .\scripts\stop-watcher.ps1
    Beendet den Watcher über die Lock-Datei.

.EXAMPLE
    .\scripts\stop-watcher.ps1 -Force
    Sucht und beendet Watcher-Prozesse auch ohne Lock-Datei.
#>

param(
    [switch]$Force
)

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptRoot '..') | Select-Object -ExpandProperty Path
$LockPath = Join-Path $RepoRoot '.2w/watcher.lock'

$found = $false

# Methode 1: Lock-Datei
if (Test-Path -LiteralPath $LockPath) {
    try {
        $lockPid = (Get-Content -LiteralPath $LockPath -Raw).Trim()
        if ($lockPid) {
            $pidNum = [int]$lockPid
            $proc = Get-Process -Id $pidNum -ErrorAction SilentlyContinue
            if ($proc) {
                Write-Host "[STOP] Found watcher process PID $pidNum ($($proc.ProcessName)). Stopping..."
                $proc.Kill()
                Write-Host "[STOP] Process PID $pidNum stopped."
                $found = $true
            }
            else {
                Write-Host "[STOP] Lock file points to PID $pidNum, but process not found. (Stale lock)"
            }
        }
        Remove-Item -LiteralPath $LockPath -Force -ErrorAction SilentlyContinue
        Write-Host "[STOP] Lock file removed."
    }
    catch {
        Write-Host "[STOP] Error reading lock file: $($_.Exception.Message)"
    }
}
else {
    Write-Host "[STOP] No lock file found at $LockPath"
}

# Methode 2: Prozess-Suche (bei -Force oder wenn Lock erfolglos)
if ($Force -or -not $found) {
    $watcherProcesses = @(Get-Process -Name 'pwsh', 'powershell' -ErrorAction SilentlyContinue | Where-Object {
        $cmdline = $_.CommandLine 2>$null
        if (-not $cmdline) {
            try { $cmdline = (Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $($_.Id)").CommandLine } catch {}
        }
        if ($cmdline) {
            $cmdline -match '2w-watcher\.ps1'
        }
    })

    if ($watcherProcesses.Count -gt 0) {
        foreach ($proc in $watcherProcesses) {
            Write-Host "[STOP] Found watcher process PID $($proc.Id) via command line search. Stopping..."
            $proc.Kill()
            Write-Host "[STOP] Process PID $($proc.Id) stopped."
            $found = $true
        }
    }
    else {
        Write-Host "[STOP] No running watcher processes found."
    }
}

if (-not $found) {
    Write-Host "[STOP] No active watcher detected. Nothing to stop."
}