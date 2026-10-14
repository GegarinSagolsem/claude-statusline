# Controls the "Claude Glass" Windows Terminal profile.
# Usage:
#   toggle-glass.ps1 [on|off|toggle]          switch glass theme on/off (default: toggle)
#   toggle-glass.ps1 water                    water-glass theme (water picture behind the text)
#   toggle-glass.ps1 clear                    clear-glass theme (see your desktop through the window)
#   toggle-glass.ps1 blur <0-10>              blur for the current glass theme
#   toggle-glass.ps1 transparency <0-100>     see-through amount for the current glass theme
param([string]$Mode = 'toggle', [string]$Value = '')

$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (-not (Test-Path $settingsPath)) { $settingsPath = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json" }
$glassDir     = "$env:USERPROFILE\.claude\glass"
$prefsPath    = "$glassDir\glass-settings.json"
$profileName  = 'Claude Glass'
$waterSchemeName = 'Claude Glass Water'
$clearSchemeName = 'Claude Clear Glass'

# Saved look per theme, so switching keeps your choices
$prefs = [pscustomobject]@{
    style = 'water'
    water = [pscustomobject]@{ blur = 0; transparency = 45 }
    clear = [pscustomobject]@{ blur = 5; transparency = 60 }
}
if (Test-Path $prefsPath) {
    try {
        $saved = Get-Content $prefsPath -Raw | ConvertFrom-Json
        if ($saved.style) {
            $prefs.style = $saved.style
            foreach ($s in 'water', 'clear') {
                if ($saved.$s) { $prefs.$s.blur = [int]$saved.$s.blur; $prefs.$s.transparency = [int]$saved.$s.transparency }
            }
        } elseif ($null -ne $saved.blur) {
            # older settings file (water only)
            $prefs.water.blur = [int]$saved.blur; $prefs.water.transparency = [int]$saved.transparency
        }
    } catch {}
}

function Get-BlurredImage([int]$level) {
    $source = "$glassDir\water.png"
    if ($level -le 0) { return $source }
    $target = "$glassDir\water-blur-$level.png"
    if (Test-Path $target) { return $target }

    # Fast blur: shrink the picture, then smoothly stretch it back up
    Add-Type -AssemblyName System.Drawing
    $img = [Drawing.Image]::FromFile($source)
    $factor = 1 + $level * 3
    $sw = [Math]::Max(8, [int]($img.Width / $factor)); $sh = [Math]::Max(8, [int]($img.Height / $factor))
    $attrs = New-Object Drawing.Imaging.ImageAttributes
    $attrs.SetWrapMode([Drawing.Drawing2D.WrapMode]::TileFlipXY)

    $small = New-Object Drawing.Bitmap $sw, $sh
    $g = [Drawing.Graphics]::FromImage($small)
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.DrawImage($img, (New-Object Drawing.Rectangle 0, 0, $sw, $sh), 0, 0, $img.Width, $img.Height, 'Pixel', $attrs)
    $g.Dispose()

    $big = New-Object Drawing.Bitmap $img.Width, $img.Height
    $g = [Drawing.Graphics]::FromImage($big)
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.DrawImage($small, (New-Object Drawing.Rectangle 0, 0, $img.Width, $img.Height), 0, 0, $sw, $sh, 'Pixel', $attrs)
    $g.Dispose()

    $big.Save($target, [Drawing.Imaging.ImageFormat]::Png)
    $big.Dispose(); $small.Dispose(); $img.Dispose()
    return $target
}

$schemes = @(
    [pscustomobject][ordered]@{
        name = $waterSchemeName; background = '#04161F'; foreground = '#EAF7FC'
        cursorColor = '#7FE0FF'; selectionBackground = '#2A6F8A'
        black = '#0A2633'; red = '#FF7B72'; green = '#5EE2A0'; yellow = '#FFD479'
        blue = '#6CC4FF'; purple = '#C3A6FF'; cyan = '#5FE3F0'; white = '#D6EEF7'
        brightBlack = '#7FA3B3'; brightRed = '#FF9E97'; brightGreen = '#8BF0BE'; brightYellow = '#FFE3A3'
        brightBlue = '#9AD7FF'; brightPurple = '#D8C4FF'; brightCyan = '#9AF0F7'; brightWhite = '#FFFFFF'
    },
    [pscustomobject][ordered]@{
        name = $clearSchemeName; background = '#0D1117'; foreground = '#F2F5F8'
        cursorColor = '#FFFFFF'; selectionBackground = '#3A4757'
        black = '#1B2129'; red = '#FF7B72'; green = '#6EE7A8'; yellow = '#FFD479'
        blue = '#79C0FF'; purple = '#D2A8FF'; cyan = '#76E3EA'; white = '#E6EDF3'
        brightBlack = '#9AA7B4'; brightRed = '#FFA198'; brightGreen = '#95F2C2'; brightYellow = '#FFE3A3'
        brightBlue = '#A5D6FF'; brightPurple = '#E2C5FF'; brightCyan = '#A5F0F4'; brightWhite = '#FFFFFF'
    }
)

$settings = [IO.File]::ReadAllText($settingsPath) | ConvertFrom-Json
$profile = $settings.profiles.list | Where-Object { $_.name -eq $profileName } | Select-Object -First 1
if (-not $profile) { Write-Output "Profile '$profileName' not found in Windows Terminal settings."; exit 1 }
$isGlass = [bool]($profile.PSObject.Properties.Name -contains 'opacity')

function Read-Number([string]$text, [int]$max, [string]$label, [int]$current) {
    $n = 0
    if (-not [int]::TryParse($text, [ref]$n) -or $n -lt 0 -or $n -gt $max) {
        Write-Output "$label must be a number from 0 to $max (now: $current)."; exit 1
    }
    return $n
}

$style = $prefs.style
switch ($Mode.ToLower()) {
    'on'    { $enable = $true }
    'off'   { $enable = $false }
    'water' { $prefs.style = 'water'; $enable = $true }
    'clear' { $prefs.style = 'clear'; $enable = $true }
    'blur' {
        $prefs.$style.blur = Read-Number $Value 10 'Blur' $prefs.$style.blur; $enable = $true
    }
    'transparency' {
        $prefs.$style.transparency = Read-Number $Value 100 'Transparency' $prefs.$style.transparency; $enable = $true
    }
    default { $enable = -not $isGlass }
}

$prefs | ConvertTo-Json -Depth 5 | Set-Content $prefsPath -Encoding UTF8

# Keep a one-time backup of the original settings
$backup = "$settingsPath.before-glass.bak"
if (-not (Test-Path $backup)) { Copy-Item $settingsPath $backup }

$glassKeys = 'colorScheme', 'opacity', 'useAcrylic', 'backgroundImage', 'backgroundImageOpacity', 'backgroundImageStretchMode'
foreach ($key in $glassKeys) {
    if ($profile.PSObject.Properties.Name -contains $key) { $profile.PSObject.Properties.Remove($key) }
}

if ($enable) {
    foreach ($scheme in $schemes) {
        if (-not ($settings.schemes | Where-Object { $_.name -eq $scheme.name })) {
            $settings.schemes = @($settings.schemes) + $scheme
        }
    }
    $style = $prefs.style
    $t = $prefs.$style.transparency
    $b = $prefs.$style.blur
    if ($style -eq 'clear') {
        $glassProps = [ordered]@{
            colorScheme = $clearSchemeName
            opacity     = [int][Math]::Max(0, 100 - $t)
            useAcrylic  = ($b -gt 0)
        }
    } else {
        $glassProps = [ordered]@{
            colorScheme                = $waterSchemeName
            opacity                    = [int][Math]::Round(100 - $t * 0.9)
            useAcrylic                 = $true
            backgroundImage            = (Get-BlurredImage $b)
            backgroundImageOpacity     = [Math]::Round([Math]::Max(0.05, (100 - $t) / 100), 2)
            backgroundImageStretchMode = 'uniformToFill'
        }
    }
    foreach ($key in $glassProps.Keys) { $profile | Add-Member -NotePropertyName $key -NotePropertyValue $glassProps[$key] -Force }
}

$json = $settings | ConvertTo-Json -Depth 20
[IO.File]::WriteAllText($settingsPath, $json, (New-Object Text.UTF8Encoding($false)))

if (-not $enable) { Write-Output 'Normal Claude theme ON for the Claude Glass window.' }
elseif ($prefs.style -eq 'clear') {
    $blurText = if ($b -gt 0) { 'blur on' } else { 'blur off' }
    Write-Output "Clear glass ON - $blurText, transparency $t%."
}
else { Write-Output "Water glass ON - blur $b/10, transparency $t%." }
