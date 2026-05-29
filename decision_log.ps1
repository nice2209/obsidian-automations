#Requires -Version 5.1
<#
.SYNOPSIS
    Appends an Architecture Decision Record to Obsidian Decision Log.

.EXAMPLE
    .\decision_log.ps1 -Decision "Use SQLite" -Reason "Zero setup, embedded" -Context "Money-Engine"
    .\decision_log.ps1 -Decision "Drop nodriver" -Reason "Unstable API" -Alternatives "camoufox, playwright" -Status "rejected"
#>
param(
    [Parameter(Mandatory)][string]$Decision,
    [Parameter(Mandatory)][string]$Reason,
    [string]$Context      = "",
    [string]$Alternatives = "",
    [string]$Status       = "accepted",   # accepted | rejected | superseded | deprecated
    [switch]$NoSync
)

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_config.ps1")

$DECISION_DIR = Join-Path $VAULT "Decision Log"
if (-not (Test-Path $DECISION_DIR)) { New-Item -ItemType Directory -Path $DECISION_DIR -Force | Out-Null }

$now      = Get-TzNow
$monthStr = $now.ToString("yyyy-MM")
$dateStr  = $now.ToString("yyyy-MM-dd")
$timeStr  = $now.ToString("HH:mm")
$outPath  = Join-Path $DECISION_DIR "$monthStr.md"

$contextLine  = if ($Context)      { "`n`n**Context:** $Context" }                       else { "" }
$altLine      = if ($Alternatives) { "`n`n**Alternatives considered:** $Alternatives" }  else { "" }

$entry = @"


---

## $dateStr $timeStr — $Decision

**Status:** $Status
**Reason:** $Reason$contextLine$altLine

"@

if (-not (Test-Path $outPath)) {
    [System.IO.File]::WriteAllText($outPath, "# Decision Log — $monthStr`n", [System.Text.Encoding]::UTF8)
}
[System.IO.File]::AppendAllText($outPath, $entry, [System.Text.Encoding]::UTF8)
Write-Host "Logged: $outPath"

if (-not $NoSync) {
    Sync-Vault "Decision Log/" "decision: $Decision"
}
