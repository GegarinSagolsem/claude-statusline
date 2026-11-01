# Installs the Claude Glass theme for the current Windows user:
#   1. copies toggle-glass.ps1, start-claude.ps1, water.png, droplet.png and winter.png to %USERPROFILE%\.claude\glass\
#   2. copies the /glass command to %USERPROFILE%\.claude\commands\
#      (and removes the old /glass-blur and /glass-transparency commands, now part of /glass)
#   3. adds a "Claude Glass" profile to Windows Terminal (if missing) and turns the water-glass theme on
#      (a backup of the Terminal settings is written first). The profile opens a small menu that
#      asks which folder Claude should start in.
$ErrorActionPreference = 'Stop'

$glassDir = Join-Path $env:USERPROFILE '.claude\glass'
$commandsDir = Join-Path $env:USERPROFILE '.claude\commands'
$utf8 = New-Object Text.UTF8Encoding $false

foreach ($dir in $glassDir, $commandsDir) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir | Out-Null }
}
$files = 'toggle-glass.ps1', 'start-claude.ps1', 'water.png', 'droplet.png', 'winter.png'
Copy-Item ($files | ForEach-Object { Join-Path $PSScriptRoot $_ }) $glassDir -Force
Copy-Item (Join-Path $PSScriptRoot 'commands\*.md') $commandsDir -Force
foreach ($old in 'glass-blur.md', 'glass-transparency.md') {
    $oldPath = Join-Path $commandsDir $old
    if (Test-Path $oldPath) { Remove-Item $oldPath -Force }
}
Write-Host "Copied theme files to $glassDir and commands to $commandsDir"

$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (-not (Test-Path $settingsPath)) { $settingsPath = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json" }
if (-not (Test-Path $settingsPath)) { throw 'Windows Terminal settings.json not found. Open Windows Terminal once, then run this again.' }

# The tab runs the folder menu, which then starts Claude. If Claude is closed, the tab stays
# open in PowerShell in your home folder (not C:\Windows\system32).
$startCommand = 'powershell.exe -NoLogo -NoExit -ExecutionPolicy Bypass -File "%USERPROFILE%\.claude\glass\start-claude.ps1"'
$oldCommand   = 'powershell.exe -NoLogo -NoExit -Command claude'

$settings = [IO.File]::ReadAllText($settingsPath, $utf8) | ConvertFrom-Json
$profile = $settings.profiles.list | Where-Object { $_.name -eq 'Claude Glass' } | Select-Object -First 1
$changed = $false
if (-not $profile) {
    $profile = [pscustomobject][ordered]@{
        guid              = '{7c1a3e5d-9b2f-4a61-8e0d-c1a0de9a7e55}'
        name              = 'Claude Glass'
        commandline       = $startCommand
        startingDirectory = '%USERPROFILE%'
        font              = [pscustomobject]@{ face = 'Cascadia Mono'; size = 12 }
        padding           = '14'
        cursorShape       = 'bar'
        hidden            = $false
    }
    $settings.profiles.list = @($profile) + @($settings.profiles.list)
    $changed = $true
    Write-Host 'Added the "Claude Glass" profile to Windows Terminal'
} elseif ($profile.commandline -eq $oldCommand) {
    # profile from an older install: switch it to the folder menu
    $profile.commandline = $startCommand
    $profile | Add-Member -NotePropertyName startingDirectory -NotePropertyValue '%USERPROFILE%' -Force
    $changed = $true
    Write-Host 'Updated the "Claude Glass" profile to ask which folder to start in'
}
if ($changed) {
    Copy-Item $settingsPath "$settingsPath.bak" -Force
    Write-Host "Backed up Terminal settings to $settingsPath.bak"
    [IO.File]::WriteAllText($settingsPath, ($settings | ConvertTo-Json -Depth 20), $utf8)
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $glassDir 'toggle-glass.ps1') water
Write-Host 'Done. In Windows Terminal, click the down arrow next to + and pick "Claude Glass".'
