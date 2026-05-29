#Requires -Version 5.1
<#
.SYNOPSIS
    Pulls latest vault changes from GitHub on login.
    Register via setup.ps1 or run manually to sync after working on another PC.
#>

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_config.ps1")

Write-Log "Pulling vault from GitHub ..." "sync-pull"

try {
    $status = git -C $VAULT status --porcelain 2>&1
    if ($status) {
        # Uncommitted local changes — stash, pull, unstash
        Write-Log "Local changes detected, stashing ..." "sync-pull"
        git -C $VAULT stash 2>&1 | Out-Null
        git -C $VAULT pull --no-rebase -X ours --quiet 2>&1 | Out-Null
        git -C $VAULT stash pop 2>&1 | Out-Null
        Write-Log "Pulled (stash restored)." "sync-pull"
    } else {
        git -C $VAULT pull --no-rebase -X ours --quiet 2>&1 | Out-Null
        Write-Log "Pulled (clean)." "sync-pull"
    }
} catch {
    Write-Log "Pull failed: $_" "sync-pull"
}

Write-Log "Done." "sync-pull"
