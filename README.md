# TankMonitor

Monorepo for the TankMonitor system — ESP32 firmware, Go+React web app, and Flutter mobile app.

## Structure

| Folder | Description |
|--------|-------------|
| `firmware/` | ESP32-S3 firmware (PlatformIO + Arduino) |
| `web/` | Go backend + React/Ant Design frontend, Docker-deployed |
| `app/` | Flutter Android mobile app |

## Hardware

- **Controller**: ESP32-S3 Nebula S3
- **Sensors**: Float switches (OH + UG tanks)
- **Display**: I2C LCD 16×2 at 0x27
- **RTC**: DS3231, EEPROM: AT24C512
- **LoRa**: RFM95 (communicates with OH tank Atmega328 controller)
- **Relays**: OH motor (GPIO 1), UG motor (GPIO 2), Buzzer (GPIO 3)

## Quick Start

### Firmware
```bash
cd firmware
pio run -e nebulas3_serial -t upload
```

### Web App (Docker)
```bash
cd web
docker build -t tankmonitor-web .
docker run -d -p 1880:8080 -e MQTT_BROKER=<ip> tankmonitor-web
```

### Mobile App
```bash
cd app
flutter build apk --release
```

## Versions

| Component | Latest |
|-----------|--------|
| Firmware  | v1.3.0 |
| Web App   | v1.3.1 |
| Mobile App | v1.4.0 |

## LCD Backlight Modes

| Mode | Behaviour |
|------|-----------|
| Auto | Off 7:00 AM – 5:30 PM (daytime), On at night |
| On   | Always on |
| Off  | Always off |
