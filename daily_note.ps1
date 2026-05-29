#Requires -Version 5.1
<#
.SYNOPSIS
    Creates today's Daily Note in Obsidian with a structured template.
    Runs every morning at 08:00 via Windows Task Scheduler.
    Skips creation if today's note already exists.
#>

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_config.ps1")

$DAILY_DIR = Join-Path $VAULT "daily"
if (-not (Test-Path $DAILY_DIR)) { New-Item -ItemType Directory -Path $DAILY_DIR -Force | Out-Null }

$now      = Get-TzNow
$dateStr  = $now.ToString("yyyy-MM-dd")
$dayName  = $now.ToString("dddd")
$outPath  = Join-Path $DAILY_DIR "$dateStr.md"

if (Test-Path $outPath) {
    Write-Log "Daily note already exists: $outPath" "daily-note"
    exit 0
}

Write-Log "Creating daily note for $dateStr ..." "daily-note"

# Pull today's GitHub activity summary if available
$githubSummary = ""
$githubDaily   = Join-Path $VAULT "GitHub Activity\Daily\$dateStr.md"
if (Test-Path $githubDaily) {
    $lines = Get-Content $githubDaily -Encoding UTF8 | Where-Object { $_ -match "^\- " } | Select-Object -First 5
    if ($lines) {
        $githubSummary = "`n" + ($lines -join "`n")
    }
}

$note = @"
---
date: $dateStr
day: $dayName
---

# $dateStr ($dayName)

## Goals

- [ ]

## GitHub Today
$( if ($githubSummary) { $githubSummary } else { "`n_No activity yet._" } )

## Notes



## Reflection

> What went well?

> What was hard?

> What carries over to tomorrow?

"@

[System.IO.File]::WriteAllText($outPath, $note, [System.Text.Encoding]::UTF8)
Write-Log "Created: $outPath" "daily-note"

Sync-Vault "daily/" "chore: daily note $dateStr"
Write-Log "Done." "daily-note"
