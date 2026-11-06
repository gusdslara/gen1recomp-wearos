# Packs the Lua game into wear/src/main/assets/game.love, preserving the
# directory layout (src/, data/, assets/, tools/, mods/, devrom/...)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$wearDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $wearDir '..\..\..')).Path
$outDir   = Join-Path $wearDir 'src\main\assets'
$outFile  = Join-Path $outDir 'game.love'
New-Item -ItemType Directory -Force $outDir | Out-Null
if (Test-Path $outFile) { Remove-Item $outFile -Force }

function Rel([string]$full) { $full.Substring($repoRoot.Length + 1).Replace('\', '/') }

$files = New-Object System.Collections.Generic.List[object]
foreach ($f in 'main.lua', 'conf.lua') { $files.Add((Get-Item (Join-Path $repoRoot $f))) }
foreach ($d in 'src', 'data', 'assets', 'tools\save-editor') {
  $p = Join-Path $repoRoot $d
  if (Test-Path $p) { Get-ChildItem $p -Recurse -File | ForEach-Object { $files.Add($_) } }
}
Get-ChildItem (Join-Path $repoRoot 'tools') -Filter 'rom_manifest*.json' -File | ForEach-Object { $files.Add($_) }

$zip = [System.IO.Compression.ZipFile]::Open($outFile, 'Create')
try {
  foreach ($f in $files) {
    $rel = Rel $f.FullName
    if ($rel -like 'data/generated/*' -or $rel -like 'assets/generated/*' -or
        $rel -like '*.DS_Store' -or $rel -like '*.psd' -or $rel -like '*/.git/*') { continue }
    [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.FullName, $rel, 'Optimal')
  }
  # marker read by src/core/Watch.lua
  [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
    $zip, (Join-Path $wearDir 'love-extra\wearos.flag'), 'wearos.flag', 'Optimal')

  # Bundled mods (e.g. voxel_world_gen3) -> mods/
  $bundledModsDir = Join-Path $wearDir 'bundled-mods'
  if (Test-Path $bundledModsDir) {
    Get-ChildItem $bundledModsDir -Recurse -File | ForEach-Object {
      $relMod = $_.FullName.Substring($bundledModsDir.Length + 1).Replace('\', '/')
      if ($relMod -notlike '*.DS_Store' -and $relMod -notlike '*/.git/*' -and $_.Name -ne 'README.md') {
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
          $zip, $_.FullName, "mods/$relMod", 'Optimal')
      }
    }
  }

  # Pack devrom if present -> devrom/
  $devRomDir = Join-Path $wearDir 'dev-rom'
  if (Test-Path $devRomDir) {
    Get-ChildItem $devRomDir -Filter '*.gba' -File | ForEach-Object {
      [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $zip, $_.FullName, "devrom/$($_.Name)", 'Optimal')
    }
  }

  # Translation recipes -> watchlang/
  $transDir = Join-Path $wearDir 'translation-tool'
  if (Test-Path $transDir) {
    Get-ChildItem $transDir -Filter 'recipe*.json' -File | ForEach-Object {
      [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $zip, $_.FullName, "watchlang/$($_.Name)", 'Optimal')
    }
  }

  # Translation ROMs -> idioma/
  $romSourcesDir = Join-Path $wearDir 'rom-sources'
  if (Test-Path $romSourcesDir) {
    Get-ChildItem $romSourcesDir -Filter '*.gba' -File | ForEach-Object {
      [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $zip, $_.FullName, "idioma/$($_.Name)", 'Optimal')
    }
  }
} finally { $zip.Dispose() }

"Packed $outFile ($((Get-Item $outFile).Length) bytes)"
