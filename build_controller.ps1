# build_controller.ps1 — Build & upload controller firmware via OTA (PlatformIO)
# Usage: .\build_controller.ps1 [-Upload] [-Monitor]
param(
    [switch]$Upload,   # Upload via OTA after build
    [switch]$Monitor   # Open serial monitor after upload
)

$ErrorActionPreference = 'Stop'
$FwDir = "$PSScriptRoot\controller_firmware"

Write-Host "==> Building controller firmware..." -ForegroundColor Cyan
Push-Location $FwDir
try {
    if ($Upload) {
        Write-Host "==> Building + uploading via OTA..." -ForegroundColor Cyan
        pio run --target upload
        if ($LASTEXITCODE -ne 0) { throw "PlatformIO upload failed" }
        Write-Host "==> Upload complete." -ForegroundColor Green

        if ($Monitor) {
            Write-Host "==> Opening serial monitor..." -ForegroundColor Cyan
            pio device monitor
        }
    } else {
        pio run
        if ($LASTEXITCODE -ne 0) { throw "PlatformIO build failed" }

        $fw = Get-ChildItem ".pio\build\nebulas3\firmware.bin" -ErrorAction SilentlyContinue
        if ($fw) {
            Write-Host "==> Built: $($fw.FullName)  ($([math]::Round($fw.Length/1KB, 1)) KB)" -ForegroundColor Green
        } else {
            Write-Host "==> Build complete." -ForegroundColor Green
        }
    }
} finally {
    Pop-Location
}
