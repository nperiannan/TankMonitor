# Changelog

All notable changes to the Tank Monitor ESP32-S3 firmware are documented here.

---

## [2.6.0] — 2026-07-16

### Added
- **Motor-change reason in MQTT status** — the status payload now includes `oh_rsn` / `ug_rsn` (the `HistReason` code of the most recent OH/UG relay change: Auto level, Manual app/web/touch, Scheduled, Tank full, Max runtime, LoRa lost, Power cut/restore). The cloud backend uses these to label derived history events accurately instead of guessing "Manual" vs "Auto/Scheduled" from timing.

---

## [2.5.0] — 2026-07-20

### Added
- **Buzzer countdown in MQTT status** — the status payload now includes `oh_cd` / `ug_cd` (buzzer-delay seconds remaining, `0` when idle). Lets the mobile app render an accurate shrinking "starting in Ns" progress bar during the pre-start buzzer, and confirms the controller acknowledged a motor command.

---

## [2.4.0] — 2026-07-13

### Added
- **v2.0 PCB support (`BOARD_V2`)** — build-time board select via PlatformIO envs `nebulas3_v2` / `nebulas3_v2_serial` (or `#define BOARD_V2`). v2.0 pin map: I2C SDA=8/SCL=9, LoRa DIO1 not wired (`RADIOLIB_NC`), touch buttons GPIO17/18, UG float GPIO47. v1.x pins are unchanged when the guard is off.
- **LCD I2C auto-detect** — scans the bus at boot and rebuilds the LCD object with the found address (handles 0x27 vs 0x3F backpacks); logs all I2C devices found.
- **Event-history reasons** — every motor ON/OFF now records *why* (Auto/level, Manual app/web/touch, Scheduled, Tank-full, Max runtime, LoRa lost, Power cut, Power restore) plus a boot reason (power-on/OTA/brownout). Packed into the record's spare flags nibble — no EEPROM migration.
- **Power-cut inference** — on boot, if a power reset occurred while a motor was intended ON, a synthetic OFF is logged, backdated to the last heartbeat (persisted only while pumping).
- **About / Device Info** on the ESP32 web UI — controller & transmitter FW, LCD/EEPROM/RTC I2C addresses, and RAM/flash usage.
- **Run-pairing** in the web Event History — motor ON→OFF merged into one row with duration and start/stop reasons.
- **LCD motor-start countdown** — a priority screen with a shrinking bar shows the pending motor and seconds remaining during the buzzer delay.

### Fixed
- **Web UI unreachable once the RFM95 was fitted** — `pollLoRa()` used a blocking `radio.receive()` (~410 ms/iteration) that starved the synchronous web server. Switched to interrupt-driven RX (`setPacketReceivedAction` + `readData`) so the loop stays responsive.
- **Buzzer silenced when cancelling one of two pending motors** — the pre-start buzzer now only stops when no motor is still counting down.
- **Push-button couldn't cancel during the countdown** — a second tap while pending now cancels the start (stops buzzer, no motor, no phantom OFF record).

---

## [2.2.0] — 2026-06-10

### Fixed
- **MQTT status payload missing RF fields** — Added `loraRSSI`, `loraSNR`, and `lastLoraReceived` to the MQTT status JSON payload. Previously these fields were only available via the HTTP API, causing the mobile app (which uses WebSocket/MQTT) to show 0 for all RF signal data.

---

## [1.3.6] — 2026-04-24

### Added
- **`buzzer_active` in MQTT and HTTP status** — Boolean field indicating whether the buzzer is currently sounding. Consumed by mobile app to show an animated buzzer icon.

---

## [1.3.5] — 2026-04-24

### Changed
- **Log timestamp** — Replaced raw milliseconds (`[3219719]`) with human-readable `[HH:MM:SS]` format. Wall-clock time is used when NTP is synced; uptime `[+HH:MM:SS]` is shown before first sync.

---

## [1.3.4] — 2026-04-24

### Added
- **Configurable log level** — Log level can be set to `Info` (Info + Warn + Error, default) or `Debug` (all messages). Configurable from the ESP32 built-in web page (Logs card), mobile app (System tab), and web app. Setting is applied instantly via HTTP POST `/setloglevel` or MQTT `set_log_level` command.
- **`log_level` in MQTT status** — Every status publish now includes the current log level so all clients can reflect it.

### Changed
- **MQTT status publish log** — The periodic `[MQTT] Published status` message is now a `DEBUG`-level log (suppressed in `Info` mode) to reduce noise.

---

## [1.3.3] — 2026-04-24

