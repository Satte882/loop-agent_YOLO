param(
    [string]$Repo = 'Satte882/loop-agent_YOLO',
    [ValidateSet('OneShot', 'Poll')]
    [string]$Mode = 'OneShot',
    [int]$IntervalSeconds = 60,
    [int]$MaxIssuesPerRun = 1,
    [int]$CodexTimeoutSeconds = 300,
    [switch]$DryRun,
    [switch]$SkipReviewer,
    [switch]$SkipHealthCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptRoot '..') | Select-Object -ExpandProperty Path
$ArtifactRoot = Join-Path $RepoRoot '.2w'
$PromptPath = Join-Path $ArtifactRoot 'watcher_review_prompt.md'
$ResultPath = Join-Path $ArtifactRoot 'watcher_review_result.md'
$LockPath = Join-Path $ArtifactRoot 'watcher.lock'
$JournalPath = Join-Path $ArtifactRoot 'watcher.journal'
$JournalMaxLines = 500

# ─── Journal ────────────────────────────────────────────────────────────

function Write-Journal {
    param(
        [string]$Level,
        [string]$Message,
        [string]$IssueId = ''
    )

    $timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')
    $line = "[$timestamp] [$Level]"
    if ($IssueId) { $line += " [#$IssueId]" }
    $line += " $Message"

    Write-Host $line

    try {
        New-Item -ItemType Directory -Force -Path $ArtifactRoot | Out-Null
        Add-Content -LiteralPath $JournalPath -Value $line -Encoding UTF8

        # Rotation: keep only last $JournalMaxLines
        $lineCount = (Get-Content -LiteralPath $JournalPath -ReadCount 0 | Measure-Object).Count
        if ($lineCount -gt $JournalMaxLines * 2) {
            $content = Get-Content -LiteralPath $JournalPath -ReadCount 0
            $content[-$JournalMaxLines..-1] | Set-Content -LiteralPath $JournalPath -Encoding UTF8
        }
    }
    catch {
        Write-Host "[JOURNAL_WARN] Could not write journal: $($_.Exception.Message)"
    }
}

# ─── Lock ───────────────────────────────────────────────────────────────

function Acquire-Lock {
    try {
        if (Test-Path -LiteralPath $LockPath) {
            $lockContent = Get-Content -LiteralPath $LockPath -Raw -ErrorAction Stop
            $lockPid = $lockContent.Trim()
            if ($lockPid -and (Get-Process -Id ([int]$lockPid) -ErrorAction SilentlyContinue)) {
                Write-Journal 'WARN' "Lock held by PID $lockPid. Skipping run."
                return $false
            }
            Write-Journal 'WARN' "Stale lock from PID $lockPid found. Releasing."
            Remove-Item -LiteralPath $LockPath -Force -ErrorAction SilentlyContinue
        }
        [System.IO.File]::WriteAllText($LockPath, [string]$PID)
        return $true
    }
    catch {
        Write-Journal 'WARN' "Could not acquire lock: $($_.Exception.Message)"
        return $false
    }
}

function Release-Lock {
    try {
        if (Test-Path -LiteralPath $LockPath) {
            $lockContent = Get-Content -LiteralPath $LockPath -Raw -ErrorAction SilentlyContinue
            if ($lockContent.Trim() -eq [string]$PID) {
                Remove-Item -LiteralPath $LockPath -Force -ErrorAction SilentlyContinue
                Write-Journal 'INFO' 'Lock released.'
            }
        }
    }
    catch {
        Write-Journal 'WARN' "Could not release lock: $($_.Exception.Message)"
    }
}

# ─── Helpers ────────────────────────────────────────────────────────────

