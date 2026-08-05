/**
 * ESP32S3_DualLED_Test.cpp
 * ESP32-S3 Dual LED Test (GPIO 38 and GPIO 39) with RadioKit BLE & Serial.
 */

#include "RADIOKIT.h"

#define LED1_PIN 38
#define LED2_PIN 39

void setup() {
    Serial.begin(115200);
    delay(500);
    Serial.println("\n--- RadioKit ESP32-S3 Dual LED Test ---");

    pinMode(LED1_PIN, OUTPUT);
    pinMode(LED2_PIN, OUTPUT);
    digitalWrite(LED1_PIN, LOW);
    digitalWrite(LED2_PIN, LOW);

    RadioKit.config.name = "ESP32S3-DualLED";
    RadioKit.config.description = "Dual LED Controller (GPIO 38 & 39)";
    RadioKit.config.theme = "dragon";

    initRadioKit();
    RadioKit.begin();

#ifdef ENABLE_RK_SERIAL
    RadioKit.startSerial(Serial);
#endif
#ifdef ENABLE_RK_BLE
    RadioKit.startBLE("ESP32S3-DualLED");
#endif

    Serial.println("RadioKit started. Waiting for connections...");
}

void loop() {
    RadioKit.update();

    // Drive physical GPIO 38 and GPIO 39 pins
    digitalWrite(LED1_PIN, btn_led1.rk.state ? HIGH : LOW);
    digitalWrite(LED2_PIN, btn_led2.rk.state ? HIGH : LOW);

    // Static change tracking for debug log output
    static bool lastLed1 = false;
    static bool lastLed2 = false;

    if (btn_led1.rk.state != lastLed1) {
        lastLed1 = btn_led1.rk.state;
        Serial.printf("[LED1 / GPIO 38] State changed to: %s\n", lastLed1 ? "HIGH (ON)" : "LOW (OFF)");
        RadioKit.printf("[LED1] GPIO 38 -> %s\n", lastLed1 ? "ON" : "OFF");
    }

    if (btn_led2.rk.state != lastLed2) {
        lastLed2 = btn_led2.rk.state;
        Serial.printf("[LED2 / GPIO 39] State changed to: %s\n", lastLed2 ? "HIGH (ON)" : "LOW (OFF)");
        RadioKit.printf("[LED2] GPIO 39 -> %s\n", lastLed2 ? "ON" : "OFF");
    }
}
