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
#include <RadioKit.h>

// ── Widget declarations ──────────────────────────────────────────────

// 1. Gas Pedal on the left. Springs to -100 (idle) on release.
RK_GasPedal gasPedal({ .label = "Gas Pedal",
                       .x = 15,
                       .y = 60,
                       .rotation = -90,  // Vertical orientation
                       .scale = 1.2f,
                       .aspect = 3.0f,  // Taller slider
                       .value = -100 });

// 2. Steering Wheel on the right. Springs to 0 (center) on release.
RK_Knob steeringWheel({ .label = "Steering",
                        .x = 85,
                        .y = 60,
                        .scale = 1.5f,
                        .centering = RK_CENTER,
                        .value = 0,
                        .variant = 0x80 | RK_CENTER, // RK_SHAPE_ALT | RK_CENTER
                        .startAngle = -150,
                        .endAngle = 150 });

// 3. Gear Selector (D, P, R)
RK_MultipleButton driveMode({ .label = "Gear",
                              .x = 50,
                              .y = 85,
                              .scale = 1.0f,
                              .items = {
                                { .label = "D", .icon = "drive_eta" },
                                { .label = "P", .icon = "local_parking" },
                                { .label = "R", .icon = "settings_backup_restore" } } });

// 4. Lights Control (Multi-select)
RK_MultipleSelect lights({ .label = "Truck Lights",
                           .x = 50,
                           .y = 35,
                           .scale = 0.9f,
                           .items = {
                             { .label = "Head", .icon = "lightbulb" },
                             { .label = "Fog", .icon = "cloud" },
                             { .label = "Hazard", .icon = "warning" },
                             { .label = "Cabin", .icon = "home" } } });

// 5. Status Display at the top center
RK_Text truckStatus({ .label = "Truck Status",
                      .x = 50,
                      .y = 10,
                      .scale = 1.2f,
                      .text = "Initializing..." });

// ── Setup ────────────────────────────────────────────────────────────

void setup() {
  Serial.begin(115200);
  delay(2000);
  Serial.println("--- RadioKit RC Truck Example ---");

  // Optional: Set theme and orientation
  RadioKit.config.theme = RK_CYBERPUNK;
  RadioKit.config.orientation = RK_LANDSCAPE;
  RadioKit.config.description = "Advanced RC Truck Controller";

  // Initialize RadioKit
  RadioKit.begin();

  // Start BLE advertising as "RC Truck"
  RadioKit.startBLE("RC Truck");

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
