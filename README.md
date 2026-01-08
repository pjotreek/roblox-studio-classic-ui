# Disable New Roblox Studio UI 

This repository provides a PowerShell script that disables the **new generation Roblox Studio UI** by forcing the following client flag:

```json
{ "FFlagEnableRibbonPlugin3": "false" }
```

The script also installs a **Scheduled Task** so the setting is automatically re-applied every time you log in (useful after Roblox updates).


---

## Requirements

- Windows
- Roblox Studio installed
- PowerShell (Windows PowerShell 5.1 or newer)
- Administrator privileges (the script will prompt automatically)

---

## Option A — Run via `irm | iex` (one-liner)


Open **PowerShell** and run:

```powershell
Start-Process powershell -Verb RunAs -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -NoExit -EncodedCommand ' + [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes('$u="https://raw.githubusercontent.com/pjotreek/roblox-studio-classic-ui/main/RobloxStudioOldUI.ps1"; $p=Join-Path $env:TEMP "RobloxStudioOldUI.ps1"; Invoke-WebRequest -UseBasicParsing $u -OutFile $p; & $p')))

```


---

## Option B — Run manually

### 1. Download the script
Download `RobloxStudioOldUI.ps1` from this repository.

### 2. Run it
Right-click the file and select:

**Run with PowerShell**

Or run it manually:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\RobloxStudioOldUI.ps1"
```

---

## What the script does

- Detects the active Roblox Studio folder:
  - `%LOCALAPPDATA%\Roblox\Versions\<version>\RobloxStudioBeta.exe`
- Creates:
  - `ClientSettings\ClientAppSettings.json`
- Writes:
  ```json
  { "FFlagEnableRibbonPlugin3": "false" }
  ```
- Installs a Scheduled Task:
  - **Name:** `RobloxStudio - Disable Ribbon Plugin`
  - **Trigger:** At user logon
  - **Purpose:** Re-applies the flag after Roblox updates
- Stores the fixer script at:
  - `C:\ProgramData\RobloxStudioTweaks\DisableRibbonPlugin.ps1`

---

## Verify installation

### Check Scheduled Task
```powershell
Get-ScheduledTask -TaskName "RobloxStudio - Disable Ribbon Plugin"
```

### Run the task manually
```powershell
schtasks /Run /TN "RobloxStudio - Disable Ribbon Plugin"
```

### Confirm the settings file
1. Open:
   ```
   %LOCALAPPDATA%\Roblox\Versions\
   ```
2. Open the newest folder containing `RobloxStudioBeta.exe`
3. Check:
   ```
   ClientSettings\ClientAppSettings.json
   ```

Expected contents:
```json
{ "FFlagEnableRibbonPlugin3": "false" }
```

---

## Uninstall / Remove everything

### 1. Remove the Scheduled Task
```powershell
schtasks /Delete /F /TN "RobloxStudio - Disable Ribbon Plugin"
```

### 2. Remove the installed fixer script (optional)
```powershell
Remove-Item "C:\ProgramData\RobloxStudioTweaks" -Recurse -Force
```

### 3. Remove all Roblox Studio client overrides (optional)

This removes `ClientSettings` from **all** Roblox version folders:

```powershell
$versions = Join-Path $env:LOCALAPPDATA "Roblox\Versions"
Get-ChildItem $versions -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $cs = Join-Path $_.FullName "ClientSettings"
    if (Test-Path $cs) {
        Remove-Item $cs -Recurse -Force
    }
}
```

---

## Notes

- Roblox Studio updates frequently create new folders under `Versions`
- The Scheduled Task ensures the UI flag is always restored
- This setup is Windows-only

---

## Disclaimer

This project is **unofficial**. Roblox may change or remove client flags at any time, which could cause this tweak to stop working. This script is made mostly with ChatGPT and I don't guarantee it working for you.
