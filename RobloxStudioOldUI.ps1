# RobloxStudioOldUI.ps1
# Disables the new-gen Roblox Studio UI and keeps the console open on success.

$ErrorActionPreference = "Stop"

function Info($m)  { Write-Host "[INFO]    $m" -ForegroundColor Cyan }
function Ok($m)    { Write-Host "[SUCCESS] $m" -ForegroundColor Green }
function Warn($m)  { Write-Host "[WARN]    $m" -ForegroundColor Yellow }
function Err($m)   { Write-Host "[ERROR]   $m" -ForegroundColor Red }

function Pause-Exit {
    Write-Host ""
    Write-Host "Press ENTER to close this window..." -ForegroundColor DarkGray
    Read-Host | Out-Null
}

function Ensure-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal]
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($isAdmin) { return }

    Info "Requesting Administrator privileges..."

    $selfPath = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($selfPath)) {
        $selfPath = Join-Path $env:TEMP ("RobloxStudioOldUI_" + [guid]::NewGuid() + ".ps1")
        $scriptText = $MyInvocation.MyCommand.Definition
        Set-Content -Path $selfPath -Value $scriptText -Encoding UTF8
        Info "Saved script to temporary file for elevation."
    }

    Start-Process powershell -Verb RunAs `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$selfPath`""

    exit
}

function Get-StudioFolder {
    $base = Join-Path $env:LOCALAPPDATA "Roblox\Versions"
    if (-not (Test-Path $base)) { return $null }

    Get-ChildItem $base -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName "RobloxStudioBeta.exe") } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 |
        Select-Object -ExpandProperty FullName
}

function Apply-Flag {
    $studio = Get-StudioFolder
    if (-not $studio) {
        Warn "Roblox Studio was not found. Install or open it once, then rerun."
        return $false
    }

    $cs = Join-Path $studio "ClientSettings"
    $json = Join-Path $cs "ClientAppSettings.json"

    New-Item $cs -ItemType Directory -Force | Out-Null
    '{ "FFlagEnableRibbonPlugin3": "false" }' |
        Set-Content $json -Encoding UTF8

    Ok "ClientAppSettings.json written successfully"
    Write-Host "          $json"
    return $true
}

function Install-FixerScript($path) {
@'
$ErrorActionPreference = "SilentlyContinue"
$base = Join-Path $env:LOCALAPPDATA "Roblox\Versions"
if (-not (Test-Path $base)) { exit 0 }

Get-ChildItem $base -Directory |
 Where-Object { Test-Path (Join-Path $_.FullName "RobloxStudioBeta.exe") } |
 Sort-Object LastWriteTime -Descending |
 Select-Object -First 1 |
 ForEach-Object {
    $cs = Join-Path $_.FullName "ClientSettings"
    New-Item $cs -ItemType Directory -Force | Out-Null
    '{ "FFlagEnableRibbonPlugin3": "false" }' |
        Set-Content (Join-Path $cs "ClientAppSettings.json") -Encoding UTF8
 }
'@ | Set-Content $path -Encoding UTF8
}

function Install-Task($fixer) {
    $name = "RobloxStudio - Disable Ribbon Plugin"
    $cmd  = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$fixer`""

    schtasks /Create /F /SC ONLOGON /TN $name /TR $cmd | Out-Null
    Ok "Scheduled Task created successfully"
    Write-Host "          $name"
}

# ---------------- MAIN ----------------
try {
    Ensure-Admin

    $installDir = "C:\ProgramData\RobloxStudioTweaks"
    $fixer = Join-Path $installDir "DisableRibbonPlugin.ps1"

    New-Item $installDir -ItemType Directory -Force | Out-Null
    Info "Using install directory: $installDir"

    Install-FixerScript $fixer
    Ok "Fixer script installed"

    $applied = Apply-Flag
    Install-Task $fixer

    schtasks /Run /TN "RobloxStudio - Disable Ribbon Plugin" | Out-Null
    Ok "Startup task executed once immediately"

    Write-Host ""
    Ok "Roblox Studio Classic UI setup completed successfully 🎉"

    if (-not $applied) {
        Warn "The setting will apply automatically once Roblox Studio exists."
    }

    Pause-Exit
}
catch {
    Err $_.Exception.Message
    Pause-Exit
}
