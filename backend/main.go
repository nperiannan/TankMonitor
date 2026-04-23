package main

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/gorilla/websocket"
)

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type Schedule struct {
	I  int    `json:"i"`
	M  string `json:"m"`
	T  string `json:"t"`
	D  uint16 `json:"d"`
	On bool   `json:"on"`
}

type Status struct {
	OHState     string     `json:"oh_state"`
	UGState     string     `json:"ug_state"`
	OHMotor     bool       `json:"oh_motor"`
	UGMotor     bool       `json:"ug_motor"`
	LoraOK      bool       `json:"lora_ok"`
	WiFiRSSI    int        `json:"wifi_rssi"`
	UptimeS     uint64     `json:"uptime_s"`
	FW          string     `json:"fw"`
	Time        string     `json:"time"`
	Schedules   []Schedule `json:"schedules"`
	OHDispOnly  bool       `json:"oh_disp_only"`
	UGDispOnly  bool       `json:"ug_disp_only"`
	UGIgnore    bool       `json:"ug_ignore"`
	BuzzerDelay bool       `json:"buzzer_delay"`
}

// ---------------------------------------------------------------------------
// App state
// ---------------------------------------------------------------------------

var (
	stateMu    sync.RWMutex
	lastStatus []byte // raw JSON, kept for fast broadcast

	upgrader = websocket.Upgrader{
		CheckOrigin: func(r *http.Request) bool { return true },
	}
	clientsMu sync.Mutex
	clients   = make(map[*websocket.Conn]struct{})
	broadcast = make(chan []byte, 64)

	mqttCli mqtt.Client

	// allowedCmds is the whitelist for inbound control requests.
	allowedCmds = map[string]bool{
		"oh_on": true, "oh_off": true,
		"ug_on": true, "ug_off": true,
		"sched_add": true, "sched_remove": true, "sched_clear": true,
		"set_setting": true, "sync_ntp": true, "reboot": true,
	}

	authSecret []byte
)

// ---------------------------------------------------------------------------
// Auth — stateless HMAC-SHA256 signed tokens (no external dependency)
// Token format: base64url(user:expiry) + "." + base64url(hmac-sha256)
// ---------------------------------------------------------------------------

func init() {
	secret := env("AUTH_SECRET", "")
	if secret != "" {
		authSecret = []byte(secret)
	} else {
		b := make([]byte, 32)
		if _, err := rand.Read(b); err != nil {
			panic(err)
		}
		authSecret = b
		log.Println("[AUTH] No AUTH_SECRET set — generated ephemeral secret (tokens invalidated on restart)")
	}
}

// tokenMake returns a signed token valid for 30 days.
func tokenMake(user string) string {
	expiry := strconv.FormatInt(time.Now().Add(30*24*time.Hour).Unix(), 10)
	payload := base64.RawURLEncoding.EncodeToString([]byte(user + ":" + expiry))
	mac := hmac.New(sha256.New, authSecret)
	mac.Write([]byte(payload))
	sig := base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
	return payload + "." + sig
}

// tokenVerify returns (username, true) if the token is valid and not expired.
func tokenVerify(token string) (string, bool) {
	parts := strings.SplitN(token, ".", 2)
	if len(parts) != 2 {
		return "", false
	}
	payload, sig := parts[0], parts[1]
	mac := hmac.New(sha256.New, authSecret)
	mac.Write([]byte(payload))
	expected := base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
	if !hmac.Equal([]byte(sig), []byte(expected)) {
		return "", false
	}
	raw, err := base64.RawURLEncoding.DecodeString(payload)
	if err != nil {
		return "", false
	}
	idx := strings.LastIndex(string(raw), ":")
	if idx < 0 {
		return "", false
	}
	expiry, err := strconv.ParseInt(string(raw[idx+1:]), 10, 64)
	if err != nil || time.Now().Unix() > expiry {
		return "", false
	}
	return string(raw[:idx]), true
}

func extractToken(r *http.Request) string {
	if auth := r.Header.Get("Authorization"); strings.HasPrefix(auth, "Bearer ") {
		return strings.TrimPrefix(auth, "Bearer ")
	}
	return r.URL.Query().Get("token")
}

func requireAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			cors(w)
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if _, ok := tokenVerify(extractToken(r)); !ok {
			cors(w)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			w.Write([]byte(`{"error":"unauthorized"}`)) //nolint:errcheck
			return
		}
		next(w, r)
	}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func controlTopic() string {
	return fmt.Sprintf("tankmonitor/%s/control", env("MQTT_LOCATION", "home"))
}

// ---------------------------------------------------------------------------
// MQTT
// ---------------------------------------------------------------------------

