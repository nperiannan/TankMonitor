#ifndef CONFIG_H
#define CONFIG_H

// =============================================================================
//                              FIRMWARE VERSION
// =============================================================================
#define FW_VERSION "1.3.0"

// =============================================================================
//                              I2C CONFIGURATION
// =============================================================================
#define SDA_PIN     18
#define SCL_PIN     17

#define LCD_ADDRESS  0x27
#define LCD_COLUMNS  16
#define LCD_ROWS      2

// =============================================================================
//                              SPI / LORA PINS  (RFM95/96 on HSPI)
// =============================================================================
#define HSPI_MISO  12
#define HSPI_MOSI  11
#define HSPI_SCLK  13
#define HSPI_SS    10
#define LORA_CS    10
#define LORA_IRQ   14
#define LORA_RST   21
#define LORA_DIO1   8

// LoRa radio parameters  (must match the remote OH-tank node)
#define LORA_FREQUENCY          865.0f
#define LORA_BANDWIDTH          125.0f
#define LORA_SPREADING_FACTOR     9
#define LORA_CODING_RATE          7
#define LORA_SYNC_WORD         0x34
#define LORA_TX_POWER            20
#define LORA_PREAMBLE_LENGTH      8

// Packet type bytes
#define LORA_PKT_FLOAT_SWITCH  0x02   // New: float switch state
#define LORA_PKT_DISTANCE      0x01   // Legacy: ultrasonic distance (backward compat)

// If a legacy distance packet is received, treat as FULL below this threshold (cm)
#define LORA_LEGACY_FULL_THRESHOLD   50
#define LORA_LEGACY_LOW_THRESHOLD   150

// =============================================================================
//                              RELAY / MOTOR PINS
// =============================================================================
#define OH_RELAY_PIN  1    // RLY1 – Overhead tank motor
#define UG_RELAY_PIN  2    // RLY2 – Underground tank motor

// Relay logic: HIGH = motor ON
#define RELAY_ON   HIGH
#define RELAY_OFF  LOW

// =============================================================================
//                              UG TANK FLOAT SWITCH PINS
// =============================================================================
// Single-pin wiring (3-wire float switch):
//   NC  ──── GND
//   COM ──── GPIO 41  (INPUT_PULLUP)
//   NO  ──── 3.3 V
// Float UP   (tank FULL)  → COM→NO 3.3V  → pin HIGH
// Float DOWN (tank EMPTY) → COM→NC GND   → pin LOW  (GND overrides pullup)
// Disconnected/wire loose → pullup holds HIGH = FULL  (safe: motor stays off)
#define UG_FLOAT_PIN  42

// =============================================================================
//                              OTHER HARDWARE PINS
// =============================================================================
#define BUZZER_PIN   3
#define DEBUG_LED   38

// =============================================================================
//                              TOUCH SWITCH PINS (TTP223)
// =============================================================================
// TTP223 default mode: A=open, B=open → momentary HIGH while touched.
// We detect rising edge (LOW→HIGH) to toggle the motor.
#define TOUCH_OH_PIN   41   // OH motor toggle (TTP223 I/O → GPIO41)
#define TOUCH_UG_PIN   40   // UG motor toggle (TTP223 I/O → GPIO40)
#define TOUCH_DEBOUNCE_MS  50UL   // Ignore re-trigger within 50 ms

// =============================================================================
//                              TIMING CONSTANTS (ms)
// =============================================================================
#define FLOAT_DEBOUNCE_MS         3000UL   // 3 s debounce for float switch state change
#define UG_SENSOR_POLL_MS         5000UL   // Poll UG float switch every 5 s
#define LCD_SCREEN_DURATION_MS    5000UL   // Each LCD screen visible for 5 s
#define LORA_STALE_TIMEOUT_MS   120000UL   // OH tank state stale after 2 min with no LoRa
#define MAX_LORA_RETRIES              3
#define LORA_REINIT_INTERVAL_MS   60000UL
#define WIFI_CHECK_INTERVAL_MS    30000UL
#define WIFI_ATTEMPT_TIMEOUT_MS   10000UL   // wait up to 10 s per connection attempt
#define WIFI_MAX_ATTEMPTS_PER_NET 3          // attempts per SSID before trying next
#define WIFI_COOLDOWN_MS          900000UL   // 15-min pause after all SSIDs fail
#define NTP_SYNC_INTERVAL_MS    3600000UL
#define BLE_STATUS_INTERVAL_MS    5000UL
#define BUZZER_MAX_DURATION_MS      35000UL   // Auto-stop buzzer after 35 s
#define MOTOR_START_BUZZER_DELAY_MS 30000UL   // Buzz 30 s before motor starts
#define BOOT_GRACE_PERIOD_MS        20000UL   // Auto-control & scheduler suppressed for 20 s after boot

