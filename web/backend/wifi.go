package main

import (
	"net/http"
	"strings"
	"sync"
	"time"
)

var (
	wifiMu      sync.RWMutex
	wifiCache   = make(map[string]wifiEntry) // mac → latest wifi_list / wifi_scan
	historyCache = make(map[string]wifiEntry) // mac → latest history_list
)

type wifiEntry struct {
	raw    []byte
	seenAt time.Time
}

// onWifiMsg routes incoming tm/{mac}/wifi messages to the correct cache
// based on the "type" field in the JSON payload.
func onWifiMsg(topic string, raw []byte) {
	mac := macFromTopic(topic)
	if mac == "" {
		return
	}
	// Determine type from payload (fast prefix scan — avoids full JSON parse)
	rawStr := string(raw)
	isHistory := strings.Contains(rawStr, `"type":"history_list"`)

	wifiMu.Lock()
	if isHistory {
		historyCache[mac] = wifiEntry{raw: raw, seenAt: time.Now()}
	} else {
		wifiCache[mac] = wifiEntry{raw: raw, seenAt: time.Now()}
	}
	wifiMu.Unlock()
}

// handleDeviceWifi serves GET /api/devices/{mac}/wifi
// Returns the last WiFi response published by the device.
func handleDeviceWifi(w http.ResponseWriter, r *http.Request) {
	cors(w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	uid := userIDFromRequest(r)
	mac := strings.ToUpper(macFromPath(r.URL.Path, "/api/devices/"))
	if idx := strings.Index(mac, "/"); idx >= 0 {
		mac = mac[:idx]
	}
	if !canAccessDevice(uid, mac) {
		jsonError(w, "forbidden", http.StatusForbidden)
		return
	}

	wifiMu.RLock()
	entry, ok := wifiCache[mac]
	wifiMu.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	if !ok || len(entry.raw) == 0 {
		w.Write([]byte(`{"type":"empty","data":{}}`)) //nolint:errcheck
		return
	}
	w.Write(entry.raw) //nolint:errcheck
}

// handleDeviceHistory serves GET /api/devices/{mac}/history
// Returns the last history_list response published by the device.
func handleDeviceHistory(w http.ResponseWriter, r *http.Request) {
	cors(w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	uid := userIDFromRequest(r)
	mac := strings.ToUpper(macFromPath(r.URL.Path, "/api/devices/"))
	if idx := strings.Index(mac, "/"); idx >= 0 {
		mac = mac[:idx]
	}
	if !canAccessDevice(uid, mac) {
		jsonError(w, "forbidden", http.StatusForbidden)
		return
	}

	wifiMu.RLock()
	entry, ok := historyCache[mac]
	wifiMu.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	if !ok || len(entry.raw) == 0 {
		w.Write([]byte(`{"type":"history_list","data":{"count":0,"eeprom":false,"records":[]}}`)) //nolint:errcheck
		return
	}
	w.Write(entry.raw) //nolint:errcheck
}