function Write-Log {
    param([string]$Level, [string]$Message)
    Write-Journal -Level $Level -Message $Message
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName,
        [string[]]$Arguments = @(),
        [string]$InputText,
        [int]$TimeoutSeconds = 0
    )

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FileName
    $psi.WorkingDirectory = $RepoRoot
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    if ($PSBoundParameters.ContainsKey('InputText')) {
        $psi.RedirectStandardInput = $true
    }
    $psi.Arguments = Join-WindowsArguments -Arguments $Arguments

    $process = [System.Diagnostics.Process]::Start($psi)
    if ($null -eq $process) {
        throw "Failed to start command: $FileName"
    }

    if ($PSBoundParameters.ContainsKey('InputText')) {
        $process.StandardInput.Write($InputText)
        $process.StandardInput.Close()
    }

    if ($TimeoutSeconds -gt 0) {
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $completed) {
            $process.Kill()
            throw "Command timed out after ${TimeoutSeconds}s: $FileName $($Arguments -join ' ')"
        }
    }
    else {
        $process.WaitForExit()
    }

    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()

    if ($process.ExitCode -ne 0) {
        throw @"
Command failed: $FileName $($Arguments -join ' ')
Exit code: $($process.ExitCode)
$stderr
"@
    }

    [pscustomobject]@{
        StdOut   = $stdout
        StdErr   = $stderr
        ExitCode = $process.ExitCode
    }
}

