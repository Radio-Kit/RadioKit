/*__RADIOKIT_Designer_Config__
{
  "version": 1,
  "appdata": {
    "appVersion": "1.0.0",
    "lastEdit": 1779879673081
  },
  "config": {
    "name": "WiFi_Cloud_Switch",
    "description": "Auth test: device_pass / user_pass",
    "type": "IOT",
    "transport": "BLE",
    "theme": "RK_DEFAULT",
    "password": "device_pass"
  },
  "canvas": {
    "size": [200, 100],
    "grid": "none",
    "skin": "dragon"
  },
  "widgets": [
    {
      "type": "switch",
      "name": "slide_switch_1",
      "label": { "text": "slide_switch_1", "show": false },
      "position": [135, 71, 0],
      "size": [null, 31],
      "haptic": true,
      "variant": "slideSwitch",
      "properties": {
        "onText": "ON",
        "offText": "OFF",
        "autoCenter": [null, "smooth", 300]
      }
    },
    {
      "type": "led",
      "name": "led_1",
      "label": { "text": "led_1", "show": false },
      "position": [115, 29, 0],
      "size": [null, 28],
      "haptic": true,
      "properties": {
        "state": "off",
        "shape": "circle",
        "color": 65280,
        "timing": 500,
        "autoCenter": [null, "smooth", 300]
      }
    }
  ]
}
RADIOKIT_Designer_Config__*/
//__RadioKit_Generated_Code__
//__Might_Be_Overwritten_

#ifndef RADIOKIT_UI_H
#define RADIOKIT_UI_H

#include <RadioKitLib.h>

// ─── Widget Declarations ───
RK_RockerSwitch slide_switch_1({
    .x = 135, .y = 71,
    .height = 31, .width = 0,
    .rotation = 0
});  // switch: pos=(135,71) size=?x31

RK_LED led_1({
    .x = 115, .y = 29,
    .height = 28, .width = 0,
    .rotation = 0
});  // led: pos=(115,29) size=?x28

// ─── Config Init ───
static inline void initRadioKit() {
  RadioKit.config.name          = "WiFi_Cloud_Switch";
  RadioKit.config.type          = "IOT";
  RadioKit.config.theme         = RK_DEFAULT;
  RadioKit.config.baudrate      = 1000000;

  // ── Cloud relay config ─────────────────────────────────
  RadioKit.config.cloud_url     = "10.0.0.17:9000";  // Local relay server
  RadioKit.config.cloud_account = "ecc5d5fa88ae5ce735dca88a60b68b20849fb1302192770f386207f5bfadaf0a";

  // ── STA WiFi compile-time defaults ────────────────────
  RadioKit.config.sta_ssid      = "Leap";
  RadioKit.config.sta_password  = "awsedrft";

  led_1.setColor(0x00ff00);

  RadioKit.begin();

  // Set user password in NVS (device password already set via JSON config)
  // This ensures user-level auth is also required.
  RadioKit.setConfig(nullptr, nullptr, nullptr, "user_pass");

  // ── Start ALL transports ──────────────────────────────
  RadioKit.startBLE(RadioKit.config.name);
  RadioKit.startWiFi();
  RadioKit.startCloud();  // Outbound relay connection to 10.0.0.17:9000
}

#endif // RADIOKIT_UI_H
