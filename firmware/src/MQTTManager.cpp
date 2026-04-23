#include <WiFi.h>
#include <PubSubClient.h>
#include <Preferences.h>
#include <esp_system.h>
#include <esp_ota_ops.h>
#include <HTTPClient.h>
#include <Update.h>

#include "MQTTManager.h"
#include "Config.h"
#include "Globals.h"
#include "Logger.h"
#include "MotorControl.h"
#include "Scheduler.h"
#include "RTCManager.h"
#include "WiFiManager.h"
#include "Display.h"
#include <ArduinoJson.h>

// ---------------------------------------------------------------------------
// Static state
// ---------------------------------------------------------------------------
static WiFiClient   s_wifiClient;
static PubSubClient s_mqtt(s_wifiClient);

static char s_broker[64];
static int  s_port;
static char s_user[32];
static char s_pass[64];
static char s_topicStatus[64];
static char s_topicControl[64];
static char s_topicLogs[64];
static char s_clientId[32];

static unsigned long s_lastPublishMs    = 0;
static unsigned long s_lastReconnectMs  = 0;
static unsigned long s_lastLogPublishMs = 0;

// ---------------------------------------------------------------------------
// NVS helpers
// ---------------------------------------------------------------------------
static void loadConfig() {
    Preferences prefs;
    prefs.begin(MQTT_NVS_NS, true);
    String broker   = prefs.getString("broker",   MQTT_BROKER_DEFAULT);
    s_port          = prefs.getInt   ("port",      MQTT_PORT_DEFAULT);
    String user     = prefs.getString("user",      MQTT_USER_DEFAULT);
    String pass     = prefs.getString("pass",      MQTT_PASS_DEFAULT);
    String location = prefs.getString("location",  MQTT_LOCATION_DEFAULT);
    prefs.end();

    strncpy(s_broker, broker.c_str(), sizeof(s_broker) - 1);
    strncpy(s_user,   user.c_str(),   sizeof(s_user)   - 1);
    strncpy(s_pass,   pass.c_str(),   sizeof(s_pass)   - 1);

    snprintf(s_topicStatus,  sizeof(s_topicStatus),  "tankmonitor/%s/status",  location.c_str());
    snprintf(s_topicControl, sizeof(s_topicControl), "tankmonitor/%s/control", location.c_str());
    snprintf(s_topicLogs,    sizeof(s_topicLogs),    "tankmonitor/%s/logs",    location.c_str());
    snprintf(s_clientId,     sizeof(s_clientId),     "esp32_%s",               location.c_str());
}

static void seedDefaultsIfEmpty() {
    Preferences prefs;
    prefs.begin(MQTT_NVS_NS, false);
    // Migrate old LAN IP to freemyip domain if still stored
    if (prefs.getString("broker", "") == "192.168.0.102") {
        prefs.putString("broker", MQTT_BROKER_DEFAULT);
        Log(INFO, "[MQTT] Migrated broker from LAN IP to " MQTT_BROKER_DEFAULT);
    }
    // Seed remaining keys only if not already set
    if (!prefs.isKey("broker"))   prefs.putString("broker",   MQTT_BROKER_DEFAULT);
    if (!prefs.isKey("port"))     prefs.putInt   ("port",     MQTT_PORT_DEFAULT);
    if (!prefs.isKey("user"))     prefs.putString("user",     MQTT_USER_DEFAULT);
    if (!prefs.isKey("pass"))     prefs.putString("pass",     MQTT_PASS_DEFAULT);
    if (!prefs.isKey("location")) prefs.putString("location", MQTT_LOCATION_DEFAULT);
    prefs.end();
    Log(INFO, "[MQTT] Config seeded");
}

// ---------------------------------------------------------------------------
// Forward declarations
static void publishMQTTLogs();

// Pending command queue — executed from loop(), not from callback stack
// ---------------------------------------------------------------------------
struct PendingCmd {
    char msg[128];
    bool active;
};
static PendingCmd s_pending = {"", false};