function ConvertTo-WindowsArgument {
    param([AllowNull()][string]$Argument)

    if ($null -eq $Argument -or $Argument.Length -eq 0) {
        return '""'
    }

    if ($Argument -notmatch '[\s"]') {
        return $Argument
    }

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('"')
    $backslashCount = 0

    foreach ($character in $Argument.ToCharArray()) {
        if ($character -eq '\') {
            $backslashCount++
            continue
        }

        if ($character -eq '"') {
            if ($backslashCount -gt 0) {
                [void]$builder.Append('\'.PadLeft($backslashCount * 2, '\'))
                $backslashCount = 0
            }
            [void]$builder.Append('\')
            [void]$builder.Append('"')
            continue
        }

        if ($backslashCount -gt 0) {
            [void]$builder.Append('\'.PadLeft($backslashCount, '\'))
            $backslashCount = 0
        }

        [void]$builder.Append($character)
    }

    if ($backslashCount -gt 0) {
        [void]$builder.Append('\'.PadLeft($backslashCount * 2, '\'))
    }

    [void]$builder.Append('"')
    return $builder.ToString()
}

function Join-WindowsArguments {
    param([string[]]$Arguments)

    @(
        foreach ($argument in $Arguments) {
            ConvertTo-WindowsArgument -Argument $argument
        }
    ) -join ' '
}

function Invoke-GhJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $result = Invoke-NativeCommand -FileName 'gh' -Arguments $Arguments
    $text = $result.StdOut.Trim()

    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    return $text | ConvertFrom-Json
}

function Assert-Prerequisites {
    Write-Log 'INFO' 'Pruefe gh und codex vorab.'
    Invoke-NativeCommand -FileName 'gh' -Arguments @('--version') | Out-Null
    Invoke-NativeCommand -FileName 'gh' -Arguments @('auth', 'status') | Out-Null
    Invoke-NativeCommand -FileName 'codex' -Arguments @('--version') | Out-Null
}

function Test-Health {
    param(
        [switch]$Quick
    )

    try {
        $healthErrors = @()

        # 1. gh auth status
        try {
            Invoke-NativeCommand -FileName 'gh' -Arguments @('auth', 'status') | Out-Null
            Write-Journal 'INFO' 'Health: gh auth OK.'
        }
        catch {
            $healthErrors += "gh auth status failed: $($_.Exception.Message)"
        }

        # 2. codex --version
        try {
            Invoke-NativeCommand -FileName 'codex' -Arguments @('--version') | Out-Null
            Write-Journal 'INFO' 'Health: codex version OK.'
        }
        catch {
            $healthErrors += "codex --version failed: $($_.Exception.Message)"
        }

        # 3. GitHub API repo access
        try {
            Invoke-GhJson -Arguments @('api', "repos/$Repo") | Out-Null
            Write-Journal 'INFO' "Health: repo $Repo accessible via gh API."
        }
        catch {
            $healthErrors += "GitHub API access to $Repo failed: $($_.Exception.Message)"
        }

        # 4. 2W labels exist (quick check)
        if (-not $Quick) {
            try {
                $labels = Invoke-GhJson -Arguments @('api', "repos/$Repo/labels?per_page=100")
                $labelNames = @($labels | ForEach-Object { $_.name })
                $requiredLabels = @('2w:ready', '2w:running', '2w:done', '2w:failed', '2w:reviewed', '2w:complete')
                $missingLabels = $requiredLabels | Where-Object { $_ -notin $labelNames }
                if ($missingLabels.Count -gt 0) {
                    Write-Journal 'WARN' "Health: Missing labels: $($missingLabels -join ', ')"
                    $healthErrors += "Missing 2W labels: $($missingLabels -join ', ')"
                }
                else {
                    Write-Journal 'INFO' 'Health: All 2W labels present.'
                }
            }
            catch {
                Write-Journal 'WARN' "Health: Could not verify labels: $($_.Exception.Message)"
            }
        }

        if ($healthErrors.Count -gt 0) {
            Write-Journal 'ERROR' "Health check FAILED:`n$($healthErrors -join "`n")"
            return $false
        }

        Write-Journal 'INFO' 'Health check PASSED.'
        return $true
    }
    catch {
        Write-Journal 'ERROR' "Health check exception: $($_.Exception.Message)"
        return $false
    }
}

function Get-LabelNames {
    param([object[]]$Labels)

    @(
        foreach ($label in $Labels) {
            if ($null -ne $label -and $label.PSObject.Properties['name']) {
                $label.name
            }
        }
    )
}

function Test-Label {
    param(
        [string[]]$Labels,
        [string]$Name
    )

    $Labels -contains $Name
}

function Normalize-Comments {
    param([object]$Comments)

    if ($null -eq $Comments) {
        return @()
    }

    if ($Comments -is [System.Collections.IEnumerable] -and $Comments -isnot [string]) {
        return @($Comments)
    }

    return @($Comments)
}

function Get-IssueComments {
    param(
        [Parameter(Mandatory = $true)]
        [int]$IssueNumber
    )

    $endpoint = "repos/$Repo/issues/$IssueNumber/comments?per_page=100"
    Normalize-Comments (Invoke-GhJson -Arguments @('api', $endpoint))
}

function Get-LatestDoneComment {
    param([object[]]$Comments)

    $doneComments = @(
        $Comments | Where-Object {
            $_.body -and $_.body.TrimStart().StartsWith('2W_DONE')
        } | Sort-Object {
            [datetime]($_.created_at)
        } -Descending
    )

    if ($doneComments.Count -eq 0) {
        return $null
    }

    return $doneComments[0]
}

function Get-LatestFailureCommentAfter {
    param(
        [object[]]$Comments,
        [datetime]$After
    )

    $failureComments = @(
        $Comments | Where-Object {
            $_.body -and $_.body.TrimStart().StartsWith('2W_FAILED') -and [datetime]($_.created_at) -gt $After
        } | Sort-Object {
            [datetime]($_.created_at)
        } -Descending
    )

    if ($failureComments.Count -eq 0) {
        return $null
    }

    return $failureComments[0]
}

function Get-CommitShaFromDoneComment {
    param([string]$Body)

    if ([string]::IsNullOrWhiteSpace($Body)) {
        return $null
    }

    $match = [regex]::Match($Body, '(?m)^commit=(?<sha>[0-9a-fA-F]{7,40}|none)\s*$')
    if (-not $match.Success) {
        return $null
    }

    $sha = $match.Groups['sha'].Value
    if ($sha -eq 'none') {
        return $null
    }

    return $sha.ToLowerInvariant()
}

function Get-CommitData {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoName,
        [Parameter(Mandatory = $true)]
        [string]$CommitSha
    )

    Invoke-GhJson -Arguments @('api', "repos/$RepoName/commits/$CommitSha")
}

function Get-2WDoneIssues {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoName
    )

    $issues = Invoke-GhJson -Arguments @(
        'issue', 'list',
        '--repo', $RepoName,
        '--state', 'open',
        '--label', '2w:done',
        '--limit', '100',
        '--json', 'number,title,body,labels,url,createdAt,updatedAt'
    )

    if ($null -eq $issues) {
        return @()
    }

    $normalizedIssues = @($issues)
    $filtered = foreach ($issue in $normalizedIssues) {
        $labelNames = Get-LabelNames -Labels $issue.labels
        if (Test-Label -Labels $labelNames -Name '2w:reviewed') {
            continue
        }

        $comments = Get-IssueComments -IssueNumber ([int]$issue.number)
        $doneComment = Get-LatestDoneComment -Comments $comments
        if ($null -eq $doneComment) {
            continue
        }

        $failureComment = Get-LatestFailureCommentAfter -Comments $comments -After ([datetime]$doneComment.created_at)
        if ($null -ne $failureComment -and (Test-Label -Labels $labelNames -Name '2w:failed')) {
            Write-Log 'INFO' ("Ueberspringe Issue #{0}: 2w:failed nach letztem 2W_DONE." -f $issue.number)
            continue
        }

        [pscustomobject]@{
            Number        = [int]$issue.number
            Title         = [string]$issue.title
            Body          = [string]$issue.body
            Labels        = $labelNames
            Url           = [string]$issue.url
            Comments      = $comments
            DoneComment   = $doneComment
            CommitSha     = Get-CommitShaFromDoneComment -Body $doneComment.body
            LatestFailure = $failureComment
        }
    }

    @($filtered) | Sort-Object {
        try {
            [datetime]($_.DoneComment.created_at)
        }
        catch {
            [datetime]::MinValue
        }
    } -Descending
}

function Trim-Text {
    param(
        [AllowNull()]
        [string]$Text,
        [int]$MaxLength = 8000
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    if ($Text.Length -le $MaxLength) {
        return $Text.Trim()
    }

    return ($Text.Substring(0, $MaxLength).TrimEnd() + "`n... [truncated]")
}

function Format-CommentBlock {
    param([object[]]$Comments)

    $lines = foreach ($comment in $Comments) {
        $author = if ($comment.user -and $comment.user.login) { $comment.user.login } else { 'unknown' }
        $created = if ($comment.created_at) { $comment.created_at } else { 'unknown' }
        "### $created | @$author`n$(Trim-Text $comment.body 2500)"
    }

    if ($lines.Count -eq 0) {
        return 'none'
    }

    return ($lines -join "`n`n")
}

function Format-CommitFiles {
    param([object[]]$Files)

    if ($null -eq $Files -or $Files.Count -eq 0) {
        return 'none'
    }

    $blocks = foreach ($file in $Files) {
        $summary = "{0} | +{1} -{2} | {3}" -f $file.filename, $file.additions, $file.deletions, $file.status
        $patch = if ($file.patch) { Trim-Text $file.patch 5000 } else { '[no patch provided]' }
        "$summary`n$patch"
    }

    return ($blocks -join "`n`n")
}

function Build-ReviewerPrompt {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Issue,
        [Parameter(Mandatory = $true)]
        [object]$CommitData
    )

    $files = if ($CommitData.files) { @($CommitData.files) } else { @() }
    $labels = if ($Issue.Labels) { $Issue.Labels -join ', ' } else { 'none' }
    $commentBlock = Format-CommentBlock -Comments $Issue.Comments
    $patchBlock = Format-CommitFiles -Files $files
    $commitMessage = if ($CommitData.commit -and $CommitData.commit.message) { $CommitData.commit.message } else { 'none' }
    $commitAuthor = if ($CommitData.commit -and $CommitData.commit.author -and $CommitData.commit.author.name) { $CommitData.commit.author.name } else { 'unknown' }
    $commitDate = if ($CommitData.commit -and $CommitData.commit.author -and $CommitData.commit.author.date) { $CommitData.commit.author.date } else { 'unknown' }

    @"
You are the local reviewer for a 2W issue.

Return exactly this machine-readable format:
DECISION: COMPLETE|NEXT_ISSUE|FIX_ISSUE|BLOCKED
TITLE: <required for NEXT_ISSUE and FIX_ISSUE, otherwise omit>
BODY: <required for NEXT_ISSUE and FIX_ISSUE, may be multiline until REASON:>
REASON: <short reason>

Rules:
- Be strict and fail closed.
- If the issue state is unclear, choose BLOCKED.
- Do not invent missing commit data.
- If you propose a new issue, keep it small and concrete.
- Keep the answer terse and parseable.

Repository: $Repo
Issue: #$($Issue.Number)
Title: $($Issue.Title)
Issue URL: $($Issue.Url)
Labels: $labels

Issue body:
$(Trim-Text $Issue.Body 6000)

Comments:
$commentBlock

Latest 2W_DONE comment:
$(Trim-Text $Issue.DoneComment.body 6000)

Parsed data from 2W_DONE:
commit_sha=$($Issue.CommitSha)
tests=$((($Issue.DoneComment.body -split "`n") | Where-Object { $_ -like 'tests=*' } | Select-Object -First 1))
codex_exit_code=$((($Issue.DoneComment.body -split "`n") | Where-Object { $_ -like 'codex_exit_code=*' } | Select-Object -First 1))

Commit:
sha=$($CommitData.sha)
message=$commitMessage
author=$commitAuthor
date=$commitDate

Changed files and patches:
$patchBlock
"@
}

function Invoke-CodexReviewer {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PromptText
    )

    New-Item -ItemType Directory -Force -Path $ArtifactRoot | Out-Null
    Set-Content -LiteralPath $PromptPath -Value $PromptText -Encoding UTF8

    try {
        $result = Invoke-NativeCommand -FileName 'codex' -Arguments @(
            'exec',
            '--sandbox', 'workspace-write',
            '--skip-git-repo-check',
            '--output-last-message', $ResultPath,
            '-'
        ) -InputText $PromptText -TimeoutSeconds $CodexTimeoutSeconds

        $reviewText = if (Test-Path -LiteralPath $ResultPath) {
            Get-Content -LiteralPath $ResultPath -Raw
        }
        else {
            $result.StdOut
        }

        [pscustomobject]@{
            ExitCode = $result.ExitCode
            Review   = $reviewText
        }
    }
    finally {
        Remove-Item -LiteralPath $PromptPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $ResultPath -Force -ErrorAction SilentlyContinue
    }
}

function Parse-ReviewerDecision {
    param([Parameter(Mandatory = $true)][string]$Text)

    $decision = $null
    $title = $null
    $bodyLines = New-Object System.Collections.Generic.List[string]
    $reasonLines = New-Object System.Collections.Generic.List[string]
    $section = $null

    foreach ($rawLine in ($Text -split "`r?`n")) {
        $line = $rawLine.TrimEnd()

        if ($line -match '^DECISION:\s*(?<value>[A-Z_]+)\s*$') {
            $decision = $matches.value.ToUpperInvariant()
            $section = $null
            continue
        }

        if ($line -match '^TITLE:\s*(?<value>.*)\s*$') {
            $title = $matches.value.Trim()
            $section = $null
            continue
        }

        if ($line -match '^BODY:\s*(?<value>.*)\s*$') {
            $section = 'BODY'
            $bodyValue = $matches.value
            if (-not [string]::IsNullOrWhiteSpace($bodyValue)) {
                [void]$bodyLines.Add($bodyValue)
            }
            continue
        }

        if ($line -match '^REASON:\s*(?<value>.*)\s*$') {
            $section = 'REASON'
            $reasonValue = $matches.value
            if (-not [string]::IsNullOrWhiteSpace($reasonValue)) {
                [void]$reasonLines.Add($reasonValue)
            }
            continue
        }

        switch ($section) {
            'BODY' { [void]$bodyLines.Add($rawLine) }
            'REASON' { [void]$reasonLines.Add($rawLine) }
        }
    }

    $body = ($bodyLines -join "`n").Trim()
    $reason = ($reasonLines -join "`n").Trim()

    if ($decision -notin @('COMPLETE', 'NEXT_ISSUE', 'FIX_ISSUE', 'BLOCKED')) {
        return [pscustomobject]@{
            Decision = 'BLOCKED'
            Title    = $null
            Body     = $null
            Reason   = 'Reviewer output did not contain a valid decision.'
        }
    }

    if ([string]::IsNullOrWhiteSpace($reason)) {
        return [pscustomobject]@{
            Decision = 'BLOCKED'
            Title    = $null
            Body     = $null
            Reason   = 'Reviewer output did not contain a reason.'
        }
    }

    if ($decision -in @('NEXT_ISSUE', 'FIX_ISSUE') -and [string]::IsNullOrWhiteSpace($title)) {
        return [pscustomobject]@{
            Decision = 'BLOCKED'
            Title    = $null
            Body     = $null
            Reason   = 'Reviewer proposed a follow-up issue without a title.'
        }
    }

    if ($decision -in @('NEXT_ISSUE', 'FIX_ISSUE') -and [string]::IsNullOrWhiteSpace($body)) {
        return [pscustomobject]@{
            Decision = 'BLOCKED'
            Title    = $null
            Body     = $null
            Reason   = 'Reviewer proposed a follow-up issue without a body.'
        }
    }

    [pscustomobject]@{
        Decision = $decision
        Title    = $title
        Body     = $body
        Reason   = $reason
    }
}

function Add-IssueLabel {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoName,
        [Parameter(Mandatory = $true)]
        [int]$IssueNumber,
        [Parameter(Mandatory = $true)]
        [string[]]$Labels
    )

    $args = @('api', "repos/$RepoName/issues/$IssueNumber/labels", '-X', 'POST')
    foreach ($label in $Labels) {
        $args += @('-f', "labels[]=$label")
    }

    Invoke-GhJson -Arguments $args | Out-Null
}

function Add-IssueComment {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoName,
        [Parameter(Mandatory = $true)]
        [int]$IssueNumber,
        [Parameter(Mandatory = $true)]
        [string]$Body
    )

    Invoke-GhJson -Arguments @(
        'api',
        "repos/$RepoName/issues/$IssueNumber/comments",
        '-X', 'POST',
        '-f', "body=$Body"
    ) | Out-Null
}

function New-NextIssue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoName,
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $true)]
        [string]$Body
    )

    Invoke-GhJson -Arguments @(
        'api',
        "repos/$RepoName/issues",
        '-X', 'POST',
        '-f', "title=$Title",
        '-f', "body=$Body",
        '-f', 'labels[]=2w:ready'
    )
}

