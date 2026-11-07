# FS25 rags-to-riches mod pack

One installer that puts the exact same Farming Simulator 25 mods on every player's PC.

## Install (Windows)

1. Close Farming Simulator 25.
2. Download **[fs25-pack-installer.exe](https://github.com/akimbohh/fs25-pack/releases/latest/download/fs25-pack-installer.exe)** and double-click it.
3. Windows will say **"Windows protected your PC"** because the installer isn't code-signed. Click **More info**, then **Run anyway**.
4. Click **Install / Update** and wait for "Done". The first run downloads about 1.3 GB.
5. Start the game and join. Run the installer again whenever the pack is updated.

"Keep my other mods" is ticked by default, so mods that aren't in the pack stay where they are. Old versions of pack mods are moved to `mods_backup`, never deleted.

### If it says Windows blocked it (Ransomware protection)

If Controlled folder access is on, Windows stops new apps from writing to Documents. The installer checks for this before downloading anything.

- **Easy way:** click **Allow this installer** and say Yes to the Windows prompt. It only adds the installer itself to the allowed apps list. It doesn't turn the protection off or change anything else.
- The installer copies itself to `%LOCALAPPDATA%\fs25-pack\fs25-pack-installer.exe` and runs from there, because Windows remembers the allowed app by its location. Use that copy for future updates.
- **By hand:** Windows Security > Virus & threat protection > Manage ransomware protection > Allow an app through Controlled folder access > Add an allowed app > Browse all apps. Pick the installer, then click **Try again**.

## What's new in 2026.11.07-r2 (adds 6 mods, changes none)

Re-run the same installer; it only downloads the 6 new mods. Your existing 63 and your own mods stay as they are.

- DynamicDrive Pro, Wet Ground Wheel Slip, Interactive Control (GIANTS ModHub)
- Soil Deformation Save (downloaded from the author's own Google Drive link; the author doesn't allow re-uploads)
- 1976 Chevrolet K30 by CrowneX and 2020 GMC Sierra Denali 2500 by AG Farms (free on the authors' itch.io pages; copies attached to the release so the installer can fetch them, each checked by SHA-256)

## Details

- Mods come straight from the official GIANTS ModHub, and each file is checked against the SHA-256 fingerprint in `manifest.json`.
- No admin rights needed. Log: `%LOCALAPPDATA%\fs25-pack\install.log`.
- Unattended: `fs25-pack-installer.exe --silent` (add `--keep-extras=false` to move non-pack mods).
  Exit codes: 0 done, 1 failed, 2 game running, 3 Windows blocked writing (Ransomware protection), 4 downloads failing.
- Fallback without the exe: `install-fs25-pack.ps1` (PowerShell):
  `irm https://github.com/akimbohh/fs25-pack/releases/latest/download/install-fs25-pack.ps1 -OutFile $env:TEMP\fs25pack.ps1; powershell -ExecutionPolicy Bypass -File $env:TEMP\fs25pack.ps1`

No mod files are hosted here. All mods belong to their authors and come from https://www.farming-simulator.com/mods.php?title=fs2025.
