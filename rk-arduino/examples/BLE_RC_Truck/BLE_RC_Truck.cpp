/**
 * BLE_RC_Truck — RadioKit Example
 * 
 * A comprehensive example demonstrating a high-end RC Truck interface:
 *   - Gas pedal (Slider) with spring-to-zero behavior
 *   - Steering wheel (Knob) with self-centering
 *   - Gear selector (MultipleButton: D, P, R)
 *   - Light controls (MultipleSelect: Headlight, Fog, Hazard, Cabin)
 *   - Status display (Text) for real-time telemetry feedback
 *
 * This example focuses on the UI and does not require external hardware outputs.
 */

#include <Arduino.h>
#include "RADIOKIT.h"

// ── Setup ────────────────────────────────────────────────────────────

void setup() {
  Serial.begin(115200);
  delay(2000);
  Serial.println("--- RadioKit RC Truck Example ---");

  initRadioKit();

  truckStatus.rk.content = "Ready to Drive";
  Serial.println("System Ready.");
}

// ── Loop ─────────────────────────────────────────────────────────────

void loop() {
  // Process incoming BLE data and manage state
  RadioKit.update();

  // Logic to update the status display based on user input
  static uint32_t lastUpdate = 0;
  if (millis() - lastUpdate > 200) {
    lastUpdate = millis();

    int8_t gas = gasPedal.rk.value;
    int8_t steer = steeringWheel.rk.value;
    uint8_t gearIdx = driveMode.rk.value;

    String status;

    // Map gear index to label
    if (gearIdx == 0) status = "[D] ";
    else if (gearIdx == 1) status = "[P] ";
    else if (gearIdx == 2) status = "[R] ";
    else status = "[?] ";

    // Movement status
    if (gearIdx == 1) {
      status += "Parked";
    } else {
      if (gas > -90) {
        status += (gearIdx == 2) ? "Reversing..." : "Moving...";
      } else {
        status += "Idling";
      }
    }

    // Steering info
    if (steer < -10) status += " <";
    else if (steer > 10) status += " >";

    // Light info (Bitmask)
    if (lights.rk.value > 0) {
      status += " {L: ";
      if (lights.rk.value & (1 << 0)) status += "H ";
      if (lights.rk.value & (1 << 1)) status += "F ";
      if (lights.rk.value & (1 << 2)) status += "W ";
      if (lights.rk.value & (1 << 3)) status += "C ";
      status += "}";
    }

    // Store status in a persistent buffer
    static char _statusBuf[64];
    strncpy(_statusBuf, status.c_str(), sizeof(_statusBuf) - 1);
    _statusBuf[sizeof(_statusBuf) - 1] = '\0';
    truckStatus.rk.content = _statusBuf;
  }
}
