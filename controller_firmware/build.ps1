# build_controller.ps1 — Build controller firmware and deploy OTA via NAS server
# Usage:
#   .\build_controller.ps1                     # build only
#   .\build_controller.ps1 -Upload             # build + upload firmware.bin to NAS + trigger OTA
#   .\build_controller.ps1 -Upload -Mac AA:BB:CC:DD:EE:FF  # specify device MAC
#   .\build_controller.ps1 -DirectOta          # build + upload directly via espota (must be on LAN)
param(
    [switch]$Upload,     # Upload firmware.bin to NAS server and trigger OTA via app
    [switch]$DirectOta,  # Upload directly via espota to tankmonitor.local (LAN only)
    [string]$Mac  = '',  # Device MAC address (required for -Upload)
    [switch]$Monitor     # Open serial monitor after direct OTA
)

$ErrorActionPreference = 'Stop'
$FwDir    = "$PSScriptRoot"
$pio      = "$env:USERPROFILE\.platformio\penv\Scripts\pio.exe"
if (-not (Test-Path $pio)) { $pio = 'pio' }  # fallback if in PATH

# NAS server config — firmware is uploaded here, then ESP32 pulls it via OTA
$NasUrl   = 'http://192.168.0.102:1880'
$ApiToken = $env:TANKMONITOR_TOKEN   # set in your shell profile, or pass via env

Write-Host "==> Building controller firmware (env: nebulas3)..." -ForegroundColor Cyan
Push-Location $FwDir
try {
    if ($DirectOta) {
        Write-Host "==> Building + uploading directly via espota to tankmonitor.local..." -ForegroundColor Cyan
        & $pio run --target upload --environment nebulas3
        if ($LASTEXITCODE -ne 0) { throw "PlatformIO espota upload failed" }
        Write-Host "==> Direct OTA upload complete." -ForegroundColor Green
        if ($Monitor) {
            Write-Host "==> Opening serial monitor..." -ForegroundColor Cyan
            & $pio device monitor
        }
    } elseif ($Upload) {
        # Step 1: Build
        & $pio run --environment nebulas3
        if ($LASTEXITCODE -ne 0) { throw "PlatformIO build failed" }

        $fwPath = ".pio\build\nebulas3\firmware.bin"
        $fw = Get-Item $fwPath -ErrorAction Stop
        Write-Host "==> Built: $($fw.FullName)  ($([math]::Round($fw.Length/1KB, 1)) KB)" -ForegroundColor Green

        # Step 2: Resolve MAC — ask if not supplied
        if ($Mac -eq '') {
            $Mac = Read-Host "Enter device MAC address (e.g. AA:BB:CC:DD:EE:FF)"
        }
        $Mac = $Mac.Trim().ToUpper()

        # Step 3: Get auth token if not set
        if (-not $ApiToken) {
            $cred = Get-Credential -Message "TankMonitor server login" -UserName "admin"
            $loginBody = @{ username = $cred.UserName; password = $cred.GetNetworkCredential().Password } | ConvertTo-Json
            $loginRes = Invoke-RestMethod -Uri "$NasUrl/api/login" -Method Post -Body $loginBody -ContentType 'application/json'
            $ApiToken = $loginRes.token
        }

        # Step 4: Upload firmware.bin to NAS
        Write-Host "==> Uploading firmware.bin to NAS ($NasUrl)..." -ForegroundColor Cyan
        $headers = @{ Authorization = "Bearer $ApiToken" }
        $form = @{ firmware = Get-Item $fwPath }
        Invoke-RestMethod -Uri "$NasUrl/api/devices/$Mac/ota/upload" `
            -Method Post -Headers $headers -Form $form | Out-Null
        Write-Host "==> Firmware uploaded to NAS." -ForegroundColor Green

        # Step 5: Trigger OTA on device
        Write-Host "==> Triggering OTA on device $Mac..." -ForegroundColor Cyan
        $triggerBody = @{ mac = $Mac } | ConvertTo-Json
        $result = Invoke-RestMethod -Uri "$NasUrl/api/devices/$Mac/ota/trigger" `
            -Method Post -Headers $headers -Body $triggerBody -ContentType 'application/json'
        Write-Host "==> OTA triggered. Device will reboot after flashing." -ForegroundColor Green
        Write-Host "    Response: $($result | ConvertTo-Json -Compress)" -ForegroundColor DarkGray
    } else {
        # Build only
        & $pio run --environment nebulas3
        if ($LASTEXITCODE -ne 0) { throw "PlatformIO build failed" }

        $fw = Get-ChildItem ".pio\build\nebulas3\firmware.bin" -ErrorAction SilentlyContinue
        if ($fw) {
            Write-Host "==> Built: $($fw.FullName)  ($([math]::Round($fw.Length/1KB, 1)) KB)" -ForegroundColor Green
            Write-Host "    To deploy: .\build_controller.ps1 -Upload -Mac AA:BB:CC:DD:EE:FF" -ForegroundColor DarkGray
        } else {
            Write-Host "==> Build complete." -ForegroundColor Green
        }
    }
} finally {
    Pop-Location
}
