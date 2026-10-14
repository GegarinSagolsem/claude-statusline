---
description: Set blur for the current Claude Glass theme (water - 0 sharp to 10 very blurry; clear - 0 off, 1-10 on)
argument-hint: "<0-10>"
allowed-tools: PowerShell(powershell.exe -NoProfile -ExecutionPolicy Bypass -File *toggle-glass.ps1*)
---

Run this command with the PowerShell tool, then reply with only its one-line output:

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\glass\toggle-glass.ps1" blur $ARGUMENTS
