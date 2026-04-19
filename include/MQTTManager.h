#ifndef MQTT_MANAGER_H
#define MQTT_MANAGER_H

// Initialise MQTT client — loads config from NVS (seeds defaults on first boot).
// Call once from setup(), after initWiFi().
void initMQTT();

// Non-blocking MQTT maintenance: reconnect if disconnected, call client.loop(),
// publish periodic status. Call every loop() iteration.
void mqttLoop();

// Publish current tank/motor state as a retained JSON message to the status topic.
// Safe to call even when disconnected (no-op).
void publishMQTTStatus();

#endif // MQTT_MANAGER_H