// =============================================================================
//                              BLE CONFIGURATION
// =============================================================================
// UUIDs must match the Flutter mobile app.
#define BLE_SERVICE_UUID       "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define BLE_TX_CHARACTERISTIC  "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define BLE_RX_CHARACTERISTIC  "beb5483e-36e1-4688-b7f5-ea07361b26a9"
#define BLE_DEVICE_NAME        "TankMonitor"

// BLE command strings (phone → ESP32)
#define CMD_GET_STATUS   "GET_STATUS"
#define CMD_MOTOR_OH_ON  "MOTOR_OH_ON"
#define CMD_MOTOR_OH_OFF "MOTOR_OH_OFF"
#define CMD_MOTOR_UG_ON  "MOTOR_UG_ON"
#define CMD_MOTOR_UG_OFF "MOTOR_UG_OFF"
#define CMD_GET_CONFIG   "GET_CONFIG"
#define CMD_SET_CONFIG   "SET_CONFIG"
#define CMD_SYNC_TIME    "SYNC_TIME"
#define CMD_BUZZER_ON    "BUZZER_ON"
#define CMD_BUZZER_OFF   "BUZZER_OFF"

// =============================================================================
//                              NVS NAMESPACES & KEYS
// =============================================================================
#define NVS_WIFI_NS       "wifi_config"
#define NVS_MOTOR_NS      "motor_cfg"
#define NVS_DISPLAY_NS    "display_cfg"
#define NVS_BUZZER_NS     "buzzer_cfg"
#define NVS_BLE_NS        "tank_settings"

#define NVS_KEY_WIFI_JSON      "wifi_json"       // JSON array of {ssid,pass} in NVS_WIFI_NS
#define NVS_KEY_WIFI_MODE      "ap_mode"
#define NVS_KEY_OH_DISP_ONLY   "oh_disp_only"
#define NVS_KEY_UG_DISP_ONLY   "ug_disp_only"
#define NVS_KEY_UG_IGNORE      "ug_ignore"       // Ignore UG state when deciding OH motor
#define NVS_KEY_BUZZER_DELAY   "buzzer_delay"    // Buzz before motor start
#define NVS_KEY_BLE_ENABLED    "ble_enabled"
#define NVS_KEY_LCD_BL_MODE    "lcd_bl_mode"

// LCD backlight modes
#define LCD_BL_AUTO       0   // Off 7:00 AM – 5:30 PM, On at night (default)
#define LCD_BL_ALWAYS_ON  1   // Always on
#define LCD_BL_ALWAYS_OFF 2   // Always off

// =============================================================================
//                              EEPROM (AT24C512 / 24T512) - I2C
// =============================================================================
#define EEPROM_I2C_ADDR    0x50      // Default I2C address (A2..A0 = GND → 0x50-0x57)
#define EEPROM_PAGE_SIZE   128       // Bytes per page for AT24C512
#define EEPROM_SIZE_BYTES  65536     // 512 kbit = 64 KB

// History circular buffer layout inside EEPROM:
//   Addr 0-7  : Header  (magic[2] + head[2] + count[2] + rsvd[2])
//   Addr 8+   : Records (8 bytes each, 8191 records max)
#define HIST_HEADER_ADDR   0
#define HIST_DATA_ADDR     8
// HIST_MAX_RECORDS is computed in History.cpp to avoid sizeof in header macros

// =============================================================================
//                              MQTT CONFIGURATION
// =============================================================================
// Credentials are seeded into NVS on first boot; change via web UI or redefine here.
#define MQTT_BROKER_DEFAULT   "nperiannan-nas.freemyip.com"
#define MQTT_PORT_DEFAULT     1883
#define MQTT_USER_DEFAULT     "tankmonitor"
#define MQTT_PASS_DEFAULT     "###TankMonitor12345"
#define MQTT_LOCATION_DEFAULT "home"          // Used in topic: tankmonitor/<location>/...

#define MQTT_NVS_NS           "mqtt_cfg"
#define MQTT_PUBLISH_MS       5000UL          // Publish status every 5 s
#define MQTT_RECONNECT_MS     15000UL         // Retry connection every 15 s

// =============================================================================
//                              WIFI DEFAULTS
// =============================================================================
#define DEFAULT_AP_SSID      "TankMonitor"
#define DEFAULT_AP_PASSWORD  "tank1234"
#define MAX_WIFI_NETWORKS        5
#define WIFI_RECONNECT_DELAY_MS  5000UL
#define MAX_WIFI_CONNECT_ATTEMPTS   20

// =============================================================================
//                              LCD SCHEDULE DEFAULTS
// =============================================================================
#define DEFAULT_LCD_ON_TIME   "17:30"
#define DEFAULT_LCD_OFF_TIME  "06:30"

#endif // CONFIG_H
