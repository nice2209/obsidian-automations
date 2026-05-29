#Requires -Version 5.1
<#
.SYNOPSIS
    Saves a Claude/LLM session learning to Obsidian LLM Wiki.

.EXAMPLE
    .\llm_wiki.ps1 -Title "nodriver vs camoufox" -Tags "scraping,python" -Content "nodriver wins on Korean finance..."
    .\llm_wiki.ps1 -Title "My learning" -FromClipboard
    .\llm_wiki.ps1 -Title "My learning" -FromClipboard -Project "Money-Engine"
#>
param(
    [Parameter(Mandatory)][string]$Title,
    [string]$Tags          = "",
    [string]$Content       = "",
    [string]$Project       = "",
    [switch]$FromClipboard,
    [switch]$NoSync
)

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_config.ps1")

$WIKI_DIR = Join-Path $VAULT "LLM Wiki"
if (-not (Test-Path $WIKI_DIR)) { New-Item -ItemType Directory -Path $WIKI_DIR -Force | Out-Null }

if ($FromClipboard) {
    if (Get-Command Get-Clipboard -ErrorAction SilentlyContinue) {
        $Content = Get-Clipboard -Raw
    } else {
        # Mac fallback
        $Content = & pbpaste
    }
}

if (-not $Content -or $Content.Trim() -eq "") {
    Write-Error "Content is empty. Use -Content '...' or -FromClipboard."
    exit 1
}

$now      = Get-TzNow
$dateStr  = $now.ToString("yyyy-MM-dd")
$timeStr  = $now.ToString("HH:mm")
$safeName = $Title -replace '[/\\:*?"<>|]', '-'
$outPath  = Join-Path $WIKI_DIR "$dateStr - $safeName.md"

$tagYaml     = if ($Tags) { "[$( ($Tags -split ',') | ForEach-Object { "`"$($_.Trim())`"" } | Join-String -Separator ', ')]" } else { "[]" }
$projectYaml = if ($Project) { "`nproject: `"$Project`"" } else { "" }

$note = @"
---
title: "$Title"
date: $dateStr
tags: $tagYaml$projectYaml
source: claude-session
---

# $Title

> Saved: $dateStr $timeStr (UTC+$TZ_OFFSET)

$($Content.Trim())
"@

[System.IO.File]::WriteAllText($outPath, $note, [System.Text.Encoding]::UTF8)
Write-Host "Saved: $outPath"

if (-not $NoSync) {
    Sync-Vault "LLM Wiki/" "wiki: $Title"
}
