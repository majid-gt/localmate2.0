# LocalMate Dev Launcher Script
# This script starts the backend server (if not already running),
# sets up ADB reverse port forwarding, and runs the Flutter app.

$ErrorActionPreference = "Stop"

# Get script folder path
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($scriptRoot)) {
    $scriptRoot = Get-Location
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "      LOCALMATE DEVELOPMENT LAUNCHER    " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. Locate ADB
$adbPath = "adb"
$defaultAdb = "C:\Users\MD MAJID\AppData\Local\Android\Sdk\platform-tools\adb.exe"
if (Test-Path $defaultAdb) {
    $adbPath = $defaultAdb
} elseif ($env:ANDROID_HOME -and (Test-Path "$env:ANDROID_HOME\platform-tools\adb.exe")) {
    $adbPath = "$env:ANDROID_HOME\platform-tools\adb.exe"
}

# 2. Check if a device is connected
Write-Host "Checking connected Android devices..." -ForegroundColor Gray
$devicesOutput = & $adbPath devices
$deviceCount = 0
$deviceLines = $devicesOutput -split "`r?`n"
foreach ($line in $deviceLines) {
    if ($line -match "device$") {
        $deviceCount++
        Write-Host "Found device: $line" -ForegroundColor Green
    }
}

if ($deviceCount -eq 0) {
    Write-Host "ERROR: No connected Android device found!" -ForegroundColor Red
    Write-Host "Please connect your phone, enable USB debugging, and try again." -ForegroundColor Yellow
    exit 1
}

# 3. Check and start backend server
Write-Host "Checking backend server on port 8000..." -ForegroundColor Gray
$portInUse = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Listen' }
if ($portInUse) {
    Write-Host "Backend server is already running on port 8000." -ForegroundColor Green
} else {
    Write-Host "Backend server is not running. Starting in a new window..." -ForegroundColor Yellow
    $pythonPath = Join-Path $scriptRoot "backend\venv\Scripts\python.exe"
    $backendDir = Join-Path $scriptRoot "backend"
    
    if (-not (Test-Path $pythonPath)) {
        Write-Host "ERROR: Could not find Python venv at $pythonPath" -ForegroundColor Red
        exit 1
    }
    
    # Start uvicorn in a new command window so logs are visible separately
    Start-Process cmd.exe -ArgumentList "/k `"$pythonPath`" -m uvicorn app.main:app --host 127.0.0.1 --port 8000" -WorkingDirectory $backendDir
    Start-Sleep -Seconds 3
}

# 4. Set up ADB Reverse Port Forwarding
Write-Host "Configuring ADB port forwarding (reverse tcp:8000 tcp:8000)..." -ForegroundColor Gray
& $adbPath reverse tcp:8000 tcp:8000
if ($LASTEXITCODE -eq 0) {
    Write-Host "ADB Port Forwarding successful! Phone can now access localhost:8000." -ForegroundColor Green
} else {
    Write-Host "WARNING: Failed to setup ADB reverse port forwarding. Check connection." -ForegroundColor Yellow
}

# 5. Launch Flutter App
Write-Host "Launching Flutter app..." -ForegroundColor Green
$mobileDir = Join-Path $scriptRoot "mobile"
Set-Location $mobileDir
flutter run
