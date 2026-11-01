# Controls the "Claude Glass" Windows Terminal profile.
# Usage (words can be combined, e.g. "water blur 3 transparency 60"):
#   toggle-glass.ps1                          switch glass on/off
#   toggle-glass.ps1 on | off                 glass on / normal black Claude
#   toggle-glass.ps1 water                    water look (water picture behind the text)
#   toggle-glass.ps1 clear                    clear look (your desktop shows through the window)
#   toggle-glass.ps1 droplet                  droplet look (misty glass with drips and droplets)
#   toggle-glass.ps1 winter                   winter look (winter window with fern frost)
#   toggle-glass.ps1 frost <on|off>           frosted glass over the desktop, for the current look
#   toggle-glass.ps1 blur <0-10|on|off>       blur the water picture (in the other looks, same as frost)
#   toggle-glass.ps1 transparency <0-100>     see-through amount for the current look
#   toggle-glass.ps1 status                   show what's on now, change nothing
#   toggle-glass.ps1 help                     list the commands
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Words = @())

$usage = @'
Claude Glass commands:
  /glass                      turn glass on or off
  /glass water                water look
  /glass clear                clear look (your desktop shows through)
  /glass droplet              droplet look (misty glass with drips and droplets)
  /glass winter               winter look (winter window with fern frost)
  /glass off                  normal black Claude (/glass on brings glass back)
  /glass frost on|off         frosted glass over your desktop (off = see it sharply)
  /glass blur 0-10            blur the water picture: 0 = sharp, 10 = very blurry
  /glass transparency 0-100   0 = solid, 100 = fully see-through
  /glass status               show what's on now
You can combine them, e.g. /glass water frost off blur 3 transparency 60
'@

