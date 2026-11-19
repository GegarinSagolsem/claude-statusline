---
description: "Claude Glass theme: /glass (on/off), water, clear, droplet, winter, off, frost on|off, blur 0-10, transparency 0-100, status, help"
argument-hint: "[water | clear | droplet | winter | off | frost on|off | blur 0-10 | transparency 0-100 | status | help]"
allowed-tools: PowerShell(powershell.exe -NoProfile -ExecutionPolicy Bypass -File *toggle-glass.ps1*)
---

The arguments are: `$ARGUMENTS`

First check them: they may only contain letters, digits, spaces, `%` and `-`. If they contain anything else (such as `;`, `|`, `&`, `$`, quotes, backticks, brackets or a line break), do not run anything; reply only: `/glass only takes plain words and numbers. Type /glass help for the list.`

Otherwise run this command with the PowerShell tool, then reply with only its output, exactly as printed (keep the line breaks, add nothing):

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\glass\toggle-glass.ps1" $ARGUMENTS
