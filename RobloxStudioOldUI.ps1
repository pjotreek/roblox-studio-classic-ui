# Setup-RobloxStudioFlag.ps1
# Does ALL steps:
# 1) Finds Roblox Studio folder (Versions\*\RobloxStudioBeta.exe)
# 2) Creates ClientSettings\ClientAppSettings.json
# 3) Writes: {"FFlagEnableRibbonPlugin3":"false"}
# 4) Sets up a scheduled task to run at logon
# 5) Runs once immediately

$ErrorActionPreference = "Stop"

function Get-StudioVersionFolder {
    $base = Join-Path $env:LOCALAPPDATA "Roblox\Versions"
    if (-not (Test-Path $base)) { return $null }

    $candidates = Get-ChildItem -Path $base -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName "RobloxStudioBeta.exe") }

    if (-not $candidates) { return $null }

    # Most recently modified folder is usually the active/updated one
    return ($candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}

function Apply-Flag {
    $studioFolder = Get-StudioVersionFolder
    if (-not $studioFolder) {
        Write-Host "Could not find Roblox Studio. Make sure Roblox Studio is installed, then run again." -ForegroundColor Yellow
        return $false
    }

    $clientSettingsDir = Join-Path $studioFolder "ClientSettings"
    $jsonPath = Join-Path $clientSettingsDir "ClientAppSettings.json"

    New-Item -Path $clientSettingsDir -ItemType Directory -Force | Out-Null

    # EXACT content you asked for
    $content = '{ "FFlagEnableRibbonPlugin3": "false" }'
    Set-Content -Path $jsonPath -Value $content -Encoding UTF8

    Write-Host "Updated:" -ForegroundColor Green
    Write-Host "  $jsonPath"
    return $true
}

function Install-StartupTask {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FixScriptPath
    )

    $taskName = "RobloxStudio - Disable Ribbon Plugin"

    # Build task command
    $taskCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$FixScriptPath`""

    # Create/replace the task (runs on logon)
    schtasks /Create /F /SC ONLOGON /TN $taskName /TR $taskCmd | Out-Null

    Write-Host "Scheduled task installed:" -ForegroundColor Green
    Write-Host "  $taskName"
}

# --- Main ---
# Put the "fixer" script somewhere stable
$installDir = "C:\ProgramData\RobloxStudioTweaks"
$fixScript  = Join-Path $installDir "DisableRibbonPlugin.ps1"

# Ensure admin for writing ProgramData + creating tasks
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Re-running as Administrator..." -ForegroundColor Cyan
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

New-Item -Path $installDir -ItemType Directory -Force | Out-Null

# Write the fixer script that runs at every login
@'
$ErrorActionPreference = "SilentlyContinue"
$base = Join-Path $env:LOCALAPPDATA "Roblox\Versions"
if (-not (Test-Path $base)) { exit 0 }

$candidates = Get-ChildItem -Path $base -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName "RobloxStudioBeta.exe") }

if (-not $candidates) { exit 0 }

$target = $candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$clientSettingsDir = Join-Path $target.FullName "ClientSettings"
$jsonPath = Join-Path $clientSettingsDir "ClientAppSettings.json"

New-Item -Path $clientSettingsDir -ItemType Directory -Force | Out-Null

# EXACT content requested
'{ "FFlagEnableRibbonPlugin3": "false" }' | Set-Content -Path $jsonPath -Encoding UTF8

exit 0
'@ | Set-Content -Path $fixScript -Encoding UTF8

Write-Host "Installed fixer script to:" -ForegroundColor Green
Write-Host "  $fixScript"

# Apply once now
$ok = Apply-Flag

# Install startup/logon task
Install-StartupTask -FixScriptPath $fixScript

# Run scheduled task once immediately too (optional but nice)
schtasks /Run /TN "RobloxStudio - Disable Ribbon Plugin" | Out-Null

if ($ok) {
    Write-Host "`nDone. This will re-apply the setting every time you log in." -ForegroundColor Green
} else {
    Write-Host "`nDone, but Roblox Studio wasn't found yet. The startup task is installed and will work once Studio is installed." -ForegroundColor Yellow
}
