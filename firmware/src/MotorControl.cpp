#include "MotorControl.h"
#include "Logger.h"
#include "Config.h"
#include "Globals.h"
#include "Buzzer.h"
#include "History.h"

// Pending motor start state (for buzzer-delay feature)
static bool          ohMotorStartPending = false;
static unsigned long ohMotorPendingStart = 0;
static bool          ugMotorStartPending = false;
static unsigned long ugMotorPendingStart = 0;

// Manual override flags: set when user explicitly turns motor ON via GUI/BLE.
// Auto-control will NOT turn off a manually-started motor.
static bool ohMotorManualOverride = false;
static bool ugMotorManualOverride = false;

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
    lcdBacklightMode   = preferences.getUChar(NVS_KEY_LCD_BL_MODE,  LCD_BL_AUTO);
    preferences.end();
    Log(INFO, "[Motor] Config loaded: ohDisp=" + String(ohDisplayOnly)
              + " ugDisp=" + String(ugDisplayOnly)
              + " ugIgnore=" + String(ugIgnoreForOH)
              + " buzzerDelay=" + String(buzzerDelayEnabled)
              + " lcdBl=" + String(lcdBacklightMode));
}

void saveMotorConfig() {
    preferences.begin(NVS_MOTOR_NS, false);
    preferences.putBool (NVS_KEY_OH_DISP_ONLY, ohDisplayOnly);
    preferences.putBool (NVS_KEY_UG_DISP_ONLY, ugDisplayOnly);
    preferences.putBool (NVS_KEY_UG_IGNORE,    ugIgnoreForOH);
    preferences.putBool (NVS_KEY_BUZZER_DELAY, buzzerDelayEnabled);
    preferences.putUChar(NVS_KEY_LCD_BL_MODE,  lcdBacklightMode);
    preferences.end();
    Log(INFO, "[Motor] Config saved");
}

// ---------------------------------------------------------------------------
//  Internal helpers
// ---------------------------------------------------------------------------

static void energiseOHRelay(bool on) {
    digitalWrite(OH_RELAY_PIN, on ? RELAY_ON : RELAY_OFF);
    ohMotorRunning = on;
    Log(INFO, String("[Motor] OH relay ") + (on ? "ON" : "OFF"));
    addHistoryRecord(on ? HIST_MOTOR_OH_ON : HIST_MOTOR_OH_OFF, ohTankState, ugTankState);
}

static void energiseUGRelay(bool on) {
    digitalWrite(UG_RELAY_PIN, on ? RELAY_ON : RELAY_OFF);
    ugMotorRunning = on;
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

    if (ohTankState == TANK_STATE_FULL && ohMotorRunning && !ohMotorManualOverride) {
        Log(INFO, "[Motor] OH AUTO OFF – tank full");
        ohMotorStartPending = false;
        stopBuzzer();
        energiseOHRelay(false);
        return;
    }
    // UNKNOWN while running: keep running (don't abort a fill on lost LoRa signal)
    if (ohTankState == TANK_STATE_UNKNOWN && ohMotorRunning) return;

    // Cancel a pending (buzzer-delay) AUTO start if state is no longer LOW.
    // Manual/scheduler overrides are NOT cancelled here – they proceed regardless of state.
    if (ohMotorStartPending && !ohMotorManualOverride && ohTankState != TANK_STATE_LOW) {
        Log(WARN, "[Motor] OH AUTO cancel pending – state no longer LOW");
        ohMotorStartPending = false;
        stopBuzzer();
        return;
    }

    if (ohTankState == TANK_STATE_LOW && !ohMotorRunning && !ohMotorStartPending) {
        if (!ugOk) {
            Log(WARN, "[Motor] OH AUTO ON blocked – UG tank not ready (state="
                      + String(tankStateStr(ugTankState)) + ")");
            return;
        }
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

// ---------------------------------------------------------------------------
//  UG auto-control
//  Rule:
//    TANK_STATE_FULL    → turn motor OFF (confirmed full)
//    TANK_STATE_LOW     → turn motor ON
//    TANK_STATE_UNKNOWN → keep running if already on (float mid-travel); skip start
// ---------------------------------------------------------------------------

void autoControlUGMotor() {
    if (millis() < BOOT_GRACE_PERIOD_MS) return;  // wait for sensors to settle after boot
    if (ugDisplayOnly) return;

    if (ugTankState == TANK_STATE_FULL && ugMotorRunning && !ugMotorManualOverride) {
        Log(INFO, "[Motor] UG AUTO OFF – tank full");
        ugMotorStartPending = false;
        energiseUGRelay(false);
        return;
    }
    // UNKNOWN while running: keep running (float may be mid-travel)
    if (ugTankState == TANK_STATE_UNKNOWN && ugMotorRunning) return;

    // Cancel a pending AUTO start if state is no longer LOW.
    // Manual/scheduler overrides are NOT cancelled here – they proceed regardless of state.
    if (ugMotorStartPending && !ugMotorManualOverride && ugTankState != TANK_STATE_LOW) {
        Log(WARN, "[Motor] UG AUTO cancel pending – state no longer LOW");
        ugMotorStartPending = false;
        stopBuzzer();
        return;
    }

    if (ugTankState == TANK_STATE_LOW && !ugMotorRunning && !ugMotorStartPending) {
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
        bool wasManual   = ohMotorManualOverride;
        ohMotorStartPending = false;
        stopBuzzer();
        if (wasManual) {
            // Manual/schedule start: energise unconditionally, keep override so auto won't turn it off
            energiseOHRelay(true);
        } else {
            // Auto start: only proceed if still LOW and not display-only
            ohMotorManualOverride = false;
            if (ohTankState == TANK_STATE_LOW && !ohDisplayOnly) energiseOHRelay(true);
        }
    }

    if (ugMotorStartPending && now - ugMotorPendingStart >= MOTOR_START_BUZZER_DELAY_MS) {
        bool wasManual   = ugMotorManualOverride;
        ugMotorStartPending = false;
        stopBuzzer();
        if (wasManual) {
            // Manual/schedule start: energise unconditionally, keep override so auto won't turn it off
            energiseUGRelay(true);
        } else {
            // Auto start: only proceed if still LOW and not display-only
            ugMotorManualOverride = false;
            if (ugTankState == TANK_STATE_LOW && !ugDisplayOnly) energiseUGRelay(true);
        }
    }
}

// ---------------------------------------------------------------------------
//  Manual commands
// ---------------------------------------------------------------------------

void turnOnOHMotor() {
    // Display-only blocks AUTO-control only; manual and scheduler can still run
    if (ohMotorRunning || ohMotorStartPending) return;  // already on or delay pending
    ohMotorManualOverride = true;
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
    ohMotorManualOverride = false;
    stopBuzzer();
    energiseOHRelay(false);
}

void turnOnUGMotor() {
    // Display-only blocks AUTO-control only; manual and scheduler can still run
    if (ugMotorRunning || ugMotorStartPending) return;  // already on or delay pending
    ugMotorManualOverride = true;
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
    ugMotorManualOverride = false;
    stopBuzzer();
    energiseUGRelay(false);
}
