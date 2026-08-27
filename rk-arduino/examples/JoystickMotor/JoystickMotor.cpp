/**
 * JoystickMotor — RadioKit Example
 *
 * A joystick in the app drives two DC motors using differential steering:
 *   Y axis  → forward / reverse
 *   X axis  → left / right mix
 *
 * A button acts as an emergency stop (toggle).
 * An LED shows direction: GREEN=fwd, RED=rev, YELLOW=turn, OFF=stopped.
 * A text widget shows speed as a percentage.
 *
 * Hardware:
 *   - ESP32 dev board
 *   - L298N (or similar) dual H-bridge motor driver
 *     Left  motor ENA → GPIO 25
 *     Right motor ENB → GPIO 26
 *     Direction IN pins wired per your driver board
 *
 * Usage:
 *   1. Flash to ESP32
 *   2. Connect to "RobotDrive" in the RadioKit app
 *   3. Use the joystick to drive; tap E-Stop to halt
 */

#include <Arduino.h>
#include "RADIOKIT.h"

// ── Pin definitions ───────────────────────────────────────────
#define PWM_LEFT_PIN  25
#define PWM_RIGHT_PIN 26

// ── State ────────────────────────────────────────────────────────────
bool emergencyStop = false;
bool eStopPrev = false;  // for edge detection on button press

// ────────────────────────────────────────────────────────────
void setup() {
    pinMode(PWM_LEFT_PIN,  OUTPUT);
    pinMode(PWM_RIGHT_PIN, OUTPUT);
    analogWrite(PWM_LEFT_PIN,  0);
    analogWrite(PWM_RIGHT_PIN, 0);

    initRadioKit();

    // Post-construction rk field config
    dirLED.rk.state = false;
    dirLED.rk.color = RK_GREEN;
    dirLED.rk.shape = RK_LED_SHAPE_CIRCLE;
}

// ────────────────────────────────────────────────────────────
void loop() {
    RadioKit.update();

    // Emergency stop toggle on rising edge
    bool eStopNow = eStop.rk.state;
    if (eStopNow && !eStopPrev) {
        emergencyStop = !emergencyStop;
    }
    eStopPrev = eStopNow;

    if (emergencyStop) {
        analogWrite(PWM_LEFT_PIN,  0);
        analogWrite(PWM_RIGHT_PIN, 0);
        dirLED.rk.color = RK_RED;
        dirLED.rk.state = true;
        speedText.rk.content = "E-STOP";
        return;
    }

    // Read joystick axes (-100..+100)
    int8_t jx = drive.rk.xvalue;
    int8_t jy = drive.rk.yvalue;

    // Differential mixing
    int leftVal  = constrain((int)jy + (int)jx, -100, 100);
    int rightVal = constrain((int)jy - (int)jx, -100, 100);

    analogWrite(PWM_LEFT_PIN,  (uint8_t)map(abs(leftVal),  0, 100, 0, 255));
    analogWrite(PWM_RIGHT_PIN, (uint8_t)map(abs(rightVal), 0, 100, 0, 255));

    // Direction LED
    if (jx == 0 && jy == 0) {
        dirLED.rk.color = RK_OFF;
        dirLED.rk.state = false;
    } else if (abs(jx) > abs(jy)) {
        dirLED.rk.color = RK_YELLOW;
        dirLED.rk.state = true;
    } else if (jy > 0) {
        dirLED.rk.color = RK_GREEN;
        dirLED.rk.state = true;
    } else {
        dirLED.rk.color = RK_RED;
        dirLED.rk.state = true;
    }

    // Speed text
    int speed = max(abs((int)jx), abs((int)jy));
    char buf[24];
    if      (jy > 0)  snprintf(buf, sizeof(buf), "Fwd %d%%",            speed);
    else if (jy < 0)  snprintf(buf, sizeof(buf), "Rev %d%%",            speed);
    else if (jx != 0) snprintf(buf, sizeof(buf), "%s %d%%", jx > 0 ? "Right" : "Left", speed);
    else              snprintf(buf, sizeof(buf), "Stopped");
    speedText.rk.content = buf;
}
