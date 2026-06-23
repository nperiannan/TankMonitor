#include "MotorControl.h"
#include "Logger.h"
#include "Config.h"
#include "Globals.h"
#include "Buzzer.h"
#include "History.h"
#include "LoRaManager.h"

// Pending motor start state (for buzzer-delay feature)
static bool          ohMotorStartPending = false;
static unsigned long ohMotorPendingStart = 0;
static bool          ugMotorStartPending = false;
static unsigned long ugMotorPendingStart = 0;

// Timestamp when motor was actually energised (for max runtime & hysteresis)
static unsigned long ohMotorStartedMs = 0;
static unsigned long ugMotorStartedMs = 0;

// Boot recovery: checked once after first valid LoRa packet
static bool bootRecoveryDone = false;

// ---------------------------------------------------------------------------
//  Init
// ---------------------------------------------------------------------------

void initMotorPins() {
    pinMode(OH_RELAY_PIN, OUTPUT);
    pinMode(UG_RELAY_PIN, OUTPUT);
    digitalWrite(OH_RELAY_PIN, RELAY_OFF);
    digitalWrite(UG_RELAY_PIN, RELAY_OFF);
    ohMotorRunning = false;
    ugMotorRunning = false;
    Log(INFO, "[Motor] Relay pins init: OH=" + String(OH_RELAY_PIN)
              + " UG=" + String(UG_RELAY_PIN));
}

// ---------------------------------------------------------------------------
//  Config persistence
// ---------------------------------------------------------------------------

void loadMotorConfig() {
    preferences.begin(NVS_MOTOR_NS, true);
    ohDisplayOnly      = preferences.getBool (NVS_KEY_OH_DISP_ONLY, false);
    ugDisplayOnly      = preferences.getBool (NVS_KEY_UG_DISP_ONLY, false);
    ugIgnoreForOH      = preferences.getBool (NVS_KEY_UG_IGNORE,    false);
    buzzerDelayEnabled = preferences.getBool (NVS_KEY_BUZZER_DELAY, true);
    manualAutoStop     = preferences.getBool (NVS_KEY_MANUAL_ASTOP, true);
    lcdBacklightMode   = preferences.getUChar(NVS_KEY_LCD_BL_MODE,  LCD_BL_AUTO);
    ohStartLevel       = (TankState)preferences.getUChar(NVS_KEY_OH_START_LVL, TANK_STATE_EMPTY);
    ohStopLevel        = (TankState)preferences.getUChar(NVS_KEY_OH_STOP_LVL,  TANK_STATE_FULL);
    ohMaxRunMin        = preferences.getUChar(NVS_KEY_OH_MAX_RUN, 20);
    if (ohMaxRunMin < 5)  ohMaxRunMin = 5;
    if (ohMaxRunMin > 60) ohMaxRunMin = 60;
    preferences.end();
    Log(INFO, "[Motor] Config loaded: ohDisp=" + String(ohDisplayOnly)
              + " ugDisp=" + String(ugDisplayOnly)
              + " ugIgnore=" + String(ugIgnoreForOH)
              + " buzzerDelay=" + String(buzzerDelayEnabled)
              + " manualAutoStop=" + String(manualAutoStop)
              + " lcdBl=" + String(lcdBacklightMode)
              + " ohStart=" + tankStateStr(ohStartLevel)
              + " ohStop=" + tankStateStr(ohStopLevel)
              + " ohMaxRun=" + String(ohMaxRunMin) + "min");
}

void saveMotorConfig() {
    preferences.begin(NVS_MOTOR_NS, false);
    preferences.putBool (NVS_KEY_OH_DISP_ONLY, ohDisplayOnly);
    preferences.putBool (NVS_KEY_UG_DISP_ONLY, ugDisplayOnly);
    preferences.putBool (NVS_KEY_UG_IGNORE,    ugIgnoreForOH);
    preferences.putBool (NVS_KEY_BUZZER_DELAY, buzzerDelayEnabled);
    preferences.putBool (NVS_KEY_MANUAL_ASTOP, manualAutoStop);
    preferences.putUChar(NVS_KEY_LCD_BL_MODE,  lcdBacklightMode);
    preferences.putUChar(NVS_KEY_OH_START_LVL, (uint8_t)ohStartLevel);
    preferences.putUChar(NVS_KEY_OH_STOP_LVL,  (uint8_t)ohStopLevel);
    preferences.putUChar(NVS_KEY_OH_MAX_RUN,   ohMaxRunMin);
    preferences.end();
    Log(INFO, "[Motor] Config saved");
}

// ---------------------------------------------------------------------------
//  Internal helpers
// ---------------------------------------------------------------------------