### Fixed
- **LCD splash screen** — Startup message now shows the actual firmware version (`FW: 1.3.3`) instead of hardcoded `Float v1.0`.

---

## [1.3.2] — 2026-04-24

### Added
- **LCD backlight mode selector** — Web UI setting to choose `Auto`, `Always On`, or `Always Off`. Persisted in NVS, applied immediately.
- **MQTT password change from web UI** — Settings card with password input and confirm dialog. Sends `set_mqtt_creds` command over MQTT to update NVS credentials on the ESP32 — no reflash needed.

### Removed
- **BLE (Bluetooth Low Energy) toggle removed from web UI** — BLE was already removed from firmware in v1.1.0; the toggle in the settings page has now been removed to match.

---

## [1.1.0] — 2026-04-19

### Fixed
- **ESP32-S3 crash/reboot loop** — BLE library registered with the WiFi coexistence module even without calling `BLEManager::begin()`, causing an abort when `WiFi.mode(WIFI_AP_STA)` was set with `PS_NONE`. Fixed by excluding `BLEManager.cpp` from the build via `build_src_filter`.
- **MQTT callback stack overflow** — `onMessage()` was directly invoking NTP sync, BLE send and `ESP.restart()` from within the PubSubClient callback (small stack). Fixed by queuing the raw payload and processing it from the main loop via `processPendingMQTT()`.
- **Adding a new WiFi SSID disconnected the active connection** — `handleAddNetwork()` called `WiFi.disconnect()` unconditionally. Fixed to skip disconnect if the device is already connected.
- **MQTT broker hardcoded to LAN IP** — Broker was hardcoded to `192.168.0.102` and overwritten in NVS on every boot. Fixed by using `nperiannan-nas.freemyip.com` as default and adding NVS migration (`seedDefaultsIfEmpty`) that rewrites the old IP only once.
- **AP mode unstable during STA reconnect** — `WiFi.scanNetworks(false)` (blocking scan, ~3 s) was disrupting AP beaconing, causing clients to drop. Changed to `WiFi.scanNetworks(true)` (async) with polling via `WiFi.scanComplete()` so the AP stays fully alive during scanning.

### Added
- **WiFi state machine** — Priority-ordered STA reconnection with 3 attempts per SSID (10 s timeout each) and 15-minute cooldown after all SSIDs fail. State tracked via `smTryIdx`, `smTryAttempts`, `smInCooldown`, `smCooldownUntilMs`.
- **WiFi scan diagnostic logging** — Before each reconnect round the firmware logs all visible SSIDs with channel and RSSI.
- **India WiFi country code** — `esp_wifi_set_country_code("IN", true)` enables channels 1–13, preventing some APs from being missed.
- **WiFi scan-to-add UI** — "Scan" button in the web UI calls `/wifiscan` REST endpoint, shows a dropdown sorted by RSSI with signal-strength bars, lock icon and channel/RSSI info. Clicking a network pre-fills the SSID field.
- **MQTT NVS migration** — `seedDefaultsIfEmpty()` migrates devices that still have the old hardcoded LAN IP stored in NVS to the new domain name without requiring a full factory reset.
- **NVS epoch persistence** — Current time is written to NVS every 5 minutes so the clock survives a power cut even if the DS3231 backup battery is dead.

### Removed
- **BLE (Bluetooth Low Energy) completely removed** — `BLEManager.cpp` and all references removed from `main.cpp`, `MQTTManager.cpp`, `HttpServer.cpp` and the web UI. The `handleSetBleEnabled()` HTTP handler is stubbed to return OK for backward compatibility.

### Changed
- **MQTT default broker** — Changed from `192.168.0.102` to `nperiannan-nas.freemyip.com` in `Config.h`.
- **WiFi add-network toast** — Changed from "Network added – connecting..." to "Network saved" since the connection attempt is no longer immediate.
- **WiFi remove-network** — `handleRemoveNetwork()` now only disconnects if the removed SSID is the currently connected SSID.

### Infrastructure
- Port forwarding configured through double NAT (Syrotech BSNL ONT → TP-Link ER605):
  - TCP 1883 → NAS Mosquitto (MQTT, externally reachable)
  - TCP 1880 → NAS Web App (dashboard, externally reachable)
- External URL: `http://nperiannan-nas.freemyip.com:1880` (web UI), `nperiannan-nas.freemyip.com:1883` (MQTT)

---

## [1.0.0] — Initial Release

- Dual-tank monitoring via float switches and LoRa (RFM95)
- Motor relay control with safety interlocks
- WiFi AP+STA, web UI, MQTT, NTP, OTA, DS3231 RTC, LCD, Buzzer, History log
