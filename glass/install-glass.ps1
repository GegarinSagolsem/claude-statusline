# Installs the Claude Glass theme for the current Windows user:
#   1. copies toggle-glass.ps1 and water.png to %USERPROFILE%\.claude\glass\
#   2. copies the /glass, /glass-blur and /glass-transparency commands to %USERPROFILE%\.claude\commands\
#   3. adds a "Claude Glass" profile to Windows Terminal (if missing) and turns the water-glass theme on
#      (a backup of the Terminal settings is written first)
$ErrorActionPreference = 'Stop'

$glassDir = Join-Path $env:USERPROFILE '.claude\glass'
$commandsDir = Join-Path $env:USERPROFILE '.claude\commands'
$utf8 = New-Object Text.UTF8Encoding $false

foreach ($dir in $glassDir, $commandsDir) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir | Out-Null }
}
Copy-Item (Join-Path $PSScriptRoot 'toggle-glass.ps1'), (Join-Path $PSScriptRoot 'water.png') $glassDir -Force
Copy-Item (Join-Path $PSScriptRoot 'commands\*.md') $commandsDir -Force
Write-Host "Copied theme files to $glassDir and commands to $commandsDir"

$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (-not (Test-Path $settingsPath)) { $settingsPath = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json" }
if (-not (Test-Path $settingsPath)) { throw 'Windows Terminal settings.json not found. Open Windows Terminal once, then run this again.' }

$settings = [IO.File]::ReadAllText($settingsPath, $utf8) | ConvertFrom-Json
if (-not ($settings.profiles.list | Where-Object { $_.name -eq 'Claude Glass' })) {
    Copy-Item $settingsPath "$settingsPath.bak" -Force
    Write-Host "Backed up Terminal settings to $settingsPath.bak"
    $profile = [pscustomobject][ordered]@{
        guid        = '{7c1a3e5d-9b2f-4a61-8e0d-c1a0de9a7e55}'
        name        = 'Claude Glass'
        commandline = 'powershell.exe -NoLogo -NoExit -Command claude'
        font        = [pscustomobject]@{ face = 'Cascadia Mono'; size = 12 }
        padding     = '14'
        cursorShape = 'bar'
        hidden      = $false
    }
    $settings.profiles.list = @($profile) + @($settings.profiles.list)
    [IO.File]::WriteAllText($settingsPath, ($settings | ConvertTo-Json -Depth 20), $utf8)
    Write-Host 'Added the "Claude Glass" profile to Windows Terminal'
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $glassDir 'toggle-glass.ps1') water
Write-Host 'Done. In Windows Terminal, click the down arrow next to + and pick "Claude Glass".'
