# claude-statusline

A Claude Code status line for Windows (PowerShell 5.1+) that shows:

```
PS C:\path\to\folder> Opus 5.5
Context ██░░░░░░░░|░░░░░░|░░░░ 65k/1M 6% │ Session █░░░░░░░ 2% (resets in 4h 45m) │ Weekly █████░░░ 58% (resets Sun 4:30 PM)
```

- **Context**: how full the current session's context window is. The yellow `|` at 50% marks a good time to start a new session; the red `|` at 80% marks the red zone.
- **Session**: the 5-hour plan usage limit and when it resets.
- **Weekly**: the 7-day plan usage limit and when it resets.

Bars are green below 50%, yellow from 50%, red from 80%.

## Install

```powershell
git clone https://github.com/GegarinSagolsem/claude-statusline.git
cd claude-statusline
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

Then restart Claude Code. It applies to every Claude Code terminal session on that PC, in any folder.

`install.ps1` copies `statusline.ps1` to `%USERPROFILE%\.claude\` and sets the `statusLine` entry in `%USERPROFILE%\.claude\settings.json`, keeping all other settings (a backup is saved as `settings.json.bak`).

## Instructions for Claude

If a user asks you to install this status line:

1. Clone the repo (it is private; use `gh repo clone GegarinSagolsem/claude-statusline` if `gh` is signed in to that account).
2. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1` from the repo folder.
3. Test it: pipe sample JSON into the installed script, e.g.
   `'{"cwd":"C:\\x","model":{"display_name":"Opus"},"context_window":{"context_window_size":1000000,"used_percentage":6,"current_usage":{"input_tokens":60000}}}' | powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\statusline.ps1"`
4. Tell the user to restart Claude Code (or send a message) to see it.

To update later: `git pull` in the repo folder and run `install.ps1` again.