// ---------------------------------------------------------------------------
// MQTT callback — only copies payload into queue, returns immediately
// ---------------------------------------------------------------------------
static void onMessage(char* topic, byte* payload, unsigned int len) {
    if (len == 0 || len > 127) return;
    if (s_pending.active) return;  // drop if previous not yet consumed
    memcpy(s_pending.msg, payload, len);
    s_pending.msg[len] = '\0';
    s_pending.active   = true;
}

// ---------------------------------------------------------------------------
// Process one queued command — called from mqttLoop() inside loop()
// ---------------------------------------------------------------------------
static void processPendingMQTT() {
    if (!s_pending.active) return;
    char msg[128];
    strncpy(msg, s_pending.msg, sizeof(msg));
    s_pending.active = false;   // mark consumed before processing

    Log(INFO, "[MQTT] Control rx: " + String(msg));

    StaticJsonDocument<512> doc;
    if (deserializeJson(doc, msg) != DeserializationError::Ok) {
        Log(WARN, "[MQTT] Bad JSON: " + String(msg));
        return;
    }
    const char* cmd = doc["cmd"] | "";

    if      (strcmp(cmd, "oh_on")  == 0) { turnOnOHMotor();  }
    else if (strcmp(cmd, "oh_off") == 0) { turnOffOHMotor(); }
    else if (strcmp(cmd, "ug_on")  == 0) { turnOnUGMotor();  }
    else if (strcmp(cmd, "ug_off") == 0) { turnOffUGMotor(); }
    else if (strcmp(cmd, "sched_add") == 0) {
        int slot = -1;
        for (int i = 0; i < MAX_SCHEDULES; i++) {
            if (!schedules[i].enabled) { slot = i; break; }
        }
        if (slot < 0) {
            Log(WARN, "[MQTT] sched_add: no free slots");
        } else {
            schedules[slot].enabled   = true;
            schedules[slot].motorType = (uint8_t)(doc["motor"] | 0);
            schedules[slot].time      = doc["time"]     | "00:00";
            schedules[slot].duration  = (uint16_t)(doc["duration"] | 2);
            schedules[slot].isRunning = false;
            schedules[slot].startTime = 0;
            saveSchedules();
            Log(INFO, "[MQTT] sched_add slot=" + String(slot) + " " + schedules[slot].time);
        }
    }
    else if (strcmp(cmd, "sched_remove") == 0) {
        int idx = doc["index"] | -1;
        if (idx >= 0 && idx < MAX_SCHEDULES) {
            schedules[idx].enabled   = false;
            schedules[idx].isRunning = false;
            schedules[idx].time      = "00:00";
            saveSchedules();
            Log(INFO, "[MQTT] sched_remove index=" + String(idx));
        } else {
            Log(WARN, "[MQTT] sched_remove: bad index");
        }
    }
    else if (strcmp(cmd, "sched_clear") == 0) {
        clearAllSchedules();
        Log(INFO, "[MQTT] sched_clear");
    }
    else if (strcmp(cmd, "set_setting") == 0) {
        const char* key = doc["key"] | "";
        bool val = doc["value"] | false;
        bool changed = true;
        if      (strcmp(key, "oh_disp_only") == 0) ohDisplayOnly      = val;
        else if (strcmp(key, "ug_disp_only") == 0) ugDisplayOnly      = val;
        else if (strcmp(key, "ug_ignore")    == 0) ugIgnoreForOH      = val;
        else if (strcmp(key, "buzzer_delay") == 0) buzzerDelayEnabled = val;
        else changed = false;
        if (changed) { saveMotorConfig(); Log(INFO, "[MQTT] set_setting " + String(key) + "=" + String(val)); }
        else          Log(WARN, "[MQTT] set_setting unknown key: " + String(key));
    }
    else if (strcmp(cmd, "set_lcd_mode") == 0) {
        const char* mode = doc["mode"] | "";
        uint8_t newMode = LCD_BL_AUTO;
        if      (strcmp(mode, "always_on")  == 0) newMode = LCD_BL_ALWAYS_ON;
        else if (strcmp(mode, "always_off") == 0) newMode = LCD_BL_ALWAYS_OFF;
        lcdBacklightMode = newMode;
        saveMotorConfig();
        applyBacklightMode();
        Log(INFO, "[MQTT] set_lcd_mode=" + String(mode));
    }
    else if (strcmp(cmd, "sync_ntp") == 0) {
        synchronizeTime();
        Log(INFO, "[MQTT] sync_ntp triggered");
    }
    else if (strcmp(cmd, "get_logs") == 0) {
        publishMQTTLogs();
        Log(INFO, "[MQTT] get_logs: log snapshot published");
    }
    else if (strcmp(cmd, "ota_start") == 0) {
        const char* url = doc["url"] | "";
        if (strlen(url) == 0) {
            Log(WARN, "[MQTT] ota_start: no url provided");
        } else {
            Log(INFO, "[MQTT] OTA start — URL: " + String(url));
            publishMQTTStatus();

            HTTPClient http;
            http.begin(url);
            http.setTimeout(30000);
            int httpCode = http.GET();
            if (httpCode != HTTP_CODE_OK) {
                Log(WARN, "[MQTT] OTA HTTP error: " + String(httpCode));
                http.end();
            } else {
                int contentLen = http.getSize();
                Log(INFO, "[MQTT] OTA firmware size: " + String(contentLen));

                if (!Update.begin(contentLen > 0 ? contentLen : UPDATE_SIZE_UNKNOWN)) {
                    Log(WARN, "[MQTT] OTA Update.begin failed: " + String(Update.errorString()));
                    http.end();
                } else {
                    WiFiClient* stream = http.getStreamPtr();
                    size_t written = Update.writeStream(*stream);
                    http.end();

                    if (Update.end(true)) {
                        Log(INFO, "[MQTT] OTA success — " + String(written) + " bytes written, rebooting…");
                        publishMQTTStatus();
                        delay(500);
                        esp_restart();
                    } else {
                        Log(WARN, "[MQTT] OTA Update.end failed: " + String(Update.errorString()));
                    }
                }
            }
        }
    }
    else if (strcmp(cmd, "ota_rollback") == 0) {
        Log(INFO, "[MQTT] OTA rollback requested");
        const esp_partition_t* running  = esp_ota_get_running_partition();
        const esp_partition_t* previous = esp_ota_get_next_update_partition(NULL);
        if (previous == NULL || previous == running) {
            Log(WARN, "[MQTT] OTA rollback: no alternate partition found");
        } else {
            esp_err_t err = esp_ota_set_boot_partition(previous);
            if (err == ESP_OK) {
                Log(INFO, "[MQTT] OTA rollback: boot set to previous partition, rebooting…");
                publishMQTTStatus();
                delay(500);
                esp_restart();
            } else {
                Log(WARN, "[MQTT] OTA rollback failed: " + String(esp_err_to_name(err)));
            }
        }
    }
    else if (strcmp(cmd, "reboot") == 0) {
        Log(INFO, "[MQTT] reboot commanded");
        publishMQTTStatus();
        delay(300);
        esp_restart();
    }
    else {
        Log(WARN, "[MQTT] Unknown cmd: " + String(cmd));
    }
}

