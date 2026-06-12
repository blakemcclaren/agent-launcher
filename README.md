# agent-launcher

A tiny Windows + WSL launcher for AI coding agents (Codex, Claude, or your own).
One double-click → pick a project → it opens a terminal window per agent, each
already `cd`'d into that project so every AI session starts with a **clean,
project-scoped context** (its own `CLAUDE.md` / `AGENTS.md`, etc.).

It also keeps npm-based agents up to date: before launching, it checks the
installed version against the latest published version and updates only when
needed (avoiding needless `sudo` prompts).

## How it works

- Your projects live under a single **reposRoot** (e.g. `E:\repo` or `C:\dev`).
- `start_agents.ps1` reads `config.json`, lets you pick a project, converts the
  Windows path to its WSL mount path (`E:\repo\foo` → `/mnt/e/repo/foo`), then
  opens one Command Prompt window per configured agent — each attaching to WSL,
  optionally updating the agent, and running it inside the project directory.
- The launcher lives in its **own folder, outside your projects**, so its files
  never pollute any project's AI context.

## Requirements

- Windows with **WSL** installed, and a Linux distro where your agent CLIs run.
- Your AI agent CLIs installed *inside WSL* (e.g. `claude`, `codex`).
- For auto-update of npm-based agents: `npm` available in WSL, and `sudo` usable
  for global installs.

## Setup

1. **Clone** this repo somewhere *outside* your projects folder. (If your
   projects are in `E:\repo`, putting the launcher at `E:\repo\agent-launcher`
   is fine — it excludes itself from the project picker.)

2. **Create your config** from the template:

   ```powershell
   copy config.example.json config.json
   ```

   `config.json` is gitignored — it holds your machine-specific settings and is
   never committed or shared.

3. **Edit `config.json`:**
   - Set `reposRoot` to the folder that contains your projects (use double
     backslashes, e.g. `"E:\\repo"`).
   - List the `agents` you use. Ship-with examples are Codex and Claude; keep,
     remove, or add your own.

4. **Run it:**

   ```powershell
   .\start_agents.ps1
   ```

   Pick a project from the list, and the agent windows open. To skip the picker:

   ```powershell
   .\start_agents.ps1 -Project football_game
   ```

   > **Run this from Windows, not from inside WSL.** `start_agents.ps1` is a
   > Windows PowerShell script that reaches into WSL for you — if you type `wsl`
   > first and try to run it in the Linux shell, you'll get `command not found`.
   > Run it from a Windows PowerShell (or `cmd.exe`) prompt.
   >
   > If PowerShell blocks the script, launch it with
   > `powershell -ExecutionPolicy Bypass -File .\start_agents.ps1`.

## config.json reference

```json
{
  "reposRoot": "E:\\repo",
  "holdWindowOpen": false,
  "agents": [
    {
      "title": "Codex Agent",
      "packageName": "@openai/codex",
      "updateTarget": "npm install -g @openai/codex@latest",
      "versionCommand": "codex --version",
      "runCommand": "codex"
    },
    {
      "title": "Claude Agent",
      "runCommand": "claude"
    }
  ]
}
```

| Field            | Scope  | Meaning |
|------------------|--------|---------|
| `reposRoot`      | top    | Windows folder containing your projects. |
| `holdWindowOpen` | top    | `true` keeps the launching PowerShell window open after launch (debugging). |
| `title`          | agent  | Window title for this agent. **Required.** |
| `runCommand`     | agent  | Command run inside WSL to start the agent (e.g. `claude`). |
| `packageName`    | agent  | *(optional)* npm package to version-check before launch. |
| `updateTarget`   | agent  | *(optional)* command used to update the package when out of date. |
| `versionCommand` | agent  | *(optional)* command that prints the installed version. |
| `versionPattern` | agent  | *(optional)* regex to extract the version; a `(?<version>...)` group is preferred. Falls back to the first `x.y.z` found. |

An agent with no `packageName` (like Claude above) just launches its
`runCommand` — no version check or update.

## One-click shortcuts

Double-clicking a `.ps1` (or a plain shortcut to one) tends to just flash a
console window — it doesn't run the launcher interactively. Use
`New-ProjectLauncher.ps1` to generate a proper `.lnk` that launches
`powershell.exe` directly and stays open (`-NoExit`) so the picker prompt and any
errors are visible.

**Picker shortcut** (recommended — works for every project, drop it on your desktop):

```powershell
.\New-ProjectLauncher.ps1 -OutputDir "$env:USERPROFILE\Desktop"
```

Creates `Agents - Picker.lnk`. Double-click it (or pin it to the taskbar) to open
the project list each time.

**Per-project shortcut** (straight into one project, no picker):

```powershell
.\New-ProjectLauncher.ps1 -Project football_game -OutputDir "$env:USERPROFILE\Desktop"
```

Creates `Agents - football_game.lnk`. Without `-OutputDir`, shortcuts go into a
`shortcuts\` folder next to the script (gitignored).

### Put a shortcut on your desktop (step by step)

The easiest way — run this from a Windows PowerShell prompt in the launcher
folder, and it creates `Agents - Picker.lnk` on your desktop:

```powershell
cd C:\path\to\agent-launcher
powershell -ExecutionPolicy Bypass -File .\New-ProjectLauncher.ps1 -OutputDir "$env:USERPROFILE\Desktop"
```

> From `cmd.exe` instead of PowerShell, use `%USERPROFILE%` for the desktop path:
> `powershell -ExecutionPolicy Bypass -File .\New-ProjectLauncher.ps1 -OutputDir "%USERPROFILE%\Desktop"`

Then double-click `Agents - Picker.lnk` on your desktop (or right-click → **Pin
to taskbar**).

**Prefer to make it by hand?** Right-click the desktop → **New → Shortcut**, and
use these two values (adjust the path to wherever you cloned this repo):

- **Target:**
  ```
  C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoExit -NoProfile -ExecutionPolicy Bypass -File "C:\path\to\agent-launcher\start_agents.ps1"
  ```
- **Start in:**
  ```
  C:\path\to\agent-launcher
  ```

For a shortcut that jumps straight into one project (no picker), append
`-Project "your_project_name"` to the end of the Target.

> Don't just double-click `start_agents.ps1` itself — Windows tends to flash a
> console and close it without running the picker. Always launch via a shortcut
> like the above (or `powershell -File ...` from a terminal).

## Adding your own agent

Add an entry to the `agents` array in `config.json`:

- **CLI already installed, no auto-update:** just `title` + `runCommand`.
- **npm package you want auto-updated:** add `packageName`, `updateTarget`, and
  `versionCommand` so the launcher checks and updates it before each run.

## Notes & limitations

- This targets **Windows + WSL**. The Windows→WSL path conversion assumes your
  projects sit on a drive mounted at `/mnt/<drive-letter>` (the WSL default).
- Update checks use `npm`/`sudo` inside WSL; non-npm agents simply skip that step.
