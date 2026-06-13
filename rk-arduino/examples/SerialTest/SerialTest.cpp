/**
 * SerialTest — RadioKit Example (v2.0)
 *
 * Minimal USB Serial sketch for testing the RadioKit app
 * over Web Serial (Chrome / Edge) or Android USB OTG.
 *
 * Wiring: LED anode → 220Ω → pin 7 → GND
 */

#include <Arduino.h>
#include "RADIOKIT.h"

#define LED_PIN 7

void setup() {
  Serial.begin(1000000);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  initRadioKit();
  Serial.println("RADIOKIT_READY");
}

void loop() {
  RadioKit.update();

  // Simple heartbeat on LED_PIN
  static uint32_t lastHeartbeat = 0;
  if (millis() - lastHeartbeat > 1000) {
    digitalWrite(LED_PIN, !digitalRead(LED_PIN));
    lastHeartbeat = millis();
  }

  // LED control: Button or switches can turn on the LED
  bool ledActive = btn.rk.state || sw.rk.state || slideSw.rk.state;
  digitalWrite(LED_PIN, ledActive ? HIGH : LOW);

  // Status LED colour reflects slider level (-100..+100)
  int8_t level = sld.rk.value;
  if (level < 0) {
    statusLED.rk.color = RK_RED;
  } else if (level == 0) {
    statusLED.rk.color = RK_YELLOW;
  } else {
    statusLED.rk.color = RK_GREEN;
  }

  // Pan knob: print value when it changes
  static int8_t lastPan = 0;
  int8_t panVal = pan.rk.value;
  if (panVal != lastPan) {
    lastPan = panVal;
    Serial.print("Pan: ");
    Serial.println(panVal);
  }

  // Uptime text updates every second
  static uint32_t lastSec = 0;
  uint32_t nowSec = millis() / 1000;
  if (nowSec != lastSec) {
    lastSec = nowSec;
    static char _uptimeBuf[32];
    const char *modeName = (mode.rk.value == 0) ? "AUTO" : "MAN";
    snprintf(_uptimeBuf, sizeof(_uptimeBuf), "%s | %lus", modeName, (unsigned long)nowSec);
    uptimeText.rk.content = _uptimeBuf;
  }

  // Options logic: if Mute is active, turn off LED regardless of slider
  if (opts.rk.value & (1 << 1)) { // "Mute" is the second item (bit 1)
    statusLED.rk.state = false;
  } else {
    statusLED.rk.state = true;
  }
}
