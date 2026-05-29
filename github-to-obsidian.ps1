# Shim: forwards to the canonical script. Keep this file so the existing Task Scheduler task continues to work.
& (Join-Path $PSScriptRoot "github_to_obsidian.ps1")