static void energiseOHRelay(bool on) {
    digitalWrite(OH_RELAY_PIN, on ? RELAY_ON : RELAY_OFF);
    ohMotorRunning = on;
    if (on) ohMotorStartedMs = millis();
    // Persist motor intent for power failure recovery
    preferences.begin(NVS_MOTOR_NS, false);
    preferences.putBool(NVS_KEY_OH_MOTOR_INTENT, on);
    preferences.end();
    Log(INFO, String("[Motor] OH relay ") + (on ? "ON" : "OFF"));
    addHistoryRecord(on ? HIST_MOTOR_OH_ON : HIST_MOTOR_OH_OFF, ohTankState, ugTankState);
}

static void energiseUGRelay(bool on) {
    digitalWrite(UG_RELAY_PIN, on ? RELAY_ON : RELAY_OFF);
    ugMotorRunning = on;
    if (on) ugMotorStartedMs = millis();
    preferences.begin(NVS_MOTOR_NS, false);
    preferences.putBool(NVS_KEY_UG_MOTOR_INTENT, on);
    preferences.end();
    Log(INFO, String("[Motor] UG relay ") + (on ? "ON" : "OFF"));
    addHistoryRecord(on ? HIST_MOTOR_UG_ON : HIST_MOTOR_UG_OFF, ohTankState, ugTankState);
}

// ---------------------------------------------------------------------------
//  OH auto-control
//  Rule:
//    TANK_STATE_FULL  → turn motor OFF  (safety – always honoured)
//    TANK_STATE_LOW   → turn motor ON   (only if UG has water, or ugIgnoreForOH)
//    TANK_STATE_UNKNOWN → turn motor OFF (safety)
// ---------------------------------------------------------------------------

void autoControlOHMotor() {
    if (millis() < BOOT_GRACE_PERIOD_MS) return;  // wait for sensors to settle after boot
    if (ohDisplayOnly) return;

    bool ugOk = ugIgnoreForOH || (ugTankState == TANK_STATE_FULL);

    // --- Max runtime safety (applies to ALL sources) ---
    if (ohMotorRunning) {
        unsigned long runMs = millis() - ohMotorStartedMs;
        if (runMs >= (unsigned long)ohMaxRunMin * 60000UL) {
            Log(WARN, "[Motor] OH OFF – max runtime " + String(ohMaxRunMin) + " min exceeded");
            ohMotorStartPending = false;
            stopBuzzer();
            energiseOHRelay(false);
            ohMotorSource = MOTOR_SRC_NONE;
            return;
        }
    }

    // --- LoRa safety: stop motor if no signal for 5 min (applies to ALL sources) ---
    if (ohMotorRunning && lastLoraReceivedTime > 0) {
        if (millis() - lastLoraReceivedTime >= LORA_MOTOR_SAFETY_TIMEOUT_MS) {
            Log(WARN, "[Motor] OH OFF – no LoRa signal for 5 min while motor running");
            ohMotorStartPending = false;
            stopBuzzer();
            // Intent stays true in NVS (energiseOHRelay(false) clears it,
            // but we want to resume after LoRa returns), so set it back
            energiseOHRelay(false);
            // Re-set intent so power recovery can resume
            preferences.begin(NVS_MOTOR_NS, false);
            preferences.putBool(NVS_KEY_OH_MOTOR_INTENT, true);
            preferences.end();
            ohMotorSource = MOTOR_SRC_NONE;
            return;
        }
    }

    // --- Hysteresis: don't stop motor within MOTOR_MIN_RUN_MS ---
    if (ohMotorRunning && (millis() - ohMotorStartedMs < MOTOR_MIN_RUN_MS)) return;

    // Scheduler-started motors are immune to auto-start/stop logic below
    if (ohMotorSource == MOTOR_SRC_SCHEDULED) return;

    // --- Stop motor when tank reaches stop threshold ---
    if (ohTankState >= ohStopLevel && ohMotorRunning
        && (ohMotorSource != MOTOR_SRC_MANUAL || manualAutoStop)) {
        Log(INFO, "[Motor] OH " + String(ohMotorSource == MOTOR_SRC_MANUAL ? "MANUAL" : "AUTO")
                  + " OFF – tank reached " + String(tankStateStr(ohTankState)));
        ohMotorStartPending = false;
        stopBuzzer();
        energiseOHRelay(false);
        ohMotorSource = MOTOR_SRC_NONE;
        return;
    }

    // UNKNOWN while running: keep running (don't abort a fill on lost LoRa signal)
    if (ohTankState == TANK_STATE_UNKNOWN && ohMotorRunning) return;

    // Cancel a pending (buzzer-delay) AUTO start if state is no longer at/below start level
    if (ohMotorStartPending && ohMotorSource == MOTOR_SRC_AUTO && ohTankState > ohStartLevel) {
        Log(WARN, "[Motor] OH AUTO cancel pending – state above start level");
        ohMotorStartPending = false;
        stopBuzzer();
        ohMotorSource = MOTOR_SRC_NONE;
        return;
    }

    // --- Start motor when tank at/below start threshold ---
    if (ohTankState != TANK_STATE_UNKNOWN && ohTankState <= ohStartLevel
        && !ohMotorRunning && !ohMotorStartPending) {
        if (!ugOk) {
            Log(WARN, "[Motor] OH AUTO ON blocked – UG tank not ready (state="
                      + String(tankStateStr(ugTankState)) + ")");
            return;
        }
        ohMotorSource = MOTOR_SRC_AUTO;
        if (buzzerDelayEnabled) {
            Log(INFO, "[Motor] OH AUTO ON pending – buzzer delay started");
            ohMotorStartPending = true;
            ohMotorPendingStart = millis();
            startBuzzer(BUZZER_COUNTDOWN);
        } else {
            energiseOHRelay(true);
        }
    }
}