$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (-not (Test-Path $settingsPath)) { $settingsPath = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json" }
$glassDir     = "$env:USERPROFILE\.claude\glass"
$prefsPath    = "$glassDir\glass-settings.json"
$dropletImage = "$glassDir\droplet.png"
$winterImage  = "$glassDir\winter.png"
$profileName  = 'Claude Glass'
$waterSchemeName = 'Claude Glass Water'
$clearSchemeName = 'Claude Clear Glass'
$looks = 'water', 'clear', 'droplet', 'winter'

# Saved settings per look, so switching keeps your choices
$prefs = [pscustomobject]@{
    style   = 'water'
    water   = [pscustomobject]@{ blur = 0; transparency = 45;  frost = $true }
    clear   = [pscustomobject]@{ blur = 0; transparency = 60;  frost = $true }
    droplet = [pscustomobject]@{ blur = 0; transparency = 100; frost = $true }
    winter  = [pscustomobject]@{ blur = 0; transparency = 100; frost = $true }
}
if (Test-Path $prefsPath) {
    try {
        $saved = Get-Content $prefsPath -Raw | ConvertFrom-Json
        if ($saved.style) {
            if ($saved.style -in $looks) { $prefs.style = $saved.style }
            foreach ($s in $looks) {
                if (-not $saved.$s) { continue }
                $prefs.$s.blur = [int]$saved.$s.blur; $prefs.$s.transparency = [int]$saved.$s.transparency
                $f = $saved.$s.frost
                if ($f -is [bool]) { $prefs.$s.frost = $f }
                elseif ($null -ne $f) {
                    # older files had frost levels 0-11: 2-10 is now the droplet look, 11 the winter look
                    $prefs.$s.frost = ([int]$f -gt 0)
                    if ($s -eq $saved.style -and [int]$f -ge 11) { $prefs.style = 'winter' }
                    elseif ($s -eq $saved.style -and [int]$f -ge 2) { $prefs.style = 'droplet' }
                }
                elseif ($s -eq 'clear') { $prefs.$s.frost = ([int]$saved.$s.blur -gt 0) }  # oldest files: clear blur was the frost
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

function Fail([string]$message) {
    Write-Output $message
    Write-Output ''
    Write-Output $usage
    exit 1
}

function Read-Number([string]$text, [int]$max, [string]$label, [int]$current) {
    $n = 0
    if (-not [int]::TryParse($text, [ref]$n) -or $n -lt 0 -or $n -gt $max) {
        Fail "$label needs a number from 0 to $max (now: $current)."
    }
    return $n
}

# frost: on/off (1/0 work too). Old frost levels point to the looks that replaced them.
function Read-Frost([string]$text, [string]$label, [bool]$current) {
    $now = if ($current) { 'on' } else { 'off' }
    if ($text -in 'on', '1') { return $true }
    if ($text -in 'off', '0') { return $false }
    $n = 0
    if ([int]::TryParse($text, [ref]$n) -and $n -ge 11) { Fail "$label is just on or off now (now: $now). For the winter window, type /glass winter." }
    if ([int]::TryParse($text, [ref]$n) -and $n -ge 2) { Fail "$label is just on or off now (now: $now). For the misty droplet glass, type /glass droplet." }
    Fail "$label needs on or off (now: $now)."
}

function Get-Status {
    if (-not $isGlass) { return 'Glass is OFF (normal black Claude). Type /glass to turn it on.' }
    $s = $prefs.style
    $t = $prefs.$s.transparency
    $frostText = if ($prefs.$s.frost) { 'frost on' } else { 'frost off' }
    switch ($s) {
        'water'   { return "Water glass ON - $frostText, picture blur $($prefs.water.blur)/10, transparency $t%." }
        'clear'   { return "Clear glass ON - $frostText, transparency $t%." }
        'droplet' { return "Droplet glass ON - $frostText, transparency $t%." }
        'winter'  { return "Winter glass ON - $frostText, transparency $t%." }
    }
}

$words = @($Words | Where-Object { $_ -ne $null -and $_.Trim() -ne '' } | ForEach-Object { $_.Trim().ToLower() })

if ($words.Count -eq 1 -and $words[0] -in 'help', '-h', '--help', '?') { Write-Output $usage; exit 0 }
if ($words.Count -eq 1 -and $words[0] -eq 'status') { Write-Output (Get-Status); exit 0 }

if ($words.Count -eq 0) {
    $enable = -not $isGlass
} else {
    $enable = $true
    for ($i = 0; $i -lt $words.Count; $i++) {
        $word = $words[$i]
        $style = $prefs.style
        switch ($word) {
            'toggle' { $enable = -not $isGlass }
            'on'     { $enable = $true }
            'off'    { $enable = $false }
            { $_ -in $looks } { $prefs.style = $word; $enable = $true }
            'frost' {
                $i++
                $value = if ($i -lt $words.Count) { $words[$i] } else { '' }
                $prefs.$style.frost = Read-Frost $value 'Frost' $prefs.$style.frost
                $enable = $true
            }
            'blur' {
                $i++
                $value = if ($i -lt $words.Count) { $words[$i] } else { '' }
                if ($style -ne 'water') {
                    # only the water look has a picture to blur; elsewhere blur is the frost
                    $n = 0
                    if ([int]::TryParse($value, [ref]$n) -and $n -ge 0 -and $n -le 10) { $prefs.$style.frost = ($n -gt 0) }
                    else { $prefs.$style.frost = Read-Frost $value 'Blur' $prefs.$style.frost }
                } else {
                    if ($value -eq 'on')      { if ($prefs.water.blur -le 0) { $prefs.water.blur = 5 } }
                    elseif ($value -eq 'off') { $prefs.water.blur = 0 }
                    else { $prefs.water.blur = Read-Number $value 10 'Blur' $prefs.water.blur }
                }
                $enable = $true
            }
            { $_ -in 'transparency', 'transparent', 'see-through' } {
                $i++
                $value = if ($i -lt $words.Count) { $words[$i].TrimEnd('%') } else { '' }   # "50%" works too
                $prefs.$style.transparency = Read-Number $value 100 'Transparency' $prefs.$style.transparency
                $enable = $true
            }
            default { Fail "I don't know '$word'." }
        }
    }
}

$prefs | ConvertTo-Json -Depth 5 | Set-Content $prefsPath -Encoding UTF8

# Keep a one-time backup of the original settings
$backup = "$settingsPath.before-glass.bak"
if (-not (Test-Path $backup)) { Copy-Item $settingsPath $backup }

$glassKeys = 'colorScheme', 'opacity', 'useAcrylic', 'background', 'backgroundImage', 'backgroundImageOpacity', 'backgroundImageStretchMode'
foreach ($key in $glassKeys) {
    if ($profile.PSObject.Properties.Name -contains $key) { $profile.PSObject.Properties.Remove($key) }
}

# pictures from older versions that are no longer used
foreach ($old in 'frost.png', 'frost-ice.png') { Remove-Item (Join-Path $glassDir $old) -Force -ErrorAction SilentlyContinue }
Get-ChildItem $glassDir -Filter 'water-mix-*.png' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

if ($enable) {
    foreach ($scheme in $schemes) {
        if (-not ($settings.schemes | Where-Object { $_.name -eq $scheme.name })) {
            $settings.schemes = @($settings.schemes) + $scheme
        }
    }
    $style = $prefs.style
    $t = $prefs.$style.transparency
    $frost = [bool]$prefs.$style.frost
    switch ($style) {
        'clear' {
            $glassProps = [ordered]@{
                colorScheme = $clearSchemeName
                opacity     = [int][Math]::Max(0, 100 - $t)
                useAcrylic  = $frost
            }
        }
        'droplet' {
            # misty glass with drips and droplets; the desktop behind is dimmed so text stays readable
            $glassProps = [ordered]@{
                colorScheme                = $waterSchemeName
                opacity                    = [int][Math]::Round((100 - $t * 0.9) * 0.4 + 60)
                useAcrylic                 = $frost
                backgroundImage            = $dropletImage
                backgroundImageOpacity     = 0.8
                backgroundImageStretchMode = 'uniformToFill'
            }
        }
        'winter' {
            # winter-window picture: a semi-transparent blue glass (the frosted desktop shows
            # through) with melt streaks, drops and fern frost; the desktop is dimmed a little
            # so text stays readable
            $glassProps = [ordered]@{
                colorScheme                = $waterSchemeName
                opacity                    = [int][Math]::Round((100 - $t * 0.9) * 0.7 + 30)
                useAcrylic                 = $frost
                backgroundImage            = $winterImage
                backgroundImageOpacity     = 1
                backgroundImageStretchMode = 'uniformToFill'
            }
        }
        default {
            $glassProps = [ordered]@{
                colorScheme                = $waterSchemeName
                opacity                    = [int][Math]::Round(100 - $t * 0.9)
                useAcrylic                 = $frost
                backgroundImage            = (Get-BlurredImage $prefs.water.blur)
                backgroundImageOpacity     = [Math]::Round([Math]::Max(0.05, (100 - $t) / 100), 2)
                backgroundImageStretchMode = 'uniformToFill'
            }
        }
    }
    foreach ($key in $glassProps.Keys) { $profile | Add-Member -NotePropertyName $key -NotePropertyValue $glassProps[$key] -Force }
}

$json = $settings | ConvertTo-Json -Depth 20
[IO.File]::WriteAllText($settingsPath, $json, (New-Object Text.UTF8Encoding($false)))

$isGlass = $enable
Write-Output (Get-Status)
