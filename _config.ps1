#Requires -Version 5.1
<#
.SYNOPSIS
    Shared config loader. Dot-source this in every script:
        . (Join-Path $PSScriptRoot "_config.ps1")
    Loads config.yaml if present, then auto-detects missing values.
    Exports: $VAULT, $GH_USER, $TZ_OFFSET, $LOG_DIR
#>

$_configPath = Join-Path $PSScriptRoot "config.yaml"

# Defaults
$_cfg = @{
    vault_path       = ""
    github_username  = ""
    timezone_offset  = "9"
    log_dir          = $env:TEMP
}

# Parse config.yaml (simple key: value, ignores comments and blank lines)
if (Test-Path $_configPath) {
    Get-Content $_configPath -Encoding UTF8 | ForEach-Object {
        if ($_ -match '^\s*([a-zA-Z_]+)\s*:\s*"?([^"#\r\n]*)"?\s*$') {
            $_cfg[$matches[1].Trim()] = $matches[2].Trim()
        }
    }
}

# --- Auto-detect vault path ---
if (-not $_cfg.vault_path) {
    # Windows: %APPDATA%\Obsidian\obsidian.json
    $obsJson = Join-Path $env:APPDATA "Obsidian\obsidian.json"
    # Mac: ~/Library/Application Support/obsidian/obsidian.json
    $obsJsonMac = Join-Path $HOME "Library/Application Support/obsidian/obsidian.json"

    $obsJsonFile = if (Test-Path $obsJson) { $obsJson } elseif (Test-Path $obsJsonMac) { $obsJsonMac } else { $null }

    if ($obsJsonFile) {
        try {
            $parsed = Get-Content $obsJsonFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $firstVault = $parsed.vaults.PSObject.Properties | Select-Object -First 1
            if ($firstVault) {
                $_cfg.vault_path = $firstVault.Value.path
            }
        } catch {
            Write-Warning "Could not parse obsidian.json: $_"
        }
    }
}

if (-not $_cfg.vault_path -or -not (Test-Path $_cfg.vault_path)) {
    throw "Vault path not found. Set 'vault_path' in config.yaml or open Obsidian at least once."
}

# --- Auto-detect GitHub username ---
if (-not $_cfg.github_username) {
    try {
        $detected = gh api user --jq .login 2>&1
        if ($LASTEXITCODE -eq 0 -and $detected -notmatch 'error') {
            $_cfg.github_username = $detected.Trim()
        }
    } catch {}
}

if (-not $_cfg.github_username) {
    throw "GitHub username not found. Run 'gh auth login' or set 'github_username' in config.yaml."
}

# --- Export globals ---
$VAULT      = $_cfg.vault_path
$GH_USER    = $_cfg.github_username
$TZ_OFFSET  = [int]$_cfg.timezone_offset
$LOG_DIR    = if ($_cfg.log_dir) { $_cfg.log_dir } else { $env:TEMP }

# --- Shared helpers ---
function Get-TzNow  { (Get-Date).ToUniversalTime().AddHours($TZ_OFFSET) }
function ConvertTo-Tz {
    param([string]$IsoString)
    [datetime]::Parse($IsoString, $null, [System.Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime().AddHours($TZ_OFFSET)
}
function Write-Log {
    param([string]$Message, [string]$LogName = "obsidian-auto")
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logFile = Join-Path $LOG_DIR "$LogName.log"
    "$ts  $Message" | Tee-Object -FilePath $logFile -Append | Write-Host
}
function Sync-Vault {
    param([string[]]$Paths, [string]$CommitMsg)
    try {
        $dirty = git -C $VAULT status --porcelain 2>&1
        if ($dirty) {
            foreach ($p in $Paths) { git -C $VAULT add $p 2>&1 | Out-Null }
            git -C $VAULT commit -m $CommitMsg 2>&1 | Out-Null
            git -C $VAULT pull --no-rebase -X ours --quiet 2>&1 | Out-Null
            git -C $VAULT push origin main 2>&1 | Out-Null
            Write-Host "Pushed: $CommitMsg"
        } else {
            Write-Host "No changes to commit."
        }
    } catch {
        Write-Warning "Git sync failed (files saved locally): $_"
    }
}