void autoControlUGMotor() {
    if (millis() < BOOT_GRACE_PERIOD_MS) return;
    if (ugDisplayOnly) return;

    // --- Max runtime safety (applies to ALL sources) ---
    if (ugMotorRunning) {
        unsigned long runMs = millis() - ugMotorStartedMs;
        if (runMs >= (unsigned long)ohMaxRunMin * 60000UL) {
            Log(WARN, "[Motor] UG OFF – max runtime " + String(ohMaxRunMin) + " min exceeded");
            ugMotorStartPending = false;
            stopBuzzer();
            energiseUGRelay(false);
            ugMotorSource = MOTOR_SRC_NONE;
            return;
        }
    }

    // --- LoRa safety: stop motor if no signal for 5 min (applies to ALL sources) ---
    if (ugMotorRunning && lastLoraReceivedTime > 0) {
        if (millis() - lastLoraReceivedTime >= LORA_MOTOR_SAFETY_TIMEOUT_MS) {
            Log(WARN, "[Motor] UG OFF – no LoRa signal for 5 min while motor running");
            ugMotorStartPending = false;
            stopBuzzer();
            energiseUGRelay(false);
            preferences.begin(NVS_MOTOR_NS, false);
            preferences.putBool(NVS_KEY_UG_MOTOR_INTENT, true);
            preferences.end();
            ugMotorSource = MOTOR_SRC_NONE;
            return;
        }
    }

    // Scheduler-started motors are immune to auto-start/stop logic below
    if (ugMotorSource == MOTOR_SRC_SCHEDULED) return;

    if (ugTankState == TANK_STATE_FULL && ugMotorRunning
        && (ugMotorSource != MOTOR_SRC_MANUAL || manualAutoStop)) {
        Log(INFO, "[Motor] UG " + String(ugMotorSource == MOTOR_SRC_MANUAL ? "MANUAL" : "AUTO")
                  + " OFF – tank full");
        ugMotorStartPending = false;
        energiseUGRelay(false);
        ugMotorSource = MOTOR_SRC_NONE;
        return;
    }
    if (ugTankState == TANK_STATE_UNKNOWN && ugMotorRunning) return;

    if (ugMotorStartPending && ugMotorSource == MOTOR_SRC_AUTO && ugTankState != TANK_STATE_LOW) {
        Log(WARN, "[Motor] UG AUTO cancel pending – state no longer LOW");
        ugMotorStartPending = false;
        stopBuzzer();
        ugMotorSource = MOTOR_SRC_NONE;
        return;
    }

    if (ugTankState == TANK_STATE_LOW && !ugMotorRunning && !ugMotorStartPending) {
        ugMotorSource = MOTOR_SRC_AUTO;
        if (buzzerDelayEnabled) {
            Log(INFO, "[Motor] UG AUTO ON pending – buzzer delay");
            ugMotorStartPending = true;
            ugMotorPendingStart = millis();
            startBuzzer(BUZZER_COUNTDOWN);
        } else {
            energiseUGRelay(true);
        }
    }
}

// ---------------------------------------------------------------------------
//  Pending motor start processing (buzzer delay)
// ---------------------------------------------------------------------------

