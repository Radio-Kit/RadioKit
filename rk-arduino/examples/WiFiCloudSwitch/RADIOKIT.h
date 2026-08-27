/*__RADIOKIT_Designer_Config__
{
  "version": 2,
  "appdata": {
    "appVersion": "1.0.0",
    "lastEdit": 1779879673081
  },
  "config": {
    "name": "WiFi_Cloud_Switch",
    "description": "Auth test: device_pass / user_pass",
    "type": "IOT",
    "transports": {
      "ble": { "enabled": true },
      "wifi": { "enabled": true, "ssid": "Leap", "pass": "awsedrft" },
      "cloud": { "enabled": true, "account": "6f5d64f15c8c0c80b3a39d4ed3ccfad30feb406ebaa6b36b70e80061389d3d1d", "relay": "10.0.0.9:9000" }
    },
    "theme": "dragon",
    "password": "device_pass"
  },
  "canvas": {
    "size": [200, 100],
    "grid": "none",
    "skin": "dragon"
  },
  "pages": [
    {
      "name": "Main",
      "orientation": "landscape",
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
  ]
}
RADIOKIT_Designer_Config__*/
//__RadioKit_Generated_Code__
//__Might_Be_Overwritten_

#ifndef RADIOKIT_UI_H
#define RADIOKIT_UI_H

#define RK_ENABLE_BLE
#define RK_ENABLE_WIFI
#define RK_ENABLE_CLOUD
#define RK_ENABLE_OTA
#include <RadioKitLib.h>

// ─── Widget Declarations ───
RK_RockerSwitch slide_switch_1(135, 71, 31);  // switch: pos=(135,71) size=?x31
RK_LED led_1(115, 29, 28);                    // led: pos=(115,29) size=?x28

// ─── Config Init ───
static inline void initRadioKit() {
  RadioKit.config.name          = "WiFi_Cloud_Switch";
  RadioKit.config.type          = "IOT";
  RadioKit.config.theme         = "dragon";
  RadioKit.config.baudrate      = 1000000;

  // ── Cloud relay config ─────────────────────────────────
  RadioKit.config.cloud_url     = "10.0.0.9:9000";  // Local relay server
  RadioKit.config.cloud_account = "6f5d64f15c8c0c80b3a39d4ed3ccfad30feb406ebaa6b36b70e80061389d3d1d";

  // ── STA WiFi compile-time defaults ────────────────────
  RadioKit.config.sta_ssid      = "Leap";
  RadioKit.config.sta_password  = "awsedrft";

  led_1.rk.color = 0x00ff00;

  RadioKit.begin();

  // Set user password in NVS (device password already set via JSON config)
  RadioKit.setConfig(nullptr, nullptr, nullptr, "user_pass");

  // Force-enable cloud in NVS on first boot (begin() defaults rk_cloud_on=0)
  {
    uint8_t _rkCloudOn = 0;
    RKNvs::readU8("rk_cloud_on", &_rkCloudOn);
    if (_rkCloudOn == 0) {
      RKNvs::writeU8("rk_cloud_on", 1);
      RKNvs::commit();
    }
  }

  RadioKit.startSerial(Serial);
  RadioKit.startBLE();
  RadioKit.startWiFi();
  RadioKit.startCloud();
}

#endif // RADIOKIT_UI_H
