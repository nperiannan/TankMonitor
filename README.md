# TankMonitor

Monorepo for the TankMonitor system — ESP32-S3 firmware, Go+React web app, and Flutter mobile app.

## Repository Structure

```
TankMonitor/
├── firmware/   ESP32-S3 firmware (PlatformIO + Arduino framework)
├── web/        Go backend + React/Ant Design frontend (Docker-deployed on TNAS)
└── app/        Flutter Android mobile app
```

## Versions

| Component   | Latest |
|-------------|--------|
| Firmware    | v1.3.2 |
| Web App     | v1.3.3 |
| Mobile App  | v1.4.1 |

---

## Hardware

| Component | Details |
|-----------|---------|
| Controller | ESP32-S3 Nebula S3 |
| OH Relay | GPIO 1 (RLY1 — Overhead tank motor) |
| UG Relay | GPIO 2 (RLY2 — Underground tank motor) |
| Buzzer | GPIO 3 |
| UG Float Switch | GPIO 42 (INPUT_PULLUP, HIGH=FULL) |
| Touch Switch OH | GPIO 41 |
| Touch Switch UG | GPIO 40 |
| I2C LCD | 16×2 at address 0x27 (SDA=18, SCL=17) |
| RTC | DS3231 |
| EEPROM | AT24C512 (I2C 0x50) |
| LoRa | RFM95 on HSPI (CS=10, IRQ=14, RST=21) — 865 MHz |
| OH Tank node | ATmega328 + LoRa, float switch (replaces HC-SR04T ultrasonic) |

---

## Credentials & Access

### ESP32 Wi-Fi Access Point (AP mode)

When no home Wi-Fi is configured, or while the device is booting, the ESP32
broadcasts its own AP for initial setup.

| Parameter | Value |
|-----------|-------|
| SSID | `TankMonitor` |
| Password | *(see private config)* |
| IP address | `192.168.4.1` |
| Config page | http://192.168.4.1 |

> **Initial Wi-Fi setup**: Connect your phone/laptop to the `TankMonitor` AP,
> open http://192.168.4.1 in a browser, and add your home Wi-Fi SSID/password.
> The device will reboot and connect to your home network.

---

### MQTT Broker (Mosquitto on TNAS)

| Parameter | Value |
|-----------|-------|
| LAN host | `192.168.0.102` |
| Public domain | `nperiannan-nas.freemyip.com` |
| Port | `1883` (plain) |
| Username | `tankmonitor` |
| Password | *(see private config)* |
| Status topic | `tankmonitor/home/status` |
| Control topic | `tankmonitor/home/control` |
| Logs topic | `tankmonitor/home/logs` |

---

### Web App

| Parameter | Value |
|-----------|-------|
| LAN URL | http://192.168.0.102:1880 |
| Public URL | http://nperiannan-nas.freemyip.com:1880 |
| Username | `admin` |
| Password | *(see private config)* |

---

### Mobile App

