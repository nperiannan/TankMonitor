#!/usr/bin/env bash
# build_web.sh — rebuild and redeploy the tankmonitor-web Docker container on the NAS.
# Run from web/: bash build_web.sh
set -e

source ~/.bashrc
conda activate base

# Full path required — docker is not in PATH for non-interactive SSH sessions on TNAS
DOCKER=/Volume1/@apps/DockerEngine/dockerd/bin/docker
GIT=/home/nperiannan/miniconda3/bin/git

cd /Volume1/docker/TankMonitor/web
$GIT -C .. pull origin master

$DOCKER build -t tankmonitor-web:2.0.10 .

$DOCKER stop tankmonitor-web 2>/dev/null || true
$DOCKER rm   tankmonitor-web 2>/dev/null || true

$DOCKER run -d \
  --name tankmonitor-web \
  --restart always \
  -p 1880:8080 \
  -v /Volume1/docker/tankmonitor-data:/data \
  -e MQTT_BROKER=192.168.0.102 \
  -e MQTT_PORT=1883 \
  -e MQTT_USER=tankmonitor \
  -e MQTT_PASS='Tank32!' \
  -e AUTH_USER=admin \
  -e AUTH_PASS='Tank32!' \
  -e AUTH_SECRET='1ee5cd0b3032e3d2d3613d23aa6b33d08890337cd7df504a9393dfa4f3e42a45' \
  -e OTA_BASE_URL=http://nperiannan-nas.freemyip.com:1880 \
  tankmonitor-web:2.0.10

echo "--- Last 10 log lines ---"
$DOCKER logs tankmonitor-web --tail 10
