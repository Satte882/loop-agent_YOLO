<#
.SYNOPSIS
    Startet den 2W Watcher im Poll-Modus. Task-Scheduler-kompatibel.

.DESCRIPTION
    Dieses Skript startet den 2W Watcher im Poll-Modus (Standard: 60s Intervall).
    Es kann direkt aus der PowerShell oder über den Windows Task Scheduler
    gestartet werden. Protokolliert Start/Stop ins Watcher-Journal.

.PARAMETER Repo
    GitHub-Repository im Format "owner/repo". Default: Satte882/loop-agent_YOLO

.PARAMETER IntervalSeconds
    Poll-Intervall in Sekunden. Default: 60

.PARAMETER CodexTimeoutSeconds
    Timeout für jeden codex exec-Aufruf in Sekunden. Default: 300

.PARAMETER MaxIssuesPerRun
    Maximal zu verarbeitende Issues pro Poll-Durchlauf. Default: 1

.PARAMETER NoReviewer
    Überspringt den Codex-Reviewer (nur für Tests).

.PARAMETER LogFile
    Optional: Pfad zu einer Logdatei für die Konsolenausgabe.

.EXAMPLE
    .\scripts\start-watcher.ps1
    Startet mit Standardwerten.

.EXAMPLE
    .\scripts\start-watcher.ps1 -Repo "Satte882/loop-agent_YOLO" -IntervalSeconds 120 -CodexTimeoutSeconds 600
    Startet mit eigenem Repo, 2 Minuten Intervall, 10 Minuten Codex-Timeout.

.EXAMPLE
    # Per Task Scheduler (als PowerShell-Aktion):
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\pfad\zu\loop-agent_YOLO\scripts\start-watcher.ps1"
#>

param(
    [string]$Repo = 'Satte882/loop-agent_YOLO',
    [int]$IntervalSeconds = 60,
    [int]$CodexTimeoutSeconds = 300,
    [int]$MaxIssuesPerRun = 1,
    [switch]$NoReviewer,
    [string]$LogFile = ''
)

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$WatcherPath = Join-Path $ScriptRoot '2w-watcher.ps1'

# Optional: Konsolenausgabe in Logdatei umleiten
if ($LogFile) {
    $logDir = Split-Path -Parent $LogFile
    if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    }
    Start-Transcript -Path $LogFile -Append | Out-Null
}

Write-Host "[START] 2W Watcher starting..."
Write-Host "[START] Repo: $Repo"
Write-Host "[START] Interval: ${IntervalSeconds}s"
Write-Host "[START] Codex Timeout: ${CodexTimeoutSeconds}s"
Write-Host "[START] Max Issues/Run: $MaxIssuesPerRun"
Write-Host "[START] SkipReviewer: $($NoReviewer.IsPresent)"

$watcherArgs = @(
    '-Repo', $Repo,
    '-Mode', 'Poll',
    '-IntervalSeconds', $IntervalSeconds,
    '-CodexTimeoutSeconds', $CodexTimeoutSeconds,
    '-MaxIssuesPerRun', $MaxIssuesPerRun
)
if ($NoReviewer) { $watcherArgs += '-SkipReviewer' }

try {
    & $WatcherPath @watcherArgs
}
catch {
    Write-Host "[START] Watcher terminated with error: $($_.Exception.Message)"
    exit 1
}
finally {
    if ($LogFile) {
        Stop-Transcript | Out-Null
    }
}