# Timora Real Device Validation Script
$adb = "C:\Users\HASIB_ULLAH\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$apk = "build\app\outputs\flutter-apk\app-debug.apk"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " TIMORA NOTIFICATION ENGINE DEVICE RUNNER " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Check for connected device
$devices = & $adb devices
$deviceList = $devices | Select-String -Pattern "device$"

if ($deviceList.Count -eq 0) {
    Write-Host "`n[!] No device connected." -ForegroundColor Yellow
    Write-Host "Please connect your phone via USB with USB debugging enabled, then re-run this script." -ForegroundColor White
    exit 1
}

$deviceId = ($deviceList[0].Line -split "`t")[0]
Write-Host "`n[+] Device detected: $deviceId" -ForegroundColor Green

# 2. Install debug APK
Write-Host "`n[*] Installing $apk..." -ForegroundColor Yellow
& $adb -s $deviceId install -r $apk

if ($LASTEXITCODE -ne 0) {
    Write-Host "[!] APK install failed. Please check phone screen for 'Install via USB' authorization prompt." -ForegroundColor Red
    exit 1
}
Write-Host "[+] Installation successful!" -ForegroundColor Green

# 3. Clear existing logcat buffers
& $adb -s $deviceId logcat -c

# 4. Launch Timora
Write-Host "`n[*] Launching Timora..." -ForegroundColor Yellow
& $adb -s $deviceId shell am start -n com.example.timora/.MainActivity

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host " LIVE DIAGNOSTIC LOGCAT MONITORING        " -ForegroundColor Cyan
Write-Host " (Watching tags: TimoraAlarm, TimoraTTS)  " -ForegroundColor Cyan
Write-Host " Press Ctrl+C to stop monitoring          " -ForegroundColor Cyan
Write-Host "==========================================`n" -ForegroundColor Cyan

& $adb -s $deviceId logcat -v time TimoraAlarmPlugin:D TimoraSpeakingReceiver:D TimoraSpeakingService:D TimoraBootReceiver:D *:S
