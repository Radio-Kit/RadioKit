/**
 * MultiPageController — RadioKit Example
 *
 * Demonstrates multi-page UI support:
 *   - Two pages: "Control" and "Settings"
 *   - Speed slider and Toggle button on the Control page
 *   - Status text and Indicator LED on the Settings page
 *   - Page switching via the Flutter app's PageSwitcher
 *
 * Hardware:
 *   - lolin_s3_mini (ESP32-S3) with WS2812 RGB LED on GPIO 2
 *   - No external components needed
 *
 * Usage:
 *   1. Flash to ESP32
 *   2. Open the RadioKit app and connect via BLE or USB Serial
 *   3. Use the page chevrons in the app to switch between Control and Settings
 *   4. Adjust the speed slider or toggle the button on the Control page
 *   5. View status text and indicator LED on the Settings page
 */

#include <Arduino.h>
#include "RADIOKIT.h"

// ── Pin definitions ───────────────────────────────────────────
#define LED_PIN       2  // Built-in WS2812 RGB LED

// ────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(1000000);
  while (!Serial) { delay(10); }
  delay(500);
  Serial.println("--- RadioKit MultiPageController Start ---");

  // Initialize RadioKit from the UI config and start transports.
  initRadioKit();

  // Set initial widget states
  status.rk.content = "Ready";
  indicator.rk.state = false;

  Serial.println("RK: Setup complete. Two pages available: Control, Settings.");
}

// ── State tracking ────────────────────────────────────────────
static bool lastToggleState = false;

// ────────────────────────────────────────────────────────────
void loop() {
  // Always call update() to process incoming packets and manage connections.
  RadioKit.update();

  // Reflect toggle state on the indicator LED (visible on Settings page)
  bool toggleNow = toggle.rk.state;
  if (toggleNow != lastToggleState) {
    lastToggleState = toggleNow;
    indicator.rk.state = toggleNow;

    Serial.print("RK: Toggle changed to ");
    Serial.println(toggleNow ? "ON" : "OFF");
  }

  // Update status text with current speed value (only if on Control page)
  int16_t speedVal = speed.rk.value;
  char buf[32];
  snprintf(buf, sizeof(buf), "Speed: %d", speedVal);
  status.rk.content = buf;
}
