#Requires -Version 5.1
<#
.SYNOPSIS
    One-liner installer for obsidian-automations.
    Usage: irm https://raw.githubusercontent.com/nice2209/obsidian-automations/main/install.ps1 | iex
#>

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

$REPO_URL   = "https://github.com/nice2209/obsidian-automations.git"
$INSTALL_DIR = Join-Path $env:USERPROFILE "Scripts"

Write-Host ""
Write-Host "=== obsidian-automations installer ==="
Write-Host ""

# --- Check dependencies ---
foreach ($cmd in @("git", "gh")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "$cmd not found. Install it first:`n  git: https://git-scm.com`n  gh:  https://cli.github.com"
        exit 1
    }
}

$ghStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not logged in to GitHub. Run: gh auth login"
    exit 1
}
Write-Host "[OK] git and gh found"

# --- Clone or update ---
if (Test-Path (Join-Path $INSTALL_DIR ".git")) {
    Write-Host "[UPDATE] Pulling latest scripts in $INSTALL_DIR ..."
    git -C $INSTALL_DIR pull --ff-only 2>&1 | Write-Host
} else {
    if (Test-Path $INSTALL_DIR) {
        # Directory exists but is not a git repo — back it up
        $backup = "$INSTALL_DIR-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Rename-Item $INSTALL_DIR $backup
        Write-Host "[BACKUP] Existing Scripts folder moved to $backup"
    }
    Write-Host "[CLONE] Cloning into $INSTALL_DIR ..."
    git clone $REPO_URL $INSTALL_DIR 2>&1 | Write-Host
}

# --- Run setup ---
Write-Host ""
Write-Host "[SETUP] Running setup.ps1 ..."
& (Join-Path $INSTALL_DIR "setup.ps1")
