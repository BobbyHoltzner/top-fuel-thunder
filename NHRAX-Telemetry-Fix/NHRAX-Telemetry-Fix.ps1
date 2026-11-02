<#
.SYNOPSIS
  NHRA Drag Racing: Top Fuel Thunder (NHRAX, Build 365) - end-of-run crash fix
  for Windows Vista / 7 / 8 / 10 / 11.

.DESCRIPTION
  The game's Racepak telemetry code opens its data file with fopen() mode
  strings "wbf" and "rbf". The 'f' is not a valid mode character. Windows XP's
  msvcrt.dll ignored it; the msvcrt.dll in Vista and later rejects it (EINVAL),
  so the file never opens, the game throws TM_ERROR__FILE_NOT_OPENED, and it
  exits at the end of every run.

  This script changes 3 bytes ('f' -> NUL) so the modes become "wb" / "rb":
    NHRAX.exe              0x819C92, 0x819DBA
    RacePak\TMConvert.exe  0x92F6
  Nothing else in the files changes. Originals are backed up as
  *.pre-fopen-fix next to each file. Run again with -Restore to undo.

.PARAMETER GameDir
  Game folder (the one containing NHRAX.exe). If omitted, the script looks in
  its own folder, then the uninstall registry entry, then the default path.

.PARAMETER Restore
  Put the backed-up original files back.
#>
param(
    [string]$GameDir,
    [switch]$Restore,
    [switch]$Elevated
)

$ErrorActionPreference = 'Stop'

# Each target: file, patch offsets (the 'f' bytes), the exact bytes expected at
# offset-2 .. offset+1 ("wbf\0" / "rbf\0"), and SHA-256 of the known retail
# original and patched files.
$Targets = @(
    @{
        File     = 'NHRAX.exe'
        Sites    = @(
            @{ Offset = 0x819C92; Expect = [byte[]](0x77, 0x62, 0x66, 0x00) }  # "wbf\0"
            @{ Offset = 0x819DBA; Expect = [byte[]](0x72, 0x62, 0x66, 0x00) }  # "rbf\0"
        )
        Original = '892793F0EBC1118EC232BBC8040247E9F01C8DA3E1C0D8AA863ED09FFDF3EAE8'
        Patched  = '943D5F473D852EB833B42121445EB1011B3C0D5D579AA5D792FBF5DE931ACD5D'
    }
    @{
        File     = 'RacePak\TMConvert.exe'
        Sites    = @(
            @{ Offset = 0x92F6; Expect = [byte[]](0x72, 0x62, 0x66, 0x00) }    # "rbf\0"
        )
        Original = '6BB4FD0B100467B4A0EAE5B23B7938B164E3639C5D8435543253637483E3120C'
        Patched  = '5546EDED0F1846ECAEF55C46332378B41835706B8287417CA82FEC3FE52104AA'
    }
)
$BackupSuffix = '.pre-fopen-fix'

function Find-GameDir {
    if ($GameDir) { return $GameDir }
    if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'NHRAX.exe'))) { return $PSScriptRoot }
    foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\NHRAX',
                   'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\NHRAX') {
        $u = (Get-ItemProperty $k -ErrorAction SilentlyContinue).UninstallString
        if ($u -match '^"?(.+?)\\UNWISE\.EXE') {
            $d = (Get-Item $Matches[1] -ErrorAction SilentlyContinue).FullName   # expands 8.3 names
            if ($d -and (Test-Path (Join-Path $d 'NHRAX.exe'))) { return $d }
        }
    }
    foreach ($d in "${env:ProgramFiles(x86)}\Emotorsports\NHRAX", "$env:ProgramFiles\Emotorsports\NHRAX") {
        if (Test-Path (Join-Path $d 'NHRAX.exe')) { return $d }
    }
    return $null
}

function Test-CanWrite([string]$Path) {
    try { [IO.File]::Open($Path, 'Open', 'ReadWrite', 'None').Close(); return $true } catch { return $false }
}

function Get-Sha256([string]$Path) { (Get-FileHash $Path -Algorithm SHA256).Hash }

function Finish([int]$Code) {
    if ($Elevated) { Write-Host ''; Read-Host 'Press Enter to close' | Out-Null }
    exit $Code
}