Install the latest APK from the [GitHub Releases](https://github.com/nperiannan/TankMonitor/releases/latest).

On first launch:
1. Enter the server URL: `http://nperiannan-nas.freemyip.com:1880`
2. Username: `admin`
3. Password: *(see private config)*

---

## Deployment — TNAS (TerraMaster NAS)

### Where it runs

| Service | Host | Container name |
|---------|------|----------------|
| Web App | `192.168.0.102:1880` → container port 8080 | `tankmonitor-web` |
| MQTT Broker | `192.168.0.102:1883` | `mosquitto` |

SSH access: `nperiannan@192.168.0.102` (password: see private config)

### Port Forwarding (Router)

Configure these rules on your home router (ER605 or similar):

| External Port | Internal IP | Internal Port | Protocol | Service |
|---------------|-------------|---------------|----------|---------|
| 1880 | 192.168.0.102 | 1880 | TCP | Web App |
| 1883 | 192.168.0.102 | 1883 | TCP | MQTT |

> **Note**: Hairpin NAT is not supported on ER605. On the local network always
> use `192.168.0.102` directly, not the public domain name.

### First-time NAS git setup (sparse checkout — `web/` only)

Run once on the NAS (via SSH or plink) to clone only the `web/` folder:

```bash
GIT=/home/nperiannan/miniconda3/bin/git

# Remove old manually-copied directory if it exists
rm -rf /Volume1/docker/TankMonitor

# Sparse clone — fetches objects only for web/
$GIT clone --no-checkout --filter=blob:none \
  https://github.com/nperiannan/TankMonitor.git \
  /Volume1/docker/TankMonitor

cd /Volume1/docker/TankMonitor
$GIT sparse-checkout init --cone
$GIT sparse-checkout set web
$GIT checkout master
```

After this the layout is `/Volume1/docker/TankMonitor/web/{Dockerfile,backend/,frontend/}`.
Future `git pull` calls from that directory automatically download only `web/` changes.

---

### Deploy / Update the Web App

Connect to TNAS via SSH, then:

```bash
# Pull latest web/ changes from GitHub
cd /Volume1/docker/TankMonitor
/home/nperiannan/miniconda3/bin/git pull

# Rebuild the Docker image (build context is web/ subfolder)
/Volume1/@apps/DockerEngine/dockerd/bin/docker build -t tankmonitor-web web/

# Stop and remove old container
/Volume1/@apps/DockerEngine/dockerd/bin/docker stop tankmonitor-web
/Volume1/@apps/DockerEngine/dockerd/bin/docker rm tankmonitor-web

# Start fresh container
/Volume1/@apps/DockerEngine/dockerd/bin/docker run -d \
  --name tankmonitor-web \
  --restart unless-stopped \
  -p 1880:8080 \
  -e MQTT_BROKER=192.168.0.102 \
  -e MQTT_PORT=1883 \
  -e MQTT_USER=tankmonitor \
  -e 'MQTT_PASS=<mqtt-password>' \
  -e MQTT_LOCATION=home \
  -e AUTH_USER=admin \
  -e 'AUTH_PASS=<web-password>' \
  -e 'AUTH_SECRET=<secret>' \
  -e OTA_BASE_URL=http://nperiannan-nas.freemyip.com:1880 \
  tankmonitor-web
```

### One-liner from Windows (via plink)

```powershell
$plink = "C:\Program Files (x86)\PuTTY\plink.exe"
$hk    = "ssh-ed25519 255 SHA256:VQhSnjH1mz/ZpLv5lwBKsZqUEoVemScYgTMBBFNQXsw"
$pw    = "<tnas-ssh-password>"
$docker = "/Volume1/@apps/DockerEngine/dockerd/bin/docker"

& $plink -ssh -pw $pw -hostkey $hk nperiannan@192.168.0.102 `
  "cd /Volume1/docker/TankMonitor && /home/nperiannan/miniconda3/bin/git pull && $docker build -t tankmonitor-web web/ && $docker stop tankmonitor-web && $docker rm tankmonitor-web && $docker run -d --name tankmonitor-web --restart unless-stopped -p 1880:8080 -e MQTT_BROKER=192.168.0.102 -e MQTT_PORT=1883 -e MQTT_USER=tankmonitor -e 'MQTT_PASS=<mqtt-password>' -e MQTT_LOCATION=home -e AUTH_USER=admin -e 'AUTH_PASS=<web-password>' -e 'AUTH_SECRET=<secret>' -e OTA_BASE_URL=http://nperiannan-nas.freemyip.com:1880 tankmonitor-web && echo DONE"
```

### Check container logs

```bash
/Volume1/@apps/DockerEngine/dockerd/bin/docker logs --tail 50 tankmonitor-web
```

---

## Firmware — Flash / OTA

### Serial flash (USB, first-time or recovery)

```bash
cd firmware
pio run -e nebulas3_serial -t upload   # COM7 on Windows
```

### OTA via Web App

1. Build firmware locally:
   ```bash
   cd firmware
   pio run -e nebulas3_serial
   # Binary at: .pio/build/nebulas3_serial/firmware.bin
   ```
2. Open http://192.168.0.102:1880, log in.
3. Go to **Firmware Update (OTA)** → click **Upload firmware.bin** → select the `.bin` file.
4. Click **Flash to ESP32** → confirm.
5. The button shows `Triggering… → Downloading… → success` as the device flashes and reboots.

---

## Mobile App — Build & Release

```bash
cd app
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

Create a GitHub release with the APK attached:

```bash
gh release create vX.Y.Z \
  --repo nperiannan/TankMonitor \
  --title "vX.Y.Z - <description>" \
  --notes "Release notes" \
  app-release.apk
```

---

## LCD Backlight Modes

| Mode | Behaviour |
|------|-----------|
| Auto | Off 7:00 AM – 5:30 PM (daytime), On at night |
| On   | Always on |
| Off  | Always off |

Configurable from the web app (Settings card) or mobile app (Settings section).

---

## Development Workflow (monorepo)

```bash
# Clone
git clone https://github.com/nperiannan/TankMonitor.git
cd TankMonitor

# Work on firmware
cd firmware && pio run ...

# Work on web app
cd web/frontend && npm run dev     # dev server
cd web && docker build ...         # production

# Work on mobile app
cd app && flutter run              # debug on device
cd app && flutter build apk ...    # release APK
```

### Commit & push

```bash
git add -A
git commit -m "component: description"
git push origin master
```

### Sync a subfolder from its old repo (one-off)

```bash
git subtree pull --prefix=firmware https://github.com/nperiannan/Tank-Monitor-Float.git master
git subtree pull --prefix=web      https://github.com/nperiannan/TankMonitor-Web.git master
git subtree pull --prefix=app      https://github.com/nperiannan/TankMonitor-App.git master
```
