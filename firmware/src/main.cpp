#include <Arduino.h>
#include <Wire.h>
#include <WiFi.h>
#include <Preferences.h>

#include "Config.h"
#include "Globals.h"
#include "Logger.h"
#include "RTCManager.h"
#include "WiFiManager.h"
#include "Buzzer.h"
#include "Display.h"
#include "Sensors.h"
#include "LoRaManager.h"
#include "MotorControl.h"
#include "BLEManager.h"
#include "HttpServer.h"
#include "Scheduler.h"
#include "History.h"
#include "TouchSwitch.h"
#include "MQTTManager.h"

// =============================================================================
//                              GLOBAL STATE DEFINITIONS
// =============================================================================

TankState      ugTankState           = TANK_STATE_UNKNOWN;  // display ? until sensor confirms; motor won't fire (hardware OFF + grace period)
TankState      ohTankState           = TANK_STATE_UNKNOWN;

bool           ohMotorRunning        = false;
bool           ugMotorRunning        = false;

bool           loraOperational       = false;
unsigned long  lastLoraReceivedTime  = 0;

bool           isAPMode              = false;
String         wifiSSID              = "";
int            wifiRSSI              = 0;

bool           ohDisplayOnly         = false;
bool           ugDisplayOnly         = false;
bool           ugIgnoreForOH         = false;
bool           buzzerDelayEnabled    = true;
uint8_t        lcdBacklightMode      = LCD_BL_AUTO;

Preferences    preferences;

// =============================================================================
//                              SETUP
// =============================================================================

void setup() {
    Serial.begin(115200);

    // --- CRITICAL: force relay pins OFF immediately before any other init ---
    // Prevents relay from energising during ESP32 GPIO floating at boot.
    // Must be the very first hardware action.
    pinMode(OH_RELAY_PIN, OUTPUT);
    digitalWrite(OH_RELAY_PIN, RELAY_OFF);
    pinMode(UG_RELAY_PIN, OUTPUT);
    digitalWrite(UG_RELAY_PIN, RELAY_OFF);

    // I2C bus
    Wire.begin(SDA_PIN, SCL_PIN);

    // Debug LED
    pinMode(DEBUG_LED, OUTPUT);
    digitalWrite(DEBUG_LED, LOW);

    Log(INFO, "=== Tank Monitor Float v" FW_VERSION " ===");

    initRTC();
    initBuzzer();
    initDisplay();

    // Load persisted configuration before any motor or sensor logic
    loadMotorConfig();

    initSensorPins();
    initMotorPins();

    // LoRa for OH tank remote node
    initLoRa();

    // EEPROM history (after Wire and RTC are ready)
    initHistory();

    // TTP223 capacitive touch switches
    initTouchSwitches();

    // WiFi (STA + AP fallback) + NTP + OTA
    initWiFi();

    // Web server
    setupWebServer();

    // Scheduler
    initScheduler();

    // MQTT remote monitoring
    initMQTT();

    Log(INFO, "=== System Ready ===");
}

// =============================================================================
//                              LOOP
// =============================================================================

void loop() {
    // --- Non-blocking WiFi/OTA maintenance ---
    checkWiFiConnection();

    // --- RTC periodic sync ---
    checkAndSyncRTC();

    // --- LoRa: receive OH tank float state ---
    pollLoRa();

    // --- UG tank: poll float switch ---
    static unsigned long lastUGRead = 0;
    if (millis() - lastUGRead >= UG_SENSOR_POLL_MS) {
        lastUGRead = millis();
        readUGFloatSwitch();
    }

    // --- Touch switch polling ---
    pollTouchSwitches();

    // --- Motor auto-control ---
    autoControlOHMotor();
    autoControlUGMotor();
    processPendingMotorStarts();

    // --- Buzzer pattern update ---
    updateBuzzer();

    // --- LCD display rotation ---
    updateDisplay();

    // --- Scheduler ---
    checkSchedules();

    // --- MQTT ---
    mqttLoop();

    // --- Web server ---
    handleWebClients();

    // --- NTP resync hourly ---
    static unsigned long lastNtp = 0;
    if (!isAPMode && WiFi.status() == WL_CONNECTED &&
        (millis() - lastNtp >= NTP_SYNC_INTERVAL_MS || lastNtp == 0)) {
        lastNtp = millis();
        synchronizeTime();
    }
}
