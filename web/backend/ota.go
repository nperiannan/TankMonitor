package main

import (
	"encoding/json"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
)

// Per-device OTA state
type OtaInfo struct {
	HasFirmware bool   `json:"has_firmware"`
	Filename    string `json:"filename"`
	Size        int64  `json:"size"`
	UploadedAt  string `json:"uploaded_at"`
	Phase       string `json:"phase"` // idle | triggered | downloading | success | failed
	PrevFw      string `json:"prev_fw,omitempty"`
}

var (
	otaMu   sync.RWMutex
	otaInfo = make(map[string]*OtaInfo) // mac → OtaInfo
)

const otaDir = "/tmp/ota"

func otaFilePath(mac string) string {
	// Sanitise mac for filesystem use (replace : with -)
	return otaDir + "/" + strings.ReplaceAll(mac, ":", "-") + ".bin"
}

// otaOnStatusReceived is called by mqtt.go on every status message.
func otaOnStatusReceived(mac, fw string) {
	otaMu.Lock()
	defer otaMu.Unlock()
	info := otaInfo[mac]
	if info == nil {
		return
	}
	if (info.Phase == "triggered" || info.Phase == "downloading") && fw != "" && fw != info.PrevFw {
		info.Phase = "success"
		log.Printf("[OTA] %s: success — fw changed %s → %s", mac, info.PrevFw, fw)
	}
}

// ---------------------------------------------------------------------------
// HTTP handlers — all scoped to /api/devices/{mac}/ota/...
// ---------------------------------------------------------------------------

func handleOtaStatus(w http.ResponseWriter, r *http.Request) {
	cors(w)
	mac := otaMacFromPath(r.URL.Path)
	otaMu.RLock()
	info := otaInfo[mac]
	otaMu.RUnlock()
	w.Header().Set("Content-Type", "application/json")
	if info == nil {
		json.NewEncoder(w).Encode(OtaInfo{Phase: "idle"}) //nolint:errcheck
		return
	}
	json.NewEncoder(w).Encode(*info) //nolint:errcheck
}

func handleOtaUpload(w http.ResponseWriter, r *http.Request) {
	cors(w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	mac := otaMacFromPath(r.URL.Path)

	if err := r.ParseMultipartForm(64 << 20); err != nil {
		http.Error(w, "file too large or invalid form", http.StatusBadRequest)
		return
	}
	file, header, err := r.FormFile("firmware")
	if err != nil {
		http.Error(w, "missing firmware field", http.StatusBadRequest)
		return
	}
	defer file.Close()

	if !strings.HasSuffix(strings.ToLower(header.Filename), ".bin") {
		http.Error(w, "only .bin files accepted", http.StatusBadRequest)
		return
	}

	if err := os.MkdirAll(otaDir, 0755); err != nil {
		http.Error(w, "storage error", http.StatusInternalServerError)
		return
	}
	dest, err := os.Create(otaFilePath(mac))
	if err != nil {
		http.Error(w, "storage error", http.StatusInternalServerError)
		return
	}
	defer dest.Close()
	written, err := io.Copy(dest, file)
	if err != nil {
		http.Error(w, "write error", http.StatusInternalServerError)
		return
	}

	otaMu.Lock()
	otaInfo[mac] = &OtaInfo{
		HasFirmware: true,
		Filename:    header.Filename,
		Size:        written,
		UploadedAt:  time.Now().UTC().Format(time.RFC3339),
		Phase:       "idle",
	}
	otaMu.Unlock()

	log.Printf("[OTA] %s: firmware uploaded %s (%d bytes)", mac, header.Filename, written)
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"ok":true}`)) //nolint:errcheck
}

func handleOtaTrigger(w http.ResponseWriter, r *http.Request) {
	cors(w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	mac := otaMacFromPath(r.URL.Path)

	otaMu.RLock()
	info := otaInfo[mac]
	otaMu.RUnlock()
	if info == nil || !info.HasFirmware {
		http.Error(w, "no firmware staged for this device", http.StatusBadRequest)
		return
	}

	var firmwareURL string
	if base := env("OTA_BASE_URL", ""); base != "" {
		firmwareURL = strings.TrimRight(base, "/") + "/api/devices/" + mac + "/ota/firmware.bin"
	} else {
		host := r.Header.Get("X-Forwarded-Host")
		if host == "" {
			host = r.Host
		}
		scheme := "http"
		if r.Header.Get("X-Forwarded-Proto") == "https" || r.TLS != nil {
			scheme = "https"
		}
		firmwareURL = scheme + "://" + host + "/api/devices/" + mac + "/ota/firmware.bin"
	}

	payload, _ := json.Marshal(map[string]interface{}{"cmd": "ota_start", "url": firmwareURL})
	if err := publishControl(mac, payload); err != nil {
		http.Error(w, "MQTT error: "+err.Error(), http.StatusServiceUnavailable)
		return
	}
	log.Printf("[OTA] %s: triggered — URL: %s", mac, firmwareURL)

	// Capture current fw for change detection
	deviceStatusMu.RLock()
	var curSt struct{ FW string `json:"fw"` }
	json.Unmarshal(deviceStatus[mac], &curSt) //nolint:errcheck
	deviceStatusMu.RUnlock()

	otaMu.Lock()
	otaInfo[mac].Phase = "triggered"
	otaInfo[mac].PrevFw = curSt.FW
	otaMu.Unlock()

	// Auto-fail after 120 s
	go func() {
		time.Sleep(120 * time.Second)
		otaMu.Lock()
		if i := otaInfo[mac]; i != nil && (i.Phase == "triggered" || i.Phase == "downloading") {
			i.Phase = "failed"
			log.Printf("[OTA] %s: timeout — marking failed", mac)
		}
		otaMu.Unlock()
	}()

	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"ok":true}`)) //nolint:errcheck
}

func handleOtaRollback(w http.ResponseWriter, r *http.Request) {
	cors(w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	mac := otaMacFromPath(r.URL.Path)
	payload, _ := json.Marshal(map[string]string{"cmd": "ota_rollback"})
	if err := publishControl(mac, payload); err != nil {
		http.Error(w, "MQTT error: "+err.Error(), http.StatusServiceUnavailable)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"ok":true}`)) //nolint:errcheck
}

// handleOtaServeFirmware serves GET /api/devices/{mac}/ota/firmware.bin
// No auth — ESP32 downloads without token support.
func handleOtaServeFirmware(w http.ResponseWriter, r *http.Request) {
	mac := otaMacFromPath(r.URL.Path)
	otaMu.RLock()
	info := otaInfo[mac]
	otaMu.RUnlock()
	if info == nil || !info.HasFirmware {
		http.Error(w, "no firmware", http.StatusNotFound)
		return
	}
	log.Printf("[OTA] %s: serving firmware to %s", mac, r.RemoteAddr)
	otaMu.Lock()
	if otaInfo[mac].Phase == "triggered" {
		otaInfo[mac].Phase = "downloading"
	}
	otaMu.Unlock()
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Disposition", `attachment; filename="firmware.bin"`)
	http.ServeFile(w, r, otaFilePath(mac))
}

func otaMacFromPath(path string) string {
	// /api/devices/{mac}/ota/... → mac
	after := strings.TrimPrefix(path, "/api/devices/")
	if idx := strings.Index(after, "/"); idx >= 0 {
		return strings.ToUpper(after[:idx])
	}
	return strings.ToUpper(after)
}
