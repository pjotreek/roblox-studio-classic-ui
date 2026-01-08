param(
    [switch]$Elevated
)

$ErrorActionPreference = "Stop"

$LogPath = Join-Path $env:TEMP "RobloxStudioOldUI.log"

function Log($msg) {
    $line = ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg)
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

function Say($tag, $msg, $color="White") {
    Write-Host "[$tag] $msg" -ForegroundColor $color
    Log "[$tag] $msg"
}

function PauseExit {
    Say "INFO" "Log: $LogPath" "DarkGray"
    Write-Host ""
    Write-Host "Press ENTER to close..." -ForegroundColor DarkGray
    [void](Read-Host)
}

function IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function EnsureAdmin {
    if (IsAdmin) {
        Say "OK" "Running as Administrator." "Green"
        return
    }

    # If we're already in the "second run", DO NOT try again (prevents spam loop)
    if ($Elevated) {
        throw "Still not Administrator after elevation attempt. Please open PowerShell as Admin and run again."
    }

    Say "INFO" "Requesting Administrator privileges..." "Cyan"

    # When running via irm|iex, there is no file path. Save script to temp first.
    $selfPath = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($selfPath)) {
        $selfPath = Join-Path $env:TEMP ("RobloxStudioOldUI_" + ([guid]::NewGuid().ToString("N")) + ".ps1")
        $scriptText = $MyInvocation.MyCommand.Definition
        Set-Content -Path $selfPath -Value $scriptText -Encoding UTF8
        Say "INFO" "Saved script to temp: $selfPath" "Cyan"
    }

    # IMPORTANT: pass -Elevated so the elevated instance never re-prompts
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$selfPath`" -Elevated"
    exit
}

function GetStudioFolder {
    $base = Join-Path $env:LOCALAPPDATA "Roblox\Versions"
    if (-not (Test-Path $base)) { return $null }

    $folders = Get-ChildItem -Path $base -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName "RobloxStudioBeta.exe") }

    if (-not $folders) { return $null }
    return ($folders | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}

function ApplyFlag {
    $studio = GetStudioFolder
    if (-not $studio) {
        Say "WARN" "Roblox Studio not found under %LOCALAPPDATA%\Roblox\Versions (no RobloxStudioBeta.exe)." "Yellow"
        return $false
    }

    $cs   = Join-Path $studio "ClientSettings"
    $json = Join-Path $cs "ClientAppSettings.json"

    New-Item -Path $cs -ItemType Directory -Force | Out-Null
    Set-Content -Path $json -Encoding UTF8 -Value '{ "FFlagEnableRibbonPlugin3": "false" }'

    Say "SUCCESS" "Wrote settings: $json" "Green"
    return $true
}

function InstallFixerScript($fixerPath) {
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

    Say "SUCCESS" "Installed fixer: $fixerPath" "Green"
}

function InstallTask($fixerPath) {
    $taskName = "RobloxStudio - Disable Ribbon Plugin"
    $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$fixerPath`""
    schtasks /Create /F /SC ONLOGON /TN $taskName /TR $cmd | Out-Null
    Say "SUCCESS" "Created Scheduled Task: $taskName" "Green"
}

# ---------------- MAIN ----------------
try {
    Remove-Item $LogPath -ErrorAction SilentlyContinue | Out-Null
    Say "INFO" "Starting setup..." "Cyan"

    EnsureAdmin

    $installDir = "C:\ProgramData\RobloxStudioTweaks"
    $fixerPath  = Join-Path $installDir "DisableRibbonPlugin.ps1"
    New-Item -Path $installDir -ItemType Directory -Force | Out-Null

    InstallFixerScript $fixerPath
    $applied = ApplyFlag
    InstallTask $fixerPath

    schtasks /Run /TN "RobloxStudio - Disable Ribbon Plugin" | Out-Null
    Say "SUCCESS" "Ran task once now." "Green"

    Say "SUCCESS" "Done!" "Green"
    if (-not $applied) {
        Say "WARN" "Roblox Studio not detected yet. It will apply once Studio is installed/opened." "Yellow"
    }

    PauseExit
}
catch {
    Say "ERROR" $_.Exception.Message "Red"
    PauseExit
    exit 1
}
