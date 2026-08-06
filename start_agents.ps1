# start_agents.ps1
# Launch one Command Prompt window per configured AI agent, each attached to WSL
# and running inside the project you select. Agents are launched with their working
# directory set to the project root, so each AI session gets a clean, project-scoped
# context (its own CLAUDE.md / AGENTS.md, etc.).
#
# Once the agent windows are open this launcher window closes itself. It only stays
# open when there's something to read - an error or a warning - or when
# holdWindowOpen is true in config.json.
#
# Configuration lives in config.json (copy config.example.json to get started).
# See README.md for setup.

[CmdletBinding()]
param(
    # Project folder name under reposRoot (e.g. "football_game"). If omitted, an
    # interactive picker lists the projects found under reposRoot.
    [string]$Project
)

$ErrorActionPreference = 'Stop'

# Defaults set before anything can fail, so the finally block below can always
# decide whether to keep this window open.
$script:holdWindowOpen = $false
$script:hadProblem = $false
$exitCode = 0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Like Write-Warning, but also flags that this window should wait for the user
# before closing - otherwise the warning would scroll past and vanish.
function Write-LauncherWarning {
    param(
        [Parameter(Mandatory = $true)][string]$Message
    )

    $script:hadProblem = $true
    Write-Warning $Message
}

function Select-Project {
    param(
        [Parameter(Mandatory = $true)][string]$ReposRoot
    )

    # List candidate projects: directories under reposRoot (including this launcher's
    # own folder, so you can open agents in it to edit the launcher itself).
    $candidates = Get-ChildItem -Path $ReposRoot -Directory | Sort-Object Name

    if (-not $candidates -or $candidates.Count -eq 0) {
        throw "No project folders found under '$ReposRoot'."
    }

    Write-Host ""
    Write-Host "Select a project (under $ReposRoot):" -ForegroundColor Cyan
    for ($i = 0; $i -lt $candidates.Count; $i++) {
        Write-Host ("  {0}) {1}" -f ($i + 1), $candidates[$i].Name)
    }
    Write-Host ""

    while ($true) {
        $choice = Read-Host "Enter number (or 'q' to quit)"

        if ($choice -match '^(q|quit|exit)$') {
            return $null
        }

        $index = 0
        if ([int]::TryParse($choice, [ref]$index) -and $index -ge 1 -and $index -le $candidates.Count) {
            return $candidates[$index - 1].Name
        }

        Write-Host "Invalid selection. Enter a number between 1 and $($candidates.Count)." -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# WSL helpers (version detection + latest-version lookup)
# ---------------------------------------------------------------------------
function Invoke-WslCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [switch]$IgnoreExitCode
    )

    $fullCommand = "cd $wslPath && $Command"
    $output = & wsl.exe -e bash -lc $fullCommand 2>&1
    $exitCode = $LASTEXITCODE

    if (-not $IgnoreExitCode -and $exitCode -ne 0) {
        $message = ($output -join "`n").Trim()
        throw "WSL command failed (exit $exitCode): $message"
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output   = $output
    }
}

function Get-AgentInstalledVersion {
    param(
        [Parameter(Mandatory = $true)]
        $Agent
    )

    if (-not $Agent.versionCommand) {
        return $null
    }

    $result = Invoke-WslCommand -Command $Agent.versionCommand -IgnoreExitCode

    if ($result.ExitCode -ne 0) {
        return $null
    }

    $outputText = ($result.Output -join "`n").Trim()

    if ([string]::IsNullOrWhiteSpace($outputText)) {
        return $null
    }

    if ($Agent.versionPattern) {
        $match = [regex]::Match($outputText, $Agent.versionPattern)
        if ($match.Success) {
            $namedGroup = $match.Groups['version']
            if ($namedGroup -and -not [string]::IsNullOrEmpty($namedGroup.Value)) {
                return $namedGroup.Value
            }
            if ($match.Value) {
                return $match.Value
            }
        }
    }

    $fallbackMatch = [regex]::Match($outputText, '\d+\.\d+\.\d+')

    if ($fallbackMatch.Success) {
        return $fallbackMatch.Value
    }

    return $null
}

function Get-LatestPackageVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName
    )

    $command = "npm view $PackageName version --json --loglevel=error --no-update-notifier --no-fund"
    $result = Invoke-WslCommand -Command $command -IgnoreExitCode

    if ($result.ExitCode -ne 0) {
        return $null
    }

    $rawOutput = ($result.Output -join "`n").Trim()

    if ([string]::IsNullOrWhiteSpace($rawOutput)) {
        return $null
    }

    try {
        $parsed = $rawOutput | ConvertFrom-Json

        if ($parsed -is [string]) {
            return $parsed
        }

        if ($parsed -is [System.Collections.IEnumerable]) {
            return ($parsed | Select-Object -Last 1)
        }
    }
    catch {
        return $rawOutput
    }

    return $null
}