void processPendingMotorStarts() {
    unsigned long now = millis();

    if (ohMotorStartPending && now - ohMotorPendingStart >= MOTOR_START_BUZZER_DELAY_MS) {
        ohMotorStartPending = false;
        stopBuzzer();
        if (ohMotorSource == MOTOR_SRC_MANUAL || ohMotorSource == MOTOR_SRC_SCHEDULED) {
            energiseOHRelay(true);
        } else {
            // Auto start: only proceed if still at/below start level and not display-only
            if (ohTankState != TANK_STATE_UNKNOWN && ohTankState <= ohStartLevel && !ohDisplayOnly) {
                energiseOHRelay(true);
            } else {
                ohMotorSource = MOTOR_SRC_NONE;
            }
        }
    }

    if (ugMotorStartPending && now - ugMotorPendingStart >= MOTOR_START_BUZZER_DELAY_MS) {
        ugMotorStartPending = false;
        stopBuzzer();
        if (ugMotorSource == MOTOR_SRC_MANUAL || ugMotorSource == MOTOR_SRC_SCHEDULED) {
            energiseUGRelay(true);
        } else {
            if (ugTankState == TANK_STATE_LOW && !ugDisplayOnly) {
                energiseUGRelay(true);
            } else {
                ugMotorSource = MOTOR_SRC_NONE;
            }
        }
    }

    // --- Boot recovery: check NVS motor intent after first valid LoRa + UG data ---
    if (!bootRecoveryDone && millis() > BOOT_GRACE_PERIOD_MS
        && ohTankState != TANK_STATE_UNKNOWN && ugTankState != TANK_STATE_UNKNOWN) {
        bootRecoveryDone = true;
        preferences.begin(NVS_MOTOR_NS, true);
        bool ohIntent = preferences.getBool(NVS_KEY_OH_MOTOR_INTENT, false);
        bool ugIntent = preferences.getBool(NVS_KEY_UG_MOTOR_INTENT, false);
        preferences.end();

        if (ohIntent && !ohMotorRunning && ohTankState < ohStopLevel) {
            bool ugOk = ugIgnoreForOH || (ugTankState == TANK_STATE_FULL);
            if (ugOk && !ohDisplayOnly) {
                Log(INFO, "[Motor] Boot recovery: resuming OH motor (intent=true, state="
                    + String(tankStateStr(ohTankState)) + ")");
                ohMotorSource = MOTOR_SRC_AUTO;
                if (buzzerDelayEnabled) {
                    ohMotorStartPending = true;
                    ohMotorPendingStart = millis();
                    startBuzzer(BUZZER_COUNTDOWN);
                } else {
                    energiseOHRelay(true);
                }
            }
        } else if (ohIntent) {
            // Clear stale intent — tank already reached stop level
            preferences.begin(NVS_MOTOR_NS, false);
            preferences.putBool(NVS_KEY_OH_MOTOR_INTENT, false);
            preferences.end();
            Log(INFO, "[Motor] Boot recovery: OH intent cleared (tank at " + String(tankStateStr(ohTankState)) + ")");
        }

        if (ugIntent && !ugMotorRunning && ugTankState != TANK_STATE_FULL) {
            if (!ugDisplayOnly) {
                Log(INFO, "[Motor] Boot recovery: resuming UG motor");
                ugMotorSource = MOTOR_SRC_AUTO;
                if (buzzerDelayEnabled) {
                    ugMotorStartPending = true;
                    ugMotorPendingStart = millis();
                    startBuzzer(BUZZER_COUNTDOWN);
                } else {
                    energiseUGRelay(true);
                }
            }
        } else if (ugIntent) {
            preferences.begin(NVS_MOTOR_NS, false);
            preferences.putBool(NVS_KEY_UG_MOTOR_INTENT, false);
            preferences.end();
            Log(INFO, "[Motor] Boot recovery: UG intent cleared");
        }
    }
}

// ---------------------------------------------------------------------------
//  Manual commands
// ---------------------------------------------------------------------------

void turnOnOHMotor() {
    if (ohMotorRunning || ohMotorStartPending) return;
    if (ohMotorSource == MOTOR_SRC_NONE) ohMotorSource = MOTOR_SRC_MANUAL;
    if (buzzerDelayEnabled) {
        ohMotorStartPending = true;
        ohMotorPendingStart = millis();
        startBuzzer(BUZZER_COUNTDOWN);
        Log(INFO, "[Motor] OH ON – buzzer delay started");
    } else {
        energiseOHRelay(true);
    }
}

void turnOffOHMotor() {
    ohMotorStartPending   = false;
    ohMotorSource         = MOTOR_SRC_NONE;
    stopBuzzer();
    energiseOHRelay(false);
}

void turnOnUGMotor() {
    if (ugMotorRunning || ugMotorStartPending) return;
    if (ugMotorSource == MOTOR_SRC_NONE) ugMotorSource = MOTOR_SRC_MANUAL;
    if (buzzerDelayEnabled) {
        ugMotorStartPending = true;
        ugMotorPendingStart = millis();
        startBuzzer(BUZZER_COUNTDOWN);
        Log(INFO, "[Motor] UG ON – buzzer delay started");
    } else {
        energiseUGRelay(true);
    }
}

void turnOffUGMotor() {
    ugMotorStartPending   = false;
    ugMotorSource         = MOTOR_SRC_NONE;
    stopBuzzer();
    energiseUGRelay(false);
}

bool isOHBuzzerPending() { return ohMotorStartPending; }
bool isUGBuzzerPending() { return ugMotorStartPending; }
