package main

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"
)

var (
	wifiMu       sync.RWMutex
	wifiCache    = make(map[string]wifiEntry) // mac → latest wifi_list / wifi_scan
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

	// Persist history snapshots to the DB so they can be served instantly and
	// survive restarts (idempotent — dedups by mac+ts+ev).
	if isHistory {
		persistHistory(mac, raw)
	}
}

// persistHistory stores each record from a history_list payload into the DB.
func persistHistory(mac string, raw []byte) {
	var msg struct {
		Data struct {
			Records []json.RawMessage `json:"records"`
		} `json:"data"`
	}
	if err := json.Unmarshal(raw, &msg); err != nil || len(msg.Data.Records) == 0 {
		return
	}
	tx, err := db.Begin()
	if err != nil {
		return
	}
	stmt, err := tx.Prepare(`INSERT OR IGNORE INTO history_events(mac, ts, ev, record) VALUES(?,?,?,?)`)
	if err != nil {
		tx.Rollback() //nolint:errcheck
		return
	}
	for _, rec := range msg.Data.Records {
		var meta struct {
			TS int64  `json:"ts"`
			EV string `json:"ev"`
		}
		if json.Unmarshal(rec, &meta) != nil || meta.TS == 0 {
			continue
		}
		stmt.Exec(strings.ToUpper(mac), meta.TS, meta.EV, string(rec)) //nolint:errcheck
	}
	stmt.Close() //nolint:errcheck
	tx.Commit()  //nolint:errcheck
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
// Serves persisted history events from the DB (fast, survives restarts).
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
	if r.Method == http.MethodDelete {
		db.Exec(`DELETE FROM history_events WHERE UPPER(mac)=UPPER(?)`, mac) //nolint:errcheck
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"ok":true}`)) //nolint:errcheck
		return
	}

	rows, err := db.Query(
		`SELECT record FROM history_events WHERE UPPER(mac)=UPPER(?) ORDER BY ts DESC LIMIT 1000`, mac)
	if err != nil {
		jsonError(w, "db error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()
	records := make([]string, 0, 256)
	for rows.Next() {
		var rec string
		if rows.Scan(&rec) == nil {
			records = append(records, rec)
		}
	}

	var b strings.Builder
	b.WriteString(`{"type":"history_list","data":{"count":`)
	b.WriteString(strconv.Itoa(len(records)))
	b.WriteString(`,"eeprom":true,"records":[`)
	b.WriteString(strings.Join(records, ","))
	b.WriteString(`]}}`)
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(b.String())) //nolint:errcheck
}
