// OH Tank Level Transmitter – Float Switch Edition
//
// Hardware:
//   MCU  : ATmega328P @ 8 MHz, 3.3 V
//   Radio: RFM95 (SX1276) LoRa module via SPI
//   Input: single float switch (NO/NC/COM type) on pin A2 (old echo pin)
//
// Behaviour:
//   Every TX_INTERVAL_MS (5 s) read the float switch pin and broadcast a
//   3-byte FloatPacket over LoRa.  The controller_firmware receives this
//   packet to determine whether the OH tank is LOW or FULL.
//
// Packet format (must stay in sync with Globals.h in controller_firmware):
//   byte 0 – type  : LORA_PKT_FLOAT_SWITCH (0x02)
//   byte 1 – low   : 1 = tank not full (COM connected to NC → GND)
//   byte 2 – full  : 1 = tank full     (COM connected to NO → 3.3 V)

#include <Arduino.h>
#include <SPI.h>
#include <LoRa.h>
#include "Config.h"

// ---------------------------------------------------------------------------
// Packet struct – mirrors FloatPacket in controller_firmware/include/Globals.h
// ---------------------------------------------------------------------------
#pragma pack(push, 1)
struct FloatPacket {
    uint8_t type;
    uint8_t low;
    uint8_t full;
};
#pragma pack(pop)

static unsigned long lastTxTime = 0;

// ---------------------------------------------------------------------------
// setup
// ---------------------------------------------------------------------------
void setup() {
    Serial.begin(57600);
    Serial.print(F("OH Tank Transmitter v"));
    Serial.println(F(FW_VERSION));

    // No INPUT_PULLUP – the switch itself drives the pin to 3.3 V (NO) or GND (NC).
    pinMode(FLOAT_FULL_PIN, INPUT);

    LoRa.setPins(LORA_SS_PIN, LORA_RST_PIN, LORA_DIO0_PIN);

    while (!LoRa.begin(LORA_FREQUENCY)) {
        Serial.println(F("LoRa init failed, retrying..."));
        delay(500);
    }

    LoRa.setSpreadingFactor(LORA_SPREADING_FACTOR);
    LoRa.setSignalBandwidth(LORA_BANDWIDTH);
    LoRa.setCodingRate4(LORA_CODING_RATE);
    LoRa.setSyncWord(LORA_SYNC_WORD);
    LoRa.setTxPower(LORA_TX_POWER);
    LoRa.setPreambleLength(LORA_PREAMBLE_LENGTH);

    Serial.println(F("LoRa ready"));
}

// ---------------------------------------------------------------------------
// loop
// ---------------------------------------------------------------------------
void loop() {
    unsigned long now = millis();
    if (now - lastTxTime < TX_INTERVAL_MS) return;
    lastTxTime = now;

    // HIGH → COM on NO → tank FULL.  LOW → COM on NC → tank LOW.
    uint8_t isFull = (digitalRead(FLOAT_FULL_PIN) == HIGH) ? 1 : 0;

    FloatPacket pkt;
    pkt.type = LORA_PKT_FLOAT_SWITCH;
    pkt.full = isFull;
    pkt.low  = isFull ? 0 : 1;   // if not full, treat as low

    LoRa.beginPacket();
    LoRa.write(reinterpret_cast<uint8_t*>(&pkt), sizeof(pkt));
    LoRa.endPacket();   // blocking; returns after TX complete

    Serial.print(F("TX  full="));
    Serial.print(pkt.full);
    Serial.print(F("  low="));
    Serial.println(pkt.low);
}