function Update-CompleteIssue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoName,
        [Parameter(Mandatory = $true)]
        [int]$IssueNumber,
        [Parameter(Mandatory = $true)]
        [string]$Reason
    )

    Add-IssueLabel -RepoName $RepoName -IssueNumber $IssueNumber -Labels @('2w:complete', '2w:reviewed')
    Add-IssueComment -RepoName $RepoName -IssueNumber $IssueNumber -Body ("2W_REVIEWED`n`nDECISION: COMPLETE`nREASON: {0}" -f $Reason)
}

function Update-FollowUpIssue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoName,
        [Parameter(Mandatory = $true)]
        [object]$Issue,
        [Parameter(Mandatory = $true)]
        [string]$Decision,
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $true)]
        [string]$Body,
        [Parameter(Mandatory = $true)]
        [string]$Reason
    )

    $finalTitle = switch ($Decision) {
        'FIX_ISSUE' {
            if ($Title.StartsWith('2W_READY: fix', [System.StringComparison]::OrdinalIgnoreCase)) {
                $Title
            }
            elseif ($Title.StartsWith('2W_READY:', [System.StringComparison]::OrdinalIgnoreCase)) {
                '2W_READY: fix ' + (($Title -replace '^(?i)2W_READY:\s*', '')).Trim()
            }
            else {
                "2W_READY: fix $Title"
            }
        }
        default {
            if ($Title.StartsWith('2W_READY:', [System.StringComparison]::OrdinalIgnoreCase)) {
                $Title
            }
            else {
                "2W_READY: $Title"
            }
        }
    }

    $newIssue = New-NextIssue -RepoName $RepoName -Title $finalTitle -Body $Body
    $newNumber = [int]$newIssue.number
    Add-IssueComment -RepoName $RepoName -IssueNumber $Issue.Number -Body ("2W_REVIEWED`n`nDECISION: {0}`nNEXT_ISSUE: #{1}`nREASON: {2}" -f $Decision, $newNumber, $Reason)
    Add-IssueLabel -RepoName $RepoName -IssueNumber $Issue.Number -Labels @('2w:reviewed')
    return $newIssue
}

