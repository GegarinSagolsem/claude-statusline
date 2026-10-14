---
description: Claude Glass theme - no args toggles on/off; or use on | off | water | clear
argument-hint: "[on|off|water|clear]"
allowed-tools: PowerShell(powershell.exe -NoProfile -ExecutionPolicy Bypass -File *toggle-glass.ps1*)
---

Run this command with the PowerShell tool, then reply with only its one-line output:

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\glass\toggle-glass.ps1" $ARGUMENTS
