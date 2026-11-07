<#
.SYNOPSIS
  Installs or updates the FS25 "rags to riches" mod pack so every player has exactly the same mods.

.DESCRIPTION
  1. Finds your Farming Simulator 25 mods folder (works with OneDrive-moved Documents and with
     the in-game "mods directory override").
  2. Reads the pack list (manifest.json): every mod's file name, version and SHA-256 fingerprint.
  3. Downloads each missing or changed mod straight from GIANTS' official ModHub servers
     (or from -MirrorBase if given) and checks the fingerprint before installing it.
  4. Moves anything that is NOT in the pack (old versions, other mods) into a dated backup folder,
     so your mods folder matches the pack exactly. Nothing is deleted.
  Re-run it any time: it only downloads what changed. No admin rights needed.

.PARAMETER ManifestUrl
  Web address or local path of manifest.json.
.PARAMETER MirrorBase
  Optional web address or local folder holding the mod zips (used before ModHub).
.PARAMETER ModsPath
  Optional: use this mods folder instead of finding it automatically.
.PARAMETER KeepExtras
  Keep mods that are not in the pack instead of moving them to the backup folder.
.PARAMETER Unattended
  No questions, no "press Enter" at the end. Exit code 0 = success, 1 = failed, 2 = game is running.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\install-fs25-pack.ps1
#>
[CmdletBinding()]
param(
    [string]$ManifestUrl = "https://github.com/akimbohh/fs25-pack/releases/latest/download/manifest.json",
    [string]$MirrorBase = "",
    [string]$ModsPath = "",
    [switch]$KeepExtras,
    [switch]$Unattended
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # makes Invoke-WebRequest much faster on Windows PowerShell 5.1
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

$UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) fs25-pack-installer"
$script:LogFile = $null

