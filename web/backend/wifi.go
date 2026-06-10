package main

import (
	"net/http"
	"strings"
	"sync"
	"time"
)

var (
	wifiMu   sync.RWMutex
	wifiData = make(map[string]wifiEntry) // mac → entry
)

type wifiEntry struct {
	raw    []byte
	seenAt time.Time
}

func onWifiMsg(topic string, raw []byte) {
	mac := macFromTopic(topic)
	if mac == "" {
		return
	}
	wifiMu.Lock()
	wifiData[mac] = wifiEntry{raw: raw, seenAt: time.Now()}
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
	entry, ok := wifiData[mac]
	wifiMu.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	if !ok || len(entry.raw) == 0 {
		w.Write([]byte(`{"type":"empty","data":{}}`)) //nolint:errcheck
		return
	}
	w.Write(entry.raw) //nolint:errcheck
}
