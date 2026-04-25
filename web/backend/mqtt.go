package main

import (
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"sync"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
)

var mqttCli mqtt.Client

// deviceStatusMu guards per-device last-status cache.
var deviceStatusMu sync.RWMutex
var deviceStatus = make(map[string][]byte) // mac → raw JSON

// allowedCmds is the whitelist for inbound control requests.
var allowedCmds = map[string]bool{
	"oh_on": true, "oh_off": true,
	"ug_on": true, "ug_off": true,
	"sched_add": true, "sched_remove": true, "sched_clear": true,
	"set_setting": true, "sync_ntp": true, "reboot": true,
	"set_lcd_mode": true, "set_log_level": true, "get_logs": true,
	"set_mqtt_creds": true,
	"ota_start":      true, "ota_rollback": true,
}

func startMQTT() {
	broker := env("MQTT_BROKER", "localhost")
	port := env("MQTT_PORT", "1883")
	user := env("MQTT_USER", "tankmonitor")
	pass := env("MQTT_PASS", "###TankMonitor12345")

	opts := mqtt.NewClientOptions().
		AddBroker(fmt.Sprintf("tcp://%s:%s", broker, port)).
		SetClientID("tankmonitor-platform").
		SetUsername(user).
		SetPassword(pass).
		SetKeepAlive(60 * time.Second).
		SetAutoReconnect(true).
		SetOnConnectHandler(func(c mqtt.Client) {
			// Subscribe to ALL device namespaces using + wildcard
			// New topic scheme: tm/+/status, tm/+/logs
			// Legacy topic scheme: tankmonitor/+/status, tankmonitor/+/logs (backward compat)
			subs := map[string]byte{
				"tm/+/status":           1,
				"tm/+/logs":             0,
				"tankmonitor/+/status":  1,
				"tankmonitor/+/logs":    0,
			}
			log.Printf("[MQTT] Connected — subscribing to %d wildcard topics", len(subs))
			c.SubscribeMultiple(subs, onMessage)
		}).
		SetConnectionLostHandler(func(_ mqtt.Client, err error) {
			log.Printf("[MQTT] Connection lost: %v", err)
		})

	mqttCli = mqtt.NewClient(opts)
	for {
		if tok := mqttCli.Connect(); tok.Wait() && tok.Error() == nil {
			break
		}
		log.Println("[MQTT] Connect failed — retrying in 5s…")
		time.Sleep(5 * time.Second)
	}
}

// onMessage handles all incoming MQTT messages from all subscribed topics.
func onMessage(_ mqtt.Client, msg mqtt.Message) {
	topic := msg.Topic()
	raw := make([]byte, len(msg.Payload()))
	copy(raw, msg.Payload())

	if strings.HasSuffix(topic, "/status") {
		onStatusMsg(topic, raw)
	} else if strings.HasSuffix(topic, "/logs") {
		onLogsMsg(topic, raw)
	}
}

func onStatusMsg(topic string, raw []byte) {
	// Parse the minimal fields we need for platform routing
	var fields struct {
		MAC        string `json:"mac"`
		DeviceType string `json:"device_type"`
		FW         string `json:"fw"`
		// OTA detection fields
		// (OTA is now per-device in ota.go)
	}
	if err := json.Unmarshal(raw, &fields); err != nil {
		log.Printf("[MQTT] bad JSON on %s: %v", topic, err)
		return
	}

	mac := fields.MAC
	if mac == "" {
		// Legacy firmware without mac field — derive mac from topic location
		// Topic: tankmonitor/{location}/status — we don't have a real MAC, use location as key
		mac = macFromTopic(topic)
	}
	if mac == "" {
		return
	}

	// Auto-register/update the device in the DB
	upsertDevice(mac, fields.DeviceType, fields.FW)

	// Cache latest status per device
	deviceStatusMu.Lock()
	deviceStatus[mac] = raw
	deviceStatusMu.Unlock()

	// Detect OTA success for this device
	otaOnStatusReceived(mac, fields.FW)

	// Fan out to per-device WebSocket subscribers
	wsHub.broadcast(mac, raw)
}

func onLogsMsg(topic string, raw []byte) {
	mac := macFromTopic(topic)
	if mac == "" {
		return
	}
	logsStore(mac, raw)
}

// publishControl publishes a control command to the correct device topic.
func publishControl(mac string, body []byte) error {
	if mqttCli == nil || !mqttCli.IsConnected() {
		return fmt.Errorf("MQTT not connected")
	}
	// Determine which topic scheme the device uses by checking if it has a real MAC
	// New firmware uses tm/{mac}/control; legacy uses tankmonitor/{location}/control
	var topic string
	if isRealMAC(mac) {
		topic = fmt.Sprintf("tm/%s/control", mac)
	} else {
		// Legacy: mac field holds the location string
		topic = fmt.Sprintf("tankmonitor/%s/control", mac)
	}
	tok := mqttCli.Publish(topic, 1, false, body)
	tok.Wait()
	return tok.Error()
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// macFromTopic extracts the device identifier from a topic.
// tm/AA:BB:CC:DD:EE:FF/status → AA:BB:CC:DD:EE:FF
// tankmonitor/home/status     → home (legacy)
func macFromTopic(topic string) string {
	parts := strings.Split(topic, "/")
	if len(parts) >= 3 {
		return parts[1]
	}
	return ""
}

// isRealMAC returns true if the string looks like a MAC address (AA:BB:CC:DD:EE:FF).
func isRealMAC(s string) bool {
	if len(s) != 17 {
		return false
	}
	for i, c := range s {
		if i%3 == 2 {
			if c != ':' {
				return false
			}
		} else {
			if !((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f')) {
				return false
			}
		}
	}
	return true
}
