#ifndef MOTOR_CONTROL_H
#define MOTOR_CONTROL_H

#include <Arduino.h>

// Initialise relay GPIO pins (OUTPUT, relay OFF at boot).
void initMotorPins();

// Load display-only / ignore-UG settings from NVS.
void loadMotorConfig();

// Save current display-only / ignore-UG settings to NVS.
void saveMotorConfig();

// Run automatic OH motor control based on ohTankState.
// Call from loop() whenever ohTankState may have changed.
void autoControlOHMotor();

// Run automatic UG motor control based on ugTankState.
// Call from loop() whenever ugTankState may have changed.
void autoControlUGMotor();

// Manual motor commands (from BLE / web UI).
void turnOnOHMotor();
void turnOffOHMotor();
void turnOnUGMotor();
void turnOffUGMotor();

// Check and handle pending motor starts (after buzzer delay).
void processPendingMotorStarts();

#endif // MOTOR_CONTROL_H
