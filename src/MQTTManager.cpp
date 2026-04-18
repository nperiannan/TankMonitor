#include <WiFi.h>
#include <PubSubClient.h>
#include <Preferences.h>

#include "MQTTManager.h"
#include "Config.h"
#include "Globals.h"
#include "Logger.h"
#include "MotorControl.h"

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
static char s_clientId[32];

static unsigned long s_lastPublishMs   = 0;
static unsigned long s_lastReconnectMs = 0;

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
    snprintf(s_clientId,     sizeof(s_clientId),     "esp32_%s",               location.c_str());
}

static void seedDefaultsIfEmpty() {
    Preferences prefs;
    prefs.begin(MQTT_NVS_NS, false);
    if (!prefs.isKey("broker")) {
        prefs.putString("broker",   MQTT_BROKER_DEFAULT);
        prefs.putInt   ("port",     MQTT_PORT_DEFAULT);
        prefs.putString("user",     MQTT_USER_DEFAULT);
        prefs.putString("pass",     MQTT_PASS_DEFAULT);
        prefs.putString("location", MQTT_LOCATION_DEFAULT);
        Log(INFO, "[MQTT] Seeded default config to NVS");
    }
    prefs.end();
}

// ---------------------------------------------------------------------------
// MQTT callback — inbound control messages
// ---------------------------------------------------------------------------
static void onMessage(char* topic, byte* payload, unsigned int len) {
    if (len == 0 || len > 127) return;

    char msg[128];
    memcpy(msg, payload, len);
    msg[len] = '\0';
    Log(INFO, "[MQTT] Control rx: " + String(msg));

    if      (strstr(msg, "\"oh_on\""))  { turnOnOHMotor();  }
    else if (strstr(msg, "\"oh_off\"")) { turnOffOHMotor(); }
    else if (strstr(msg, "\"ug_on\""))  { turnOnUGMotor();  }
    else if (strstr(msg, "\"ug_off\"")) { turnOffUGMotor(); }
    else {
        Log(WARN, "[MQTT] Unknown control command: " + String(msg));
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
    s_mqtt.setBufferSize(512);

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

    unsigned long now = millis();
    if (now - s_lastPublishMs >= MQTT_PUBLISH_MS) {
        s_lastPublishMs = now;
        publishMQTTStatus();
    }
}

void publishMQTTStatus() {
    if (!s_mqtt.connected()) return;

    char payload[256];
    snprintf(payload, sizeof(payload),
        "{\"oh_state\":\"%s\",\"ug_state\":\"%s\","
        "\"oh_motor\":%s,\"ug_motor\":%s,"
        "\"lora_ok\":%s,\"wifi_rssi\":%d,"
        "\"uptime_s\":%lu,\"fw\":\"%s\"}",
        tankStateStr(ohTankState),
        tankStateStr(ugTankState),
        ohMotorRunning ? "true" : "false",
        ugMotorRunning ? "true" : "false",
        loraOperational ? "true" : "false",
        wifiRSSI,
        millis() / 1000UL,
        FW_VERSION
    );

    if (s_mqtt.publish(s_topicStatus, payload, true)) {
        Log(INFO, "[MQTT] Published status");
    } else {
        Log(WARN, "[MQTT] Publish failed (buffer too small?)");
    }
}
