/**
 * SliderServo — RadioKit Example
 *
 * A slider in the app controls a servo motor angle (0-180°).
 * A text widget shows the current angle.
 * An LED indicates the position zone:
 *   0-30°   → RED   (left)
 *   31-150°  → GREEN (centre)
 *   151-180° → BLUE  (right)
 *
 * Hardware:
 *   - ESP32 dev board
 *   - Standard RC servo: signal → GPIO 18, power → 5 V, GND → GND
 *
 * Requires the "ESP32Servo" library (install via Library Manager).
 *
 * Usage:
 *   1. Flash to ESP32
 *   2. Connect to "ServoControl" in the RadioKit app
 *   3. Drag the slider to move the servo
 *
 * ───────────────────────────────────────────────────────────────
 *  Editing policy
 *
 *  • Widget positions / labels / transport selection → RADIOKIT.h
 *  • This file: hardware pins, servo driving, and loop() logic only
 * ───────────────────────────────────────────────────────────────
 */

#include <Arduino.h>
#include <ESP32Servo.h>
#include "RADIOKIT.h"

// ── Pin definitions ───────────────────────────────────────────
#define SERVO_PIN 5

// ── Servo object ────────────────────────────────────────────────
Servo myServo;

// ──────────────────────────────────────────────────────────────
//  State tracking for zone LED debounce
// ──────────────────────────────────────────────────────────────
static int   lastAngle     = -1;
static uint32_t lastLedColor = 0;

// ──────────────────────────────────────────────────────────────
void setup()
{
    myServo.attach(SERVO_PIN, 500, 2400);
    myServo.write(90);   // centre on boot

    Serial.begin(115200);
    delay(2000);
    Serial.println("--- RadioKit SliderServo Start ---");

    initRadioKit();   // all RadioKit init lives in RADIOKIT.h

    zoneLED.rk.state = false;
    Serial.println("RK: Setup complete.");
}

// ──────────────────────────────────────────────────────────────
void loop()
{
    RadioKit.update();   // always pump the transport first

    // ── Servo range: slider -100..+100 → 0°..180° ──────────
    int angle = map(servoSlider.rk.value, -100, 100, 0, 180);
    myServo.write(angle);

    // ── Text widget: update only on change ───────────────────
    if (angle != lastAngle) {
        lastAngle = angle;
        char buf[16];
        snprintf(buf, sizeof(buf), "%d deg", angle);
        angleText.rk.content = "";  // Reset then set via snprintf if needed
        // Note: rk.content is a pointer; for persistent content, write to a static buffer.
        // Using a scoped buf here won't work across loop iterations.
        // For this demo, we use a simple approach:
        static char _angleBuf[16];
        snprintf(_angleBuf, sizeof(_angleBuf), "%d deg", angle);
        angleText.rk.content = _angleBuf;
    }

    // ── Zone LED: update only on zone change ─────────────────
    uint32_t zoneColor = RK_GREEN;   // default: centre zone
    if      (angle <= 30)   zoneColor = RK_RED;
    else if (angle <= 150)  zoneColor = RK_GREEN;
    else                    zoneColor = RK_BLUE;

    if (zoneColor != lastLedColor) {
        lastLedColor = zoneColor;
        zoneLED.rk.color = zoneColor;
    }
}
