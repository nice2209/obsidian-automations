#Requires -Version 5.1
<#
.SYNOPSIS
    Fetches GitHub activity and writes it to Obsidian vault as markdown notes.
    Runs every hour via Windows Task Scheduler.
#>

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

# --- Config ---
$USERNAME    = "nice2209"
$VAULT       = "C:\Users\16912\Documents\Obsidian Vault"
$ACTIVITY_DIR = Join-Path $VAULT "GitHub Activity"
$DAILY_DIR   = Join-Path $ACTIVITY_DIR "Daily"
$PROJECTS_DIR = Join-Path $ACTIVITY_DIR "Projects"
$LOG_FILE    = Join-Path $env:TEMP "github-to-obsidian.log"

function Write-Log {
    param([string]$Message)
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "$ts  $Message" | Tee-Object -FilePath $LOG_FILE -Append | Write-Host
}

# KST = UTC+9
function Get-KstNow { (Get-Date).ToUniversalTime().AddHours(9) }
function ConvertTo-Kst { param([string]$IsoString)
    [datetime]::Parse($IsoString, $null, [System.Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime().AddHours(9)
}

# --- Fetch events (3 pages) ---
Write-Log "Fetching GitHub events for $USERNAME ..."
$token = (gh auth token 2>&1).Trim()
$headers = @{ Authorization = "token $token"; "User-Agent" = "github-to-obsidian/1.0" }
$allEvents = @()
for ($page = 1; $page -le 3; $page++) {
    try {
        $uri = "https://api.github.com/users/$USERNAME/events?per_page=100&page=$page"
        $parsed = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        if ($parsed.Count -eq 0) { break }
        $allEvents += $parsed
    } catch {
        Write-Log "Page $page fetch failed: $_"
        break
    }
}
Write-Log "Total events fetched: $($allEvents.Count)"

# --- Prepare output dirs ---
foreach ($dir in @($DAILY_DIR, $PROJECTS_DIR)) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

# --- Group events by KST date ---
$byDate   = @{}  # "2026-05-27" -> list of formatted lines
$byRepo   = @{}  # "owner/repo" -> list of formatted lines

function Add-Entry {
    param([string]$Date, [string]$Repo, [string]$Line)
    if (-not $byDate.ContainsKey($Date)) { $byDate[$Date] = [System.Collections.Generic.List[string]]::new() }
    $byDate[$Date].Add($Line)
    if (-not $byRepo.ContainsKey($Repo))  { $byRepo[$Repo]  = [System.Collections.Generic.List[string]]::new() }
    $byRepo[$Repo].Add("[$Date] $Line")
}

foreach ($ev in $allEvents) {
    $kst  = ConvertTo-Kst $ev.created_at
    $date = $kst.ToString("yyyy-MM-dd")
    $time = $kst.ToString("HH:mm")
    $repo = $ev.repo.name  # "owner/repo"

    switch ($ev.type) {
        "PushEvent" {
            $branch  = $ev.payload.ref -replace "^refs/heads/", ""
            $commits = $ev.payload.commits
            $count   = if ($commits) { $commits.Count } else { 0 }
            $msgs    = if ($commits) {
                ($commits | Select-Object -First 3 | ForEach-Object { "  - $($_.message -split "`n" | Select-Object -First 1)" }) -join "`n"
            } else { "" }
            $line = "- ``$time`` **Push** to ``$repo/$branch`` ($count commit(s))`n$msgs"
            Add-Entry $date $repo $line
        }
        "PullRequestEvent" {
            $pr     = $ev.payload.pull_request
            $action = $ev.payload.action
            $title  = $pr.title
            $url    = $pr.html_url
            $line   = "- ``$time`` **PR $action**: [$title]($url) in ``$repo``"
            Add-Entry $date $repo $line
        }
        "IssuesEvent" {
            $issue  = $ev.payload.issue
            $action = $ev.payload.action
            $title  = $issue.title
            $url    = $issue.html_url
            $line   = "- ``$time`` **Issue $action**: [$title]($url) in ``$repo``"
            Add-Entry $date $repo $line
        }
        "CreateEvent" {
            $refType = $ev.payload.ref_type
            $ref     = $ev.payload.ref
            $line    = "- ``$time`` **Created** $refType ``$ref`` in ``$repo``"
            Add-Entry $date $repo $line
        }
        "ReleaseEvent" {
            $release = $ev.payload.release
            $action  = $ev.payload.action
            $tag     = $release.tag_name
            $url     = $release.html_url
            $line    = "- ``$time`` **Release $action**: [$tag]($url) in ``$repo``"
            Add-Entry $date $repo $line
        }
        "IssueCommentEvent" {
            $issue  = $ev.payload.issue
            $url    = $ev.payload.comment.html_url
            $line   = "- ``$time`` **Comment** on [#$($issue.number) $($issue.title)]($url) in ``$repo``"
            Add-Entry $date $repo $line
        }
        "PullRequestReviewEvent" {
            $pr     = $ev.payload.pull_request
            $state  = $ev.payload.review.state
            $line   = "- ``$time`` **Review ($state)**: [$($pr.title)]($($pr.html_url)) in ``$repo``"
            Add-Entry $date $repo $line
        }
    }
}

# --- Write daily notes ---
foreach ($date in $byDate.Keys | Sort-Object -Descending) {
    $path = Join-Path $DAILY_DIR "$date.md"

    # Load existing note if present, find the marker
    $existingLines = @()
    if (Test-Path $path) {
        $existingLines = Get-Content $path -Encoding UTF8
    }

    $header = @(
        "# GitHub Activity — $date",
        "",
        "> Auto-generated by github-to-obsidian. Last updated: $(Get-KstNow | Get-Date -Format 'yyyy-MM-dd HH:mm') KST",
        ""
    )
    $body   = $byDate[$date] -join "`n`n"
    $content = ($header -join "`n") + $body + "`n"
    [System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)
    Write-Log "Written: $path"
}

# --- Write per-project notes ---
foreach ($repo in $byRepo.Keys | Sort-Object) {
    $safeName = $repo -replace "[/\\:*?`"<>|]", "-"
    $path = Join-Path $PROJECTS_DIR "$safeName.md"

    $header = @(
        "# $repo",
        "",
        "> Auto-generated by github-to-obsidian. Last updated: $(Get-KstNow | Get-Date -Format 'yyyy-MM-dd HH:mm') KST",
        ""
    )
    $body    = $byRepo[$repo] -join "`n`n"
    $content = ($header -join "`n") + $body + "`n"
    [System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)
    Write-Log "Written: $path"
}

# --- Write README index ---
$readmePath = Join-Path $ACTIVITY_DIR "README.md"
$repoLinks  = ($byRepo.Keys | Sort-Object | ForEach-Object {
    $safeName = $_ -replace "[/\\:*?`"<>|]", "-"
    "- [[$safeName]] ($_)"
}) -join "`n"

$dailyLinks = ($byDate.Keys | Sort-Object -Descending | Select-Object -First 14 | ForEach-Object {
    "- [[$_]]"
}) -join "`n"

$readme = @"
# GitHub Activity Index

> Last updated: $(Get-KstNow | Get-Date -Format 'yyyy-MM-dd HH:mm') KST

## Recent Days
$dailyLinks

## Projects
$repoLinks
"@
[System.IO.File]::WriteAllText($readmePath, $readme, [System.Text.Encoding]::UTF8)
Write-Log "Written README index"

# --- Commit and push vault ---
Write-Log "Committing vault ..."
$gitArgs = "-C `"$VAULT`""
$commitMsg = "chore: github activity sync $(Get-KstNow | Get-Date -Format 'yyyy-MM-dd HH:mm') KST"

try {
    $status = git -C $VAULT status --porcelain 2>&1
    if ($status) {
        git -C $VAULT add "GitHub Activity/" 2>&1 | Write-Log
        git -C $VAULT commit -m $commitMsg 2>&1 | Write-Log
        git -C $VAULT push origin main 2>&1 | Write-Log
        Write-Log "Vault pushed successfully."
    } else {
        Write-Log "No changes to commit."
    }
} catch {
    Write-Log "Git push failed: $_"
}

Write-Log "Done."
