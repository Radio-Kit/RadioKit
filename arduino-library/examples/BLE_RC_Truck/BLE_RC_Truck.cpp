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

  truckStatus.set("Ready to Drive");
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

    int8_t gas = gasPedal.get();
    int8_t steer = steeringWheel.get();
    uint8_t gearIdx = driveMode.get();  // Returns the index of the selected button

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
    if (lights.get() > 0) {
      status += " {L: ";
      if (lights.get(0)) status += "H ";
      if (lights.get(1)) status += "F ";
      if (lights.get(2)) status += "W ";
      if (lights.get(3)) status += "C ";
      status += "}";
    }

    truckStatus.set(status);
  }
}
