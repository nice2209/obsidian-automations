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

# --- Prerequisite checker ---
function Test-Prerequisites {
    $missing = 0

    # git
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        $gitVer = (git --version 2>&1) -replace "git version ", ""
        Write-Host "[OK]     git $gitVer found"
    } else {
        Write-Host "[MISSING] git not found -- install: winget install Git.Git"
        $missing++
    }

    # gh
    $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($ghCmd) {
        $ghVer = (gh --version 2>&1 | Select-Object -First 1) -replace "gh version ", "" -replace " \(.*", ""
        Write-Host "[OK]     gh $ghVer found"
    } else {
        Write-Host "[MISSING] gh not found -- install: winget install GitHub.cli"
        $missing++
    }

    # Python 3
    $pyCmd = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pyCmd) { $pyCmd = Get-Command python3 -ErrorAction SilentlyContinue }
    if ($pyCmd) {
        $pyVer = (& $pyCmd.Source --version 2>&1) -replace "Python ", ""
        if ($pyVer -match "^3\.") {
            Write-Host "[OK]     Python $pyVer found"
        } else {
            Write-Host "[WARN]   Python $pyVer found but Python 3 is required -- install: winget install Python.Python.3"
            $missing++
        }
    } else {
        Write-Host "[MISSING] Python 3 not found -- install: winget install Python.Python.3"
        $missing++
    }

    # Obsidian installation
    $obsidianPaths = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Obsidian\Obsidian.exe"),
        (Join-Path ${env:ProgramFiles} "Obsidian\Obsidian.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Obsidian\Obsidian.exe")
    )
    $obsidianFound = $obsidianPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($obsidianFound) {
        Write-Host "[OK]     Obsidian found at $obsidianFound"
    } else {
        Write-Host "[WARN]   Obsidian not found in Program Files or AppData -- install: winget install Obsidian.Obsidian"
    }

    # gh auth status
    if ($ghCmd) {
        $ghAuth = gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK]     gh authenticated"
        } else {
            Write-Host "[MISSING] gh not authenticated -- run: gh auth login"
            $missing++
        }
    }

    # Obsidian vault exists (parse obsidian.json)
    $obsJson = Join-Path $env:APPDATA "Obsidian\obsidian.json"
    if (Test-Path $obsJson) {
        try {
            $parsed = Get-Content $obsJson -Raw -Encoding UTF8 | ConvertFrom-Json
            $vaultEntry = $parsed.vaults.PSObject.Properties | Select-Object -First 1
            if ($vaultEntry -and (Test-Path $vaultEntry.Value.path)) {
                Write-Host "[OK]     Obsidian vault found at $($vaultEntry.Value.path)"
            } else {
                Write-Host "[WARN]   obsidian.json found but vault path does not exist -- open Obsidian and create a vault first"
            }
        } catch {
            Write-Host "[WARN]   Could not parse obsidian.json -- open Obsidian at least once"
        }
    } else {
        Write-Host "[WARN]   obsidian.json not found -- open Obsidian at least once to create a vault"
    }

    Write-Host ""
    if ($missing -gt 0) {
        Write-Host "[FAIL]   $missing required tool(s) missing. Install them and re-run."
        exit 1
    }
    Write-Host "[OK]     All prerequisites satisfied. Continuing install..."
    Write-Host ""
}

Test-Prerequisites

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
