# Tank Monitor — Web App

Go backend + React/Ant Design frontend, deployed as a Docker container on TerraMaster NAS.

- **Backend version**: 2.1.0
- **Frontend version**: 2.1.0
- **Docker image**: `tankmonitor-web:2.1.0`

## Features

### Backend (Go)

- **Auth** — JWT-based login/register with SQLite user store
- **MQTT bridge** — Connects to Mosquitto broker, relays status → WebSocket and control commands → MQTT
- **WebSocket** — Real-time push of device status to connected web/mobile clients
- **Device registry** — Claim/unclaim devices by MAC address, per-user device list
- **OTA firmware staging** — Upload `.bin`, serve to ESP32 via `GET /api/ota/check/{mac}`
- **Version endpoint** — `GET /api/version` returns `{"web_version":"2.1.0"}`
- **Transparent pass-through** — No field parsing; forwards MQTT JSON payloads as-is to clients

### Frontend (React SPA)

- **Tank status** — Animated arc gauges for OH and UG tanks (FULL / HALF / LOW / EMPTY / UNKNOWN)
- **Motor control** — ON/OFF buttons with status pills and buzzer indicator
- **Transmitter lost warning** — Banner when no LoRa signal for 90+ seconds, shows last known OH state
- **Motor scheduler** — Add/edit/delete timed schedules per motor
- **Settings** — Display-only mode, motor start/stop level thresholds, max runtime, LCD backlight, MQTT password
- **OTA firmware update** — Upload `.bin` with progress bar, flash with phase tracking and 150s countdown
- **Firmware rollback** — Revert to previous OTA partition
- **Device logs** — Fetch and display logs with level filter and clipboard copy
- **System info** — WiFi RSSI, LoRa status, TX status, uptime, firmware versions
- **Dark/light theme** — Toggle with localStorage persistence
- **Auth** — Login/logout with JWT token

## Project Structure

```text
web/
├── backend/
│   └── main.go           # Go server (auth, MQTT bridge, WebSocket, OTA, REST API)
├── frontend/
│   ├── src/
│   │   ├── App.tsx        # Main React SPA (all UI in single file)
│   │   └── types.ts       # TypeScript interfaces (Status, ControlCmd, OtaStatus)
│   ├── package.json
│   └── vite.config.ts
├── Dockerfile             # Multi-stage: Node build → Go build → scratch
├── build_web.sh           # Build + deploy script for TNAS
├── build.ps1              # Windows build script
└── .dockerignore
```

## API Endpoints

| Method | Path | Description |
| --- | --- | --- |
| POST | `/api/auth/register` | Create account |
| POST | `/api/auth/login` | Login, returns JWT |
| GET | `/api/version` | Web app version |
| GET | `/api/devices` | List user's claimed devices |
| POST | `/api/devices/claim` | Claim device by MAC |
| GET | `/api/ota/check/{mac}` | ESP32 polls for staged firmware |
| POST | `/api/ota/upload` | Upload firmware `.bin` |
| WS | `/ws` | WebSocket for real-time status/control |

## Build & Deploy

### On TNAS (primary, via SSH)

```bash
cd /Volume1/docker/TankMonitor/web
bash build_web.sh
```

The script pulls latest code, builds the Docker image, stops the old container, and starts a new one with all required environment variables.

### On OrangePi (backup host @ 192.168.0.105, via SSH)

```bash
ssh root@192.168.0.105
bash /opt/TankMonitor/web/deploy_orangepi.sh
```

The script pulls latest code, builds the image, sets up Mosquitto (with password auth) and the web app on a `tankmonitor` Docker network. Both containers restart automatically on boot.

> **Note:** The OrangePi runs its own independent Mosquitto broker on port 1883. ESP32 devices must point to `192.168.0.105:1883` to use the backup stack.

### Local development

```bash
# Frontend
cd frontend && npm install && npm run dev

# Backend
cd backend && go run main.go
```

## Environment Variables

| Variable | Description | Default |
| --- | --- | --- |
| `MQTT_BROKER` | Mosquitto broker address | `192.168.0.102` |
| `MQTT_PORT` | Broker port | `1883` |
| `MQTT_USER` | MQTT username | `tankmonitor` |
| `MQTT_PASS` | MQTT password | — |
| `JWT_SECRET` | JWT signing key | — |
| `PORT` | HTTP server port | `8080` |

## Access

| | URL |
| --- | --- |
| TNAS (primary) | <http://192.168.0.102:1880> |
| OrangePi (backup, MR200 network) | <http://192.168.1.50:1880> |
| Public | <http://nperiannan-nas.freemyip.com:1880> |
