#Requires -Version 5.1
<#
.SYNOPSIS
    Fetches GitHub activity and writes it to Obsidian vault as markdown notes.
    Runs every hour via Windows Task Scheduler (or launchd on Mac).
#>

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_config.ps1")

$ACTIVITY_DIR = Join-Path $VAULT "GitHub Activity"
$DAILY_DIR    = Join-Path $ACTIVITY_DIR "Daily"
$PROJECTS_DIR = Join-Path $ACTIVITY_DIR "Projects"

Write-Log "Fetching GitHub events for $GH_USER ..." "github-to-obsidian"

$token = (gh auth token 2>&1).Trim()
if ($LASTEXITCODE -ne 0 -or -not $token) { Write-Log "gh auth token failed — aborting" "github-to-obsidian"; exit 1 }
$headers = @{ Authorization = "token $token"; "User-Agent" = "obsidian-automations/1.0" }

$allEvents = @()
for ($page = 1; $page -le 3; $page++) {
    try {
        $parsed = Invoke-RestMethod -Uri "https://api.github.com/users/$GH_USER/events?per_page=100&page=$page" -Headers $headers
        if ($parsed.Count -eq 0) { break }
        $allEvents += $parsed
    } catch {
        Write-Log "Page $page fetch failed: $_" "github-to-obsidian"
        break
    }
}
Write-Log "Total events fetched: $($allEvents.Count)" "github-to-obsidian"

foreach ($dir in @($DAILY_DIR, $PROJECTS_DIR)) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

$byDate = @{}
$byRepo = @{}

function Add-Entry {
    param([string]$Date, [string]$Repo, [string]$Line)
    if (-not $byDate.ContainsKey($Date)) { $byDate[$Date] = [System.Collections.Generic.List[string]]::new() }
    $byDate[$Date].Add($Line)
    if (-not $byRepo.ContainsKey($Repo))  { $byRepo[$Repo]  = [System.Collections.Generic.List[string]]::new() }
    $byRepo[$Repo].Add("[$Date] $Line")
}

foreach ($ev in $allEvents) {
    $kst  = ConvertTo-Tz $ev.created_at
    $date = $kst.ToString("yyyy-MM-dd")
    $time = $kst.ToString("HH:mm")
    $repo = $ev.repo.name

    switch ($ev.type) {
        "PushEvent" {
            $branch  = $ev.payload.ref -replace "^refs/heads/", ""
            $commits = $ev.payload.commits
            $count   = if ($commits) { $commits.Count } else { 0 }
            $msgs    = if ($commits) {
                ($commits | Select-Object -First 3 | ForEach-Object { "  - $($_.message -split "`n" | Select-Object -First 1)" }) -join "`n"
            } else { "" }
            Add-Entry $date $repo "- ``$time`` **Push** to ``$repo/$branch`` ($count commit(s))`n$msgs"
        }
        "PullRequestEvent" {
            $pr   = $ev.payload.pull_request
            Add-Entry $date $repo "- ``$time`` **PR $($ev.payload.action)**: [$($pr.title)]($($pr.html_url)) in ``$repo``"
        }
        "IssuesEvent" {
            $issue = $ev.payload.issue
            Add-Entry $date $repo "- ``$time`` **Issue $($ev.payload.action)**: [$($issue.title)]($($issue.html_url)) in ``$repo``"
        }
        "CreateEvent" {
            Add-Entry $date $repo "- ``$time`` **Created** $($ev.payload.ref_type) ``$($ev.payload.ref)`` in ``$repo``"
        }
        "ReleaseEvent" {
            $rel = $ev.payload.release
            Add-Entry $date $repo "- ``$time`` **Release $($ev.payload.action)**: [$($rel.tag_name)]($($rel.html_url)) in ``$repo``"
        }
        "IssueCommentEvent" {
            $issue = $ev.payload.issue
            Add-Entry $date $repo "- ``$time`` **Comment** on [#$($issue.number) $($issue.title)]($($ev.payload.comment.html_url)) in ``$repo``"
        }
        "PullRequestReviewEvent" {
            $pr = $ev.payload.pull_request
            Add-Entry $date $repo "- ``$time`` **Review ($($ev.payload.review.state))**: [$($pr.title)]($($pr.html_url)) in ``$repo``"
        }
    }
}

$now = Get-TzNow

foreach ($date in $byDate.Keys | Sort-Object -Descending) {
    $path    = Join-Path $DAILY_DIR "$date.md"
    $header  = "# GitHub Activity — $date`n`n> Auto-generated. Last updated: $($now.ToString('yyyy-MM-dd HH:mm')) (UTC+$TZ_OFFSET)`n`n"
    $content = $header + ($byDate[$date] -join "`n`n") + "`n"
    [System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)
    Write-Log "Written: $path" "github-to-obsidian"
}

foreach ($repo in $byRepo.Keys | Sort-Object) {
    $safeName = $repo -replace '[/\\:*?"<>|]', "-"
    $path     = Join-Path $PROJECTS_DIR "$safeName.md"
    $header   = "# $repo`n`n> Auto-generated. Last updated: $($now.ToString('yyyy-MM-dd HH:mm')) (UTC+$TZ_OFFSET)`n`n"
    $content  = $header + ($byRepo[$repo] -join "`n`n") + "`n"
    [System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)
    Write-Log "Written: $path" "github-to-obsidian"
}

$repoLinks  = ($byRepo.Keys | Sort-Object | ForEach-Object { $safe = $_ -replace '[/\\:*?"<>|]', "-"; "- [[$safe]] ($_)" }) -join "`n"
$dailyLinks = ($byDate.Keys | Sort-Object -Descending | Select-Object -First 14 | ForEach-Object { "- [[$_]]" }) -join "`n"
$readme     = "# GitHub Activity Index`n`n> Last updated: $($now.ToString('yyyy-MM-dd HH:mm')) (UTC+$TZ_OFFSET)`n`n## Recent Days`n$dailyLinks`n`n## Projects`n$repoLinks`n"
[System.IO.File]::WriteAllText((Join-Path $ACTIVITY_DIR "README.md"), $readme, [System.Text.Encoding]::UTF8)

Sync-Vault "GitHub Activity/" "chore: github activity sync $($now.ToString('yyyy-MM-dd HH:mm')) (UTC+$TZ_OFFSET)"
Write-Log "Done." "github-to-obsidian"
