# Installs the status line for the current Windows user:
#   1. copies statusline.ps1 to %USERPROFILE%\.claude\
#   2. adds/updates the "statusLine" entry in %USERPROFILE%\.claude\settings.json
#      (all other settings are kept; a backup is written first)
$ErrorActionPreference = 'Stop'

$claudeDir = Join-Path $env:USERPROFILE '.claude'
$target = Join-Path $claudeDir 'statusline.ps1'
$settingsPath = Join-Path $claudeDir 'settings.json'
$utf8 = New-Object Text.UTF8Encoding $false

if (-not (Test-Path $claudeDir)) { New-Item -ItemType Directory $claudeDir | Out-Null }
Copy-Item (Join-Path $PSScriptRoot 'statusline.ps1') $target -Force
Write-Host "Copied script to $target"

$command = "powershell -NoProfile -ExecutionPolicy Bypass -File $($target -replace '\\', '/')"
$entry = [pscustomobject]@{ type = 'command'; command = $command }

if (Test-Path $settingsPath) {
    $text = [IO.File]::ReadAllText($settingsPath, $utf8)
    Copy-Item $settingsPath "$settingsPath.bak" -Force
    Write-Host "Backed up settings to $settingsPath.bak"
    if ($text.Trim()) { $settings = $text | ConvertFrom-Json } else { $settings = [pscustomobject]@{} }
} else {
    $settings = [pscustomobject]@{}
}

if ($settings.PSObject.Properties['statusLine']) { $settings.statusLine = $entry }
else { $settings | Add-Member -NotePropertyName statusLine -NotePropertyValue $entry }

[IO.File]::WriteAllText($settingsPath, ($settings | ConvertTo-Json -Depth 100), $utf8)
Write-Host "Set statusLine in $settingsPath"
Write-Host "Done. Restart Claude Code to see the status line."
