#include "Display.h"
#include "Logger.h"
#include "Config.h"
#include "Globals.h"
#include "LoRaManager.h"
#include "WiFiManager.h"
#include <Wire.h>
#include <WiFi.h>
#include <LiquidCrystal_I2C.h>
#include <time.h>

// Screen indices
#define SCREEN_OH_TANK   0
#define SCREEN_UG_TANK   1
#define SCREEN_NETWORK   2
#define SCREEN_DATETIME  3
#define SCREEN_LORA      4
#define SCREEN_COUNT     5

static LiquidCrystal_I2C lcd(LCD_ADDRESS, LCD_COLUMNS, LCD_ROWS);
static bool     lcdInitOk       = false;
static bool     backlightOn     = true;
static bool     pairingPinShown = false;

static int           currentScreen    = 0;
static unsigned long lastScreenChange = 0;
static unsigned long lastBlCheckMs    = 0;  // last backlight mode check

// ---------------------------------------------------------------------------
//  Helpers
// ---------------------------------------------------------------------------

static void printTankLine(uint8_t row, const char* label, TankState state,
                           bool motorOn, bool displayOnly) {
    char buf[17] = {};
    const char* stateStr = tankStateStr(state);
    const char* motorStr = displayOnly ? "---" : (motorOn ? "ON " : "OFF");
    snprintf(buf, sizeof(buf), "%-2s:%-7s M:%s", label, stateStr, motorStr);
    lcd.setCursor(0, row);
    lcd.print(buf);
}

// ---------------------------------------------------------------------------
//  Screens
// ---------------------------------------------------------------------------

static void showOHTank() {
    lcd.clear();
    printTankLine(0, "OH", ohTankState,  ohMotorRunning, ohDisplayOnly);
    printTankLine(1, "UG", ugTankState, ugMotorRunning, ugDisplayOnly);
}

static void showNetwork() {
    lcd.clear();
    lcd.setCursor(0, 0);
    if (isAPMode) {
        lcd.print("AP: " DEFAULT_AP_SSID);
        lcd.setCursor(0, 1);
        lcd.print(WiFi.softAPIP().toString());
    } else if (WiFi.status() == WL_CONNECTED) {
        String ssid = WiFi.SSID();
        if (ssid.length() > 16) ssid = ssid.substring(0, 16);
        lcd.print(ssid);
        lcd.setCursor(0, 1);
        lcd.print(WiFi.localIP().toString());
    } else {
        lcd.print("WiFi: Disconnected");
        lcd.setCursor(0, 1);
        lcd.print("Reconnecting...");
    }
}

static void showDateTime() {
    lcd.clear();
    String t = getFormattedTime();   // "hh:mm:ss AM DD-MM-YYYY"
    // Row 0: "hh:mm AM"  (fits 16 chars easily)
    // Row 1: DD-MM-YYYY
    int spaceAfterAmpm = t.indexOf(' ', 9); // space after AM/PM
    lcd.setCursor(0, 0);
    lcd.print(t.substring(0, spaceAfterAmpm)); // "hh:mm:ss AM"
    lcd.setCursor(0, 1);
    lcd.print(t.substring(spaceAfterAmpm + 1)); // "DD-MM-YYYY"
}

static void showLora() {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print(isLoraOperational() ? "LoRa: OK" : "LoRa: ERROR");
    lcd.setCursor(0, 1);
    if (lastLoraReceivedTime == 0) {
        lcd.print("No data yet");
    } else {
        unsigned long secAgo = (millis() - lastLoraReceivedTime) / 1000UL;
        char buf[17];
        snprintf(buf, sizeof(buf), "Last: %lus ago", secAgo);
        lcd.print(buf);
    }
}

static void renderCurrentScreen() {
    if (pairingPinShown) return;   // Pairing PIN has priority
    switch (currentScreen) {
        case SCREEN_OH_TANK:
        case SCREEN_UG_TANK:  showOHTank();  break;  // Both show combined view
        case SCREEN_NETWORK:  showNetwork(); break;
        case SCREEN_DATETIME: showDateTime(); break;
        case SCREEN_LORA:     showLora();    break;
        default:              showOHTank();  break;
    }
}

// ---------------------------------------------------------------------------
//  Public API
// ---------------------------------------------------------------------------

void initDisplay() {
    lcd.init();
    lcd.backlight();
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Tank Monitor");
    lcd.setCursor(0, 1);
    lcd.print("  Float v1.0  ");
    lcdInitOk   = true;
    backlightOn = true;
    applyBacklightMode();  // apply persisted mode at startup
    Log(INFO, "[Display] LCD initialised at 0x" + String(LCD_ADDRESS, HEX));
}

void updateDisplay() {
    if (!lcdInitOk || pairingPinShown) return;

    unsigned long now = millis();

    // Re-check backlight every 30 s (auto mode follows time-of-day)
    if (now - lastBlCheckMs >= 30000UL || lastBlCheckMs == 0) {
        lastBlCheckMs = now;
        applyBacklightMode();
    }

    if (now - lastScreenChange >= LCD_SCREEN_DURATION_MS) {
        currentScreen = (currentScreen + 1) % SCREEN_COUNT;
        lastScreenChange = now;
        renderCurrentScreen();
    }
}

void displayPairingPin(uint32_t pin) {
    pairingPinShown = true;
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("** BLE PAIRING **");
    char buf[7];
    snprintf(buf, sizeof(buf), "%06lu", (unsigned long)pin);
    lcd.setCursor(0, 1);
    lcd.print("PIN: ");
    lcd.print(buf);
    Log(INFO, "[Display] BLE pairing PIN shown: " + String(buf));
}

void clearPairingPinDisplay() {
    pairingPinShown = false;
    lcd.clear();
    renderCurrentScreen();
    Log(INFO, "[Display] Pairing PIN cleared");
}

void setLcdBacklight(bool on) {
    backlightOn = on;
    if (on) lcd.backlight();
    else    lcd.noBacklight();
}

bool isLcdBacklightOn() {
    return backlightOn;
}

// Apply the current lcdBacklightMode — called at startup and every 30 s
void applyBacklightMode() {
    if (!lcdInitOk) return;
    if (lcdBacklightMode == LCD_BL_ALWAYS_ON) {
        setLcdBacklight(true);
    } else if (lcdBacklightMode == LCD_BL_ALWAYS_OFF) {
        setLcdBacklight(false);
    } else {
        // AUTO: off during daytime 07:00–17:30, on at night
        struct tm ti;
        if (getLocalTime(&ti, 100)) {
            int totalMin = ti.tm_hour * 60 + ti.tm_min;
            bool isDaytime = (totalMin >= 7 * 60 && totalMin < 17 * 60 + 30);
            setLcdBacklight(!isDaytime);
        }
    }
}
