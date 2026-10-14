---
description: Set how see-through the current Claude Glass theme is (0 = solid, 100 = fully clear)
argument-hint: "<0-100>"
allowed-tools: PowerShell(powershell.exe -NoProfile -ExecutionPolicy Bypass -File *toggle-glass.ps1*)
---

Run this command with the PowerShell tool, then reply with only its one-line output:

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\glass\toggle-glass.ps1" transparency $ARGUMENTS