func startMQTT() {
	broker := env("MQTT_BROKER", "localhost")
	port := env("MQTT_PORT", "1883")
	user := env("MQTT_USER", "tankmonitor")
	pass := env("MQTT_PASS", "###TankMonitor12345")
	location := env("MQTT_LOCATION", "home")

	statusTopic := fmt.Sprintf("tankmonitor/%s/status", location)

	opts := mqtt.NewClientOptions().
		AddBroker(fmt.Sprintf("tcp://%s:%s", broker, port)).
		SetClientID("tankmonitor-web").
		SetUsername(user).
		SetPassword(pass).
		SetKeepAlive(60 * time.Second).
		SetAutoReconnect(true).
		SetOnConnectHandler(func(c mqtt.Client) {
			log.Printf("[MQTT] Connected — subscribing %s", statusTopic)
			c.Subscribe(statusTopic, 1, onStatusMsg)
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

func onStatusMsg(_ mqtt.Client, msg mqtt.Message) {
	raw := make([]byte, len(msg.Payload()))
	copy(raw, msg.Payload())

	stateMu.Lock()
	lastStatus = raw
	stateMu.Unlock()

	select {
	case broadcast <- raw:
	default: // drop if hub is backed up
	}
}

func publishControl(body []byte) error {
	if mqttCli == nil || !mqttCli.IsConnected() {
		return fmt.Errorf("MQTT not connected")
	}
	tok := mqttCli.Publish(controlTopic(), 1, false, body)
	tok.Wait()
	return tok.Error()
}

// ---------------------------------------------------------------------------
// WebSocket hub — fans out status updates to all connected browsers
// ---------------------------------------------------------------------------

func hub() {
	for msg := range broadcast {
		clientsMu.Lock()
		for conn := range clients {
			if err := conn.WriteMessage(websocket.TextMessage, msg); err != nil {
				conn.Close()
				delete(clients, conn)
			}
		}
		clientsMu.Unlock()
	}
}

// ---------------------------------------------------------------------------
// HTTP handlers
// ---------------------------------------------------------------------------

func cors(w http.ResponseWriter) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
}

func handleLogin(w http.ResponseWriter, r *http.Request) {
	cors(w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var creds struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&creds); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}
	wantUser := env("AUTH_USER", "admin")
	wantPass := env("AUTH_PASS", "tank1234")
	// Constant-time comparison to prevent timing attacks
	userOK := hmac.Equal([]byte(creds.Username), []byte(wantUser))
	passOK := hmac.Equal([]byte(creds.Password), []byte(wantPass))
	if !userOK || !passOK {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		w.Write([]byte(`{"error":"invalid credentials"}`)) //nolint:errcheck
		return
	}
	token := tokenMake(creds.Username)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"token": token}) //nolint:errcheck
}

func handleWS(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[WS] Upgrade error: %v", err)
		return
	}

	clientsMu.Lock()
	clients[conn] = struct{}{}
	clientsMu.Unlock()

	// Push current status immediately on connect.
	stateMu.RLock()
	cur := lastStatus
	stateMu.RUnlock()
	if cur != nil {
		conn.WriteMessage(websocket.TextMessage, cur) //nolint:errcheck
	}

	// Read loop — detects disconnect.
	for {
		if _, _, err := conn.ReadMessage(); err != nil {
			clientsMu.Lock()
			delete(clients, conn)
			clientsMu.Unlock()
			conn.Close()
			return
		}
	}
}

func handleStatus(w http.ResponseWriter, r *http.Request) {
	cors(w)
	w.Header().Set("Content-Type", "application/json")
	stateMu.RLock()
	cur := lastStatus
	stateMu.RUnlock()
	if cur == nil {
		w.Write([]byte(`{}`)) //nolint:errcheck
		return
	}
	w.Write(cur) //nolint:errcheck
}

func handleControl(w http.ResponseWriter, r *http.Request) {
	cors(w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var body map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}

	cmd, _ := body["cmd"].(string)
	if !allowedCmds[cmd] {
		http.Error(w, "unknown command", http.StatusBadRequest)
		return
	}

	raw, _ := json.Marshal(body)
	if err := publishControl(raw); err != nil {
		http.Error(w, "MQTT error: "+err.Error(), http.StatusServiceUnavailable)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"ok":true}`)) //nolint:errcheck
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

func main() {
	go startMQTT()
	go hub()

	port := env("PORT", "8080")
	staticDir := env("STATIC_DIR", "/app/static")

	mux := http.NewServeMux()
	mux.HandleFunc("/api/login",   handleLogin)
	mux.HandleFunc("/api/status",  requireAuth(handleStatus))
	mux.HandleFunc("/api/control", requireAuth(handleControl))
	mux.HandleFunc("/ws",          requireAuth(handleWS))

	// Serve the React SPA — fall back to index.html for unknown paths.
	fs := http.FileServer(http.Dir(staticDir))
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fullPath := filepath.Join(staticDir, filepath.Clean("/"+r.URL.Path))
		if _, err := os.Stat(fullPath); os.IsNotExist(err) {
			http.ServeFile(w, r, filepath.Join(staticDir, "index.html"))
			return
		}
		fs.ServeHTTP(w, r)
	})

	log.Printf("[HTTP] Listening on :%s  static=%s", port, staticDir)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatal(err)
	}
}
