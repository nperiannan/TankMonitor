# TankMonitor

Monorepo for the TankMonitor system — ESP32-S3 firmware, Go+React web app, and Flutter mobile app.

## Repository Structure

```
TankMonitor/
├── controller_firmware/   ESP32-S3 firmware (PlatformIO + Arduino framework)
├── web/                   Go backend + React/Ant Design frontend (Docker-deployed on TNAS)
└── app/                   Flutter Android mobile app
```

## Versions

| Component | Latest |
|-----------|--------|
| Controller Firmware | v1.5.1 |
| Web App | v2.0.7 |
| Mobile App | v1.5.9 |

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

Run once on the NAS (via SSH or TNAS terminal) to clone only the `web/` folder:

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

After this the layout is `/Volume1/docker/TankMonitor/web/{Dockerfile,backend/,frontend/,build_web.sh}`.
Future updates via `git pull` will download only `web/` changes.

---

### Deploy / Update the Web App

A build script is included at `web/build_web.sh`. Copy it to the NAS once,
then run it for every update:

```bash
cd /Volume1/docker/TankMonitor/web
bash build_web.sh
```

The script:
1. `source ~/.bashrc` + `conda activate base` (sets up environment)
2. `git -C .. pull origin master` (pulls latest `web/` changes)
3. `docker build -t tankmonitor-web:2.0.3 .`
4. Stops/removes old container and starts a fresh one with all required env vars

### Check container logs

```bash
docker logs --tail 50 tankmonitor-web
```

---

## Firmware — Flash / OTA

### Serial flash (USB, first-time or recovery)

```bash
cd controller_firmware
pio run -e nebulas3_serial -t upload   # COM7 on Windows
```

### OTA via build script (recommended)

From the repo root on Windows:

```powershell
# Build + upload + trigger OTA in one step
.\build_controller.ps1 -Upload -Mac 'AA:BB:CC:DD:EE:FF'
```

The script builds with PlatformIO (`nebulas3` env), uploads `firmware.bin` to the NAS,
then triggers OTA via MQTT. The device downloads and flashes automatically.

### OTA via Mobile App

1. Open the app → go to **Settings tab** → **FIRMWARE UPDATE (OTA)**.
2. **Step 1**: tap **Choose firmware.bin** → pick the `.bin` file from your phone.
   An upload progress bar is shown; once complete the file size and upload time appear.
3. **Step 2**: tap **Flash Firmware** → confirm.
4. A 150-second countdown progress bar tracks the update:
   - `triggered` → `ack_received` (ESP32 confirmed) → `downloading` (flashing) → `success`
5. On success the device reboots into the new firmware.

### OTA via Web App

1. Open http://192.168.0.102:1880, log in.
2. Go to **Firmware Update (OTA)** → click **Upload firmware.bin** → select the `.bin` file.
3. Click **Flash to ESP32** → confirm.
4. A 150-second progress bar tracks the update phases until `success`.

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
 cd controller_firmware && pio run ...
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
git subtree pull --prefix=controller_firmware https://github.com/nperiannan/Tank-Monitor-Float.git master
git subtree pull --prefix=web      https://github.com/nperiannan/TankMonitor-Web.git master
git subtree pull --prefix=app      https://github.com/nperiannan/TankMonitor-App.git master
```
