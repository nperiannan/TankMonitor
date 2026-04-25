package main

// legacy.go — shim routes for the old React web frontend (v1.x).
//
// The original single-device API is preserved by auto-selecting the first
// device the authenticated user has claimed.  If no device is claimed the
// caller receives a 404 JSON error.
//
//  Old route                   →  New per-device route
//  ─────────────────────────────────────────────────────
//  WS  /ws                     →  WS /ws/{mac}
//  POST /api/control           →  POST /api/devices/{mac}/control
//  GET  /api/ota/status        →  GET  /api/devices/{mac}/ota/status
//  POST /api/ota/upload        →  POST /api/devices/{mac}/ota/upload
//  POST /api/ota/trigger       →  POST /api/devices/{mac}/ota/trigger
//  POST /api/ota/rollback      →  POST /api/devices/{mac}/ota/rollback
//  GET  /api/logs              →  GET  /api/devices/{mac}/logs

import "net/http"

// firstClaimedMAC returns the first device MAC the user has claimed, or "".
func firstClaimedMAC(uid int64) string {
	var mac string
	db.QueryRow( //nolint:errcheck
		`SELECT mac FROM user_devices WHERE user_id=? LIMIT 1`, uid,
	).Scan(&mac)
	return mac
}

// rewritePath clones the request and sets a new URL path.
func rewritePath(r *http.Request, path string) *http.Request {
	r2 := r.Clone(r.Context())
	r2.URL.Path = path
	return r2
}

// legacyDevice resolves the first claimed MAC for the authenticated user.
// Returns ("", false) and writes a 404 JSON error if nothing is claimed.
func legacyDevice(w http.ResponseWriter, r *http.Request) (string, bool) {
	mac := firstClaimedMAC(userIDFromRequest(r))
	if mac == "" {
		jsonError(w, "no device claimed — claim a device first", http.StatusNotFound)
		return "", false
	}
	return mac, true
}

// handleLegacyWS  /ws?token=...  →  /ws/{mac}?token=...
func handleLegacyWS(w http.ResponseWriter, r *http.Request) {
	mac, ok := legacyDevice(w, r)
	if !ok {
		return
	}
	handleWS(w, rewritePath(r, "/ws/"+mac))
}

// handleLegacyControl  POST /api/control  →  POST /api/devices/{mac}/control
func handleLegacyControl(w http.ResponseWriter, r *http.Request) {
	mac, ok := legacyDevice(w, r)
	if !ok {
		return
	}
	handleDeviceControl(w, rewritePath(r, "/api/devices/"+mac+"/control"))
}

// handleLegacyOtaStatus  GET /api/ota/status  →  GET /api/devices/{mac}/ota/status
func handleLegacyOtaStatus(w http.ResponseWriter, r *http.Request) {
	mac, ok := legacyDevice(w, r)
	if !ok {
		return
	}
	handleOtaStatus(w, rewritePath(r, "/api/devices/"+mac+"/ota/status"))
}

// handleLegacyOtaUpload  POST /api/ota/upload  →  POST /api/devices/{mac}/ota/upload
func handleLegacyOtaUpload(w http.ResponseWriter, r *http.Request) {
	mac, ok := legacyDevice(w, r)
	if !ok {
		return
	}
	handleOtaUpload(w, rewritePath(r, "/api/devices/"+mac+"/ota/upload"))
}

// handleLegacyOtaTrigger  POST /api/ota/trigger  →  POST /api/devices/{mac}/ota/trigger
func handleLegacyOtaTrigger(w http.ResponseWriter, r *http.Request) {
	mac, ok := legacyDevice(w, r)
	if !ok {
		return
	}
	handleOtaTrigger(w, rewritePath(r, "/api/devices/"+mac+"/ota/trigger"))
}

// handleLegacyOtaRollback  POST /api/ota/rollback  →  POST /api/devices/{mac}/ota/rollback
func handleLegacyOtaRollback(w http.ResponseWriter, r *http.Request) {
	mac, ok := legacyDevice(w, r)
	if !ok {
		return
	}
	handleOtaRollback(w, rewritePath(r, "/api/devices/"+mac+"/ota/rollback"))
}

// handleLegacyLogs  GET /api/logs  →  GET /api/devices/{mac}/logs
func handleLegacyLogs(w http.ResponseWriter, r *http.Request) {
	mac, ok := legacyDevice(w, r)
	if !ok {
		return
	}
	handleDeviceLogs(w, rewritePath(r, "/api/devices/"+mac+"/logs"))
}
