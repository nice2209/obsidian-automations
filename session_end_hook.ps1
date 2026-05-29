#Requires -Version 5.1
<#
.SYNOPSIS
    Claude Code Stop hook — saves .omc/notepad.md to LLM Wiki if content exists.
    Registered in ~/.claude/settings.json as a Stop hook (async).
#>

Set-StrictMode -Off
$ErrorActionPreference = "SilentlyContinue"   # Hook must not crash Claude Code

# Resolve project dir — Claude Code sets working directory to project root
$projectDir  = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { $PWD.Path }
$projectName = Split-Path $projectDir -Leaf

# Check for OMC notepad (written by /remember, /wiki, etc.)
$notepadPath = Join-Path $projectDir ".omc\notepad.md"
if (-not (Test-Path $notepadPath)) { exit 0 }

$content = (Get-Content $notepadPath -Raw -Encoding UTF8).Trim()
if ($content.Length -lt 30) { exit 0 }    # Skip trivially short notes

$title = "Session: $projectName"

# Call llm_wiki.ps1 from the same Scripts folder
$wikiScript = Join-Path $PSScriptRoot "llm_wiki.ps1"
if (-not (Test-Path $wikiScript)) { exit 0 }

try {
    & powershell -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass `
        -File $wikiScript `
        -Title $title `
        -Content $content `
        -Tags "session,$projectName" `
        -Project $projectName `
        -NoSync
} catch {
    # Silently fail — hook must never block Claude Code exit
}
