---
description: "Claude Glass theme: /glass (on/off), water, clear, droplet, winter, off, frost on|off, blur 0-10, transparency 0-100, status, help"
argument-hint: "[water | clear | droplet | winter | off | frost on|off | blur 0-10 | transparency 0-100 | status | help]"
allowed-tools: PowerShell(powershell.exe -NoProfile -ExecutionPolicy Bypass -File *toggle-glass.ps1*)
---

Run this command with the PowerShell tool, then reply with only its output, exactly as printed (keep the line breaks, add nothing):

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\glass\toggle-glass.ps1" $ARGUMENTS
