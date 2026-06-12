# New-ProjectLauncher.ps1
# Generate a one-click Windows shortcut (.lnk) that launches the agents for a
# specific project — no picker, straight into that project.
#
# Optional convenience on top of start_agents.ps1. The default launcher already
# works for every project via its interactive picker; use this only when you want
# a dedicated, pinnable shortcut for a project you work in often.
#
# Examples:
#   .\New-ProjectLauncher.ps1 -Project football_game
#   .\New-ProjectLauncher.ps1 -Project football_game -OutputDir "$env:USERPROFILE\Desktop"

[CmdletBinding()]
param(
    # Project folder name under your reposRoot (e.g. "football_game").
    [Parameter(Mandatory = $true)]
    [string]$Project,

    # Where to write the .lnk. Defaults to a 'shortcuts' folder next to this script.
    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'

$launcher = Join-Path $PSScriptRoot 'start_agents.ps1'
if (-not (Test-Path $launcher)) {
    Write-Error "Could not find start_agents.ps1 next to this script ($PSScriptRoot)."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $PSScriptRoot 'shortcuts'
}
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$shortcutPath = Join-Path $OutputDir ("Agents - {0}.lnk" -f $Project)

# Resolve the PowerShell executable to launch the script with.
$powershell = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
if (-not $powershell) {
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
}

$arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Project "{1}"' -f $launcher, $Project

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $powershell
$shortcut.Arguments = $arguments
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.Description = "Launch AI agents for $Project"
$shortcut.IconLocation = "$powershell,0"
$shortcut.Save()

Write-Host "Created shortcut:" -ForegroundColor Green
Write-Host "  $shortcutPath"
Write-Host "Double-click it (or pin it to the taskbar) to launch agents straight into '$Project'."
