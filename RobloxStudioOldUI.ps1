# RobloxStudioOldUI.ps1
# Disables new Roblox Studio UI by setting:
# { "FFlagEnableRibbonPlugin3": "false" }
# Installs a logon scheduled task and prints clear success messages.

$ErrorActionPreference = "Stop"

function Pause-Exit {
    Write-Host ""
    Write-Host "Press ENTER to close..." -ForegroundColor DarkGray
    [void](Read-Host)
}

function Is-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Admin {
    if (Is-Admin) { return }

    Write-Host "[INFO] Requesting Administrator privileges..." -ForegroundColor Cyan

    # When running via irm|iex, there's no file path. Save to temp, then run elevated.
    $selfPath = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($selfPath)) {
        $selfPath = Join-Path $env:TEMP ("RobloxStudioOldUI_" + ([guid]::NewGuid().ToString("N")) + ".ps1")
        $scriptText = $MyInvocation.MyCommand.Definition
        Set-Content -Path $selfPath -Value $scriptText -Encoding UTF8
        Write-Host "[INFO] Saved to temp for elevation: $selfPath" -ForegroundColor Cyan
    }

    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$selfPath`""
    exit
}

function Get-StudioFolder {
    $base = Join-Path $env:LOCALAPPDATA "Roblox\Versions"
    if (-not (Test-Path $base)) { return $null }

    $folders = Get-ChildItem -Path $base -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName "RobloxStudioBeta.exe") }

    if (-not $folders) { return $null }

    return ($folders | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}

function Apply-Flag {
    $studio = Get-StudioFolder
    if (-not $studio) {
        Write-Host "[WARN] Roblox Studio not found in %LOCALAPPDATA%\Roblox\Versions (no RobloxStudioBeta.exe)." -ForegroundColor Yellow
        return $false
    }

    $cs = Join-Path $studio "ClientSettings"
    $json = Join-Path $cs "ClientAppSettings.json"

    New-Item -Path $cs -ItemType Directory -Force | Out-Null
    Set-Content -Path $json -Encoding UTF8 -Value '{ "FFlagEnableRibbonPlugin3": "false" }'

    Write-Host "[SUCCESS] Wrote settings file:" -ForegroundColor Green
    Write-Host "          $json"
    return $true
}

function Install-FixerScript {
    param([Parameter(Mandatory=$true)][string]$FixerPath)

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
'@ | Set-Content -Path $FixerPath -Encoding UTF8
}

function Install-Task {
    param([Parameter(Mandatory=$true)][string]$FixerPath)

    $taskName = "RobloxStudio - Disable Ribbon Plugin"
    $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$FixerPath`""
    schtasks /Create /F /SC ONLOGON /TN $taskName /TR $cmd | Out-Null

    Write-Host "[SUCCESS] Scheduled Task created:" -ForegroundColor Green
    Write-Host "          $taskName"
}

# ---------------- MAIN ----------------
try {
    Ensure-Admin

    $installDir = "C:\ProgramData\RobloxStudioTweaks"
    $fixerPath  = Join-Path $installDir "DisableRibbonPlugin.ps1"

    New-Item -Path $installDir -ItemType Directory -Force | Out-Null
    Write-Host "[INFO] Install dir: $installDir" -ForegroundColor Cyan

    Install-FixerScript -FixerPath $fixerPath
    Write-Host "[SUCCESS] Fixer script installed:" -ForegroundColor Green
    Write-Host "          $fixerPath"

    $applied = Apply-Flag
    Install-Task -FixerPath $fixerPath

    schtasks /Run /TN "RobloxStudio - Disable Ribbon Plugin" | Out-Null
    Write-Host "[SUCCESS] Ran task once immediately." -ForegroundColor Green

    Write-Host ""
    Write-Host "[SUCCESS] Completed setup!" -ForegroundColor Green
    if (-not $applied) {
        Write-Host "[WARN] Roblox Studio wasn't detected yet. It will apply once Studio is installed/opened." -ForegroundColor Yellow
    }

    Pause-Exit
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Pause-Exit
    exit 1
}
