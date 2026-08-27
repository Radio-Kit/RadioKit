/**
 * SerialSimple — RadioKit Example
 *
 * Minimal serial-only RadioKit example for RP2040 (and ESP32).
 * Demonstrates:
 *   - USB Serial transport (no BLE)
 *   - Push button widget controlling an LED widget
 *   - Cross-platform: compiles on RP2040, ESP32, and STM32
 *
 * Hardware:
 *   - Raspberry Pi Pico W (or any RP2040 board with USB Serial)
 *   - Onboard LED on GPIO 25 (Pico) or GPIO 6 (Pico W)
 *
 * Usage:
 *   1. Flash to your board
 *   2. Open the RadioKit app and connect via USB Serial at 115200 baud
 *   3. Tap the button to toggle the LED
 */

#include <Arduino.h>
#include "RADIOKIT.h"

#define LED_PIN 25  // Onboard LED (GPIO 25 on Pico; use WL_GPIO for Pico W)

void setup() {
  Serial.begin(115200);
  delay(1000);

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  initRadioKit();

  Serial.println("SerialSimple: Ready");
}

void loop() {
  RadioKit.update();

  // Sync the physical LED with the widget state
  digitalWrite(LED_PIN, led_1.rk.state ? HIGH : LOW);

  // Button press toggles the LED
  if (button_1.rk.state) {
    led_1.rk.state = !led_1.rk.state;
    button_1.rk.state = false;  // Reset the push button
  }
}