function Mark-BlockedIssue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoName,
        [Parameter(Mandatory = $true)]
        [int]$IssueNumber,
        [Parameter(Mandatory = $true)]
        [string]$Reason
    )

    Add-IssueComment -RepoName $RepoName -IssueNumber $IssueNumber -Body ("2W_REVIEW_BLOCKED`n`nREASON: {0}" -f $Reason)
}

function Process-OneIssue {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Issue,
        [switch]$DryRun,
        [switch]$SkipReviewer
    )

    Write-Log 'INFO' ("Verarbeite Issue #{0}: {1}" -f $Issue.Number, $Issue.Title)

    if ([string]::IsNullOrWhiteSpace($Issue.CommitSha)) {
        Write-Log 'BLOCKED' ("Issue #{0} hat keine Commit-SHA im letzten 2W_DONE." -f $Issue.Number)
        if (-not $DryRun) {
            Mark-BlockedIssue -RepoName $Repo -IssueNumber $Issue.Number -Reason 'Missing commit SHA in latest 2W_DONE comment.'
        }
        return [pscustomobject]@{
            Decision = 'BLOCKED'
            Reason   = 'Missing commit SHA in latest 2W_DONE comment.'
        }
    }

    $commitData = $null
    try {
        $commitData = Get-CommitData -RepoName $Repo -CommitSha $Issue.CommitSha
    }
    catch {
        Write-Log 'BLOCKED' ("Commit {0} konnte nicht per GitHub API geladen werden." -f $Issue.CommitSha)
        if (-not $DryRun) {
            Mark-BlockedIssue -RepoName $Repo -IssueNumber $Issue.Number -Reason "GitHub API could not load commit $($Issue.CommitSha)."
        }
        return [pscustomobject]@{
            Decision = 'BLOCKED'
            Reason   = "GitHub API could not load commit $($Issue.CommitSha)."
        }
    }

    $promptText = Build-ReviewerPrompt -Issue $Issue -CommitData $commitData

    if (-not $SkipReviewer) {
        Write-Log 'INFO' 'Starte lokalen Codex-Reviewer.'
        try {
            $reviewRun = Invoke-CodexReviewer -PromptText $promptText
            $reviewText = $reviewRun.Review
            if ([string]::IsNullOrWhiteSpace($reviewText)) {
                throw 'Reviewer returned an empty response.'
            }
            $review = Parse-ReviewerDecision -Text $reviewText
            Write-Log 'INFO' ("Reviewer-Entscheidung: {0}" -f $review.Decision)
        }
        catch {
            $review = [pscustomobject]@{
                Decision = 'BLOCKED'
                Title    = $null
                Body     = $null
                Reason   = "Reviewer unavailable or unreadable: $($_.Exception.Message)"
            }
            Write-Log 'BLOCKED' $review.Reason
        }
    }
    else {
        $review = [pscustomobject]@{
            Decision = 'BLOCKED'
            Title    = $null
            Body     = $null
            Reason   = 'Reviewer skipped by -SkipReviewer.'
        }
        Write-Log 'INFO' 'Reviewer wurde per -SkipReviewer uebersprungen.'
    }

    if ($DryRun) {
        Write-Log 'DRYRUN' ("Wuerde auf Issue #{0} reagieren: {1}" -f $Issue.Number, $review.Decision)
        switch ($review.Decision) {
            'COMPLETE' {
                Write-Log 'DRYRUN' 'Wuerde Labels 2w:complete und 2w:reviewed setzen und 2W_REVIEWED kommentieren.'
            }
            'NEXT_ISSUE' {
                Write-Log 'DRYRUN' ("Wuerde neues Issue erstellen: {0}" -f $review.Title)
            }
            'FIX_ISSUE' {
                Write-Log 'DRYRUN' ("Wuerde Fix-Issue erstellen: {0}" -f $review.Title)
            }
            default {
                Write-Log 'DRYRUN' ("Wuerde BLOCKED kommentieren: {0}" -f $review.Reason)
            }
        }

        return [pscustomobject]@{
            Decision = $review.Decision
            Reason   = $review.Reason
        }
    }

    switch ($review.Decision) {
        'COMPLETE' {
            Update-CompleteIssue -RepoName $Repo -IssueNumber $Issue.Number -Reason $review.Reason
            Write-Log 'INFO' ("Issue #{0} als abgeschlossen markiert." -f $Issue.Number)
        }
        'NEXT_ISSUE' {
            $newIssue = Update-FollowUpIssue -RepoName $Repo -Issue $Issue -Decision $review.Decision -Title $review.Title -Body $review.Body -Reason $review.Reason
            Write-Log 'INFO' ("Neues Issue #{0} erstellt." -f $newIssue.number)
        }
        'FIX_ISSUE' {
            $newIssue = Update-FollowUpIssue -RepoName $Repo -Issue $Issue -Decision $review.Decision -Title $review.Title -Body $review.Body -Reason $review.Reason
            Write-Log 'INFO' ("Fix-Issue #{0} erstellt." -f $newIssue.number)
        }
        default {
            Mark-BlockedIssue -RepoName $Repo -IssueNumber $Issue.Number -Reason $review.Reason
            Write-Log 'BLOCKED' ("Issue #{0} bleibt ohne 2w:reviewed, weil BLOCKED." -f $Issue.Number)
        }
    }

    return [pscustomobject]@{
        Decision = $review.Decision
        Reason   = $review.Reason
    }
}

