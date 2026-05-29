#Requires -Version 5.1
<#
.SYNOPSIS
    Generates a weekly GitHub activity summary in Obsidian.
    Runs every Sunday via Windows Task Scheduler (or launchd on Mac).
#>

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_config.ps1")

$WEEKLY_DIR = Join-Path $VAULT "Weekly Reports"
if (-not (Test-Path $WEEKLY_DIR)) { New-Item -ItemType Directory -Path $WEEKLY_DIR -Force | Out-Null }

$now       = Get-TzNow
$weekStart = $now.AddDays(-6).Date
$weekEnd   = $now.Date
$weekNum   = "$($now.ToString('yyyy'))-W$(Get-Date $now -UFormat '%V')"
$outPath   = Join-Path $WEEKLY_DIR "$weekNum.md"

Write-Log "Generating weekly report $weekNum ..." "weekly-report"

$token   = (gh auth token 2>&1).Trim()
$headers = @{ Authorization = "token $token"; "User-Agent" = "obsidian-automations/1.0" }

$allEvents = @()
for ($page = 1; $page -le 5; $page++) {
    try {
        $parsed = Invoke-RestMethod -Uri "https://api.github.com/users/$GH_USER/events?per_page=100&page=$page" -Headers $headers
        if ($parsed.Count -eq 0) { break }
        $allEvents += $parsed
    } catch { break }
}

$weekEvents = $allEvents | Where-Object {
    $d = ConvertTo-Tz $_.created_at
    $d.Date -ge $weekStart -and $d.Date -le $weekEnd
}

$pushCount    = 0; $commitCount = 0; $prCount = 0; $issueCount = 0; $releaseCount = 0
$repoSet      = [System.Collections.Generic.HashSet[string]]::new()
$highlights   = [System.Collections.Generic.List[string]]::new()

foreach ($ev in $weekEvents) {
    $repoSet.Add($ev.repo.name) | Out-Null
    switch ($ev.type) {
        "PushEvent" {
            $pushCount++
            $commitCount += if ($ev.payload.commits) { $ev.payload.commits.Count } else { 0 }
        }
        "PullRequestEvent" {
            if ($ev.payload.action -in @("opened", "merged")) {
                $prCount++
                $highlights.Add("- **PR $($ev.payload.action)**: [$($ev.payload.pull_request.title)]($($ev.payload.pull_request.html_url))")
            }
        }
        "IssuesEvent" {
            if ($ev.payload.action -eq "opened") {
                $issueCount++
                $highlights.Add("- **Issue opened**: [$($ev.payload.issue.title)]($($ev.payload.issue.html_url))")
            }
        }
        "ReleaseEvent" {
            if ($ev.payload.action -eq "published") {
                $releaseCount++
                $highlights.Add("- **Release**: [$($ev.payload.release.tag_name)]($($ev.payload.release.html_url)) in ``$($ev.repo.name)``")
            }
        }
    }
}

$repoList      = if ($repoSet.Count) { ($repoSet | Sort-Object | ForEach-Object { "- ``$_``" }) -join "`n" } else { "_No activity._" }
$highlightText = if ($highlights.Count) { $highlights -join "`n" } else { "_No notable events._" }

$report = @"
# Weekly Report — $weekNum

> Period: $($weekStart.ToString('yyyy-MM-dd')) ~ $($weekEnd.ToString('yyyy-MM-dd'))
> Generated: $($now.ToString('yyyy-MM-dd HH:mm')) (UTC+$TZ_OFFSET)

## Stats

| Metric | Count |
|--------|-------|
| Pushes | $pushCount |
| Commits | $commitCount |
| PRs opened/merged | $prCount |
| Issues opened | $issueCount |
| Releases | $releaseCount |
| Repos touched | $($repoSet.Count) |

## Repos Active This Week

$repoList

## Highlights

$highlightText

## Reflection

<!-- What went well? What was hard? What to focus on next week? -->

"@

[System.IO.File]::WriteAllText($outPath, $report, [System.Text.Encoding]::UTF8)
Write-Log "Written: $outPath" "weekly-report"

Sync-Vault "Weekly Reports/" "chore: weekly report $weekNum"
Write-Log "Done." "weekly-report"
