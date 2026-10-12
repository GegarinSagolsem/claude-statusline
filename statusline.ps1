[Console]::OutputEncoding = [Text.Encoding]::UTF8
$j = [Console]::In.ReadToEnd() | ConvertFrom-Json

$e = [char]27
$reset = "$e[0m"; $dim = "$e[90m"; $bold = "$e[1m"
$full = [char]0x2588; $empty = [char]0x2591; $sep = " $dim$([char]0x2502)$reset "

function Color($pct) {
    if ($pct -ge 80) { "$e[31m" } elseif ($pct -ge 50) { "$e[33m" } else { "$e[32m" }
}
function Bar($pct, $width) {
    $p = [Math]::Max(0, [Math]::Min(100, [double]$pct))
    $n = [int][Math]::Round($p / 100 * $width)
    if ($p -gt 0 -and $n -eq 0) { $n = 1 }
    "$(Color $p)$([string]$full * $n)$dim$([string]$empty * ($width - $n))$reset"
}
# Context bar with markers: yellow '|' at 50% (good time to switch), red '|' at 80% (red zone)
function ContextBar($pct, $width) {
    $p = [Math]::Max(0, [Math]::Min(100, [double]$pct))
    $n = [int][Math]::Round($p / 100 * $width)
    if ($p -gt 0 -and $n -eq 0) { $n = 1 }
    $switchAt = [int]($width * 0.5); $redAt = [int]($width * 0.8)
    $c = Color $p
    $s = ""
    for ($i = 0; $i -lt $width; $i++) {
        if ($i -eq $switchAt) { $s += "$e[33m|" }
        if ($i -eq $redAt) { $s += "$e[31m|" }
        if ($i -lt $n) { $s += "$c$full" } else { $s += "$dim$empty" }
    }
    "$s$reset"
}
function Tokens($n) {
    if ($n -ge 1000000) { "{0:0.#}M" -f ($n / 1000000) }
    elseif ($n -ge 1000) { "{0:0.#}k" -f ($n / 1000) }
    else { "$n" }
}
function Until($epoch) {
    $span = [DateTimeOffset]::FromUnixTimeSeconds([long]$epoch) - [DateTimeOffset]::UtcNow
    if ($span.TotalMinutes -lt 1) { return "now" }
    if ($span.TotalHours -ge 1) { "{0}h {1}m" -f [int][Math]::Floor($span.TotalHours), $span.Minutes }
    else { "{0}m" -f $span.Minutes }
}
function WeekDay($epoch) {
    [DateTimeOffset]::FromUnixTimeSeconds([long]$epoch).ToLocalTime().ToString("ddd h:mm tt")
}

# Line 1: prompt-style folder and model
$dir = $j.workspace.current_dir
if (-not $dir) { $dir = $j.cwd }
$line1 = "PS $dir>"
if ($j.model.display_name) { $line1 += " $bold$($j.model.display_name)$reset" }

# Line 2: context window and plan usage limits
$parts = @()
$cw = $j.context_window
if ($cw -and $cw.context_window_size) {
    $u = $cw.current_usage
    $used = 0
    if ($u) { $used = [long]$u.input_tokens + [long]$u.cache_creation_input_tokens + [long]$u.cache_read_input_tokens }
    $pct = $cw.used_percentage
    if ($null -eq $pct) { $pct = [Math]::Round($used * 100 / $cw.context_window_size) }
    $parts += "Context $(ContextBar $pct 20) $(Tokens $used)/$(Tokens $cw.context_window_size) $(Color $pct)$pct%$reset"
}
$rl = $j.rate_limits
if ($rl.five_hour) {
    $p = $rl.five_hour.used_percentage
    $parts += "Session $(Bar $p 8) $(Color $p)$p%$reset $dim(resets in $(Until $rl.five_hour.resets_at))$reset"
}
if ($rl.seven_day) {
    $p = $rl.seven_day.used_percentage
    $parts += "Weekly $(Bar $p 8) $(Color $p)$p%$reset $dim(resets $(WeekDay $rl.seven_day.resets_at))$reset"
}

Write-Output $line1
if ($parts.Count) { Write-Output ($parts -join $sep) }