function Invoke-2WWatcherOnce {
    param(
        [switch]$DryRun,
        [switch]$SkipReviewer,
        [switch]$SkipHealthCheck
    )

    Assert-Prerequisites

    if (-not $SkipHealthCheck) {
        Write-Log 'INFO' 'Fuehre Health-Check vor Poll-Schleife aus.'
        $healthOk = Test-Health -Quick
        if (-not $healthOk) {
            Write-Log 'ERROR' 'Health-Check fehlgeschlagen. Breche ab.'
            return
        }
        Write-Log 'INFO' 'Health-Check erfolgreich.'
    }

    $eligibleIssues = Get-2WDoneIssues -RepoName $Repo
    if ($eligibleIssues.Count -eq 0) {
        Write-Log 'INFO' 'Keine offenen 2w:done-Issues ohne 2w:reviewed gefunden.'
        return
    }

    $limit = [Math]::Max(1, $MaxIssuesPerRun)
    $processed = 0

    foreach ($issue in $eligibleIssues) {
        if ($processed -ge $limit) {
            break
        }

        [void](Process-OneIssue -Issue $issue -DryRun:$DryRun -SkipReviewer:$SkipReviewer)
        $processed++
    }
}

# ─── Main ───────────────────────────────────────────────────────────

try {
    Push-Location $RepoRoot

    $lockAcquired = Acquire-Lock
    if (-not $lockAcquired) {
        Write-Journal 'WARN' 'Watcher already running (lock held). Exiting.'
        exit 0
    }

    Write-Journal 'INFO' "Watcher started (Repo=$Repo Mode=$Mode PID=$PID)"

    if ($Mode -eq 'Poll') {
        Write-Journal 'INFO' ("Starte Poll-Modus mit Intervall {0}s. Codex-Timeout: {1}s." -f $IntervalSeconds, $CodexTimeoutSeconds)

        # Full health check before entering poll loop
        if (-not $SkipHealthCheck) {
            $initialHealth = Test-Health
            if (-not $initialHealth) {
                Write-Journal 'ERROR' 'Initialer Health-Check fehlgeschlagen. Beende Poll-Loop.'
                exit 1
            }
        }

        while ($true) {
            Invoke-2WWatcherOnce -DryRun:$DryRun -SkipReviewer:$SkipReviewer -SkipHealthCheck:$true
            Write-Journal 'INFO' ("Warte {0}s bis zum naechsten Poll-Durchlauf." -f $IntervalSeconds)
            Start-Sleep -Seconds $IntervalSeconds
        }
    }
    else {
        Invoke-2WWatcherOnce -DryRun:$DryRun -SkipReviewer:$SkipReviewer -SkipHealthCheck:$SkipHealthCheck
    }
}
catch {
    Write-Journal 'ERROR' "Unbehandelter Fehler: $($_.Exception.Message)"
    throw
}
finally {
    Release-Lock
    Pop-Location
}