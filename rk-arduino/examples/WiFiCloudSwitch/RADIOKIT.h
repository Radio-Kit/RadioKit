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
RK_RockerSwitch slide_switch_1(135, 71, 31);  // switch: pos=(135,71) size=?x31
RK_LED led_1(115, 29, 28);                    // led: pos=(115,29) size=?x28

// ─── Config Init ───
static inline void initRadioKit() {
  RadioKit.config.name          = "WiFi_Cloud_Switch";
  RadioKit.config.type          = "IOT";
  RadioKit.config.theme         = RK_DEFAULT;
  RadioKit.config.baudrate      = 1000000;

  // ── Cloud relay config ─────────────────────────────────
  RadioKit.config.cloud_url     = "10.0.0.17:9000";  // Local relay server
  RadioKit.config.cloud_account = "c29abe914b26b6349a299db2e5b9b2755f73ec85df83e3361abe1b1914a85992";

  // ── STA WiFi compile-time defaults ────────────────────
  RadioKit.config.sta_ssid      = "Leap";
  RadioKit.config.sta_password  = "awsedrft";

  led_1.rk.color = 0x00ff00;

  RadioKit.begin();

  // Set user password in NVS (device password already set via JSON config)
  // This ensures user-level auth is also required.
  RadioKit.setConfig(nullptr, nullptr, nullptr, "user_pass");

  // ── Start ALL transports ──────────────────────────────
  // Transport NVS defaults are set by RadioKit.begin() on first boot:
  // BLE=1, WiFi=1, Cloud=0. Enable cloud here unless the user has
  // explicitly disabled it via NVS_RAW_WRITE (rk_cloud_on=0).
  // Use readU8()'s return value to distinguish "key doesn't exist"
  // (first boot: write default 1) from "key exists with value 0"
  // (user disabled: respect choice and skip write).
  {
    uint8_t _rkCloudOn = 0;
    bool _rkCloudExists = RKNvs::readU8("rk_cloud_on", &_rkCloudOn);
    if (!_rkCloudExists) {
      RKNvs::writeU8("rk_cloud_on", 1);
      RKNvs::commit();
    }
  }

  RadioKit.startBLE(RadioKit.config.name);
  RadioKit.startWiFi();
  RadioKit.startCloud();  // Cloud relay requires WiFi + relay server running
}

#endif // RADIOKIT_UI_H
