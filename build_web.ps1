# build_web.ps1 — Build & deploy web backend Docker image to NAS
# Usage: .\build_web.ps1 [-Version <tag>] [-NasHost <host>] [-NasUser <user>]
param(
    [string]$Version = "2.0.3",
    [string]$NasHost = "192.168.0.102",
    [string]$NasUser = "nperiannan",
    [string]$NasRepoPath = "/Volume1/docker/TankMonitor",
    [string]$AuthSecret = "1ee5cd0b3032e3d2d3613d23aa6b33d08890337cd7df504a9393dfa4f3e42a45"
)

$ErrorActionPreference = 'Stop'
$ImageTag = "tankmonitor-web:$Version"

Write-Host "==> Pushing latest code to GitHub..." -ForegroundColor Cyan
Push-Location $PSScriptRoot
git push origin HEAD
Pop-Location

Write-Host ""
Write-Host "==> Deploying $ImageTag to NAS ($NasUser@$NasHost)..." -ForegroundColor Cyan
Write-Host "    You will be prompted for the NAS SSH password." -ForegroundColor Yellow
Write-Host ""

$remote = @"
source ~/.bashrc && conda activate base
cd $NasRepoPath
git pull origin \$(git rev-parse --abbrev-ref HEAD)
docker build -t $ImageTag web/ && \
docker stop tankmonitor-web 2>/dev/null || true
docker rm   tankmonitor-web 2>/dev/null || true
docker run -d --name tankmonitor-web --restart unless-stopped \
  -p 1880:8080 \
  -v /Volume1/docker/tankmonitor-data:/data \
  -e MQTT_BROKER=$NasHost \
  -e MQTT_USER=tankmonitor \
  -e MQTT_PASS='Tank32!' \
  -e AUTH_USER=admin \
  -e AUTH_PASS='Tank32!' \
  -e AUTH_SECRET='$AuthSecret' \
  -e OTA_BASE_URL=http://nperiannan-nas.freemyip.com:1880 \
  $ImageTag
docker logs tankmonitor-web --tail 5
"@

ssh "$NasUser@$NasHost" $remote