Write-Host 'NHRAX telemetry crash fix' -ForegroundColor Cyan
$dir = Find-GameDir
if (-not $dir) {
    Write-Host 'Could not find the game. Run again with -GameDir "<folder containing NHRAX.exe>".' -ForegroundColor Red
    Finish 1
}
Write-Host "Game folder: $dir"
foreach ($t in $Targets) {
    if (-not (Test-Path (Join-Path $dir $t.File))) {
        Write-Host "Missing $($t.File) - is this the NHRAX folder? Nothing was changed." -ForegroundColor Red
        Finish 1
    }
}

# Only a game running from this folder matters; an unreadable path (game running
# elevated) is treated as a match to be safe.
$running = Get-Process NHRAX -ErrorAction SilentlyContinue |
    Where-Object { -not $_.Path -or $_.Path.StartsWith($dir.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) }
if ($running) {
    Write-Host 'The game is running. Close it and run this again.' -ForegroundColor Red
    Finish 1
}

# Program Files needs admin: relaunch elevated once if we cannot write.
$needAdmin = $Targets | Where-Object { -not (Test-CanWrite (Join-Path $dir $_.File)) }
if ($needAdmin) {
    if ($Elevated) { Write-Host 'Still cannot write the game files, even as administrator.' -ForegroundColor Red; Finish 1 }
    Write-Host 'Administrator rights are needed to change files in this folder - asking Windows...'
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-GameDir', "`"$dir`"", '-Elevated')
    if ($Restore) { $argList += '-Restore' }
    try { Start-Process powershell.exe -Verb RunAs -ArgumentList $argList -Wait }
    catch { Write-Host 'Administrator prompt was cancelled. Nothing was changed.' -ForegroundColor Yellow; exit 1 }
    exit 0
}

if ($Restore) {
    foreach ($t in $Targets) {
        $path = Join-Path $dir $t.File
        if (Test-Path ($path + $BackupSuffix)) {
            Copy-Item ($path + $BackupSuffix) $path -Force
            Write-Host "Restored $($t.File)" -ForegroundColor Green
        } else {
            Write-Host "No backup for $($t.File) - left as is"
        }
    }
    Finish 0
}

# Check every file before changing any of them.
$plan = @()
foreach ($t in $Targets) {
    $path = Join-Path $dir $t.File
    if (-not (Test-Path $path)) { Write-Host "Missing $($t.File) - is this the NHRAX folder?" -ForegroundColor Red; Finish 1 }
    $hash = Get-Sha256 $path
    if ($hash -eq $t.Patched) { Write-Host "$($t.File): already patched"; continue }

    $bytes = [IO.File]::ReadAllBytes($path)
    $match = $true
    foreach ($s in $t.Sites) {
        $start = $s.Offset - 2
        for ($i = 0; $i -lt $s.Expect.Length; $i++) {
            if ($start + $i -ge $bytes.Length -or $bytes[$start + $i] -ne $s.Expect[$i]) { $match = $false }
        }
    }
    if (-not $match) {
        Write-Host "$($t.File): unexpected contents (different version or already modified). Nothing was changed." -ForegroundColor Red
        Finish 1
    }
    if ($hash -ne $t.Original) {
        Write-Host "$($t.File): not the known retail Build 365 file, but the bytes to fix are exactly where expected - patching." -ForegroundColor Yellow
    }
    $plan += @{ Target = $t; Path = $path; Bytes = $bytes }
}

if (-not $plan) { Write-Host 'Nothing to do - already patched.' -ForegroundColor Green; Finish 0 }

foreach ($p in $plan) {
    if (-not (Test-Path ($p.Path + $BackupSuffix))) {
        Copy-Item $p.Path ($p.Path + $BackupSuffix)
        Write-Host "Backed up $($p.Target.File) -> $($p.Target.File)$BackupSuffix"
    }
    foreach ($s in $p.Target.Sites) { $p.Bytes[$s.Offset] = 0 }
    [IO.File]::WriteAllBytes($p.Path, $p.Bytes)
    $ok = (Get-Sha256 $p.Path) -eq $p.Target.Patched
    $note = if ($ok) { 'verified' } else { 'done (non-retail file, hash not verifiable)' }
    Write-Host "$($p.Target.File): patched, $note" -ForegroundColor Green
}

Write-Host ''
Write-Host 'Done. Start the game normally (not as administrator).' -ForegroundColor Cyan
Finish 0
