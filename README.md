# FS25 rags-to-riches mod pack

One script that installs the exact same Farming Simulator 25 mods for everyone in our game.

## Install (Windows)

1. Close Farming Simulator 25.
2. Open PowerShell (Start menu, type "PowerShell") and paste:

   ```powershell
   irm https://github.com/akimbohh/fs25-pack/releases/latest/download/install-fs25-pack.ps1 -OutFile $env:TEMP\fs25pack.ps1; powershell -ExecutionPolicy Bypass -File $env:TEMP\fs25pack.ps1
   ```

3. Wait for "Done. All 63 mods match pack version ...". The first run downloads about 1.26 GB.
4. Start the game and join. Run the same line again whenever the pack is updated.

## What it does

- Finds your `Documents\My Games\FarmingSimulator2025\mods` folder (OneDrive too).
- Downloads each mod straight from the official GIANTS ModHub and checks it against the SHA-256 in `manifest.json`.
- Moves mods that aren't in the pack to `mods_backup\<date>` (nothing is deleted). Use `-KeepExtras` to keep them.
- No admin rights needed. Log: `%LOCALAPPDATA%\fs25-pack\install.log`.

No mod files are hosted here. All mods belong to their authors and come from https://www.farming-simulator.com/mods.php?title=fs2025.
