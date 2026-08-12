@echo off
rem ===================================================================
rem  cs2-config setup - saves your CS2 settings into a portable folder.
rem
rem  Double-click this file. Nothing else is needed: the PowerShell
rem  script is stored in plain text below the marker at the bottom of
rem  this header, and you can read it in Notepad or on GitHub.
rem
rem  cmd stops reading at the exit below, so the marker and everything
rem  after it are never parsed as batch. PowerShell re-reads this same
rem  file as UTF-8, which is why the Russian text in it survives.
rem
rem  https://github.com/oceanvievv/cs2-config
rem ===================================================================

setlocal
title cs2-config setup

rem  Russian output needs a console codepage that can render Cyrillic; a stock
rem  Russian Windows console is 866. Switch to UTF-8 and put the old one back on
rem  the way out, so running this from an existing terminal leaves no trace.
set "CP="
for /f "tokens=2 delims=:" %%c in ('chcp') do set "CP=%%c"
chcp 65001 >nul

set "PS1=%TEMP%\cs2-config-setup.ps1"

rem  The script writes the finished pack's path here; only it knows where that is.
set "OUTF=%TEMP%\cs2-config-outdir.txt"
if exist "%OUTF%" del "%OUTF%"

rem  Handed over as environment variables rather than pasted into the command line:
rem  an apostrophe in the path would otherwise break the PowerShell string. SELFDIR is
rem  where the pack gets built, so that this file placed inside a pack updates it.
set "SELF=%~f0"
set "SELFDIR=%~dp0"
powershell -NoProfile -Command "$m='::'+'PS1'+'::'; $t=[IO.File]::ReadAllText($env:SELF,[Text.Encoding]::UTF8); $i=$t.LastIndexOf($m); if($i -lt 0){exit 1}; [IO.File]::WriteAllText($env:TEMP+'\cs2-config-setup.ps1', $t.Substring($i+$m.Length), (New-Object Text.UTF8Encoding($true)))"
if not exist "%PS1%" goto broken

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
if errorlevel 1 goto failed
echo.
pause
call :openpack
call :restorecp
exit /b 0

:broken
echo.
echo Could not unpack the script from this file.
echo Re-download it: some editors and chat apps corrupt .cmd files.
echo.
pause
call :restorecp
exit /b 1

:failed
echo.
echo The script did not finish. Read the message above.
echo A copy of it is at %PS1% if you want to run it by hand.
echo.
pause
call :restorecp
exit /b 1

:openpack
rem  Open the finished pack in Explorer, so nobody has to go hunting for it.
if not exist "%OUTF%" goto :eof
for /f "usebackq delims=" %%d in ("%OUTF%") do if exist "%%d" start "" "%%d"
del "%OUTF%"
goto :eof

:restorecp
if defined CP chcp %CP% >nul
goto :eof

::PS1::
<#
.SYNOPSIS
    Packs your CS2 settings into a portable bundle that restores itself on any PC.

.DESCRIPTION
    Steam Cloud syncs your sensitivity, crosshair and binds. It does not sync the .cfg
    files in the game folder, your video settings, or your launch options. Lose those and
    a borrowed PC feels wrong in ways you notice mid-round.

    This script reads all of it off your machine and writes a folder containing:

      apply-config.cmd   double-click it on the other PC; every config is
                             embedded in it, so this one file puts everything back
      apply-config-using-console.txt      fallback for locked-down PCs: paste into the console
      cfg/ video/ cloud-backup/
      README.md, README.ru.md

    Nothing is uploaded. The folder is yours; publish it or keep it on a USB stick.

    Double-clicking is the whole interface: which configs are yours, which one is the main
    one, your crosshair, your launch options, your name and your language are all detected.

    The parameters below are escape hatches for when detection gets it wrong, or for
    driving this from a script. They are deliberately left out of the README, because a
    flag you cannot pass by double-clicking is not something to put in front of everyone.

.PARAMETER Name
    Pack name. Defaults to your in-game name.

.PARAMETER OutDir
    Where to write the pack. Defaults to your Desktop: cs2-config-<name>

.PARAMETER Main
    Your main config, the one autoexec should run (e.g. myconfig.cfg). Auto-detected when
    unambiguous: the config that no other config or bind already execs.

.PARAMETER Include
    Extra filenames from the game cfg folder to pack that detection skipped.

.PARAMETER Exclude
    Filenames to leave out.

.PARAMETER RepoUrl
    Your GitHub repo URL, if you plan to publish. Bakes a working one-line installer into
    the generated README instead of leaving <you> and <repo> to fill in by hand.

.PARAMETER Anonymize
    Strip your in-game name from the packed settings.

.PARAMETER Force
    Skip the notice about overwriting an existing pack folder.

.EXAMPLE
    setup.cmd

.EXAMPLE
    setup.cmd -Main myconfig.cfg -RepoUrl https://github.com/me/cs2-config-me
#>
param(
    [string]   $Name,
    [string]   $OutDir,
    [string]   $Main,
    [string[]] $Include = @(),
    [string[]] $Exclude = @(),
    [string]   $RepoUrl,
    [switch]   $Anonymize,
    [switch]   $Force
)

$ErrorActionPreference = 'Stop'
$TOOL_VERSION = '1.6.2'
$TOOL_URL     = 'https://github.com/oceanvievv/cs2-config'

# The Windows display language decides, and nothing else. Keyboard layouts are
# deliberately not consulted: having a Russian layout says nothing about which language
# you want your tools in.
$Lang = 'en'
try {
    if ((Get-UICulture).TwoLetterISOLanguageName -eq 'ru') { $Lang = 'ru' }
} catch { }

# Every message carries both languages at the call site. Passing only English is fine
# and means "same in both", which is what you want for paths and file names.
function L($en, $ru) {
    if ($Lang -eq 'ru' -and $ru) { return $ru }
    return $en
}
function Info($en, $ru) { Write-Host "     $(L $en $ru)" }
function Ok  ($en, $ru) { Write-Host "OK   $(L $en $ru)" -ForegroundColor Green }
function Warn($en, $ru) { Write-Host "WARN $(L $en $ru)" -ForegroundColor Yellow }
function Die ($en, $ru) { Write-Host "FAIL $(L $en $ru)" -ForegroundColor Red; exit 1 }
function Head($en, $ru) { Write-Host ''; Write-Host (L $en $ru) -ForegroundColor Cyan }

# Pad a label to a fixed column so the two languages line up the same way.
function Lbl($en, $ru) { return (L $en $ru).PadRight(18) }

$UTF8 = New-Object System.Text.UTF8Encoding($false)   # no BOM: everything this writes

# ==================================================================================
#  Detection
# ==================================================================================

