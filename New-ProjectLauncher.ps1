# New-ProjectLauncher.ps1
# Generate a one-click Windows shortcut (.lnk) for the agent launcher.
#
#   - With -Project: a shortcut that launches straight into that project (no picker).
#   - Without -Project: a "picker" shortcut that opens the project list each time.
#
# Generated shortcuts run powershell.exe directly (so they actually run, instead of
# flashing) and use -NoExit so any output or error stays on screen.
#
# Examples:
#   .\New-ProjectLauncher.ps1                                  # picker shortcut
#   .\New-ProjectLauncher.ps1 -OutputDir "$env:USERPROFILE\Desktop"
#   .\New-ProjectLauncher.ps1 -Project football_game           # straight into a project
#   .\New-ProjectLauncher.ps1 -Project football_game -OutputDir "$env:USERPROFILE\Desktop"

[CmdletBinding()]
param(
    # Project folder name under your reposRoot (e.g. "football_game").
    # Omit to create a picker shortcut that prompts for the project each time.
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

$usePicker = [string]::IsNullOrWhiteSpace($Project)

if ($usePicker) {
    $shortcutName = "Agents - Picker.lnk"
    $description = "Launch AI agents (pick a project)"
}
else {
    $shortcutName = "Agents - $Project.lnk"
    $description = "Launch AI agents for $Project"
}
$shortcutPath = Join-Path $OutputDir $shortcutName

# Resolve the PowerShell executable to launch the script with.
$powershell = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
if (-not $powershell) {
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
}

# -NoExit keeps the window open so the picker prompt (or any error) is visible
# instead of flashing closed.
$arguments = '-NoExit -NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $launcher
if (-not $usePicker) {
    $arguments += ' -Project "{0}"' -f $Project
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $powershell
$shortcut.Arguments = $arguments
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.Description = $description
$shortcut.IconLocation = "$powershell,0"
$shortcut.Save()

Write-Host "Created shortcut:" -ForegroundColor Green
Write-Host "  $shortcutPath"
if ($usePicker) {
    Write-Host "Double-click it (or pin it to the taskbar) to open the project picker."
}
else {
    Write-Host "Double-click it (or pin it to the taskbar) to launch agents straight into '$Project'."
}
