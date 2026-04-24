#ifndef HISTORY_H
#define HISTORY_H

#include <Arduino.h>
#include "Globals.h"

// =============================================================================
//  Event types recorded in EEPROM history
// =============================================================================
typedef enum : uint8_t {
    HIST_MOTOR_OH_ON  = 0,
    HIST_MOTOR_OH_OFF = 1,
    HIST_MOTOR_UG_ON  = 2,
    HIST_MOTOR_UG_OFF = 3,
    HIST_OH_STATE_CHG = 4,   // OH tank state changed (LoRa update)
    HIST_UG_STATE_CHG = 5,   // UG tank state changed (float switch)
    HIST_BOOT         = 6,
} HistEvent;

// =============================================================================
//  8-byte packed record stored in EEPROM circular buffer
// =============================================================================
#pragma pack(push, 1)
struct HistoryRecord {
    uint32_t timestamp;   // Seconds since epoch (local IST)
    uint8_t  event;       // HistEvent
    uint8_t  ohState;     // TankState for OH tank
    uint8_t  ugState;     // TankState for UG tank
    uint8_t  flags;       // bit0 = ohMotorRunning, bit1 = ugMotorRunning
};
#pragma pack(pop)

// =============================================================================
//  Public interface
// =============================================================================
extern bool histEepromFound;

// Call once from setup() after Wire.begin()
void    initHistory();

// Record one event. oh/ug = current tank states at time of event.
void    addHistoryRecord(HistEvent evt, TankState oh, TankState ug);

// Return last maxRecords events as a JSON string (newest first).
String  getHistoryJson(uint16_t maxRecords = 100);

// Wipe the circular buffer (keeps EEPROM magic intact).
void    clearHistory();

#endif // HISTORY_H
