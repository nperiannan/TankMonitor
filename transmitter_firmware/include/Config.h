#ifndef CONFIG_H
#define CONFIG_H

// =============================================================================
//                           FIRMWARE VERSION
// =============================================================================
#define FW_VERSION "1.0.0"

// =============================================================================
//                    LORA RADIO PARAMETERS
//   Must match controller_firmware/include/Config.h exactly.
// =============================================================================
#define LORA_FREQUENCY          865E6    // Hz
#define LORA_BANDWIDTH          125E3    // Hz
#define LORA_SPREADING_FACTOR       9
#define LORA_CODING_RATE            7    // 4/7
#define LORA_SYNC_WORD           0x34
#define LORA_TX_POWER              20    // dBm
#define LORA_PREAMBLE_LENGTH        8

// =============================================================================
//                    SPI / LORA PINS  (RFM95 on ATmega328P hardware SPI)
// =============================================================================
#define LORA_SS_PIN    10
#define LORA_RST_PIN    9
#define LORA_DIO0_PIN   2

// =============================================================================
//                    PACKET TYPE  (must match controller_firmware Config.h)
// =============================================================================
#define LORA_PKT_FLOAT_SWITCH  0x02

// =============================================================================
//                    FLOAT SWITCH INPUT PIN
//
//   Reuses A2 (echo pin from original HC-SR04T wiring) to avoid rewiring.
//   A1 (trigger pin) is left unused / floating.
//
//   Wiring:
//     Switch NO  → 3.3 V
//     Switch NC  → GND
//     Switch COM → FLOAT_FULL_PIN  (A2)
//
//   When tank is FULL  the float tilts, COM connects to NO → pin reads HIGH (1)
//   When tank is LOW   the float rests, COM connects to NC → pin reads LOW  (0)
// =============================================================================
#define FLOAT_FULL_PIN  A2   // COM of float switch – reuses old echo pin (A2)

// =============================================================================
//                    TRANSMIT INTERVAL
// =============================================================================
#define TX_INTERVAL_MS  5000UL   // 5 seconds

#endif // CONFIG_H
