# RobloxStudioOldUI.ps1
# Installer (must be run as Administrator). No self-elevation -> no loops.

$ErrorActionPreference = "Stop"

$LogPath = Join-Path $env:TEMP "RobloxStudioOldUI-install.log"

function IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function PauseExit {
    Write-Host ""
    Write-Host "Log saved to: $LogPath" -ForegroundColor DarkGray
    Write-Host "Press ENTER to close..." -ForegroundColor DarkGray
    [void](Read-Host)
}

try {
    # Always log (transcript is the most reliable)
    Start-Transcript -Path $LogPath -Force | Out-Null

    Write-Host "[INFO] Starting Roblox Studio Classic UI setup..." -ForegroundColor Cyan

    if (-not (IsAdmin)) {
        Write-Host "[ERROR] This installer must be run as Administrator." -ForegroundColor Red
        Write-Host "Open PowerShell as Admin, then run the install command from the README." -ForegroundColor Yellow
        PauseExit
        exit 1
    }

    # --- Find Roblox Studio folder ---
    $base = Join-Path $env:LOCALAPPDATA "Roblox\Versions"
    $studioFolder = $null

    if (Test-Path $base) {
        $studioFolder = Get-ChildItem -Path $base -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName "RobloxStudioBeta.exe") } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1 |
            Select-Object -ExpandProperty FullName
    }

    if (-not $studioFolder) {
        Write-Host "[WARN] Roblox Studio not found in %LOCALAPPDATA%\Roblox\Versions (no RobloxStudioBeta.exe)." -ForegroundColor Yellow
        Write-Host "[WARN] Install/open Roblox Studio once, then run this installer again." -ForegroundColor Yellow
    }
    else {
        $cs   = Join-Path $studioFolder "ClientSettings"
        $json = Join-Path $cs "ClientAppSettings.json"
        New-Item -Path $cs -ItemType Directory -Force | Out-Null
        Set-Content -Path $json -Encoding UTF8 -Value '{ "FFlagEnableRibbonPlugin3": "false" }'

        Write-Host "[SUCCESS] Wrote settings file:" -ForegroundColor Green
        Write-Host "          $json"
    }

    # --- Install fixer script (runs at logon) ---
    $installDir = "C:\ProgramData\RobloxStudioTweaks"
    $fixerPath  = Join-Path $installDir "DisableRibbonPlugin.ps1"
    New-Item -Path $installDir -ItemType Directory -Force | Out-Null

@'
$ErrorActionPreference = "SilentlyContinue"
$base = Join-Path $env:LOCALAPPDATA "Roblox\Versions"
if (-not (Test-Path $base)) { exit 0 }

$target = Get-ChildItem -Path $base -Directory |
  Where-Object { Test-Path (Join-Path $_.FullName "RobloxStudioBeta.exe") } |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if (-not $target) { exit 0 }

$cs = Join-Path $target.FullName "ClientSettings"
New-Item -Path $cs -ItemType Directory -Force | Out-Null
Set-Content -Path (Join-Path $cs "ClientAppSettings.json") -Encoding UTF8 -Value '{ "FFlagEnableRibbonPlugin3": "false" }'
exit 0
'@ | Set-Content -Path $fixerPath -Encoding UTF8

    Write-Host "[SUCCESS] Installed fixer script:" -ForegroundColor Green
    Write-Host "          $fixerPath"

    # --- Create scheduled task ---
    $taskName = "RobloxStudio - Disable Ribbon Plugin"
    $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$fixerPath`""
    schtasks /Create /F /SC ONLOGON /TN $taskName /TR $cmd | Out-Null

    Write-Host "[SUCCESS] Created Scheduled Task:" -ForegroundColor Green
    Write-Host "          $taskName"

    # Run it once immediately
    schtasks /Run /TN $taskName | Out-Null
    Write-Host "[SUCCESS] Ran task once immediately." -ForegroundColor Green

    Write-Host ""
    Write-Host "[SUCCESS] Setup complete 🎉" -ForegroundColor Green

    PauseExit
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    PauseExit
    exit 1
}
finally {
    try { Stop-Transcript | Out-Null } catch {}
}
