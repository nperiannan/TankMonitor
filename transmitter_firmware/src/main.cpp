#include <RadioLib.h>
#include <avr/wdt.h>

// ** Float Switch Configuration **
#define FLOAT_LOW_PIN   A1   // Bottom float switch (LOW level)
#define FLOAT_HALF_PIN  A2   // Middle float switch (HALF level)
#define FLOAT_FULL_PIN  A3   // Top float switch (FULL level)

// ** LoRa Module Configuration **
#define NSS 10              // Chip select pin for LoRa
#define DIO0 2              // Interrupt pin for LoRa
#define RESET 3             // Reset pin for LoRa
#define DEBUG_LED 9         // LED to indicate transmission

// ** Transmission Interval **
unsigned long interval = 30000;  // 30 seconds
static uint8_t txFailCount = 0;  // consecutive transmit failures

SX1276 radio = new Module(NSS, DIO0, RESET);

// ** Data Struct for Transmission **
#pragma pack(push, 1)
struct FloatPacket {
    uint8_t type;      // Packet type (0x02 = float switch)
    uint8_t sw_full;   // 1 = FULL switch triggered
    uint8_t sw_half;   // 1 = HALF switch triggered
    uint8_t sw_low;    // 1 = LOW  switch triggered
};
#pragma pack(pop)

// ** Function Declarations **
void blink_led();

void setup() {
    wdt_disable();  // Disable WDT early in case it was active from a reset
    Serial.begin(57600);
    delay(100);

    pinMode(FLOAT_LOW_PIN,  INPUT_PULLUP);
    pinMode(FLOAT_HALF_PIN, INPUT_PULLUP);
    pinMode(FLOAT_FULL_PIN, INPUT_PULLUP);
    pinMode(DEBUG_LED, OUTPUT);

    // 3 quick blinks = setup started
    for (uint8_t i = 0; i < 3; i++) {
        digitalWrite(DEBUG_LED, HIGH); delay(100);
        digitalWrite(DEBUG_LED, LOW);  delay(100);
    }

    Serial.print(F("LoRa Initializing ... "));
    int state = radio.begin(865.0, 125.0, 9, 7, 0x34, 20, 8, 0);
    if (state == RADIOLIB_ERR_NONE) {
        Serial.println(F("success!"));
        // 1 long blink = LoRa OK
        digitalWrite(DEBUG_LED, HIGH); delay(1000);
        digitalWrite(DEBUG_LED, LOW);
    } else {
        Serial.print(F("Failed, code: "));
        Serial.println(state);
        // Rapid blink forever = LoRa FAILED
        while (true) {
            digitalWrite(DEBUG_LED, HIGH); delay(50);
            digitalWrite(DEBUG_LED, LOW);  delay(50);
        }
    }

    state = radio.setOutputPower(20);
    if (state == RADIOLIB_ERR_NONE) {
        Serial.println(F("Transmit power set!"));
    } else {
        Serial.print(F("Failed to set transmit power, code: "));
        Serial.println(state);
        while (true) {
            digitalWrite(DEBUG_LED, HIGH); delay(50);
            digitalWrite(DEBUG_LED, LOW);  delay(50);
        }
    }

    Serial.println(F("LoRa transmitter initialized!"));

    // Enable watchdog timer (8 second timeout)
    // If anything hangs, MCU auto-resets
    wdt_enable(WDTO_8S);
}

void loop() {
    // ** Read float switches **
    // Switches are NO, INPUT_PULLUP: LOW = water present, HIGH = no water
    uint8_t lo   = (digitalRead(FLOAT_LOW_PIN)  == LOW) ? 1 : 0;
    uint8_t half = (digitalRead(FLOAT_HALF_PIN) == LOW) ? 1 : 0;
    uint8_t full = (digitalRead(FLOAT_FULL_PIN) == LOW) ? 1 : 0;

    // ** Pack Data into Struct **
    FloatPacket pkt;
    pkt.type    = 0x02;
    pkt.sw_full = full;
    pkt.sw_half = half;
    pkt.sw_low  = lo;

    // ** Transmit Data Over LoRa **
    wdt_reset();
    Serial.println(F("LoRa Transmitting Data ..."));
    Serial.print(F("LOW=")); Serial.print(lo);
    Serial.print(F(" HALF=")); Serial.print(half);
    Serial.print(F(" FULL=")); Serial.println(full);

    int state = radio.transmit((uint8_t*)&pkt, sizeof(pkt));

    if (state == RADIOLIB_ERR_NONE) {
        Serial.println(F("Success!"));
        blink_led();
        txFailCount = 0;
    } else {
        Serial.print(F("Transmission Failed, code: "));
        Serial.println(state);
        txFailCount++;
        // After 3 consecutive failures, reinit the radio
        if (txFailCount >= 3) {
            Serial.println(F("Reinitializing radio..."));
            radio.begin(865.0, 125.0, 9, 7, 0x34, 20, 8, 0);
            radio.setOutputPower(20);
            txFailCount = 0;
        }
    }

    // ** Delay with WDT petting **
    // delay(30000) exceeds 8s WDT, so pet in chunks
    for (uint8_t i = 0; i < 6; i++) {
        wdt_reset();
        delay(5000);
    }
}

// ** LED Blink Function **
void blink_led() {
    digitalWrite(DEBUG_LED, HIGH);
    delay(200);
    digitalWrite(DEBUG_LED, LOW);
    delay(200);
}
