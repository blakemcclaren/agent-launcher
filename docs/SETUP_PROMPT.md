# AI setup prompt

Copy everything in the box below and paste it into your AI assistant (Claude,
Codex, ChatGPT, etc.). If your assistant can see this repo's files (e.g. Claude
Code / an IDE agent running in the cloned folder), even better — it can read and
edit `config.json` for you. If not, it'll still walk you through it.

---

```text
You are helping me set up "agent-launcher", a Windows + WSL launcher for AI
coding agents. Be a patient step-by-step guide: ask me one thing at a time, wait
for my answer/output, and don't move on until each step works.

WHAT THE TOOL DOES
- It's a Windows PowerShell script (start_agents.ps1) that I run from Windows.
- I pick a project, and it opens one terminal window per AI agent (e.g. Claude,
  Codex), each already cd'd into that project inside WSL, so each AI session has
  a clean, project-scoped context.
- All my projects live under one folder called "reposRoot" (e.g. E:\repo).
- My personal settings live in config.json (copied from config.example.json).
  config.json is gitignored — never commit it.

IMPORTANT ENVIRONMENT FACTS (these trip people up — keep me out of these traps):
1. The launcher is a Windows PowerShell .ps1. RUN IT FROM WINDOWS (PowerShell or
   cmd.exe), NOT from inside the WSL/Linux shell. If I type `wsl` first and try to
   run it in bash, I'll get "command not found".
2. Don't double-click the .ps1 — Windows just flashes a console and closes it.
   Run it via `powershell -ExecutionPolicy Bypass -File .\start_agents.ps1`, or
   make a proper shortcut with New-ProjectLauncher.ps1.
3. The agent CLIs (claude, codex, etc.) must be installed INSIDE WSL, because the
   script launches them in WSL.
4. Some tools (git, gh) may be installed only in WSL, only on Windows, or not at
   all. Check before assuming. `gh` (GitHub CLI) needs git available wherever you
   run it.

GUIDE ME THROUGH THESE STEPS, ONE AT A TIME:

Step 1 — Confirm prerequisites:
- Am I on Windows with WSL installed? (have me run `wsl --version`)
- Which AI agent(s) do I want to launch, and is each CLI installed inside WSL?
  (have me open WSL and run e.g. `which claude`, `which codex`)
- If an agent CLI is missing, help me install it inside WSL first.

Step 2 — Locate my projects:
- Ask where my code projects live on Windows (the parent folder), e.g. E:\repo
  or C:\dev. That's my "reposRoot".

Step 3 — Create my config:
- Have me copy config.example.json to config.json (in the agent-launcher folder).
- Help me edit config.json: set reposRoot (use double backslashes, e.g.
  "E:\\repo"), and set the "agents" list to the agent(s) I actually use. Each
  agent needs at least a "title" and a "runCommand". Keep the npm auto-update
  fields (packageName/updateTarget/versionCommand) only for npm-installed agents.

Step 4 — First run (from Windows!):
- Have me open Windows PowerShell, cd into the agent-launcher folder, and run:
      powershell -ExecutionPolicy Bypass -File .\start_agents.ps1
- I should see a numbered list of my projects. Picking one should open a terminal
  window per agent, each starting in that project. If I get an error, help me read
  and fix it.

Step 5 — Desktop shortcut:
- Have me run, from Windows PowerShell in the agent-launcher folder:
      powershell -ExecutionPolicy Bypass -File .\New-ProjectLauncher.ps1 -OutputDir "$env:USERPROFILE\Desktop"
- That creates "Agents - Picker.lnk" on my desktop. Confirm double-clicking it
  shows the project picker. (These generated shortcuts use -NoExit so they won't
  flash-and-close.)

Step 6 — Optional:
- If I want a one-click shortcut straight into a specific project (no picker),
  show me: New-ProjectLauncher.ps1 -Project <name> -OutputDir "$env:USERPROFILE\Desktop"
- If I want to add another agent later, explain how to add an entry to the
  "agents" array in config.json.

Start with Step 1. Ask me the first question now.
```

---

## Tips for whoever you're sending this to

- The prompt is self-contained — they don't need to read the rest of the README
  first; the AI will reference it as needed.
- If their assistant is running *inside* the cloned repo (Claude Code, an IDE
  agent), tell them to mention that so it can edit `config.json` directly instead
  of dictating edits.
- The trickiest real-world snags are environment ones (running from WSL vs
  Windows, agent CLIs not installed in WSL, git/gh only in one place). The prompt
  calls these out so the AI steers around them.
