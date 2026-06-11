# Android Emulator penceresi ekran disina kaymissa geri getirir.
# Kullanim:
#   powershell -ExecutionPolicy Bypass -File scripts/reset_emulator_window.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/reset_emulator_window.ps1 -AvdName Pixel_9_Pro_XL -Relaunch

param(
    [string]$AvdName = "Pixel_9_Pro_XL",
    [int]$PosX = 80,
    [int]$PosY = 80,
    [int]$Width = 420,
    [int]$Height = 920,
    [double]$Scale = 0.33,
    [switch]$Relaunch
)

$ErrorActionPreference = "Stop"

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class EmulatorWinApi {
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@

function Reset-AvdWindowIni {
    param([string]$Name, [double]$WindowScale)
    $iniPath = Join-Path $env:USERPROFILE ".android\avd\$Name.avd\emulator-user.ini"
    if (-not (Test-Path $iniPath)) {
        Write-Warning "AVD ini bulunamadi: $iniPath"
        return
    }
    @"
window.x = $PosX
window.y = $PosY
window.scale = $WindowScale
resizable.config.id = -1
posture = 0
"@ | Set-Content -Path $iniPath -Encoding ASCII
    Write-Host "Pencere ayari kaydedildi: $iniPath"
}

function Move-EmulatorWindow {
    $proc = Get-Process -Name "qemu-system-x86_64" -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowTitle -match "Android Emulator" } |
        Select-Object -First 1
    if (-not $proc -or $proc.MainWindowHandle -eq [IntPtr]::Zero) {
        return $false
    }
    $flags = 0x0040 # SWP_SHOWWINDOW
    [EmulatorWinApi]::SetWindowPos($proc.MainWindowHandle, [IntPtr]::Zero, $PosX, $PosY, $Width, $Height, $flags) | Out-Null
    [EmulatorWinApi]::ShowWindow($proc.MainWindowHandle, 9) | Out-Null  # SW_RESTORE
    [EmulatorWinApi]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
    Write-Host "Emulator penceresi tasindi: $($proc.MainWindowTitle)"
    return $true
}

function Stop-AndroidEmulator {
    $adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $adb) {
        & $adb -s emulator-5554 emu kill 2>$null
        Start-Sleep -Seconds 2
    }
    Get-Process -Name "emulator", "qemu-system-x86_64" -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
}

Reset-AvdWindowIni -Name $AvdName -WindowScale $Scale

if (Move-EmulatorWindow) {
    Write-Host "Emulator zaten acikti; pencere ekrana alindi."
    exit 0
}

if ($Relaunch) {
    Stop-AndroidEmulator
    $emulator = Join-Path $env:LOCALAPPDATA "Android\Sdk\emulator\emulator.exe"
    if (-not (Test-Path $emulator)) {
        throw "emulator.exe bulunamadi: $emulator"
    }
    Write-Host "Emulator yeniden baslatiliyor: $AvdName (scale=$Scale)"
    Start-Process -FilePath $emulator -ArgumentList @("-avd", $AvdName, "-scale", "$Scale")
    exit 0
}

Write-Host "Acik emulator penceresi bulunamadi. Yeniden baslatmak icin -Relaunch ekleyin."
