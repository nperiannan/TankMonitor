#ifndef GLOBALS_H
#define GLOBALS_H

#include <Arduino.h>
#include <Preferences.h>

// =============================================================================
//                              SHARED TYPES
// =============================================================================

// State reported by a float switch sensor.
typedef enum : uint8_t {
    TANK_STATE_UNKNOWN = 0,  // No valid reading yet (startup / sensor fault)
    TANK_STATE_LOW     = 1,  // Float is at low position  → tank needs filling
    TANK_STATE_FULL    = 2,  // Float is at full position → tank is full
} TankState;

// Returns a human-readable C-string for a TankState.
inline const char* tankStateStr(TankState s) {
    switch (s) {
        case TANK_STATE_LOW:  return "LOW";
        case TANK_STATE_FULL: return "FULL";
        default:              return "UNKNOWN";
    }
}

// LoRa packet sent by the remote OH-tank node (float switch version).
#pragma pack(push, 1)
struct FloatPacket {
    uint8_t type;    // LORA_PKT_FLOAT_SWITCH (0x02)
    uint8_t low;     // 1 = LOW-position float triggered
    uint8_t full;    // 1 = FULL-position float triggered
};

// Legacy ultrasonic distance packet (for backward compatibility).
struct DistancePacket {
    uint8_t  type;      // LORA_PKT_DISTANCE (0x01)
    uint16_t distance;  // Distance in mm * 100
};
#pragma pack(pop)

// =============================================================================
//                              GLOBAL STATE (defined in main.cpp)
// =============================================================================
extern TankState ugTankState;         // Current UG tank float state
extern TankState ohTankState;         // Current OH tank float state (from LoRa)

extern bool ohMotorRunning;           // OH relay is energised
extern bool ugMotorRunning;           // UG relay is energised

extern bool loraOperational;          // LoRa radio is healthy
extern unsigned long lastLoraReceivedTime; // millis() of last valid LoRa packet

extern bool isAPMode;                 // ESP32 is in AP (hotspot) mode
extern String wifiSSID;               // Current connected SSID
extern int    wifiRSSI;               // Current WiFi RSSI

// Runtime configuration (loaded from NVS at boot, also written back on change)
extern bool    ohDisplayOnly;       // True → do NOT drive OH relay; monitor only
extern bool    ugDisplayOnly;       // True → do NOT drive UG relay; monitor only
extern bool    ugIgnoreForOH;       // True → start OH motor even if UG tank is LOW
extern bool    buzzerDelayEnabled;  // True → buzz before motor starts
extern uint8_t lcdBacklightMode;    // LCD_BL_AUTO / LCD_BL_ALWAYS_ON / LCD_BL_ALWAYS_OFF

// Shared NVS preferences object (opened/closed per use in each module)
extern Preferences preferences;

#endif // GLOBALS_H
