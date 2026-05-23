/**
 * SerialTest — RadioKit Example (v2.0)
 *
 * Minimal USB Serial sketch for testing the RadioKit app
 * over Web Serial (Chrome / Edge) or Android USB OTG.
 *
 * Wiring: LED anode → 220Ω → pin 7 → GND
 */

#include <Arduino.h>
#include "RadioKit_UI.h"

#define LED_PIN 7

void setup() {
  Serial.begin(115200);
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
  bool ledActive = btn.isPressed() || sw.get() || slideSw.get();
  digitalWrite(LED_PIN, ledActive ? HIGH : LOW);

  // Status LED colour reflects slider level (-100..+100)
  int8_t level = sld.get();
  if (level < 0) {
    statusLED.setColor(RK_RED);
  } else if (level == 0) {
    statusLED.setColor(RK_YELLOW);
  } else {
    statusLED.setColor(RK_GREEN);
  }

  // Pan knob: print value when it changes
  static int8_t lastPan = 0;
  int8_t panVal = pan.get();
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
    char buf[32];
    const char *modeName = (mode.get() == 0) ? "AUTO" : "MAN";
    snprintf(buf, sizeof(buf), "%s | %lus", modeName, (unsigned long)nowSec);
    uptimeText.set(buf);
  }

  // Options logic: if Mute is active, turn off LED regardless of slider
  if (opts.get(1)) { // "Mute" is the second item (bit 1)
    statusLED.off();
  } else {
    statusLED.on();
  }
}