function Say([string]$msg, [string]$color = "Gray") {
    Write-Host $msg -ForegroundColor $color
    if ($script:LogFile) { Add-Content -Path $script:LogFile -Value ("{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg) }
}

function Finish([int]$code) {
    if (-not $Unattended) { Write-Host ""; Read-Host "Press Enter to close" | Out-Null }
    exit $code
}

function Get-Sha256([string]$path) {
    (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
}

function Find-ModsFolder {
    if ($ModsPath) { return $ModsPath }
    $docs = [Environment]::GetFolderPath("MyDocuments")      # follows OneDrive / moved Documents
    if (-not $docs) { $docs = Join-Path $HOME "Documents" }
    $gameDir = Join-Path $docs "My Games\FarmingSimulator2025"
    # Respect the game's own "mods directory override" if the player set one.
    $settings = Join-Path $gameDir "gameSettings.xml"
    if (Test-Path -LiteralPath $settings) {
        try {
            [xml]$xml = Get-Content -LiteralPath $settings -Raw
            $ov = $xml.SelectSingleNode("//modsDirectoryOverride")
            if ($ov -and $ov.active -eq "true" -and $ov.directory) { return $ov.directory }
        } catch { }
    }
    return (Join-Path $gameDir "mods")
}

function Read-Manifest([string]$src) {
    if (Test-Path -LiteralPath $src) { return (Get-Content -LiteralPath $src -Raw | ConvertFrom-Json) }
    $r = Invoke-WebRequest -Uri $src -UseBasicParsing -UserAgent $UserAgent -TimeoutSec 60
    $text = if ($r.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($r.Content) } else { $r.Content }
    return ($text | ConvertFrom-Json)
}

function Get-ModFile($mod, [string]$dest) {
    # Try the mirror first (if any), then GIANTS ModHub. Returns $true when $dest holds the right file.
    $sources = @()
    if ($MirrorBase) { $sources += ,@("mirror", ($MirrorBase.TrimEnd("/", "\") + "/" + $mod.file)) }
    if ($mod.download) { $sources += ,@("ModHub", $mod.download) }
    foreach ($s in $sources) {
        $kind = $s[0]; $src = $s[1]
        try {
            if (Test-Path -LiteralPath $src) {
                Copy-Item -LiteralPath $src -Destination $dest -Force
            } else {
                $headers = @{}
                if ($mod.url) { $headers["Referer"] = $mod.url }   # ModHub's download server wants the mod page as referer
                try {
                    Invoke-WebRequest -Uri $src -OutFile $dest -UseBasicParsing -UserAgent $UserAgent -Headers $headers -TimeoutSec 900
                } catch {
                    # Fallback: curl.exe ships with Windows 10/11.
                    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
                    if (-not $curl) { throw }
                    & $curl.Source -sSfL --retry 3 -A $UserAgent -e "$($mod.url)" -o $dest $src
                    if ($LASTEXITCODE -ne 0) { throw "curl.exe exit code $LASTEXITCODE" }
                }
            }
            if ((Get-Sha256 $dest) -eq $mod.sha256) { return $true }
            Say ("   {0} copy of {1} doesn't match the pack (the mod may have been updated on ModHub)." -f $kind, $mod.file) "Yellow"
        } catch {
            Say ("   Couldn't get {0} from {1}: {2}" -f $mod.file, $kind, $_.Exception.Message) "Yellow"
        }
        Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
    }
    return $false
}

# ---------------------------------------------------------------- start
$stateRoot = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { [IO.Path]::GetTempPath() }
$stateDir = Join-Path $stateRoot "fs25-pack"
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
$script:LogFile = Join-Path $stateDir "install.log"

Say "FS25 mod pack installer" "Cyan"

if (Get-Process -Name "FarmingSimulator2025*" -ErrorAction SilentlyContinue) {
    Say "Farming Simulator 25 is running. Close the game, then run this again." "Red"
    Finish 2
}

$mods = Find-ModsFolder
Say "Mods folder: $mods"
New-Item -ItemType Directory -Force -Path $mods | Out-Null

try { $manifest = Read-Manifest $ManifestUrl }
catch { Say "Couldn't read the pack list from $ManifestUrl : $($_.Exception.Message)" "Red"; Finish 1 }
if (-not $manifest.mods -or $manifest.mods.Count -lt 1) { Say "The pack list is empty or broken. Nothing changed." "Red"; Finish 1 }
Say ("Pack {0}, version {1}: {2} mods, about {3:N0} MB, for game patch {4}" -f $manifest.pack, $manifest.pack_version, $manifest.mods.Count, ($manifest.total_bytes / 1MB), $manifest.game_patch)

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = Join-Path (Split-Path -Parent $mods) ("mods_backup\" + $stamp)
$tmp = Join-Path $mods ".fs25pack-download"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

function Move-ToBackup([string]$path) {
    New-Item -ItemType Directory -Force -Path $backup | Out-Null
    Move-Item -LiteralPath $path -Destination (Join-Path $backup (Split-Path -Leaf $path)) -Force
}

$wanted = @{}
foreach ($m in $manifest.mods) { $wanted[$m.file.ToLowerInvariant()] = $m }

# 1) Work out what needs downloading.
$todo = @()
$ok = 0
foreach ($m in $manifest.mods) {
    $target = Join-Path $mods $m.file
    if ((Test-Path -LiteralPath $target) -and ((Get-Sha256 $target) -eq $m.sha256)) { $ok++ } else { $todo += $m }
}
Say ("Already up to date: {0}. To download: {1}." -f $ok, $todo.Count)

# 2) Download + verify into a temp folder, then swap in (old file goes to backup).
$failed = @()
$i = 0
foreach ($m in $todo) {
    $i++
    Say ("[{0}/{1}] {2} {3} ({4:N1} MB)" -f $i, $todo.Count, $m.name, $m.version, ($m.bytes / 1MB))
    $part = Join-Path $tmp $m.file
    if (Get-ModFile $m $part) {
        $target = Join-Path $mods $m.file
        if (Test-Path -LiteralPath $target) { Move-ToBackup $target }
        Move-Item -LiteralPath $part -Destination $target -Force
    } else {
        $failed += $m
        Say ("   FAILED: {0}. Your old copy (if any) was left in place." -f $m.name) "Red"
    }
}
Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue

# 3) Anything not in the pack goes to the backup folder so everyone matches exactly.
$removed = 0
if (-not $KeepExtras) {
    Get-ChildItem -LiteralPath $mods -Force | Where-Object {
        $_.Name -ne ".fs25pack-download" -and -not $wanted.ContainsKey($_.Name.ToLowerInvariant())
    } | ForEach-Object { Move-ToBackup $_.FullName; $removed++; Say ("   Moved out (not in pack): {0}" -f $_.Name) }
}

# 4) Record what was installed and report.
@{ pack = $manifest.pack; pack_version = $manifest.pack_version; installed = (Get-Date).ToString("s");
   mods_folder = $mods; failed = @($failed | ForEach-Object { $_.file }) } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stateDir "state.json")

Say ""
if ($removed -gt 0 -or (Test-Path -LiteralPath $backup)) { Say "Old or extra files were moved (not deleted) to: $backup" }
if ($failed.Count -gt 0) {
    Say ("{0} mod(s) could not be installed: {1}" -f $failed.Count, (($failed | ForEach-Object { $_.name }) -join ", ")) "Red"
    Say "Tell Luke: the pack probably needs a refresh because a mod was updated on ModHub." "Red"
    Say "Log: $script:LogFile"
    Finish 1
}
Say ("Done. All {0} mods match pack version {1}. Start the game and join the server." -f $manifest.mods.Count, $manifest.pack_version) "Green"
Finish 0
