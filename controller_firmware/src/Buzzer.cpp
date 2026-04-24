#include "Buzzer.h"
#include "Logger.h"
#include "Config.h"

static bool          buzzerActive   = false;
static BuzzerPattern currentPattern = BUZZER_NONE;
static unsigned long buzzerStartMs  = 0;
static unsigned long nextToggleMs   = 0;
static bool          buzzerPinState = false;

// Countdown pattern: beep ON time is fixed 300 ms.
// OFF time starts at 2700 ms (3 s period) and shrinks linearly down to 100 ms
// over MOTOR_START_BUZZER_DELAY_MS milliseconds.
static const uint16_t COUNTDOWN_ON_MS      = 300;
static const uint16_t COUNTDOWN_OFF_START  = 2700;  // gap at t=0
static const uint16_t COUNTDOWN_OFF_END    = 100;   // gap near motor start

static const uint16_t SHORT_ON_MS  = 200;
static const uint16_t SHORT_OFF_MS = 800;

static uint16_t currentOffMs() {
    // Linearly interpolate gap based on elapsed time within the 30 s window
    unsigned long elapsed = millis() - buzzerStartMs;
    if (elapsed >= MOTOR_START_BUZZER_DELAY_MS) return COUNTDOWN_OFF_END;
    float frac = (float)elapsed / (float)MOTOR_START_BUZZER_DELAY_MS;
    return (uint16_t)(COUNTDOWN_OFF_START - frac * (COUNTDOWN_OFF_START - COUNTDOWN_OFF_END));
}

void initBuzzer() {
    pinMode(BUZZER_PIN, OUTPUT);
    digitalWrite(BUZZER_PIN, LOW);
    Log(INFO, "[Buzzer] Init on GPIO " + String(BUZZER_PIN));
}

void startBuzzer(BuzzerPattern pattern) {
    buzzerActive    = true;
    currentPattern  = pattern;
    buzzerStartMs   = millis();
    buzzerPinState  = true;
    digitalWrite(BUZZER_PIN, HIGH);
    uint16_t firstOn = (pattern == BUZZER_SHORT_BEEPS) ? SHORT_ON_MS : COUNTDOWN_ON_MS;
    nextToggleMs = buzzerStartMs + firstOn;
    Log(INFO, "[Buzzer] Start pattern=" + String(pattern));
}

void stopBuzzer() {
    if (!buzzerActive) return;
    buzzerActive   = false;
    currentPattern = BUZZER_NONE;
    buzzerPinState = false;
    noTone(BUZZER_PIN);
    digitalWrite(BUZZER_PIN, LOW);
    Log(INFO, "[Buzzer] Stopped");
}

void updateBuzzer() {
    if (!buzzerActive) return;

    unsigned long now = millis();

    if (now - buzzerStartMs >= BUZZER_MAX_DURATION_MS) {
        stopBuzzer();
        return;
    }

    if (now < nextToggleMs) return;

    buzzerPinState = !buzzerPinState;
    digitalWrite(BUZZER_PIN, buzzerPinState ? HIGH : LOW);

    if (currentPattern == BUZZER_SHORT_BEEPS) {
        nextToggleMs = now + (buzzerPinState ? SHORT_ON_MS : SHORT_OFF_MS);
    } else {
        // BUZZER_COUNTDOWN: fixed ON, dynamic OFF that shrinks over time
        nextToggleMs = now + (buzzerPinState ? COUNTDOWN_ON_MS : currentOffMs());
    }
}

bool isBuzzerActive() {
    return buzzerActive;
}