// ---------------------------------------------------------------------------
// Connection
// ---------------------------------------------------------------------------
static bool mqttConnect() {
    if (WiFi.status() != WL_CONNECTED) return false;

    Log(INFO, "[MQTT] Connecting to " + String(s_broker) + ":" + String(s_port) + " as " + String(s_clientId) + " ...");

    if (s_mqtt.connect(s_clientId, s_user, s_pass)) {
        Log(INFO, "[MQTT] Connected. Subscribing " + String(s_topicControl));
        s_mqtt.subscribe(s_topicControl, 1);
        publishMQTTStatus();
        return true;
    }

    Log(WARN, "[MQTT] Failed, rc=" + String(s_mqtt.state()));
    return false;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------
void initMQTT() {
    seedDefaultsIfEmpty();
    loadConfig();

    s_mqtt.setServer(s_broker, s_port);
    s_mqtt.setCallback(onMessage);
    s_mqtt.setKeepAlive(60);
    s_mqtt.setSocketTimeout(10);
    s_mqtt.setBufferSize(4096);  // large enough for status + log payloads

    Log(INFO, "[MQTT] Init. Broker=" + String(s_broker) + ":" + String(s_port) + " topic=" + String(s_topicStatus));
}

void mqttLoop() {
    if (WiFi.status() != WL_CONNECTED || isAPMode) return;

    if (!s_mqtt.connected()) {
        unsigned long now = millis();
        if (now - s_lastReconnectMs >= MQTT_RECONNECT_MS) {
            s_lastReconnectMs = now;
            mqttConnect();
        }
        return;
    }

    s_mqtt.loop();

    // Process any command queued by the callback (runs on loop() stack, not callback stack)
    processPendingMQTT();

    unsigned long now = millis();
    if (now - s_lastPublishMs >= MQTT_PUBLISH_MS) {
        s_lastPublishMs = now;
        publishMQTTStatus();
    }

    // Publish logs every 60 s (independent of status interval)
    if (now - s_lastLogPublishMs >= 60000UL) {
        s_lastLogPublishMs = now;
        publishMQTTLogs();
    }
}

void publishMQTTStatus() {
    if (!s_mqtt.connected()) return;

    // Current time
    struct tm ti;
    char timeStr[12] = "??:??:??";
    if (getLocalTime(&ti)) {
        snprintf(timeStr, sizeof(timeStr), "%02d:%02d:%02d", ti.tm_hour, ti.tm_min, ti.tm_sec);
    }

    // Build compact schedules JSON array (enabled entries only)
    char schedJson[400] = "[";
    bool firstSched = true;
    for (int i = 0; i < MAX_SCHEDULES; i++) {
        if (!schedules[i].enabled) continue;
        char entry[96];
        snprintf(entry, sizeof(entry), "%s{\"i\":%d,\"m\":\"%s\",\"t\":\"%s\",\"d\":%u,\"on\":%s}",
            firstSched ? "" : ",",
            i,
            schedules[i].motorType == 0 ? "OH" : "UG",
            schedules[i].time.c_str(),
            schedules[i].duration,
            schedules[i].isRunning ? "true" : "false");
        if (strlen(schedJson) + strlen(entry) + 2 < sizeof(schedJson)) {
            strcat(schedJson, entry);
            firstSched = false;
        }
    }
    strcat(schedJson, "]");

    char payload[1152];
    snprintf(payload, sizeof(payload),
        "{\"oh_state\":\"%s\",\"ug_state\":\"%s\","
        "\"oh_motor\":%s,\"ug_motor\":%s,"
        "\"lora_ok\":%s,\"wifi_rssi\":%d,"
        "\"uptime_s\":%lu,\"fw\":\"%s\","
        "\"time\":\"%s\","
        "\"oh_disp_only\":%s,\"ug_disp_only\":%s,"
        "\"ug_ignore\":%s,\"buzzer_delay\":%s,"
        "\"lcd_bl_mode\":%u,"
        "\"schedules\":%s}",
        tankStateStr(ohTankState),
        tankStateStr(ugTankState),
        ohMotorRunning ? "true" : "false",
        ugMotorRunning ? "true" : "false",
        loraOperational ? "true" : "false",
        wifiRSSI,
        millis() / 1000UL,
        FW_VERSION,
        timeStr,
        ohDisplayOnly      ? "true" : "false",
        ugDisplayOnly      ? "true" : "false",
        ugIgnoreForOH      ? "true" : "false",
        buzzerDelayEnabled ? "true" : "false",
        (unsigned)lcdBacklightMode,
        schedJson
    );

    if (s_mqtt.publish(s_topicStatus, payload, true)) {
        Log(INFO, "[MQTT] Published status");
    } else {
        Log(WARN, "[MQTT] Publish failed (buffer too small?)");
    }
}

// Publish the in-memory log ring buffer to the logs topic (last 30 entries)
static void publishMQTTLogs() {
    if (!s_mqtt.connected()) return;
    String logsJson = getLogsJson(30);
    // Wrap in an object so consumers can distinguish from plain arrays
    String payload = "{\"logs\":" + logsJson + "}";
    if (!s_mqtt.publish(s_topicLogs, payload.c_str(), false)) {
        Log(WARN, "[MQTT] Log publish failed");
    }
}
