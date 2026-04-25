package main

import (
	"database/sql"
	"log"

	_ "modernc.org/sqlite"
)

var db *sql.DB

const dbPath = "/data/tankmonitor.db"

func initDB() {
	var err error
	db, err = sql.Open("sqlite", dbPath+"?_journal_mode=WAL&_foreign_keys=on")
	if err != nil {
		log.Fatalf("[DB] open: %v", err)
	}
	if err = db.Ping(); err != nil {
		log.Fatalf("[DB] ping: %v", err)
	}
	migrate()
	seedDeviceTypes()
	log.Printf("[DB] Ready — %s", dbPath)
}

func migrate() {
	stmts := []string{
		`CREATE TABLE IF NOT EXISTS device_types (
			type_id      TEXT PRIMARY KEY,
			display_name TEXT NOT NULL,
			vendor       TEXT NOT NULL,
			capabilities TEXT NOT NULL DEFAULT '[]'
		)`,
		`CREATE TABLE IF NOT EXISTS users (
			user_id       INTEGER PRIMARY KEY AUTOINCREMENT,
			username      TEXT    UNIQUE NOT NULL,
			password_hash TEXT    NOT NULL,
			is_admin      INTEGER NOT NULL DEFAULT 0,
			created_at    TEXT    DEFAULT (datetime('now'))
		)`,
		`CREATE TABLE IF NOT EXISTS devices (
			mac          TEXT PRIMARY KEY,
			type_id      TEXT REFERENCES device_types(type_id),
			display_name TEXT,
			fw_version   TEXT,
			last_seen    TEXT,
			created_at   TEXT DEFAULT (datetime('now'))
		)`,
		`CREATE TABLE IF NOT EXISTS user_devices (
			user_id INTEGER NOT NULL REFERENCES users(user_id)  ON DELETE CASCADE,
			mac     TEXT    NOT NULL REFERENCES devices(mac)    ON DELETE CASCADE,
			role    TEXT    NOT NULL DEFAULT 'owner',
			PRIMARY KEY (user_id, mac)
		)`,
		// Index for fast per-user device lookups
		`CREATE INDEX IF NOT EXISTS idx_user_devices_user ON user_devices(user_id)`,
	}
	for _, s := range stmts {
		if _, err := db.Exec(s); err != nil {
			log.Fatalf("[DB] migrate: %v\nSQL: %s", err, s)
		}
	}
}

func seedDeviceTypes() {
	types := []struct {
		id, name, vendor, caps string
	}{
		{
			"tank_monitor",
			"Tank Monitor",
			"TankMonitor Project",
			`["oh_motor","ug_motor","buzzer","float_switch","lora","schedules"]`,
		},
		{
			"smart_ups",
			"Smart UPS",
			"Generic",
			`["battery_pct","load_pct","output_voltage","runtime_min"]`,
		},
	}
	for _, t := range types {
		_, err := db.Exec(`
			INSERT INTO device_types(type_id, display_name, vendor, capabilities)
			VALUES(?,?,?,?)
			ON CONFLICT(type_id) DO NOTHING`,
			t.id, t.name, t.vendor, t.caps)
		if err != nil {
			log.Printf("[DB] seed device_type %s: %v", t.id, err)
		}
	}
}
