/**
 * WiFiCloudSwitch — RadioKit Example
 *
 * Demonstrates all three transports active simultaneously:
 *   - BLE: local control via the RadioKit companion app
 *   - WiFi: local WebSocket server on port 5555 (AP or STA mode)
 *   - Cloud: outbound relay connection (optional, requires cloud_url)
 *
 * A rocker switch toggles the built-in LED over any connected transport.
 * The LED state is synchronised across all transports automatically via
 * the RadioKit broadcast model.
 *
 * Hardware:
 *   - lolin_s3_mini (ESP32-S3) with built-in LED on GPIO 2
 *   - Rocker switch widget controls the LED
 *
 * Build requirements:
 *   - platformio.ini must include -D RADIOKIT_ENABLE_WIFI
 *   - arduinoWebSockets library is auto-fetched via library.properties
 *
 * Usage:
 *   1. Flash to ESP32-S3
 *   2. Connect via BLE: Open RadioKit app, scan, connect to "RK_WiFi_Cloud_Switch"
 *   3. Connect via WiFi: Connect to AP "RK_WiFi_Cloud_Switch" or join the STA network,
 *      then open RadioKit app WiFi tab and connect to ws://<device-ip>:5555
 *   4. Connect via Cloud: Set cloud_url in initRadioKit(), deploy relay server,
 *      and connect from the app's Cloud tab
 *   5. Tap the switch to toggle the LED — changes sync across all transports
 */

#include <Arduino.h>
#include "RADIOKIT.h"

// ── Pin definitions ───────────────────────────────────────────
#define LED_PIN       2

// ────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(2000);  // Allow USB CDC enumeration
  Serial.println("--- RadioKit WiFiCloudSwitch Start ---");

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  led_1.rk.state = false;

  initRadioKit();

  Serial.println("RadioKit: Setup complete.");
  Serial.println("RadioKit: BLE + WiFi transports active (Cloud disabled for local test).");
}

// ── State tracking ────────────────────────────────────────────
static bool lastSwitchState = false;

// ────────────────────────────────────────────────────────────
void loop() {
  RadioKit.update();

  // Sync LED from the switch widget (works over any transport)
  bool switchNow = slide_switch_1.rk.state;
  if (switchNow != lastSwitchState) {
    lastSwitchState = switchNow;
    digitalWrite(LED_PIN, switchNow ? HIGH : LOW);
  }
}