# Windows does not care how a path is spelled, but whoever reads the output does. Steam
# writes SteamPath into the registry all lower case and with forward slashes, like
# c:/program files (x86)/steam. The slashes are a substitution; how the folders are really
# spelled only the filesystem knows, so every segment is looked up in its parent.
function Get-TruePath($path) {
    $dir = New-Object IO.DirectoryInfo $path
    if (-not $dir.Exists) { return $path }
    $parts = New-Object System.Collections.Generic.List[string]
    while ($dir.Parent) {
        $hit = $dir.Parent.GetDirectories($dir.Name)
        if ($hit.Count -lt 1) { return $path }
        $parts.Insert(0, $hit[0].Name)
        $dir = $dir.Parent
    }
    # Only a drive letter is worth upper-casing. A UNC root is spelled by its server.
    $root = $dir.Name.TrimEnd('\')
    if ($root -match '^[a-z]:$') { $root = $root.ToUpper() }
    if ($parts.Count -eq 0) { return "$root\" }
    return $root + '\' + ($parts -join '\')
}

function Get-SteamPath {
    foreach ($k in @('HKCU:\Software\Valve\Steam',
                     'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
                     'HKLM:\SOFTWARE\Valve\Steam')) {
        if (Test-Path $k) {
            $p = Get-ItemProperty $k
            $raw = $p.SteamPath
            if (-not $raw) { $raw = $p.InstallPath }
            if ($raw) { return Get-TruePath (($raw -replace '/', '\').TrimEnd('\')) }
        }
    }
    return $null
}

function Get-CS2CfgPath($steam) {
    $roots = New-Object System.Collections.Generic.List[string]
    $roots.Add($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        foreach ($line in Get-Content $vdf) {
            if ($line -match '"path"\s+"(.+?)"') { $roots.Add(($matches[1] -replace '\\\\', '\')) }
        }
    }
    foreach ($r in $roots) {
        $p = Join-Path $r 'steamapps\common\Counter-Strike Global Offensive\game\csgo\cfg'
        if (Test-Path $p) { return Get-TruePath $p }
    }
    return $null
}

function Get-SteamAccountId($steam) {
    if (Test-Path 'HKCU:\Software\Valve\Steam\ActiveProcess') {
        $id = (Get-ItemProperty 'HKCU:\Software\Valve\Steam\ActiveProcess').ActiveUser
        if ($id -and $id -ne 0 -and (Test-Path (Join-Path $steam "userdata\$id\730"))) { return "$id" }
    }
    $ud = Join-Path $steam 'userdata'
    if (-not (Test-Path $ud)) { return $null }
    $best = Get-ChildItem $ud -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName '730\local\cfg') } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($best) { return $best.Name }
    return $null
}

# Launch options live in the 730 block of localconfig.vdf. Other apps have their own
# "LaunchOptions" lines, so walk back to the nearest app id and check it.
function Get-LaunchOptions($steam, $accountId) {
    $lc = Join-Path $steam "userdata\$accountId\config\localconfig.vdf"
    if (-not (Test-Path $lc)) { return $null }
    $lines = Get-Content $lc
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '"LaunchOptions"\s+"(.*)"\s*$') {
            $value = $matches[1]
            for ($j = $i; $j -ge 0 -and $j -gt $i - 60; $j--) {
                if ($lines[$j] -match '^\s*"(\d{3,7})"\s*$') {
                    if ($matches[1] -eq '730') { return $value }
                    break
                }
            }
        }
    }
    return $null
}

# Parse a VDF-ish "key"  "value" file into an ordered map.
function Read-VdfPairs($path) {
    $map = [ordered]@{}
    if (-not (Test-Path $path)) { return $map }
    foreach ($line in Get-Content $path) {
        if ($line -match '^\s*"([^"]+)"\s+"(.*)"\s*$') { $map[$matches[1]] = $matches[2] }
    }
    return $map
}

# ==================================================================================
#  Which .cfg files are actually yours
# ==================================================================================

$StockPrefixes = @('gamemode_', 'valve_', 'subscribed_', 'banned_', 'default_',
                   '360', 'joystick', 'undo_', 'config_default')
$StockExact    = @('server.cfg', 'server_default.cfg', 'perftest.cfg', 'default.cfg',
                   'config.cfg', 'video.cfg', 'videodefaults.cfg')

function Get-UserCfgFiles($cfgDir) {
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($f in (Get-ChildItem $cfgDir -Filter *.cfg -File | Sort-Object Name)) {
        if ($Exclude -contains $f.Name) { continue }
        $isStock = $false
        if ($StockExact -contains $f.Name.ToLower()) { $isStock = $true }
        foreach ($p in $StockPrefixes) {
            if ($f.Name.ToLower().StartsWith($p)) { $isStock = $true; break }
        }
        if ($isStock -and -not ($Include -contains $f.Name)) { continue }
        $out.Add($f)
    }
    return $out
}

# The main config is the one nothing else runs. Anything reached by `exec x` from another
# config or from a keybind is a sub-mode (practice, knife, ...) and must not autoexec.
function Find-MainCfg($files, $keysPath) {
    # An existing autoexec is the most direct evidence: whatever it execs is the main one.
    $auto = @($files | Where-Object { $_.Name.ToLower() -eq 'autoexec.cfg' })
    if ($auto.Count -gt 0) {
        $atext = [IO.File]::ReadAllText($auto[0].FullName)
        foreach ($m in [regex]::Matches($atext, '(?i)\bexec\s+"?([A-Za-z0-9_\-\.]+)"?')) {
            $n = $m.Groups[1].Value
            if (-not $n.ToLower().EndsWith('.cfg')) { $n = "$n.cfg" }
            if ($n.ToLower() -eq 'crosshair.cfg') { continue }
            $hit = @($files | Where-Object { $_.Name.ToLower() -eq $n.ToLower() })
            if ($hit.Count -eq 1) { return $hit[0].Name }
        }
    }
    $referenced = New-Object System.Collections.Generic.HashSet[string]
    $sources = New-Object System.Collections.Generic.List[string]
    foreach ($f in $files) { $sources.Add([IO.File]::ReadAllText($f.FullName)) }
    if ($keysPath -and (Test-Path $keysPath)) { $sources.Add([IO.File]::ReadAllText($keysPath)) }
    foreach ($text in $sources) {
        foreach ($m in [regex]::Matches($text, '(?i)\bexec\s+"?([A-Za-z0-9_\-\.]+)"?')) {
            $n = $m.Groups[1].Value
            if (-not $n.ToLower().EndsWith('.cfg')) { $n = "$n.cfg" }
            [void]$referenced.Add($n.ToLower())
        }
    }
    $candidates = @($files | Where-Object {
        $_.Name.ToLower() -ne 'autoexec.cfg' -and -not $referenced.Contains($_.Name.ToLower())
    })
    if ($candidates.Count -eq 1) { return $candidates[0].Name }
    return $null
}

# ==================================================================================
#  Launch option portability
# ==================================================================================

# Flags that take a following value token.
$ValueFlags = @('-threads', '-w', '-width', '-h', '-height', '-refresh', '-freq',
                '-language', '-dxlevel', '-tickrate', '-maxplayers')

# Flags worth dropping when the pack lands on unknown hardware.
$NotPortable = @{
    '-threads'                     = 'thread count is specific to this CPU'
    '-high'                        = 'high priority can starve audio and input on a faster CPU'
    '-w'                           = 'resolution differs on another monitor'
    '-width'                       = 'resolution differs on another monitor'
    '-h'                           = 'resolution differs on another monitor'
    '-height'                      = 'resolution differs on another monitor'
    '-refresh'                     = 'refresh rate differs on another monitor'
    '-freq'                        = 'refresh rate differs on another monitor'
    '-softparticlesdefaultoff'     = 'lowers quality to gain fps you may not need'
    '-low'                         = 'lowers quality to gain fps you may not need'
    '-lowmemory'                   = 'lowers quality to gain fps you may not need'
    '-nod3d9ex'                    = 'legacy workaround, not needed'
    '-disable_d3d9ex'              = 'legacy workaround, not needed'
    '-dxlevel'                     = 'legacy, forces a renderer level'
    '-processheap'                 = 'legacy workaround, not needed'
    '+mat_disable_fancy_blending'  = 'lowers quality to gain fps you may not need'
}

$NotPortableRu = @{
    '-threads'                     = 'число потоков подобрано под этот процессор'
    '-high'                        = 'высокий приоритет на быстром процессоре мешает звуку и вводу'
    '-w'                           = 'на другом мониторе другое разрешение'
    '-width'                       = 'на другом мониторе другое разрешение'
    '-h'                           = 'на другом мониторе другое разрешение'
    '-height'                      = 'на другом мониторе другое разрешение'
    '-refresh'                     = 'на другом мониторе другая частота обновления'
    '-freq'                        = 'на другом мониторе другая частота обновления'
    '-softparticlesdefaultoff'     = 'жертвует качеством ради кадров, которых там хватит'
    '-low'                         = 'жертвует качеством ради кадров, которых там хватит'
    '-lowmemory'                   = 'жертвует качеством ради кадров, которых там хватит'
    '-nod3d9ex'                    = 'устаревший костыль, больше не нужен'
    '-disable_d3d9ex'              = 'устаревший костыль, больше не нужен'
    '-dxlevel'                     = 'устаревший флаг, жёстко задаёт уровень рендера'
    '-processheap'                 = 'устаревший костыль, больше не нужен'
    '+mat_disable_fancy_blending'  = 'жертвует качеством ради кадров, которых там хватит'
}

function Split-LaunchOptions($raw) {
    $tokens = @($raw -split '\s+' | Where-Object { $_ -ne '' })
    $items = New-Object System.Collections.Generic.List[object]
    $i = 0
    while ($i -lt $tokens.Count) {
        $t = $tokens[$i]
        $val = $null
        # every +convar takes one value; -flags only when known to
        if ($t.StartsWith('+') -or ($ValueFlags -contains $t.ToLower())) {
            if ($i + 1 -lt $tokens.Count -and -not ($tokens[$i + 1] -match '^[+\-]')) {
                $val = $tokens[$i + 1]; $i++
            }
        }
        $items.Add([pscustomobject]@{ Flag = $t; Value = $val })
        $i++
    }
    return $items
}

function Get-PortableLaunchOptions($raw) {
    $kept    = New-Object System.Collections.Generic.List[string]
    $dropped = New-Object System.Collections.Generic.List[object]
    foreach ($item in (Split-LaunchOptions $raw)) {
        $key = $item.Flag.ToLower()
        $text = $item.Flag
        if ($null -ne $item.Value) { $text = "$($item.Flag) $($item.Value)" }
        if ($NotPortable.ContainsKey($key)) {
            $dropped.Add([pscustomobject]@{
                Text  = $text
                Why   = $NotPortable[$key]
                WhyRu = $NotPortableRu[$key]
            })
        } else {
            $kept.Add($text)
        }
    }
    return [pscustomobject]@{ Portable = ($kept -join ' '); Dropped = $dropped }
}

# ==================================================================================
#  Go
# ==================================================================================

Head '=== cs2-config setup ======================================='

$steam = Get-SteamPath
if (-not $steam) {
    Die 'Steam not found in the registry. Is Steam installed?' `
        'Steam не найден в реестре. Он вообще установлен?'
}
Ok "$(Lbl 'Steam' 'Steam')$steam"

$cfgDir = Get-CS2CfgPath $steam
if (-not $cfgDir) {
    Die 'CS2 not found in any Steam library.' `
        'CS2 не найдена ни в одной библиотеке Steam.'
}
Ok "$(Lbl 'CS2 cfg folder' 'Папка cfg')$cfgDir"

$accountId = Get-SteamAccountId $steam
$userCfgDir = $null
if ($accountId) {
    $userCfgDir = Join-Path $steam "userdata\$accountId\730\local\cfg"
    Ok "$(Lbl 'Steam account' 'Аккаунт Steam')$accountId"
} else {
    Warn 'No CS2 userdata folder found. Video settings and cloud backup will be skipped.' `
         'Папка userdata для CS2 не найдена. Настройки видео и копию Steam Cloud пропускаю.'
}

$convarsPath = $null
$keysPath    = $null
$videoPath   = $null
if ($userCfgDir -and (Test-Path $userCfgDir)) {
    $c = Join-Path $userCfgDir 'cs2_user_convars_0_slot0.vcfg'
    $k = Join-Path $userCfgDir 'cs2_user_keys_0_slot0.vcfg'
    $v = Join-Path $userCfgDir 'cs2_video.txt'
    if (Test-Path $c) { $convarsPath = $c }
    if (Test-Path $k) { $keysPath    = $k }
    if (Test-Path $v) { $videoPath   = $v }
}

$convars = Read-VdfPairs $convarsPath

# --- name -------------------------------------------------------------------------
$playerName = $null
if ($convars.Contains('name')) { $playerName = $convars['name'] }
if (-not $Name) {
    if ($playerName) { $Name = $playerName } else { $Name = 'me' }
}
$slug = ($Name -replace '[^A-Za-z0-9_\-]', '').ToLower()
if ($slug -eq '') { $slug = 'me' }
Ok "$(Lbl 'Pack name' 'Название')$Name"

# The pack lands next to the launcher that made it. Two cases, and telling them apart
# is what makes update-config.cmd work: launched from inside a pack, it rebuilds that
# pack in place; launched from anywhere else, it creates cs2-config alongside itself.
if (-not $OutDir) {
    $here = $env:SELFDIR
    if (-not $here) { $here = (Get-Location).Path }
    $here = $here.TrimEnd('\')
    if (Test-Path (Join-Path $here 'apply-config.cmd')) {
        $OutDir = $here
    } else {
        $OutDir = Join-Path $here 'cs2-config'
    }
}

if ((Test-Path $OutDir) -and -not $Force) {
    $existing = @(Get-ChildItem $OutDir -Force -ErrorAction SilentlyContinue)
    if ($existing.Count -gt 0) {
        Warn "$OutDir already exists and is not empty." `
             "Папка $OutDir уже есть и не пуста."
        Info 'Its cfg/, video/, cloud-backup/ and generated files will be replaced.' `
             'Папки cfg/, video/, cloud-backup/ и созданные файлы будут перезаписаны.'
        Info 'Anything else in the folder is left alone.' `
             'Остальное в папке не трогается.'
    }
}

# --- configs ----------------------------------------------------------------------
$userCfgs = Get-UserCfgFiles $cfgDir
if ($userCfgs.Count -eq 0) {
    Warn 'No user configs found in the game cfg folder.' `
         'В папке cfg не нашлось ни одного твоего конфига.'
    Info 'If you keep configs elsewhere, copy them into that folder and run this again.' `
         'Если держишь их в другом месте — перенеси их туда и запусти снова.'
} else {
    Ok "$(Lbl 'Configs found' 'Найдено конфигов')$($userCfgs.Count)"
    foreach ($f in $userCfgs) { Info "  $($f.Name)" }
}

if (-not $Main) { $Main = Find-MainCfg $userCfgs $keysPath }
$hasOwnAutoexec = @($userCfgs | Where-Object { $_.Name.ToLower() -eq 'autoexec.cfg' }).Count -gt 0
if ($Main) {
    Ok "$(Lbl 'Main config' 'Главный конфиг')$Main"
} elseif (-not $hasOwnAutoexec) {
    Warn 'Could not tell which config is your main one.' `
         'Не понял, какой из конфигов главный.'
    Info 'autoexec will only load the crosshair. Point your own autoexec.cfg at it instead.' `
         'autoexec подтянет только прицел. Пропиши нужный exec в своём autoexec.cfg.'
}

# --- crosshair ---------------------------------------------------------------------
# CS2 packs a whole crosshair into 18 bytes and prints them as base-57. Rebuilding that
# code here means the summary shows something you can paste into any client or send to
# someone, instead of a count of convars that tells you nothing. Byte layout follows the
# maintained reference implementation, github.com/akiver/csgo-sharecode.
$XH_DICT = 'ABCDEFGHJKLMNOPQRSTUVWXYZabcdefhijkmnopqrstuvwxyz23456789'

# Convars are strings, and CS2 writes booleans as true/false. Anything unreadable falls
# back to 0, which is what the game itself would show for a convar it never wrote.
function Cv-Num($map, $key) {
    if (-not $map.Contains($key)) { return 0.0 }
    $v = ([string]$map[$key]).Trim()
    if ($v -eq 'true')  { return 1.0 }
    if ($v -eq 'false') { return 0.0 }
    $out = 0.0
    if ([double]::TryParse($v, [Globalization.NumberStyles]::Float,
                           [Globalization.CultureInfo]::InvariantCulture, [ref]$out)) { return $out }
    return 0.0
}
# The format stores tenths and halves as whole bytes, so every field is scaled then
# rounded. A slider set to 1.875223 comes back as 1.9, exactly as the game encodes it.
function Cv-Scaled($map, $key, $scale) {
    return [int][math]::Round((Cv-Num $map $key) * $scale, [MidpointRounding]::AwayFromZero)
}
function Cv-Flag($map, $key) {
    if ((Cv-Num $map $key) -ne 0) { return 1 }
    return 0
}

function Get-CrosshairShareCode($map) {
    $b = New-Object byte[] 18
    $b[1]  = 1                                                    # format version
    $b[2]  = (Cv-Scaled $map 'cl_crosshairgap' 10) -band 0xff      # signed, wraps
    $b[3]  = (Cv-Scaled $map 'cl_crosshair_outlinethickness' 2) -band 0xff
    $b[4]  = (Cv-Scaled $map 'cl_crosshaircolor_r' 1) -band 0xff
    $b[5]  = (Cv-Scaled $map 'cl_crosshaircolor_g' 1) -band 0xff
    $b[6]  = (Cv-Scaled $map 'cl_crosshaircolor_b' 1) -band 0xff
    $b[7]  = (Cv-Scaled $map 'cl_crosshairalpha' 1) -band 0xff
    $b[8]  = ((Cv-Scaled $map 'cl_crosshair_dynamic_splitdist' 1) -band 7) -bor
             ((Cv-Flag $map 'cl_crosshair_recoil') -shl 7)
    $b[9]  = (Cv-Scaled $map 'cl_fixedcrosshairgap' 10) -band 0xff # signed, wraps
    $b[10] = ((Cv-Scaled $map 'cl_crosshaircolor' 1) -band 7) -bor
             ((Cv-Flag $map 'cl_crosshair_drawoutline') -shl 3) -bor
             (((Cv-Scaled $map 'cl_crosshair_dynamic_splitalpha_innermod' 10) -band 0xF) -shl 4)
    $b[11] = ((Cv-Scaled $map 'cl_crosshair_dynamic_splitalpha_outermod' 10) -band 0xF) -bor
             (((Cv-Scaled $map 'cl_crosshair_dynamic_maxdist_splitratio' 10) -band 0xF) -shl 4)
    $b[12] = (Cv-Scaled $map 'cl_crosshairthickness' 10) -band 0xff
    $b[13] = (((Cv-Scaled $map 'cl_crosshairstyle' 1) -band 7) -shl 1) -bor
             ((Cv-Flag $map 'cl_crosshairdot') -shl 4) -bor
             ((Cv-Flag $map 'cl_crosshairgap_useweaponvalue') -shl 5) -bor
             ((Cv-Flag $map 'cl_crosshairusealpha') -shl 6) -bor
             ((Cv-Flag $map 'cl_crosshair_t') -shl 7)
    $b[14] = (Cv-Scaled $map 'cl_crosshairsize' 10) -band 0xff

    # Byte 0 is a checksum over the rest; CS2 refuses the code without it.
    $sum = 0
    for ($i = 1; $i -lt 18; $i++) { $sum += $b[$i] }
    $b[0] = $sum -band 0xff

    $total = [System.Numerics.BigInteger]::Zero
    foreach ($x in $b) { $total = $total * 256 + [int]$x }
    $out = ''
    for ($i = 0; $i -lt 25; $i++) {
        $out += $XH_DICT[[int]($total % 57)]
        $total = [System.Numerics.BigInteger]::Divide($total, 57)
    }
    return "CSGO-$($out.Substring(0,5))-$($out.Substring(5,5))-$($out.Substring(10,5))-" +
           "$($out.Substring(15,5))-$($out.Substring(20,5))"
}

$crosshair = [ordered]@{}
foreach ($k in $convars.Keys) {
    if ($k -match '^(cl_crosshair|cl_fixedcrosshairgap)') { $crosshair[$k] = $convars[$k] }
}
if ($crosshair.Count -gt 0) {
    $shareCode = $null
    try { $shareCode = Get-CrosshairShareCode $convars } catch { $shareCode = $null }
    if ($shareCode) {
        Ok "$(Lbl 'Crosshair' 'Прицел')$shareCode"
    } else {
        Ok "$(Lbl 'Crosshair' 'Прицел')$($crosshair.Count) convars captured" `
           "$(Lbl 'Crosshair' 'Прицел')переменных снято: $($crosshair.Count)"
    }
} else {
    Warn 'No crosshair convars found. Launch CS2 once so it writes its settings.' `
         'Переменные прицела не найдены. Зайди в CS2 один раз, чтобы она их записала.'
}

# --- launch options ------------------------------------------------------------------
$launchRaw = $null
if ($accountId) { $launchRaw = Get-LaunchOptions $steam $accountId }
$launch = $null
if ($launchRaw) {
    $launch = Get-PortableLaunchOptions $launchRaw
    Ok "$(Lbl 'Launch options' 'Параметры запуска')captured" `
       "$(Lbl 'Launch options' 'Параметры запуска')считаны"
    if ($launch.Dropped.Count -gt 0) {
        Info "  $($launch.Dropped.Count) flag(s) not portable, see the pack README" `
             "  не переносится флагов: $($launch.Dropped.Count), подробности в README набора"
    }
} else {
    Warn 'No launch options set for CS2 (or none found).' `
         'Параметры запуска у CS2 не заданы, либо найти их не вышло.'
}

# ==================================================================================
#  Assemble
# ==================================================================================

Head '--- building pack ---' '--- собираю набор ---'

foreach ($sub in @('cfg', 'video', 'cloud-backup')) {
    $p = Join-Path $OutDir $sub
    if (Test-Path $p) { Remove-Item $p -Recurse -Force }
    New-Item -ItemType Directory -Force $p | Out-Null
}

$packCfg = Join-Path $OutDir 'cfg'
foreach ($f in $userCfgs) {
    if ($f.Name.ToLower() -eq 'autoexec.cfg') { continue }   # rebuilt below
    Copy-Item $f.FullName $packCfg -Force
}

# crosshair.cfg
if ($crosshair.Count -gt 0) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('// Crosshair, read from your CS2 settings by cs2-config.')
    [void]$sb.AppendLine('// Applying this needs no share code.')
    [void]$sb.AppendLine('')
    foreach ($k in $crosshair.Keys) { [void]$sb.AppendLine("$k `"$($crosshair[$k])`"") }
    [IO.File]::WriteAllText((Join-Path $packCfg 'crosshair.cfg'), $sb.ToString(), $UTF8)
}

# autoexec.cfg: keep the user's own content, then add what is missing
$autoBody = ''
$ownAutoexec = @($userCfgs | Where-Object { $_.Name.ToLower() -eq 'autoexec.cfg' })
if ($ownAutoexec.Count -gt 0) { $autoBody = [IO.File]::ReadAllText($ownAutoexec[0].FullName).TrimEnd() }

$needed = New-Object System.Collections.Generic.List[string]
if ($crosshair.Count -gt 0 -and $autoBody -notmatch '(?i)\bexec\s+"?crosshair') { $needed.Add('exec crosshair') }
if ($Main) {
    $mainBare = [IO.Path]::GetFileNameWithoutExtension($Main)
    if ($autoBody -notmatch "(?i)\bexec\s+`"?$([regex]::Escape($mainBare))") { $needed.Add("exec $mainBare") }
}

$auto = New-Object System.Text.StringBuilder
if ($autoBody -ne '') {
    [void]$auto.AppendLine($autoBody)
    [void]$auto.AppendLine('')
    [void]$auto.AppendLine('// ---- added by cs2-config ----')
} else {
    [void]$auto.AppendLine('// CS2 runs this file automatically on startup.')
    [void]$auto.AppendLine('// Generated by cs2-config.')
    [void]$auto.AppendLine('')
}
foreach ($line in $needed) { [void]$auto.AppendLine($line) }
if ($autoBody -eq '') {
    [void]$auto.AppendLine('')
    [void]$auto.AppendLine('host_writeconfig')
} elseif ($needed.Count -gt 0 -and $autoBody -match '(?i)\bhost_writeconfig\b') {
    # Their own host_writeconfig ran before the lines we just appended, so it would not
    # persist them. Run it once more at the end.
    [void]$auto.AppendLine('host_writeconfig')
}
[IO.File]::WriteAllText((Join-Path $packCfg 'autoexec.cfg'), $auto.ToString(), $UTF8)

# video + cloud backup
$hasVideo = $false
if ($videoPath) {
    Copy-Item $videoPath (Join-Path $OutDir 'video') -Force
    $hasVideo = $true
}
$cloudFiles = @()
foreach ($p in @($convarsPath, $keysPath)) {
    if (-not $p) { continue }
    $dest = Join-Path (Join-Path $OutDir 'cloud-backup') (Split-Path -Leaf $p)
    if ($Anonymize -and $p -eq $convarsPath) {
        $text = [IO.File]::ReadAllText($p) -replace '(?m)^(\s*"name"\s+")[^"]*(")', '${1}player${2}'
        [IO.File]::WriteAllText($dest, $text, $UTF8)
    } else {
        Copy-Item $p $dest -Force
    }
    $cloudFiles += (Split-Path -Leaf $p)
}
if ($Anonymize) {
    Ok "$(Lbl 'Anonymized' 'Обезличено')in-game name stripped" `
       "$(Lbl 'Anonymized' 'Обезличено')игровой ник убран"
}

$packedCfgs = @(Get-ChildItem $packCfg -Filter *.cfg | Sort-Object Name)
Ok "$(Lbl 'cfg/' 'cfg/')$($packedCfgs.Count) files" "$(Lbl 'cfg/' 'cfg/')файлов: $($packedCfgs.Count)"
if ($hasVideo)         { Ok "$(Lbl 'video/' 'video/')cs2_video.txt" }
if ($cloudFiles.Count) {
    Ok "$(Lbl 'cloud-backup/' 'cloud-backup/')$($cloudFiles.Count) files" `
       "$(Lbl 'cloud-backup/' 'cloud-backup/')файлов: $($cloudFiles.Count)"
}

# ==================================================================================
#  Generate apply-config.ps1
# ==================================================================================

function Read-Payload($path) {
    $text = [IO.File]::ReadAllText($path)
    foreach ($line in ($text -split "`r?`n")) {
        if ($line -match "^\s*'@") { Die "$path has a line starting with '@ and cannot be embedded" }
    }
    return $text.TrimEnd("`r", "`n")
}

function Emit-Map($varName, $dir, $filter) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("`$$varName = [ordered]@{}")
    if (Test-Path $dir) {
        foreach ($f in (Get-ChildItem $dir -Filter $filter -File | Sort-Object Name)) {
            [void]$sb.AppendLine("`$$varName['$($f.Name)'] = @'")
            [void]$sb.AppendLine((Read-Payload $f.FullName))
            [void]$sb.AppendLine("'@")
        }
    }
    return $sb.ToString()
}

$payload  = Emit-Map 'GameCfg'  $packCfg                               '*.cfg'
$payload += Emit-Map 'VideoCfg' (Join-Path $OutDir 'video')            '*.txt'
$payload += Emit-Map 'CloudCfg' (Join-Path $OutDir 'cloud-backup')     '*.vcfg'

$launchPortable = ''
if ($launch) { $launchPortable = $launch.Portable }

$restoreConsts =
    "`$PackName      = '$($Name -replace "'", "''")'`r`n" +
    "`$LaunchOptions = '$($launchPortable -replace "'", "''")'`r`n" +
    "`$ToolUrl       = '$TOOL_URL'`r`n"

$restoreHead = @'
<#
    CS2 settings pack. SELF-CONTAINED - every config is embedded below, so this one
    file is all you need on another PC. No git, no ZIP, no internet.

    Double-click apply-config.cmd and pick from the menu, or pass a switch to it
    and the menu is skipped:

      apply-config.cmd            configs only
      apply-config.cmd -Video     also apply resolution and quality
      apply-config.cmd -Convars   also restore sensitivity and binds (if Steam Cloud failed)
      apply-config.cmd -Check     show what differs, write nothing
      apply-config.cmd -Undo      put this PC back the way you found it

    GENERATED FILE. Rebuild it with update-config.cmd instead of editing it.
#>
param(
    [switch]$Video,
    [switch]$Convars,
    [switch]$Check,
    [switch]$Undo
)

$ErrorActionPreference = 'Stop'
$BackupRoot = Join-Path $env:TEMP 'cs2-config-apply-backup'
$Backup     = Join-Path $BackupRoot (Get-Date -Format 'yyyyMMdd-HHmmss')

function Info($m) { Write-Host "     $m" }
function Ok  ($m) { Write-Host "OK   $m" -ForegroundColor Green }
function Warn($m) { Write-Host "WARN $m" -ForegroundColor Yellow }
function Die ($m) { Write-Host "FAIL $m" -ForegroundColor Red; exit 1 }

# Windows does not care how a path is spelled, but whoever reads the output does. Steam
# writes SteamPath into the registry all lower case and with forward slashes, like
# c:/program files (x86)/steam. The slashes are a substitution; how the folders are really
# spelled only the filesystem knows, so every segment is looked up in its parent.
function Get-TruePath($path) {
    $dir = New-Object IO.DirectoryInfo $path
    if (-not $dir.Exists) { return $path }
    $parts = New-Object System.Collections.Generic.List[string]
    while ($dir.Parent) {
        $hit = $dir.Parent.GetDirectories($dir.Name)
        if ($hit.Count -lt 1) { return $path }
        $parts.Insert(0, $hit[0].Name)
        $dir = $dir.Parent
    }
    # Only a drive letter is worth upper-casing. A UNC root is spelled by its server.
    $root = $dir.Name.TrimEnd('\')
    if ($root -match '^[a-z]:$') { $root = $root.ToUpper() }
    if ($parts.Count -eq 0) { return "$root\" }
    return $root + '\' + ($parts -join '\')
}

function Get-SteamPath {
    foreach ($k in @('HKCU:\Software\Valve\Steam',
                     'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
                     'HKLM:\SOFTWARE\Valve\Steam')) {
        if (Test-Path $k) {
            $p = Get-ItemProperty $k
            $raw = $p.SteamPath
            if (-not $raw) { $raw = $p.InstallPath }
            if ($raw) { return Get-TruePath (($raw -replace '/', '\').TrimEnd('\')) }
        }
    }
    return $null
}

function Get-CS2CfgPath($steam) {
    $roots = New-Object System.Collections.Generic.List[string]
    $roots.Add($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        foreach ($line in Get-Content $vdf) {
            if ($line -match '"path"\s+"(.+?)"') { $roots.Add(($matches[1] -replace '\\\\', '\')) }
        }
    }
    foreach ($r in $roots) {
        $p = Join-Path $r 'steamapps\common\Counter-Strike Global Offensive\game\csgo\cfg'
        if (Test-Path $p) { return Get-TruePath $p }
    }
    return $null
}

function Get-UserCfgPath($steam) {
    if (Test-Path 'HKCU:\Software\Valve\Steam\ActiveProcess') {
        $id = (Get-ItemProperty 'HKCU:\Software\Valve\Steam\ActiveProcess').ActiveUser
        if ($id -and $id -ne 0) {
            $p = Join-Path $steam "userdata\$id\730\local\cfg"
            if (Test-Path $p) { return $p }
        }
    }
    $ud = Join-Path $steam 'userdata'
    if (-not (Test-Path $ud)) { return $null }
    $best = Get-ChildItem $ud -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName '730\local\cfg') } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($best) { return (Join-Path $best.FullName '730\local\cfg') }
    return $null
}

$UTF8 = New-Object System.Text.UTF8Encoding($false)

function Normalize($text) { return ($text -replace "`r`n", "`n").TrimEnd("`n", " ", "`t") }

function Compare-Payload($map, $destDir, $label) {
    if (-not $destDir) { return }
    foreach ($name in $map.Keys) {
        $dest = Join-Path $destDir $name
        if (-not (Test-Path $dest)) { Write-Host "     MISSING    $label/$name" -ForegroundColor Yellow }
        elseif ((Normalize ([IO.File]::ReadAllText($dest))) -eq (Normalize $map[$name])) {
            Info "same       $label/$name"
        }
        else { Write-Host "     DIFFERENT  $label/$name" -ForegroundColor Yellow }
    }
}

function Write-Payload($map, $destDir, $tag) {
    $bdir  = Join-Path $Backup $tag
    $added = New-Object System.Collections.Generic.List[string]
    foreach ($name in $map.Keys) {
        $dest = Join-Path $destDir $name
        if (Test-Path $dest) {
            New-Item -ItemType Directory -Force $bdir | Out-Null
            Copy-Item $dest $bdir -Force
        } else {
            # Nothing to back up: remember it so -Undo can delete it again.
            $added.Add($name)
        }
        [IO.File]::WriteAllText($dest, ($map[$name] -replace "`r?`n", "`r`n") + "`r`n", $UTF8)
        Info $name
    }
    if ($added.Count -gt 0) {
        New-Item -ItemType Directory -Force $bdir | Out-Null
        [IO.File]::WriteAllLines((Join-Path $bdir '_added.txt'), $added)
    }
}

'@

$restoreBody = @'

Write-Host ''
Write-Host "=== CS2 settings: $PackName ================================" -ForegroundColor Cyan

$steam = Get-SteamPath
if (-not $steam) { Die 'Steam not found in the registry. Is Steam installed?' }
$cfgDir = Get-CS2CfgPath $steam
if (-not $cfgDir) { Die 'CS2 not found in any Steam library. Install CS2 first.' }
$userCfg = Get-UserCfgPath $steam
Ok "CS2 cfg folder   $cfgDir"

# --- undo -------------------------------------------------------------------------
if ($Undo) {
    if (-not (Test-Path $BackupRoot)) { Die 'No backup found on this PC. Nothing to undo.' }
    $last = Get-ChildItem $BackupRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $last) { Die 'No backup found on this PC. Nothing to undo.' }
    Write-Host ''
    Write-Host "Restoring the files this PC had before: $($last.Name)"
    $map = @{ 'cfg' = $cfgDir; 'video' = $userCfg; 'cloud' = $userCfg }
    foreach ($tag in $map.Keys) {
        $dir = Join-Path $last.FullName $tag
        if (-not (Test-Path $dir) -or -not $map[$tag]) { continue }
        foreach ($f in Get-ChildItem $dir -File) {
            if ($f.Name -eq '_added.txt') { continue }
            Copy-Item $f.FullName (Join-Path $map[$tag] $f.Name) -Force
            Info "restored  $tag/$($f.Name)"
        }
        $addedList = Join-Path $dir '_added.txt'
        if (Test-Path $addedList) {
            foreach ($n in (Get-Content $addedList)) {
                if ($n.Trim() -eq '') { continue }
                $victim = Join-Path $map[$tag] $n
                if (Test-Path $victim) { Remove-Item $victim -Force; Info "removed   $tag/$n" }
            }
        }
    }
    Ok 'Undo complete. This PC is back to how you found it.'
    exit 0
}

# --- check ------------------------------------------------------------------------
if ($Check) {
    Write-Host ''
    Write-Host 'Comparing this pack against the PC (nothing will be written):'
    Compare-Payload $GameCfg  $cfgDir  'cfg'
    if ($userCfg) {
        Compare-Payload $VideoCfg $userCfg 'video'
        Compare-Payload $CloudCfg $userCfg 'cloud'
    }
    Write-Host ''
    Info 'Run without -Check to apply.'
    exit 0
}

# --- apply ------------------------------------------------------------------------
Write-Host ''
Write-Host 'Writing configs:'
Write-Payload $GameCfg $cfgDir 'cfg'
Ok 'Configs in place. Crosshair included, no share code needed.'

if ($Video) {
    if (-not $userCfg) { Warn 'No CS2 userdata folder. Log into Steam, run CS2 once, retry.' }
    elseif ($VideoCfg.Count -eq 0) { Warn 'This pack has no video settings.' }
    else {
        Write-Host ''
        Write-Host 'Writing video settings:'
        Write-Payload $VideoCfg $userCfg 'video'
        Warn 'Check the resolution in game: CS2 may re-detect the GPU and override some of it.'
    }
} else {
    Info ''
    Info 'Video settings not touched. Pass -Video to apply them.'
}

if ($Convars) {
    if (-not $userCfg) { Warn 'No CS2 userdata folder. Cannot restore the cloud backup.' }
    else {
        Write-Host ''
        Write-Host 'Restoring Steam Cloud settings:'
        Warn 'Close CS2 AND Steam first, or Steam overwrites these when it exits.'
        Write-Payload $CloudCfg $userCfg 'cloud'
    }
}

if (Test-Path $Backup) {
    Write-Host ''
    Info "This PC's original files: $Backup"
    Info 'Run with -Undo to put them back.'
}

Write-Host ''
Write-Host '=== BY HAND ================================================' -ForegroundColor Cyan
if ($LaunchOptions -ne '') {
    Write-Host ''
    Write-Host 'Launch options (Steam > CS2 > Properties > General):' -ForegroundColor White
    Write-Host ''
    Write-Host "   $LaunchOptions" -ForegroundColor Yellow
    try { Set-Clipboard -Value $LaunchOptions; Write-Host ''; Info 'Copied to your clipboard. Just paste.' } catch { }
}
Write-Host ''
Write-Host 'If you play a stretched 4:3 resolution, set GPU scaling too:' -ForegroundColor White
Write-Host 'NVIDIA Control Panel > Adjust desktop size and position > Full-screen,' -ForegroundColor White
Write-Host 'scaling on GPU, tick Override the scaling mode set by games.' -ForegroundColor White
Write-Host ''
Write-Host 'Then start CS2 and check your crosshair, sensitivity and binds.' -ForegroundColor White
Write-Host ''
Write-Host "Made with cs2-config: $ToolUrl" -ForegroundColor DarkGray
Write-Host ''
'@

$applyPs = $restoreHead + $payload + "`r`n" + $restoreConsts + $restoreBody

$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseInput($applyPs, [ref]$null, [ref]$errors)
if ($errors -and $errors.Count -gt 0) {
    Write-Host 'FAIL the generated apply-config has syntax errors:' -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "     $($_.Message) (line $($_.Extent.StartLineNumber))" -ForegroundColor Red }
    exit 1
}

# One file, not two. The PowerShell rides below a marker inside the .cmd, where cmd
# never reads, and the launcher unpacks it to TEMP before running it: the same trick
# this file uses on itself. A loose .ps1 is only a thing to lose, to leave behind on
# someone else's PC, or to open in Notepad by accident.
#
# Its marker is ::CFG::, deliberately different from the one this file carries for
# itself, so neither extractor can ever find the other's payload. For that same reason
# this file's own marker is never spelled out again anywhere below it: extraction takes
# the LAST match, so a second mention would silently become the marker.
$applyCmdHead = @'
@echo off
rem  Double-click this to apply the settings in this folder.
rem
rem  Generated by cs2-config. Everything is in this one file: the PowerShell below
rem  the marker is plain text, and cmd stops reading at the exit above it.

setlocal
title CS2 config

set "PS1=%TEMP%\apply-config.ps1"
if exist "%PS1%" del "%PS1%"

rem  Via an environment variable, so an apostrophe in the path cannot break the string.
set "SELF=%~f0"
powershell -NoProfile -Command "$m='::'+'CFG::'; $t=[IO.File]::ReadAllText($env:SELF,[Text.Encoding]::UTF8); $i=$t.LastIndexOf($m); if($i -lt 0){exit 1}; [IO.File]::WriteAllText($env:TEMP+'\apply-config.ps1', $t.Substring($i+$m.Length), (New-Object Text.UTF8Encoding($true)))"
if not exist "%PS1%" goto broken

rem  A switch skips the menu, so the one-line install can pass -Video straight through.
if not "%~1"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
    goto done
)

echo.
echo   CS2 CONFIG
echo.
echo     [1]  Apply everything     configs, crosshair, resolution and quality
echo     [2]  Apply configs only   leaves this PC's video settings alone
echo     [3]  Check                show what differs, change nothing
echo     [4]  Undo                 put this PC back the way you found it
echo.

set "ARGS=-Video"
set /p "PICK=  Choose 1-4, or just press Enter for 1: "
if "%PICK%"=="2" set "ARGS="
if "%PICK%"=="3" set "ARGS=-Check"
if "%PICK%"=="4" set "ARGS=-Undo"

echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %ARGS%

:done
rem  Leave nothing behind on a machine you borrowed.
if exist "%PS1%" del "%PS1%"
echo.
pause
exit /b 0

:broken
echo.
echo Could not unpack the script from this file.
echo Re-download it: some editors and chat apps corrupt .cmd files.
echo.
echo If PowerShell is blocked here, copy cfg\*.cfg into the game folder by hand,
echo or paste apply-config-using-console.txt into the CS2 console instead.
echo.
pause
exit /b 1

::CFG::
'@

$applyCmdText = ($applyCmdHead -replace "`r?`n", "`r`n") + $applyPs
$applyMarker  = '::' + 'CFG::'
$markerHits   = ([regex]::Matches($applyCmdText, [regex]::Escape($applyMarker))).Count
if ($markerHits -ne 1) {
    Die "One of your configs contains the text $applyMarker, which the launcher uses as its own marker. Remove it and run this again." `
        "В одном из твоих конфигов есть текст $applyMarker — этой меткой лаунчер отделяет свой скрипт. Убери её и запусти снова."
}

$applyPath = Join-Path $OutDir 'apply-config.cmd'
[IO.File]::WriteAllText($applyPath, $applyCmdText, $UTF8)
$applyKb = [math]::Round((Get-Item $applyPath).Length / 1KB, 1)
Ok "apply-config.cmd  $applyKb KB, parses clean" `
   "apply-config.cmd  $applyKb КБ, синтаксис в порядке"

# update-config.cmd is this launcher, copied in. Started from inside a pack it rebuilds
# that pack, so updating never means hunting down the original download again.
#
# Skipped when it would land on the file currently running: cmd re-reads a batch file
# after each command returns, so overwriting it mid-run wrecks the rest of the run.
$updatePath = Join-Path $OutDir 'update-config.cmd'
if ($env:SELF -and (Test-Path $env:SELF)) {
    $sameFile = $false
    try { $sameFile = ([IO.Path]::GetFullPath($env:SELF) -eq [IO.Path]::GetFullPath($updatePath)) } catch { }
    if ($sameFile) {
        Ok 'update-config.cmd  already in place' 'update-config.cmd  уже на месте'
    } else {
        Copy-Item $env:SELF $updatePath -Force
        Ok 'update-config.cmd'
    }
} else {
    Warn 'Could not copy myself in as update-config.cmd.' `
         'Не смог положить себя в набор как update-config.cmd.'
    Info 'Updating means running this setup again by hand.' `
         'Обновлять придётся, запуская этот скрипт вручную.'
}

# ==================================================================================
#  Generate apply-config-using-console.txt
# ==================================================================================

# One cfg line is one command. Never split a line: semicolons also appear inside quoted
# bind bodies, and splitting there would corrupt them.
function Get-ConsoleCommands($cfgPath) {
    $cmds = New-Object System.Collections.Generic.List[string]
    foreach ($line in (Get-Content $cfgPath)) {
        $t = $line.Trim()
        if ($t -eq '' -or $t.StartsWith('//')) { continue }
        $t = $t.TrimEnd(';', ' ')
        if ($t -ne '') { $cmds.Add($t) }
    }
    return $cmds
}

# A config another one binds a key to, like bind f1 "exec training", is meant to run when
# that key is pressed, not now. training.cfg on its own would flip sv_cheats and kick the
# bots on whatever server you happen to be on, so those files stay out of the paste.
function Get-OnDemandCfgs($cfgs) {
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($f in $cfgs) {
        foreach ($line in (Get-Content $f.FullName)) {
            foreach ($m in [regex]::Matches($line, '(?i)bind\s+"?[^"\s]+"?\s+"[^"]*\bexec\s+([\w.-]+)')) {
                $n = $m.Groups[1].Value.ToLower()
                if (-not $n.EndsWith('.cfg')) { $n = "$n.cfg" }
                if (-not $names.Contains($n)) { $names.Add($n) }
            }
        }
    }
    return $names
}

# The file is opened, selected whole, copied and pasted into the console once. So it holds
# one line of commands and nothing else: a heading or a note would be pasted along with
# them. What the file cannot say, the pack README says instead.
#
# autoexec.cfg stays out as well. It only chains to the other configs with exec and calls
# host_writeconfig, and neither means anything on a PC that does not have those files.
$onDemand    = Get-OnDemandCfgs $packedCfgs
$consoleCmds = New-Object System.Collections.Generic.List[string]
$consoleLeft = New-Object System.Collections.Generic.List[string]

# Main config first. If the console does turn out to have a length limit, what falls off
# the end is then the least important thing in the file.
$ordered = @($packedCfgs | Where-Object { $Main -and $_.Name -eq $Main }) +
           @($packedCfgs | Where-Object { -not ($Main -and $_.Name -eq $Main) })
foreach ($f in $ordered) {
    $lower = $f.Name.ToLower()
    if ($lower -eq 'autoexec.cfg') { continue }
    if ($onDemand.Contains($lower)) { $consoleLeft.Add($f.Name); continue }
    foreach ($c in (Get-ConsoleCommands $f.FullName)) { $consoleCmds.Add($c) }
}

$consoleLine = ($consoleCmds -join '; ')
# No BOM. The file exists to be copied, and an editor that carries the BOM into the
# clipboard would glue it onto the first command.
[IO.File]::WriteAllText((Join-Path $OutDir 'apply-config-using-console.txt'), $consoleLine, $UTF8)
Ok "apply-config-using-console.txt  $($consoleCmds.Count) commands, $($consoleLine.Length) chars" `
   "apply-config-using-console.txt  команд: $($consoleCmds.Count), символов: $($consoleLine.Length)"
if ($consoleLeft.Count -gt 0) {
    Info "not in it: $($consoleLeft -join ', ') — run from a key, not on arrival" `
         "не вошли: $($consoleLeft -join ', ') — они запускаются с клавиши, а не при старте"
}

# ==================================================================================
#  Generate the pack instructions, English and Russian
#  Markdown, because the pack is meant to end up on GitHub, where README.md becomes the
#  landing page. That decides the formatting: single newlines collapse when rendered, so
#  anything that has to keep its line breaks - listings, commands - goes in a fence.
# ==================================================================================

# Only meaningful once the folder is on GitHub. Normally nobody knows the repo yet, so the
# command is written as a template with the name and repo left to fill in; PUBLISH IT at
# the bottom says so. -RepoUrl fills it in instead.
$rawBase = 'https://raw.githubusercontent.com/<you>/<repo>/main'
if ($RepoUrl) {
    $rawBase = ($RepoUrl -replace '^https?://github\.com/', 'https://raw.githubusercontent.com/').TrimEnd('/')
    $rawBase = "$rawBase/main"
}
$cmd = "iwr -useb $rawBase/apply-config.cmd -OutFile `"`$env:TEMP\cs2.cmd`"; & `"`$env:TEMP\cs2.cmd`" -Video"
$oneLinerEn = $cmd
$oneLinerRu = $cmd

function Format-Dropped($items, $header) {
    if (-not $items -or $items.Count -eq 0) { return '' }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine($header)
    [void]$sb.AppendLine('')
    foreach ($d in $items) {
        [void]$sb.AppendLine('- `' + $d.Text + '` — ' + $d.Why)
    }
    return $sb.ToString().TrimEnd()
}

$droppedEn = ''
$droppedRu = ''
if ($launch -and $launch.Dropped.Count -gt 0) {
    $droppedEn = Format-Dropped $launch.Dropped 'Dropped, because they do not travel well:'
    $ru = $launch.Dropped | ForEach-Object { [pscustomobject]@{ Text = $_.Text; Why = $_.WhyRu } }
    $droppedRu = Format-Dropped $ru 'Убрано, потому что плохо переносится:'
}

# PadRight alone is not enough: cs2_user_convars_0_slot0.vcfg is longer than the column,
# and its description would end up glued to the file name.
function Col($name, $desc) {
    if ($desc -eq '') { return $name }
    $gap = 33 - $name.Length
    if ($gap -lt 2) { $gap = 2 }
    return $name + (' ' * $gap) + $desc
}

$fileLinesEn = New-Object System.Collections.Generic.List[string]
$fileLinesRu = New-Object System.Collections.Generic.List[string]
foreach ($f in $packedCfgs) {
    $en = ''
    $ru = ''
    if ($f.Name -eq 'autoexec.cfg')   { $en = 'runs automatically on startup';        $ru = 'запускается сам при старте игры' }
    if ($f.Name -eq 'crosshair.cfg')  { $en = 'your crosshair, no share code needed'; $ru = 'твой прицел, код обмена не нужен' }
    if ($Main -and $f.Name -eq $Main) { $en = 'your main config';                     $ru = 'твой главный конфиг' }
    $fileLinesEn.Add((Col "cfg\$($f.Name)" $en))
    $fileLinesRu.Add((Col "cfg\$($f.Name)" $ru))
}
if ($hasVideo) {
    $fileLinesEn.Add((Col 'video\cs2_video.txt' 'resolution and quality'))
    $fileLinesRu.Add((Col 'video\cs2_video.txt' 'разрешение и качество картинки'))
}
foreach ($c in $cloudFiles) {
    $fileLinesEn.Add((Col "cloud-backup\$c" 'what Steam Cloud normally brings'))
    $fileLinesRu.Add((Col "cloud-backup\$c" 'то, что обычно приносит Steam Cloud'))
}
$filesBlockEn = ($fileLinesEn -join "`r`n")
$filesBlockRu = ($fileLinesRu -join "`r`n")

# The contents of the folder, never the folder itself: the one-line install above reads
# apply-config.cmd from the repository root, and a dragged folder would nest it a level
# down and 404.
$publishEn = @'
Git is not needed. This is all done in a browser.

**Putting the config in the cloud**

1. Sign in at github.com
2. Create a public repository (`cs2-config`, for example)
3. On the page that opens, click **uploading an existing file**
4. Drag the contents of this folder onto the page
5. Click **Commit changes**

**Updating the config in the cloud**

1. Open the repository holding your config
2. Click `Add file` and pick `Upload files`
3. Drag the contents of this folder onto the page
4. Click **Commit changes**

'@

$publishRu = @'
Git не нужен, всё делается в браузере.

**Создание конфига в облаке**

1. Авторизуйся на github.com
2. Создай публичный репозиторий (например `cs2-config`)
3. На открывшейся странице нажми **uploading an existing file**
4. Перетащи на страницу содержимое этой папки
5. Нажми **Commit changes**

**Обновление конфига в облаке**

1. Перейди в репозиторий своего конфига
2. Нажми `Add file` и выбери `Upload files`
3. Перетащи на страницу содержимое этой папки
4. Нажми **Commit changes**

'@

# With -RepoUrl the one-liner is already correct, so telling them to fix it would be wrong.
if ($RepoUrl) {
    $publishEn += "`r`nThe one-line install at the top of this file already points at your repo."
    $publishRu += "`r`nКоманда установки в начале этого файла уже указывает на твой репозиторий."
} else {
    $publishEn += @'

Then fix up the one-line install at the top of this file: replace <you> and <repo> with
your GitHub name and the repo you just created.
'@
    $publishRu += @'

Потом поправь команду установки в начале этого файла: подставь вместо <you> и <repo>
свой ник на GitHub и созданный репозиторий.
'@
}

$tmplEn = @'
# CS2 config

{{NAME}} — CS2 config packed by [cs2-config]({{TOOLURL}}).

## Installing the config on another PC

Use the first option that works there.

### 1. Double-click `apply-config.cmd`

Needs PowerShell. The easy one: you already have this folder, off a USB stick or a
download. It asks what to do — apply everything, apply configs only, check what differs,
or undo.

### 2. One command

Needs PowerShell and internet. For a PC that has nothing on it yet:

```powershell
{{ONELINER}}
```

### 3. PowerShell blocked

Needs only Explorer. Copy the files from `cfg\` into:

```
...\steamapps\common\Counter-Strike Global Offensive\game\csgo\cfg\
```

That is all the installer does.

### 4. No file access at all

Needs only the game. `apply-config-using-console.txt` is one line of console commands and
nothing else: open it, select all, copy, paste into the CS2 console, Enter. Once.

Turn the console on first: Settings > Game > Enable Developer Console = Yes. It opens with
the ~ key.

Not an equal substitute: configs and crosshair only. No video settings, no
`cloud-backup`, nothing written to disk, no undo. Configs you run from a key are left out
of the line as well — pasting one would change the server you are on rather than your
settings. Crosshair, sensitivity and binds do survive a restart, because CS2 saves those
convars on exit. Server settings like `sv_cheats` do not.

## apply-config switches

`apply-config.cmd` offers these as a menu. Pass one on the command line and the menu is
skipped.

| switch | what it does |
|---|---|
| `-Video` | also apply resolution and quality |
| `-Convars` | restore sensitivity and binds from `cloud-backup\`. Only if Steam Cloud failed. Close CS2 and Steam first |
| `-Check` | show what differs, write nothing |
| `-Undo` | put the PC back the way you found it |

## Launch options

Steam > CS2 > Properties > General.

Portable version, safe on unknown hardware:

```
{{LAUNCHPORTABLE}}
```

Your full version, for home:

```
{{LAUNCHFULL}}
```

{{DROPPED}}

## What is in here

```
apply-config.cmd                 applies the settings; your configs are embedded in it
apply-config-using-console.txt   one line to paste into the console, see option 4
update-config.cmd                re-reads your settings and rebuilds this folder
{{FILES}}
```

The crosshair is applied as convars. There is no share code to paste.

`cloud-backup\` is a copy of what Steam Cloud normally delivers. You usually never need
it: logging into Steam brings your sensitivity, crosshair and binds down by itself.

## The config in the cloud

{{PUBLISH}}

## Updating the config

Changed your settings in the game? Run `update-config.cmd`. Before you travel, not after.

---

Built with cs2-config {{TOOLVER}} — {{TOOLURL}}
'@

$tmplRu = @'
# Конфиг CS2

{{NAME}} — конфиг CS2, собранный утилитой [cs2-config]({{TOOLURL}}).

## Установка конфига на другом компьютере

Возьми первый способ, который сработает на этом ПК.

### 1. Двойной клик по `apply-config.cmd`

Нужен PowerShell. Самый простой путь: папка уже у тебя, с флешки или из скачанного
архива. Файл спросит, что делать — применить всё, только конфиги, показать различия
или откатить.

### 2. Одна команда

Нужны PowerShell и интернет. Когда на компьютере ещё ничего нет:

```powershell
{{ONELINER}}
```

### 3. PowerShell заблокирован

Нужен только проводник. Скопируй файлы из `cfg\` в папку:

```
...\steamapps\common\Counter-Strike Global Offensive\game\csgo\cfg\
```

Установщик не делает ничего сверх этого.

### 4. К файлам доступа нет вообще

Нужна только игра. `apply-config-using-console.txt` — это одна строка консольных команд и
больше ничего: открой, выдели всё, скопируй, вставь в консоль CS2, Enter. Один раз.

Сначала включи консоль: «Настройки» > «Игра» > «Включить консоль разработчика» = «Да».
Открывается клавишей ~.

Это не равноценная замена: только конфиги и прицел. Без настроек видео, без
`cloud-backup`, на диск ничего не пишется, откатить нечем. Конфиги, которые запускаются
с клавиши, в строку тоже не вошли: вставить такой — поменять сервер, на котором играешь,
а не свои настройки. Прицел, чувствительность и бинды перезапуск переживут: эти
переменные CS2 сохраняет при выходе. Серверные вроде `sv_cheats` — нет.

## Ключи apply-config

`apply-config.cmd` предлагает их меню. Если передать ключ в командной строке, меню
пропускается.

| ключ | что делает |
|---|---|
| `-Video` | ещё и разрешение с качеством картинки |
| `-Convars` | вернуть чувствительность и бинды из `cloud-backup\`. Только если Steam Cloud не сработал. Сначала закрой CS2 и Steam |
| `-Check` | показать различия, ничего не записывая |
| `-Undo` | вернуть ПК в то состояние, в котором ты его застал |

## Параметры запуска

Steam > CS2 > «Свойства» > «Общие».

Переносимый вариант, безопасный на незнакомом железе:

```
{{LAUNCHPORTABLE}}
```

Твой полный вариант, домашний:

```
{{LAUNCHFULL}}
```

{{DROPPED}}

## Что лежит внутри

```
apply-config.cmd                 применяет настройки; конфиги лежат внутри него же
apply-config-using-console.txt   одна строка для консоли, способ 4
update-config.cmd                перечитывает настройки и пересобирает эту папку
{{FILES}}
```

Прицел применяется через консольные переменные. Код обмена вставлять не нужно.

`cloud-backup\` — копия того, что обычно приносит Steam Cloud. Обычно она не нужна:
вход в Steam сам подтянет чувствительность, прицел и бинды.

## Конфиг в облаке

{{PUBLISH}}

## Обновление конфига

Поменял настройки в игре? Запусти `update-config.cmd`. Лучше до поездки, а не после.

---

Собрано утилитой cs2-config {{TOOLVER}} — {{TOOLURL}}
'@

function Expand-Template($t, $oneLiner, $dropped, $publish, $files) {
    $launchFull = $launchRaw
    if (-not $launchFull) { $launchFull = '(none set)' }
    $lp = $launchPortable
    if ($lp -eq '') { $lp = '(none set)' }
    return $t.Replace('{{NAME}}', $Name).
              Replace('{{TOOLURL}}', $TOOL_URL).
              Replace('{{TOOLVER}}', $TOOL_VERSION).
              Replace('{{ONELINER}}', $oneLiner).
              Replace('{{LAUNCHPORTABLE}}', $lp).
              Replace('{{LAUNCHFULL}}', $launchFull).
              Replace('{{DROPPED}}', $dropped).
              Replace('{{FILES}}', $files).
              Replace('{{PUBLISH}}', $publish)
}

# CRLF and a BOM so Notepad on a stock Windows box renders them correctly.
# Names this tool used to write. A pack built by an older version keeps them forever
# otherwise, and two apply scripts side by side is worse than none.
foreach ($old in @('cs2-config-apply.cmd', 'cs2-config-apply.ps1', 'apply-config.ps1',
                   'console-paste.txt', 'README.txt', 'README.ru.txt')) {
    $stale = Join-Path $OutDir $old
    if (Test-Path $stale) { Remove-Item $stale -Force }
}
$enTxt = (Expand-Template $tmplEn $oneLinerEn $droppedEn $publishEn $filesBlockEn) -replace "`r?`n", "`r`n"
$ruTxt = (Expand-Template $tmplRu $oneLinerRu $droppedRu $publishRu $filesBlockRu) -replace "`r?`n", "`r`n"
# No BOM: markdown is read by GitHub far more often than by Notepad, and modern Notepad
# detects UTF-8 on its own anyway.
[IO.File]::WriteAllText((Join-Path $OutDir 'README.md'),    $enTxt, $UTF8)
[IO.File]::WriteAllText((Join-Path $OutDir 'README.ru.md'), $ruTxt, $UTF8)
Ok 'README.md, README.ru.md' 'README.md, README.ru.md — инструкции'
# ==================================================================================
#  Summary
# ==================================================================================

Head '=== done ===================================================' `
     '=== готово ================================================='
Write-Host ''
Info "Pack written to: $OutDir" "Набор собран здесь: $OutDir"
Write-Host ''
# Just the string worth pasting. The per-flag reasoning lives in the pack README,
# which is where someone actually goes looking for it.
if ($launchPortable -ne '') {
    Write-Host (L 'Launch options you can try:' 'Параметры запуска, которые можно поставить:') -ForegroundColor White
    Write-Host $launchPortable -ForegroundColor Yellow
    Write-Host ''
}
Write-Host (L 'Next:' 'Дальше:') -ForegroundColor White
Info '1. Copy the whole folder to a USB stick. It is tiny, and apply-config-using-console.txt' `
     '1. Скопируй всю папку на флешку. Она крошечная, а apply-config-using-console.txt —'
Info '   is the fallback you want when a venue PC blocks PowerShell.' `
     '   тот самый запасной вариант, когда на площадке закрыт PowerShell.'
Info '2. On the other PC, double-click apply-config.cmd and pick an option.' `
     '2. На другом ПК кликни по apply-config.cmd и выбери пункт.'
Info '3. Or put the contents of the folder on GitHub for a one-line install (see its README).' `
     '3. Или выложи содержимое папки на GitHub, чтобы ставить одной командой (см. её README).'
Info '4. Settings changed later? Run update-config.cmd from inside that folder.' `
     '4. Поменяешь настройки — запусти update-config.cmd из этой же папки.'
Write-Host ''

# Hand the path to the launcher, which opens the folder once Enter is pressed. Doing it
# from here instead would bury Explorer under the console window still waiting on pause.
try {
    [IO.File]::WriteAllText((Join-Path $env:TEMP 'cs2-config-outdir.txt'), $OutDir, $UTF8)
} catch { }
