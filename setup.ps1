#Requires -Version 5.1
<#
.SYNOPSIS
    One-shot setup for obsidian-automations on a new Windows machine.
    Run once: .\setup.ps1
    Optional: .\setup.ps1 -ScriptsDir "D:\MyScripts" -WeeklyDay "Monday"

.REQUIRES
    - git, gh CLI (and gh auth login already done)
    - Obsidian installed and opened at least once (so obsidian.json exists)
#>
param(
    [string]$ScriptsDir = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [string]$WeeklyDay  = "Sunday",
    [string]$HourlyTime = "22:00"   # Time of day for first hourly trigger
)

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=== obsidian-automations setup ==="
Write-Host ""

# --- Check dependencies ---
foreach ($cmd in @("git", "gh")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "$cmd is not installed or not in PATH. Install it and re-run."
        exit 1
    }
}

$ghStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not logged in to GitHub. Run: gh auth login"
    exit 1
}
Write-Host "[OK] git and gh found"

# --- Load config (auto-detect vault + user) ---
. (Join-Path $ScriptsDir "_config.ps1")
Write-Host "[OK] Vault: $VAULT"
Write-Host "[OK] GitHub user: $GH_USER"

# --- Create config.yaml if not present ---
$configPath = Join-Path $ScriptsDir "config.yaml"
if (-not (Test-Path $configPath)) {
    @"
vault_path: "$($VAULT -replace '\\', '\\')"
github_username: "$GH_USER"
timezone_offset: $TZ_OFFSET
"@ | Set-Content $configPath -Encoding UTF8
    Write-Host "[OK] Created config.yaml"
} else {
    Write-Host "[OK] config.yaml already exists"
}

# --- Update Task Scheduler: github_to_obsidian (hourly) ---
function Register-HourlyTask {
    param([string]$TaskName, [string]$ScriptFile, [string]$StartTime)
    $action  = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptFile`""
    $trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Hours 1) `
        -Once -At $StartTime
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
        -StartWhenAvailable -RunOnlyIfNetworkAvailable
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null
        Write-Host "[UPDATE] Task: $TaskName"
    } else {
        Write-Host "[NEW] Task: $TaskName"
    }
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Settings $settings -RunLevel Highest -Force | Out-Null
}

function Register-WeeklyTask {
    param([string]$TaskName, [string]$ScriptFile, [string]$Day, [string]$Time)
    $action  = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptFile`""
    $trigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek $Day -At $Time
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
        -StartWhenAvailable -RunOnlyIfNetworkAvailable
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null
        Write-Host "[UPDATE] Task: $TaskName"
    } else {
        Write-Host "[NEW] Task: $TaskName"
    }
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Settings $settings -RunLevel Highest -Force | Out-Null
}

function Register-LoginTask {
    param([string]$TaskName, [string]$ScriptFile)
    $action   = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptFile`""
    $trigger  = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
        -StartWhenAvailable -RunOnlyIfNetworkAvailable
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null
        Write-Host "[UPDATE] Task: $TaskName"
    } else {
        Write-Host "[NEW] Task: $TaskName"
    }
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Settings $settings -RunLevel Highest -Force | Out-Null
}

function Register-DailyTask {
    param([string]$TaskName, [string]$ScriptFile, [string]$Time)
    $action  = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptFile`""
    $trigger = New-ScheduledTaskTrigger -Daily -At $Time
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
        -StartWhenAvailable
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null
        Write-Host "[UPDATE] Task: $TaskName"
    } else {
        Write-Host "[NEW] Task: $TaskName"
    }
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Settings $settings -RunLevel Highest -Force | Out-Null
}

Register-HourlyTask "github-to-obsidian"      (Join-Path $ScriptsDir "github_to_obsidian.ps1") $HourlyTime
Register-WeeklyTask "obsidian-weekly-report"   (Join-Path $ScriptsDir "weekly_report.ps1") $WeeklyDay "22:00"
Register-LoginTask  "obsidian-sync-pull"       (Join-Path $ScriptsDir "sync_pull.ps1")
Register-DailyTask  "obsidian-daily-note"      (Join-Path $ScriptsDir "daily_note.ps1") "08:00"

Write-Host ""
Write-Host "=== Setup complete ==="
Write-Host ""
Write-Host "Tasks registered:"
Write-Host "  github-to-obsidian     — every hour          (GitHub activity -> Obsidian)"
Write-Host "  obsidian-weekly-report — every $WeeklyDay at 22:00   (weekly summary)"
Write-Host "  obsidian-sync-pull     — on login             (pull latest vault from GitHub)"
Write-Host "  obsidian-daily-note    — every day at 08:00   (create today's daily note)"
Write-Host ""
Write-Host "Manual scripts (run from PowerShell):"
Write-Host "  .\llm_wiki.ps1 -Title 'My learning' -Content '...' [-Tags 'tag1,tag2'] [-Project 'Name']"
Write-Host "  .\llm_wiki.ps1 -Title 'My learning' -FromClipboard"
Write-Host "  .\decision_log.ps1 -Decision 'Use X' -Reason 'Because Y' [-Context 'Project'] [-Alternatives 'A,B']"
Write-Host "  .\sync_pull.ps1   (manual pull anytime)"
Write-Host ""
Write-Host "Test run:"
Write-Host "  powershell -File '$(Join-Path $ScriptsDir 'github_to_obsidian.ps1')'"