try {
    # -----------------------------------------------------------------------
    # Load configuration
    # -----------------------------------------------------------------------
    $configPath = Join-Path $PSScriptRoot 'config.json'

    if (-not (Test-Path $configPath)) {
        throw @"
config.json not found.

Copy the example and personalize it for your machine:
    copy config.example.json config.json

Then edit config.json to set your reposRoot and the agents you use.
"@
    }

    try {
        $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
    }
    catch {
        throw "Failed to parse config.json: $_"
    }

    if (-not $config.reposRoot) {
        throw "config.json is missing 'reposRoot' (the folder that holds your projects, e.g. 'E:\\repo')."
    }

    if (-not $config.agents -or $config.agents.Count -eq 0) {
        throw "config.json has no 'agents' defined. Add at least one agent (see config.example.json)."
    }

    $reposRoot = $config.reposRoot
    # Flip holdWindowOpen in config.json to always pause before this window closes.
    $script:holdWindowOpen = [bool]$config.holdWindowOpen

    if (-not (Test-Path $reposRoot)) {
        throw "reposRoot '$reposRoot' was not found. Update reposRoot in config.json."
    }

    # -----------------------------------------------------------------------
    # Resolve which project to launch into
    # -----------------------------------------------------------------------
    if ([string]::IsNullOrWhiteSpace($Project)) {
        $Project = Select-Project -ReposRoot $reposRoot
    }

    if ([string]::IsNullOrWhiteSpace($Project)) {
        # Picker was cancelled - nothing to report, so let the window close.
        Write-Host "Cancelled."
    }
    else {
        $repoPath = Join-Path $reposRoot $Project

        if (-not (Test-Path $repoPath)) {
            throw "Project path '$repoPath' was not found. Check the project name or your reposRoot in config.json."
        }

        # Convert the Windows project path to its WSL mount path (e.g. E:\repo\foo -> /mnt/e/repo/foo).
        $driveLetter = $repoPath.Substring(0, 1).ToLower()
        $wslPath = "/mnt/$driveLetter" + $repoPath.Substring(2).Replace('\', '/')

        Write-Host "Launching agents for project '$Project'" -ForegroundColor Green
        Write-Host "  Windows path: $repoPath"
        Write-Host "  WSL path:     $wslPath"

        # -------------------------------------------------------------------
        # Launch each agent
        # -------------------------------------------------------------------
        foreach ($agent in $config.agents) {
            if (-not $agent.title) {
                Write-LauncherWarning "Skipping an agent entry with no 'title'."
                continue
            }

            $installedVersion = $null
            $latestVersion = $null
            $hasPackage = [bool]$agent.packageName
            $shouldUpdate = $hasPackage

            if ($hasPackage) {
                if (-not $agent.updateTarget) {
                    Write-LauncherWarning "$($agent.title): 'packageName' is set but 'updateTarget' is missing - skipping auto-update."
                    $shouldUpdate = $false
                }
                else {
                    try {
                        $installedVersion = Get-AgentInstalledVersion -Agent $agent
                    }
                    catch {
                        Write-LauncherWarning "$($agent.title): Failed to read installed version. $_"
                    }

                    try {
                        $latestVersion = Get-LatestPackageVersion -PackageName $agent.packageName
                    }
                    catch {
                        Write-LauncherWarning "$($agent.title): Failed to resolve latest version for $($agent.packageName). $_"
                    }

                    if ($installedVersion) {
                        if ($latestVersion) {
                            if ($installedVersion -eq $latestVersion) {
                                Write-Host "$($agent.title): $($agent.packageName) is up to date ($installedVersion)."
                                $shouldUpdate = $false
                            }
                            else {
                                Write-Host "$($agent.title): $($agent.packageName) installed $installedVersion, latest $latestVersion - updating."
                                $shouldUpdate = $true
                            }
                        }
                        else {
                            Write-LauncherWarning "$($agent.title): Installed version $installedVersion detected, but latest version could not be retrieved. Skipping update to avoid an unnecessary sudo prompt."
                            $shouldUpdate = $false
                        }
                    }
                    else {
                        if ($latestVersion) {
                            Write-Host "$($agent.title): Not installed. Latest available $latestVersion - installing."
                        }
                        else {
                            Write-Host "$($agent.title): Unable to determine package state, attempting installation to ensure availability."
                        }
                        $shouldUpdate = $true
                    }
                }
            }

            $wslCommands = @("cd $wslPath")

            if ($shouldUpdate -and $agent.updateTarget) {
                $wslCommands += "sudo $($agent.updateTarget)"
            }
            elseif ($hasPackage) {
                $wslCommands += ('echo {0} already up to date.' -f $agent.packageName)
            }

            if ($agent.runCommand) {
                $wslCommands += ("exec {0}" -f $agent.runCommand)
            }
            else {
                Write-LauncherWarning "$($agent.title): no 'runCommand' set - the window will open but no agent will start."
            }

            $wslInner = ($wslCommands -join " && ")
            $cmdLine = "title $($agent.title) && cd /d $repoPath && wsl.exe -e bash -lc `"$wslInner`""
            Start-Process -FilePath "cmd.exe" -ArgumentList "/k", $cmdLine
        }
    }
}
catch {
    $script:hadProblem = $true
    $exitCode = 1
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    # A clean run has nothing left to show, so let this window close on its own.
    if ($script:holdWindowOpen -or $script:hadProblem) {
        Write-Host ""
        Read-Host "Press Enter to close"
    }
}

exit $exitCode
