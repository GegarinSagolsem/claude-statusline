# Starts Claude Code in the Claude Glass tab, after asking which folder to start in:
#   - the last folder you used Claude in, and a few other recent ones (from Claude's history)
#   - a folder you paste
#   - your home folder
# Use the arrow keys and Enter, or press a number. Enter on its own picks the first choice.
# Extra arguments are passed on to claude. -DryRun prints the chosen folder instead of starting Claude.
param(
    [switch]$DryRun,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$ClaudeArgs = @()
)

$homeDir    = $env:USERPROFILE
$historyLog = Join-Path $homeDir '.claude\history.jsonl'
$lastPick   = Join-Path $homeDir '.claude\glass\last-folder.txt'
$windowsDir = $env:SystemRoot.TrimEnd('\')

function Test-Usable([string]$path) {
    if (-not $path) { return $false }
    $p = $path.TrimEnd('\')
    if ($p -ieq $homeDir.TrimEnd('\')) { return $false }                       # has its own choice
    if ($p -ieq $windowsDir -or $p.StartsWith("$windowsDir\", 'OrdinalIgnoreCase')) { return $false }  # never system32
    return (Test-Path -LiteralPath $p -PathType Container)
}

# Folders Claude was used in, most recent first
$recent = New-Object System.Collections.Generic.List[string]
if (Test-Path $historyLog) {
    $rx = [regex]'"project":"((?:[^"\\]|\\.)*)"'
    try {
        foreach ($line in [IO.File]::ReadLines($historyLog)) {
            $m = $rx.Match($line)
            if ($m.Success) {
                $p = [regex]::Unescape($m.Groups[1].Value)
                [void]$recent.Remove($p); $recent.Add($p)
            }
        }
    } catch {}
}
$recent.Reverse()
if (Test-Path $lastPick) {
    $p = (Get-Content $lastPick -Raw -ErrorAction SilentlyContinue)
    if ($p) { $p = $p.Trim(); [void]$recent.Remove($p); $recent.Insert(0, $p) }
}
$folders = @($recent | Where-Object { Test-Usable $_ } | Select-Object -First 4)

$items = @()
for ($i = 0; $i -lt $folders.Count; $i++) {
    $label = if ($i -eq 0) { 'Last folder' } else { 'Recent' }
    $items += [pscustomobject]@{ Label = $label; Path = $folders[$i]; Kind = 'folder' }
}
$items += [pscustomobject]@{ Label = 'Paste a folder'; Path = ''; Kind = 'paste' }
$items += [pscustomobject]@{ Label = 'Home folder'; Path = $homeDir; Kind = 'folder' }

function Show-Menu([int]$selected) {
    Clear-Host
    Write-Host ''
    Write-Host '  Claude Glass' -ForegroundColor Cyan
    Write-Host '  Where should Claude start?'
    Write-Host ''
    for ($i = 0; $i -lt $items.Count; $i++) {
        $mark  = if ($i -eq $selected) { '>' } else { ' ' }
        $color = if ($i -eq $selected) { 'Cyan' } else { 'Gray' }
        Write-Host ('  {0} {1}. {2,-15}{3}' -f $mark, ($i + 1), $items[$i].Label, $items[$i].Path) -ForegroundColor $color
    }
    Write-Host ''
    Write-Host '  Up/Down and Enter, or press a number. Esc = home folder.' -ForegroundColor DarkGray
}

function Read-PastedFolder {
    while ($true) {
        Write-Host ''
        if ([Console]::IsInputRedirected) {
            Write-Host '  Paste a folder (Enter on its own goes back): ' -NoNewline
            $raw = [Console]::In.ReadLine()
        } else {
            $raw = Read-Host '  Paste a folder (Enter on its own goes back)'
        }
        if (-not $raw -or -not $raw.Trim()) { return $null }
        $p = [Environment]::ExpandEnvironmentVariables($raw.Trim().Trim('"').Trim("'"))
        if (Test-Path -LiteralPath $p -PathType Container) { return (Resolve-Path -LiteralPath $p).ProviderPath }
        Write-Host "  That folder doesn't exist: $p" -ForegroundColor Yellow
    }
}

function Select-Folder {
    $selected = 0
    $interactive = -not [Console]::IsInputRedirected
    while ($true) {
        if ($interactive) {
            Show-Menu $selected
            $key = [Console]::ReadKey($true)
            $choice = -1
            switch ($key.Key) {
                'UpArrow'   { $selected = ($selected - 1 + $items.Count) % $items.Count }
                'DownArrow' { $selected = ($selected + 1) % $items.Count }
                'Enter'     { $choice = $selected }
                'Escape'    { return $homeDir }
                default {
                    $n = 0
                    if ([int]::TryParse([string]$key.KeyChar, [ref]$n) -and $n -ge 1 -and $n -le $items.Count) { $choice = $n - 1 }
                }
            }
            if ($choice -lt 0) { continue }
        } else {
            # no keyboard (input piped in): read a number per line, blank = first choice
            Show-Menu -1
            $line = [Console]::In.ReadLine()
            if ($null -eq $line -or -not $line.Trim()) { $choice = 0 }
            else {
                $n = 0
                if (-not ([int]::TryParse($line.Trim(), [ref]$n) -and $n -ge 1 -and $n -le $items.Count)) { continue }
                $choice = $n - 1
            }
        }
        $item = $items[$choice]
        if ($item.Kind -eq 'folder') { return $item.Path }
        $selected = $choice
        $pasted = Read-PastedFolder
        if ($pasted) { return $pasted }
    }
}

$target = Select-Folder
try { Set-Content -LiteralPath $lastPick -Value $target -Encoding UTF8 -ErrorAction Stop } catch {}

if ($DryRun) { Write-Output "CHOSEN: $target"; return }

Set-Location -LiteralPath $target
Clear-Host
Write-Host "  Starting Claude in $target" -ForegroundColor DarkGray
& claude @ClaudeArgs
