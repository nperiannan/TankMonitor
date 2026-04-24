#include "LoRaManager.h"
#include "Logger.h"
#include "Config.h"
#include "History.h"
#include <RadioLib.h>
#include <SPI.h>

// RadioLib: RFM95 on HSPI
static SPIClass     spi2(HSPI);
static RFM95        radio = new Module(LORA_CS, LORA_IRQ, LORA_RST, LORA_DIO1, spi2);

static bool          loraReady        = false;
static int           retryCount       = 0;
static unsigned long lastReinitMs     = 0;
static float         lastRSSI         = 0.0f;
static float         lastSNR          = 0.0f;

// ---------------------------------------------------------------------------
//  Derive TankState from a legacy distance packet
// ---------------------------------------------------------------------------
static TankState stateFromDistance(uint16_t distanceMm) {
    uint16_t cm = distanceMm / 100;
    if (cm <= LORA_LEGACY_FULL_THRESHOLD)  return TANK_STATE_FULL;
    if (cm >= LORA_LEGACY_LOW_THRESHOLD)   return TANK_STATE_LOW;
    return TANK_STATE_UNKNOWN;
}

// ---------------------------------------------------------------------------
//  Public API
// ---------------------------------------------------------------------------

bool initLoRa() {
    spi2.begin(HSPI_SCLK, HSPI_MISO, HSPI_MOSI, HSPI_SS);
    int state = radio.begin(
        LORA_FREQUENCY,
        LORA_BANDWIDTH,
        LORA_SPREADING_FACTOR,
        LORA_CODING_RATE,
        LORA_SYNC_WORD,
        LORA_TX_POWER,
        LORA_PREAMBLE_LENGTH
    );

    if (state == RADIOLIB_ERR_NONE) {
        loraReady  = true;
        retryCount = 0;
        radio.startReceive();
        Log(INFO, "[LoRa] Initialised successfully");
        loraOperational = true;
    } else {
        loraReady       = false;
        loraOperational = false;
        Log(ERROR, "[LoRa] Init failed, code=" + String(state));
    }
    return loraReady;
}

void pollLoRa() {
    // --- Re-init logic if radio failed ---
    if (!loraReady) {
        if (retryCount >= MAX_LORA_RETRIES) {
            if (millis() - lastReinitMs >= LORA_REINIT_INTERVAL_MS) {
                Log(INFO, "[LoRa] Attempting re-init...");
                lastReinitMs = millis();
                if (initLoRa()) {
                    retryCount = 0;
                    return;
                }
                retryCount = 0;
            }
        }
        return;
    }

    // --- Check for stale OH state ---
    if (lastLoraReceivedTime > 0 &&
        millis() - lastLoraReceivedTime >= LORA_STALE_TIMEOUT_MS &&
        ohTankState != TANK_STATE_UNKNOWN) {
        Log(WARN, "[LoRa] OH tank data stale – marking UNKNOWN");
        ohTankState = TANK_STATE_UNKNOWN;
    }

    // --- Poll radio (non-blocking) ---
    // Read the first byte to determine packet type
    uint8_t buf[8] = {};
    int state = radio.receive(buf, sizeof(buf));

    if (state == RADIOLIB_ERR_NONE) {
        if (!loraOperational) {
            Log(INFO, "[LoRa] Communication restored");
            loraOperational = true;
        }
        retryCount       = 0;
        lastLoraReceivedTime = millis();
        lastRSSI         = radio.getRSSI();
        lastSNR          = radio.getSNR();

        // Flash debug LED
        digitalWrite(DEBUG_LED, HIGH);
        delayMicroseconds(50000); // 50 ms
        digitalWrite(DEBUG_LED, LOW);

        uint8_t pktType = buf[0];
        TankState newState = TANK_STATE_UNKNOWN;

        if (pktType == LORA_PKT_FLOAT_SWITCH && sizeof(FloatPacket) <= sizeof(buf)) {
            FloatPacket* fp = reinterpret_cast<FloatPacket*>(buf);
            if (fp->full) newState = TANK_STATE_FULL;
            else if (fp->low) newState = TANK_STATE_LOW;
            Log(INFO, "[LoRa] Float pkt: low=" + String(fp->low)
                      + " full=" + String(fp->full)
                      + " → " + tankStateStr(newState));
        } else if (pktType == LORA_PKT_DISTANCE && sizeof(DistancePacket) <= sizeof(buf)) {
            DistancePacket* dp = reinterpret_cast<DistancePacket*>(buf);
            newState = stateFromDistance(dp->distance);
            Log(INFO, "[LoRa] Legacy distance pkt: " + String(dp->distance / 100)
                      + "cm → " + tankStateStr(newState));
        } else {
            Log(WARN, "[LoRa] Unknown packet type: 0x" + String(pktType, HEX));
        }

        if (newState != ohTankState) {
            ohTankState = newState;
            addHistoryRecord(HIST_OH_STATE_CHG, ohTankState, ugTankState);
        } else {
            ohTankState = newState;
        }
        radio.startReceive();

    } else if (state == RADIOLIB_ERR_RX_TIMEOUT) {
        // Normal – nothing received this poll
    } else {
        retryCount++;
        Log(WARN, "[LoRa] Receive error " + String(state) + " (retry " + String(retryCount) + ")");
        if (retryCount >= MAX_LORA_RETRIES) {
            loraReady       = false;
            loraOperational = false;
            Log(ERROR, "[LoRa] Too many errors – marking non-operational");
        } else {
            radio.startReceive();
        }
    }
}

bool isLoraOperational() { return loraReady; }
float getLoraRSSI()      { return lastRSSI;  }
float getLoraSNR()       { return lastSNR;   }
